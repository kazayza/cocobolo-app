import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/app_colors.dart';
import '../../services/theme_service.dart';
import '../../services/loan_service.dart';

/// إدارة السلف والأقساط — مطابق 100% لـ HR/LoansPage.razor
/// وضع 3 أوضاع: كل السلف | أقساط الشهر | كشف الموظف + 6 كروت إحصاء
class LoansScreen extends StatefulWidget {
  final int userId;
  final String username;
  const LoansScreen({super.key, required this.userId, required this.username});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final LoanService _service = LoanService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _viewMode = 'loans'; // loans | installments | statement
  List<dynamic> _loans = [];
  List<dynamic> _installments = [];
  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _statement;
  String _statusFilter = 'Active';
  String _month = DateFormat('yyyy-MM').format(DateTime.now());
  String _installMonth = DateFormat('yyyy-MM').format(DateTime.now());
  bool _loading = true;
  bool _statsLoading = true;

  String _money(dynamic v) => NumberFormat('#,##0').format(v is num ? v : num.tryParse('$v') ?? 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _statsLoading = true; });
    try {
      final stats = await _service.getStats();
      final loans = await _service.getLoans(status: _statusFilter, search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(), month: _month.isEmpty ? null : _month);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loans = (loans['items'] ?? loans['data'] ?? loans['rows'] ?? []) as List;
        _statsLoading = false;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _statsLoading = false; });
    }
  }

  Future<void> _loadInstallments() async {
    setState(() => _loading = true);
    final data = await _service.getMonthInstallments(_installMonth);
    if (!mounted) return;
    setState(() { _installments = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text('إدارة السلف والأقساط', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _header()),
        if (_statsLoading) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator(color: Color(0xFFD4AF37))))
        else SliverToBoxAdapter(child: _statsGrid()),
        SliverToBoxAdapter(child: _modeSwitcher()),
        if (_viewMode == 'loans') ...[
          SliverToBoxAdapter(child: _loanFilters()),
          SliverToBoxAdapter(child: _loansTable()),
        ] else if (_viewMode == 'installments') ...[
          SliverToBoxAdapter(child: _installmentFilters()),
          SliverToBoxAdapter(child: _installmentsTable()),
        ] else ...[
          SliverToBoxAdapter(child: _statementSearch()),
          if (_statement != null) SliverToBoxAdapter(child: _statementView()),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
      floatingActionButton: _viewMode == 'loans'
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: const Color(0xFF0F172A),
              icon: const Icon(Icons.add_rounded),
              label: Text('سلفة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              onPressed: () {},
            )
          : null,
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إدارة السلف والأقساط', style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            Text('تابع السلف النشطة، الأقساط المستحقة، وكشف حساب كل موظف', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10)),
          ]),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
          onPressed: () {},
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('سلفة جديدة', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _statsGrid() {
    if (_stats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: [
          _stat('سلف نشطة', '${_stats['ActiveLoansCount'] ?? 0}', 'قروض مفتوحة', const Color(0xFF10B981), Icons.account_balance_rounded),
          _stat('إجمالي المتبقي', '${_money(_stats['TotalRemainingAmount'] ?? 0)} ج', 'الرصيد غير المسدد', const Color(0xFFEF4444), Icons.account_balance_wallet_rounded),
          _stat('أقساط الشهر', '${_money(_stats['ThisMonthDeductions'] ?? 0)} ج', 'مستحق هذا الشهر', const Color(0xFF3B82F6), Icons.payments_rounded),
          _stat('أقساط معلقة', '${_stats['PendingInstallmentsCount'] ?? 0}', 'كل الأقساط pending', const Color(0xFFF59E0B), Icons.hourglass_top_rounded),
          _stat('انتهت هذا الشهر', '${_stats['CompletedThisMonth'] ?? 0}', 'سلف أغلقت', const Color(0xFF8B5CF6), Icons.task_alt_rounded),
          _stat('متوسط السلفة', '${_money(_stats['AverageLoanAmount'] ?? 0)} ج', 'إجمالي نشط ${_money(_stats['TotalLoanAmount'] ?? 0)}', const Color(0xFF06B6D4), Icons.analytics_rounded),
        ],
      ),
    );
  }

  Widget _stat(String title, String value, String note, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.cairo(color: const Color(0xFF64748B), fontSize: 8, fontWeight: FontWeight.bold)),
            Text(value, style: GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
            Text(note, style: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 7)),
          ]),
        ),
      ]),
    );
  }

  Widget _modeSwitcher() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        _modeBtn('كل السلف', Icons.view_list_rounded, 'loans', const Color(0xFF2563EB)),
        const SizedBox(width: 6),
        _modeBtn('أقساط الشهر', Icons.calendar_month_rounded, 'installments', const Color(0xFFF59E0B)),
        const SizedBox(width: 6),
        _modeBtn('كشف الموظف', Icons.receipt_long_rounded, 'statement', const Color(0xFF06B6D4)),
      ]),
    );
  }

  Widget _modeBtn(String label, IconData icon, String mode, Color color) {
    final active = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          setState(() => _viewMode = mode);
          if (mode == 'installments' && _installments.isEmpty) await _loadInstallments();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: active ? color : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: active ? color : Colors.transparent)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: active ? Colors.white : color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.cairo(color: active ? Colors.white : color, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }

  Widget _loanFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الفلاتر', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.cairo(fontSize: 11),
              decoration: InputDecoration(hintText: 'اسم الموظف / القسم', hintStyle: GoogleFonts.cairo(fontSize: 10), prefixIcon: const Icon(Icons.search_rounded, size: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: InputDecoration(labelText: 'الحالة', labelStyle: GoogleFonts.cairo(fontSize: 9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              items: const [DropdownMenuItem(value: 'Active', child: Text('نشطة')), DropdownMenuItem(value: 'Completed', child: Text('منتهية')), DropdownMenuItem(value: 'Cancelled', child: Text('ملغية'))],
              onChanged: (v) => setState(() => _statusFilter = v ?? 'Active'),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(onPressed: _load, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A)), child: Text('عرض', style: GoogleFonts.cairo(fontSize: 11))),
        ]),
      ]),
    );
  }

  Widget _loansTable() {
    if (_loading) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    if (_loans.isEmpty) return Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('لا توجد سلف', style: GoogleFonts.cairo(color: Colors.grey))));
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Expanded(flex: 2, child: Text('الموظف', style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
            Expanded(child: Text('القيمة', style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
            Expanded(child: Text('المتبقي', style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
            Expanded(child: Text('الحالة', style: GoogleFonts.cairo(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
          ]),
        ),
        ..._loans.asMap().entries.map((e) {
          final row = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.08)))),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: Row(children: [
                  CircleAvatar(radius: 14, backgroundColor: const Color(0xFFD4AF37), child: Text('${row['EmployeeName'] ?? '?'}'.substring(0, 1), style: const TextStyle(color: Colors.white, fontSize: 10))),
                  const SizedBox(width: 6),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${row['EmployeeName'] ?? ''}', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('${row['Department'] ?? ''}', style: GoogleFonts.cairo(fontSize: 8, color: Colors.grey)),
                  ])),
                ]),
              ),
              Expanded(child: Text('${_money(row['LoanAmount'] ?? 0)} ج', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(child: Text('${_money(row['RemainingAmount'] ?? 0)} ج', style: GoogleFonts.cairo(fontSize: 10, color: (row['RemainingAmount'] ?? 0) > 0 ? Colors.red : Colors.green))),
              Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('${row['StatusAr'] ?? row['Status'] ?? ''}', style: GoogleFonts.cairo(fontSize: 8, color: const Color(0xFF10B981)), textAlign: TextAlign.center))),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _installmentFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: TextField(controller: TextEditingController(text: _installMonth), decoration: InputDecoration(labelText: 'الشهر (YYYY-MM)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), onChanged: (v) => _installMonth = v)),
        const SizedBox(width: 8),
        FilledButton(onPressed: _loadInstallments, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)), child: Text('تحميل', style: GoogleFonts.cairo(color: Colors.white))),
      ]),
    );
  }

  Widget _installmentsTable() {
    if (_installments.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('لا توجد أقساط', style: GoogleFonts.cairo(color: Colors.grey))));
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: _installments.map((r) => ListTile(
        title: Text('${r['EmployeeName'] ?? ''}', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
        subtitle: Text('${r['MonthDisplay'] ?? ''} • قسط ${r['InstallmentNumber'] ?? ''}', style: GoogleFonts.cairo(fontSize: 9)),
        trailing: Text('${_money(r['Amount'] ?? 0)} ج', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37))),
      )).toList()),
    );
  }

  Widget _statementSearch() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('كشف حساب الموظف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(decoration: InputDecoration(hintText: 'ابحث عن موظف...', prefixIcon: const Icon(Icons.person_search_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), onSubmitted: (v) async {
          final res = await _service.searchEmployees(v);
          if (res.isNotEmpty && mounted) {
            final emp = res.first;
            final stmt = await _service.getStatement(emp['EmployeeId'] ?? emp['EmployeeID'] ?? 0);
            if (mounted) setState(() => _statement = stmt);
          }
        }),
      ]),
    );
  }

  Widget _statementView() {
    if (_statement == null) return const SizedBox.shrink();
    final s = _statement!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['EmployeeName'] ?? ''}', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('${s['Department'] ?? ''} • ${s['JobTitle'] ?? ''}', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10)),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.8,
          children: [
            _stat('السلف النشطة', '${s['ActiveLoansCount'] ?? 0}', '', const Color(0xFF10B981), Icons.account_balance_rounded),
            _stat('إجمالي السلف', '${_money(s['TotalLoanAmount'] ?? 0)} ج', '', const Color(0xFF3B82F6), Icons.payments_rounded),
            _stat('المتبقي', '${_money(s['TotalRemainingAmount'] ?? 0)} ج', '', const Color(0xFFEF4444), Icons.account_balance_wallet_rounded),
          ],
        ),
      ]),
    );
  }
}
