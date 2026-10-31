import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../services/employee_photo_service.dart';
import '../services/permission_service.dart';
import '../core/auth/session_service.dart';

import '../widgets/app_drawer.dart';
import 'hr/biometric_logs_screen.dart';
import 'hr/manual_attendance_screen.dart';

/// سجل الحضور — مرآة شاشة بلازور (AttendanceList/Report):
/// فلاتر الفترة والبحث بالاسم للمديرين، وأعمدة التاريخ والحضور
/// والانصراف والحالة والموظف.
///
/// إصلاح السبب الجذري لخلوّ الشاشة من البيانات (2026-10-30):
/// كانت الشاشة ترسل دائمًا userId الخاص بالمشاهد نفسه، ومسار التقرير
/// في الـ API يفسّر أي userId وارد بوصفه «المستخدم المستهدف» فيقيّد
/// التقرير بكود بصمة ذلك المستخدم وحده — وللمدير بلا كود بصمة مرتبط
/// يرجع [] فورًا مهما وُجدت بيانات. الهوية تُستنتج من التوكن خادميًا
/// (غير المدير يُقيَّد تلقائيًا بسجلاته)، فلا يُرسل userId ولا role.
class AttendanceReportScreen extends StatefulWidget {
  final int? userId;
  final String? username;

