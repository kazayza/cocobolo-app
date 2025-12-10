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
  List<dynamic> expenseGroups = [];
  Map<String, dynamic> summary = {};
  bool loading = true;

  final TextEditingController _searchController = TextEditingController();
  int? selectedGroupId;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchExpenseGroups();
    fetchSummary();
    fetchExpenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchExpenseGroups() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/expense-groups'));
      if (res.statusCode == 200) {
        setState(() => expenseGroups = jsonDecode(res.body));
      }
    } catch (e) {
      print('Error fetching expense groups: $e');
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
        url += 'groupId=$selectedGroupId';
      }

      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        setState(() {
          expenses = jsonDecode(res.body);
          loading = false;
        });
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

  void _onFilterChanged(int? groupId) {
    setState(() => selectedGroupId = groupId);
    fetchExpenses();
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
          icon: const Icon(Icons.refresh),
          onPressed: _refreshAll,
        ),
      ],
    );
  }

  // ✅ Summary Section معدل
  Widget _buildSummarySection() {
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
                _formatCurrency(summary['todayAmount']),
                Icons.today,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Colors.white24,
            ),
            Expanded(
              child: _buildSummaryItem(
                'إجمالي المصروفات',
                _formatCurrency(summary['totalAmount']),
                Icons.account_balance_wallet,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // ✅ Summary Item معدل مع FittedBox
  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.red[300], size: 20),
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
          TextField(
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: selectedGroupId,
                isExpanded: true,
                hint: Text(
                  'كل التصنيفات',
                  style: GoogleFonts.cairo(color: Colors.white70),
                ),
                dropdownColor: const Color(0xFF1A1A1A),
                icon: const Icon(Icons.filter_list, color: Color(0xFFFFD700)),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'كل التصنيفات',
                      style: GoogleFonts.cairo(color: Colors.white),
                    ),
                  ),
                  ...expenseGroups.map((group) => DropdownMenuItem<int?>(
                        value: group['ExpenseGroupID'],
                        child: Text(
                          group['ExpenseGroupName'],
                          style: GoogleFonts.cairo(color: Colors.white),
                        ),
                      )),
                ],
                onChanged: _onFilterChanged,
              ),
            ),
          ),
        ],
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

  // ✅ Expense Card معدل
  Widget _buildExpenseCard(Map<String, dynamic> expense, int index) {
    final date = DateTime.tryParse(expense['ExpenseDate'] ?? '');
    final formattedDate = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : '';

    return Card(
      color: Colors.white.withOpacity(0.08),
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
              // الأيقونة
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  color: Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              
              // التفاصيل
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense['ExpenseName'] ?? '',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              
              // المبلغ والتاريخ
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

  void _showExpenseDetails(Map<String, dynamic> expense) {
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
            Text(
              expense['ExpenseName'] ?? '',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
                Icons.attach_money, 'المبلغ', '${expense['Amount']} ج.م'),
            _buildDetailRow(
                Icons.category, 'التصنيف', expense['ExpenseGroupName'] ?? ''),
            _buildDetailRow(
                Icons.account_balance_wallet, 'الخزينة', expense['CashBoxName'] ?? ''),
            if (expense['Torecipient'] != null)
              _buildDetailRow(
                  Icons.person, 'المستلم', expense['Torecipient']),
            if (expense['Notes'] != null && expense['Notes'].toString().isNotEmpty)
              _buildDetailRow(Icons.notes, 'ملاحظات', expense['Notes']),
            _buildDetailRow(Icons.person_outline, 'بواسطة', expense['CreatedBy'] ?? ''),
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
    if (!PermissionService().canAdd(FormNames.expensesAdd)) {
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