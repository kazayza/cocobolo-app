import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:fl_chart/fl_chart.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/recovery_service.dart';
import 'opportunity_detail_screen.dart';

/// تقرير استرداد الفرص الخاسرة - مطابق بلازور LostRecoveryReport.razor 1044 سطر
/// تصميم بهوية فلاتر navy+gold + تحليلات: جدول + اتجاه شهري + أداء موظفين + أسباب خسارة
class LostRecoveryReportScreen extends StatefulWidget {
  final int userId;
  final String username;

  const LostRecoveryReportScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<LostRecoveryReportScreen> createState() => _LostRecoveryReportScreenState();
}

class _LostRecoveryReportScreenState extends State<LostRecoveryReportScreen> {
  bool _loading = true;
  bool _searching = false;
  String? _errorMsg;
  bool _autoRefresh = true;

  DateTime? _from;
  DateTime? _to;
  String _quick = 'all';
  String _status = 'all';
  int? _empId;
  String _q = '';
  final _searchCtrl = TextEditingController();

  Map<String, dynamic> _result = {
    'Rows': <dynamic>[],
    'RowCount': 0,
    'TotalValue': 0,
    'UncontactedCount': 0,
    'ContactedCount': 0,
    'RejectedCount': 0,
    'RevivedCount': 0,
    'PageIndex': 1,
    'PageSize': 50,
    'TotalPages': 1,
    'HasMore': false,
  };

  List<dynamic> _csEmployees = [];
  List<dynamic> _trend = [];
  List<dynamic> _staff = [];
  List<dynamic> _reasons = [];
  String _tab = 'table'; // table | trend | staff | reasons

  bool get _isDark => ThemeService().isDarkMode;

