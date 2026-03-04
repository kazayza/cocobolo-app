import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
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
import '../services/permission_service.dart';

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

class _AttendanceReportScreenState extends State<AttendanceReportScreen> with TickerProviderStateMixin {
  List<dynamic> records = [];
  bool loading = true;

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
  
  // ✅ متغير الطي
  bool _isStatsExpanded = false;

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

  @override
  void initState() {
    super.initState();
    _loadLogo();

    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month, 1);
    toDate = now;

    if (!isManager) {
      searchQuery = PermissionService().fullName ?? widget.username ?? '';
    }

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
      _logoBytes = await rootBundle.load('assets/icons/app_icon.png').then((data) => data.buffer.asUint8List());
    } catch (e) {
      print('Error loading logo: $e');
    }
  }

  Future<void> fetchReport() async {
    if (!mounted) return;
    
    setState(() => loading = true);
    try {
      final queryParams = {
        'startDate': DateFormat('yyyy-MM-dd').format(fromDate),
        'endDate': DateFormat('yyyy-MM-dd').format(toDate),
        'userId': widget.userId.toString(),
        'role': PermissionService().role ?? 'User',
        if (searchQuery.isNotEmpty) 'employeeName': searchQuery,
      };

      final uri = Uri.parse('$baseUrl/api/attendance/report').replace(queryParameters: queryParams);
      final res = await http.get(uri);

      if (!mounted) return;

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          records = data;
          _calculateStats(data);
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _calculateStats(List<dynamic> data) {
    totalDays = data.length;
    lateDays = data.where((r) => (r['LateMinutes'] ?? 0) > 0).length;
    earlyLeaveDays = data.where((r) => (r['EarlyLeaveMinutes'] ?? 0) > 0).length;
    onTimeDays = data.where((r) => 
      (r['LateMinutes'] ?? 0) == 0 && (r['EarlyLeaveMinutes'] ?? 0) == 0 && r['TimeIn'] != null
    ).length;
    
    totalWorkHours = data.fold(0.0, (sum, item) => sum + (item['TotalHours'] ?? 0));
    averageHours = totalDays > 0 ? totalWorkHours / totalDays : 0;
    
    totalLateMinutes = data.fold(0.0, (sum, item) => sum + (item['LateMinutes'] ?? 0));
    totalEarlyMinutes = data.fold(0.0, (sum, item) => sum + (item['EarlyLeaveMinutes'] ?? 0));
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE8B923),
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1E1E1E),
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
        _showSnackBar('لا توجد بيانات للتصدير', Colors.orange);
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
        final date = DateTime.parse(item['LogDate']);
        sheetObject.appendRow([
          excel.TextCellValue(DateFormat('yyyy-MM-dd').format(date)),
          excel.TextCellValue(item['FullName'] ?? ''),
          excel.TextCellValue(item['TimeIn'] ?? '--:--'),
          excel.TextCellValue(item['TimeOut'] ?? '--:--'),
          excel.TextCellValue('${item['LateMinutes'] ?? 0}'),
          excel.TextCellValue('${item['EarlyLeaveMinutes'] ?? 0}'),
          excel.TextCellValue('${item['TotalHours']?.toStringAsFixed(1) ?? '0.0'}'),
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
      
      _showSnackBar('تم التصدير بنجاح', Colors.green);
    } catch (e) {
      _showSnackBar('حدث خطأ: $e', Colors.red);
    }
  }

  Future<void> _exportToPDF() async {
    try {
      if (records.isEmpty) {
        _showSnackBar('لا توجد بيانات للتصدير', Colors.orange);
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
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: ttf),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'COCOBOLO Furniture',
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.amber, font: ttf),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'الفترة: ${DateFormat('yyyy-MM-dd').format(fromDate)} إلى ${DateFormat('yyyy-MM-dd').format(toDate)}',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey, font: ttf),
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
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey, font: ttf),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.Text(
                      DateFormat('yyyy/MM/dd').format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: ttf),
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
                  _buildPdfStat('إجمالي الساعات', totalWorkHours.toStringAsFixed(1), ttf),
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
                  final date = DateTime.parse(item['LogDate']);
                  return pw.TableRow(
                    children: [
                      _buildTableCell(_getStatusText(item), ttf),
                      _buildTableCell(item['TimeOut'] ?? '--:--', ttf),
                      _buildTableCell(item['TimeIn'] ?? '--:--', ttf),
                      _buildTableCell(item['FullName']?.split(' ')[0] ?? '', ttf),
                      _buildTableCell(DateFormat('yyyy-MM-dd').format(date), ttf),
                    ],
                  );
                }).toList(),
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
              style: pw.TextStyle(color: PdfColors.grey, font: ttf, fontSize: 8),
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
      _showSnackBar('حدث خطأ: $e', Colors.red);
    }
  }

  pw.Widget _buildTableCell(String text, pw.Font font, {bool isHeader = false}) {
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
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font, fontSize: 12),
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
    final late = item['LateMinutes'] ?? 0;
    final early = item['EarlyLeaveMinutes'] ?? 0;
    if (late > 0) return 'تأخير $lateد';
    if (early > 0) return 'مبكر $earlyد';
    return 'منتظم';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ========== البناء الرئيسي ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
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
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8B923).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_rounded, color: Color(0xFFE8B923), size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'سجل الحضور',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A1A),
      centerTitle: false,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'excel') _exportToExcel();
            if (value == 'pdf') _exportToPDF();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'excel',
              child: Row(
                children: [
                  Icon(Icons.grid_on, color: Colors.green, size: 18),
                  SizedBox(width: 10),
                  Text('تصدير Excel', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                  SizedBox(width: 10),
                  Text('تصدير PDF', style: TextStyle(color: Colors.white)),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          if (isManager)
            TextField(
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ابحث عن موظف...',
                hintStyle: GoogleFonts.cairo(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE8B923), size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 16),
                        onPressed: () {
                          setState(() => searchQuery = '');
                          fetchReport();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: _onSearchChanged,
            )
          else 
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFFE8B923), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    PermissionService().fullName ?? '',
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRangeChip('يوم', 'daily', Icons.today),
                const SizedBox(width: 6),
                _buildRangeChip('أسبوع', 'weekly', Icons.weekend),
                const SizedBox(width: 6),
                _buildRangeChip('شهر', 'monthly', Icons.calendar_month),
                const SizedBox(width: 6),
                _buildRangeChip('مخصص', 'custom', Icons.date_range),
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
                icon: const Icon(Icons.refresh, color: Color(0xFFE8B923), size: 18),
                onPressed: fetchReport,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05),
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
    return GestureDetector(
      onTap: () => _setDateRange(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFE8B923).withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFE8B923)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFE8B923) : Colors.grey, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: isSelected ? const Color(0xFFE8B923) : Colors.white,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 9)),
            Text(
              DateFormat('yyyy/MM/dd').format(date),
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ الإحصائيات القابلة للطي
  Widget _buildStatsCards() {
    return Column(
      children: [
        // زر الطي/الفتح
        GestureDetector(
          onTap: () {
            setState(() {
              _isStatsExpanded = !_isStatsExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1A1A1A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Color(0xFFE8B923), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'الإحصائيات',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // إحصائيات مصغرة لما يكون مقفول
                    if (!_isStatsExpanded) ...[
                      _buildMiniStat('$totalDays يوم', Colors.blue),
                      const SizedBox(width: 6),
                      _buildMiniStat('$lateDays تأخير', Colors.orange),
                      const SizedBox(width: 6),
                      _buildMiniStat('$onTimeDays منتظم', Colors.green),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      _isStatsExpanded 
                          ? Icons.keyboard_arrow_up 
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xFFE8B923),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // الإحصائيات القابلة للطي
        AnimatedCrossFade(
          firstChild: Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF0F0F0F),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatCard('أيام العمل', '$totalDays', Icons.calendar_month, Colors.blue)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildStatCard('إجمالي الساعات', totalWorkHours.toStringAsFixed(1), Icons.timer, Colors.green)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('منتظم', '$onTimeDays', Icons.check_circle, Colors.green)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildStatCard('متأخر', '$lateDays', Icons.warning, Colors.orange)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildStatCard('مبكر', '$earlyLeaveDays', Icons.logout, Colors.red)),
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

  // إحصائية مصغرة
  Widget _buildMiniStat(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFE8B923),
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(text: 'السجل'),
          Tab(text: 'إحصائيات'),
          Tab(text: 'التأخير'),
          Tab(text: 'ملخص'),
        ],
        labelStyle: GoogleFonts.cairo(fontSize: 10),
        unselectedLabelColor: Colors.grey,
        labelColor: const Color(0xFFE8B923),
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

  // ✅ عرض السجلات مع إحصائيات قابلة للطي
  Widget _buildRecordsView() {
    return Column(
      children: [
        // الإحصائيات القابلة للطي
        _buildStatsCards(),
        
        // هيدر الجدول ثابت
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: const Color(0xFF2C2C2C),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('التاريخ', style: _headerStyle)),
              Expanded(flex: 2, child: Center(child: Text('حضور', style: _headerStyle))),
              Expanded(flex: 2, child: Center(child: Text('انصراف', style: _headerStyle))),
              Expanded(flex: 2, child: Center(child: Text('الحالة', style: _headerStyle))),
              if (isManager) Expanded(flex: 2, child: Center(child: Text('الموظف', style: _headerStyle))),
            ],
          ),
        ),
        
        // الجدول
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: records.length,
            separatorBuilder: (c, i) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              final item = records[index];
              return _buildDataRow(item, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(dynamic item, int index) {
    final lateMins = item['LateMinutes'] ?? 0;
    final earlyMins = item['EarlyLeaveMinutes'] ?? 0;
    final date = DateTime.parse(item['LogDate']);
    final dayName = DateFormat('EEE', 'ar').format(date);
    final dayNum = DateFormat('dd/MM').format(date);

    return Container(
      color: index % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.02),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$dayName $dayNum', 
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                item['TimeIn'] ?? '--:--',
                style: GoogleFonts.cairo(
                  color: lateMins > 0 ? Colors.redAccent : Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                item['TimeOut'] ?? '--:--',
                style: GoogleFonts.cairo(
                  color: earlyMins > 0 ? Colors.orange : Colors.white,
                  fontSize: 10, 
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(child: _buildStatusBadge(lateMins, earlyMins)),
          ),
          if (isManager)
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  item['FullName']?.split(' ')[0] ?? '',
                  style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 9),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms, delay: (index * 15).ms);
  }

  Widget _buildStatisticsView() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildStatSection('معدلات الأداء', [
          _buildStatRow('متوسط ساعات العمل اليومي', '${averageHours.toStringAsFixed(1)} ساعة', Colors.blue),
          _buildStatRow('إجمالي دقائق التأخير', '${totalLateMinutes.toStringAsFixed(0)} د', Colors.orange),
          _buildStatRow('إجمالي دقائق الانصراف المبكر', '${totalEarlyMinutes.toStringAsFixed(0)} د', Colors.red),
        ]),
        const SizedBox(height: 16),
        _buildStatSection('نسب مئوية', [
          _buildProgressRow('نسبة الحضور المنتظم', totalDays > 0 ? onTimeDays / totalDays : 0, Colors.green),
          _buildProgressRow('نسبة التأخير', totalDays > 0 ? lateDays / totalDays : 0, Colors.orange),
          _buildProgressRow('نسبة الانصراف المبكر', totalDays > 0 ? earlyLeaveDays / totalDays : 0, Colors.red),
        ]),
      ],
    );
  }

  Widget _buildLateAnalysisView() {
    final lateRecords = records.where((r) => (r['LateMinutes'] ?? 0) > 0).toList();
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'تحليل أيام التأخير',
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Expanded(
          child: lateRecords.isEmpty
              ? Center(child: Text('لا توجد أيام تأخير 🎉', style: GoogleFonts.cairo(color: Colors.grey)))
              : ListView.separated(
                  itemCount: lateRecords.length,
                  separatorBuilder: (c, i) => const Divider(color: Colors.white10),
                  itemBuilder: (c, i) {
                    final item = lateRecords[i];
                    final date = DateTime.parse(item['LogDate']);
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.red.withOpacity(0.1),
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.red, fontSize: 10)),
                      ),
                      title: Text(
                        DateFormat('yyyy-MM-dd').format(date),
                        style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                      ),
                      subtitle: Text(
                        item['FullName'] ?? '',
                        style: GoogleFonts.cairo(color: Colors.grey, fontSize: 10),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item['LateMinutes']} د',
                          style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
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
              _buildCircularStat('أيام', totalDays.toString(), Icons.calendar_month, Colors.blue),
              _buildCircularStat('ساعات', totalWorkHours.toStringAsFixed(0), Icons.timer, Colors.green),
              _buildCircularStat('نسبة', '${totalDays > 0 ? ((onTimeDays / totalDays) * 100).toStringAsFixed(0) : '0'}%', Icons.percent, Colors.orange),
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
              _buildSummaryBox('تأخير', lateDays.toString(), Icons.warning_amber, Colors.red),
              _buildSummaryBox('مبكر', earlyLeaveDays.toString(), Icons.logout, Colors.orange),
              _buildSummaryBox('دقائق تأخير', totalLateMinutes.toStringAsFixed(0), Icons.timer_off, Colors.red.shade700),
              _buildSummaryBox('دقائق مبكر', totalEarlyMinutes.toStringAsFixed(0), Icons.timer, Colors.orange.shade700),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 8),
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

  Widget _buildCircularStat(String label, String value, IconData icon, Color color) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(color: Colors.grey, fontSize: 7),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.cairo(color: const Color(0xFFE8B923), fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 11)),
          Text(value, style: GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, double progress, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 11)),
              Text('${(progress * 100).toStringAsFixed(1)}%', style: GoogleFonts.cairo(color: color, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(int late, int early) {
    if (late > 0) {
      return _badge('تأخير $late', Colors.red.withOpacity(0.2), Colors.red);
    } else if (early > 0) {
      return _badge('مبكر $early', Colors.orange.withOpacity(0.2), Colors.orange);
    } else {
      return _badge('منتظم', Colors.green.withOpacity(0.2), Colors.green);
    }
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(color: fg, fontSize: 7, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        maxLines: 1,
      ),
    );
  }

  TextStyle get _headerStyle {
    return GoogleFonts.cairo(
      color: Colors.grey[400], 
      fontSize: 10, 
      fontWeight: FontWeight.bold
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFE8B923)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_rows_rounded, size: 40, color: Colors.grey[800]),
          const SizedBox(height: 8),
          Text('لا توجد بيانات', style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}