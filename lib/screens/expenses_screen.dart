import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import 'add_expense_screen.dart';
import '../services/permission_service.dart';

class ExpensesScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ExpensesScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<dynamic> expenses = [];
  List<dynamic> allGroups = [];
  List<dynamic> parentGroups = [];
  List<dynamic> childGroups = [];
  Map<String, dynamic> summary = {};
  bool loading = true;

  final TextEditingController _searchController = TextEditingController();
  int? selectedGroupId;
  int? selectedParentId;
  String searchQuery = '';
  
  // فلتر التاريخ
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  // البحث المتقدم
  final TextEditingController _amountFromController = TextEditingController();
  final TextEditingController _amountToController = TextEditingController();
  String? selectedCashBox;
  List<dynamic> cashBoxes = [];

  @override
  void initState() {
    super.initState();
    _initializeDates();
    fetchExpenseGroups();
    fetchCashBoxes();
    fetchSummary();
    fetchExpenses();
  }

  void _initializeDates() {
    final now = DateTime.now();
    selectedStartDate = DateTime(now.year, now.month, 1);
    selectedEndDate = now;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountFromController.dispose();
    _amountToController.dispose();
    super.dispose();
  }

  Future<void> fetchExpenseGroups() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/expenses/groups'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        
        setState(() {
          allGroups = data;
          parentGroups = data.where((group) => 
            group['ParentGroupID'] == null
          ).toList();
          childGroups = data.where((group) => 
            group['ParentGroupID'] != null
          ).toList();
        });
      }
    } catch (e) {
      print('Error fetching expense groups: $e');
    }
  }

  Future<void> fetchCashBoxes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/cashboxes'));
      if (res.statusCode == 200) {
        setState(() {
          cashBoxes = jsonDecode(res.body);
        });
      }
    } catch (e) {
      print('Error fetching cash boxes: $e');
    }
  }

  Future<void> fetchChildGroupsByParent(int? parentId) async {
    try {
      if (parentId != null) {
        final childGroupsLocal = allGroups.where((group) => 
          group['ParentGroupID'] == parentId
        ).toList();
        
        setState(() {
          childGroups = childGroupsLocal;
          selectedGroupId = null;
        });
      } else {
        setState(() {
          childGroups = allGroups.where((group) => 
            group['ParentGroupID'] != null
          ).toList();
        });
      }
    } catch (e) {
      print('Error fetching child groups: $e');
    }
  }

  Future<void> fetchSummary() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/expenses/summary'));
      if (res.statusCode == 200) {
        setState(() => summary = jsonDecode(res.body));
      }
    } catch (e) {
      print('Error fetching summary: $e');
    }
  }

  Future<void> fetchExpenses() async {
    setState(() => loading = true);

    try {
      String url = '$baseUrl/api/expenses?';

      if (searchQuery.isNotEmpty) {
        url += 'search=${Uri.encodeComponent(searchQuery)}&';
      }
      if (selectedGroupId != null) {
        url += 'groupId=$selectedGroupId&';
      }
      if (selectedStartDate != null) {
        url += 'startDate=${selectedStartDate!.toIso8601String()}&';
      }
      if (selectedEndDate != null) {
        url += 'endDate=${selectedEndDate!.toIso8601String()}&';
      }

      // البحث المتقدم - إصلاح الباراميترات
      if (_amountFromController.text.isNotEmpty) {
        url += 'minAmount=${_amountFromController.text}&';
      }
      if (_amountToController.text.isNotEmpty) {
        url += 'maxAmount=${_amountToController.text}&';
      }
      if (selectedCashBox != null) {
        url += 'cashBoxId=$selectedCashBox&';
      }

      print('Fetching URL: $url'); // Debugging
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        setState(() {
          expenses = jsonDecode(res.body);
          loading = false;
        });
      } else {
        print('API Error: ${res.statusCode} - ${res.body}');
        setState(() => loading = false);
      }
    } catch (e) {
      print('Error fetching expenses: $e');
      setState(() => loading = false);
    }
  }

  Future<void> _refreshAll() async {
    await fetchSummary();
    await fetchExpenses();
  }

  void _onSearch(String value) {
    setState(() => searchQuery = value);
    fetchExpenses();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? selectedStartDate! : selectedEndDate!,
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
      setState(() {
        if (isStartDate) {
          selectedStartDate = picked;
        } else {
          selectedEndDate = picked;
        }
      });
      fetchExpenses();
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      searchQuery = '';
      selectedParentId = null;
      selectedGroupId = null;
      selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
      selectedEndDate = DateTime.now();
      _amountFromController.clear();
      _amountToController.clear();
      selectedCashBox = null;
      
      childGroups = allGroups.where((group) => 
        group['ParentGroupID'] != null
      ).toList();
    });
    
    fetchExpenses();
  }

  // دالة لتحديد اللون حسب حالة المصروف
  Color _getExpenseStatusColor(Map<String, dynamic> expense) {
    final amount = double.tryParse(expense['Amount'].toString()) ?? 0;
    final dateStr = expense['ExpenseDate'];
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    
    if (date != null) {
      final now = DateTime.now();
      final difference = now.difference(date);
      
      // إذا كان المصروف حديث (أقل من 3 أيام)
      if (difference.inDays < 3) {
        return Colors.green.withOpacity(0.3);
      }
      
      // إذا كان المصروف قديم (أكثر من 30 يوم)
      if (difference.inDays > 30) {
        return Colors.grey.withOpacity(0.2);
      }
    }
    
    // لون حسب المبلغ
    if (amount > 10000) {
      return Colors.red.withOpacity(0.15);
    } else if (amount > 5000) {
      return Colors.orange.withOpacity(0.15);
    } else if (amount > 1000) {
      return Colors.yellow.withOpacity(0.15);
    }
    
    return Colors.white.withOpacity(0.05);
  }

  // أيقونة حسب حالة المصروف
  IconData _getExpenseStatusIcon(Map<String, dynamic> expense) {
    final amount = double.tryParse(expense['Amount'].toString()) ?? 0;
    
    if (amount > 10000) return Icons.warning;
    if (amount > 5000) return Icons.trending_up;
    return Icons.attach_money;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSummarySection(),
          _buildSearchAndFilter(),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                  )
                : expenses.isEmpty
                    ? _buildEmptyState()
                    : _buildExpensesList(),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'المصروفات',
        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black),
      ),
      backgroundColor: const Color(0xFFE8B923),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_alt_off),
          onPressed: _clearAllFilters,
          tooltip: 'مسح كل الفلاتر',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshAll,
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    double filteredAmount = 0;
    if (expenses.isNotEmpty) {
      filteredAmount = expenses
          .map<double>((e) => double.tryParse(e['Amount'].toString()) ?? 0)
          .reduce((a, b) => a + b);
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.2),
            Colors.red.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'مصروفات اليوم',
                _formatCurrency(summary['todayAmount'] ?? 0),
                Icons.today,
                Colors.green,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Colors.white24,
            ),
            Expanded(
              child: _buildSummaryItem(
                'مصروفات الشهر',
                _formatCurrency(summary['monthAmount'] ?? 0),
                Icons.calendar_month,
                Colors.blue,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Colors.white24,
            ),
            Expanded(
              child: _buildSummaryItem(
                'إجمالي الفترة',
                _formatCurrency(filteredAmount),
                Icons.filter_alt,
                Colors.orange,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                color: Colors.grey[400],
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // الصف الأول: البحث + البحث المتقدم
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.cairo(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو المستلم...',
                    hintStyle: GoogleFonts.cairo(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFFFD700)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _onSearch,
                ),
              ),
              const SizedBox(width: 8),
              // زر البحث المتقدم كـ dropdown
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune, color: Color(0xFFFFD700)),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'advanced',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.attach_money, size: 18, color: Color(0xFFFFD700)),
                        SizedBox(width: 8),
                        Text('نطاق المبلغ', style: GoogleFonts.cairo(fontSize: 12)),
                      ],
                    ),
                  ),
                  if (cashBoxes.isNotEmpty)
                    PopupMenuItem(
                      value: 'cashbox',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet, size: 18, color: Color(0xFFFFD700)),
                          SizedBox(width: 8),
                          Text('الخزينة', style: GoogleFonts.cairo(fontSize: 12)),
                        ],
                      ),
                    ),
                ],
                onSelected: (value) {
                  if (value == 'advanced') {
                    _showAmountRangeDialog();
                  } else if (value == 'cashbox') {
                    _showCashBoxDialog();
                  }
                },
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // فلتر التاريخ (مصغر)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // من تاريخ مع أيقونة
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Color(0xFFFFD700)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedStartDate != null
                                  ? '${selectedStartDate!.day}/${selectedStartDate!.month}'
                                  : 'من',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // سهم الفاصل
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                ),
                
                // إلى تاريخ مع أيقونة
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Color(0xFFFFD700)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              selectedEndDate != null
                                  ? '${selectedEndDate!.day}/${selectedEndDate!.month}'
                                  : 'إلى',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // أزرار تاريخ سريعة مصغرة
                SizedBox(width: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    _buildSmallDateButton('اليوم', 0),
                    _buildSmallDateButton('7 أيام', 7),
                    _buildSmallDateButton('شهر', 30),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // الصف الثالث: المجموعات الأساسية والفرعية في سطر واحد
          Row(
            children: [
              // المجموعة الأساسية
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: selectedParentId,
                      isExpanded: true,
                      hint: Text(
                        'المجموعة الأساسية',
                        style: GoogleFonts.cairo(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1A1A1A),
                      icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFFFFD700)),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'الكل',
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        ...parentGroups.map((parent) => DropdownMenuItem<int?>(
                              value: parent['ExpenseGroupID'],
                              child: Text(
                                parent['ExpenseGroupName'],
                                style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedParentId = value;
                        });
                        
                        fetchChildGroupsByParent(value);
                        fetchExpenses();
                      },
                    ),
                  ),
                ),
              ),
              
              SizedBox(width: 8),
              
              // المجموعة الفرعية
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: selectedGroupId,
                      isExpanded: true,
                      hint: Text(
                        'المجموعة الفرعية',
                        style: GoogleFonts.cairo(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      dropdownColor: const Color(0xFF1A1A1A),
                      icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFFFFD700)),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'الكل',
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        ...childGroups.map((group) => DropdownMenuItem<int?>(
                              value: group['ExpenseGroupID'],
                              child: Text(
                                group['ExpenseGroupName'],
                                style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => selectedGroupId = value);
                        fetchExpenses();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallDateButton(String label, int days) {
    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        setState(() {
          selectedStartDate = now.subtract(Duration(days: days));
          selectedEndDate = now;
        });
        fetchExpenses();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showAmountRangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'نطاق المبلغ',
          style: GoogleFonts.cairo(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountFromController,
                    style: GoogleFonts.cairo(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'الحد الأدنى',
                      hintStyle: GoogleFonts.cairo(color: Colors.white54),
                      prefixIcon: Icon(Icons.arrow_upward, color: Color(0xFFFFD700)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountToController,
                    style: GoogleFonts.cairo(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'الحد الأقصى',
                      hintStyle: GoogleFonts.cairo(color: Colors.white54),
                      prefixIcon: Icon(Icons.arrow_downward, color: Color(0xFFFFD700)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // أزرار مبلغ سريعة
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAmountButton('1000+', 1000, null),
                _buildAmountButton('5000+', 5000, null),
                _buildAmountButton('10000+', 10000, null),
                _buildAmountButton('> 50000', 50000, null),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _amountFromController.clear();
                _amountToController.clear();
              });
              Navigator.pop(context);
              fetchExpenses();
            },
            child: Text('مسح', style: GoogleFonts.cairo(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // التأكد من أن القيم صحيحة
              if (_amountFromController.text.isNotEmpty && 
                  double.tryParse(_amountFromController.text) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('القيمة الدنيا غير صالحة'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (_amountToController.text.isNotEmpty && 
                  double.tryParse(_amountToController.text) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('القيمة العليا غير صالحة'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              fetchExpenses();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
            ),
            child: Text('تطبيق', style: GoogleFonts.cairo(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountButton(String label, double? from, double? to) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _amountFromController.text = from?.toString() ?? '';
          _amountToController.text = '';
        });
        fetchExpenses();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showCashBoxDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'اختر الخزينة',
          style: GoogleFonts.cairo(color: Colors.white),
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cashBoxes.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: Text(
                    'كل الخزائن',
                    style: GoogleFonts.cairo(color: Colors.white),
                  ),
                  leading: Icon(Icons.all_inclusive, color: Color(0xFFFFD700)),
                  onTap: () {
                    setState(() => selectedCashBox = null);
                    Navigator.pop(context);
                    fetchExpenses();
                  },
                );
              }
              
              final cashBox = cashBoxes[index - 1];
              return ListTile(
                title: Text(
                  cashBox['CashBoxName'],
                  style: GoogleFonts.cairo(color: Colors.white),
                ),
                leading: Icon(Icons.account_balance_wallet, color: Color(0xFFFFD700)),
                onTap: () {
                  setState(() => selectedCashBox = cashBox['CashBoxID'].toString());
                  Navigator.pop(context);
                  fetchExpenses();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 20),
          Text(
            'لا توجد مصروفات',
            style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey[400]),
          ),
          const SizedBox(height: 10),
          Text(
            'اضغط + لإضافة مصروف جديد',
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: const Color(0xFFE8B923),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: expenses.length,
        itemBuilder: (context, index) {
          final expense = expenses[index];
          return _buildExpenseCard(expense, index);
        },
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense, int index) {
    final date = DateTime.tryParse(expense['ExpenseDate'] ?? '');
    final formattedDate = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : '';

    return Card(
      color: _getExpenseStatusColor(expense),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showExpenseDetails(expense),
        onLongPress: () => _showExpenseOptions(expense),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // المؤشر اللوني للحالة
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.withOpacity(0.4),
                      Colors.red.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Icon(
                  _getExpenseStatusIcon(expense),
                  color: Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expense['ExpenseName'] ?? '',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // مؤشر حالة صغير
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getExpenseStatusColor(expense).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getExpenseStatusText(expense),
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.category_outlined,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            expense['ExpenseGroupName'] ?? '',
                            style: GoogleFonts.cairo(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (expense['Torecipient'] != null &&
                        expense['Torecipient'].toString().isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              expense['Torecipient'],
                              style: GoogleFonts.cairo(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_formatNumber(expense['Amount'])} ج.م',
                      style: GoogleFonts.cairo(
                        color: Colors.red[300],
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: GoogleFonts.cairo(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }

  // دالة للحصول على نص الحالة
  String _getExpenseStatusText(Map<String, dynamic> expense) {
    final amount = double.tryParse(expense['Amount'].toString()) ?? 0;
    final dateStr = expense['ExpenseDate'];
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    
    if (date != null) {
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays < 3) return 'جديد';
      if (difference.inDays > 30) return 'قديم';
    }
    
    if (amount > 10000) return 'كبير';
    if (amount > 5000) return 'متوسط';
    if (amount > 1000) return 'صغير';
    
    return 'عادي';
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    final createdDate = DateTime.tryParse(expense['CreatedAt'] ?? '');
    final formattedCreatedDate = createdDate != null
        ? '${createdDate.day}/${createdDate.month}/${createdDate.year} ${createdDate.hour}:${createdDate.minute.toString().padLeft(2, '0')}'
        : 'غير متوفر';
    
    // تحديد لون الحالة
    final statusColor = _getExpenseStatusColor(expense);
    final statusText = _getExpenseStatusText(expense);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // رأس البطاقة مع مؤشر الحالة
            Row(
              children: [
                Expanded(
                  child: Text(
                    expense['ExpenseName'] ?? '',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            _buildDetailRow(
                Icons.attach_money, 'المبلغ', '${_formatNumber(expense['Amount'])} ج.م'),
            _buildDetailRow(
                Icons.category, 'التصنيف', expense['ExpenseGroupName'] ?? ''),
            _buildDetailRow(
                Icons.account_balance_wallet, 'الخزينة', expense['CashBoxName'] ?? ''),
            if (expense['PaymentMethod'] != null)
              _buildDetailRow(
                  Icons.payment, 'طريقة الدفع', expense['PaymentMethod']),
            if (expense['Torecipient'] != null)
              _buildDetailRow(
                  Icons.person, 'المستلم', expense['Torecipient']),
            if (expense['Notes'] != null && expense['Notes'].toString().isNotEmpty)
              _buildDetailRow(Icons.notes, 'ملاحظات', expense['Notes']),
            _buildDetailRow(Icons.person_outline, 'تم الإضافة بواسطة', expense['CreatedBy'] ?? ''),
            _buildDetailRow(Icons.access_time, 'تاريخ الإضافة', formattedCreatedDate),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 20),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseOptions(Map<String, dynamic> expense) {
    final permissions = PermissionService();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (permissions.canEdit(FormNames.expensesAdd))
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFFFFD700)),
                title: Text('تعديل', style: GoogleFonts.cairo(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddExpenseScreen(
                        username: widget.username,
                        existingExpense: expense,
                      ),
                    ),
                  ).then((_) => _refreshAll());
                },
              ),
            if (permissions.canDelete(FormNames.expensesAdd))
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(expense);
                },
              ),
            if (!permissions.canEdit(FormNames.expensesAdd) && 
                !permissions.canDelete(FormNames.expensesAdd))
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'ليس لديك صلاحيات للتعديل أو الحذف',
                  style: GoogleFonts.cairo(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.cairo(color: Colors.white),
        ),
        content: Text(
          'هل تريد حذف "${expense['ExpenseName']}"؟',
          style: GoogleFonts.cairo(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteExpense(expense['ExpenseID']);
            },
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(int id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/api/expenses/$id'));
      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الحذف بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
          ),
        );
        _refreshAll();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في الحذف', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildFAB() {
  // ⭐⭐⭐ التحقق من صلاحية الإضافة ⭐⭐⭐
  if (!PermissionService().canAdd('frm_Expenses')) {
    return const SizedBox.shrink();
  }
  
  return FloatingActionButton.extended(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddExpenseScreen(username: widget.username),
        ),
      ).then((_) => _refreshAll());
    },
    backgroundColor: const Color(0xFFE8B923),
    icon: const Icon(Icons.add, color: Colors.black),
    label: Text(
      'إضافة مصروف',
      style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold),
    ),
  );
}

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 ج.م';
    final num = double.tryParse(amount.toString()) ?? 0;
    return '${_formatNumber(num.toInt())} ج.م';
  }
}