  bool get _hasActiveFilters =>
      _q.trim().isNotEmpty || _status != 'all' || _empId != null || _from != null || _to != null;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadReport();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final emps = await RecoveryService.getCsEmployees();
    if (mounted) setState(() => _csEmployees = emps);
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final res = await RecoveryService.getReport(
        from: _from != null ? DateFormat('yyyy-MM-dd').format(_from!) : null,
        to: _to != null ? DateFormat('yyyy-MM-dd').format(_to!) : null,
        status: _status,
        employeeId: _empId,
        search: _q,
        pageIndex: _result['PageIndex'] ?? 1,
        pageSize: _result['PageSize'] ?? 50,
      );
      final trend = await RecoveryService.getTrend(months: 12);
      final staff = await RecoveryService.getStaffPerformance();
      final reasons = await RecoveryService.getReasonsAnalysis();
      if (!mounted) return;
      setState(() {
        _result = res;
        _trend = trend;
        _staff = staff;
        _reasons = reasons;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _goToPage(int page) async {
    if (page < 1) return;
    setState(() => _searching = true);
    try {
      final res = await RecoveryService.getReport(
        from: _from != null ? DateFormat('yyyy-MM-dd').format(_from!) : null,
        to: _to != null ? DateFormat('yyyy-MM-dd').format(_to!) : null,
        status: _status,
        employeeId: _empId,
        search: _q,
        pageIndex: page,
        pageSize: 50,
      );
      if (mounted) setState(() => _result = res);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _setQuick(String k) {
    setState(() {
      _quick = k;
      final today = DateTime.now();
      switch (k) {
        case 'month':
          _from = DateTime.now().subtract(const Duration(days: 30));
          _to = today;
          break;
        case 'quarter':
          _from = DateTime.now().subtract(const Duration(days: 90));
          _to = today;
          break;
        case 'year':
          _from = DateTime(today.year, 1, 1);
          _to = today;
          break;
        case 'all':
          _from = null;
          _to = null;
          break;
      }
    });
    _loadReport();
  }

  void _clearAll() {
    setState(() {
      _q = '';
      _searchCtrl.clear();
      _status = 'all';
      _empId = null;
      _quick = 'all';
      _from = null;
      _to = null;
    });
    _loadReport();
  }

  String _money(dynamic v) {
    if (v == null) return '—';
    try {
      final numericValue = v is num ? v : double.tryParse('$v') ?? 0;
      return '${NumberFormat('#,###').format(numericValue)} ج.م';
    } catch (_) {
      return '$v';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        body: NestedScrollView(
          headerSliverBuilder: (ctx, inner) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 170,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              title: Text('تقرير الاسترداد', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
              actions: [
                IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _loadReport),
                IconButton(
                  icon: const Icon(Icons.file_download_rounded),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تصدير Excel - قريباً', style: GoogleFonts.cairo())));
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(background: _buildHero()),
            ),
            SliverToBoxAdapter(child: _buildKpis()),
            SliverToBoxAdapter(child: _buildSegments()),
            SliverToBoxAdapter(child: _buildFilters()),
            SliverToBoxAdapter(child: _buildTabs()),
          ],
          body: _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
              : _buildTabContent(),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.navy, const Color(0xFF1E3A5F), const Color(0xFF2D4A7F)], begin: Alignment.topRight, end: Alignment.bottomLeft),
      ),
      child: Stack(children: [
        Positioned(top: -20, right: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle))),
        Positioned(bottom: -30, left: 20, child: Container(width: 120, height: 120, decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.08), shape: BoxShape.circle))),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
            child: Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.18))), child: Icon(Icons.assessment_rounded, color: AppColors.gold, size: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('تقرير استرداد الفرص الخاسرة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                Text('صورة كاملة: الفرص في طابور الاسترداد + نتائج التواصل والرفض والعودة', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11, height: 1.3)),
              ])),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildKpis() {
    final rowCount = _result['RowCount'] ?? 0;
    final totalValue = _result['TotalValue'] ?? 0;
    final revived = _result['RevivedCount'] ?? 0;
    final uncontacted = _result['UncontactedCount'] ?? 0;

    return Container(
      color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _kpi(Icons.track_changes_rounded, '$rowCount', 'إجمالي الفرص', const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          _kpi(Icons.payments_outlined, _money(totalValue), 'إجمالي القيمة', const Color(0xFF4F46E5)),
          const SizedBox(width: 8),
          _kpi(Icons.restart_alt_rounded, '$revived', 'مُسترد', const Color(0xFF059669)),
          const SizedBox(width: 8),
          _kpi(Icons.trending_down_rounded, '$uncontacted', 'لم يُتواصل', const Color(0xFF64748B)),
        ]),
      ),
    );
  }

  Widget _kpi(IconData icon, String val, String label, Color c) {
    return SizedBox(
      width: 145,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withOpacity(0.06)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: c, size: 17)),
          ]),
          const SizedBox(height: 8),
          Text(val, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: c)),
          Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary(_isDark))),
        ]),
      ),
    );
  }

  Widget _buildSegments() {
    final rowCount = _result['RowCount'] ?? 0;
    if (rowCount == 0) return const SizedBox.shrink();
    final total = rowCount > 0 ? rowCount : 1;
    final un = _result['UncontactedCount'] ?? 0;
    final con = _result['ContactedCount'] ?? 0;
    final rej = _result['RejectedCount'] ?? 0;
    final rev = _result['RevivedCount'] ?? 0;

    double pct(int v) => (v / total) * 100;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withOpacity(0.06))),
      child: Column(children: [
        _segment('لم يُتواصل', un, pct(un), const Color(0xFF64748B)),
        const SizedBox(height: 8),
        _segment('قيد المتابعة', con, pct(con), const Color(0xFFD97706)),
        const SizedBox(height: 8),
        _segment('رفض نهائي', rej, pct(rej), const Color(0xFFDC2626)),
        const SizedBox(height: 8),
        _segment('مُسترد', rev, pct(rev), const Color(0xFF059669)),
      ]),
    );
  }

  Widget _segment(String label, int count, double percent, Color c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('$count (${percent.toStringAsFixed(0)}%)', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: percent / 100, minHeight: 5, backgroundColor: c.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(c))),
    ]);
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.06))),
      child: Column(children: [
        Row(children: [
          Expanded(child: _dateField('من تاريخ', _from, (d) => setState(() => _from = d))),
          const SizedBox(width: 8),
          Expanded(child: _dateField('إلى تاريخ', _to, (d) => setState(() => _to = d))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _status,
              decoration: InputDecoration(labelText: 'الحالة', labelStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              items: [
                DropdownMenuItem(value: 'all', child: Text('كل الحالات', style: GoogleFonts.cairo(fontSize: 12))),
                DropdownMenuItem(value: 'uncontacted', child: Text('لم يُتواصل', style: GoogleFonts.cairo(fontSize: 12))),
                DropdownMenuItem(value: 'contacting', child: Text('قيد المتابعة', style: GoogleFonts.cairo(fontSize: 12))),
                DropdownMenuItem(value: 'rejected', child: Text('رفض نهائي', style: GoogleFonts.cairo(fontSize: 12))),
                DropdownMenuItem(value: 'revived', child: Text('مُسترد', style: GoogleFonts.cairo(fontSize: 12))),
              ],
              onChanged: (v) {
                setState(() => _status = v ?? 'all');
                _loadReport();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: _empId,
              decoration: InputDecoration(labelText: 'موظف خدمة العملاء', labelStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              items: [
                DropdownMenuItem(value: null, child: Text('الكل', style: GoogleFonts.cairo(fontSize: 12))),
                ..._csEmployees.map((e) => DropdownMenuItem<int?>(value: e['EmployeeID'] ?? e['EmployeeId'], child: Text(e['FullName'] ?? '', style: GoogleFonts.cairo(fontSize: 12)))),
              ],
              onChanged: (v) {
                setState(() => _empId = v);
                _loadReport();
              },
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _q = v),
          onSubmitted: (_) => _loadReport(),
          style: GoogleFonts.cairo(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'بحث بالعميل / الهاتف...',
            hintStyle: GoogleFonts.cairo(fontSize: 11),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: _q.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () { _searchCtrl.clear(); setState(() => _q = ''); _loadReport(); }) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('آخر شهر', _quick == 'month', () => _setQuick('month')),
            _chip('آخر 3 شهور', _quick == 'quarter', () => _setQuick('quarter')),
            _chip('من أول السنة', _quick == 'year', () => _setQuick('year')),
            _chip('كل الفترات', _quick == 'all', () => _setQuick('all')),
            if (_hasActiveFilters) _chip('مسح الكل', false, _clearAll, isClear: true),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text('آخر تحديث: ${DateFormat('yyyy/MM/dd HH:mm:ss').format(DateTime.now())}', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey)),
          const Spacer(),
          Row(children: [
            Checkbox(value: _autoRefresh, onChanged: (v) => setState(() => _autoRefresh = v ?? true), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
            Text('تحديث تلقائي', style: GoogleFonts.cairo(fontSize: 10)),
          ]),
        ]),
      ]),
    );
  }

  Widget _dateField(String label, DateTime? date, Function(DateTime?) onChanged) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: date ?? DateTime.now());
        if (d != null) {
          onChanged(d);
          _loadReport();
        }
      },
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.event_rounded, size: 14, color: AppColors.gold), const SizedBox(width: 6), Text(date == null ? label : DateFormat('yyyy/MM/dd').format(date), style: GoogleFonts.cairo(fontSize: 11))])),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {bool isClear = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isClear ? const Color(0xFFFEE2E2) : (selected ? AppColors.navy : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isClear ? const Color(0xFFFCA5A5) : (selected ? AppColors.navy : const Color(0xFFDBE3F3))),
          ),
          child: Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: isClear ? const Color(0xFFB91C1C) : (selected ? Colors.white : const Color(0xFF475569)))),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        _tabBtn('table', 'الجدول', Icons.table_rows_rounded),
        _tabBtn('trend', 'الاتجاه', Icons.show_chart_rounded),
        _tabBtn('staff', 'الموظفون', Icons.groups_outlined),
        _tabBtn('reasons', 'الأسباب', Icons.category_outlined),
      ]),
    );
  }

  Widget _tabBtn(String key, String label, IconData icon) {
    final sel = _tab == key;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _tab = key),
        child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: sel ? AppColors.card(_isDark) : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: sel ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)] : null), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 15, color: sel ? AppColors.gold : AppColors.textSecondary(_isDark)), const SizedBox(width: 4), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 10.5, fontWeight: sel ? FontWeight.bold : FontWeight.w600, color: sel ? AppColors.navy : AppColors.textSecondary(_isDark))))])),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_searching) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: AppColors.gold), const SizedBox(height: 8), Text('جارٍ البحث...', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey))]));
    }

    switch (_tab) {
      case 'trend':
        return _buildTrendTab();
      case 'staff':
        return _buildStaffTab();
      case 'reasons':
        return _buildReasonsTab();
      default:
        return _buildTableTab();
    }
  }

  Widget _buildTableTab() {
    final rows = (_result['Rows'] as List?) ?? [];
    if (rows.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(_hasActiveFilters ? 'لا توجد نتائج مطابقة' : 'لا توجد بيانات للتقرير بعد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('جرب تغيير الفلاتر أو البحث', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
      ])));
    }

    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFC7D2FE), style: BorderStyle.solid)),
        child: Row(children: [
          Text('لم يُتواصل = بلا تواصل بعد الخسارة', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey.shade700)),
          const SizedBox(width: 8),
          Text('•', style: GoogleFonts.cairo(color: Colors.grey)),
          const SizedBox(width: 8),
          Text('مُسترد = عاد لدورة البيع', style: GoogleFonts.cairo(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = Map<String, dynamic>.from(rows[i] as Map);
            return _ReportRowCard(row: r, isDark: _isDark, money: _money, onOpen: () {
              final id = r['OpportunityId'] ?? 0;
              Navigator.push(context, MaterialPageRoute(builder: (_) => OpportunityDetailScreen(opportunityId: id is int ? id : int.tryParse('$id') ?? 0, userId: widget.userId, username: widget.username)));
            });
          },
        ),
      ),
      if ((_result['TotalPages'] ?? 1) > 1)
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(onPressed: (_result['PageIndex'] ?? 1) <= 1 ? null : () => _goToPage((_result['PageIndex'] ?? 1) - 1), style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('→ السابق', style: GoogleFonts.cairo(fontSize: 11))),
            const SizedBox(width: 12),
            Text('صفحة ${_result['PageIndex']} من ${_result['TotalPages']}', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: (_result['HasMore'] ?? false) == false ? null : () => _goToPage((_result['PageIndex'] ?? 1) + 1), style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('التالي ←', style: GoogleFonts.cairo(fontSize: 11))),
          ]),
        ),
    ]);
  }

  Widget _buildTrendTab() {
    if (_trend.isEmpty) {
      return Center(child: Text('لا توجد بيانات كافية للرسم بعد', style: GoogleFonts.cairo(color: Colors.grey)));
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withOpacity(0.06))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الاتجاه الشهري — آخر 12 شهرًا', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('عدد الفرص حسب حالة الصف وتاريخ حدث الحالة', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (v) => FlLine(color: Colors.black.withOpacity(0.06), strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= _trend.length) return const SizedBox.shrink();
                      final label = '${_trend[idx]['Label'] ?? ''}';
                      return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label.split('/').last, style: GoogleFonts.cairo(fontSize: 9, color: Colors.grey)));
                    })),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, meta) => Text('${v.toInt()}', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey)))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    _lineBar(_trend.map((e) => (e['Revived'] ?? 0) as int).toList(), const Color(0xFF10B981)),
                    _lineBar(_trend.map((e) => (e['Contacting'] ?? 0) as int).toList(), const Color(0xFFF59E0B)),
                    _lineBar(_trend.map((e) => (e['Rejected'] ?? 0) as int).toList(), const Color(0xFFEF4444)),
                    _lineBar(_trend.map((e) => (e['Uncontacted'] ?? 0) as int).toList(), const Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, children: [
              _legendDot('مُسترد', const Color(0xFF10B981)),
              _legendDot('قيد المتابعة', const Color(0xFFF59E0B)),
              _legendDot('رفض نهائي', const Color(0xFFEF4444)),
              _legendDot('لم يُتواصل', const Color(0xFF94A3B8)),
            ]),
          ]),
        ),
      ]),
    );
  }

  LineChartBarData _lineBar(List<int> values, Color c) {
    return LineChartBarData(
      spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i].toDouble())),
      isCurved: false,
      color: c,
      barWidth: 3,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: c.withOpacity(0.12)),
    );
  }

  Widget _legendDot(String label, Color c) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildStaffTab() {
    if (_staff.isEmpty) {
      return Center(child: Text('لا توجد بيانات أداء بعد', style: GoogleFonts.cairo(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: _staff.length,
      itemBuilder: (_, i) {
        final s = Map<String, dynamic>.from(_staff[i] as Map);
        final rate = (s['ReviveRate'] ?? 0).toDouble();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withOpacity(0.06))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.10), shape: BoxShape.circle), child: Center(child: Text('${(s['FullName'] ?? '?')[0]}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.navy)))),
              const SizedBox(width: 10),
              Expanded(child: Text(s['FullName'] ?? '', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text('مُسترد ${s['Revived']} • ${_money(s['RevivedValue'])}', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF047857)))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _miniStat('القضايا', '${s['Assigned']}', Colors.blue),
              const SizedBox(width: 8),
              _miniStat('لم يُتواصل', '${s['Uncontacted']}', Colors.grey),
              const SizedBox(width: 8),
              _miniStat('قيد المتابعة', '${s['Contacting']}', Colors.orange),
              const SizedBox(width: 8),
              _miniStat('رفض', '${s['Rejected']}', Colors.red),
            ]),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (rate / 100).clamp(0, 1), minHeight: 8, backgroundColor: Colors.black.withOpacity(0.08), valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)))),
            const SizedBox(height: 4),
            Text('نسبة الاسترداد ${rate.toStringAsFixed(0)}%', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600)),
          ]),
        );
      },
    );
  }

  Widget _miniStat(String label, String val, Color c) {
    return Expanded(
      child: Container(padding: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(8)), child: Column(children: [Text(val, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: c)), Text(label, style: GoogleFonts.cairo(fontSize: 9, color: Colors.grey.shade600))])),
    );
  }

  Widget _buildReasonsTab() {
    if (_reasons.isEmpty) {
      return Center(child: Text('لا توجد أسباب مسجلة بعد', style: GoogleFonts.cairo(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: _reasons.length,
      itemBuilder: (_, i) {
        final r = Map<String, dynamic>.from(_reasons[i] as Map);
        final rate = (r['ReviveRate'] ?? 0).toDouble();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withOpacity(0.06))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r['ReasonName'] ?? '', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.10), borderRadius: BorderRadius.circular(20)), child: Text('العدد ${r['Total']} • مُسترد ${r['Revived']}', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700))),
            ]),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (rate / 100).clamp(0, 1), minHeight: 8, backgroundColor: Colors.black.withOpacity(0.08), valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)))),
            const SizedBox(height: 4),
            Text('نسبة الاسترداد ${rate.toStringAsFixed(0)}% - لمعرفة أين تتركز فرص الاسترداد', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey.shade600)),
          ]),
        );
      },
    );
  }
}

