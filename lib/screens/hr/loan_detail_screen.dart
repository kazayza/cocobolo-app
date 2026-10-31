import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../services/loan_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/design_kit.dart';
import '../../widgets/identity_dialog.dart';
import '../../widgets/month_picker.dart';
import 'loan_status.dart';

/// تفاصيل سلفة واحدة: مرساة هوية بالمبالغ وشريط التقدم الذهبي، وقائمة
/// الأقساط بإجراءات (تخطي/تقسيم/تعديل) على المعلّقة فقط والسلفة نشطة.
/// كل فشل ظاهر برسالة الخادم كما هي — لا ابتلاع صامت في هذه الشاشة.
class LoanDetailScreen extends StatefulWidget {
  final int loanId;
  final String username;

  const LoanDetailScreen({
    super.key,
    required this.loanId,
    required this.username,
  });

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final LoanService _service = LoanService();
  final _moneyFmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('yyyy/MM/dd');

  Map<String, dynamic>? _loan;
  List<dynamic> _installments = [];
  bool _loading = true;
  String? _error;
  bool _acting = false;

  bool get _isDark => ThemeService().isDarkMode;

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  String _money(dynamic v) => _moneyFmt.format(_num(v));

  String _date(dynamic v) {
    final d = DateTime.tryParse('${v ?? ''}');
    return d == null ? '—' : _dateFmt.format(d);
  }

