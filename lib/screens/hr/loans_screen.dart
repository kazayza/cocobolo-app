import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../services/loan_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/design_kit.dart';
import '../../widgets/identity_dialog.dart';
import '../../widgets/month_picker.dart';
import 'loan_detail_screen.dart';
import 'loan_form_screen.dart';
import 'loan_status.dart';

/// إدارة السلف والأقساط — ثلاثة أوضاع: كل السلف | أقساط الشهر |
/// كشف الموظف. مرساة هوية كحلية وبطاقات سلف بشريط تقدم ذهبي، وكل
/// فشل ظاهر برسالة الخادم مع إعادة محاولة — لا ابتلاع صامت.
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
  String _installMonth = DateFormat('yyyy-MM').format(DateTime.now());
  final TextEditingController _stmtSearchCtrl = TextEditingController();
  final _moneyFmt = NumberFormat('#,##0.00');

  String _viewMode = 'loans'; // loans | installments | statement
  List<dynamic> _loans = [];
  List<dynamic> _installments = [];
  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _statement;
  int _statementEmployeeId = 0;
  List<dynamic> _stmtEmployees = [];
  String _statusFilter = 'all';
  bool _loading = true;
  bool _statsLoading = true;
  bool _instLoading = false;
  bool _stmtLoading = false;
  String? _error;
  String? _instError;
  String? _stmtError;

  bool get _isDark => ThemeService().isDarkMode;

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  String _money(dynamic v) => _moneyFmt.format(_num(v));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _stmtSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _statsLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getStats(),
        // العرض الافتراضي = كل السلف بلا أي قيد شهر أو حالة: لا يُرسل
        // شهر إطلاقًا، والحالة تُرسل فقط عند اختيار المستخدم فلترًا
        // صريحًا غير «الكل»
        _service.getLoans(
          status: _statusFilter == 'all' ? null : _statusFilter,
          search:
              _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
          pageSize: 100,
        ),
      ]);
      if (!mounted) return;
      final loans = results[1];
      dynamic raw = loans['items'] ?? loans['data'] ?? loans['rows'];
      if (raw is Map) raw = raw['items'] ?? raw['data'] ?? raw['rows'];
      setState(() {
        _stats = results[0];
        _loans = (raw as List?) ?? [];
        _statsLoading = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _statsLoading = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadInstallments() async {
    setState(() {
      _instLoading = true;
      _instError = null;
    });
    try {
      final data = await _service.getMonthInstallments(_installMonth);
      if (!mounted) return;
      setState(() {
        _installments = data;
        _instLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _instError = e.toString();
        _instLoading = false;
      });
    }
  }

  Future<void> _searchStatementEmployees() async {
    setState(() {
      _stmtLoading = true;
      _stmtError = null;
    });
    try {
      final res = await _service.searchEmployees(
        _stmtSearchCtrl.text.trim().isEmpty
            ? null
            : _stmtSearchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _stmtEmployees = res;
        _stmtLoading = false;
        if (res.isEmpty) _stmtError = 'لا توجد نتائج مطابقة للبحث';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stmtError = e.toString();
        _stmtLoading = false;
      });
    }
  }

  Future<void> _loadStatement(int employeeId) async {
    _statementEmployeeId = employeeId;
    setState(() {
      _stmtLoading = true;
      _stmtError = null;
    });
    try {
      final stmt = await _service.getStatement(employeeId);
      if (!mounted) return;
      setState(() {
        _statement = stmt;
        _stmtEmployees = [];
        _stmtLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stmtError = e.toString();
        _stmtLoading = false;
      });
    }
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

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LoanFormScreen(userId: widget.userId, username: widget.username),
      ),
    );
    if (created == true) {
      _snack('تم إنشاء السلفة وتوليد أقساطها');
      await _load();
    }
  }

  Future<void> _openDetail(int loanId) async {
    if (loanId <= 0) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LoanDetailScreen(loanId: loanId, username: widget.username),
      ),
    );
    if (!mounted) return;
    // أي إجراء داخل التفاصيل (إلغاء/تخطي/تقسيم/تعديل) قد يغيّر القائمة
    if (_viewMode == 'loans') {
      await _load();
    } else if (_viewMode == 'statement' && _statement != null) {
      if (_statementEmployeeId > 0) await _loadStatement(_statementEmployeeId);
    }
  }

  Future<void> _cancelLoan(Map<String, dynamic> row) async {
    final loanId = (row['LoanId'] as num?)?.toInt() ??
        (row['LoanID'] as num?)?.toInt() ??
        0;
    if (loanId <= 0) return;
    final confirmed = await showIdentityConfirmDialog(
      context: context,
      icon: Icons.cancel_rounded,
      title: 'إلغاء السلفة',
      subtitle: row['EmployeeName']?.toString(),
      message:
          'سيتم إلغاء سلفة ${row['EmployeeName'] ?? ''} بمبلغ ${_money(row['LoanAmount'])} جـ وعكس أثرها المالي إن صُرفت من خزينة. متابعة؟',
      confirmLabel: 'إلغاء السلفة',
      danger: true,
    );
    if (!confirmed) return;
    try {
      final res = await _service.cancelLoan(loanId, widget.username);
      _snack(res['message']?.toString() ?? 'تم إلغاء السلفة وعكس الأثر المالي');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frm_LoansPage'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'إدارة السلف والأقساط',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _anchorHeader(),
            ),
          ),
          SliverToBoxAdapter(child: _statsSection()),
          SliverToBoxAdapter(child: _modeSwitcher()),
          if (_viewMode == 'loans') ...[
            SliverToBoxAdapter(child: _loanFilters()),
            SliverToBoxAdapter(child: _loansBody()),
          ] else if (_viewMode == 'installments') ...[
            SliverToBoxAdapter(child: _installmentFilters()),
            SliverToBoxAdapter(child: _installmentsBody()),
          ] else ...[
            SliverToBoxAdapter(child: _statementSearch()),
            SliverToBoxAdapter(child: _statementBody()),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      floatingActionButton: _viewMode == 'loans'
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'سلفة جديدة',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              onPressed: _openCreate,
            )
          : null,
    );
  }

  /// مرساة الهوية الكحلية: عنوان الشاشة وعدّادات سريعة وحبة إنشاء ذهبية
  Widget _anchorHeader() {
    final textTheme = Theme.of(context).textTheme;
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة السلف والأقساط',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'سلف نشطة: ${_stats['ActiveLoansCount'] ?? 0} • المتبقي: ${_money(_stats['TotalRemainingAmount'])} جـ',
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
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: _openCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(
                'سلفة جديدة',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsSection() {
    if (_statsLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: LinearProgressIndicator(color: AppColors.gold),
      );
    }
    if (_stats.isEmpty) return const SizedBox.shrink();
    final stats = <(String, String, Color, IconData)>[
      (
        'سلف نشطة',
        '${_stats['ActiveLoansCount'] ?? 0}',
        _isDark ? AppColors.successLight : AppColors.success,
        Icons.account_balance_rounded,
      ),
      (
        'إجمالي المتبقي',
        '${_money(_stats['TotalRemainingAmount'])} جـ',
        _isDark ? AppColors.errorLight : AppColors.error,
        Icons.account_balance_wallet_rounded,
      ),
      (
        'أقساط الشهر',
        '${_money(_stats['ThisMonthDeductions'])} جـ',
        _isDark ? AppColors.infoLight : AppColors.info,
        Icons.payments_rounded,
      ),
      (
        'أقساط معلقة',
        '${_stats['PendingInstallmentsCount'] ?? 0}',
        _isDark ? AppColors.warningLight : AppColors.warning,
        Icons.hourglass_top_rounded,
      ),
      (
        'انتهت هذا الشهر',
        '${_stats['CompletedThisMonth'] ?? 0}',
        _isDark ? AppColors.gold : AppColors.navy,
        Icons.task_alt_rounded,
      ),
      (
        'متوسط السلفة',
        '${_money(_stats['AverageLoanAmount'])} جـ',
        _isDark ? AppColors.infoLight : AppColors.info,
        Icons.analytics_rounded,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.25,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (final s in stats)
            AppStatCard(label: s.$1, value: s.$2, color: s.$3, icon: s.$4),
        ],
      ),
    );
  }

  /// محكّم الأوضاع الثلاثة بحبات هوية (مختار = كحلي نهارًا/ذهبي ليلًا)
  Widget _modeSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 50,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color:
              _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _modePill('كل السلف', Icons.view_list_rounded, 'loans'),
            _modePill('أقساط الشهر', Icons.calendar_month_rounded,
                'installments'),
            _modePill('كشف الموظف', Icons.receipt_long_rounded, 'statement'),
          ],
        ),
      ),
    );
  }

  Widget _modePill(String label, IconData icon, String mode) {
    final active = _viewMode == mode;
    final selectedColor = _isDark ? AppColors.gold : AppColors.navy;
    final selectedText = _isDark ? AppColors.navy : Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          setState(() => _viewMode = mode);
          if (mode == 'installments' && _installments.isEmpty) {
            await _loadInstallments();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: active ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active
                    ? selectedText
                    : AppColors.textSecondary(_isDark),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: active
                          ? selectedText
                          : AppColors.textSecondary(_isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(IconData icon, {String? hint, String? label}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppColors.textHint(_isDark)),
      prefixIcon:
          Icon(icon, size: 19, color: AppColors.textSecondary(_isDark)),
      filled: true,
      fillColor:
          _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ThemeService().accentColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _loanFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AppCard(
        color: AppColors.surface(_isDark),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _searchCtrl,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.text(_isDark), fontSize: 14),
                decoration: _fieldDecoration(Icons.search_rounded,
                    hint: 'اسم الموظف / القسم'),
                onSubmitted: (_) => _load(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _isDark
                      ? AppColors.card(_isDark)
                      : AppColors.inputFill(_isDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: ThemeService().accentColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('الكل'),
                  ),
                  DropdownMenuItem(
                    value: 'Active',
                    child: Text(loanStatusLabel('Active')),
                  ),
                  DropdownMenuItem(
                    value: 'Completed',
                    child: Text(loanStatusLabel('Completed')),
                  ),
                  DropdownMenuItem(
                    value: 'Cancelled',
                    child: Text(loanStatusLabel('Cancelled')),
                  ),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: _isDark ? AppColors.gold : AppColors.navy,
                foregroundColor: _isDark ? AppColors.navy : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: const Text('عرض'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loansBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: AppLoading(),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: AppError(message: _error!, onRetry: _load),
      );
    }
    if (_loans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: AppEmpty(message: 'لا توجد سلف مطابقة'),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          for (final row in _loans)
            _loanCard(Map<String, dynamic>.from(row as Map)),
        ],
      ),
    );
  }

  /// بطاقة سلفة واحدة — نفس البطاقة في وضع «كل السلف» ووضع «كشف
  /// الموظف»: الاسم والقسم، الإجمالي، المدفوع/المتبقي مع شريط التقدم
  /// الذهبي، القسط الشهري، شارة الحالة، وإلغاء للنشطة فقط.
  Widget _loanCard(Map<String, dynamic> row) {
    final textTheme = Theme.of(context).textTheme;
    final total = _num(row['LoanAmount']);
    final remaining = _num(row['RemainingAmount']);
    final paid = row['PaidAmount'] != null
        ? _num(row['PaidAmount'])
        : (total - remaining);
    final ratio = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final status = row['Status']?.toString();
    final loanId = (row['LoanId'] as num?)?.toInt() ??
        (row['LoanID'] as num?)?.toInt() ??
        0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: AppColors.surface(_isDark),
        padding: const EdgeInsets.all(12),
        onTap: () => _openDetail(loanId),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.gold,
                  child: Text(
                    (row['EmployeeName']?.toString() ?? '?').isNotEmpty
                        ? (row['EmployeeName']?.toString() ?? '?')
                            .substring(0, 1)
                        : '?',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['EmployeeName']?.toString() ?? '—',
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.text(_isDark),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${row['Department'] ?? ''}'
                        '${(row['JobTitle']?.toString() ?? '').isNotEmpty ? ' • ${row['JobTitle']}' : ''}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(_isDark),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: row['StatusAr']?.toString() ??
                      loanStatusLabel(status),
                  color: loanStatusColor(status, _isDark),
                  icon: loanStatusIcon(status),
                  small: true,
                ),
                if (status == 'Active')
                  IconButton(
                    tooltip: 'إلغاء السلفة',
                    icon: Icon(
                      Icons.cancel_outlined,
                      size: 19,
                      color: _isDark ? AppColors.errorLight : AppColors.error,
                    ),
                    onPressed: () => _cancelLoan(row),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'الإجمالي ${_money(total)} جـ',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.text(_isDark),
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const Spacer(),
                Text(
                  'القسط الشهري ${_money(row['MonthlyInstallment'])} جـ',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppColors.divider(_isDark),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'المدفوع ${_money(paid)} جـ',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  'المتبقي ${_money(remaining)} جـ',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // حقائق السلفة صراحة بجانب شريط التقدم: بداية الخصم، وعدد
            // الأقساط الكلي والمدفوع منها والمتبقي
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _cardFact(
                  Icons.calendar_month_rounded,
                  'البداية: ${monthLabel(row['StartDeductionMonth']?.toString())}',
                ),
                _cardFact(
                  Icons.format_list_numbered_rounded,
                  'الأقساط: ${(row['TotalInstallments'] as num?)?.toInt() ?? 0}',
                ),
                _cardFact(
                  Icons.check_circle_rounded,
                  'مدفوع: ${(row['PaidInstallments'] as num?)?.toInt() ?? 0}',
                ),
                _cardFact(
                  Icons.hourglass_top_rounded,
                  'متبقٍّ: ${((row['TotalInstallments'] as num?)?.toInt() ?? 0) - ((row['PaidInstallments'] as num?)?.toInt() ?? 0)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardFact(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.5, color: AppColors.textSecondary(_isDark)),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(_isDark),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _installmentFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AppCard(
        color: AppColors.surface(_isDark),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: MonthField(
                label: 'الشهر',
                value: _installMonth,
                onChanged: (v) {
                  if (v != null) setState(() => _installMonth = v);
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _loadInstallments,
              style: FilledButton.styleFrom(
                backgroundColor: _isDark ? AppColors.gold : AppColors.navy,
                foregroundColor: _isDark ? AppColors.navy : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: const Text('تحميل'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _installmentsBody() {
    if (_instLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: AppLoading(),
      );
    }
    if (_instError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: AppError(message: _instError!, onRetry: _loadInstallments),
      );
    }
    if (_installments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: AppEmpty(message: 'لا توجد أقساط لهذا الشهر'),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AppCard(
        color: AppColors.surface(_isDark),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final r in _installments)
              ListTile(
                title: Text(
                  '${r['EmployeeName'] ?? ''}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.text(_isDark),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                ),
                subtitle: Text(
                  '${r['MonthDisplay'] ?? r['DeductionMonth'] ?? ''} • قسط ${r['InstallmentNumber'] ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 11,
                      ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AmountText(
                      value: '${_money(r['Amount'])} جـ',
                      color: AppColors.text(_isDark),
                      size: 13,
                    ),
                    if (r['Status'] != null) ...[
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: installmentStatusLabel(
                            r['Status']?.toString()),
                        color: installmentStatusColor(
                            r['Status']?.toString(), _isDark),
                        small: true,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statementSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AppCard(
        color: AppColors.surface(_isDark),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: 'كشف حساب الموظف',
              icon: Icons.receipt_long_rounded,
              accent: _isDark ? AppColors.gold : AppColors.navy,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stmtSearchCtrl,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.text(_isDark), fontSize: 14),
                    decoration: _fieldDecoration(Icons.person_search_rounded,
                        hint: 'ابحث عن موظف...'),
                    onSubmitted: (_) => _searchStatementEmployees(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _stmtLoading ? null : _searchStatementEmployees,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isDark ? AppColors.gold : AppColors.navy,
                    foregroundColor: _isDark ? AppColors.navy : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: const Text('بحث'),
                ),
              ],
            ),
            if (_stmtEmployees.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 170),
                decoration: BoxDecoration(
                  color: _isDark
                      ? AppColors.card(_isDark)
                      : AppColors.inputFill(_isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _stmtEmployees.length,
                  itemBuilder: (_, i) {
                    final emp =
                        Map<String, dynamic>.from(_stmtEmployees[i] as Map);
                    final empId = (emp['EmployeeID'] as num?)?.toInt() ??
                        (emp['EmployeeId'] as num?)?.toInt() ??
                        0;
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${emp['FullName'] ?? ''}',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.text(_isDark),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                      ),
                      subtitle: Text(
                        '${emp['Department'] ?? ''} • ${emp['JobTitle'] ?? ''}',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary(_isDark),
                                  fontSize: 11,
                                ),
                      ),
                      onTap: () => _loadStatement(empId),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statementBody() {
    if (_stmtLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: AppLoading(),
      );
    }
    if (_stmtError != null && _statement == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (_isDark ? AppColors.errorLight : AppColors.error)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            _stmtError!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _isDark ? AppColors.errorLight : AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
          ),
        ),
      );
    }
    final s = _statement;
    if (s == null) return const SizedBox.shrink();
    final loans = (s['Loans'] as List?) ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                Text(
                  s['EmployeeName']?.toString() ?? '—',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${s['Department'] ?? ''} • ${s['JobTitle'] ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.goldLight,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppStatCard(
                  label: 'السلف النشطة',
                  value: '${s['ActiveLoansCount'] ?? 0}',
                  color: _isDark ? AppColors.successLight : AppColors.success,
                  icon: Icons.account_balance_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatCard(
                  label: 'إجمالي السلف',
                  value: '${_money(s['TotalLoanAmount'])} جـ',
                  color: _isDark ? AppColors.infoLight : AppColors.info,
                  icon: Icons.payments_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatCard(
                  label: 'المتبقي',
                  value: '${_money(s['TotalRemainingAmount'])} جـ',
                  color: _isDark ? AppColors.errorLight : AppColors.error,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppSectionHeader(
            title: 'سلف الموظف',
            subtitle: '${loans.length} سلفة',
            icon: Icons.account_balance_rounded,
            accent: _isDark ? AppColors.gold : AppColors.navy,
          ),
          const SizedBox(height: 10),
          if (loans.isEmpty)
            const AppEmpty(message: 'لا توجد سلف لهذا الموظف')
          else
            for (final l in loans)
              _loanCard(Map<String, dynamic>.from(l as Map)),
        ],
      ),
    );
  }
}
