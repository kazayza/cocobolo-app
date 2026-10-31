import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_colors.dart';
import '../../services/cashbox_service.dart';
import '../../services/design_tokens.dart';
import '../../services/off_payroll_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/design_kit.dart';
import '../../widgets/employee_picker.dart';
import '../../widgets/identity_dialog.dart';
import '../../widgets/month_picker.dart';
import 'payroll_status.dart';

/// دفعات خارج الراتب — مطابقة OffPayrollPaymentsPage.razor في بلازور:
/// مرساة هوية + خطوات + 6 إحصاءات + نموذج طلب (موظف/نوع/مبلغ/شهران/
/// وصف/سبب) + قائمة بحالاتها وإجراءاتها: اعتماد ورفض وإلغاء وصرف —
/// والصرف يدعم مقاصة أقساط السلف المعلّقة كما في بلازور حرفيًا
/// (PayOneWithLoanAllocationAsync): النقدي = الدفعة − المخصص.
/// كل فشل ظاهر برسالة الخادم — لا ابتلاع صامت.
class OffPayrollScreen extends StatefulWidget {
  final int userId;
  final String username;
  const OffPayrollScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<OffPayrollScreen> createState() => _OffPayrollScreenState();
}

class _OffPayrollScreenState extends State<OffPayrollScreen> {
  final OffPayrollService _service = OffPayrollService();
  final _moneyFmt = NumberFormat('#,##0.00');

  List<dynamic> _items = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;

  String? _month; // null = كل الشهور
  String? _statusFilter; // قيمة PaymentStatus العربية أو null = الكل
  String? _typeFilter;
  final TextEditingController _searchCtrl = TextEditingController();

  // ── نموذج الطلب ──
  bool _formExpanded = false;
  EmployeeOption? _employee;
  String _paymentType = 'BonusSeparate';
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  String _paymentMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String _referenceMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String? _formError;
  bool _saving = false;

  bool get _isDark => ThemeService().isDarkMode;

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  String _money(dynamic v) => _moneyFmt.format(_num(v));

  String _typeAr(dynamic raw) {
    switch ('${raw ?? ''}') {
      case 'CommissionSeparate':
        return 'عمولة منفصلة';
      case 'BonusSeparate':
        return 'مكافأة منفصلة';
      default:
        return 'دفعة خارج الراتب';
    }
  }

  int _rowId(Map r) =>
      (r['PayrollID'] as num?)?.toInt() ??
      (r['PayrollId'] as num?)?.toInt() ??
      0;

