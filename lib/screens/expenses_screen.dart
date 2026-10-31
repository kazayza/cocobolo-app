import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/expense_service.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../core/network/api_client.dart';
import '../widgets/design_kit.dart';
import 'add_expense_screen.dart';

/// قائمة المصروفات — هوية واعية بالوضع (فاتح/داكن) عبر ThemeService
/// وAppColors، وعقد خادم كامل: فلاتر ExpenseFilterDto + صفحات + إحصائيات
/// GetStatsAsync. الافتراضي بلا قيد تاريخ (مطابقة بلازور)، ولا شارات
/// مخترعة — الشارات الوحيدة هي «مصروف مقدم/شهر فرعي» من حقول المقدم.
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
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> allGroups = [];
  List<Map<String, dynamic>> cashBoxes = [];
  Map<String, dynamic> summary = {};
  bool loading = true;
  bool loadingMore = false;
  String? _error;
  String? _summaryError;
  int _page = 1;
  int _totalCount = 0;
  static const int _pageSize = 25;

  final TextEditingController _searchController = TextEditingController();
  int? selectedGroupId;
  int? selectedParentId;
  String searchQuery = '';

  // بلا قيد تاريخ افتراضيًا — «مسح الفلاتر» يعيد هذا الوضع (مطابقة بلازور)
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  String _amountFromText = '';
  String _amountToText = '';
  int? selectedCashBoxId;

  bool get _isDark => ThemeService().isDarkMode;

  List<Map<String, dynamic>> get parentGroups =>
      allGroups.where((g) => g['ParentGroupID'] == null).toList();

  List<Map<String, dynamic>> get childGroups {
    if (selectedParentId == null) {
      return allGroups.where((g) => g['ParentGroupID'] != null).toList();
    }
    return allGroups
        .where((g) => g['ParentGroupID'] == selectedParentId)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _refreshAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _dateStr(DateTime? d) =>
      d == null ? null : DateFormat('yyyy-MM-dd').format(d);

  double? _amountValue(String text) =>
      text.trim().isEmpty ? null : double.tryParse(text.trim());

  Future<void> _loadLookups() async {
    try {
      final groups = await ExpenseService.getExpenseGroups();
      if (mounted) setState(() => allGroups = groups);
    } catch (_) {
      // قوائم الفلاتر تكميلية — فشلها لا يوقف القائمة نفسها
    }
    try {
      final boxes = await ExpenseService.getCashBoxes();
      if (mounted) setState(() => cashBoxes = boxes);
    } catch (_) {}
  }

  Future<void> fetchSummary() async {
    try {
      final s = await ExpenseService.getSummary(
        search: searchQuery,
        groupId: selectedGroupId,
        parentGroupId: selectedParentId,
        cashBoxId: selectedCashBoxId,
        startDate: _dateStr(selectedStartDate),
        endDate: _dateStr(selectedEndDate),
        amountFrom: _amountValue(_amountFromText),
        amountTo: _amountValue(_amountToText),
      );
      if (mounted) {
        setState(() {
          summary = s ?? {};
          _summaryError = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _summaryError = e.message);
    } catch (_) {
      if (mounted) setState(() => _summaryError = 'فشل تحميل الإحصائيات');
    }
  }

  Future<void> fetchExpenses({bool append = false}) async {
    setState(() {
      if (append) {
        loadingMore = true;
      } else {
        loading = true;
        _error = null;
        _page = 1;
      }
    });
    try {
      final paged = await ExpenseService.getExpensesPaged(
        search: searchQuery,
        groupId: selectedGroupId,
        parentGroupId: selectedParentId,
        cashBoxId: selectedCashBoxId,
        startDate: _dateStr(selectedStartDate),
        endDate: _dateStr(selectedEndDate),
        amountFrom: _amountValue(_amountFromText),
        amountTo: _amountValue(_amountToText),
        page: append ? _page + 1 : 1,
        pageSize: _pageSize,
      );
      final items = (paged['items'] as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          if (append) {
            expenses = [...expenses, ...items];
            _page += 1;
          } else {
            expenses = items;
          }
          _totalCount = (paged['totalCount'] as num?)?.toInt() ?? items.length;
          loading = false;
          loadingMore = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          loading = false;
          loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'فشل الاتصال بالخادم';
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([fetchSummary(), fetchExpenses()]);
  }

  void _onSearch(String value) {
    setState(() => searchQuery = value);
    _refreshAll();
  }

  Future<void> _selectDate(bool isStartDate) async {
    final initial = (isStartDate ? selectedStartDate : selectedEndDate) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          selectedStartDate = picked;
        } else {
          selectedEndDate = picked;
        }
      });
      _refreshAll();
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      searchQuery = '';
      selectedParentId = null;
      selectedGroupId = null;
      selectedStartDate = null; // بلا قيد تاريخ — مطابقة بلازور
      selectedEndDate = null;
      _amountFromText = '';
      _amountToText = '';
      selectedCashBoxId = null;
    });
    _refreshAll();
  }

  // قفل تعديل المقدم (ExpenseService.cs:620-633): الشهر الفرعي ممنوع
  // والأصل المقدم ممنوع — برسائل بلازور نفسها.
  bool _isAdvanceLocked(Map<String, dynamic> e) {
    if (e['AdvanceParentExpenseId'] != null) return true;
    final months = (e['AdvanceMonths'] as num?)?.toInt() ?? 0;
    return e['IsAdvance'] == true && months > 1;
  }

  String _advanceLockHint(Map<String, dynamic> e) {
    if (e['AdvanceParentExpenseId'] != null) {
      return 'هذا شهر فرعي من مصروف مقدم - لا يمكن تعديله. عدّل الأصل أو احذفه.';
    }
    return 'لا يمكن تعديل مصروف مقدم بعد الحفظ. احذفه وأنشئ واحد جديد.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSummarySection(isDark),
          _buildSearchAndFilter(isDark),
          Expanded(
            child: loading
                ? const AppLoading()
                : _error != null
                    ? AppError(message: _error!, onRetry: _refreshAll)
                    : expenses.isEmpty
                        ? _buildEmptyState()
                        : _buildExpensesList(isDark),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'المصروفات',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
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

  Widget _buildSummarySection(bool isDark) {
    if (_summaryError != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.10),
          borderRadius: AppRadius.all(AppRadius.md),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                size: 18, color: isDark ? AppColors.errorLight : AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_summaryError!,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.text(isDark))),
            ),
            TextButton(onPressed: fetchSummary, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    final periodLabel =
        summary['isPeriod'] == true ? 'إجمالي الفترة' : 'مصروفات الشهر';
    final breakdown = (summary['groupBreakdown'] as List?) ?? const [];
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: AppStatCard(
                  label: 'اليوم (${summary['todayCount'] ?? 0})',
                  value: _formatCurrency(summary['todayAmount']),
                  color: isDark ? AppColors.successLight : AppColors.success,
                  icon: Icons.today_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatCard(
                  label: '$periodLabel (${summary['monthCount'] ?? 0})',
                  value: _formatCurrency(summary['monthAmount']),
                  color: isDark ? AppColors.infoLight : AppColors.info,
                  icon: Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatCard(
                  label: 'السنة (${summary['yearCount'] ?? 0})',
                  value: _formatCurrency(summary['yearAmount']),
                  color: AppColors.gold,
                  icon: Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatCard(
                  label: 'الإجمالي (${summary['totalCount'] ?? 0})',
                  value: _formatCurrency(summary['totalAmount']),
                  color: isDark ? AppColors.errorLight : AppColors.error,
                  icon: Icons.summarize_rounded,
                ),
              ),
            ],
          ),
        ),
        if (breakdown.isNotEmpty)
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: breakdown.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final g = Map<String, dynamic>.from(breakdown[i] as Map);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface(isDark),
                    borderRadius: AppRadius.all(AppRadius.pill),
                    border: Border.all(color: AppColors.divider(isDark)),
                  ),
                  child: Text(
                    '${g['GroupName'] ?? ''}: ${_formatNumber(g['Total'])} (${g['Percentage'] ?? 0}%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    final fill = AppColors.inputFill(isDark);
    final textColor = AppColors.text(isDark);
    final hintColor = AppColors.textHint(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو المستلم أو المجموعة...',
                    hintStyle: TextStyle(color: hintColor),
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.gold),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: hintColor),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: fill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _onSearch,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune, color: AppColors.gold),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'advanced',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(Icons.attach_money, size: 18, color: AppColors.gold),
                        SizedBox(width: 8),
                        Text('نطاق المبلغ', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  if (cashBoxes.isNotEmpty)
                    const PopupMenuItem(
                      value: 'cashbox',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              size: 18, color: AppColors.gold),
                          SizedBox(width: 8),
                          Text('الخزينة', style: TextStyle(fontSize: 12)),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(true),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: AppColors.gold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            selectedStartDate != null
                                ? '${selectedStartDate!.day}/${selectedStartDate!.month}/${selectedStartDate!.year}'
                                : 'من (بلا قيد)',
                            style: TextStyle(color: textColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward,
                      size: 14, color: AppColors.textSecondary(isDark)),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(false),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: AppColors.gold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            selectedEndDate != null
                                ? '${selectedEndDate!.day}/${selectedEndDate!.month}/${selectedEndDate!.year}'
                                : 'إلى (بلا قيد)',
                            style: TextStyle(color: textColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    _buildSmallDateButton('اليوم', 0, isDark),
                    _buildSmallDateButton('7 أيام', 7, isDark),
                    _buildSmallDateButton('شهر', 30, isDark),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGroupDropdown(
                  isDark: isDark,
                  value: selectedParentId,
                  hint: 'المجموعة الأساسية',
                  items: parentGroups,
                  onChanged: (value) {
                    setState(() {
                      selectedParentId = value;
                      selectedGroupId = null;
                    });
                    _refreshAll();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildGroupDropdown(
                  isDark: isDark,
                  value: selectedGroupId,
                  hint: 'المجموعة الفرعية',
                  items: childGroups,
                  onChanged: (value) {
                    setState(() => selectedGroupId = value);
                    _refreshAll();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupDropdown({
    required bool isDark,
    required int? value,
    required String hint,
    required List<Map<String, dynamic>> items,
    required ValueChanged<int?> onChanged,
  }) {
    // حماية وضع التعديل/القيم الإرثية: قيمة غير موجودة في القائمة تُصفّى
    final safeValue =
        items.any((g) => g['ExpenseGroupID'] == value) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill(isDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: safeValue,
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(
                color: AppColors.textSecondary(isDark), fontSize: 11),
          ),
          dropdownColor: AppColors.surface(isDark),
          icon: const Icon(Icons.arrow_drop_down,
              size: 20, color: AppColors.gold),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'الكل',
                style: TextStyle(color: AppColors.text(isDark), fontSize: 12),
              ),
            ),
            ...items.map((g) => DropdownMenuItem<int?>(
                  value: (g['ExpenseGroupID'] as num).toInt(),
                  child: Text(
                    g['ExpenseGroupName']?.toString() ?? '',
                    style:
                        TextStyle(color: AppColors.text(isDark), fontSize: 12),
                  ),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSmallDateButton(String label, int days, bool isDark) {
    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        setState(() {
          selectedStartDate = now.subtract(Duration(days: days));
          selectedEndDate = now;
        });
        _refreshAll();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.text(isDark)),
        ),
      ),
    );
  }

  Future<void> _showAmountRangeDialog() async {
    // وحدات تحكم مملوكة للحوار نفسه وتُحرَّر عند إغلاقه
    final fromCtrl = TextEditingController(text: _amountFromText);
    final toCtrl = TextEditingController(text: _amountToText);
    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('نطاق المبلغ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: fromCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'الحد الأدنى',
                      prefixIcon:
                          Icon(Icons.arrow_upward, color: AppColors.gold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: toCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'الحد الأقصى',
                      prefixIcon:
                          Icon(Icons.arrow_downward, color: AppColors.gold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in [1000, 5000, 10000, 50000])
                  ActionChip(
                    label: Text('$v+'),
                    onPressed: () => fromCtrl.text = '$v',
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              fromCtrl.clear();
              toCtrl.clear();
              Navigator.pop(dialogContext, true);
            },
            child: Text('مسح',
                style: TextStyle(
                    color: _isDark ? AppColors.errorLight : AppColors.error)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
    if (applied == true) {
      if ((fromCtrl.text.isNotEmpty &&
              double.tryParse(fromCtrl.text) == null) ||
          (toCtrl.text.isNotEmpty && double.tryParse(toCtrl.text) == null)) {
        _showSnack('قيمة المبلغ غير صالحة', isError: true);
      } else {
        setState(() {
          _amountFromText = fromCtrl.text;
          _amountToText = toCtrl.text;
        });
        _refreshAll();
      }
    }
    fromCtrl.dispose();
    toCtrl.dispose();
  }

  void _showCashBoxDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اختر الخزينة'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cashBoxes.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: const Text('كل الخزائن'),
                  leading:
                      const Icon(Icons.all_inclusive, color: AppColors.gold),
                  onTap: () {
                    setState(() => selectedCashBoxId = null);
                    Navigator.pop(dialogContext);
                    _refreshAll();
                  },
                );
              }
              final cashBox = cashBoxes[index - 1];
              return ListTile(
                title: Text(cashBox['CashBoxName']?.toString() ?? ''),
                subtitle: cashBox['BranchName'] != null
                    ? Text(cashBox['BranchName'].toString())
                    : null,
                leading: const Icon(Icons.account_balance_wallet,
                    color: AppColors.gold),
                onTap: () {
                  setState(() => selectedCashBoxId =
                      (cashBox['CashBoxID'] as num).toInt());
                  Navigator.pop(dialogContext);
                  _refreshAll();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmpty(
      icon: Icons.receipt_long_outlined,
      message: 'لا توجد مصروفات',
      hint: 'اضغط + لإضافة مصروف جديد',
    );
  }

  Widget _buildExpensesList(bool isDark) {
    final hasMore = expenses.length < _totalCount;
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: AppColors.gold,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: expenses.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == expenses.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AppButton(
                label: loadingMore
                    ? 'جاري التحميل...'
                    : 'تحميل المزيد (${expenses.length} من $_totalCount)',
                icon: Icons.expand_more_rounded,
                color: AppColors.gold,
                onTap: () {
                  if (!loadingMore) fetchExpenses(append: true);
                },
              ),
            );
          }
          return _buildExpenseCard(expenses[index], index, isDark);
        },
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense, int index, bool isDark) {
    final date = DateTime.tryParse(expense['ExpenseDate']?.toString() ?? '');
    final formattedDate =
        date != null ? '${date.day}/${date.month}/${date.year}' : '';
    final isParent = expense['IsAdvance'] == true &&
        expense['AdvanceParentExpenseId'] == null;
    final isChild = expense['AdvanceParentExpenseId'] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
      padding: const EdgeInsets.all(12),
      radius: AppRadius.lg,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showExpenseDetails(expense),
        onLongPress: () => _showExpenseOptions(expense),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: _isDark ? AppColors.errorLight : AppColors.error,
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
                          expense['ExpenseName']?.toString() ?? '',
                          style: TextStyle(
                            color: AppColors.text(isDark),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isParent)
                        const StatusBadge(
                          label: 'مصروف مقدم',
                          color: AppColors.gold,
                          small: true,
                        ),
                      if (isChild)
                        StatusBadge(
                          label: 'شهر فرعي',
                          color: _isDark ? AppColors.infoLight : AppColors.info,
                          small: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.category_outlined,
                          size: 12, color: AppColors.textHint(isDark)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (expense['FullGroupPath'] ??
                                  expense['ExpenseGroupName'] ??
                                  '')
                              .toString(),
                          style: TextStyle(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (expense['BranchName'] != null)
                    Row(
                      children: [
                        Icon(Icons.store_outlined,
                            size: 12, color: AppColors.textHint(isDark)),
                        const SizedBox(width: 4),
                        Text(
                          expense['BranchName'].toString(),
                          style: TextStyle(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  if (expense['Torecipient'] != null &&
                      expense['Torecipient'].toString().isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 12, color: AppColors.textHint(isDark)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            expense['Torecipient'].toString(),
                            style: TextStyle(
                              color: AppColors.textSecondary(isDark),
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
                AmountText(
                  value: '${_formatNumber(expense['Amount'])} ج.م',
                  color: _isDark ? AppColors.errorLight : AppColors.error,
                  size: 14,
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: AppColors.textHint(isDark),
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
        .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms)
        .slideX(begin: 0.1, end: 0);
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    final isDark = _isDark;
    final createdDate =
        DateTime.tryParse(expense['CreatedAt']?.toString() ?? '');
    final formattedCreatedDate = createdDate != null
        ? '${createdDate.day}/${createdDate.month}/${createdDate.year} ${createdDate.hour}:${createdDate.minute.toString().padLeft(2, '0')}'
        : 'غير متوفر';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
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
                  color: AppColors.divider(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              expense['ExpenseName']?.toString() ?? '',
              style: TextStyle(
                color: AppColors.text(isDark),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.attach_money, 'المبلغ',
                '${_formatNumber(expense['Amount'])} ج.م', isDark),
            _buildDetailRow(
                Icons.category,
                'المجموعة',
                (expense['FullGroupPath'] ?? expense['ExpenseGroupName'] ?? '')
                    .toString(),
                isDark),
            if (expense['BranchName'] != null)
              _buildDetailRow(
                  Icons.store, 'الفرع', expense['BranchName'].toString(), isDark),
            _buildDetailRow(Icons.account_balance_wallet, 'الخزينة',
                expense['CashBoxName']?.toString() ?? '', isDark),
            if (expense['Torecipient'] != null &&
                expense['Torecipient'].toString().isNotEmpty)
              _buildDetailRow(Icons.person, 'المستلم',
                  expense['Torecipient'].toString(), isDark),
            if (expense['Notes'] != null &&
                expense['Notes'].toString().isNotEmpty)
              _buildDetailRow(
                  Icons.notes, 'ملاحظات', expense['Notes'].toString(), isDark),
            if (expense['IsAdvance'] == true &&
                expense['AdvanceParentExpenseId'] == null)
              _buildDetailRow(Icons.schedule, 'مصروف مقدم',
                  '${expense['AdvanceMonths'] ?? ''} أشهر', isDark),
            if (expense['AdvanceParentExpenseId'] != null)
              _buildDetailRow(Icons.calendar_month, 'شهر فرعي',
                  'الشهر ${expense['AdvanceMonthIndex'] ?? ''} من مصروف مقدم', isDark),
            _buildDetailRow(Icons.person_outline, 'تم الإضافة بواسطة',
                expense['CreatedBy']?.toString() ?? '', isDark),
            _buildDetailRow(
                Icons.access_time, 'تاريخ الإضافة', formattedCreatedDate, isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
                color: AppColors.textSecondary(isDark), fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.text(isDark), fontSize: 14),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseOptions(Map<String, dynamic> expense) {
    final isDark = _isDark;
    final permissions = PermissionService();
    final canEdit = permissions.canEdit(FormNames.expensesAdd);
    // بوابة حذف القائمة في بلازور هي frm_ExpensesList:Delete
    final canDelete = permissions.canDelete(FormNames.expensesList);
    final locked = _isAdvanceLocked(expense);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit && !locked)
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.gold),
                title: Text('تعديل',
                    style: TextStyle(color: AppColors.text(isDark))),
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
            if (canEdit && locked)
              ListTile(
                leading: Icon(Icons.lock_outline,
                    color: AppColors.textHint(isDark)),
                title: Text('تعديل',
                    style: TextStyle(color: AppColors.textHint(isDark))),
                subtitle: Text(
                  _advanceLockHint(expense),
                  style: TextStyle(
                      color: AppColors.textSecondary(isDark), fontSize: 11),
                ),
              ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete,
                    color: _isDark ? AppColors.errorLight : AppColors.error),
                title: Text('حذف',
                    style: TextStyle(
                        color:
                            _isDark ? AppColors.errorLight : AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(expense);
                },
              ),
            if (!canEdit && !canDelete)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'ليس لديك صلاحيات للتعديل أو الحذف',
                  style: TextStyle(color: AppColors.textSecondary(isDark)),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف "${expense['ExpenseName']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteExpense((expense['ExpenseID'] as num).toInt());
            },
            child: Text('حذف',
                style: TextStyle(
                    color: _isDark ? AppColors.errorLight : AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(int id) async {
    try {
      final result = await ExpenseService.deleteExpense(id);
      _showSnack(result['message']?.toString() ?? 'تم الحذف بنجاح');
      _refreshAll();
    } on ApiException catch (e) {
      // رفض الخادم (صلاحية/قاعدة) يظهر برسالة الخادم نفسها — لا فشل صامت
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('فشل الاتصال بالخادم', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  Widget _buildFAB() {
    if (!PermissionService().canAdd(FormNames.expensesAdd)) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton(
      mini: true,
      tooltip: 'إضافة مصروف',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddExpenseScreen(username: widget.username),
          ),
        ).then((_) => _refreshAll());
      },
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.navy,
      child: const Icon(Icons.add, color: AppColors.navy),
    );
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    final n = double.tryParse(number.toString()) ?? 0;
    return NumberFormat('#,##0.##').format(n);
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 ج.م';
    return '${_formatNumber(amount)} ج.م';
  }
}