  const AttendanceReportScreen({
    Key? key,
    this.userId,
    this.username,
  }) : super(key: key);

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen>
    with TickerProviderStateMixin {
  List<dynamic> records = [];
  bool loading = true;
  String? errorMessage;

  // إحصائيات
  int totalDays = 0;
  int lateDays = 0;
  int earlyLeaveDays = 0;
  int onTimeDays = 0;
  double totalWorkHours = 0.0;
  double averageHours = 0.0;
  double totalLateMinutes = 0.0;
  double totalEarlyMinutes = 0.0;

  // Filters
  String searchQuery = '';
  late DateTime fromDate;
  late DateTime toDate;
  String selectedView = 'monthly';

  Timer? _debounceTimer;
  late TabController _tabController;

  // متغير الطي
  bool _isStatsExpanded = false;

  bool get _isDark => ThemeService().isDarkMode;

  bool get isManager {
    final perms = PermissionService();
    return perms.isAdmin ||
        perms.isSalesManager ||
        perms.isAccountManager ||
        perms.isAccount ||
        perms.isWarehouse ||
        (perms.role?.toLowerCase() == 'hr');
  }

  Uint8List? _logoBytes;

  /// قراءة رقمية متسامحة: القيم قد تصل أرقامًا أو نصوصًا رقمية
  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int _int(dynamic v) => _num(v).round();

  /// تاريخ سجل بأمان — قيمة فاسدة ترجع اليوم بدل إسقاط الصف
  static DateTime _recordDate(dynamic item) {
    try {
      return DateTime.parse(item['LogDate'].toString());
    } catch (e) {
      return DateTime.now();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLogo();

    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month, 1);
    toDate = now;

    _tabController = TabController(length: 4, vsync: this);

    fetchReport();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogo() async {
    try {
      _logoBytes = await rootBundle
          .load('assets/icons/app_icon.png')
          .then((data) => data.buffer.asUint8List());
    } catch (e) {
      // الشعار اختياري في تصدير PDF — غيابه لا يمنع التقرير
    }
  }

  Future<void> fetchReport() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      // لا userId ولا role: الهوية والدور من التوكن على الخادم.
      // إرسال userId كان يقيّد تقرير المدير بكود بصمته هو (أو يرجع
      // قائمة فارغة عند غياب الربط) — وهو سبب خلوّ الشاشة من البيانات.
      final queryParams = <String, String>{
        'startDate': DateFormat('yyyy-MM-dd').format(fromDate),
        'endDate': DateFormat('yyyy-MM-dd').format(toDate),
        if (isManager && searchQuery.isNotEmpty) 'employeeName': searchQuery,
      };

      final uri = Uri.parse('$baseUrl/api/attendance/report')
          .replace(queryParameters: queryParams);
      final res =
          await http.get(uri, headers: SessionService.instance.authHeaders);

      if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          data = decoded['data'] as List<dynamic>;
        } else {
          data = const [];
        }
        setState(() {
          records = data;
          _calculateStats(data);
          loading = false;
        });
        _preloadPhotos();
      } else {
        String message = 'فشل تحميل سجل الحضور (رمز ${res.statusCode})';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }
        } catch (e) {
          // جسد الخطأ غير مقروء — تبقى الرسالة العامة
        }
        setState(() {
          loading = false;
          errorMessage = message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          errorMessage = 'فشل الاتصال بالخادم — تحقق من الشبكة وحاول مجددًا';
        });
      }
    }
  }

  void _calculateStats(List<dynamic> data) {
    totalDays = data.length;
    lateDays = data.where((r) => _int(r['LateMinutes']) > 0).length;
    earlyLeaveDays = data.where((r) => _int(r['EarlyLeaveMinutes']) > 0).length;
    onTimeDays = data
        .where((r) =>
            _int(r['LateMinutes']) == 0 &&
            _int(r['EarlyLeaveMinutes']) == 0 &&
            r['TimeIn'] != null)
        .length;

    totalWorkHours =
        data.fold(0.0, (sum, item) => sum + _num(item['TotalHours']));
    averageHours = totalDays > 0 ? totalWorkHours / totalDays : 0;

    totalLateMinutes =
        data.fold(0.0, (sum, item) => sum + _num(item['LateMinutes']));
    totalEarlyMinutes =
        data.fold(0.0, (sum, item) => sum + _num(item['EarlyLeaveMinutes']));
  }

  /// تحميل صور الموظفين المحلية لصفوف التقرير إلى ذاكرة الخدمة ثم
  /// إعادة الرسم — على نمط شاشة الموظفين تمامًا (محلي فقط، لا تأتي
  /// من الباك إند إطلاقًا)
  Future<void> _preloadPhotos() async {
    final service = EmployeePhotoService();
    final ids = <int>{
      for (final item in records)
        if ((item['EmployeeID'] as num?)?.toInt() != null)
          (item['EmployeeID'] as num).toInt(),
    };
    if (ids.isEmpty) return;
    await Future.wait([for (final id in ids) service.loadFor(id)]);
    if (mounted) setState(() {});
  }

  /// تحليل وقت التقرير بصيغ الإنتاج ('hh:mm tt') إلى دقائق منذ منتصف
  /// الليل — بأنماط صريحة ثم تحليل يدوي حتمي كما في شاشة الشيفت
  /// (لا DateFormat بلغة الجهاز)، لكن الفشل هنا يرجع null فيُخفى
  /// الشريط الزمني بدل اختراع وقت
  static int? _timeToMinutes(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    for (final pattern in ['hh:mm a', 'h:mm a', 'HH:mm:ss', 'HH:mm']) {
      try {
        final dt = DateFormat(pattern, 'en_US').parse(s);
        return dt.hour * 60 + dt.minute;
      } catch (e) {
        // جرّب النمط التالي
      }
    }
    try {
      var t = s.toUpperCase();
      final isPm = t.contains('PM') || t.contains('م');
      final isAm = t.contains('AM') || t.contains('ص');
      t = t.replaceAll(RegExp(r'[^0-9:]'), ' ');
      final nums = t
          .split(RegExp(r'[:\s]+'))
          .where((p) => p.isNotEmpty)
          .map(int.parse)
          .toList();
      var hour = nums[0];
      final minute = nums.length > 1 ? nums[1] : 0;
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return (hour % 24) * 60 + (minute % 60);
    } catch (e) {
      return null;
    }
  }

  /// تنسيق دقائق منذ منتصف الليل لعرض التسميات ('9:00 ص')
  static String _minutesLabel(int minutes) {
    final h24 = (minutes ~/ 60) % 24;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = (minutes % 60).toString().padLeft(2, '0');
    return '$h12:$mm ${h24 < 12 ? 'ص' : 'م'}';
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: ThemeService().accentColor,
                surface: AppColors.surface(_isDark),
                onSurface: AppColors.text(_isDark),
              ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
        selectedView = 'custom';
      });
      fetchReport();
    }
  }

  void _onSearchChanged(String query) {
    if (!isManager) return;
    setState(() => searchQuery = query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        fetchReport();
      }
    });
  }

  void _setDateRange(String range) {
    if (!mounted) return;

    final now = DateTime.now();
    setState(() {
      selectedView = range;
      switch (range) {
        case 'daily':
          fromDate = now;
          toDate = now;
          break;
        case 'weekly':
          fromDate = now.subtract(Duration(days: now.weekday - 1));
          toDate = now;
          break;
        case 'monthly':
          fromDate = DateTime(now.year, now.month, 1);
          toDate = now;
          break;
      }
    });
    fetchReport();
  }

  // ========== دوال التصدير ==========
  Future<void> _exportToExcel() async {
    try {
      if (records.isEmpty) {
        _showSnackBar('لا توجد بيانات للتصدير',
            _isDark ? AppColors.warningLight : AppColors.warning);
        return;
      }

      var excelFile = excel.Excel.createExcel();
      excel.Sheet sheetObject = excelFile['تقرير الحضور'];

      sheetObject.appendRow([
        excel.TextCellValue('التاريخ'),
        excel.TextCellValue('الموظف'),
        excel.TextCellValue('الحضور'),
        excel.TextCellValue('الانصراف'),
        excel.TextCellValue('تأخير (د)'),
        excel.TextCellValue('مبكر (د)'),
        excel.TextCellValue('إجمالي الساعات'),
      ]);

      for (var item in records) {
        final date = _recordDate(item);
        sheetObject.appendRow([
          excel.TextCellValue(DateFormat('yyyy-MM-dd').format(date)),
          excel.TextCellValue(item['FullName'] ?? ''),
          excel.TextCellValue(item['TimeIn'] ?? '--:--'),
          excel.TextCellValue(item['TimeOut'] ?? '--:--'),
          excel.TextCellValue('${_int(item['LateMinutes'])}'),
          excel.TextCellValue('${_int(item['EarlyLeaveMinutes'])}'),
          excel.TextCellValue(_num(item['TotalHours']).toStringAsFixed(1)),
        ]);
      }

      var fileBytes = excelFile.save();
      if (fileBytes == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'attendance_report_$timestamp.xlsx';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(fileBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'تقرير الحضور');

      _showSnackBar('تم التصدير بنجاح',
          _isDark ? AppColors.successLight : AppColors.success);
    } catch (e) {
      _showSnackBar(
          'حدث خطأ: $e', _isDark ? AppColors.errorLight : AppColors.error);
    }
  }

  Future<void> _exportToPDF() async {
    try {
      if (records.isEmpty) {
        _showSnackBar('لا توجد بيانات للتصدير',
            _isDark ? AppColors.warningLight : AppColors.warning);
        return;
      }

      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (_logoBytes != null)
                  pw.Container(
                    width: 40,
                    height: 40,
                    child: pw.Image(pw.MemoryImage(_logoBytes!)),
                  ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'تقرير الحضور والانصراف',
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            font: ttf),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'COCOBOLO Furniture',
                        style: pw.TextStyle(
                            fontSize: 12, color: PdfColors.amber, font: ttf),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'الفترة: ${DateFormat('yyyy-MM-dd').format(fromDate)} إلى ${DateFormat('yyyy-MM-dd').format(toDate)}',
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey, font: ttf),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'تاريخ التقرير:',
                      style: pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey, font: ttf),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Text(
                      DateFormat('yyyy/MM/dd').format(DateTime.now()),
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          font: ttf),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ],
                ),
              ],
            ),
          ),
          build: (context) => [
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPdfStat('إجمالي الأيام', '$totalDays', ttf),
                  _buildPdfStat(
                      'إجمالي الساعات', totalWorkHours.toStringAsFixed(1), ttf),
                  _buildPdfStat('أيام التأخير', '$lateDays', ttf),
                  _buildPdfStat('أيام المبكر', '$earlyLeaveDays', ttf),
                ],
              ),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.amber),
                  children: [
                    _buildTableCell('الحالة', ttf, isHeader: true),
                    _buildTableCell('الانصراف', ttf, isHeader: true),
                    _buildTableCell('الحضور', ttf, isHeader: true),
                    _buildTableCell('الموظف', ttf, isHeader: true),
                    _buildTableCell('التاريخ', ttf, isHeader: true),
                  ],
                ),
                ...records.map((item) {
                  final date = _recordDate(item);
                  return pw.TableRow(
                    children: [
                      _buildTableCell(_getStatusText(item), ttf),
                      _buildTableCell(item['TimeOut'] ?? '--:--', ttf),
                      _buildTableCell(item['TimeIn'] ?? '--:--', ttf),
                      _buildTableCell(
                          item['FullName']?.split(' ')[0] ?? '', ttf),
                      _buildTableCell(
                          DateFormat('yyyy-MM-dd').format(date), ttf),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'توقيع المدير: ____________________',
                  style: pw.TextStyle(font: ttf, fontSize: 10),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  'توقيع الموظف: ____________________',
                  style: pw.TextStyle(font: ttf, fontSize: 10),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'صفحة ${context.pageNumber} من ${context.pagesCount}',
              style:
                  pw.TextStyle(color: PdfColors.grey, font: ttf, fontSize: 8),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'attendance_report.pdf',
      );
    } catch (e) {
      _showSnackBar(
          'حدث خطأ: $e', _isDark ? AppColors.errorLight : AppColors.error);
    }
  }

  pw.Widget _buildTableCell(String text, pw.Font font,
      {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPdfStat(String label, String value, pw.Font font) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, font: font, fontSize: 12),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: pw.TextStyle(color: PdfColors.grey, font: font, fontSize: 8),
          textDirection: pw.TextDirection.rtl,
        ),
      ],
    );
  }

  String _getStatusText(item) {
    final late = _int(item['LateMinutes']);
    final early = _int(item['EarlyLeaveMinutes']);
    if (late > 0) return 'تأخير $lateد';
    if (early > 0) return 'مبكر $earlyد';
    return 'منتظم';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ========== البناء الرئيسي ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'rpt_empAttendance'),
      backgroundColor: AppColors.background(_isDark),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // الفلاتر ثابتة
          _buildFiltersBar(),

          // التابات ثابتة
          _buildTabBar(),

          // المحتوى
          Expanded(
            child: loading
                ? _buildLoadingState()
                : errorMessage != null && records.isEmpty
                    ? AppError(message: errorMessage!, onRetry: fetchReport)
                    : records.isEmpty
                        ? _buildEmptyState()
                        : _buildDataTable(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_rounded,
                color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'سجل الحضور',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
          ),
        ],
      ),
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      leading: const AppDrawerMenuButton(),
      actions: [
        if (PermissionService().canViewRawLogs)
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'سجلات البصمة الخام',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BiometricLogsScreen(
                  userId: widget.userId ?? PermissionService().userId ?? 0,
                  username: widget.username ?? '',
                ),
              ),
            ),
          ),
        if (PermissionService().canManualWriteAttendance)
          IconButton(
            icon: const Icon(Icons.edit_calendar_rounded,
                color: Colors.white),
            tooltip: 'الحضور اليدوي اليومي',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManualAttendanceScreen(
                  userId: widget.userId ?? PermissionService().userId ?? 0,
                  username: widget.username ?? '',
                ),
              ),
            ),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          color: AppColors.surface(_isDark),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'excel') _exportToExcel();
            if (value == 'pdf') _exportToPDF();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'excel',
              child: Row(
                children: [
                  Icon(Icons.grid_on_rounded,
                      color:
                          _isDark ? AppColors.successLight : AppColors.success,
                      size: 18),
                  const SizedBox(width: 10),
                  Text('تصدير Excel',
                      style: TextStyle(color: AppColors.text(_isDark))),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_rounded,
                      color: _isDark ? AppColors.errorLight : AppColors.error,
                      size: 18),
                  const SizedBox(width: 10),
                  Text('تصدير PDF',
                      style: TextStyle(color: AppColors.text(_isDark))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        border: Border(bottom: BorderSide(color: AppColors.divider(_isDark))),
      ),
      child: Column(
        children: [
          if (isManager)
            TextField(
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.text(_isDark),
                    fontSize: 13,
                  ),
              decoration: InputDecoration(
                hintText: 'ابحث عن موظف...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _isDark
                          ? AppColors.textSecondary(_isDark)
                          : AppColors.textHint(_isDark),
                      fontSize: 13,
                    ),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.gold, size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            color: AppColors.textSecondary(_isDark), size: 16),
                        onPressed: () {
                          setState(() => searchQuery = '');
                          fetchReport();
                        },
                      )
                    : null,
                filled: true,
                fillColor: _isDark
                    ? AppColors.card(_isDark)
                    : AppColors.inputFill(_isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: _isDark
                      ? BorderSide(color: Colors.white.withValues(alpha: 0.12))
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide(color: ThemeService().accentColor),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: _onSearchChanged,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _isDark
                    ? AppColors.card(_isDark)
                    : AppColors.inputFill(_isDark),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded,
                      color: AppColors.gold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      PermissionService().fullName ?? widget.username ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.text(_isDark),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRangeChip('يوم', 'daily', Icons.today_rounded),
                const SizedBox(width: 6),
                _buildRangeChip('أسبوع', 'weekly', Icons.view_week_rounded),
                const SizedBox(width: 6),
                _buildRangeChip('شهر', 'monthly', Icons.calendar_month_rounded),
                const SizedBox(width: 6),
                _buildRangeChip('مخصص', 'custom', Icons.date_range_rounded),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildDateSelector('من:', fromDate, true)),
              const SizedBox(width: 6),
              Expanded(child: _buildDateSelector('إلى:', toDate, false)),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.gold, size: 18),
                onPressed: fetchReport,
                style: IconButton.styleFrom(
                  backgroundColor: _isDark
                      ? AppColors.card(_isDark)
                      : AppColors.inputFill(_isDark),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeChip(String label, String value, IconData icon) {
    final isSelected = selectedView == value;
    final accent = ThemeService().accentColor;
    return GestureDetector(
      onTap: () => _setDateRange(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isDark ? AppColors.gold : AppColors.navy)
              : (_isDark
                  ? AppColors.card(_isDark)
                  : AppColors.inputFill(_isDark)),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected
                ? (_isDark ? AppColors.gold : AppColors.navy)
                : AppColors.divider(_isDark),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected
                    ? (_isDark ? AppColors.navy : Colors.white)
                    : accent,
                size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? (_isDark ? AppColors.navy : Colors.white)
                        : AppColors.text(_isDark),
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime date, bool isFrom) {
    return GestureDetector(
      onTap: () => _selectDate(context, isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color:
              _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.divider(_isDark)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontSize: 10,
                    )),
            Text(
              DateFormat('yyyy/MM/dd').format(date),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.text(_isDark),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // الإحصائيات القابلة للطي — بطاقة مرساة كحلية مختصرة + تفاصيل سطحية
  Widget _buildStatsCards() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isStatsExpanded = !_isStatsExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppGradients.identityHeader,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_rounded,
                        color: AppColors.gold, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'الإحصائيات',
                      style: textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!_isStatsExpanded) ...[
                      _buildMiniStat('$totalDays يوم', AppColors.infoLight),
                      const SizedBox(width: 6),
                      _buildMiniStat('$lateDays تأخير', AppColors.warningLight),
                      const SizedBox(width: 6),
                      _buildMiniStat(
                          '$onTimeDays منتظم', AppColors.successLight),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      _isStatsExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.gold,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _buildStatCard(
                            'أيام العمل',
                            '$totalDays',
                            Icons.calendar_month_rounded,
                            _isDark ? AppColors.infoLight : AppColors.info)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: _buildStatCard(
                            'إجمالي الساعات',
                            totalWorkHours.toStringAsFixed(1),
                            Icons.timer_rounded,
                            _isDark
                                ? AppColors.successLight
                                : AppColors.success)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                        child: _buildStatCard(
                            'منتظم',
                            '$onTimeDays',
                            Icons.check_circle_rounded,
                            _isDark
                                ? AppColors.successLight
                                : AppColors.success)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: _buildStatCard(
                            'متأخر',
                            '$lateDays',
                            Icons.warning_rounded,
                            _isDark
                                ? AppColors.warningLight
                                : AppColors.warning)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: _buildStatCard(
                            'مبكر',
                            '$earlyLeaveDays',
                            Icons.logout_rounded,
                            _isDark ? AppColors.errorLight : AppColors.error)),
                  ],
                ),
              ],
            ),
          ),
          secondChild: const SizedBox(height: 0),
          crossFadeState: _isStatsExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 3),
          AmountText(value: value, color: AppColors.text(_isDark), size: 13),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 9,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface(_isDark),
      child: TabBar(
        controller: _tabController,
        indicatorColor: ThemeService().accentColor,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(text: 'السجل'),
          Tab(text: 'إحصائيات'),
          Tab(text: 'التأخير'),
          Tab(text: 'ملخص'),
        ],
        labelStyle:
            Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 11),
        unselectedLabelColor: AppColors.textSecondary(_isDark),
        labelColor: _isDark ? AppColors.gold : AppColors.navy,
      ),
    );
  }

  Widget _buildDataTable() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildRecordsView(),
        _buildStatisticsView(),
        _buildLateAnalysisView(),
        _buildQuickSummaryView(),
      ],
    );
  }

  // تبويب السجل: بطاقات مجمّعة بالأيام بدل جدول الأعمدة — ترويسة
  // يوم لاصقة بعدّاداته (حاضر/متأخر/غائب) وبطاقة لكل موظف فيها
  // رقائقا الحضور والانصراف وشارة الحالة كما كانت تُحسب، وصورة
  // الموظف، وشريط زمني (متوقع/فعلي) حين يرجع ShiftStart/ShiftEnd
  // من الـ API — يُحسم خادميًا بنفس قاعدة حساب التأخير/المبكر،
  // وغيابه (لا شيفت محسمًا للصف) يُخفي الشريط دون اختراع أوقات.
  Widget _buildRecordsView() {
    final groups = _groupRecordsByDay();
    return Column(
      children: [
        _buildStatsCards(),
        Expanded(
          child: CustomScrollView(
            slivers: [
              for (final group in groups) ...[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DayHeaderDelegate(
                    height: 46,
                    child: _buildDayHeader(group),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  sliver: SliverList.builder(
                    itemCount: group.rows.length,
                    itemBuilder: (context, index) =>
                        _buildRecordCard(group.rows[index], index),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// تجميع السجلات بأيامها — الردّ مرتب أصلًا بالأحدث أولًا،
  /// فالتجميع على التوالي المتجاور صحيح.
  List<_DayGroup> _groupRecordsByDay() {
    final groups = <_DayGroup>[];
    for (final item in records) {
      final date = _recordDate(item);
      final day = DateTime(date.year, date.month, date.day);
      if (groups.isEmpty || groups.last.day != day) {
        groups.add(_DayGroup(day: day, rows: [item]));
      } else {
        groups.last.rows.add(item);
      }
    }
    return groups;
  }

  Widget _buildDayHeader(_DayGroup group) {
    var present = 0;
    var late = 0;
    var absent = 0;
    for (final item in group.rows) {
      if (_int(item['LateMinutes']) > 0) late++;
      if (item['Status']?.toString() == 'غائب' || item['TimeIn'] == null) {
        absent++;
      } else {
        present++;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background(_isDark),
        border: Border(
          bottom: BorderSide(color: AppColors.divider(_isDark)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded,
              size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              DateFormat('EEEE، dd MMMM yyyy', 'ar').format(group.day),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.text(_isDark),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (present > 0)
            _buildDayCountChip(
              'حاضر $present',
              _isDark ? AppColors.successLight : AppColors.success,
            ),
          if (late > 0)
            _buildDayCountChip(
              'متأخر $late',
              _isDark ? AppColors.errorLight : AppColors.error,
            ),
          if (absent > 0)
            _buildDayCountChip(
              'غائب $absent',
              _isDark ? AppColors.neutralLight : AppColors.neutral,
            ),
        ],
      ),
    );
  }

  Widget _buildDayCountChip(String label, Color color) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Widget _buildRecordCard(dynamic item, int index) {
    final lateMins = _int(item['LateMinutes']);
    final earlyMins = _int(item['EarlyLeaveMinutes']);
    final textTheme = Theme.of(context).textTheme;

    // شارة الحالة بنفس اشتقاق الجدول السابق حرفيًا
    final (badgeLabel, badgeColor) = lateMins > 0
        ? ('تأخير $lateMins', _isDark ? AppColors.errorLight : AppColors.error)
        : earlyMins > 0
            ? (
                'مبكر $earlyMins',
                _isDark ? AppColors.warningLight : AppColors.warning
              )
            : ('منتظم', _isDark ? AppColors.successLight : AppColors.success);

    final timeIn = item['TimeIn']?.toString();
    final timeOut = item['TimeOut']?.toString();
    final jobTitle = item['JobTitle']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        color: AppColors.surface(_isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildRecordAvatar(item),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['FullName']?.toString() ?? '',
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.text(_isDark),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (jobTitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          jobTitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(_isDark),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                StatusBadge(label: badgeLabel, color: badgeColor, small: true),
                if (PermissionService().canManualWriteAttendance &&
                    (item['EmployeeID'] as num?)?.toInt() != null)
                  IconButton(
                    icon: Icon(Icons.edit_rounded,
                        size: 18,
                        color: _isDark ? AppColors.gold : AppColors.navy),
                    tooltip: 'تعديل يدوي',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManualAttendanceScreen(
                          userId:
                              widget.userId ?? PermissionService().userId ?? 0,
                          username: widget.username ?? '',
                          initialEmployeeId:
                              (item['EmployeeID'] as num).toInt(),
                          initialDate: _recordDate(item),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTimeChip(
                    icon: Icons.login_rounded,
                    label: 'حضور',
                    value: timeIn ?? 'بلا حضور',
                    tint: _isDark ? AppColors.successLight : AppColors.success,
                    foreground: lateMins > 0
                        ? (_isDark ? AppColors.errorLight : AppColors.error)
                        : (_isDark
                            ? AppColors.successLight
                            : AppColors.success),
                    muted: timeIn == null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTimeChip(
                    icon: Icons.logout_rounded,
                    label: 'انصراف',
                    value: timeOut ?? 'بلا انصراف',
                    tint: AppColors.gold,
                    foreground: earlyMins > 0
                        ? (_isDark ? AppColors.warningLight : AppColors.warning)
                        : (_isDark ? AppColors.gold : AppColors.navy),
                    muted: timeOut == null,
                  ),
                ),
              ],
            ),
            _buildTimelineStrip(item),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms, delay: (index * 30).ms);
  }

  /// بلاطة رمز شخص محايدة — الملاذ الأخير حين لا يحمل الصف رقم
  /// موظف أو تفشل الصورة الافتراضية المُجمّعة نفسها
  Widget _glyphAvatarTile() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: _isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Icon(Icons.person_rounded,
          color: AppColors.gold, size: 20),
    );
  }

  /// الصورة الافتراضية المطابقة لنوع الموظف كما في شاشة الموظفين:
  /// «أنثى» للأنثى، وما عداها للذكر — أصل مُجمّع داخل التطبيق
  Widget _defaultAvatarImage(dynamic item) {
    return Image.asset(
      item['Gender']?.toString() == 'أنثى'
          ? 'assets/images/default_avatar_female.png'
          : 'assets/images/default_avatar_male.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.person_rounded, size: 20, color: AppColors.gold),
      ),
    );
  }

  /// أفاتار صف السجل بنفس حسم شاشة الموظفين: الصورة المحلية من
  /// EmployeePhotoService عند توفرها، وإلا الافتراضية بحسب النوع،
  /// داخل الإطار الدائري ذي الحلقة الذهبية نفسه. صف بلا EmployeeID
  /// يبقى على بلاطة الرمز المحايدة.
  Widget _buildRecordAvatar(dynamic item) {
    final employeeId = (item['EmployeeID'] as num?)?.toInt();
    if (employeeId == null) return _glyphAvatarTile();
    final bytes = EmployeePhotoService().bytesFor(employeeId);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.navy.withValues(alpha: 0.08),
        border: Border.all(
          color: _isDark
              ? AppColors.gold.withValues(alpha: 0.55)
              : AppColors.goldDark.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: ClipOval(
          child: bytes == null
              ? _defaultAvatarImage(item)
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _defaultAvatarImage(item),
                ),
        ),
      ),
    );
  }

  /// الشريط الزمني للصف: يُرسم فقط حين يحمل الصف وقتي شيفت محسمين
  /// (ShiftStart/ShiftEnd) ووقت حضور على الأقل — وما عداه يرجع
  /// فراغًا فيبقى شكل البطاقة كما هو تمامًا.
  /// المقياس: [بداية الشيفت − 60 دقيقة، نهايته + 60 دقيقة].
  /// المسار = نافذة الشيفت بدرجة سطح باهتة؛ والمقطع الفعلي من
  /// الدخول إلى الانصراف (أو إلى نهاية النافذة عند غياب الانصراف)
  /// بالكحلي في الفاتح والذهبي في الليلي؛ ورأس التأخير (دخول بعد
  /// بداية الشيفت) وذيل المبكر (انصراف قبل نهايته) بدرجة الخطأ.
  Widget _buildTimelineStrip(dynamic item) {
    final shiftStart = _timeToMinutes(item['ShiftStart']);
    final shiftEnd = _timeToMinutes(item['ShiftEnd']);
    final timeIn = _timeToMinutes(item['TimeIn']);
    if (shiftStart == null || shiftEnd == null || timeIn == null) {
      return const SizedBox.shrink();
    }
    final timeOut = _timeToMinutes(item['TimeOut']);
    final scaleStart = shiftStart - 60;
    final scaleSpan = (shiftEnd + 60) - scaleStart;
    if (scaleSpan <= 0) return const SizedBox.shrink();

    final actualEnd = timeOut ?? shiftEnd;
    final actualColor = _isDark ? AppColors.gold : AppColors.navy;
    final errorColor = _isDark ? AppColors.errorLight : AppColors.error;
    final trackColor =
        _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            double at(int minutes) =>
                (((minutes - scaleStart) / scaleSpan).clamp(0.0, 1.0)) * width;
            Widget segment(int from, int to, Color color) {
              final left = at(from);
              final w = at(to) - left;
              if (w < 1) return const SizedBox.shrink();
              return PositionedDirectional(
                start: left,
                width: w,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 8,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // مسار نافذة الشيفت
                  segment(shiftStart, shiftEnd, trackColor),
                  // رأس التأخير داخل النافذة قبل الدخول الفعلي
                  if (timeIn > shiftStart)
                    segment(shiftStart, timeIn, errorColor),
                  // ذيل الانصراف المبكر داخل النافذة بعد الانصراف
                  if (timeOut != null && timeOut < shiftEnd)
                    segment(timeOut, shiftEnd, errorColor),
                  // المقطع الفعلي المُنجز
                  segment(timeIn, actualEnd, actualColor),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          'الشيفت ${_minutesLabel(shiftStart)} – ${_minutesLabel(shiftEnd)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary(_isDark),
                fontSize: 10,
              ),
        ),
      ],
    );
  }

  /// رقاقة وقت ملوّنة الخلفية: أيقونة + عنوان + القيمة بخط عريض؛
  /// الغياب (لا بصمة) يظهر بدرجة محايدة باهتة.
  Widget _buildTimeChip({
    required IconData icon,
    required String label,
    required String value,
    required Color tint,
    required Color foreground,
    required bool muted,
  }) {
    final effective = muted ? AppColors.textSecondary(_isDark) : foreground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: muted
            ? (_isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark))
            : tint.withValues(alpha: _isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: effective),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 10,
                ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: effective,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsView() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildStatSection('معدلات الأداء', [
          _buildStatRow(
              'متوسط ساعات العمل اليومي',
              '${averageHours.toStringAsFixed(1)} ساعة',
              _isDark ? AppColors.infoLight : AppColors.info),
          _buildStatRow(
              'إجمالي دقائق التأخير',
              '${totalLateMinutes.toStringAsFixed(0)} د',
              _isDark ? AppColors.warningLight : AppColors.warning),
          _buildStatRow(
              'إجمالي دقائق الانصراف المبكر',
              '${totalEarlyMinutes.toStringAsFixed(0)} د',
              _isDark ? AppColors.errorLight : AppColors.error),
        ]),
        const SizedBox(height: 16),
        _buildStatSection('نسب مئوية', [
          _buildProgressRow(
              'نسبة الحضور المنتظم',
              totalDays > 0 ? onTimeDays / totalDays : 0,
              _isDark ? AppColors.successLight : AppColors.success),
          _buildProgressRow(
              'نسبة التأخير',
              totalDays > 0 ? lateDays / totalDays : 0,
              _isDark ? AppColors.warningLight : AppColors.warning),
          _buildProgressRow(
              'نسبة الانصراف المبكر',
              totalDays > 0 ? earlyLeaveDays / totalDays : 0,
              _isDark ? AppColors.errorLight : AppColors.error),
        ]),
      ],
    );
  }

  Widget _buildLateAnalysisView() {
    final lateRecords =
        records.where((r) => _int(r['LateMinutes']) > 0).toList();
    final errorColor = _isDark ? AppColors.errorLight : AppColors.error;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'تحليل أيام التأخير',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.text(_isDark),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
            ),
          ),
        ),
        Expanded(
          child: lateRecords.isEmpty
              ? AppEmpty(
                  icon: Icons.check_circle_rounded,
                  message: 'لا توجد أيام تأخير',
                  hint: 'كل السجلات في الفترة المحددة منتظمة')
              : ListView.separated(
                  itemCount: lateRecords.length,
                  separatorBuilder: (c, i) =>
                      Divider(height: 1, color: AppColors.divider(_isDark)),
                  itemBuilder: (c, i) {
                    final item = lateRecords[i];
                    final date = _recordDate(item);
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: errorColor.withValues(alpha: 0.12),
                        child: Text('${i + 1}',
                            style: TextStyle(
                                color: errorColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                      title: Text(
                        DateFormat('yyyy-MM-dd').format(date),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.text(_isDark),
                              fontSize: 12,
                            ),
                      ),
                      subtitle: Text(
                        item['FullName'] ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary(_isDark),
                              fontSize: 10.5,
                            ),
                      ),
                      trailing: StatusBadge(
                        label: '${_int(item['LateMinutes'])} د',
                        color: errorColor,
                        small: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildQuickSummaryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircularStat(
                  'أيام',
                  totalDays.toString(),
                  Icons.calendar_month_rounded,
                  _isDark ? AppColors.infoLight : AppColors.info),
              _buildCircularStat(
                  'ساعات',
                  totalWorkHours.toStringAsFixed(0),
                  Icons.timer_rounded,
                  _isDark ? AppColors.successLight : AppColors.success),
              _buildCircularStat(
                  'نسبة',
                  '${totalDays > 0 ? ((onTimeDays / totalDays) * 100).toStringAsFixed(0) : '0'}%',
                  Icons.percent_rounded,
                  _isDark ? AppColors.warningLight : AppColors.warning),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 2.8,
            children: [
              _buildSummaryBox(
                  'تأخير',
                  lateDays.toString(),
                  Icons.warning_amber_rounded,
                  _isDark ? AppColors.errorLight : AppColors.error),
              _buildSummaryBox(
                  'مبكر',
                  earlyLeaveDays.toString(),
                  Icons.logout_rounded,
                  _isDark ? AppColors.warningLight : AppColors.warning),
              _buildSummaryBox(
                  'دقائق تأخير',
                  totalLateMinutes.toStringAsFixed(0),
                  Icons.timer_off_rounded,
                  _isDark ? AppColors.errorLight : AppColors.error),
              _buildSummaryBox(
                  'دقائق مبكر',
                  totalEarlyMinutes.toStringAsFixed(0),
                  Icons.timer_rounded,
                  _isDark ? AppColors.warningLight : AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 9,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularStat(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface(_isDark),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 2),
          AmountText(value: value, color: AppColors.text(_isDark), size: 13),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 8.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
            title: title,
            icon: Icons.analytics_rounded,
            accent: ThemeService().accentColor),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontSize: 11.5,
                    )),
          ),
          Text(value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  )),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, double progress, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 11.5,
                      )),
              Text('${(progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      )),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.divider(_isDark),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const AppLoading(message: 'جاري تحميل سجل الحضور...');
  }

  Widget _buildEmptyState() {
    return const AppEmpty(
      icon: Icons.table_rows_rounded,
      message: 'لا توجد بيانات',
      hint: 'لا توجد سجلات حضور في الفترة المحددة',
    );
  }
}

/// مجموعة سجلات يوم واحد في تبويب السجل
class _DayGroup {
  final DateTime day;
  final List<dynamic> rows;

  const _DayGroup({required this.day, required this.rows});
}

/// مندوب ترويسة اليوم اللاصقة في قائمة السجل المجمّعة
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const _DayHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(height: height, child: child);
  }

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
