import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/app_colors.dart';
import '../../services/theme_service.dart';
import '../../services/payroll_service.dart';
import '../../services/permission_service.dart';

/// سجل المرتبات — مطابق 100% لـ HR/Payroll/PayrollList.razor (بلازور هو الأساس)
/// هيدر بريميوم + خطوات 1-4 + 6 كروت إحصاء + شرائح شهور + جدول + فلاتر
class PayrollListScreen extends StatefulWidget {
  final int userId;
  final String username;
  const PayrollListScreen({super.key, required this.userId, required this.username});

  @override
  State<PayrollListScreen> createState() => _PayrollListScreenState();
}

class _PayrollListScreenState extends State<PayrollListScreen> {
  final PayrollService _service = PayrollService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<dynamic> _payrolls = [];
  List<dynamic> _months = [];
  Map<String, dynamic> _stats = {};
  String? _selectedMonth; // YYYY-MM or null = كل الشهور
  String _statusFilter = 'all'; // all, pending, approved, paid
  bool _loading = true;
  String? _error;

  bool get _isDark => ThemeService().isDarkMode;
  String get _statsTitle {
    if (_selectedMonth == null) return 'الشهر الحالي';
    return _formatMonth(_selectedMonth!);
  }

  String _formatMonth(String m) {
    try {
      final parts = m.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMMM yyyy', 'ar').format(d);
    } catch (_) {
      return m;
    }
  }

