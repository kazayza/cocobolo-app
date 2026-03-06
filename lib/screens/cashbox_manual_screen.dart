import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/cashbox_service.dart';
import '../services/permission_service.dart';

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

  // الحقول
  String selectedTransactionType = 'قبض';
  int? selectedCashboxFrom;
  int? selectedCashboxTo;
  double? currentBalance;
  
  final TextEditingController amountController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  DateTime selectedDate = DateTime.now();

  // أنواع العمليات
  final List<Map<String, dynamic>> transactionTypes = [
    {'value': 'قبض', 'label': 'قبض', 'icon': Icons.arrow_downward, 'color': Colors.green},
    {'value': 'صرف', 'label': 'صرف', 'icon': Icons.arrow_upward, 'color': Colors.red},
    {'value': 'تحويل', 'label': 'تحويل', 'icon': Icons.swap_horiz, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _loadCashboxes();
  }

  @override
  void dispose() {
    amountController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCashboxes() async {
    setState(() => loading = true);
    
    final data = await CashboxService.getAllCashboxes();
    
    setState(() {
      cashboxes = data;
      loading = false;
    });
  }

  Future<void> _loadBalance(int cashboxId) async {
    final balance = await CashboxService.getCashboxBalance(cashboxId);
    setState(() {
      currentBalance = balance;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE8B923),
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1E1E1E),
        ),
        child: child!,
      ),
    );
    
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  String _getCashboxName(int? id) {
    if (id == null) return '';
    final cashbox = cashboxes.firstWhere(
      (c) => c['CashBoxID'] == id,
      orElse: () => {},
    );
    return cashbox['CashBoxName'] ?? '';
  }

  Future<void> _save() async {
    // التحقق من البيانات
    if (selectedCashboxFrom == null) {
      _showError('اختر الخزنة');
      return;
    }

    if (selectedTransactionType == 'تحويل' && selectedCashboxTo == null) {
      _showError('اختر الخزنة المستقبلة');
      return;
    }

    if (selectedTransactionType == 'تحويل' && selectedCashboxFrom == selectedCashboxTo) {
      _showError('الخزنة المصدر والمستقبلة يجب أن تكونا مختلفتين');
      return;
    }

    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      _showError('أدخل مبلغاً صحيحاً أكبر من صفر');
      return;
    }

    // التحقق من الرصيد للصرف والتحويل
    if (selectedTransactionType != 'قبض' && currentBalance != null && amount > currentBalance!) {
      _showError('المبلغ أكبر من الرصيد المتاح');
      return;
    }

    setState(() => saving = true);

    try {
      Map<String, dynamic> result;

      if (selectedTransactionType == 'تحويل') {
        // تحويل بين خزينتين
        result = await CashboxService.transfer(
          cashBoxIdFrom: selectedCashboxFrom!,
          cashBoxIdTo: selectedCashboxTo!,
          cashBoxFromName: _getCashboxName(selectedCashboxFrom),
          cashBoxToName: _getCashboxName(selectedCashboxTo),
          amount: amount,
          notes: notesController.text,
          createdBy: PermissionService().username ?? widget.username ?? 'System',
        );
      } else {
        // قبض أو صرف
        result = await CashboxService.createTransaction(
          cashBoxId: selectedCashboxFrom!,
          transactionType: selectedTransactionType,
          amount: amount,
          notes: notesController.text,
          createdBy: PermissionService().username ?? widget.username ?? 'System',
        );
      }

      setState(() => saving = false);

      if (result['success'] == true) {
        _showSuccess('تم تسجيل الحركة بنجاح');
        _clearForm();
        // تحديث الرصيد
        if (selectedCashboxFrom != null) {
          _loadBalance(selectedCashboxFrom!);
        }
      } else {
        _showError(result['message'] ?? 'فشل تسجيل الحركة');
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
      selectedCashboxTo = null;
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
                style: GoogleFonts.cairo(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
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
                style: GoogleFonts.cairo(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppBar(),
      body: loading
          ? _buildLoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTransactionTypeSelector(),
                  const SizedBox(height: 20),
                  _buildCashboxFromDropdown(),
                  const SizedBox(height: 16),
                  if (selectedTransactionType == 'تحويل') ...[
                    _buildCashboxToDropdown(),
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
              color: const Color(0xFFE8B923).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long, color: Color(0xFFE8B923), size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'سند قبض / صرف',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1A1A),
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
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: transactionTypes.map((type) {
            final isSelected = selectedTransactionType == type['value'];
            final Color color = type['color'];
            
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedTransactionType = type['value'];
                    if (type['value'] != 'تحويل') {
                      selectedCashboxTo = null;
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.white.withOpacity(0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        type['icon'],
                        color: isSelected ? color : Colors.grey[500],
                        size: 22,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        type['label'],
                        style: GoogleFonts.cairo(
                          color: isSelected ? color : Colors.grey[400],
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildCashboxFromDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedTransactionType == 'تحويل' ? 'من خزنة' : 'الخزنة',
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedCashboxFrom,
              hint: Text(
                'اختر الخزنة',
                style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 14),
              ),
              dropdownColor: const Color(0xFF2A2A2A),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFE8B923)),
              items: cashboxes.map((c) => DropdownMenuItem<int?>(
                value: c['CashBoxID'],
                child: Text(
                  c['CashBoxName'] ?? '',
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
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
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedCashboxTo,
              hint: Text(
                'اختر الخزنة المستقبلة',
                style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 14),
              ),
              dropdownColor: const Color(0xFF2A2A2A),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.purple),
              items: cashboxes
                  .where((c) => c['CashBoxID'] != selectedCashboxFrom)
                  .map((c) => DropdownMenuItem<int?>(
                    value: c['CashBoxID'],
                    child: Text(
                      c['CashBoxName'] ?? '',
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
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

    final Color balanceColor = (currentBalance ?? 0) >= 0 ? Colors.green : Colors.red;

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
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
              Text(
                currentBalance != null
                    ? NumberFormat('#,##0.00', 'en').format(currentBalance)
                    : 'جاري التحميل...',
                style: GoogleFonts.cairo(
                  color: balanceColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildAmountField() {
    final Color typeColor = selectedTransactionType == 'قبض'
        ? Colors.green
        : selectedTransactionType == 'صرف'
            ? Colors.red
            : Colors.purple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المبلغ',
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: typeColor.withOpacity(0.3)),
          ),
          child: TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(
                selectedTransactionType == 'قبض'
                    ? Icons.add
                    : selectedTransactionType == 'صرف'
                        ? Icons.remove
                        : Icons.swap_horiz,
                color: typeColor,
              ),
              suffixText: 'ج.م',
              suffixStyle: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 14),
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
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
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
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFFE8B923), size: 18),
                const SizedBox(width: 12),
                Text(
                  DateFormat('yyyy/MM/dd', 'ar').format(selectedDate),
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey[500]),
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
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: notesController,
            maxLines: 3,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'أدخل ملاحظات...',
              hintStyle: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 350.ms).slideY(begin: -0.1);
  }

  Widget _buildSaveButton() {
    final Color typeColor = selectedTransactionType == 'قبض'
        ? Colors.green
        : selectedTransactionType == 'صرف'
            ? Colors.red
            : Colors.purple;

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
                  Icon(
                    selectedTransactionType == 'قبض'
                        ? Icons.arrow_downward
                        : selectedTransactionType == 'صرف'
                            ? Icons.arrow_upward
                            : Icons.swap_horiz,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    selectedTransactionType == 'تحويل'
                        ? 'تأكيد التحويل'
                        : 'تسجيل ${selectedTransactionType}',
                    style: GoogleFonts.cairo(
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFE8B923),
            strokeWidth: 2,
          ).animate().fadeIn().scale(),
          const SizedBox(height: 16),
          Text(
            'جاري التحميل...',
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}