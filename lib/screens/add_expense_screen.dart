import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/permission_service.dart';

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
  bool _loadingDropdowns = false;
  String _errorMessage = '';

  // Controllers
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _recipientController = TextEditingController();

  // Dropdowns
  List<Map<String, dynamic>> expenseGroups = [];
  List<Map<String, dynamic>> cashBoxes = [];
  int? selectedGroupId;
  int? selectedCashBoxId;
  String? selectedGroupName;
  String? selectedCashBoxName;

  // التاريخ
  DateTime selectedDate = DateTime.now();

  // مقدم
  bool isAdvance = false;
  final _advanceMonthsController = TextEditingController();
  final FocusNode _advanceMonthsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingExpense != null;
    
    print('🚀 بدء شاشة ${_isEditing ? 'تعديل' : 'إضافة'} مصروف');
    
    _fetchDropdownData();

    if (_isEditing) {
      _populateFields();
    } else {
      // للإضافة فقط
      selectedGroupId = null;
      selectedCashBoxId = null;
    }
  }

  void _populateFields() {
    final e = widget.existingExpense!;
    
    _nameController.text = e['ExpenseName'] ?? '';
    _amountController.text = (e['Amount'] ?? 0).toString();
    _notesController.text = e['Notes'] ?? '';
    _recipientController.text = e['Torecipient'] ?? '';
    selectedGroupId = e['ExpenseGroupID'];
    selectedGroupName = e['ExpenseGroupName'];
    selectedCashBoxId = e['CashBoxID'];
    selectedCashBoxName = e['CashBoxName'];
    isAdvance = e['IsAdvance'] == true;
    _advanceMonthsController.text = (e['AdvanceMonths'] ?? '').toString();

    if (e['ExpenseDate'] != null) {
      final dateTime = DateTime.tryParse(e['ExpenseDate']);
      if (dateTime != null) {
        selectedDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
      }
    }
  }

 Future<void> _fetchDropdownData() async {
  setState(() {
    _loadingDropdowns = true;
    _errorMessage = '';
  });
  
  try {
    print('📥 جاري تحميل البيانات...');
    
    // 1. جلب التصنيفات
    final groupsRes = await http.get(Uri.parse('$baseUrl/api/expenses/groups'));
    
    if (groupsRes.statusCode == 200) {
      final List<dynamic> groupsData = jsonDecode(groupsRes.body);
      print('✅ تم تحميل ${groupsData.length} تصنيف');
      
      setState(() {
        expenseGroups = groupsData.map<Map<String, dynamic>>((item) {
          return {
            'ExpenseGroupID': item['ExpenseGroupID'] ?? 0,
            'ExpenseGroupName': item['ExpenseGroupName'] ?? 'غير معروف',
          };
        }).toList();
      });
    }

    // 2. جلب الخزائن
    final cashBoxesRes = await http.get(Uri.parse('$baseUrl/api/cashbox'));
    
    if (cashBoxesRes.statusCode == 200) {
      final List<dynamic> rawData = jsonDecode(cashBoxesRes.body);
      print('📦 عدد الخزائن: ${rawData.length}');
      
      setState(() {
        cashBoxes = rawData.map<Map<String, dynamic>>((item) {
          return {
            'CashBoxID': item['CashBoxID'] ?? 0,
            'CashBoxName': item['CashBoxName'] ?? 'غير معروف',
            'Description': item['Description'] ?? '',
          };
        }).toList();
      });
    }
    
  } catch (e) {
    print('🔥 خطأ: $e');
    setState(() => _errorMessage = 'خطأ في الاتصال');
  } finally {
    setState(() => _loadingDropdowns = false);
  }
}

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _recipientController.dispose();
    _advanceMonthsController.dispose();
    _advanceMonthsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissions = PermissionService();
    final canAdd = permissions.canAdd('frm_Expenses');
    final canEdit = permissions.canEdit('frm_Expenses');
    
    if (_isEditing && !canEdit) {
      return _buildPermissionDeniedScreen('تعديل المصروف', 'ليس لديك صلاحيات التعديل');
    }

    if (!_isEditing && !canAdd) {
      return _buildPermissionDeniedScreen('إضافة مصروف', 'ليس لديك صلاحيات الإضافة');
    }

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
      body: _loadingDropdowns
          ? _buildLoadingWidget()
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : _buildFormWidget(),
    );
  }

  Widget _buildPermissionDeniedScreen(String title, String message) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.cairo(color: Colors.black)),
        backgroundColor: Color(0xFFE8B923),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 80, color: Colors.red),
            SizedBox(height: 20),
            Text(
              message,
              style: GoogleFonts.cairo(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFFFD700)),
          SizedBox(height: 20),
          Text(
            'جاري تحميل البيانات...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red),
          SizedBox(height: 20),
          Text(
            _errorMessage,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchDropdownData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFFD700),
            ),
            child: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormWidget() {
    return Form(
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
                // حقل التصنيف - النسخة المعدلة
                _buildExpenseGroupDropdown(),
                const SizedBox(height: 16),
                
                // اسم المصروف
                _buildTextField(
                  controller: _nameController,
                  label: 'اسم المصروف *',
                  icon: Icons.receipt,
                  validator: (v) => v!.trim().isEmpty ? 'اسم المصروف مطلوب' : null,
                  enabled: false,
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                
                // الخزينة
                _buildCashboxDropdown(),
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
                    if (v!.trim().isEmpty) return 'المبلغ مطلوب';
                    final cleanValue = v.replaceAll(',', '');
                    final amount = double.tryParse(cleanValue);
                    if (amount == null) return 'رقم غير صحيح';
                    if (amount <= 0) return 'يجب أن يكون أكبر من صفر';
                    return null;
                  },
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      _formatAmount(value);
                    }
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
            if (!_isEditing) _buildAdvanceSection(),

            const SizedBox(height: 40),

            // زر الحفظ
            _buildSaveButton(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ====================== دالة التصنيفات المعدلة بشكل نهائي ======================
  Widget _buildExpenseGroupDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التصنيف *',
          style: GoogleFonts.cairo(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<int?>(
            value: selectedGroupId,
            isExpanded: true,
            underline: Container(),
            
            // ⭐⭐ بناء العناصر بشكل مبسط ⭐⭐
            items: _buildExpenseGroupItems(),
            
            onChanged: (newValue) {
              print('🔘 تغيير التصنيف إلى: $newValue');
              setState(() {
                selectedGroupId = newValue;
                if (newValue != null) {
                  // البحث عن العنصر المحدد
                  for (var item in expenseGroups) {
                    if (item['ExpenseGroupID'] == newValue) {
                      selectedGroupName = item['ExpenseGroupName'];
                      _nameController.text = selectedGroupName ?? '';
                      break;
                    }
                  }
                } else {
                  _nameController.text = '';
                }
              });
            },
            
            dropdownColor: const Color(0xFF1A1A1A),
            icon: const Icon(Icons.arrow_drop_down, 
                   color: Color(0xFFFFD700), size: 24),
            
            // ⭐⭐ إزالة selectedItemBuilder نهائياً ⭐⭐
            // سيستخدم DropdownButton العرض الافتراضي
            
            hint: Text(
              'اختر التصنيف',
              style: GoogleFonts.cairo(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            
            // ⭐⭐ هذه الخاصية مهمة لمنع الخطأ ⭐⭐
            selectedItemBuilder: (BuildContext context) {
              // نعيد قائمة بنفس طول العناصر
              List<Widget> items = [];
              
              // العنصر الافتراضي
              items.add(
                Text(
                  'اختر التصنيف',
                  style: GoogleFonts.cairo(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                )
              );
              
              // العناصر الأخرى
              for (var item in expenseGroups) {
                items.add(
                  Text(
                    item['ExpenseGroupName'] ?? 'غير معروف',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                );
              }
              
              return items;
            },
          ),
        ),
        
        // رسالة الخطأ
        if (selectedGroupId == null && _formKey.currentState != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Text(
              'التصنيف مطلوب',
              style: GoogleFonts.cairo(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // ⭐⭐ دالة مساعدة لبناء عناصر التصنيف ⭐⭐
  List<DropdownMenuItem<int?>> _buildExpenseGroupItems() {
    final List<DropdownMenuItem<int?>> items = [];
    
    // أولاً: الخيار الافتراضي
    items.add(
      DropdownMenuItem<int?>(
        value: null,
        child: Text(
          'اختر التصنيف',
          style: GoogleFonts.cairo(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      ),
    );
    
    // ثانياً: التصنيفات من البيانات
    for (var item in expenseGroups) {
      items.add(
        DropdownMenuItem<int?>(
          value: item['ExpenseGroupID'],
          child: Text(
            item['ExpenseGroupName'] ?? 'غير معروف',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
    
    return items;
  }

  // ====================== دالة الخزائن ======================
  Widget _buildCashboxDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الخزينة *',
          style: GoogleFonts.cairo(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<int?>(
            value: selectedCashBoxId,
            isExpanded: true,
            underline: Container(),
            
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(
                  'اختر الخزينة',
                  style: GoogleFonts.cairo(color: Colors.grey),
                ),
              ),
              ...cashBoxes.map((item) {
                return DropdownMenuItem<int?>(
                  value: item['CashBoxID'],
                  child: Text(
                    item['CashBoxName'] ?? 'غير معروف',
                    style: GoogleFonts.cairo(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ],
            
            onChanged: (newValue) {
              setState(() {
                selectedCashBoxId = newValue;
                if (newValue != null) {
                  for (var item in cashBoxes) {
                    if (item['CashBoxID'] == newValue) {
                      selectedCashBoxName = item['CashBoxName'];
                      break;
                    }
                  }
                }
              });
            },
            
            dropdownColor: const Color(0xFF1A1A1A),
            icon: const Icon(Icons.arrow_drop_down, 
                   color: Color(0xFFFFD700), size: 24),
            hint: Text(
              cashBoxes.isEmpty ? 'جاري التحميل...' : 'اختر الخزينة',
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
          ),
        ),
        
        if (selectedCashBoxId == null && _formKey.currentState != null && cashBoxes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Text(
              'الخزينة مطلوبة',
              style: GoogleFonts.cairo(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildAdvanceSection() {
    return _buildSection(
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
        if (isAdvance) ...[
          const SizedBox(height: 8),
          _buildTextField(
            controller: _advanceMonthsController,
            label: 'عدد الشهور *',
            icon: Icons.calendar_month,
            keyboardType: TextInputType.number,
            focusNode: _advanceMonthsFocus,
            validator: isAdvance ? (v) {
              if (v!.trim().isEmpty) return 'عدد الشهور مطلوب';
              final months = int.tryParse(v);
              if (months == null || months <= 0) return 'عدد أشهر صحيح مطلوب';
              return null;
            } : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'ملاحظة: المصروف المقدم سيتم توزيعه على عدة أشهر',
              style: GoogleFonts.cairo(
                color: Colors.orange,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
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
    void Function(String)? onChanged,
    FocusNode? focusNode,
    bool enabled = true,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.cairo(
        color: enabled ? Colors.white : Colors.grey,
      ),
      validator: validator,
      onChanged: onChanged,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
        suffixText: suffixText,
        suffixStyle: GoogleFonts.cairo(color: Colors.grey),
        filled: true,
        fillColor: enabled 
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تاريخ المصروف',
          style: GoogleFonts.cairo(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
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
                      onPrimary: Colors.black,
                      surface: Color(0xFF1A1A1A),
                      onSurface: Colors.white,
                    ),
                    dialogBackgroundColor: const Color(0xFF1A1A1A),
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
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFFFFD700)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(selectedDate),
                    style: GoogleFonts.cairo(color: Colors.white),
                  ),
                ),
                Text(
                  'تغيير',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFFFFD700),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
          disabledBackgroundColor: Colors.grey,
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

  void _formatAmount(String value) {
    final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanValue.isNotEmpty) {
      try {
        final numValue = int.parse(cleanValue);
        final formatted = NumberFormat('#,##0').format(numValue);
        
        if (_amountController.text != formatted) {
          _amountController.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
      } catch (e) {
        print('Error formatting amount: $e');
      }
    }
  }

  Future<void> _saveExpense() async {
    if (selectedGroupId == null) {
      _showErrorSnackBar('يرجى اختيار التصنيف');
      return;
    }
    
    if (selectedCashBoxId == null) {
      _showErrorSnackBar('يرجى اختيار الخزينة');
      return;
    }
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (isAdvance && !_isEditing) {
      final months = int.tryParse(_advanceMonthsController.text.trim());
      if (months == null || months <= 0) {
        _showErrorSnackBar('يرجى إدخال عدد أشهر صحيح للمصروف المقدم');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final expenseData = {
        'expenseName': _nameController.text.trim(),
        'expenseGroupId': selectedGroupId,
        'cashBoxId': selectedCashBoxId,
        'amount': double.parse(_amountController.text.replaceAll(',', '')),
        'expenseDate': DateFormat('yyyy-MM-dd').format(selectedDate),
        'notes': _notesController.text.trim(),
        'toRecipient': _recipientController.text.trim(),
        'isAdvance': isAdvance,
        'advanceMonths': isAdvance ? int.parse(_advanceMonthsController.text.trim()) : null,
        'createdBy': widget.username,
      };

      http.Response res;

      if (_isEditing) {
        final expenseId = widget.existingExpense!['ExpenseID'];
        res = await http.put(
          Uri.parse('$baseUrl/api/expenses/$expenseId'),
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

      if (res.statusCode == 200) {
        final result = jsonDecode(res.body);
        
        if (result['success'] == true) {
          final message = _isEditing ? 'تم تعديل المصروف بنجاح' : 'تم إضافة المصروف بنجاح';
          _showSuccessSnackBar(message);
          
          await Future.delayed(const Duration(milliseconds: 800));
          Navigator.pop(context, true);
        } else {
          throw Exception(result['message'] ?? 'فشل في الحفظ');
        }
      } else {
        throw Exception('خطأ في السيرفر: ${res.statusCode}');
      }
    } catch (e) {
      print('❌ خطأ في الحفظ: $e');
      _showErrorSnackBar('فشل في الحفظ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}