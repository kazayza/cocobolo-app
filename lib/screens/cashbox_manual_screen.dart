import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/cashbox_service.dart';
import '../services/permission_service.dart';
import '../widgets/design_kit.dart';

class CashboxManualScreen extends StatefulWidget {
  final int? userId;
  final String? username;

  const CashboxManualScreen({
    Key? key,
    this.userId,
    this.username,
  }) : super(key: key);

  @override
  State<CashboxManualScreen> createState() => _CashboxManualScreenState();
}

class _CashboxManualScreenState extends State<CashboxManualScreen> {
  // البيانات
  List<Map<String, dynamic>> cashboxes = [];
  bool loading = true;
  bool saving = false;
  String? loadError;

  // أسطح واعية بالوضع من AppColors/ThemeService (قاعدة الهوية)
  bool get _isDark => ThemeService().isDarkMode;
  Color get _textColor => AppColors.text(_isDark);
  Color get _secondaryColor => AppColors.textSecondary(_isDark);
  Color get _hintColor => AppColors.textHint(_isDark);
  Color get _fillColor => AppColors.inputFill(_isDark);
  Color get _borderColor => AppColors.divider(_isDark);
  Color get _surfaceColor => AppColors.surface(_isDark);

  // الحقول
  String selectedOperationType = 'ManualReceipt';
  int? selectedCashboxFrom;
  int? selectedCashboxTo;
  int? selectedPersonalAccountId;
  List<Map<String, dynamic>> personalAccounts = [];
  double? currentBalance;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController recipientController = TextEditingController();
  DateTime selectedDate = DateTime.now();

  // الأنواع الستة — DTOS/CashBoxDto.cs ManualOperationTypes (Item 25)
  final List<Map<String, dynamic>> operationTypes = [
    {'value': 'ManualReceipt', 'label': 'سند قبض يدوي', 'icon': Icons.arrow_downward, 'color': AppColors.success},
    {'value': 'ManualPayment', 'label': 'سند صرف يدوي', 'icon': Icons.arrow_upward, 'color': AppColors.error},
    {'value': 'LoanIn', 'label': 'قرض دخل من شخص', 'icon': Icons.handshake, 'color': AppColors.info},
    {'value': 'LoanRepayment', 'label': 'تسديد قرض لشخص', 'icon': Icons.payments, 'color': AppColors.warning},
    {'value': 'Transfer', 'label': 'تحويل بين خزن', 'icon': Icons.swap_horiz, 'color': AppColors.gold},
    {'value': 'OpeningBalance', 'label': 'رصيد افتتاحي', 'icon': Icons.stars, 'color': AppColors.navyLight},
  ];

  bool get _isLoan =>
      selectedOperationType == 'LoanIn' ||
      selectedOperationType == 'LoanRepayment';
  bool get _isOut =>
      selectedOperationType == 'ManualPayment' ||
      selectedOperationType == 'LoanRepayment' ||
      selectedOperationType == 'Transfer';
  bool get _needsRecipient =>
      selectedOperationType == 'ManualReceipt' ||
      selectedOperationType == 'ManualPayment';

  Color get _opColor {
    for (final t in operationTypes) {
      if (t['value'] == selectedOperationType) return t['color'] as Color;
    }
    return AppColors.success;
  }

  IconData get _opIcon {
    for (final t in operationTypes) {
      if (t['value'] == selectedOperationType) return t['icon'] as IconData;
    }
    return Icons.receipt_long;
  }

