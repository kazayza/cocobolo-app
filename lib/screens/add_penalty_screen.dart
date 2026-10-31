import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../core/network/api_client.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/penalty_service.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import '../widgets/employee_picker.dart';

/// نموذج جزاء جديد: موظف ← نوع (أيام/مبلغ مقطوع) ← القيمة ← السبب ←
/// الشهر المستهدف، مع محاكاة حية لقيمة الخصم من نقطة /preview —
/// فشل المحاكاة يُخفيها فقط ولا يمنع الحفظ أبدًا.
class AddPenaltyScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? preselectedEmployeeId;
  final String? preselectedEmployeeName;
  final String? preselectedEmployeeJob;

  const AddPenaltyScreen({
    super.key,
    required this.userId,
    required this.username,
    this.preselectedEmployeeId,
    this.preselectedEmployeeName,
    this.preselectedEmployeeJob,
  });

  @override
  State<AddPenaltyScreen> createState() => _AddPenaltyScreenState();
}

class _AddPenaltyScreenState extends State<AddPenaltyScreen> {
  final _service = PenaltyService();
  final _moneyFmt = intl.NumberFormat('#,##0.00');

  final _daysController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  List<EmployeeOption> _employees = [];
  EmployeeOption? _employee;
  String _type = 'Days';
  late String _month;
  Map<String, dynamic>? _preview;
  bool _previewLoading = false;
  bool _submitting = false;
  Timer? _debounce;

  bool get _isDark => ThemeService().isDarkMode;
  bool get _employeeLocked => widget.preselectedEmployeeId != null;

