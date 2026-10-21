import 'dart:io';
import 'dart:math' as math;

import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/app_colors.dart';
import '../services/executive_cockpit_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_states.dart';

class ExecutiveCockpitScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ExecutiveCockpitScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ExecutiveCockpitScreen> createState() => _ExecutiveCockpitScreenState();
}

class _ExecutiveCockpitScreenState extends State<ExecutiveCockpitScreen> {
  final ExecutiveCockpitService _service = ExecutiveCockpitService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  String _period = 'month';
  String _employeeFilter = 'all';

  bool get _isDark => ThemeService().isDarkMode;
  Map<String, dynamic> get _capabilities => _map(_data?['Capabilities']);
  bool _can(String key) => _capabilities[key] == true;

  static const Map<String, String> _periods = <String, String>{
    'today': 'اليوم',
    'week': 'الأسبوع',
    'month': 'الشهر',
    'quarter': 'ربع السنة',
    'year': 'السنة',
  };

  static const Map<String, String> _employeeFilters = <String, String>{
    'all': 'الكل',
    'green': 'نشط',
    'yellow': 'نشاط قليل',
    'red': 'ساكن',
    'off': 'موقوف أو إجازة',
    'gray': 'بلا حساب',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getCockpit(period: _period);
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _setPeriod(String value) async {
    if (_period == value) return;
    setState(() => _period = value);
    await _load();
  }

  List<Map<String, dynamic>> get _employees {
    final rows = _list(_data?['Employees']);
    if (_employeeFilter == 'all') return rows;
    return rows.where((row) => row['Status'] == _employeeFilter).toList();
  }

  List<Map<String, dynamic>> get _salesEmployees => _list(_data?['Employees'])
      .where((row) => row['IsSales'] == true && row['Status'] != 'off')
      .toList()
    ..sort((a, b) => _num(b['MonthSales']).compareTo(_num(a['MonthSales'])));

  Future<void> _openTimeline(Map<String, dynamic> employee) async {
    final id = _int(employee['EmployeeId']);
    if (id <= 0 || !_can('canViewEmployeeTimeline')) return;
    var loading = true;
    String? error;
    List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(_isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) {
          if (loading) {
            _service.getEmployeeTimeline(id).then((value) {
              if (!sheetContext.mounted) return;
              setSheetState(() {
                rows = value;
                loading = false;
              });
            }).catchError((Object value) {
              if (!sheetContext.mounted) return;
              setSheetState(() {
                error = value.toString();
                loading = false;
              });
            });
          }
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.70,
            maxChildSize: 0.94,
            builder: (_, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(18),
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider(_isDark),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Row(children: [
                  const Icon(Icons.timeline_rounded, color: AppColors.goldDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${employee['FullName'] ?? ''} — ${employee['JobTitle'] ?? ''}',
                      style: GoogleFonts.cairo(
                        color: AppColors.text(_isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (error != null)
                  AppError(message: error!, onRetry: () {})
                else if (rows.isEmpty)
                  const AppEmpty(
                    message: 'لا يوجد نشاط مسجل لهذا الموظف',
                    icon: Icons.timeline_rounded,
                  )
                else
                  for (final row in rows) _timelineRow(row),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _timelineRow(Map<String, dynamic> row) {
    final invoice = row['Kind'] == 'invoice';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color:
            (invoice ? AppColors.info : AppColors.gold).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(invoice ? Icons.receipt_long_rounded : Icons.history_rounded,
            color: invoice ? AppColors.info : AppColors.goldDark, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${row['What'] ?? 'إجراء'}',
                style: GoogleFonts.cairo(
                    color: AppColors.text(_isDark),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5)),
            Text(_dateTime(row['When']),
                style: GoogleFonts.cairo(
                    color: AppColors.textSecondary(_isDark), fontSize: 9.5)),
          ]),
        ),
      ]),
    );
  }

  Future<void> _exportExcel() async {
    if (_exporting || !_can('canExport')) return;
    setState(() => _exporting = true);
    try {
      final workbook = excel.Excel.createExcel();
      if (workbook.sheets.containsKey('Sheet1')) workbook.delete('Sheet1');
      final summary = workbook['الملخص التنفيذي'];
      summary.appendRow(<excel.CellValue>[
        excel.TextCellValue('المؤشر'),
        excel.TextCellValue('الحالي'),
        excel.TextCellValue('السابق'),
        excel.TextCellValue('سنويًا'),
        excel.TextCellValue('% السابق'),
        excel.TextCellValue('% سنوي'),
      ]);
      for (final entry in _kpiRows()) {
        final value = _map(entry['data']);
        summary.appendRow(<excel.CellValue>[
          excel.TextCellValue('${entry['label']}'),
          excel.DoubleCellValue(_num(value['Value'])),
          excel.DoubleCellValue(_num(value['PrevValue'])),
          excel.DoubleCellValue(_num(value['YearValue'])),
          excel.DoubleCellValue(_num(value['PrevPct'])),
          excel.DoubleCellValue(_num(value['YearPct'])),
        ]);
      }
      final employees = workbook['فريق العمل'];
      employees.appendRow(<excel.CellValue>[
        excel.TextCellValue('الموظف'),
        excel.TextCellValue('الوظيفة'),
        excel.TextCellValue('الحضور'),
        excel.IntCellValue(0),
        excel.TextCellValue('إجراءات الشهر'),
        excel.TextCellValue('آخر نشاط'),
        excel.TextCellValue('مبيعات الشهر'),
        excel.TextCellValue('تحصيل الشهر'),
        excel.TextCellValue('مهام معلقة'),
        excel.TextCellValue('مهام متأخرة'),
        excel.TextCellValue('الحالة'),
      ]);
      employees
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0))
          .value = excel.TextCellValue('إجراءات اليوم');
      for (final row in _list(_data?['Employees'])) {
        employees.appendRow(<excel.CellValue>[
          excel.TextCellValue('${row['FullName'] ?? ''}'),
          excel.TextCellValue('${row['JobTitle'] ?? ''}'),
          excel.TextCellValue('${row['Attendance'] ?? ''}'),
          excel.IntCellValue(_int(row['ActionsToday'])),
          excel.IntCellValue(_int(row['ActionsMonth'])),
          excel.TextCellValue('${row['LastActivityText'] ?? ''}'),
          excel.DoubleCellValue(_num(row['MonthSales'])),
          excel.DoubleCellValue(_num(row['MonthCollection'])),
          excel.IntCellValue(_int(row['TasksPending'])),
          excel.IntCellValue(_int(row['TasksOverdue'])),
          excel.TextCellValue(_statusLabel('${row['Status'] ?? ''}')),
        ]);
      }
      final branches = workbook['مبيعات الفروع'];
      branches.appendRow(<excel.CellValue>[
        excel.TextCellValue('الفرع'),
        excel.TextCellValue('المبيعات'),
      ]);
      for (final row in _list(_data?['BranchSales'])) {
        branches.appendRow(<excel.CellValue>[
          excel.TextCellValue('${row['Name'] ?? ''}'),
          excel.DoubleCellValue(_num(row['Value'])),
        ]);
      }
      final bytes = workbook.save();
      if (bytes == null) throw StateError('تعذر إنشاء ملف Excel');
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/Executive_Cockpit_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: <XFile>[
          XFile(file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
        ],
        text: 'لوحة القيادة التنفيذية — ${_data?['PeriodLabel'] ?? ''}',
      ));
    } catch (error) {
      if (mounted) _message('تعذر تصدير Excel: $error', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_exporting || !_can('canExport')) return;
    setState(() => _exporting = true);
    try {
      final regularData =
          await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      final regular = pw.Font.ttf(regularData);
      final bold = pw.Font.ttf(boldData);
      final document = pw.Document();
      document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (_) => pw.Column(children: [
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('لوحة القيادة التنفيذية',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 19,
                        color: const PdfColor.fromInt(0xFF13273F))),
                pw.Text('${_data?['PeriodLabel'] ?? ''}',
                    style: pw.TextStyle(font: bold, fontSize: 11)),
              ]),
          pw.Divider(color: const PdfColor.fromInt(0xFFDBBF74), thickness: 1.5),
        ]),
        build: (_) => <pw.Widget>[
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF4F0E5),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text('${_data?['Story'] ?? ''}',
                style: pw.TextStyle(font: regular, fontSize: 9)),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: <String>['المؤشر', 'الحالي', '% السابق', '% سنوي'],
            data: _kpiRows().map((entry) {
              final value = _map(entry['data']);
              return <String>[
                '${entry['label']}',
                _money(value['Value']),
                '${_num(value['PrevPct']).toStringAsFixed(1)}%',
                '${_num(value['YearPct']).toStringAsFixed(1)}%',
              ];
            }).toList(),
            headerStyle:
                pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF13273F)),
            cellStyle: pw.TextStyle(font: regular, fontSize: 8),
            cellAlignment: pw.Alignment.centerRight,
          ),
          pw.SizedBox(height: 14),
          pw.Text('الاستثناءات', style: pw.TextStyle(font: bold, fontSize: 12)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: <String>['البند', 'العدد / القيمة'],
            data: _exceptionRows()
                .map((row) => <String>[
                      '${row['label']}',
                      '${row['value']}',
                    ])
                .toList(),
            headerStyle:
                pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF8B2635)),
            cellStyle: pw.TextStyle(font: regular, fontSize: 8),
          ),
          pw.SizedBox(height: 14),
          pw.Text('أعلى المبيعات هذا الشهر',
              style: pw.TextStyle(font: bold, fontSize: 12)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: <String>['الموظف', 'الوظيفة', 'المبيعات', 'التحصيل'],
            data: _salesEmployees
                .take(10)
                .map((row) => <String>[
                      '${row['FullName'] ?? ''}',
                      '${row['JobTitle'] ?? ''}',
                      _money(row['MonthSales']),
                      _money(row['MonthCollection']),
                    ])
                .toList(),
            headerStyle:
                pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF13273F)),
            cellStyle: pw.TextStyle(font: regular, fontSize: 8),
          ),
        ],
        footer: (_) => pw.Center(
          child: pw.Text(
            'بيانات لحظية من نظام COCOBOLO — ${_dateTime(_data?['GeneratedAt'])}',
            style: pw.TextStyle(
                font: regular, fontSize: 7, color: PdfColors.grey600),
          ),
        ),
      ));
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/Executive_Cockpit_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
      await file.writeAsBytes(await document.save(), flush: true);
      await SharePlus.instance.share(ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
        text: 'لوحة القيادة التنفيذية — ${_data?['PeriodLabel'] ?? ''}',
      ));
    } catch (error) {
      if (mounted) _message('تعذر إنشاء PDF: $error', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: GoogleFonts.cairo()),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Text('لوحة القيادة التنفيذية',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        actions: [
          if (_data != null && _can('canExport'))
            PopupMenuButton<String>(
              tooltip: 'تصدير',
              icon: const Icon(Icons.ios_share_rounded),
              onSelected: (value) {
                if (value == 'pdf') _exportPdf();
                if (value == 'excel') _exportExcel();
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_rounded),
                    title: Text('PDF', style: GoogleFonts.cairo()),
                  ),
                ),
                PopupMenuItem(
                  value: 'excel',
                  child: ListTile(
                    leading: const Icon(Icons.table_chart_rounded),
                    title: Text('Excel', style: GoogleFonts.cairo()),
                  ),
                ),
              ],
            ),
          IconButton(
            onPressed: _exporting ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Stack(children: [
        if (_loading)
          const AppLoading(message: 'جاري تجهيز لوحة القيادة التنفيذية')
        else if (_error != null)
          AppError(message: _error!, onRetry: _load)
        else if (_data == null)
          AppEmpty(
            message: 'لا توجد بيانات تنفيذية',
            icon: Icons.workspace_premium_outlined,
            onRefresh: _load,
          )
        else
          RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(slivers: <Widget>[
              SliverToBoxAdapter(child: _hero()),
              SliverToBoxAdapter(child: _story()),
              SliverToBoxAdapter(child: _sectionTitle('نبض الشركة')),
              SliverToBoxAdapter(child: _kpiGrid()),
              SliverToBoxAdapter(child: _pipeline()),
              SliverToBoxAdapter(child: _sectionTitle('الاتجاهات والتوقعات')),
              SliverToBoxAdapter(child: _trendAndForecast()),
              SliverToBoxAdapter(child: _sectionTitle('الفروع والنشاط')),
              SliverToBoxAdapter(child: _branchesAndActivity()),
              SliverToBoxAdapter(child: _sectionTitle('لوحة الشرف — المبيعات')),
              SliverToBoxAdapter(child: _leaderboard()),
              SliverToBoxAdapter(child: _sectionTitle('فريق العمل')),
              SliverToBoxAdapter(child: _employeeFiltersWidget()),
              SliverList.builder(
                itemCount: _employees.length,
                itemBuilder: (_, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _employeeCard(_employees[index]),
                ),
              ),
              SliverToBoxAdapter(child: _sectionTitle('لوحة المدير العام')),
              SliverToBoxAdapter(child: _generalManager()),
              SliverToBoxAdapter(
                  child: _sectionTitle('استثناءات تحتاج قرارًا')),
              SliverToBoxAdapter(child: _exceptions()),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ]),
          ),
        if (_exporting)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.28),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ]),
    );
  }

  Widget _hero() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            AppColors.navyDark,
            AppColors.navy,
            AppColors.navyLight
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.38)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: AppColors.gold, size: 29),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('القرار في شاشة واحدة',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              Text(
                'آخر تحديث ${DateFormat('hh:mm a').format(DateTime.tryParse('${_data?['GeneratedAt'] ?? ''}') ?? DateTime.now())}',
                style: GoogleFonts.cairo(color: Colors.white60, fontSize: 10),
              ),
            ]),
          ),
          if (_int(_data?['DecisionsPending']) > 0)
            _badge('${_int(_data?['DecisionsPending'])} قرار', AppColors.error),
        ]),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _periods.entries.map((entry) {
              final selected = _period == entry.key;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 7),
                child: ChoiceChip(
                  selected: selected,
                  label: Text(entry.value,
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: selected ? AppColors.navyDark : Colors.white70,
                          fontWeight: FontWeight.w700)),
                  selectedColor: AppColors.gold,
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  side: BorderSide(
                      color: selected ? AppColors.gold : Colors.white12),
                  onSelected: (_) => _setPeriod(entry.key),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _story() => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: _isDark ? 0.10 : 0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.bolt_rounded, color: AppColors.goldDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${_data?['Story'] ?? ''}',
                style: GoogleFonts.cairo(
                    color: AppColors.text(_isDark),
                    fontSize: 11.5,
                    height: 1.55,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 15, 14, 8),
        child: Row(children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.cairo(
                  color: AppColors.text(_isDark),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900)),
        ]),
      );

  List<Map<String, dynamic>> _kpiRows() => <Map<String, dynamic>>[
        {
          'label': 'المبيعات',
          'icon': Icons.paid_rounded,
          'color': AppColors.success,
          'data': _data?['Sales'],
          'invert': false
        },
        {
          'label': 'المحصّل',
          'icon': Icons.account_balance_rounded,
          'color': AppColors.info,
          'data': _data?['Collected'],
          'invert': false
        },
        {
          'label': 'المشتريات',
          'icon': Icons.local_shipping_rounded,
          'color': AppColors.warning,
          'data': _data?['Purchases'],
          'invert': true
        },
        {
          'label': 'المصروفات',
          'icon': Icons.receipt_long_rounded,
          'color': AppColors.error,
          'data': _data?['Expenses'],
          'invert': true
        },
        {
          'label': 'صافي التدفق',
          'icon': Icons.currency_exchange_rounded,
          'color': Colors.purple,
          'data': _data?['Net'],
          'invert': false
        },
        {
          'label': 'رصيد الخزائن',
          'icon': Icons.savings_rounded,
          'color': AppColors.goldDark,
          'data': {'Value': _data?['CashBalance']},
          'invert': false,
          'instant': true
        },
      ];

  Widget _kpiGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(builder: (_, constraints) {
        final width = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 20) / 3
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _kpiRows().map((item) => _kpiCard(item, width)).toList(),
        );
      }),
    );
  }

  Widget _kpiCard(Map<String, dynamic> item, double width) {
    final data = _map(item['data']);
    final color = item['color'] as Color;
    final previousPct = _num(data['PrevPct']);
    final annualPct = _num(data['YearPct']);
    final invert = item['invert'] == true;
    final instant = item['instant'] == true;
    return Container(
      width: width,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.27)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(item['icon'] as IconData, color: color, size: 19),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${item['label']}',
                style: GoogleFonts.cairo(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(_money(data['Value']),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
                color: AppColors.text(_isDark),
                fontSize: 17,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        if (instant)
          Text('الرصيد اللحظي لكل الخزن',
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark), fontSize: 8.5))
        else
          Wrap(spacing: 5, runSpacing: 4, children: [
            _comparison(previousPct, invert, 'السابق'),
            _comparison(annualPct, invert, 'سنوي'),
          ]),
      ]),
    );
  }

  Widget _comparison(double pct, bool invert, String caption) {
    final good = invert ? pct <= 0 : pct >= 0;
    final color = pct == 0
        ? AppColors.neutral
        : good
            ? AppColors.success
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
            pct > 0
                ? Icons.arrow_upward_rounded
                : pct < 0
                    ? Icons.arrow_downward_rounded
                    : Icons.remove_rounded,
            color: color,
            size: 11),
        const SizedBox(width: 2),
        Text('${pct.abs().toStringAsFixed(1)}% $caption',
            style: GoogleFonts.cairo(
                color: color, fontSize: 7.8, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _pipeline() {
    final rows = <Map<String, dynamic>>[
      {
        'label': 'فرص مفتوحة',
        'value': '${_int(_data?['PipelineOpen'])}',
        'icon': Icons.business_center_rounded,
        'color': AppColors.info
      },
      {
        'label': 'قيمة متوقعة',
        'value': _money(_data?['PipelineValue']),
        'icon': Icons.trending_up_rounded,
        'color': AppColors.success
      },
      {
        'label': 'متابعة فرص متأخرة',
        'value': '${_int(_data?['PipelineStalled'])}',
        'icon': Icons.schedule_rounded,
        'color': AppColors.warning
      },
      {
        'label': 'طلبات B2B معلقة',
        'value': '${_int(_data?['B2bPending'])}',
        'icon': Icons.business_rounded,
        'color': Colors.purple
      },
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: LayoutBuilder(builder: (_, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rows.map((row) {
            final color = row['color'] as Color;
            return Container(
              width: width,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.card(_isDark),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color.withValues(alpha: 0.23)),
              ),
              child: Row(children: [
                Icon(row['icon'] as IconData, color: color, size: 19),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${row['value']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                                color: AppColors.text(_isDark),
                                fontSize: 13,
                                fontWeight: FontWeight.w900)),
                        Text('${row['label']}',
                            maxLines: 1,
                            style: GoogleFonts.cairo(
                                color: AppColors.textSecondary(_isDark),
                                fontSize: 8.5)),
                      ]),
                ),
              ]),
            );
          }).toList(),
        );
      }),
    );
  }

  Widget _trendAndForecast() {
    final trend = _list(_data?['Trend']);
    final maxValue = trend.fold<double>(
        1,
        (value, row) => math.max(
            value,
            math.max(_num(row['Sales']),
                math.max(_num(row['Collected']), _num(row['Purchases'])))));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Container(
          height: 265,
          padding: const EdgeInsets.fromLTRB(8, 15, 8, 8),
          decoration: BoxDecoration(
            color: AppColors.card(_isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider(_isDark)),
          ),
          child: Column(children: [
            Row(children: [
              _legend(AppColors.goldDark, 'المبيعات'),
              _legend(AppColors.success, 'المحصّل'),
              _legend(AppColors.info, 'المشتريات'),
            ]),
            const SizedBox(height: 10),
            Expanded(
              child: CustomPaint(
                painter: _ExecutiveTrendPainter(
                  rows: trend,
                  maxValue: maxValue,
                  isDark: _isDark,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card(_isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _forecastColor().withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.insights_rounded, color: _forecastColor()),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('توقع إقفال الشهر',
                        style: GoogleFonts.cairo(
                            color: AppColors.textSecondary(_isDark),
                            fontSize: 10)),
                    Text(_money(_data?['ForecastValue']),
                        style: GoogleFonts.cairo(
                            color: AppColors.text(_isDark),
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    Text('الشهر السابق: ${_money(_data?['LastMonthSales'])}',
                        style: GoogleFonts.cairo(
                            color: AppColors.textSecondary(_isDark),
                            fontSize: 9)),
                  ]),
            ),
            _badge(
              '${_num(_data?['ForecastVsLastPct']) >= 0 ? '+' : ''}${_num(_data?['ForecastVsLastPct']).toStringAsFixed(1)}%',
              _forecastColor(),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _legend(Color color, String label) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark), fontSize: 9)),
        ]),
      );

  Color _forecastColor() {
    final pct = _num(_data?['ForecastVsLastPct']);
    return pct >= 0
        ? AppColors.success
        : pct >= -15
            ? AppColors.warning
            : AppColors.error;
  }

  Widget _branchesAndActivity() {
    final branches = _list(_data?['BranchSales']);
    final employees = [..._list(_data?['Employees'])]..sort(
        (a, b) => _int(b['ActionsMonth']).compareTo(_int(a['ActionsMonth'])));
    final maxBranch = branches.fold<double>(
        1, (value, row) => math.max(value, _num(row['Value'])));
    final maxActions = employees.fold<int>(
        1, (value, row) => math.max(value, _int(row['ActionsMonth'])));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        _rankCard(
          title: 'مبيعات الفروع',
          icon: Icons.store_rounded,
          rows: branches
              .take(8)
              .map((row) => <String, dynamic>{
                    'label': row['Name'],
                    'value': _money(row['Value']),
                    'ratio': _num(row['Value']) / maxBranch,
                    'color': AppColors.info,
                  })
              .toList(),
        ),
        const SizedBox(height: 9),
        _rankCard(
          title: 'الأكثر إجراءً في النظام — 30 يومًا',
          icon: Icons.bar_chart_rounded,
          rows: employees
              .take(8)
              .map((row) => <String, dynamic>{
                    'label': row['FullName'],
                    'value': '${_int(row['ActionsMonth'])}',
                    'ratio': _int(row['ActionsMonth']) / maxActions,
                    'color': AppColors.goldDark,
                  })
              .toList(),
        ),
      ]),
    );
  }

  Widget _rankCard({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppColors.goldDark, size: 19),
          const SizedBox(width: 7),
          Text(title,
              style: GoogleFonts.cairo(
                  color: AppColors.text(_isDark),
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Text('لا توجد بيانات في هذه الفترة',
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark), fontSize: 10))
        else
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Text('${row['label'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                            color: AppColors.text(_isDark),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ),
                  Text('${row['value'] ?? ''}',
                      style: GoogleFonts.cairo(
                          color: AppColors.text(_isDark),
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: (_num(row['ratio'])).clamp(0, 1),
                    minHeight: 5,
                    color: row['color'] as Color,
                    backgroundColor: AppColors.divider(_isDark),
                  ),
                ),
              ]),
            ),
      ]),
    );
  }

  Widget _leaderboard() {
    final top = _salesEmployees.take(3).toList();
    final bottom = [..._salesEmployees]
      ..sort((a, b) => _num(a['MonthSales']).compareTo(_num(b['MonthSales'])));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        _leaderGroup('الأعلى إنتاجًا', top, AppColors.goldDark,
            Icons.emoji_events_rounded),
        const SizedBox(height: 9),
        _leaderGroup('يحتاجون متابعة', bottom.take(3).toList(), AppColors.error,
            Icons.warning_amber_rounded),
      ]),
    );
  }

  Widget _leaderGroup(String title, List<Map<String, dynamic>> rows,
      Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(children: [
        Row(children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 7),
          Text(title,
              style: GoogleFonts.cairo(
                  color: AppColors.text(_isDark),
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text('لا توجد بيانات مبيعات هذا الشهر',
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark), fontSize: 10))
        else
          for (var index = 0; index < rows.length; index++)
            InkWell(
              onTap: () => _openTimeline(rows[index]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Text('${index + 1}',
                        style: GoogleFonts.cairo(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${rows[index]['FullName'] ?? ''}',
                              style: GoogleFonts.cairo(
                                  color: AppColors.text(_isDark),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          Text('${rows[index]['JobTitle'] ?? ''}',
                              style: GoogleFonts.cairo(
                                  color: AppColors.textSecondary(_isDark),
                                  fontSize: 8.5)),
                        ]),
                  ),
                  Text(_money(rows[index]['MonthSales']),
                      style: GoogleFonts.cairo(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
      ]),
    );
  }

  Widget _employeeFiltersWidget() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          children: _employeeFilters.entries.map((entry) {
            final selected = _employeeFilter == entry.key;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                selected: selected,
                avatar: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor(entry.key),
                    shape: BoxShape.circle,
                  ),
                ),
                label:
                    Text(entry.value, style: GoogleFonts.cairo(fontSize: 9.5)),
                onSelected: (_) => setState(() => _employeeFilter = entry.key),
              ),
            );
          }).toList(),
        ),
      );

  Widget _employeeCard(Map<String, dynamic> employee) {
    final status = '${employee['Status'] ?? 'gray'}';
    final color = _statusColor(status);
    final heat = (employee['Heat7'] as List? ?? const <dynamic>[])
        .map((value) => _int(value))
        .toList();
    return InkWell(
      onTap: () => _openTimeline(employee),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card(_isDark),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: 0.27)),
        ),
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(
                _initial('${employee['FullName'] ?? ''}'),
                style: GoogleFonts.cairo(
                    color: color, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${employee['FullName'] ?? ''}',
                        style: GoogleFonts.cairo(
                            color: AppColors.text(_isDark),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800)),
                    Text('${employee['JobTitle'] ?? '—'}',
                        style: GoogleFonts.cairo(
                            color: AppColors.textSecondary(_isDark),
                            fontSize: 9)),
                  ]),
            ),
            _badge(_statusLabel(status), color),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            _employeeMetric('الحضور', '${employee['Attendance'] ?? '—'}'),
            _employeeMetric(
                'إجراءات اليوم', '${_int(employee['ActionsToday'])}'),
            _employeeMetric(
                'إنتاج الشهر',
                employee['IsSales'] == true
                    ? _money(employee['MonthSales'])
                    : '—'),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            Text('نشاط 7 أيام',
                style: GoogleFonts.cairo(
                    color: AppColors.textSecondary(_isDark), fontSize: 8.5)),
            const SizedBox(width: 7),
            if (status == 'off' || status == 'gray')
              Text('—', style: GoogleFonts.cairo(color: AppColors.neutral))
            else
              ...heat.map((count) => Container(
                    width: 13,
                    height: 13,
                    margin: const EdgeInsetsDirectional.only(end: 3),
                    decoration: BoxDecoration(
                      color: _heatColor(count),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
            const Spacer(),
            Text('${employee['LastActivityText'] ?? ''}',
                style: GoogleFonts.cairo(
                    color: status == 'red'
                        ? AppColors.error
                        : AppColors.textSecondary(_isDark),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700)),
          ]),
          if (_int(employee['TasksOverdue']) > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _badge(
                '${_int(employee['TasksPending'])} مهمة — ${_int(employee['TasksOverdue'])} متأخرة',
                AppColors.error,
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _employeeMetric(String label, String value) => Expanded(
        child: Column(children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                  color: AppColors.text(_isDark),
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark), fontSize: 7.8)),
        ]),
      );

  Widget _generalManager() {
    final gm = _map(_data?['Gm']);
    final ops = _map(_data?['Ops']);
    final recent = _list(gm['Recent']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.card(_isDark),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.gavel_rounded, color: AppColors.goldDark),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  gm['Found'] == true
                      ? '${gm['FullName'] ?? ''} — ${gm['LastActivityText'] ?? ''}'
                      : 'لم يتم التعرف على المدير العام من المسمى الوظيفي',
                  style: GoogleFonts.cairo(
                      color: AppColors.text(_isDark),
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ]),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 9),
              for (final row in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(children: [
                    SizedBox(
                      width: 75,
                      child: Text('${row['When'] ?? ''}',
                          style: GoogleFonts.cairo(
                              color: AppColors.textSecondary(_isDark),
                              fontSize: 8.5)),
                    ),
                    Expanded(
                      child: Text('${row['What'] ?? ''}',
                          style: GoogleFonts.cairo(
                              color: AppColors.text(_isDark), fontSize: 9.5)),
                    ),
                  ]),
                ),
            ],
          ]),
        ),
        const SizedBox(height: 9),
        LayoutBuilder(builder: (_, constraints) {
          final width = (constraints.maxWidth - 8) / 2;
          final rows = <Map<String, dynamic>>[
            {
              'label': 'طلبات أسعار معلقة',
              'value': gm['PendingPrice'],
              'icon': Icons.price_change_rounded,
              'color': AppColors.warning
            },
            {
              'label': 'شكاوى مصعّدة',
              'value': gm['EscalatedComplaints'],
              'icon': Icons.report_problem_rounded,
              'color': AppColors.error
            },
            {
              'label': 'نشطون اليوم',
              'value':
                  '${_int(gm['TeamActiveToday'])}/${_int(gm['TeamTotal'])}',
              'icon': Icons.groups_rounded,
              'color': AppColors.success
            },
            {
              'label': 'أوامر مصنع مفتوحة',
              'value': ops['FactoryOpen'],
              'icon': Icons.factory_rounded,
              'color': AppColors.info
            },
            {
              'label': 'استلامات المصنع',
              'value': ops['FactoryMonth'],
              'icon': Icons.inventory_rounded,
              'color': AppColors.success
            },
            {
              'label': 'Leads جديدة',
              'value': ops['NewLeads'],
              'icon': Icons.person_add_alt_1_rounded,
              'color': Colors.purple
            },
          ];
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rows.map((row) => _smallMetric(row, width)).toList(),
          );
        }),
      ]),
    );
  }

  Widget _smallMetric(Map<String, dynamic> row, double width) {
    final color = row['color'] as Color;
    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(children: [
        Icon(row['icon'] as IconData, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${row['value'] ?? 0}',
                style: GoogleFonts.cairo(
                    color: AppColors.text(_isDark),
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
            Text('${row['label'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    color: AppColors.textSecondary(_isDark), fontSize: 8)),
          ]),
        ),
      ]),
    );
  }

  List<Map<String, dynamic>> _exceptionRows() {
    final values = _map(_data?['Exceptions']);
    return <Map<String, dynamic>>[
      {
        'label': 'مديونات أكثر من 30 يومًا',
        'value':
            '${_int(values['Debts30'])} — ${_money(values['Debts30Amount'])}',
        'count': values['Debts30'],
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.error
      },
      {
        'label': 'تسليمات متأخرة',
        'value': '${_int(values['LateDeliveries'])}',
        'count': values['LateDeliveries'],
        'icon': Icons.local_shipping_rounded,
        'color': AppColors.error
      },
      {
        'label': 'طلبات أسعار معلقة',
        'value': '${_int(values['PendingPrice'])}',
        'count': values['PendingPrice'],
        'icon': Icons.price_change_rounded,
        'color': AppColors.warning
      },
      {
        'label': 'أصناف برصيد سالب',
        'value': '${_int(values['NegativeStock'])}',
        'count': values['NegativeStock'],
        'icon': Icons.inventory_2_rounded,
        'color': AppColors.warning
      },
      {
        'label': 'Leads بلا متابعة',
        'value': '${_int(values['StalledLeads'])}',
        'count': values['StalledLeads'],
        'icon': Icons.person_off_rounded,
        'color': AppColors.info
      },
      {
        'label': 'شكاوى مفتوحة',
        'value': '${_int(values['OpenComplaints'])}',
        'count': values['OpenComplaints'],
        'icon': Icons.report_problem_rounded,
        'color': Colors.purple
      },
    ];
  }

  Widget _exceptions() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: LayoutBuilder(builder: (_, constraints) {
          final width = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _exceptionRows().map((row) {
              final color = row['color'] as Color;
              return Container(
                width: width,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: _isDark ? 0.10 : 0.07),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: color.withValues(alpha: 0.30)),
                ),
                child: Row(children: [
                  Icon(row['icon'] as IconData, color: color, size: 21),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${row['value']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900)),
                          Text('${row['label']}',
                              maxLines: 2,
                              style: GoogleFonts.cairo(
                                  color: AppColors.text(_isDark),
                                  fontSize: 8.5)),
                        ]),
                  ),
                ]),
              );
            }).toList(),
          );
        }),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: GoogleFonts.cairo(
                color: color, fontSize: 8.5, fontWeight: FontWeight.w800)),
      );

  Color _statusColor(String status) => switch (status) {
        'green' => AppColors.success,
        'yellow' => AppColors.warning,
        'red' => AppColors.error,
        'off' => AppColors.neutral,
        _ => Colors.blueGrey,
      };

  String _statusLabel(String status) => switch (status) {
        'green' => 'نشط',
        'yellow' => 'نشاط قليل',
        'red' => 'ساكن',
        'off' => 'موقوف أو إجازة',
        _ => 'بلا حساب',
      };

  Color _heatColor(int count) {
    if (count <= 0) return AppColors.error.withValues(alpha: 0.50);
    if (count <= 2) return AppColors.warning.withValues(alpha: 0.50);
    if (count <= 4) return AppColors.success.withValues(alpha: 0.45);
    return AppColors.success;
  }

  String _initial(String value) {
    final text = value.trim();
    return text.isEmpty ? '—' : text.characters.first;
  }

  String _money(dynamic value) =>
      '${NumberFormat('#,##0').format(_num(value))} ج.م';

  String _dateTime(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? '—' : DateFormat('yyyy/MM/dd HH:mm').format(date);
  }
}

