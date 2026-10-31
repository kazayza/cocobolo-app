import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_colors.dart';
import '../../services/cashbox_service.dart';
import '../../services/design_tokens.dart';
import '../../services/loan_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/design_kit.dart';
import '../../widgets/month_picker.dart';

/// نموذج إنشاء سلفة — صفحة كاملة بهوية التطبيق بدل الحوار القديم.
/// الخزينة إلزامية (عقد الخادم الجديد): بلا اختيار خزينة يُحظر الحفظ
/// برسالة ظاهرة، ورسائل الخادم (اختيار الخزينة/نقص الرصيد) تظهر داخل
/// النموذج كما هي. النجاح يرجع pop(true) لتعيد القائمة التحميل.
class LoanFormScreen extends StatefulWidget {
  final int userId;
  final String username;

  const LoanFormScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  final LoanService _service = LoanService();
  final _moneyFmt = NumberFormat('#,##0.00');

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _countCtrl = TextEditingController(text: '10');
  String _startMonth = DateFormat('yyyy-MM').format(DateTime.now());
  final TextEditingController _purposeCtrl = TextEditingController();

  Map<String, dynamic>? _selectedEmployee;
  List<dynamic> _employeeResults = [];
  bool _searching = false;
  String? _searchError;

  List<Map<String, dynamic>> _cashboxes = [];
  bool _cashboxesLoading = true;
  String? _cashboxesError;
  int? _cashBoxId;

  bool _saving = false;
  String? _formError;
  String? _employeeError;
  String? _amountError;
  String? _countError;
  String? _cashBoxError;

  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _loadCashboxes();
    _amountCtrl.addListener(_refreshPreview);
    _countCtrl.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _countCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;
  int get _count => int.tryParse(_countCtrl.text.trim()) ?? 0;

  /// القسط الشهري المعروض للمعاينة: المبلغ ÷ العدد (القسط الأخير
  /// يمتص الباقي عند التوليد في الخادم — المعاينة تعرض القيمة الشهرية).
  double get _monthlyPreview =>
      (_amount > 0 && _count > 0) ? _amount / _count : 0;