  String _formatMoney(dynamic v) {
    final n = v is num ? v : num.tryParse('$v') ?? 0;
    return NumberFormat('#,##0').format(n);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getMonths(),
        _service.getByMonth(_selectedMonth),
        _service.getStats(_selectedMonth),
      ]);
      if (!mounted) return;
      setState(() {
        _months = results[0] as List;
        _payrolls = results[1] as List;
        _stats = results[2] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectMonth(String? month) async {
    setState(() => _selectedMonth = month);
    await _load();
  }

  List<dynamic> get _filtered {
    var list = _payrolls;
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        final name = '${r['EmployeeName'] ?? ''}'.toLowerCase();
        final dept = '${r['Department'] ?? ''}'.toLowerCase();
        return name.contains(q) || dept.contains(q);
      }).toList();
    }
    if (_statusFilter != 'all') {
      list = list.where((r) => '${r['Status'] ?? ''}'.toLowerCase() == _statusFilter).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(child: _buildSteps()),
                    if (_stats.isNotEmpty) SliverToBoxAdapter(child: _buildStats()),
                    SliverToBoxAdapter(child: _buildMonthChips()),
                    SliverToBoxAdapter(child: _buildFilters()),
                    SliverToBoxAdapter(child: _buildTable()),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator(color: Color(0xFFDBBF74)));
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: GoogleFonts.cairo(color: Colors.white)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: Text('إعادة المحاولة', style: GoogleFonts.cairo())),
      ]),
    );
  }

  // ── AppBar بريميوم مطابق للبلازور ──
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 170,
      pinned: true,
      backgroundColor: const Color(0xFF1A2842),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(children: [
          // gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2842), Color(0xFF2A3F6A), Color(0xFF1A2842)],
              ),
            ),
          ),
          // orbs
          Positioned(top: -20, right: -10, child: _orb(90, const Color(0xFFDBBF74).withOpacity(0.08))),
          Positioned(bottom: -10, left: 20, child: _orb(120, Colors.white.withOpacity(0.04))),
          Positioned(top: 40, left: 60, child: _orb(45, const Color(0xFFDBBF74).withOpacity(0.06))),
          // grid pattern (dots)
          Positioned.fill(child: Opacity(opacity: 0.03, child: CustomPaint(painter: _GridPainter()))),
          // content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              child: Row(children: [
                // icon
                Stack(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF0D060)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.3), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.payments_rounded, color: Color(0xFF1A2842), size: 28),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFF1A2842)),
                    ),
                  ),
                ]).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('سجل المرتبات', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.diamond_rounded, size: 10, color: Color(0xFFD4AF37)),
                          const SizedBox(width: 4),
                          Text('Premium', style: GoogleFonts.cairo(color: const Color(0xFFD4AF37), fontSize: 9, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.insights_rounded, size: 12, color: Color(0xFFD4AF37)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'مراجعة واعتماد وصرف المرتبات — ${DateFormat('EEEE yyyy/MM/dd', 'ar').format(DateTime.now())}',
                          style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10),
                        ),
                      ),
                    ]),
                  ]),
                ),
                Column(children: [
                  _appBarButton('معالجة جديدة', Icons.add_rounded, true, () {}),
                  const SizedBox(height: 6),
                  _appBarButton('خارج الراتب', Icons.card_giftcard_rounded, false, () {}),
                ]),
              ]),
            ),
          ),
        ]),
      ),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
      title: Text('المرتبات', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
      centerTitle: true,
    );
  }

  Widget _orb(double size, Color color) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }

  Widget _appBarButton(String label, IconData icon, bool primary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: primary ? const Color(0xFF1A2842) : Colors.white),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.cairo(color: primary ? const Color(0xFF1A2842) : Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildSteps() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF13273F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        _step('1', 'معالجة'),
        _stepArrow(),
        _step('2', 'حفظ ومراجعة'),
        _stepArrow(),
        _step('3', 'اعتماد'),
        _stepArrow(),
        _step('4', 'صرف'),
        const Spacer(),
        const Icon(Icons.info_rounded, size: 12, color: Color(0xFFD4AF37)),
        const SizedBox(width: 4),
        Flexible(child: Text('الإضافات المنفصلة تُصرف كحركة مستقلة', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 8))),
      ]),
    );
  }

  Widget _step(String num, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
        child: Text(num, style: GoogleFonts.cairo(color: const Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 9)),
    ]);
  }

  Widget _stepArrow() => const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_back_rounded, size: 10, color: Colors.white38));

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.insights_rounded, size: 14, color: Color(0xFFD4AF37)),
          const SizedBox(width: 6),
          Text('إحصاء $_statsTitle', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          if (_selectedMonth == null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('كل الشهور — المعروض للشهر الحالي فقط', style: GoogleFonts.cairo(color: const Color(0xFFD4AF37), fontSize: 8)),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.6,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            _statCard('إجمالي الصافي', '${_formatMoney(_stats['TotalNetThisMonth'] ?? _stats['totalNet'] ?? 0)} جـ', Icons.payments_rounded, const Color(0xFF1E3A5F), const Color(0xFFD4AF37)),
            _statCard('قيد المراجعة', '${_stats['ReviewCount'] ?? 0}', Icons.rate_review_rounded, const Color(0xFFFB923C).withOpacity(0.15), const Color(0xFFFB923C)),
            _statCard('معتمد', '${_stats['ApprovedCount'] ?? 0}', Icons.verified_rounded, const Color(0xFF3B82F6).withOpacity(0.15), const Color(0xFF3B82F6)),
            _statCard('مدفوع', '${_stats['PaidCount'] ?? 0}', Icons.paid_rounded, const Color(0xFF10B981).withOpacity(0.15), const Color(0xFF10B981)),
            _statCard('إضافات منفصلة', '${_formatMoney(_stats['TotalSeparateBonuses'] ?? 0)} جـ', Icons.card_giftcard_rounded, const Color(0xFF8B5CF6).withOpacity(0.15), const Color(0xFF8B5CF6)),
            _statCard('غير مدفوع', '${_stats['PendingCount'] ?? 0}', Icons.history_rounded, const Color(0xFFEF4444).withOpacity(0.15), const Color(0xFFEF4444)),
          ],
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2342),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.cairo(color: Colors.white60, fontSize: 8)),
            Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildMonthChips() {
    if (_months.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF13273F), borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Text('الشهر', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10)),
          const SizedBox(width: 8),
          ..._months.map((m) {
            final monthStr = '${m['Month'] ?? m['PayrollMonth'] ?? ''}';
            final count = m['PayrollCount'] ?? m['count'] ?? 0;
            final total = m['TotalNet'] ?? m['totalNet'] ?? 0;
            final active = _selectedMonth == monthStr;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => _selectMonth(monthStr),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: active ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(children: [
                    Text(_formatMonth(monthStr), style: GoogleFonts.cairo(color: active ? const Color(0xFF1A2842) : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(count > 0 ? '$count مرتب · ${_formatMoney(total)}' : 'لا مرتبات', style: GoogleFonts.cairo(color: active ? const Color(0xFF1A2842).withOpacity(0.7) : Colors.white60, fontSize: 8)),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _selectMonth(null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedMonth == null ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('كل الشهور', style: GoogleFonts.cairo(color: _selectedMonth == null ? const Color(0xFF1A2842) : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'بحث باسم الموظف أو القسم',
                hintStyle: GoogleFonts.cairo(color: Colors.white38, fontSize: 11),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFD4AF37), size: 18),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: const Color(0xFF1A1A1A),
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 11),
                icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة')),
                  DropdownMenuItem(value: 'approved', child: Text('معتمد')),
                  DropdownMenuItem(value: 'paid', child: Text('مدفوع')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.info_outline_rounded, size: 12, color: Colors.white38),
          const SizedBox(width: 6),
          Text('عرض ${_filtered.length} من ${_payrolls.length} مرتب', style: GoogleFonts.cairo(color: Colors.white38, fontSize: 10)),
          const Spacer(),
          Text('Premium HR', style: GoogleFonts.cairo(color: const Color(0xFFD4AF37).withOpacity(0.5), fontSize: 9)),
        ]),
      ]),
    );
  }

  Widget _buildTable() {
    final list = _filtered;
    if (list.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14)),
        child: Center(
          child: Column(children: [
            Icon(Icons.payments_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text('لا توجد مرتبات', style: GoogleFonts.cairo(color: Colors.white60)),
            Text('اختر شهراً آخر أو غيّر الفلتر', style: GoogleFonts.cairo(color: Colors.white38, fontSize: 11)),
          ]),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            Expanded(flex: 3, child: Text('الموظف', style: GoogleFonts.cairo(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold))),
            Expanded(child: Text('الشهر', style: GoogleFonts.cairo(color: Colors.white60, fontSize: 10))),
            Expanded(child: Text('الصافي', style: GoogleFonts.cairo(color: Colors.white60, fontSize: 10))),
            Expanded(child: Text('الحالة', style: GoogleFonts.cairo(color: Colors.white60, fontSize: 10))),
            const SizedBox(width: 24),
          ]),
        ),
        ...list.asMap().entries.map((e) {
          final idx = e.key;
          final row = e.value;
          final status = '${row['Status'] ?? row['PayrollStatus'] ?? 'pending'}'.toLowerCase();
          Color statusColor;
          String statusText;
          switch (status) {
            case 'approved': statusColor = const Color(0xFF3B82F6); statusText = 'معتمد'; break;
            case 'paid': statusColor = const Color(0xFF10B981); statusText = 'مدفوع'; break;
            default: statusColor = const Color(0xFFFB923C); statusText = 'قيد المراجعة';
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04)))),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('${idx + 1}', style: GoogleFonts.cairo(color: const Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${row['EmployeeName'] ?? ''}', style: GoogleFonts.cairo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('${row['Department'] ?? row['BranchName'] ?? ''}', style: GoogleFonts.cairo(color: Colors.white38, fontSize: 9)),
                    ]),
                  ),
                ]),
              ),
              Expanded(child: Text('${row['PayrollMonth'] ?? row['Month'] ?? ''}', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10))),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                Text('${_formatMoney(row['GrossSalary'] ?? row['BasicSalary'] ?? 0)} ج', style: GoogleFonts.cairo(color: const Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                Text('خصم ${_formatMoney(row['TotalDeductions'] ?? 0)}', style: GoogleFonts.cairo(color: const Color(0xFFEF4444), fontSize: 8)),
              ])),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText, style: GoogleFonts.cairo(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
              Icon(Icons.chevron_left_rounded, size: 16, color: Colors.white38),
            ]),
          ).animate(delay: Duration(milliseconds: idx * 30)).fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
        }),
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 0.3;
    const gap = 18.0;
    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 0.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
