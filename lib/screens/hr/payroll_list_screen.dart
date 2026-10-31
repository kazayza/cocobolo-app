import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../services/app_colors.dart';
import '../../services/cashbox_service.dart';
import '../../services/design_tokens.dart';
import '../../services/payroll_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/design_kit.dart';
import 'off_payroll_screen.dart';
import 'payroll_status.dart';
import 'payslip_screen.dart';

/// سجل المرتبات — مطابق لـ HR/Payroll/PayrollList.razor (بلازور هو الأساس)
/// بهوية التطبيق: مرساة كحلية تحمل الشهر والإجراءات، وبطاقات موظفين
/// يعرض كلٌّ منها الصافي الحقيقي (NetSalary) لا الإجمالي.
class PayrollListScreen extends StatefulWidget {
  final int userId;
  final String username;
  const PayrollListScreen({
    super.key,
    required this.userId,
    required this.username,
  });

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

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  /// إجمالي خصومات الصف: الحقل التجميعي من الخادم، واحتياطيًا مجموع
  /// مكوناته (غياب + تأخير + سلف + جزاءات) أو عمود الخصومات العام.
  double _deductionsOf(Map row) {
    if (row['TotalDeductions'] != null) return _num(row['TotalDeductions']);
    final parts = ['AbsenceDeduction', 'LateDeduction', 'LoanDeduction', 'PenaltyDeduction']
        .where((k) => row[k] != null)
        .fold<double>(0, (s, k) => s + _num(row[k]));
    if (parts > 0) return parts;
    return _num(row['Deductions']);
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

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  int _payrollId(Map row) =>
      (row['PayrollID'] as num?)?.toInt() ??
      (row['PayrollId'] as num?)?.toInt() ??
      (row['ID'] as num?)?.toInt() ??
      (row['Id'] as num?)?.toInt() ??
      0;

  /// حساب وحفظ رواتب الشهر للمراجعة — POST /api/payroll/runs
  Future<void> _createRun() async {
    final month =
        _selectedMonth ?? DateFormat('yyyy-MM').format(DateTime.now());
    final textTheme = Theme.of(context).textTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(_isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'حساب وحفظ رواتب الشهر',
          style: textTheme.titleMedium?.copyWith(
            color: AppColors.text(_isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'سيتم حساب رواتب شهر ${_formatMonth(month)} لجميع الموظفين النشطين وحفظها بحالة «قيد المراجعة» (تُتخطى المسجلة سابقًا وذات الأساسي الصفري). متابعة؟',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary(_isDark),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary(_isDark),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _isDark ? AppColors.gold : AppColors.navy,
              foregroundColor: _isDark ? AppColors.navy : Colors.white,
            ),
            child: const Text('حساب وحفظ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final run = await _service.createRun(month);
      _snack(
          'تم إنشاء كشف رواتب $month — العدد ${run['PayrollCount'] ?? 0} · الإجمالي ${_formatMoney(run['TotalNet'] ?? 0)} ج');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _approveRow(Map row) async {
    final id = _payrollId(row);
    if (id <= 0) return;
    try {
      await _service.approve(id);
      _snack('تم اعتماد مرتب ${row['EmployeeName'] ?? ''}');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _payRow(Map row) async {
    final id = _payrollId(row);
    if (id <= 0) return;
    List<dynamic> boxes = [];
    try {
      boxes = await CashboxService.getAllCashboxes();
    } catch (_) {
      boxes = [];
    }
    if (!mounted) return;
    if (boxes.isEmpty) {
      _snack('لا توجد خزائن متاحة للصرف', error: true);
      return;
    }
    int? selected = (boxes.first['CashBoxID'] as num?)?.toInt();
    final textTheme = Theme.of(context).textTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface(_isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Text(
            'صرف المرتب',
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.text(_isDark),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${row['EmployeeName'] ?? ''} — الصافي ${_formatMoney(row['NetSalary'] ?? 0)} ج',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selected,
                decoration: InputDecoration(
                  labelText: 'خزينة الصرف',
                  filled: true,
                  fillColor: AppColors.inputFill(_isDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: AppColors.surface(_isDark),
                items: boxes.map((b) {
                  final m = Map<String, dynamic>.from(b as Map);
                  return DropdownMenuItem<int>(
                    value: (m['CashBoxID'] as num?)?.toInt(),
                    child: Text('${m['CashBoxName'] ?? ''}'),
                  );
                }).toList(),
                onChanged: (v) => setDialogState(() => selected = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'إلغاء',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                ),
              ),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: _isDark ? AppColors.gold : AppColors.navy,
                foregroundColor: _isDark ? AppColors.navy : Colors.white,
              ),
              child: const Text('صرف الآن'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || selected == null) return;
    try {
      await _service.pay(id, selected!);
      _snack('تم صرف مرتب ${row['EmployeeName'] ?? ''} من الخزينة');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  void _openPayslip(Map row) {
    final id = _payrollId(row);
    if (id <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayslipScreen(payrollId: id, username: widget.username),
      ),
    );
  }

  void _openOffPayroll() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OffPayrollScreen(userId: widget.userId, username: widget.username),
      ),
    );
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
      // المرشح والشارة من مصدر واحد: مفتاح الحالة المشتق من
      // PaymentStatus العربي أولًا (كان المرشح يقرأ Status الإنجليزي
      // وحده فتفلت منه الصفوف ذات الحالة العربية).
      list = list
          .where((r) => payrollStatusKey(r as Map) == _statusFilter)
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frm_PayrollList'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        title: Text(
          'سجل المرتبات',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? AppError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _buildAnchorHeader(),
                      if (_stats.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildStats(),
                      ],
                      if (_months.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildMonthChips(),
                      ],
                      const SizedBox(height: 12),
                      _buildFilters(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _createRun,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                _isDark ? AppColors.gold : AppColors.navy,
                            foregroundColor:
                                _isDark ? AppColors.navy : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                          icon: const Icon(Icons.calculate_rounded, size: 18),
                          label: Text(
                            'حساب وحفظ رواتب الشهر للمراجعة',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color:
                                      _isDark ? AppColors.navy : Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCards(),
                    ],
                  ),
                ),
    );
  }

  /// المرساة الكحلية: العنوان وسياق الشهر، وخطوات الدورة ١-٤،
  /// وإجراءا «معالجة جديدة» و«خارج الراتب» كحبوب ممتلئة.
  Widget _buildAnchorHeader() {
    final textTheme = Theme.of(context).textTheme;
    final monthLabel = _selectedMonth == null
        ? 'كل الشهور'
        : _formatMonth(_selectedMonth!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: AppColors.gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سجل المرتبات',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'مراجعة واعتماد وصرف المرتبات — $monthLabel',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.goldLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _createRun,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'معالجة جديدة',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _openOffPayroll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.card_giftcard_rounded, size: 17),
                label: Text(
                  'خارج الراتب',
                  style: textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
          const SizedBox(height: 10),
          Row(
            children: [
              _step('1', 'معالجة'),
              _stepArrow(),
              _step('2', 'حفظ ومراجعة'),
              _stepArrow(),
              _step('3', 'اعتماد'),
              _stepArrow(),
              _step('4', 'صرف'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'الإضافات المنفصلة تُصرف كحركة مستقلة خارج الراتب',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.goldLight.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String num, String label) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 19,
          height: 19,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            num,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _stepArrow() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 11,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      );

  Widget _buildStats() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'إحصاء $_statsTitle',
          icon: Icons.insights_rounded,
          trailing: _selectedMonth == null
              ? Text(
                  'المعروض للشهر الحالي فقط',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 11,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.55,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _statCard(
              'إجمالي الصافي',
              '${_formatMoney(_stats['TotalNetThisMonth'] ?? _stats['totalNet'] ?? 0)} جـ',
              Icons.payments_rounded,
              _isDark ? AppColors.gold : AppColors.navy,
            ),
            _statCard(
              'قيد المراجعة',
              '${_stats['ReviewCount'] ?? 0}',
              Icons.rate_review_rounded,
              _isDark ? AppColors.infoLight : AppColors.info,
            ),
            _statCard(
              'معتمد',
              '${_stats['ApprovedCount'] ?? 0}',
              Icons.verified_rounded,
              _isDark ? AppColors.gold : AppColors.goldDark,
            ),
            _statCard(
              'مدفوع',
              '${_stats['PaidCount'] ?? 0}',
              Icons.paid_rounded,
              _isDark ? AppColors.successLight : AppColors.success,
            ),
            _statCard(
              'إضافات منفصلة',
              '${_formatMoney(_stats['TotalSeparateBonuses'] ?? 0)} جـ',
              Icons.card_giftcard_rounded,
              _isDark ? AppColors.neutralLight : AppColors.neutral,
            ),
            _statCard(
              'غير مدفوع',
              '${_stats['PendingCount'] ?? 0}',
              Icons.history_rounded,
              _isDark ? AppColors.warningLight : AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: _isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.text(_isDark),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthChips() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'الشهر',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary(_isDark),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            ..._months.map((m) {
              final monthStr = '${m['Month'] ?? m['PayrollMonth'] ?? ''}';
              final count = m['PayrollCount'] ?? m['count'] ?? 0;
              final total = m['TotalNet'] ?? m['totalNet'] ?? 0;
              final active = _selectedMonth == monthStr;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _monthChip(
                  label: _formatMonth(monthStr),
                  sub: count > 0
                      ? '$count مرتب · ${_formatMoney(total)}'
                      : 'لا مرتبات',
                  active: active,
                  onTap: () => _selectMonth(monthStr),
                ),
              );
            }),
            _monthChip(
              label: 'كل الشهور',
              sub: null,
              active: _selectedMonth == null,
              onTap: () => _selectMonth(null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthChip({
    required String label,
    required String? sub,
    required bool active,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final bg = active
        ? (_isDark ? AppColors.gold : AppColors.navy)
        : AppColors.inputFill(_isDark);
    final fg = active
        ? (_isDark ? AppColors.navy : Colors.white)
        : AppColors.text(_isDark);
    final subFg = active
        ? fg.withValues(alpha: 0.75)
        : AppColors.textSecondary(_isDark);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (sub != null)
              Text(
                sub,
                style: textTheme.labelSmall?.copyWith(color: subFg),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.text(_isDark),
                  ),
                  decoration: InputDecoration(
                    hintText: 'بحث باسم الموظف أو القسم',
                    hintStyle: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textHint(_isDark),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary(_isDark),
                      size: 19,
                    ),
                    filled: true,
                    fillColor: AppColors.inputFill(_isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide:
                          BorderSide(color: ThemeService().accentColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.inputFill(_isDark),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    dropdownColor: AppColors.surface(_isDark),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.text(_isDark),
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.textSecondary(_isDark),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('الكل')),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('قيد المراجعة'),
                      ),
                      DropdownMenuItem(value: 'approved', child: Text('معتمد')),
                      DropdownMenuItem(value: 'paid', child: Text('مدفوع')),
                    ],
                    onChanged: (v) =>
                        setState(() => _statusFilter = v ?? 'all'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: AppColors.textSecondary(_isDark),
              ),
              const SizedBox(width: 6),
              Text(
                'عرض ${_filtered.length} من ${_payrolls.length} مرتب',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCards() {
    final list = _filtered;
    if (list.isEmpty) {
      return const AppEmpty(
        icon: Icons.payments_outlined,
        message: 'لا توجد مرتبات',
        hint: 'اختر شهراً آخر أو غيّر الفلتر',
      );
    }
    return Column(
      children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildPayrollCard(Map<String, dynamic>.from(list[i] as Map), i),
        ],
      ],
    );
  }

  /// بطاقة مرتب موظف: الاسم والقسم/الوظيفة، الأساسي والخصومات،
  /// والصافي الحقيقي NetSalary بارزًا، وشارة الحالة، وإجراءا
  /// الاعتماد/الصرف بحسب الحالة — والنقر يفتح القسيمة.
  Widget _buildPayrollCard(Map<String, dynamic> row, int idx) {
    final textTheme = Theme.of(context).textTheme;
    final statusKey = payrollStatusKey(row);
    final statusColor = payrollStatusColor(statusKey, _isDark);
    final statusLabel =
        payrollStatusLabel(statusKey, raw: '${row['PaymentStatus'] ?? ''}');
    final name = '${row['EmployeeName'] ?? ''}';
    final dept = '${row['Department'] ?? row['BranchName'] ?? ''}';
    final job = '${row['JobTitle'] ?? ''}';
    final subtitle = [job, dept].where((s) => s.isNotEmpty).join(' • ');
    final monthRaw = '${row['PayrollMonth'] ?? row['Month'] ?? ''}';
    final netColor = _isDark ? AppColors.gold : AppColors.navy;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPayslip(row),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.gold
                          .withValues(alpha: _isDark ? 0.2 : 0.14),
                      child: Text(
                        name.isNotEmpty ? name[0] : '؟',
                        style: textTheme.titleMedium?.copyWith(
                          color: _isDark ? AppColors.gold : AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              color: AppColors.text(_isDark),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary(_isDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: statusLabel,
                      color: statusColor,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill(_isDark),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      _miniStat('الشهر',
                          monthRaw.isEmpty ? '—' : _formatMonth(monthRaw)),
                      _miniStat(
                          'الأساسي', '${_formatMoney(row['BasicSalary'])} جـ'),
                      _miniStat(
                        'الخصومات',
                        '${_formatMoney(_deductionsOf(row))} جـ',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'الصافي',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AmountText(
                      // الصافي الحقيقي من NetSalary — لا GrossSalary
                      value: '${_formatMoney(row['NetSalary'])} جـ',
                      color: netColor,
                      size: 19,
                    ),
                    const Spacer(),
                    if (statusKey == 'pending')
                      FilledButton.icon(
                        onPressed: () => _approveRow(row),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _isDark ? AppColors.infoLight : AppColors.info,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        icon: const Icon(Icons.verified_rounded, size: 15),
                        label: const Text('اعتماد'),
                      ),
                    if (statusKey == 'approved')
                      FilledButton.icon(
                        onPressed: () => _payRow(row),
                        style: FilledButton.styleFrom(
                          backgroundColor: _isDark
                              ? AppColors.successLight
                              : AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        icon: const Icon(Icons.payments_rounded, size: 15),
                        label: const Text('صرف'),
                      ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: AppColors.textSecondary(_isDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: idx * 40))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _miniStat(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary(_isDark),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelLarge?.copyWith(
              color: AppColors.text(_isDark),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