  Future<void> _loadCashboxes() async {
    setState(() {
      _cashboxesLoading = true;
      _cashboxesError = null;
    });
    try {
      final boxes = await CashboxService.getAllCashboxes();
      if (!mounted) return;
      setState(() {
        _cashboxes = boxes
            .where((b) => b['IsActive'] != false)
            .map((b) => Map<String, dynamic>.from(b))
            .toList();
        _cashboxesLoading = false;
        if (_cashboxes.isEmpty) {
          _cashboxesError = 'لا توجد خزائن متاحة للصرف';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cashboxesLoading = false;
        _cashboxesError = 'تعذر تحميل الخزائن: $e';
      });
    }
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final res = await _service.searchEmployees(
        _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _employeeResults = res;
        _searching = false;
        if (res.isEmpty) _searchError = 'لا توجد نتائج مطابقة للبحث';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.toString();
      });
    }
  }

  int _employeeIdOf(Map<String, dynamic> emp) =>
      (emp['EmployeeID'] as num?)?.toInt() ??
      (emp['EmployeeId'] as num?)?.toInt() ??
      0;

  Future<void> _submit() async {
    final empId =
        _selectedEmployee == null ? 0 : _employeeIdOf(_selectedEmployee!);
    // شهر البداية يأتي من منتقي الشهور — صيغته سليمة دائمًا بلا تحقق نصي
    final month = _startMonth;
    setState(() {
      _formError = null;
      _employeeError = empId <= 0 ? 'اختر الموظف من نتائج البحث أولًا' : null;
      _amountError = _amount <= 0 ? 'المبلغ يجب أن يكون أكبر من صفر' : null;
      _countError = _count <= 0 ? 'عدد الأقساط يجب أن يكون أكبر من صفر' : null;
      _cashBoxError = _cashBoxId == null ? 'يرجى اختيار الخزينة' : null;
    });
    if (_employeeError != null ||
        _amountError != null ||
        _countError != null ||
        _cashBoxError != null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.createLoan(
        employeeId: empId,
        amount: _amount,
        totalInstallments: _count,
        startMonth: month,
        cashBoxId: _cashBoxId!,
        purpose: _purposeCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Text(
          'سلفة جديدة',
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
                  title: 'بيانات السلفة',
                  icon: Icons.account_balance_rounded,
                  accent: _isDark ? AppColors.gold : AppColors.navy,
                ),
                const SizedBox(height: 14),
                _buildEmployeePicker(),
                _fieldError(_employeeError),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _amountCtrl,
                        label: 'مبلغ السلفة (جـ)',
                        icon: Icons.payments_rounded,
                        hint: 'مثال: 10000',
                        keyboardType: TextInputType.number,
                        isRequired: true,
                        error: _amountError,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _countCtrl,
                        label: 'عدد الأقساط',
                        icon: Icons.format_list_numbered_rounded,
                        hint: 'مثال: 10',
                        keyboardType: TextInputType.number,
                        isRequired: true,
                        error: _countError,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MonthField(
                    label: 'شهر بداية الخصم',
                    value: _startMonth,
                    isRequired: true,
                    onChanged: (v) {
                      if (v != null) setState(() => _startMonth = v);
                    },
                  ),
                ),
                _buildCashboxField(),
                _fieldError(_cashBoxError),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _purposeCtrl,
                  label: 'الغرض / ملاحظات',
                  icon: Icons.edit_note_rounded,
                  hint: 'اكتب الغرض من السلفة...',
                  maxLines: 2,
                ),
                if (_monthlyPreview > 0) _buildPreview(),
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_isDark
                              ? AppColors.errorLight
                              : AppColors.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _formError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _isDark
                                ? AppColors.errorLight
                                : AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
                  _selectedEmployee?['FullName']?.toString() ?? 'سلفة جديدة',
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _selectedEmployee != null
                      ? '${_selectedEmployee!['Department'] ?? ''} • ${_selectedEmployee!['JobTitle'] ?? ''}'
                      : 'تُصرف من الخزينة المختارة وتُولَّد أقساطها تلقائيًا',
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

  Widget _buildEmployeePicker() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('الموظف', isRequired: true),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: textTheme.bodyLarge
                    ?.copyWith(color: AppColors.text(_isDark)),
                decoration: _inputDecoration(
                  Icons.person_search_rounded,
                  hint: 'ابحث باسم الموظف...',
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _searching ? null : _search,
              style: FilledButton.styleFrom(
                backgroundColor: _isDark ? AppColors.gold : AppColors.navy,
                foregroundColor: _isDark ? AppColors.navy : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: _searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('بحث'),
            ),
          ],
        ),
        if (_searchError != null) _fieldError(_searchError),
        if (_employeeResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: _isDark
                  ? AppColors.card(_isDark)
                  : AppColors.inputFill(_isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _employeeResults.length,
              itemBuilder: (_, i) {
                final emp =
                    Map<String, dynamic>.from(_employeeResults[i] as Map);
                final selected = _selectedEmployee != null &&
                    _employeeIdOf(_selectedEmployee!) == _employeeIdOf(emp) &&
                    _employeeIdOf(emp) > 0;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor:
                      ThemeService().accentColor.withValues(alpha: 0.12),
                  leading: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.person_outline_rounded,
                    size: 19,
                    color: selected
                        ? ThemeService().accentColor
                        : AppColors.textSecondary(_isDark),
                  ),
                  title: Text(
                    '${emp['FullName'] ?? ''}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${emp['Department'] ?? ''} • ${emp['JobTitle'] ?? ''}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontSize: 11,
                    ),
                  ),
                  onTap: () => setState(() {
                    _selectedEmployee = emp;
                    _employeeResults = [];
                    _employeeError = null;
                  }),
                );
              },
            ),
          ),
        ],
        if (_selectedEmployee != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: (_isDark ? AppColors.successLight : AppColors.success)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: _isDark ? AppColors.successLight : AppColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الموظف: ${_selectedEmployee!['FullName'] ?? ''}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textSecondary(_isDark)),
                  onPressed: () => setState(() => _selectedEmployee = null),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCashboxField() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('خزينة الصرف', isRequired: true),
        const SizedBox(height: 6),
        if (_cashboxesLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: _isDark
                  ? AppColors.card(_isDark)
                  : AppColors.inputFill(_isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'جاري تحميل الخزائن...',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else if (_cashboxesError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: (_isDark ? AppColors.errorLight : AppColors.error)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _cashboxesError!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _isDark ? AppColors.errorLight : AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _loadCashboxes,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<int>(
            initialValue: _cashBoxId,
            isExpanded: true,
            decoration: _inputDecoration(Icons.account_balance_wallet_rounded),
            hint: Text(
              'اختر الخزينة',
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textHint(_isDark)),
            ),
            items: _cashboxes.map((b) {
              final balanceRaw = b['CurrentBalance'];
              final balance = balanceRaw is num
                  ? balanceRaw
                  : num.tryParse('${balanceRaw ?? ''}');
              final balanceText = balance != null
                  ? ' — الرصيد ${_moneyFmt.format(balance)} جـ'
                  : '';
              return DropdownMenuItem<int>(
                value: (b['CashBoxID'] as num?)?.toInt(),
                child: Text(
                  '${b['CashBoxName'] ?? ''}$balanceText',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.text(_isDark),
                    fontSize: 13.5,
                  ),
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() {
              _cashBoxId = v;
              _cashBoxError = null;
            }),
          ),
        if (_cashBoxId == null && !_cashboxesLoading && _cashboxesError == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'اختيار الخزينة إلزامي لصرف السلفة — لن يتم الحفظ بدونها',
              style: textTheme.bodySmall?.copyWith(
                color: _isDark ? AppColors.warningLight : AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPreview() {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calculate_rounded,
              size: 19,
              color: _isDark ? AppColors.gold : AppColors.navy,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'القسط الشهري: ${_moneyFmt.format(_monthlyPreview)} جـ × $_count قسطًا (القسط الأخير يستوعب باقي التقريب)',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.text(_isDark),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
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
    TextInputType? keyboardType,
    String? error,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, isRequired: isRequired),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.text(_isDark)),
            decoration: _inputDecoration(icon, hint: hint),
          ),
          _fieldError(error),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label, {bool isRequired = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
                  color: _isDark ? AppColors.errorLight : AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
          ),
      ],
    );
  }

  Widget _fieldError(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        error,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isDark ? AppColors.errorLight : AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppColors.textHint(_isDark)),
      prefixIcon: Icon(icon, size: 19, color: AppColors.textSecondary(_isDark)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  /// شريط سفلي لاصق كحلي بحبة حفظ ذهبية — لغة النماذج المعتمدة
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
                _monthlyPreview > 0
                    ? 'القسط الشهري ${_moneyFmt.format(_monthlyPreview)} جـ'
                    : 'صرف سلفة وتوليد أقساطها',
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
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: AppColors.navy)
                      : Text(
                          'حفظ السلفة',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
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
