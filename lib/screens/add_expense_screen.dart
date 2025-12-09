import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';

class AddExpenseScreen extends StatefulWidget {
  final String username;
  final Map<String, dynamic>? existingExpense;

  const AddExpenseScreen({
    Key? key,
    required this.username,
    this.existingExpense,
  }) : super(key: key);

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;

  // Controllers
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _recipientController = TextEditingController();

  // Dropdowns
  List<dynamic> expenseGroups = [];
  List<dynamic> cashBoxes = [];
  int? selectedGroupId;
  int? selectedCashBoxId;

  // التاريخ
  DateTime selectedDate = DateTime.now();

  // مقدم
  bool isAdvance = false;
  final _advanceMonthsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingExpense != null;
    fetchDropdownData();

    if (_isEditing) {
      _populateFields();
    }
  }

  void _populateFields() {
    final e = widget.existingExpense!;
    _nameController.text = e['ExpenseName'] ?? '';
    _amountController.text = (e['Amount'] ?? 0).toString();
    _notesController.text = e['Notes'] ?? '';
    _recipientController.text = e['Torecipient'] ?? '';
    selectedGroupId = e['ExpenseGroupID'];
    selectedCashBoxId = e['CashBoxID'];
    isAdvance = e['IsAdvance'] == true;
    _advanceMonthsController.text = (e['AdvanceMonths'] ?? '').toString();

    if (e['ExpenseDate'] != null) {
      selectedDate = DateTime.tryParse(e['ExpenseDate']) ?? DateTime.now();
    }
  }

  Future<void> fetchDropdownData() async {
    try {
      // جلب التصنيفات
      final groupsRes = await http.get(Uri.parse('$baseUrl/api/expense-groups'));
      if (groupsRes.statusCode == 200) {
        setState(() => expenseGroups = jsonDecode(groupsRes.body));
      }

      // جلب الخزائن
      final cashBoxesRes = await http.get(Uri.parse('$baseUrl/api/cashboxes'));
      if (cashBoxesRes.statusCode == 200) {
        setState(() => cashBoxes = jsonDecode(cashBoxesRes.body));
      }
    } catch (e) {
      print('Error fetching dropdown data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _recipientController.dispose();
    _advanceMonthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'تعديل المصروف' : 'إضافة مصروف',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: const Color(0xFFE8B923),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // البيانات الأساسية
              _buildSection(
                'البيانات الأساسية',
                Icons.info_outline,
                [
                  _buildTextField(
                    controller: _nameController,
                    label: 'اسم المصروف *',
                    icon: Icons.receipt,
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown<int>(
                    label: 'التصنيف *',
                    icon: Icons.category,
                    value: selectedGroupId,
                    items: expenseGroups.map((g) {
                      return DropdownMenuItem<int>(
                        value: g['ExpenseGroupID'],
                        child: Text(g['ExpenseGroupName'],
                            style: GoogleFonts.cairo(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => selectedGroupId = v),
                    validator: (v) => v == null ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown<int>(
                    label: 'الخزينة *',
                    icon: Icons.account_balance_wallet,
                    value: selectedCashBoxId,
                    items: cashBoxes.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['CashBoxID'],
                        child: Text(c['CashBoxName'],
                            style: GoogleFonts.cairo(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => selectedCashBoxId = v),
                    validator: (v) => v == null ? 'مطلوب' : null,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // المبلغ والتاريخ
              _buildSection(
                'المبلغ والتاريخ',
                Icons.attach_money,
                [
                  _buildTextField(
                    controller: _amountController,
                    label: 'المبلغ *',
                    icon: Icons.money,
                    keyboardType: TextInputType.number,
                    suffixText: 'ج.م',
                    validator: (v) {
                      if (v!.isEmpty) return 'مطلوب';
                      if (double.tryParse(v) == null) return 'رقم غير صحيح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDatePicker(),
                ],
              ),

              const SizedBox(height: 24),

              // المستلم والملاحظات
              _buildSection(
                'تفاصيل إضافية',
                Icons.notes,
                [
                  _buildTextField(
                    controller: _recipientController,
                    label: 'المستلم',
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _notesController,
                    label: 'ملاحظات',
                    icon: Icons.note,
                    maxLines: 3,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // مصروف مقدم
              _buildSection(
                'مصروف مقدم',
                Icons.schedule,
                [
                  SwitchListTile(
                    title: Text('مصروف مقدم؟',
                        style: GoogleFonts.cairo(color: Colors.white)),
                    value: isAdvance,
                    activeColor: const Color(0xFFFFD700),
                    onChanged: (v) => setState(() => isAdvance = v),
                  ),
                  if (isAdvance)
                    _buildTextField(
                      controller: _advanceMonthsController,
                      label: 'عدد الشهور',
                      icon: Icons.calendar_month,
                      keyboardType: TextInputType.number,
                    ),
                ],
              ),

              const SizedBox(height: 40),

              // زر الحفظ
              _buildSaveButton(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFD700), size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.cairo(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
        suffixText: suffixText,
        suffixStyle: GoogleFonts.cairo(color: Colors.grey),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700)),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      dropdownColor: const Color(0xFF1A1A1A),
      style: GoogleFonts.cairo(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFFFFD700),
                  surface: Color(0xFF1A1A1A),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => selectedDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFFFFD700)),
            const SizedBox(width: 12),
            Text(
              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveExpense,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8B923),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, color: Colors.black),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing ? 'حفظ التعديلات' : 'إضافة المصروف',
                    style: GoogleFonts.cairo(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final expenseData = {
        'expenseName': _nameController.text,
        'expenseGroupId': selectedGroupId,
        'cashBoxId': selectedCashBoxId,
        'amount': double.parse(_amountController.text),
        'expenseDate': selectedDate.toIso8601String(),
        'notes': _notesController.text,
        'toRecipient': _recipientController.text,
        'isAdvance': isAdvance,
        'advanceMonths': int.tryParse(_advanceMonthsController.text),
        'createdBy': widget.username, // 👈 اسم المستخدم
      };

      http.Response res;

      if (_isEditing) {
        res = await http.put(
          Uri.parse('$baseUrl/api/expenses/${widget.existingExpense!['ExpenseID']}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(expenseData),
        );
      } else {
        res = await http.post(
          Uri.parse('$baseUrl/api/expenses'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(expenseData),
        );
      }

      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'تم التعديل بنجاح' : 'تم إضافة المصروف بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في الحفظ: $e', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}