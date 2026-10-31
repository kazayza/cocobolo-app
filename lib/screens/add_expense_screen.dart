import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/expense_service.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../core/network/api_client.dart';
import '../widgets/design_kit.dart';

/// نموذج المصروف (إضافة/تعديل) — الهيكل والحقول وسير العمل كما هو معتمد،
/// بهوية واعية بالوضع (فاتح/داكن) عبر ThemeService وAppColors.
/// - الخزائن من /api/expenses/cashboxes: نشطة فقط، مع اسم الفرع والرصيد
///   الحالي والرصيد بعد العملية وتحذير عدم الكفاية (عرض فقط).
/// - عند التعديل لا تُرسل حقول المقدم إطلاقًا، والحفظ يستخدم
///   widget.expenseId ?? existingExpense — فلا تعطّل في مسار الإشعارات.
/// - فشل تحميل المصروف للتعديل يظهر خطأً ويمنع الحفظ.
/// - لا يُرسل createdBy: الخادم يشتقه من التوكن.
class AddExpenseScreen extends StatefulWidget {
  final String username;
  final Map<String, dynamic>? existingExpense;
  final int? expenseId;

  const AddExpenseScreen({
    Key? key,
    required this.username,
    this.existingExpense,
    this.expenseId,
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
  String? _loadError; // فشل تحميل مصروف التعديل — يمنع الحفظ

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _recipientController = TextEditingController();

  List<Map<String, dynamic>> expenseGroups = [];
  List<Map<String, dynamic>> cashBoxes = [];
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _visibleSuggestions = [];
  int? selectedGroupId;
  int? selectedCashBoxId;
  int? _branchId;

  DateTime selectedDate = DateTime.now();

  bool isAdvance = false;
  final _advanceMonthsController = TextEditingController();
  final FocusNode _advanceMonthsFocus = FocusNode();

  bool get _isDark => ThemeService().isDarkMode;

  Map<String, dynamic>? get _selectedBox {
    for (final b in cashBoxes) {
      if (b['CashBoxID'] == selectedCashBoxId) return b;
    }
    return null;
  }

  double get _amount =>
      double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingExpense != null || widget.expenseId != null;
    _fetchDropdownData();
    if (widget.existingExpense != null) {
      _populateFields();
    } else if (widget.expenseId != null) {
      _fetchExpenseById(widget.expenseId!);
    }
  }

  Future<void> _fetchExpenseById(int id) async {
    try {
      final data = await ExpenseService.getExpenseById(id);
      if (!mounted) return;
      setState(() {
        _nameController.text = data['ExpenseName']?.toString() ?? '';
        _amountController.text = (data['Amount'] ?? 0).toString();
        _notesController.text = data['Notes']?.toString() ?? '';
        _recipientController.text = data['Torecipient']?.toString() ?? '';
        selectedGroupId = (data['ExpenseGroupID'] as num?)?.toInt();
        selectedCashBoxId = (data['CashBoxID'] as num?)?.toInt();
        _branchId = (data['BranchId'] as num?)?.toInt();
        if (data['ExpenseDate'] != null) {
          selectedDate =
              DateTime.tryParse(data['ExpenseDate'].toString()) ?? selectedDate;
        }
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'فشل تحميل بيانات المصروف');
      }
    }
  }

  void _populateFields() {
    final e = widget.existingExpense!;
    _nameController.text = e['ExpenseName']?.toString() ?? '';
    _amountController.text = (e['Amount'] ?? 0).toString();
    _notesController.text = e['Notes']?.toString() ?? '';
    _recipientController.text = e['Torecipient']?.toString() ?? '';
    selectedGroupId = (e['ExpenseGroupID'] as num?)?.toInt();
    selectedCashBoxId = (e['CashBoxID'] as num?)?.toInt();
    _branchId = (e['BranchId'] as num?)?.toInt();
    if (e['ExpenseDate'] != null) {
      final dateTime = DateTime.tryParse(e['ExpenseDate'].toString());
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
      final groups = await ExpenseService.getExpenseGroups();
      final boxes = await ExpenseService.getCashBoxes();
      List<Map<String, dynamic>> suggestions = [];
      try {
        suggestions = await ExpenseService.getNameSuggestions();
      } catch (_) {
        suggestions = []; // الاقتراحات تكميلية لا توقف النموذج
      }
      if (!mounted) return;
      setState(() {
        expenseGroups = groups;
        cashBoxes = boxes;
        _suggestions = suggestions;
        // قيم محفوظة غير موجودة في القوائم الحالية تُصفّى بدل تعطّل القائمة
        if (selectedGroupId != null &&
            !groups.any((g) => g['ExpenseGroupID'] == selectedGroupId)) {
          selectedGroupId = null;
        }
        if (selectedCashBoxId != null &&
            !boxes.any((b) => b['CashBoxID'] == selectedCashBoxId)) {
          selectedCashBoxId = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'خطأ في الاتصال');
    } finally {
      if (mounted) setState(() => _loadingDropdowns = false);
    }
  }

  void _onNameChanged(String value) {
    final q = value.trim();
    setState(() {
      if (q.isEmpty) {
        _visibleSuggestions = [];
      } else {
        _visibleSuggestions = _suggestions
            .where((s) =>
                (s['ExpenseName']?.toString() ?? '').contains(q) &&
                s['ExpenseName']?.toString() != q)
            .take(5)
            .toList();
      }
    });
  }

  void _applySuggestion(Map<String, dynamic> s) {
    setState(() {
      _nameController.text = s['ExpenseName']?.toString() ?? '';
      // تعبئة المجموعة تلقائيًا عند اختيار اسم سابق (مطابقة بلازور)
      final gid = (s['ExpenseGroupID'] as num?)?.toInt();
      if (gid != null && expenseGroups.any((g) => g['ExpenseGroupID'] == gid)) {
        selectedGroupId = gid;
      }
      _visibleSuggestions = [];
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
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
    final isDark = _isDark;
    final permissions = PermissionService();
    final canAdd = permissions.canAdd(FormNames.expensesAdd);
    final canEdit = permissions.canEdit(FormNames.expensesAdd);

    if (_isEditing && !canEdit) {
      return _buildPermissionDeniedScreen(
          'تعديل المصروف', 'ليس لديك صلاحيات التعديل', isDark);
    }
    if (!_isEditing && !canAdd) {
      return _buildPermissionDeniedScreen(
          'إضافة مصروف', 'ليس لديك صلاحيات الإضافة', isDark);
    }

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'تعديل المصروف' : 'إضافة مصروف',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loadingDropdowns
          ? const AppLoading(message: 'جاري تحميل البيانات...')
          : _errorMessage.isNotEmpty
              ? AppError(message: _errorMessage, onRetry: _fetchDropdownData)
              : _loadError != null
                  ? AppError(
                      message: _loadError!,
                      onRetry: () => _fetchExpenseById(widget.expenseId!),
                    )
                  : _buildFormWidget(isDark),
    );
  }

  Widget _buildPermissionDeniedScreen(
      String title, String message, bool isDark) {
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block,
                size: 80,
                color: isDark ? AppColors.errorLight : AppColors.error),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(fontSize: 18, color: AppColors.text(isDark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormWidget(bool isDark) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'البيانات الأساسية',
              Icons.info_outline,
              isDark,
              [
                _buildExpenseGroupDropdown(isDark),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _nameController,
                  label: 'اسم المصروف *',
                  icon: Icons.receipt,
                  validator: (v) =>
                      v!.trim().isEmpty ? 'اسم المصروف مطلوب' : null,
                  onChanged: _onNameChanged,
                ),
                if (_visibleSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.inputFill(isDark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        for (final s in _visibleSuggestions)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.history,
                                size: 18, color: AppColors.gold),
                            title: Text(
                              s['ExpenseName']?.toString() ?? '',
                              style: TextStyle(
                                  color: AppColors.text(isDark),
                                  fontSize: 13),
                            ),
                            subtitle: s['FullGroupPath'] != null
                                ? Text(
                                    s['FullGroupPath'].toString(),
                                    style: TextStyle(
                                        color:
                                            AppColors.textSecondary(isDark),
                                        fontSize: 11),
                                  )
                                : null,
                            onTap: () => _applySuggestion(s),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildCashboxDropdown(isDark),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'المبلغ والتاريخ',
              Icons.attach_money,
              isDark,
              [
                _buildTextField(
                  controller: _amountController,
                  label: 'المبلغ *',
                  icon: Icons.money,
                  keyboardType: TextInputType.number,
                  suffixText: 'ج.م',
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'المبلغ مطلوب';
                    final amount =
                        double.tryParse(v.replaceAll(',', ''));
                    if (amount == null) return 'رقم غير صحيح';
                    if (amount <= 0) return 'يجب أن يكون أكبر من صفر';
                    return null;
                  },
                  onChanged: (value) {
                    if (value.isNotEmpty) _formatAmount(value);
                    setState(() {}); // تحديث «الرصيد بعد العملية»
                  },
                ),
                if (_selectedBox != null) ...[
                  const SizedBox(height: 10),
                  _buildBalanceAfter(isDark),
                ],
                const SizedBox(height: 16),
                _buildDatePicker(isDark),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'تفاصيل إضافية',
              Icons.notes,
              isDark,
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
            if (!_isEditing) _buildAdvanceSection(isDark),
            const SizedBox(height: 40),
            _buildSaveButton(isDark),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // الرصيد بعد العملية + تحذير عدم الكفاية — عرض فقط، حارس الخادم كما هو
  Widget _buildBalanceAfter(bool isDark) {
    final balance =
        (_selectedBox!['CurrentBalance'] as num?)?.toDouble() ?? 0;
    final after = balance - _amount;
    final insufficient = after < 0;
    final color = insufficient
        ? (isDark ? AppColors.errorLight : AppColors.error)
        : AppColors.textSecondary(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: insufficient
            ? AppColors.error.withValues(alpha: 0.10)
            : AppColors.inputFill(isDark),
        borderRadius: BorderRadius.circular(10),
        border: insufficient
            ? Border.all(color: AppColors.error.withValues(alpha: 0.35))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رصيد الخزينة الحالي: ${NumberFormat('#,##0.00').format(balance)} ج.م'
            ' — الرصيد بعد العملية: ${NumberFormat('#,##0.00').format(after)} ج.م',
            style: TextStyle(fontSize: 12, color: color),
          ),
          if (insufficient) ...[
            const SizedBox(height: 4),
            Text(
              'تحذير: الرصيد بعد العملية سالب — قد يرفض الخادم الحفظ لعدم كفاية الرصيد.',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.errorLight : AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpenseGroupDropdown(bool isDark) {
    final safeValue = expenseGroups.any((g) => g['ExpenseGroupID'] == selectedGroupId)
        ? selectedGroupId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('التصنيف *', isDark),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.inputFill(isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<int?>(
            value: safeValue,
            isExpanded: true,
            underline: Container(),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('اختر التصنيف',
                    style: TextStyle(color: AppColors.textHint(isDark))),
              ),
              ...expenseGroups.map((item) => DropdownMenuItem<int?>(
                    value: (item['ExpenseGroupID'] as num).toInt(),
                    child: Text(
                      item['ExpenseGroupName']?.toString() ?? 'غير معروف',
                      style: TextStyle(color: AppColors.text(isDark)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: (newValue) {
              setState(() {
                selectedGroupId = newValue;
                if (newValue != null) {
                  for (var item in expenseGroups) {
                    if (item['ExpenseGroupID'] == newValue) {
                      // سير العمل المعتمد: اختيار التصنيف يملأ اسم المصروف
                      _nameController.text =
                          item['ExpenseGroupName']?.toString() ?? '';
                      break;
                    }
                  }
                }
              });
            },
            dropdownColor: AppColors.surface(isDark),
            icon: const Icon(Icons.arrow_drop_down,
                color: AppColors.gold, size: 24),
            hint: Text(
              'اختر التصنيف',
              style: TextStyle(color: AppColors.textHint(isDark), fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashboxDropdown(bool isDark) {
    final safeValue = cashBoxes.any((b) => b['CashBoxID'] == selectedCashBoxId)
        ? selectedCashBoxId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('الخزينة *', isDark),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.inputFill(isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<int?>(
            value: safeValue,
            isExpanded: true,
            underline: Container(),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('اختر الخزينة',
                    style: TextStyle(color: AppColors.textHint(isDark))),
              ),
              ...cashBoxes.map((item) {
                final balance =
                    (item['CurrentBalance'] as num?)?.toDouble() ?? 0;
                final branch = item['BranchName']?.toString();
                return DropdownMenuItem<int?>(
                  value: (item['CashBoxID'] as num).toInt(),
                  child: Text(
                    '${item['CashBoxName'] ?? 'غير معروف'}'
                    '${branch != null ? ' — $branch' : ''}'
                    ' (${NumberFormat('#,##0.00').format(balance)} ج.م)',
                    style: TextStyle(color: AppColors.text(isDark)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (newValue) {
              setState(() {
                selectedCashBoxId = newValue;
                final box = _selectedBox;
                _branchId = (box?['BranchId'] as num?)?.toInt();
              });
            },
            dropdownColor: AppColors.surface(isDark),
            icon: const Icon(Icons.arrow_drop_down,
                color: AppColors.gold, size: 24),
            hint: Text(
              cashBoxes.isEmpty ? 'جاري التحميل...' : 'اختر الخزينة',
              style: TextStyle(color: AppColors.textHint(isDark)),
            ),
          ),
        ),
        if (_selectedBox != null && _selectedBox!['BranchName'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Text(
              'الفرع: ${_selectedBox!['BranchName']}',
              style: TextStyle(
                  color: AppColors.textSecondary(isDark), fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildAdvanceSection(bool isDark) {
    return _buildSection(
      'مصروف مقدم',
      Icons.schedule,
      isDark,
      [
        SwitchListTile(
          title: Text('مصروف مقدم؟',
              style: TextStyle(color: AppColors.text(isDark))),
          value: isAdvance,
          activeColor: AppColors.gold,
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
            validator: isAdvance
                ? (v) {
                    if (v!.trim().isEmpty) return 'عدد الشهور مطلوب';
                    final months = int.tryParse(v);
                    if (months == null || months < 1) {
                      return 'عدد الشهور يجب أن يكون على الأقل 1';
                    }
                    if (months > 60) return 'الحد الأقصى لعدد الشهور هو 60 شهر';
                    return null;
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'ملاحظة: المصروف المقدم سيتم توزيعه على عدة أشهر',
              style: TextStyle(
                color: isDark ? AppColors.warningLight : AppColors.warning,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSection(
      String title, IconData icon, bool isDark, List<Widget> children) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title, icon: icon),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.textSecondary(isDark),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
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
  }) {
    final isDark = _isDark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.text(isDark)),
      validator: validator,
      onChanged: onChanged,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary(isDark)),
        prefixIcon: Icon(icon, color: AppColors.gold),
        suffixText: suffixText,
        suffixStyle: TextStyle(color: AppColors.textSecondary(isDark)),
        filled: true,
        fillColor: AppColors.inputFill(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ThemeService().accentColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? AppColors.errorLight : AppColors.error),
        ),
      ),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('تاريخ المصروف', isDark),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => selectedDate = picked);
            }
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.inputFill(isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(selectedDate),
                    style: TextStyle(color: AppColors.text(isDark)),
                  ),
                ),
                Text(
                  'تغيير',
                  style: TextStyle(
                    color: isDark ? AppColors.gold : AppColors.goldDark,
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

  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppColors.buttonGradient(isDark)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveExpense,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? CircularProgressIndicator(
                  color: isDark ? AppColors.navy : Colors.white)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save,
                        color: isDark ? AppColors.navy : Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      _isEditing ? 'حفظ التعديلات' : 'إضافة المصروف',
                      style: TextStyle(
                        color: isDark ? AppColors.navy : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
      } catch (_) {}
    }
  }

  Future<void> _saveExpense() async {
    if (_loadError != null) {
      _showErrorSnackBar('تعذّر تحميل بيانات المصروف — لا يمكن الحفظ');
      return;
    }
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
      if (months == null || months < 1 || months > 60) {
        _showErrorSnackBar('يرجى إدخال عدد أشهر صحيح للمصروف المقدم (1 إلى 60)');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      // الفرع من فرع الخزينة المختارة؛ وعند التعديل الفرع المحمّل إن غاب
      final branchId = _branchId ??
          (widget.existingExpense?['BranchId'] as num?)?.toInt();

      final expenseData = <String, dynamic>{
        'expenseName': _nameController.text.trim(),
        'expenseGroupId': selectedGroupId,
        'cashBoxId': selectedCashBoxId,
        'branchId': branchId,
        'amount': double.parse(_amountController.text.replaceAll(',', '')),
        'expenseDate': DateFormat('yyyy-MM-dd').format(selectedDate),
        'notes': _notesController.text.trim(),
        'toRecipient': _recipientController.text.trim(),
        // لا createdBy: الخادم يشتق المنشئ من التوكن فقط
      };

      Map<String, dynamic> result;
      if (_isEditing) {
        // مسار الإشعارات (expenseId فقط) ومسار القائمة (كائن كامل) سواء
        final expenseId = widget.expenseId ??
            (widget.existingExpense?['ExpenseID'] as num?)?.toInt();
        if (expenseId == null) {
          throw const ApiException(
              statusCode: 0, message: 'تعذّر تحديد المصروف المراد تعديله');
        }
        // عند التعديل لا تُرسل حقول المقدم إطلاقًا (الخادم يرفض تعديلها)
        result = await ExpenseService.updateExpense(expenseId, expenseData);
      } else {
        expenseData['isAdvance'] = isAdvance;
        expenseData['advanceMonths'] = isAdvance
            ? int.parse(_advanceMonthsController.text.trim())
            : null;
        result = await ExpenseService.createExpense(expenseData);
      }

      if (result['success'] == true || result['expenseId'] != null) {
        _showSuccessSnackBar(
            _isEditing ? 'تم تعديل المصروف بنجاح' : 'تم إضافة المصروف بنجاح');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, true);
      } else {
        throw ApiException(
            statusCode: 200,
            message: result['message']?.toString() ?? 'فشل في الحفظ');
      }
    } on ApiException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (_) {
      _showErrorSnackBar('فشل في الحفظ: تعذّر الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