  bool get _loanActive => _loan?['Status']?.toString() == 'Active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _service.getLoanDetail(widget.loanId);
      if (!mounted) return;
      final loan = detail['Loan'];
      setState(() {
        _loan = loan is Map ? Map<String, dynamic>.from(loan) : null;
        _installments =
            detail['Installments'] is List ? detail['Installments'] as List : [];
        _loading = false;
        if (_loan == null) _error = 'السلفة غير موجودة';
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

  Future<void> _cancelLoan() async {
    final loan = _loan;
    if (loan == null) return;
    final confirmed = await showIdentityConfirmDialog(
      context: context,
      icon: Icons.cancel_rounded,
      title: 'إلغاء السلفة',
      subtitle: loan['EmployeeName']?.toString(),
      message:
          'سيتم إلغاء سلفة ${loan['EmployeeName'] ?? ''} بمبلغ ${_money(loan['LoanAmount'])} جـ وعكس أثرها المالي إن صُرفت من خزينة. متابعة؟',
      confirmLabel: 'إلغاء السلفة',
      danger: true,
    );
    if (!confirmed) return;
    setState(() => _acting = true);
    try {
      final res = await _service.cancelLoan(widget.loanId, widget.username);
      if (!mounted) return;
      _snack(res['message']?.toString() ?? 'تم إلغاء السلفة وعكس الأثر المالي');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      _snack(e.toString(), error: true);
    }
  }

  /// حوار إجراء على قسط — الحوار يملك وحدات تحكّمه داخل حالته ويحرّرها
  /// في dispose الخاصة به بعد زوال مساره تمامًا (إصلاح الشاشة الحمراء:
  /// تحرير الوحدات فور اكتمال مستقبل showDialog كان يحدث أثناء حركة
  /// خروج الحوار وهي ما زالت مبنية فوقها). يرجع خريطة القيم عند
  /// التأكيد أو null عند التراجع بأي مسار (زر الرجوع مشمول).
  Future<Map<String, String>?> _actionDialog({
    required _InstAction action,
    required Map<String, dynamic> inst,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _InstallmentActionDialog(action: action, inst: inst),
    );
  }

  Future<void> _runInstallmentAction(
    Future<Map<String, dynamic>> Function() call,
  ) async {
    setState(() => _acting = true);
    try {
      final res = await call();
      if (!mounted) return;
      setState(() => _acting = false);
      _snack(res['message']?.toString() ?? 'تم تنفيذ الإجراء بنجاح');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _skipInstallment(Map<String, dynamic> inst) async {
    final id = (inst['InstallmentId'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    final values = await _actionDialog(action: _InstAction.skip, inst: inst);
    if (values == null) return;
    await _runInstallmentAction(() => _service.skipInstallment(
          id,
          reason: values['reason'],
          targetMonth: values['targetMonth'],
        ));
  }

  Future<void> _splitInstallment(Map<String, dynamic> inst) async {
    final id = (inst['InstallmentId'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    final values = await _actionDialog(action: _InstAction.split, inst: inst);
    if (values == null) return;
    // التحقق الرقمي الكامل تم داخل الحوار نفسه قبل الإغلاق
    final keep = double.tryParse(values['amountToKeep'] ?? '') ?? 0;
    await _runInstallmentAction(() => _service.splitInstallment(
          id,
          amountToKeep: keep,
          reason: values['reason'],
          targetMonth: values['targetMonth'],
        ));
  }

  Future<void> _updateInstallment(Map<String, dynamic> inst) async {
    final id = (inst['InstallmentId'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    final values = await _actionDialog(action: _InstAction.update, inst: inst);
    if (values == null) return;
    final amountText = values['newAmount'] ?? '';
    final newAmount = amountText.isEmpty ? null : double.tryParse(amountText);
    await _runInstallmentAction(() => _service.updateInstallment(
          id,
          newAmount: newAmount,
          newMonth: values['newMonth'],
          notes: values['notes'],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Text(
          'تفاصيل السلفة',
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
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppLoading();
    if (_error != null) {
      return AppError(message: _error!, onRetry: _load);
    }
    final loan = _loan!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildAnchor(loan),
        const SizedBox(height: 16),
        AppSectionHeader(
          title: 'الأقساط',
          subtitle: '${_installments.length} قسطًا',
          icon: Icons.format_list_numbered_rounded,
          accent: _isDark ? AppColors.gold : AppColors.navy,
        ),
        const SizedBox(height: 10),
        if (_installments.isEmpty)
          const AppEmpty(message: 'لا توجد أقساط لهذه السلفة')
        else
          ..._installments.map((e) =>
              _installmentRow(Map<String, dynamic>.from(e as Map))),
      ],
    );
  }

  Widget _buildAnchor(Map<String, dynamic> loan) {
    final textTheme = Theme.of(context).textTheme;
    final total = _num(loan['LoanAmount']);
    final paid = loan['PaidAmount'] != null
        ? _num(loan['PaidAmount'])
        : (total - _num(loan['RemainingAmount']));
    final ratio = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final status = loan['Status']?.toString();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan['EmployeeName']?.toString() ?? '—',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${loan['Department'] ?? ''} • ${loan['JobTitle'] ?? ''}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.goldLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: loanStatusLabel(status),
                color: loanStatusColor(status, true),
                icon: loanStatusIcon(status),
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'إجمالي السلفة',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.goldLight,
              fontSize: 11.5,
            ),
          ),
          AmountText(
            value: '${_money(loan['LoanAmount'])} جـ',
            color: Colors.white,
            size: 26,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _anchorFigure('المدفوع', '${_money(paid)} جـ'),
              _anchorFigure('المتبقي', '${_money(loan['RemainingAmount'])} جـ'),
              _anchorFigure(
                  'القسط الشهري', '${_money(loan['MonthlyInstallment'])} جـ'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _anchorMeta(Icons.calendar_month_rounded,
                  'بداية الخصم: ${loan['StartDeductionMonth'] ?? '—'}'),
              _anchorMeta(Icons.event_rounded,
                  'تاريخ السلفة: ${_date(loan['LoanDate'])}'),
              if ((loan['CashBoxName']?.toString() ?? '').isNotEmpty)
                _anchorMeta(Icons.account_balance_wallet_rounded,
                    'الخزينة: ${loan['CashBoxName']}'),
              _anchorMeta(Icons.format_list_numbered_rounded,
                  'الأقساط: ${loan['PaidInstallments'] ?? 0} من ${loan['TotalInstallments'] ?? 0} مدفوعة • ${((loan['TotalInstallments'] as num?)?.toInt() ?? 0) - ((loan['PaidInstallments'] as num?)?.toInt() ?? 0)} متبقية'),
            ],
          ),
          if ((loan['Notes']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              loan['Notes'].toString(),
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
          if (_loanActive) ...[
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: _acting ? null : _cancelLoan,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                ),
                icon: const Icon(Icons.cancel_rounded, size: 17),
                label: Text(
                  'إلغاء السلفة',
                  style: textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _anchorFigure(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.goldLight,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          AmountText(value: value, color: Colors.white, size: 14),
        ],
      ),
    );
  }

  Widget _anchorMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11.5,
              ),
        ),
      ],
    );
  }

  Widget _installmentRow(Map<String, dynamic> inst) {
    final textTheme = Theme.of(context).textTheme;
    final status = inst['Status']?.toString();
    final canAct = _loanActive && status == 'Pending';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: AppColors.surface(_isDark),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (_isDark ? AppColors.gold : AppColors.navy)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${inst['InstallmentNumber'] ?? '—'}',
                    style: textTheme.titleSmall?.copyWith(
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
                        'قسط شهر ${inst['DeductionMonth'] ?? '—'}',
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.text(_isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      if ((inst['PayrollMonth']?.toString() ?? '').isNotEmpty)
                        Text(
                          'شهر الرواتب: ${inst['PayrollMonth']}',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(_isDark),
                            fontSize: 11,
                          ),
                        ),
                      if (inst['DeductionDate'] != null)
                        Text(
                          'تاريخ الخصم: ${_date(inst['DeductionDate'])}',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(_isDark),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                AmountText(
                  value: '${_money(inst['Amount'])} جـ',
                  color: AppColors.text(_isDark),
                  size: 14,
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  label: installmentStatusLabel(status),
                  color: installmentStatusColor(status, _isDark),
                  icon: installmentStatusIcon(status),
                  small: true,
                ),
              ],
            ),
            if ((inst['Notes']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                inst['Notes'].toString(),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 11.5,
                ),
              ),
            ],
            if (canAct) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _actionPill(
                    label: 'تخطي / تأجيل',
                    icon: Icons.schedule_rounded,
                    onTap: _acting ? null : () => _skipInstallment(inst),
                  ),
                  const SizedBox(width: 8),
                  _actionPill(
                    label: 'تقسيم',
                    icon: Icons.call_split_rounded,
                    onTap: _acting ? null : () => _splitInstallment(inst),
                  ),
                  const SizedBox(width: 8),
                  _actionPill(
                    label: 'تعديل',
                    icon: Icons.edit_rounded,
                    onTap: _acting ? null : () => _updateInstallment(inst),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionPill({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final color = _isDark ? AppColors.gold : AppColors.navy;
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
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
}

/// أنواع إجراءات القسط الثلاثة
enum _InstAction { skip, split, update }

/// حوار إجراء على قسط واحد (تخطٍّ/تقسيم/تعديل) بهيكل الحوارات الموحّد.
/// وحدات التحكّم مملوكة لحالة هذا الحوار وتُحرَّر في dispose الخاصة
/// بها بعد زوال مسار الحوار من الشجرة تمامًا — هذا هو الإصلاح الجذري
/// للشاشة الحمراء التي كانت تظهر عند الرجوع دون حفظ. الشهر يُختار من
/// منتقي الشهور التقويمي، والتحقق يظهر داخل الحوار بلون الخطأ.
class _InstallmentActionDialog extends StatefulWidget {
  final _InstAction action;
  final Map<String, dynamic> inst;

  const _InstallmentActionDialog({required this.action, required this.inst});

  @override
  State<_InstallmentActionDialog> createState() =>
      _InstallmentActionDialogState();
}

class _InstallmentActionDialogState extends State<_InstallmentActionDialog> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _textCtrl = TextEditingController();

  /// الشهر المختار من المنتقي (targetMonth في التخطي/التقسيم، و
  /// newMonth في التعديل) — null يعني «بلا تغيير/الافتراضي»
  String? _month;
  String? _error;

  bool get _isDark => ThemeService().isDarkMode;

  double get _instAmount {
    final v = widget.inst['Amount'];
    return v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
  }

  String get _moneyText =>
      NumberFormat('#,##0.00').format(_instAmount);

  @override
  void dispose() {
    _amountCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  (IconData, String, String) get _head {
    final n = widget.inst['InstallmentNumber'] ?? '';
    return switch (widget.action) {
      _InstAction.skip => (
          Icons.schedule_rounded,
          'تخطي / تأجيل القسط رقم $n',
          'تأجيل القسط',
        ),
      _InstAction.split => (
          Icons.call_split_rounded,
          'تقسيم القسط رقم $n',
          'تقسيم القسط',
        ),
      _InstAction.update => (
          Icons.edit_rounded,
          'تعديل القسط رقم $n',
          'حفظ التعديل',
        ),
    };
  }

  void _submit() {
    final amountText = _amountCtrl.text.trim();
    final text = _textCtrl.text.trim();
    switch (widget.action) {
      case _InstAction.skip:
        Navigator.pop(context, {
          'targetMonth': _month ?? '',
          'reason': text,
        });
      case _InstAction.split:
        final keep = double.tryParse(amountText);
        if (keep == null || keep <= 0) {
          setState(() => _error = 'المبلغ المُبقى يجب أن يكون أكبر من صفر');
          return;
        }
        if (keep >= _instAmount) {
          setState(() => _error =
              'المبلغ المُبقى يجب أن يكون أقل من مبلغ القسط ($_moneyText جـ) — للترحيل الكامل استخدم «تخطي / تأجيل»');
          return;
        }
        Navigator.pop(context, {
          'amountToKeep': amountText,
          'targetMonth': _month ?? '',
          'reason': text,
        });
      case _InstAction.update:
        if (amountText.isNotEmpty) {
          final na = double.tryParse(amountText);
          if (na == null || na <= 0) {
            setState(() => _error = 'المبلغ الجديد يجب أن يكون أكبر من صفر');
            return;
          }
        }
        if (amountText.isEmpty && _month == null && text.isEmpty) {
          setState(() => _error = 'يرجى إدخال تعديل واحد على الأقل');
          return;
        }
        Navigator.pop(context, {
          'newAmount': amountText,
          'newMonth': _month ?? '',
          'notes': text,
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, title, confirmLabel) = _head;
    final currentMonthText =
        monthLabel(widget.inst['DeductionMonth']?.toString());
    return IdentityDialog(
      icon: icon,
      title: title,
      subtitle:
          'قسط شهر $currentMonthText • المبلغ $_moneyText جـ',
      errorText: _error,
      actions: [
        IdentityDialogAction(
          label: 'تراجع',
          onPressed: () => Navigator.pop(context),
        ),
        IdentityDialogAction(
          label: confirmLabel,
          filled: true,
          onPressed: _submit,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (widget.action) {
          _InstAction.skip => [
              MonthField(
                label: 'الشهر الهدف — اختياري',
                value: _month,
                hint: 'الافتراضي: بعد آخر قسط في السلفة',
                clearable: true,
                onChanged: (v) => setState(() {
                  _month = v;
                  _error = null;
                }),
              ),
              const SizedBox(height: 14),
              _DialogTextField(
                controller: _textCtrl,
                label: 'السبب — اختياري',
                hint: 'سبب التأجيل',
                isDark: _isDark,
              ),
            ],
          _InstAction.split => [
              _DialogTextField(
                controller: _amountCtrl,
                label: 'المبلغ المُبقى في هذا الشهر (جـ)',
                hint: 'أقل من مبلغ القسط $_moneyText',
                keyboardType: TextInputType.number,
                isRequired: true,
                isDark: _isDark,
              ),
              const SizedBox(height: 14),
              MonthField(
                label: 'شهر نقل الباقي — اختياري',
                value: _month,
                hint: 'الافتراضي: الشهر التالي لشهر القسط',
                clearable: true,
                onChanged: (v) => setState(() {
                  _month = v;
                  _error = null;
                }),
              ),
              const SizedBox(height: 14),
              _DialogTextField(
                controller: _textCtrl,
                label: 'السبب — اختياري',
                hint: 'سبب التقسيم',
                isDark: _isDark,
              ),
            ],
          _InstAction.update => [
              _DialogTextField(
                controller: _amountCtrl,
                label: 'المبلغ الجديد (جـ) — اختياري',
                hint: 'الحالي $_moneyText',
                keyboardType: TextInputType.number,
                isDark: _isDark,
              ),
              const SizedBox(height: 14),
              MonthField(
                label: 'الشهر الجديد — اختياري',
                value: _month,
                hint: 'الحالي: $currentMonthText',
                clearable: true,
                onChanged: (v) => setState(() {
                  _month = v;
                  _error = null;
                }),
              ),
              const SizedBox(height: 14),
              _DialogTextField(
                controller: _textCtrl,
                label: 'ملاحظات — اختيارية',
                hint: 'ملاحظات التعديل',
                isDark: _isDark,
              ),
            ],
        },
      ),
    );
  }
}

/// حقل نصي داخل حوارات الأقساط: عنوان فوق حقل ممتلئ بنصف قطر 12
class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool isRequired;
  final bool isDark;

  const _DialogTextField({
    required this.controller,
    required this.label,
    required this.isDark,
    this.hint,
    this.keyboardType,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary(isDark),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: textTheme.labelLarge?.copyWith(
                  color: isDark ? AppColors.errorLight : AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: textTheme.bodyLarge
              ?.copyWith(color: AppColors.text(isDark), fontSize: 14.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: textTheme.bodyMedium
                ?.copyWith(color: AppColors.textHint(isDark)),
            filled: true,
            fillColor:
                isDark ? AppColors.card(isDark) : AppColors.inputFill(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: ThemeService().accentColor),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          ),
        ),
      ],
    );
  }
}