  String get _opLabel {
    for (final t in operationTypes) {
      if (t['value'] == selectedOperationType) return t['label'] as String;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadCashboxes();
    _loadPersonalAccounts();
  }

  Future<void> _loadPersonalAccounts() async {
    try {
      final data = await CashboxService.getPersonalAccounts();
      if (!mounted) return;
      setState(() => personalAccounts = data);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    notesController.dispose();
    recipientController.dispose();
    super.dispose();
  }

  // الخزن النشطة فقط لقائمة الاختيار — مطابقة لبلازور (Item 3)
  Future<void> _loadCashboxes() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final data = await CashboxService.getActiveCashboxes();
      if (!mounted) return;
      setState(() {
        cashboxes = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadError = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _loadBalance(int cashboxId) async {
    try {
      final balance = await CashboxService.getCashboxBalance(cashboxId);
      if (!mounted) return;
      setState(() {
        currentBalance = balance;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => currentBalance = null);
      _showError(e.toString());
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    // التحقق من البيانات
    if (selectedCashboxFrom == null) {
      _showError('اختر الخزنة');
      return;
    }

    if (selectedOperationType == 'Transfer' && selectedCashboxTo == null) {
      _showError('اختر الخزنة المستقبلة');
      return;
    }

    if (selectedOperationType == 'Transfer' &&
        selectedCashboxFrom == selectedCashboxTo) {
      _showError('الخزنة المصدر والمستقبلة يجب أن تكونا مختلفتين');
      return;
    }

    if (_isLoan && selectedPersonalAccountId == null) {
      _showError('يرجى اختيار الحساب الشخصي');
      return;
    }

    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      _showError('أدخل مبلغاً صحيحاً أكبر من صفر');
      return;
    }

    // التحقق من الرصيد للعمليات الصادرة (الخادم يفرضه أيضًا)
    if (_isOut && currentBalance != null && amount > currentBalance!) {
      _showError('المبلغ أكبر من الرصيد المتاح');
      return;
    }

    setState(() => saving = true);

    try {
      final result = await CashboxService.createManualOperation(
        operationType: selectedOperationType,
        cashBoxId: selectedCashboxFrom!,
        toCashBoxId:
            selectedOperationType == 'Transfer' ? selectedCashboxTo : null,
        personalAccountId: _isLoan ? selectedPersonalAccountId : null,
        amount: amount,
        notes: notesController.text,
        recipient: _needsRecipient && recipientController.text.trim().isNotEmpty
            ? recipientController.text.trim()
            : null,
        transactionDate: selectedDate,
        createdBy: PermissionService().username ?? widget.username ?? 'System',
      );

      setState(() => saving = false);

      if (result['success'] == true) {
        _showSuccess(result['message'] ?? 'تم تسجيل العملية بنجاح');
        _clearForm();
        if (selectedCashboxFrom != null) {
          _loadBalance(selectedCashboxFrom!);
        }
      } else {
        _showError(result['message'] ?? 'فشل تسجيل العملية');
      }
    } catch (e) {
      setState(() => saving = false);
      _showError('حدث خطأ: $e');
    }
  }

  void _clearForm() {
    setState(() {
      amountController.clear();
      notesController.clear();
      recipientController.clear();
      selectedCashboxTo = null;
      selectedPersonalAccountId = null;
      selectedDate = DateTime.now();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: _buildAppBar(),
      body: loading
          ? _buildLoadingState()
          : (loadError != null && cashboxes.isEmpty)
              ? AppError(message: loadError!, onRetry: _loadCashboxes)
              : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTransactionTypeSelector(),
                  const SizedBox(height: 20),
                  _buildCashboxFromDropdown(),
                  const SizedBox(height: 16),
                  if (selectedOperationType == 'Transfer') ...[
                    _buildCashboxToDropdown(),
                    const SizedBox(height: 16),
                  ],
                  if (_isLoan) ...[
                    _buildPersonalAccountDropdown(),
                    const SizedBox(height: 16),
                  ],
                  if (_needsRecipient) ...[
                    _buildRecipientField(),
                    const SizedBox(height: 16),
                  ],
                  _buildBalanceCard(),
                  const SizedBox(height: 20),
                  _buildAmountField(),
                  const SizedBox(height: 16),
                  _buildDateField(),
                  const SizedBox(height: 16),
                  _buildNotesField(),
                  const SizedBox(height: 30),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'حركة خزينة يدوية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildTransactionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع العملية',
          style: TextStyle(
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.35,
          children: operationTypes.map((type) {
            final isSelected = selectedOperationType == type['value'];
            final Color color = type['color'];
            // الذهبي الصافي لا يُقرأ نصًا على سطح فاتح — يُستبدل بدرجته الداكنة نهارًا
            final Color selectedColor = isSelected &&
                    !_isDark &&
                    color == AppColors.gold
                ? AppColors.goldDark
                : color;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedOperationType = type['value'];
                  if (type['value'] != 'Transfer') {
                    selectedCashboxTo = null;
                  }
                  if (type['value'] != 'LoanIn' &&
                      type['value'] != 'LoanRepayment') {
                    selectedPersonalAccountId = null;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.15) : _fillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : _borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type['icon'],
                      color: isSelected ? selectedColor : _secondaryColor,
                      size: 22,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      type['label'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? selectedColor : _secondaryColor,
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildPersonalAccountDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الحساب الشخصي',
          style: TextStyle(
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedPersonalAccountId,
              hint: Text(
                'اختر الحساب الشخصي',
                style: TextStyle(color: _secondaryColor, fontSize: 14),
              ),
              dropdownColor: _surfaceColor,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.gold),
              items: personalAccounts.map((a) => DropdownMenuItem<int?>(
                value: (a['PersonalAccountId'] as num?)?.toInt(),
                child: Text(
                  a['AccountName'] ?? '',
                  style: TextStyle(color: _textColor, fontSize: 14),
                ),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  selectedPersonalAccountId = value;
                });
              },
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms).slideY(begin: -0.1);
  }

  Widget _buildRecipientField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المستلم (اختياري)',
          style: TextStyle(
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: TextField(
            controller: recipientController,
            style: TextStyle(color: _textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'اسم المستلم...',
              hintStyle: TextStyle(color: _hintColor, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 175.ms).slideY(begin: -0.1);
  }

  Widget _buildCashboxFromDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedOperationType == 'Transfer' ? 'من خزنة' : 'الخزنة',
          style: TextStyle(
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedCashboxFrom,
              hint: Text(
                'اختر الخزنة',
                style: TextStyle(color: _secondaryColor, fontSize: 14),
              ),
              dropdownColor: _surfaceColor,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.gold),
              items: cashboxes.map((c) => DropdownMenuItem<int?>(
                value: c['CashBoxID'],
                child: Text(
                  c['CashBoxName'] ?? '',
                  style: TextStyle(color: _textColor, fontSize: 14),
                ),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCashboxFrom = value;
                  currentBalance = null;
                });
                if (value != null) {
                  _loadBalance(value);
                }
              },
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1);
  }

  Widget _buildCashboxToDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إلى خزنة',
          style: TextStyle(
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedCashboxTo,
              hint: Text(
                'اختر الخزنة المستقبلة',
                style: TextStyle(color: _secondaryColor, fontSize: 14),
              ),
              dropdownColor: _surfaceColor,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.gold),
              items: cashboxes
                  .where((c) => c['CashBoxID'] != selectedCashboxFrom)
                  .map((c) => DropdownMenuItem<int?>(
                    value: c['CashBoxID'],
                    child: Text(
                      c['CashBoxName'] ?? '',
                      style: TextStyle(color: _textColor, fontSize: 14),
                    ),
                  )).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCashboxTo = value;
                });
              },
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms).slideY(begin: -0.1);
  }

  Widget _buildBalanceCard() {
    if (selectedCashboxFrom == null) {
      return const SizedBox.shrink();
    }

    final Color balanceColor = (currentBalance ?? 0) >= 0 ? AppColors.success : AppColors.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: balanceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: balanceColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: balanceColor, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الرصيد الحالي',
                style: TextStyle(
                  color: _secondaryColor,
                  fontSize: 11,
                ),
              ),
              AmountText(
                value: currentBalance != null
                    ? NumberFormat('#,##0.00', 'en').format(currentBalance)
                    : 'جاري التحميل...',
                size: 18,
                color: balanceColor,
                weight: FontWeight.bold,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildAmountField() {
    final Color typeColor = _opColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المبلغ',
          style: TextStyle(
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: typeColor.withOpacity(0.3)),
          ),
          child: TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: TextStyle(
              color: _textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: _hintColor, fontSize: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(
                _isOut ? Icons.remove : Icons.add,
                color: typeColor,
              ),
              suffixText: 'ج.م',
              suffixStyle: TextStyle(color: _secondaryColor, fontSize: 14),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 250.ms).slideY(begin: -0.1);
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التاريخ',
          style: TextStyle(
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.gold, size: 18),
                const SizedBox(width: 12),
                Text(
                  DateFormat('yyyy/MM/dd', 'ar').format(selectedDate),
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(Icons.keyboard_arrow_down, color: _secondaryColor),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: -0.1);
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ملاحظات (اختياري)',
          style: TextStyle(
            color: _secondaryColor,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: TextField(
            controller: notesController,
            maxLines: 3,
            style: TextStyle(color: _textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'أدخل ملاحظات...',
              hintStyle: TextStyle(color: _hintColor, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 350.ms).slideY(begin: -0.1);
  }

  Widget _buildSaveButton() {
    final Color typeColor = _opColor;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: typeColor,
          disabledBackgroundColor: typeColor.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: saving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_opIcon, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'تسجيل $_opLabel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildLoadingState() {
    return const AppLoading(message: 'جاري التحميل...');
  }
}