import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/home/widgets/home_accent.dart';
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../services/permission_service.dart';
import '../../widgets/design_kit.dart';
import '../../services/invoice_service.dart';
import '../../core/network/api_client.dart';
import 'invoice_details_screen.dart';
import 'add_invoice_screen.dart';

import '../../widgets/app_drawer.dart';
/// ─────────────────────────────────────────────────────────────
///  إدارة الفواتير — نسخة مطابقة لصفحة SalesList في بلازور
///  - كروت إحصائيات (إجمالي/مبيعات/محصل/متبقي/اليوم/متأخرة)
///  - تبويبات: مبيعات / مشتريات (حسب الصلاحية)
///  - فلاتر: بحث + تاريخ + حالة + سداد — مع حفظ الفلاتر
///  - جدول بكل التفاصيل + الحالات + الإجراءات
/// ─────────────────────────────────────────────────────────────
class SalesInvoicesScreen extends StatefulWidget {
  final int userId;
  final String username;

  /// التبويب الافتتاحي: 'Sale' (مبيعات) أو 'Purchase' (مشتريات)
  final String initialTab;

  const SalesInvoicesScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialTab = 'Sale',
  });

  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  static const _filtersKey = 'invoices_filters_v1';

  List<Map<String, dynamic>> _invoices = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String? _error;

  // ── التبويب النشط ─────────────────────────────────────
  String _activeTab = 'Sale'; // Sale | Purchase

  // ── الفلاتر ───────────────────────────────────────────
  String _searchText = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _statusFilter; // Open | PartiallyPaid | Paid | Cancelled
  bool? _hasRemaining; // true = فيها متبقي | false = مسددة
  bool? _isOverdue;
  int _page = 1;
  final int _pageSize = 20;

  final PermissionService _perms = PermissionService();

  // ── الصلاحيات ─────────────────────────────────────────
  bool get _canViewPurchases => _perms.canViewPurchaseInvoices;

  bool get _canSeeAmounts => _activeTab == 'Sale'
      ? _perms.canViewSalesInvoices
      : _perms.canViewPurchaseInvoices;

  bool get _canSeeInvoices => _activeTab == 'Sale'
      ? _perms.canViewSalesInvoices
      : _perms.canViewPurchaseInvoices;

  bool get _canSeeProfit =>
      _activeTab == 'Sale' && _perms.canViewInvoiceProfit;

  bool get _canAdd => _activeTab == 'Sale'
      ? (_perms.isAdmin || _perms.canAdd('frm_SalesInvoiveNew'))
      : (_perms.isAdmin ||
          _perms.isFactory ||
          _perms.canView('frm_SupplierInvoices'));

  @override
  void initState() {
    super.initState();
    // التبويب الافتتاحي (من المدخل)
    _activeTab = widget.initialTab;
    _restoreFilters();
    _loadData();
  }

  // ═══════════════════════════════════════════════════════════
  // حفظ واستعادة الفلاتر
  // ═══════════════════════════════════════════════════════════
  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _filtersKey,
        jsonEncode({
          'tab': _activeTab,
          'search': _searchText,
          'dateFrom': _dateFrom?.toIso8601String(),
          'dateTo': _dateTo?.toIso8601String(),
          'status': _statusFilter,
          'hasRemaining': _hasRemaining,
          'isOverdue': _isOverdue,
          'page': _page,
        }),
      );
    } catch (_) {}
  }

  Future<void> _restoreFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_filtersKey);
      if (raw == null) return;
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _activeTab = saved['tab'] ?? 'Sale';
        _searchText = saved['search'] ?? '';
        _dateFrom = saved['dateFrom'] != null
            ? DateTime.tryParse(saved['dateFrom'].toString())
            : null;
        _dateTo = saved['dateTo'] != null
            ? DateTime.tryParse(saved['dateTo'].toString())
            : null;
        _statusFilter = saved['status'] as String?;
        _hasRemaining = saved['hasRemaining'] as bool?;
        _isOverdue = saved['isOverdue'] as bool?;
        _page = saved['page'] ?? 1;
      });
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // تحميل البيانات
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (!_canSeeInvoices) {
      setState(() {
        _error = 'ليس لديك صلاحية عرض هذا النوع من الفواتير';
        _isLoading = false;
      });
      return;
    }

    try {
      final filters = <String, dynamic>{
        'page': _page,
        'limit': _pageSize,
        if (_searchText.trim().isNotEmpty) 'search': _searchText.trim(),
        if (_dateFrom != null)
          'dateFrom': DateFormat('yyyy-MM-dd').format(_dateFrom!),
        if (_dateTo != null)
          'dateTo': DateFormat('yyyy-MM-dd').format(_dateTo!),
        if (_statusFilter != null) 'status': _statusFilter,
        if (_hasRemaining != null) 'hasRemaining': _hasRemaining,
        if (_isOverdue == true) 'overdue': true,
      };

      final data = await InvoiceService.instance.list(
        type: _activeTab,
        filters: filters,
      );
      final list = ((data['data'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _invoices = list;
        _stats = data['stats'] is Map
            ? Map<String, dynamic>.from(data['stats'] as Map)
            : {};
        _isLoading = false;
      });
      _saveFilters();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'فشل الاتصال بالخادم';
        _isLoading = false;
      });
    }
  }

  void _switchTab(String tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
      _page = 1;
    });
    _loadData();
  }

  void _resetFilters() {
    setState(() {
      _searchText = '';
      _dateFrom = null;
      _dateTo = null;
      _statusFilter = null;
      _hasRemaining = null;
      _isOverdue = null;
      _page = 1;
    });
    _loadData();
  }

  // ═══════════════════════════════════════════════════════════
  // UI Helpers
  // ═══════════════════════════════════════════════════════════
  String _fmt(dynamic v) {
    if (v == null) return '0';
    return NumberFormat(
      '#,##0',
    ).format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  String _fmtCompact(dynamic v) {
    final n = v is num
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '') ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  String _date(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  bool _isOverdueInv(Map<String, dynamic> inv) {
    final due = DateTime.tryParse((inv['DueDate'] ?? '').toString());
    if (due == null) return false;
    final status = (inv['InvoiceStatus'] ?? '').toString();
    return due.isBefore(DateTime.now()) &&
        status != 'Paid' &&
        status != 'Cancelled';
  }

  (Color, String) _statusInfo(String? status) {
    switch (status) {
      case 'Paid':
        return (AppColors.success, 'مدفوعة');
      case 'PartiallyPaid':
        return (AppColors.warning, 'مدفوعة جزئياً');
      case 'Cancelled':
        return (AppColors.error, 'ملغاة');
      default:
        return (AppColors.info, 'مفتوحة');
    }
  }

  Future<void> _openAddInvoice() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddInvoiceScreen(
          userId: widget.userId,
          username: widget.username,
          initialType: _activeTab == 'Sale' ? 'Sale' : 'Purchase',
        ),
      ),
    );
    if (changed == true && mounted) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frm_PartiesInvoices'),
      appBar: AppBar( leading: const AppDrawerMenuButton(),
        title: const Text('إدارة الفواتير'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading && _invoices.isEmpty
          ? const AppLoading()
          : _error != null
          ? _buildError(theme)
          : !_canSeeInvoices
          ? _buildNoPermission(theme)
          : _buildBody(theme, isDark),
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: _openAddInvoice,
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy,
              icon: const Icon(Icons.add_rounded),
              label: const Text('فاتورة جديدة'),
            )
          : null,
    );
  }

  Widget _buildError(ThemeData theme) {
    return AppError(message: _error!, onRetry: _loadData);
  }

  Widget _buildNoPermission(ThemeData theme) {
    return const AppEmpty(
      icon: Icons.lock_rounded,
      message: 'ليس لديك صلاحية لعرض هذه الفواتير',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // الواجهة الرئيسية
  // ═══════════════════════════════════════════════════════════
  Widget _buildBody(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // ── كروت الإحصائيات ─────────────────────────────
        _buildStatsCards(theme, isDark),

        // ── التبويبات ────────────────────────────────────
        _buildTabs(theme),

        // ── الفلاتر ──────────────────────────────────────
        _buildFilters(theme),

        // ── القائمة ──────────────────────────────────────
        Expanded(
          child: _invoices.isEmpty
              ? _buildEmpty(theme)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: HomeAccent.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) => _InvoiceCard(
                      invoice: _invoices[index],
                      canSeeAmounts: _canSeeAmounts,
                      canSeeProfit: _canSeeProfit,
                      isPurchase: _activeTab == 'Purchase',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvoiceDetailsScreen(
                              transactionId:
                                  (_invoices[index]['TransactionID'] ?? 0)
                                      as int,
                              username: widget.username,
                              invoiceType: _activeTab,
                            ),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── كروت الإحصائيات (زي بلازور) ────────────────────────────
  Widget _buildStatsCards(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          // الصف الأول: إجمالي + (مبيعات للمخول) + اليوم
          Row(
            children: [
              Expanded(
                child: AppStatCard(
                  label: 'إجمالي الفواتير',
                  value: '${_stats['TotalCount'] ?? _invoices.length}',
                  color: HomeAccent.indigo,
                  icon: Icons.receipt_long_rounded,
                  onTap: null,
                ),
              ),
              const SizedBox(width: 8),
              if (_canSeeAmounts)
                Expanded(
                  child: AppStatCard(
                    label: 'إجمالي المبيعات',
                    value: _fmtCompact(_stats['TotalSales']),
                    color: AppColors.success,
                    icon: Icons.trending_up_rounded,
                    tooltip: '${_fmt(_stats['TotalSales'])} ج.م',
                    onTap: null,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatCard(
                  label: 'فواتير اليوم',
                  value: '${_stats['TodayCount'] ?? 0}',
                  color: AppColors.info,
                  icon: Icons.today_rounded,
                  onTap: null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // الصف الثاني: المحصل + المتبقي + المتأخرة
          Row(
            children: [
              if (_canSeeAmounts) ...[
                Expanded(
                  child: AppStatCard(
                    label: 'المحصّل',
                    value: _fmtCompact(_stats['TotalPaid']),
                    color: HomeAccent.teal,
                    icon: Icons.check_circle_rounded,
                    tooltip: '${_fmt(_stats['TotalPaid'])} ج.م',
                    onTap: null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppStatCard(
                    label: 'المتبقي',
                    value: _fmtCompact(_stats['TotalRemaining']),
                    color: AppColors.error,
                    icon: Icons.schedule_rounded,
                    tooltip: '${_fmt(_stats['TotalRemaining'])} ج.م',
                    onTap: null,
                  ),
                ),
              ] else ...[
                Expanded(
                  child: AppStatCard(
                    label: 'مفتوحة',
                    value: '${_stats['OpenCount'] ?? 0}',
                    color: AppColors.info,
                    icon: Icons.lock_open_rounded,
                    onTap: null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppStatCard(
                    label: 'مدفوعة',
                    value: '${_stats['PaidCount'] ?? 0}',
                    color: AppColors.success,
                    icon: Icons.check_circle_rounded,
                    onTap: null,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: AppStatCard(
                  label: 'متأخرة',
                  value: '${_stats['OverdueCount'] ?? 0}',
                  color: AppColors.warning,
                  icon: Icons.warning_amber_rounded,
                  selected: _isOverdue == true,
                  onTap: () {
                    setState(
                      () => _isOverdue = _isOverdue == true ? null : true,
                    );
                    _loadData();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── التبويبات ──────────────────────────────────────────────
  Widget _buildTabs(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _TabBtn(
            label: 'المبيعات',
            icon: Icons.sell_rounded,
            selected: _activeTab == 'Sale',
            color: HomeAccent.indigo,
            onTap: () => _switchTab('Sale'),
          ),
          if (_canViewPurchases) ...[
            const SizedBox(width: 8),
            _TabBtn(
              label: 'المشتريات',
              icon: Icons.shopping_cart_rounded,
              selected: _activeTab == 'Purchase',
              color: HomeAccent.teal,
              onTap: () => _switchTab('Purchase'),
            ),
          ],
        ],
      ),
    );
  }

  // ── الفلاتر ────────────────────────────────────────────────
  Widget _buildFilters(ThemeData theme) {
    final hasActiveFilters =
        _searchText.isNotEmpty ||
        _dateFrom != null ||
        _dateTo != null ||
        _statusFilter != null ||
        _hasRemaining != null ||
        _isOverdue == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // البحث
          TextField(
            onChanged: (v) {
              setState(() => _searchText = v);
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted && v == _searchText) {
                  _page = 1;
                  _loadData();
                }
              });
            },
            decoration: InputDecoration(
              hintText: 'بحث برقم الفاتورة أو اسم العميل...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        setState(() => _searchText = '');
                        _loadData();
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // الصف: تاريخ + حالة + سداد + مسح
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterField(
                  label: _dateFrom == null
                      ? 'من تاريخ'
                      : DateFormat('yyyy/MM/dd').format(_dateFrom!),
                  icon: Icons.calendar_today_rounded,
                  onTap: () => _pickDate(from: true),
                  onClear: _dateFrom == null
                      ? null
                      : () {
                          setState(() => _dateFrom = null);
                          _loadData();
                        },
                ),
                const SizedBox(width: 6),
                _FilterField(
                  label: _dateTo == null
                      ? 'إلى تاريخ'
                      : DateFormat('yyyy/MM/dd').format(_dateTo!),
                  icon: Icons.event_rounded,
                  onTap: () => _pickDate(from: false),
                  onClear: _dateTo == null
                      ? null
                      : () {
                          setState(() => _dateTo = null);
                          _loadData();
                        },
                ),
                const SizedBox(width: 6),
                // فلتر الحالة
                PopupMenuButton<String>(
                  tooltip: 'الحالة',
                  initialValue: _statusFilter,
                  onSelected: (v) {
                    setState(() => _statusFilter = v);
                    _loadData();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'Open', child: Text('مفتوحة')),
                    PopupMenuItem(
                      value: 'PartiallyPaid',
                      child: Text('مدفوعة جزئياً'),
                    ),
                    PopupMenuItem(value: 'Paid', child: Text('مدفوعة')),
                    PopupMenuItem(value: 'Cancelled', child: Text('ملغاة')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: AppRadius.all(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _statusFilter != null
                              ? Icons.filter_alt_rounded
                              : Icons.filter_list_rounded,
                          size: 18,
                          color: _statusFilter != null
                              ? HomeAccent.accent
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _statusFilter != null
                              ? _statusInfo(_statusFilter).$2
                              : 'الحالة',
                          style: TextStyle(
                            fontSize: 12,
                            color: _statusFilter != null
                                ? HomeAccent.accent
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // فلتر السداد
                PopupMenuButton<bool?>(
                  tooltip: 'السداد',
                  initialValue: _hasRemaining,
                  onSelected: (v) {
                    setState(() => _hasRemaining = v);
                    _loadData();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: true, child: Text('فيها متبقي')),
                    PopupMenuItem(value: false, child: Text('مسددة بالكامل')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: AppRadius.all(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 18,
                          color: _hasRemaining != null
                              ? HomeAccent.accent
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _hasRemaining == null
                              ? 'السداد'
                              : _hasRemaining == true
                              ? 'فيها متبقي'
                              : 'مسددة',
                          style: TextStyle(
                            fontSize: 12,
                            color: _hasRemaining != null
                                ? HomeAccent.accent
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // زر مسح
                if (hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'مسح الفلاتر',
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: _resetFilters,
                  ),
                ],
              ],
            ),
          ),
          // شريط النتائج
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'عرض ${_invoices.length} فاتورة',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_isOverdue == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '⚠️ فواتير متأخرة',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppStatus.overdue,
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

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from
          ? (_dateFrom ?? DateTime.now())
          : (_dateTo ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
      _page = 1;
    });
    _loadData();
  }

  Widget _buildEmpty(ThemeData theme) {
    return const AppEmpty(
      icon: Icons.receipt_long_rounded,
      message: 'لا توجد فواتير مطابقة',
    );
  }}

// ═══════════════════════════════════════════════════════════
// Widgets مساعدة
// ═══════════════════════════════════════════════════════════

/// زر تبويب
class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? color : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? color : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حقل فلتر تاريخ
class _FilterField extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterField({
    required this.label,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: AppRadius.all(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.clear_rounded,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// كارت الفاتورة
class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final bool canSeeAmounts;
  final bool canSeeProfit;
  final bool isPurchase;
  final VoidCallback onTap;

  const _InvoiceCard({
    required this.invoice,
    required this.canSeeAmounts,
    required this.canSeeProfit,
    required this.isPurchase,
    required this.onTap,
  });

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return NumberFormat('#,##0').format(
      v is num ? v : double.tryParse(v.toString()) ?? 0,
    );
  }

  String _date(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  bool _isOverdue() {
    final due = DateTime.tryParse((invoice['DueDate'] ?? '').toString());
    if (due == null) return false;
    final status = (invoice['InvoiceStatus'] ?? '').toString();
    return due.isBefore(DateTime.now()) &&
        status != 'Paid' &&
        status != 'Cancelled';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = (invoice['InvoiceStatus'] ?? '').toString();
    final editStatus = invoice['EditStatus'] ?? 0;
    final overdue = _isOverdue();
    final delivered = invoice['IsDelivered'] == true;
    final remaining = (invoice['RemainingAmount'] ?? 0) is num
        ? (invoice['RemainingAmount'] ?? 0) as num
        : double.tryParse((invoice['RemainingAmount'] ?? 0).toString()) ?? 0;

    // ── لون وحالة الفاتورة ─────────────────────────────
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;
    switch (status) {
      case 'Paid':
        statusColor = AppColors.success;
        statusText = 'مدفوعة';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'PartiallyPaid':
        statusColor = AppColors.warning;
        statusText = 'مدفوعة جزئياً';
        statusIcon = Icons.payment_rounded;
        break;
      case 'Cancelled':
        statusColor = AppColors.error;
        statusText = 'ملغاة';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = AppColors.info;
        statusText = 'مفتوحة';
        statusIcon = Icons.lock_open_rounded;
    }

    // ── العميل/المورد + الموظف ─────────────────────────
    final customerName = isPurchase
        ? (invoice['SupplierName'] ??
            invoice['EmployeeName'] ??
            invoice['PartyName'] ??
            '—')
        : (invoice['PartyName'] ?? '—');
    final employeeName = (invoice['EmployeeName'] ?? '').toString();
    final phone = (invoice['Phone'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: overdue
              ? AppColors.warning.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── شريط علوي: الحالة + رقم الفاتورة ────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: overdue
                    ? AppColors.warning.withValues(alpha: 0.12)
                    : statusColor.withValues(alpha: 0.08),
              ),
              child: Row(
                children: [
                  StatusBadge(
                    label: statusText,
                    color: statusColor,
                    icon: statusIcon,
                    small: true,
                  ),
                  if (overdue) ...[
                    const SizedBox(width: 6),
                    const StatusBadge(
                      label: 'متأخرة',
                      color: AppStatus.overdue,
                      small: true,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '#${invoice['TransactionID']}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (invoice['ReferenceNumber'] != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      invoice['ReferenceNumber'].toString(),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── اسم العميل + الإجمالي ──────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // أفاتار العميل
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              statusColor,
                              Color.lerp(statusColor, Colors.black, 0.25)!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            customerName.isNotEmpty
                                ? customerName.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      // الاسم + الهاتف + الموظف
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (!isPurchase && phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_rounded,
                                    size: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (employeeName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      employeeName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // الإجمالي
                      if (canSeeAmounts)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AmountText(
                              value: _fmt(invoice['GrandTotal']),
                              size: 15,
                            ),
                            Text(
                              'ج.م',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 9.5,
                              ),
                            ),
                            if (canSeeProfit && invoice['GrossProfit'] != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppStatus.profit
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'ربح ${_fmt(invoice['GrossProfit'])} ج',
                                  style: const TextStyle(
                                    color: AppStatus.profit,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),

                  // ── شارات طلب التعديل ──────────────────
                  if (editStatus == 1 || editStatus == 2) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: (editStatus == 1
                                ? AppStatus.editPending
                                : AppColors.info)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (editStatus == 1
                                  ? AppStatus.editPending
                                  : AppColors.info)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            editStatus == 1
                                ? Icons.hourglass_top_rounded
                                : Icons.check_circle_rounded,
                            size: 14,
                            color: editStatus == 1
                                ? AppStatus.editPending
                                : AppColors.info,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              editStatus == 1
                                  ? 'طلب تعديل من: ${invoice['EditBy'] ?? '—'}'
                                  : '🔓 متاح للتعديل',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: editStatus == 1
                                    ? AppStatus.editPending
                                    : AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // ── الصف السفلي: تاريخ + استحقاق + متبقي + تسليم ──
                  // (Wrap عشان مفيش overflow على أي شاشة)
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _BottomItem(
                        icon: Icons.event_rounded,
                        label: _date(invoice['TransactionDate']),
                        theme: theme,
                      ),
                      if (invoice['DueDate'] != null)
                        _BottomItem(
                          icon: Icons.local_shipping_rounded,
                          label: _date(invoice['DueDate']),
                          theme: theme,
                          color: overdue
                              ? AppStatus.overdue
                              : null,
                        ),
                      if (canSeeAmounts && remaining > 0)
                        _BottomItem(
                          icon: Icons.payments_outlined,
                          label: 'متبقي ${_fmt(remaining)}',
                          theme: theme,
                          color: AppColors.error,
                          bold: true,
                        ),
                      _BottomItem(
                        icon: delivered
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        label: delivered ? 'تم التسليم' : 'قيد التسليم',
                        theme: theme,
                        color: delivered
                            ? AppColors.success
                            : AppStatus.overdue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// عنصر سفلي في كارت الفاتورة
class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;
  final Color? color;
  final bool bold;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.theme,
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: c,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