  double _rowAmount(Map r) => _num(r['Amount'] ?? r['NetSalary'] ?? 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getAll(
        month: _month,
        status: _statusFilter,
        paymentType: _typeFilter,
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List?) ?? [];
        _stats = (data['stats'] as Map?)?.cast<String, dynamic>() ?? {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
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

  // ── إجراءات الصفوف ──
  Future<void> _approve(Map r) async {
    try {
      await _service.approve(_rowId(r));
      _snack('تم اعتماد الدفعة');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _reject(Map r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(employeeName: '${r['EmployeeName'] ?? ''}'),
    );
    if (reason == null) return;
    try {
      await _service.reject(_rowId(r),
          reason: reason.isEmpty ? null : reason);
      _snack('تم رفض الدفعة');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _cancel(Map r) async {
    final confirmed = await showIdentityConfirmDialog(
      context: context,
      icon: Icons.cancel_rounded,
      title: 'إلغاء الدفعة',
      subtitle: '${r['EmployeeName'] ?? ''}',
      message:
          'سيتم إلغاء دفعة ${_typeAr(r['PaymentType'])} بمبلغ ${_money(_rowAmount(r))} جـ للموظف ${r['EmployeeName'] ?? ''}. متابعة؟',
      confirmLabel: 'إلغاء الدفعة',
      danger: true,
    );
    if (!confirmed) return;
    try {
      await _service.cancel(_rowId(r));
      _snack('تم إلغاء الدفعة');
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _pay(Map r) async {
    final paid = await showDialog<bool>(
      context: context,
      builder: (_) => _PayDialog(
        service: _service,
        payrollId: _rowId(r),
        employeeId: (r['EmployeeID'] as num?)?.toInt() ?? 0,
        employeeName: '${r['EmployeeName'] ?? ''}',
        amount: _rowAmount(r),
      ),
    );
    if (paid == true) {
      _snack('تم صرف الدفعة من الخزينة');
      await _load();
    }
  }

  // ── إنشاء طلب ──
  Future<void> _pickEmployee() async {
    final employees = await fetchActiveEmployeeOptions();
    if (!mounted) return;
    if (employees.isEmpty) {
      _snack('تعذر تحميل قائمة الموظفين', error: true);
      return;
    }
    final picked = await showEmployeePickerSheet(context, employees: employees);
    if (picked != null && mounted) setState(() => _employee = picked);
  }

  Future<void> _create() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    String? error;
    if (_employee == null) {
      error = 'يجب اختيار الموظف';
    } else if (amount <= 0) {
      error = 'قيمة الدفعة يجب أن تكون أكبر من صفر';
    } else if (_descCtrl.text.trim().isEmpty) {
      error = 'وصف الدفعة مطلوب';
    }
    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final effectiveMonth =
          _referenceMonth.isNotEmpty ? _referenceMonth : _paymentMonth;
      await _service.create(
        employeeId: _employee!.id,
        amount: amount,
        paymentType: _paymentType,
        paymentMonth: _paymentMonth,
        referenceMonth: effectiveMonth,
        description: _descCtrl.text.trim(),
        reason: _reasonCtrl.text.trim().isEmpty
            ? null
            : _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      _snack('تم إنشاء طلب الدفعة وإرساله للمراجعة');
      setState(() {
        _saving = false;
        _formExpanded = false;
        _employee = null;
        _amountCtrl.clear();
        _descCtrl.clear();
        _reasonCtrl.clear();
        _month = effectiveMonth;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frm_OffPayroll'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'دفعات خارج الراتب',
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
              child: _anchor(),
            ),
          ),
          SliverToBoxAdapter(child: _steps()),
          if (_formExpanded)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _form(),
              ),
            ),
          SliverToBoxAdapter(child: _statsSection()),
          SliverToBoxAdapter(child: _filters()),
          SliverToBoxAdapter(child: _body()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _anchor() {
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
                  Icons.card_giftcard_rounded,
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
                      'حوافز ومكافآت خارج الراتب',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'إجمالي الطلبات: ${_money(_stats['TotalAmount'] ?? 0)} جـ • بانتظار المراجعة: ${_stats['ReviewCount'] ?? 0}',
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
              onPressed: () => setState(() => _formExpanded = !_formExpanded),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              icon: Icon(
                _formExpanded ? Icons.expand_less_rounded : Icons.post_add_rounded,
                size: 19,
              ),
              label: Text(
                'طلب دفعة',
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

  Widget _steps() {
    final textTheme = Theme.of(context).textTheme;
    Widget step(String n, String label) => Row(
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
                n,
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
              ),
            ),
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                step('1', 'تسجيل'),
                const Icon(Icons.arrow_back_rounded,
                    size: 11, color: Colors.white38),
                step('2', 'مراجعة'),
                const Icon(Icons.arrow_back_rounded,
                    size: 11, color: Colors.white38),
                step('3', 'اعتماد'),
                const Icon(Icons.arrow_back_rounded,
                    size: 11, color: Colors.white38),
                step('4', 'صرف'),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'دفعات مستقلة لا تدخل في صافي الراتب الشهري',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.goldLight,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsSection() {
    if (_loading && _stats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: LinearProgressIndicator(color: AppColors.gold),
      );
    }
    if (_stats.isEmpty) return const SizedBox.shrink();
    final stats = <(String, String, Color, IconData)>[
      (
        'إجمالي الطلبات',
        '${_money(_stats['TotalAmount'] ?? 0)} جـ',
        _isDark ? AppColors.gold : AppColors.navy,
        Icons.attach_money_rounded,
      ),
      (
        'قيد المراجعة',
        '${_stats['ReviewCount'] ?? 0}',
        _isDark ? AppColors.warningLight : AppColors.warning,
        Icons.rate_review_rounded,
      ),
      (
        'معتمد',
        '${_stats['ApprovedCount'] ?? 0}',
        _isDark ? AppColors.infoLight : AppColors.info,
        Icons.verified_rounded,
      ),
      (
        'مدفوع',
        '${_stats['PaidCount'] ?? 0}',
        _isDark ? AppColors.successLight : AppColors.success,
        Icons.paid_rounded,
      ),
      (
        'مرفوض',
        '${_stats['RejectedCount'] ?? 0}',
        _isDark ? AppColors.errorLight : AppColors.error,
        Icons.cancel_rounded,
      ),
      (
        'ملغي',
        '${_stats['CancelledCount'] ?? 0}',
        _isDark ? AppColors.neutralLight : AppColors.neutral,
        Icons.block_rounded,
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

  Widget _filters() {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final months = <String?>[
      null,
      for (var i = 0; i < 6; i++)
        DateFormat('yyyy-MM').format(DateTime(now.year, now.month - i)),
    ];
    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          labelStyle: textTheme.labelMedium?.copyWith(
            color: selected
                ? (_isDark ? AppColors.navy : Colors.white)
                : AppColors.text(_isDark),
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
          selectedColor: _isDark ? AppColors.gold : AppColors.navy,
          backgroundColor: AppColors.surface(_isDark),
          side: BorderSide(color: AppColors.divider(_isDark)),
          showCheckmark: false,
        );
    const statusOptions = <(String?, String)>[
      (null, 'كل الحالات'),
      ('قيد المراجعة', 'قيد المراجعة'),
      ('معتمد', 'معتمد'),
      ('مدفوع', 'مدفوع'),
      ('غير مدفوع', 'غير مدفوع'),
      ('مرفوض', 'مرفوض'),
      ('ملغي', 'ملغي'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            onSubmitted: (_) => _load(),
            style: textTheme.bodyMedium
                ?.copyWith(color: AppColors.text(_isDark)),
            decoration: InputDecoration(
              hintText: 'بحث بالموظف أو القسم أو الوصف…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: AppColors.inputFill(_isDark),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final m in months) ...[
                  chip(
                    m == null ? 'كل الشهور' : monthLabel(m),
                    _month == m,
                    () {
                      setState(() => _month = m);
                      _load();
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in statusOptions) ...[
                  chip(s.$2, _statusFilter == s.$1, () {
                    setState(() => _statusFilter = s.$1);
                    _load();
                  }),
                  const SizedBox(width: 6),
                ],
                chip('مكافآت فقط', _typeFilter == 'BonusSeparate', () {
                  setState(() => _typeFilter =
                      _typeFilter == 'BonusSeparate' ? null : 'BonusSeparate');
                  _load();
                }),
                const SizedBox(width: 6),
                chip('عمولات فقط', _typeFilter == 'CommissionSeparate', () {
                  setState(() => _typeFilter =
                      _typeFilter == 'CommissionSeparate'
                          ? null
                          : 'CommissionSeparate');
                  _load();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    final textTheme = Theme.of(context).textTheme;
    InputDecoration fieldDeco(String label, {bool required = false}) =>
        InputDecoration(
          labelText: required ? '$label *' : label,
          labelStyle: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary(_isDark),
            fontSize: 13,
          ),
          filled: true,
          fillColor: AppColors.inputFill(_isDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        );
    final monthMismatch = _referenceMonth != _paymentMonth;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(
            title: 'طلب دفعة جديدة',
            subtitle: 'تُرسل للمراجعة ثم الاعتماد ثم الصرف من الخزينة',
            icon: Icons.post_add_rounded,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickEmployee,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.inputFill(_isDark),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_search_rounded,
                      size: 20, color: AppColors.textSecondary(_isDark)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _employee == null
                          ? 'اختر الموظف *'
                          : '${_employee!.name}${_employee!.subtitle.isEmpty ? '' : ' • ${_employee!.subtitle}'}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: _employee == null
                            ? AppColors.textHint(_isDark)
                            : AppColors.text(_isDark),
                        fontWeight: _employee == null
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded,
                      color: AppColors.textSecondary(_isDark)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _paymentType,
                  decoration: fieldDeco('نوع الدفعة'),
                  dropdownColor: AppColors.surface(_isDark),
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.text(_isDark)),
                  items: const [
                    DropdownMenuItem(
                        value: 'BonusSeparate', child: Text('مكافأة منفصلة')),
                    DropdownMenuItem(
                        value: 'CommissionSeparate',
                        child: Text('عمولة منفصلة')),
                  ],
                  onChanged: (v) =>
                      setState(() => _paymentType = v ?? 'BonusSeparate'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.text(_isDark)),
                  decoration: fieldDeco('المبلغ (جـ)', required: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MonthField(
                  label: 'شهر الدفعة',
                  value: _paymentMonth,
                  isRequired: true,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      // الشهر المرجعي يتبع شهر الدفعة ما دام لم يُفصلا
                      if (_referenceMonth == _paymentMonth) {
                        _referenceMonth = v;
                      }
                      _paymentMonth = v;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MonthField(
                  label: 'الشهر المرجعي',
                  value: _referenceMonth,
                  isRequired: true,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _referenceMonth = v);
                  },
                ),
              ),
            ],
          ),
          if (monthMismatch) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_isDark ? AppColors.warningLight : AppColors.warning)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'الشهر المرجعي (${monthLabel(_referenceMonth)}) يختلف عن شهر الدفعة (${monthLabel(_paymentMonth)}) — هذا مقصود (مكافأة متأخرة أو مقدمة)، وستُسجَّل الدفعة على الشهر المرجعي.',
                style: textTheme.bodySmall?.copyWith(
                  color: _isDark ? AppColors.warningLight : AppColors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            style:
                textTheme.bodyMedium?.copyWith(color: AppColors.text(_isDark)),
            decoration: fieldDeco('وصف الدفعة', required: true)
                .copyWith(hintText: 'مثال: مكافأة تحقيق هدف المبيعات'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            style:
                textTheme.bodyMedium?.copyWith(color: AppColors.text(_isDark)),
            decoration: fieldDeco('سبب أو مبرر الطلب'),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: (_isDark ? AppColors.errorLight : AppColors.error)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _formError!,
                style: textTheme.bodyMedium?.copyWith(
                  color: _isDark ? AppColors.errorLight : AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: _isDark ? AppColors.gold : AppColors.navy,
              foregroundColor: _isDark ? AppColors.navy : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _saving ? 'جارٍ الإرسال…' : 'حفظ وإرسال للمراجعة',
              style: textTheme.labelLarge?.copyWith(
                color: _isDark ? AppColors.navy : Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const AppLoading();
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: AppError(message: _error!, onRetry: _load),
      );
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: AppEmpty(message: 'لا توجد دفعات مطابقة للمرشحات الحالية'),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [for (final r in _items) _rowCard(Map<String, dynamic>.from(r as Map))],
      ),
    );
  }

  Widget _rowCard(Map<String, dynamic> r) {
    final textTheme = Theme.of(context).textTheme;
    final key = payrollStatusKey(r);
    final rawStatus = '${r['PaymentStatus'] ?? ''}';
    final requested = r['RequestedAt'] ?? r['CreatedAt'];
    DateTime? reqDate;
    if (requested is DateTime) reqDate = requested;
    if (requested is String) reqDate = DateTime.tryParse(requested);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['EmployeeName'] ?? ''}',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.text(_isDark),
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      if ('${r['Department'] ?? ''}'.isNotEmpty)
                        Text(
                          '${r['Department']}',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(_isDark),
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: payrollStatusLabel(key, raw: rawStatus),
                  color: payrollStatusColor(key, _isDark),
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_typeAr(r['PaymentType'])}${'${r['Description'] ?? ''}'.isNotEmpty ? ' — ${r['Description']}' : ''}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Text(
                  '${_money(_rowAmount(r))} جـ',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.text(_isDark),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${monthLabel('${r['PayrollMonth'] ?? ''}')}${reqDate != null ? ' • طُلبت ${DateFormat('dd/MM/yyyy').format(reqDate)}' : ''}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textHint(_isDark),
                fontSize: 11,
              ),
            ),
            if (key == 'pending' || key == 'approved' || key == 'unpaid' || key == 'rejected') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (key == 'pending') ...[
                    _actionButton(
                      icon: Icons.verified_rounded,
                      label: 'اعتماد',
                      filled: true,
                      onTap: () => _approve(r),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.close_rounded,
                      label: 'رفض',
                      danger: true,
                      onTap: () => _reject(r),
                    ),
                  ],
                  if (key == 'approved' || key == 'unpaid')
                    _actionButton(
                      icon: Icons.payments_rounded,
                      label: 'صرف',
                      filled: true,
                      onTap: () => _pay(r),
                    ),
                  const Spacer(),
                  if (rawStatus != 'ملغي')
                    IconButton(
                      tooltip: 'إلغاء الدفعة',
                      icon: Icon(Icons.block_rounded,
                          size: 19, color: AppColors.textSecondary(_isDark)),
                      onPressed: () => _cancel(r),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
    bool danger = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
    final text = Text(
      label,
      style: textTheme.labelMedium?.copyWith(
        color: danger
            ? (_isDark ? AppColors.errorLight : AppColors.error)
            : filled
                ? (_isDark ? AppColors.navy : Colors.white)
                : AppColors.text(_isDark),
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    );
    if (danger) {
      return OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: (_isDark ? AppColors.errorLight : AppColors.error)
                  .withValues(alpha: 0.6)),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        icon: Icon(icon,
            size: 16, color: _isDark ? AppColors.errorLight : AppColors.error),
        label: text,
      );
    }
    if (filled) {
      return FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _isDark ? AppColors.gold : AppColors.navy,
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        icon: Icon(icon,
            size: 16, color: _isDark ? AppColors.navy : Colors.white),
        label: text,
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(shape: shape),
      icon: Icon(icon, size: 16),
      label: text,
    );
  }
}

/// حوار الرفض — حالة خاصة به ووحدة تحكم تُحرَّر في dispose الخاصة به.
class _RejectDialog extends StatefulWidget {
  final String employeeName;
  const _RejectDialog({required this.employeeName});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final TextEditingController _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    return IdentityDialog(
      icon: Icons.close_rounded,
      title: 'رفض دفعة خارج الراتب',
      subtitle: widget.employeeName,
      actions: [
        IdentityDialogAction(
          label: 'تراجع',
          onPressed: () => Navigator.pop(context),
        ),
        IdentityDialogAction(
          label: 'رفض الدفعة',
          danger: true,
          onPressed: () => Navigator.pop(context, _reasonCtrl.text.trim()),
        ),
      ],
      child: TextField(
        controller: _reasonCtrl,
        maxLines: 3,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'سبب الرفض',
          filled: true,
          fillColor: AppColors.inputFill(isDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// حوار الصرف مع مقاصة أقساط السلف — حالة الحوار تملك كل وحدات
/// التحكم وتحررها في dispose؛ أي إغلاق (رجوع/إلغاء) لا يترك أثرًا.
class _PayDialog extends StatefulWidget {
  final OffPayrollService service;
  final int payrollId;
  final int employeeId;
  final String employeeName;
  final double amount;
  const _PayDialog({
    required this.service,
    required this.payrollId,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
  });

  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  final _moneyFmt = NumberFormat('#,##0.00');
  List<dynamic> _boxes = [];
  int? _boxId;
  List<dynamic> _installments = [];
  final Map<int, TextEditingController> _allocCtrls = {};
  final Set<int> _selected = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  @override
  void initState() {
    super.initState();
    _loadDialogData();
  }

  @override
  void dispose() {
    for (final c in _allocCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDialogData() async {
    try {
      final boxes = await CashboxService.getAllCashboxes();
      List<dynamic> installments = [];
      String? instError;
      try {
        installments =
            await widget.service.getPendingInstallments(widget.employeeId);
      } catch (e) {
        instError = 'تعذر تحميل أقساط السلف: $e';
      }
      if (!mounted) return;
      setState(() {
        _boxes = boxes;
        _boxId = boxes.isEmpty
            ? null
            : (boxes.first['CashBoxID'] as num?)?.toInt();
        _installments = installments;
        _loading = false;
        _error = boxes.isEmpty ? 'لا توجد خزائن متاحة للصرف' : instError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات الصرف: $e';
      });
    }
  }

  double get _allocTotal {
    var sum = 0.0;
    for (final id in _selected) {
      sum += double.tryParse(_allocCtrls[id]?.text.trim() ?? '') ?? 0;
    }
    return sum;
  }

  Future<void> _submit() async {
    if (_boxId == null) {
      setState(() => _error = 'اختر خزينة الصرف');
      return;
    }
    final allocations = <Map<String, dynamic>>[];
    for (final id in _selected) {
      final inst = _installments.firstWhere(
        (i) => (i['InstallmentId'] as num?)?.toInt() == id,
        orElse: () => null,
      );
      if (inst == null) continue;
      final value = double.tryParse(_allocCtrls[id]?.text.trim() ?? '') ?? 0;
      if (value <= 0) {
        setState(() => _error = 'كل مبلغ مخصص يجب أن يكون أكبر من صفر');
        return;
      }
      if (value > _num(inst['Amount'])) {
        setState(() => _error =
            'المبلغ المخصص للقسط رقم ${inst['InstallmentNumber']} أكبر من قيمته (${_moneyFmt.format(_num(inst['Amount']))} جـ)');
        return;
      }
      allocations.add({'installmentId': id, 'amount': value});
    }
    if (_allocTotal > widget.amount) {
      setState(() => _error =
          'إجمالي المخصص للأقساط (${_moneyFmt.format(_allocTotal)} جـ) أكبر من قيمة الدفعة (${_moneyFmt.format(widget.amount)} جـ)');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.service.pay(widget.payrollId, _boxId!,
          allocations: allocations);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final cash = widget.amount - _allocTotal;
    return IdentityDialog(
      icon: Icons.payments_rounded,
      title: 'صرف دفعة خارج الراتب',
      subtitle: widget.employeeName,
      errorText: _error,
      actions: [
        IdentityDialogAction(
          label: 'إلغاء',
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
        ),
        IdentityDialogAction(
          label: _submitting ? 'جارٍ الصرف…' : 'صرف الآن',
          filled: true,
          icon: Icons.payments_rounded,
          onPressed: (_submitting || _loading) ? null : _submit,
        ),
      ],
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _boxId,
                  decoration: InputDecoration(
                    labelText: 'خزينة الصرف *',
                    filled: true,
                    fillColor: AppColors.inputFill(isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: AppColors.surface(isDark),
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.text(isDark)),
                  items: [
                    for (final b in _boxes)
                      DropdownMenuItem<int>(
                        value: (b['CashBoxID'] as num?)?.toInt(),
                        child: Text(
                          '${b['CashBoxName'] ?? ''}${b['CurrentBalance'] != null ? ' — ${_moneyFmt.format(_num(b['CurrentBalance']))} جـ' : ''}',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _boxId = v),
                ),
                if (_installments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.account_balance_rounded,
                          size: 17,
                          color: isDark ? AppColors.gold : AppColors.navy),
                      const SizedBox(width: 6),
                      Text(
                        'مقاصة أقساط السلف (اختياري)',
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.text(isDark),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'حدد الأقساط التي تُخصم من قيمة الدفعة — كامل القسط أو جزء منه (الجزء الباقي يبقى قسطًا معلّقًا). الباقي يُصرف نقدًا للموظف.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final inst in _installments) _allocRow(inst, isDark),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill(isDark),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      children: [
                        _sumRow('قيمة الدفعة', widget.amount, isDark),
                        _sumRow('المخصص للأقساط', _allocTotal, isDark,
                            gold: true),
                        const Divider(height: 14),
                        _sumRow('النقدي للموظف', cash, isDark,
                            strong: true, negative: cash < 0),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _sumRow(String label, double value, bool isDark,
      {bool gold = false, bool strong = false, bool negative = false}) {
    final textTheme = Theme.of(context).textTheme;
    final color = negative
        ? (isDark ? AppColors.errorLight : AppColors.error)
        : gold
            ? (isDark ? AppColors.gold : AppColors.goldDark)
            : AppColors.text(isDark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(isDark),
                fontSize: 12.5,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${_moneyFmt.format(value)} جـ',
            style: textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: strong ? 14 : 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _allocRow(dynamic raw, bool isDark) {
    final inst = Map<String, dynamic>.from(raw as Map);
    final id = (inst['InstallmentId'] as num?)?.toInt() ?? 0;
    final selected = _selected.contains(id);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? (isDark ? AppColors.gold : AppColors.navy).withValues(alpha: 0.07)
            : AppColors.inputFill(isDark).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: selected
              ? (isDark ? AppColors.gold : AppColors.navy)
                  .withValues(alpha: 0.45)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selected.add(id);
                  _allocCtrls[id] = TextEditingController(
                    text: _num(inst['Amount']).toStringAsFixed(2),
                  );
                } else {
                  _selected.remove(id);
                  _allocCtrls.remove(id)?.dispose();
                }
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قسط ${inst['InstallmentNumber']}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.text(isDark),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  '${monthLabel('${inst['DeductionMonth'] ?? ''}')} • ${_moneyFmt.format(_num(inst['Amount']))} جـ',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            SizedBox(
              width: 110,
              child: TextField(
                controller: _allocCtrls[id],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.text(isDark), fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'المخصص',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface(isDark),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