  static const List<String> _monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static String _monthString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _month = _monthString(DateTime.now());
    if (_employeeLocked) {
      _employee = EmployeeOption(
        id: widget.preselectedEmployeeId!,
        name: widget.preselectedEmployeeName ?? '',
        jobTitle: widget.preselectedEmployeeJob ?? '',
      );
    } else {
      _loadEmployees();
    }
    _daysController.addListener(_schedulePreview);
    _amountController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _daysController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final employees = await fetchActiveEmployeeOptions();
    if (!mounted) return;
    setState(() => _employees = employees);
  }

  double get _days => double.tryParse(_daysController.text.trim()) ?? 0;
  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  /// جدولة محاكاة الأيام: استدعاء مؤجل (نصف ثانية) عند تغيّر الموظف
  /// أو الشهر أو عدد الأيام — فشلها يُخفي المعاينة فقط
  void _schedulePreview() {
    if (mounted) setState(() {});
    _debounce?.cancel();
    if (_type != 'Days' || _employee == null || _days <= 0) {
      if (mounted) setState(() => _preview = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), _fetchPreview);
  }

  Future<void> _fetchPreview() async {
    final employee = _employee;
    if (employee == null || _days <= 0) return;
    setState(() => _previewLoading = true);
    final result = await _service.preview(
      employeeId: employee.id,
      month: _month,
      days: _days,
    );
    if (!mounted) return;
    setState(() {
      _preview = result;
      _previewLoading = false;
    });
  }

  Future<void> _pickEmployee() async {
    final picked = await showEmployeePickerSheet(
      context,
      employees: _employees,
      title: 'اختر الموظف',
    );
    if (picked == null) return;
    setState(() => _employee = picked);
    _schedulePreview();
  }

  Future<void> _pickMonth() async {
    var year = int.tryParse(_month.substring(0, 4)) ?? DateTime.now().year;
    var month = int.tryParse(_month.substring(5, 7)) ?? DateTime.now().month;
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final textTheme = Theme.of(context).textTheme;
          return AlertDialog(
            backgroundColor: AppColors.surface(_isDark),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'الشهر المستهدف',
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.text(_isDark),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: AppColors.textSecondary(_isDark),
                      onPressed: () => setDialogState(() => year--),
                    ),
                    Text(
                      '$year',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.text(_isDark),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      color: AppColors.textSecondary(_isDark),
                      onPressed: () => setDialogState(() => year++),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var m = 1; m <= 12; m++)
                      ChoiceChip(
                        label: Text(_monthNames[m - 1]),
                        selected: month == m,
                        onSelected: (_) => setDialogState(() => month = m),
                        labelStyle: textTheme.labelMedium?.copyWith(
                          color: month == m
                              ? (_isDark ? AppColors.navy : Colors.white)
                              : AppColors.textSecondary(_isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        selectedColor: _isDark ? AppColors.gold : AppColors.navy,
                        backgroundColor: AppColors.surface(_isDark),
                        side: BorderSide(color: AppColors.divider(_isDark)),
                        showCheckmark: false,
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'إلغاء',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  '$year-${month.toString().padLeft(2, '0')}',
                ),
                child: Text(
                  'تأكيد',
                  style: textTheme.labelLarge?.copyWith(
                    color: _isDark ? AppColors.gold : AppColors.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (picked == null) return;
    setState(() => _month = picked);
    _schedulePreview();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _submit() async {
    if (_employee == null) {
      _showError('اختر الموظف أولًا');
      return;
    }
    if (_type == 'Days' && _days <= 0) {
      _showError('أدخل عدد أيام أكبر من صفر');
      return;
    }
    if (_type == 'Amount' && _amount <= 0) {
      _showError('أدخل مبلغًا أكبر من صفر');
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      _showError('سبب الجزاء مطلوب');
      return;
    }

    setState(() => _submitting = true);
    try {
      final row = await _service.create(
        employeeId: _employee!.id,
        type: _type,
        daysCount: _type == 'Days' ? _days : null,
        fixedAmount: _type == 'Amount' ? _amount : null,
        reason: _reasonController.text.trim(),
        targetMonth: _month,
      );
      if (!mounted) return;
      final status = row['status']?.toString();
      final targetMonth = row['targetMonth']?.toString() ?? _month;
      final rolledFrom = row['rolledFrom']?.toString();
      final String message;
      if (status == 'Approved') {
        message = 'سُجّل الجزاء واعتُمد فورًا وسيُخصم من مرتب $targetMonth'
            '${rolledFrom != null && rolledFrom.isNotEmpty ? ' — نُقل من شهر $rolledFrom لأن راتبه محفوظ' : ''}';
      } else {
        message = 'سُجّل الجزاء وهو بانتظار اعتماد صاحب التوقيع المباشر';
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface(_isDark),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 56),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodyLarge?.copyWith(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'تم',
                style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(
                      color: _isDark ? AppColors.gold : AppColors.navy,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('فشل الاتصال بالسيرفر');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Text(
          'جزاء جديد',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBar: _buildSaveBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildAnchorHeader(),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.surface(_isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionHeader(
                  title: 'بيانات الجزاء',
                  icon: Icons.gavel_rounded,
                  accent: _isDark ? AppColors.gold : AppColors.navy,
                ),
                const SizedBox(height: 14),
                EmployeePickerField(
                  label: 'الموظف *',
                  selected: _employee,
                  locked: _employeeLocked,
                  onTap: _pickEmployee,
                ),
                const SizedBox(height: 14),
                _buildTypeSegment(),
                const SizedBox(height: 14),
                if (_type == 'Days')
                  _buildNumberField(
                    controller: _daysController,
                    label: 'عدد الأيام',
                    icon: Icons.calendar_month_rounded,
                    hint: 'مثال: 0.5 أو 1 أو 2',
                  )
                else
                  _buildNumberField(
                    controller: _amountController,
                    label: 'المبلغ المقطوع (جـ)',
                    icon: Icons.payments_rounded,
                    hint: 'مثال: 500',
                  ),
                const SizedBox(height: 2),
                _buildTextField(
                  controller: _reasonController,
                  label: 'سبب الجزاء',
                  icon: Icons.edit_note_rounded,
                  hint: 'اكتب سبب الجزاء...',
                  maxLines: 3,
                  isRequired: true,
                ),
                _buildMonthField(),
              ],
            ),
          ),
          ..._buildPreviewPanel(),
        ],
      ),
    );
  }

  Widget _buildAnchorHeader() {
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.gavel_rounded,
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
                  _employee?.name ?? 'تسجيل جزاء',
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _employee != null && _employee!.subtitle.isNotEmpty
                      ? _employee!.subtitle
                      : 'خصم من مرتب الشهر المستهدف بعد الاعتماد',
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
    );
  }

  /// محكّم نوع الجزاء: حاويتان متجاورتان (أيام | مبلغ مقطوع) على نمط
  /// محكّم حالة الموظف في نموذج الموظف
  Widget _buildTypeSegment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع الجزاء',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary(_isDark),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isDark
                ? AppColors.card(_isDark)
                : AppColors.inputFill(_isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildTypeOption('Days', 'أيام'),
              _buildTypeOption('Amount', 'مبلغ مقطوع'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeOption(String value, String label) {
    final selected = _type == value;
    final color = _isDark ? AppColors.gold : AppColors.navy;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _type = value);
          _schedulePreview();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: _isDark ? 0.22 : 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected ? Border.all(color: color) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? color : AppColors.textSecondary(_isDark),
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textHint(_isDark),
          ),
      prefixIcon: Icon(
        icon,
        size: 19,
        color: AppColors.textSecondary(_isDark),
      ),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                ' *',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _isDark ? AppColors.errorLight : AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.text(_isDark),
                ),
            decoration: _inputDecoration(icon, hint: hint),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color:
                            _isDark ? AppColors.errorLight : AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.text(_isDark),
                ),
            decoration: _inputDecoration(icon, hint: hint),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthField() {
    final textTheme = Theme.of(context).textTheme;
    final monthNum = int.tryParse(_month.substring(5, 7)) ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الشهر المستهدف',
          style: textTheme.labelLarge?.copyWith(
            color: AppColors.textSecondary(_isDark),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickMonth,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: _isDark
                  ? AppColors.card(_isDark)
                  : AppColors.inputFill(_isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 19,
                  color: AppColors.textSecondary(_isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$_month (${_monthNames[monthNum - 1]})',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.text(_isDark),
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary(_isDark),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// لوحة المحاكاة الحية: للأيام من نقطة /preview عند توفرها (تُخفى
  /// عند فشلها)، وللمبلغ المقطوع نص مباشر من القيمة المدخلة
  List<Widget> _buildPreviewPanel() {
    final textTheme = Theme.of(context).textTheme;
    String? text;
    if (_type == 'Amount') {
      if (_amount > 0) {
        text = 'سيُخصم مبلغ ${_moneyFmt.format(_amount)} جـ من مرتب شهر $_month';
      }
    } else if (_preview != null && _employee != null && _days > 0) {
      final dayValue = (_preview!['dayValue'] as num?)?.toDouble() ??
          double.tryParse('${_preview!['dayValue'] ?? ''}') ??
          0;
      final computed = (_preview!['computedAmount'] as num?)?.toDouble() ??
          double.tryParse('${_preview!['computedAmount'] ?? ''}') ??
          0;
      text = 'قيمة اليوم: ${_moneyFmt.format(dayValue)} جـ × '
          '${formatPenaltyDays(_days)} يوم = ${_moneyFmt.format(computed)} جـ '
          '— سيُخصم من مرتب شهر $_month';
    }
    if (text == null && !_previewLoading) return const [];
    return [
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: _isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.calculate_rounded,
              size: 19,
              color: _isDark ? AppColors.gold : AppColors.navy,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _previewLoading && text == null
                  ? Text(
                      'جارٍ حساب قيمة الخصم...',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 13,
                      ),
                    )
                  : Text(
                      text ?? '',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.text(_isDark),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ];
  }

  /// شريط سفلي لاصق كحلي بحبة حفظ ذهبية — لغة نموذج الموظف المعتمدة
  Widget _buildSaveBar() {
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                _type == 'Days' ? 'خصم أيام من المرتب' : 'خصم مبلغ مقطوع',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.goldLight,
                      fontSize: 12,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gold, AppColors.goldLight],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: _submitting
                      ? const CircularProgressIndicator(color: AppColors.navy)
                      : Text(
                          'حفظ الجزاء',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.navy,
                                  ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