class _ExecutiveTrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> rows;
  final double maxValue;
  final bool isDark;

  const _ExecutiveTrendPainter({
    required this.rows,
    required this.maxValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rows.isEmpty || size.width <= 0 || size.height <= 0) return;
    const left = 8.0;
    const right = 8.0;
    const top = 6.0;
    const bottom = 28.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : AppColors.navy).withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = top + chartHeight * index / 4;
      canvas.drawLine(
          Offset(left, y), Offset(size.width - right, y), gridPaint);
    }
    final series = <(String, Color)>[
      ('Sales', AppColors.goldDark),
      ('Collected', AppColors.success),
      ('Purchases', AppColors.info),
    ];
    final step = rows.length <= 1 ? chartWidth : chartWidth / (rows.length - 1);
    for (final entry in series) {
      final path = Path();
      for (var index = 0; index < rows.length; index++) {
        final value = _number(rows[index][entry.$1]);
        final x = left + step * index;
        final y = top + chartHeight * (1 - value / math.max(maxValue, 1));
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = entry.$2);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = entry.$2
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (var index = 0; index < rows.length; index += 2) {
      final painter = TextPainter(
        text: TextSpan(
          text: '${rows[index]['Label'] ?? ''}',
          style: TextStyle(
            color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
            fontSize: 7,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: 48);
      final x = (left + step * index - painter.width / 2)
          .clamp(0.0, size.width - painter.width);
      painter.paint(canvas, Offset(x, size.height - bottom + 8));
    }
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  @override
  bool shouldRepaint(covariant _ExecutiveTrendPainter oldDelegate) =>
      oldDelegate.rows != rows ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.isDark != isDark;
}