class _ReportRowCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isDark;
  final String Function(dynamic) money;
  final VoidCallback onOpen;

  const _ReportRowCard({required this.row, required this.isDark, required this.money, required this.onOpen});

  Color _statusColor(String s) {
    switch (s) {
      case 'رفض نهائي':
        return const Color(0xFFDC2626);
      case 'مُسترد':
        return const Color(0xFF059669);
      case 'قيد المتابعة':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = '${row['StatusAr'] ?? ''}';
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.22))),
      child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(14), child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onOpen, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(8)), child: Text('#${row['OpportunityId']}', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(child: Text(row['ClientName'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25))), child: Text(status, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (row['Phone'] != null) _chip(Icons.phone_rounded, '${row['Phone']}'),
          _chip(Icons.payments_rounded, money(row['ExpectedValue'])),
          if (row['LostReasonName'] != null) _chip(Icons.info_outline_rounded, '${row['LostReasonName']}'),
          if (row['ClosedAt'] != null) _chip(Icons.event_rounded, () { try { final dt = DateTime.tryParse(row['ClosedAt'].toString()); return dt == null ? '' : DateFormat('yyyy/MM/dd').format(dt); } catch (_) { return ''; } }()),
          if (row['CsEmployeeName'] != null) _chip(Icons.person_rounded, '${row['CsEmployeeName']}'),
          _chip(Icons.chat_rounded, 'تواصل ${row['ContactCount'] ?? 0}'),
        ]),
        if (row['LastCsSummary'] != null && '${row['LastCsSummary']}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)), child: Text('${row['LastCsSummary']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade700))),
        ],
      ])))),
    );
  }

  Widget _chip(IconData icon, String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
