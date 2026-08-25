import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../features/home/widgets/home_accent.dart';
import '../../services/permission_service.dart';
import '../../services/cashbox_service.dart';
import '../../services/cashbox_report_service.dart';
import 'cashbox_manual_screen.dart';
import 'expenses/expense_dashboard_screen.dart';
import 'invoice/invoice_details_screen.dart';

/// مُنسّق أرقام مشترك
final NumberFormat _fmtShared = NumberFormat('#,##0');

/// أنواع المراجع (مطابقة لبلازور CashBoxRefTypes)
const List<({String label, String value})> _refTypeOptions = [
  (label: 'الكل', value: ''),
  (label: 'فاتورة مبيعات', value: 'SaleInvoice'),
  (label: 'فاتورة مشتريات', value: 'PurchaseInvoice'),
  (label: 'مصروف', value: 'Expense'),
  (label: 'مصروف مقدم', value: 'AdvanceExpense'),
  (label: 'راتب', value: 'Payroll'),
  (label: 'مكافأة منفصلة', value: 'BonusSeparate'),
  (label: 'عمولة منفصلة', value: 'CommissionSeparate'),
  (label: 'قرض', value: 'Loan'),
  (label: 'تحويل وارد', value: 'TransferIn'),
  (label: 'تحويل صادر', value: 'TransferOut'),
  (label: 'رسوم معاينة', value: 'AdvanceCharge'),
  (label: 'سند قبض يدوي', value: 'ManualReceipt'),
  (label: 'سند صرف يدوي', value: 'ManualPayment'),
  (label: 'رصيد افتتاحي', value: 'OpeningBalance'),
];

const Map<String, String> _refColors = {
  'SaleInvoice': '#10b981',
  'PurchaseInvoice': '#ef4444',
  'Expense': '#f59e0b',
  'AdvanceExpense': '#f59e0b',
  'Payroll': '#8b5cf6',
  'BonusSeparate': '#0ea5e9',
  'CommissionSeparate': '#06b6d4',
  'Loan': '#3b82f6',
  'TransferIn': '#06b6d4',
  'TransferOut': '#06b6d4',
  'AdvanceCharge': '#84cc16',
  'ManualReceipt': '#22c55e',
  'ManualPayment': '#dc2626',
  'OpeningBalance': '#6366f1',
};

/// ─────────────────────────────────────────────────────────────
/// 💱 حركات الخزينة — نسخة فخمة 2026 (مطابقة لبلازور)
///  - 5 كروت إحصائيات (عدد / دخل / صرف / صافي / رصيد فعلي)
///  - فلاتر محفوظة: بحث + خزينة + نوع + مصدر + تاريخ
///  - ترقيم صفحات + تصدير Excel + عرض المصدر
///  - Theme-aware (ليلي/نهاري) + ألوان مخصصة
/// ─────────────────────────────────────────────────────────────
class CashboxTransactionsScreen extends StatefulWidget {
  /// قابل للـ null للتوافق مع كل الأماكن اللي بتنادي الشاشة
  final int? userId;
  final String? username;

  const CashboxTransactionsScreen({
    super.key,
    this.userId,
    this.username,
  });

  @override
  State<CashboxTransactionsScreen> createState() =>
      _CashboxTransactionsScreenState();
}

class _CashboxTransactionsScreenState extends State<CashboxTransactionsScreen>
    with SingleTickerProviderStateMixin {
  // ── البيانات ────────────────────────────────────────────
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic> _stats = const {'TotalIn': 0, 'TotalOut': 0, 'Net': 0};
  List<Map<String, dynamic>> _boxes = [];
  int _total = 0;
  int _totalPages = 1;
  int _page = 1;

  // ── الحالة ──────────────────────────────────────────────
  bool _loading = true;
  bool _tableLoading = false;
  bool _loadingMore = false;
  bool _exporting = false;
  bool _filterExpanded = true;
  String? _error;
  bool _suppressSearchLoad = false;

  // ── الفلاتر ─────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  int? _cashboxId;
  String _type = 'الكل';
  String _refType = '';
  DateTime? _from;
  DateTime? _to;
  Timer? _searchTimer;

  // ── الصلاحيات ───────────────────────────────────────────
  final PermissionService _perms = PermissionService();
  bool get _canView =>
      _perms.isAdmin || _perms.canView(FormNames.cashBoxTransaction);
  bool get _canAdd =>
      _perms.isAdmin || _perms.canAdd(FormNames.cashBoxManual);

  /// معرف آمن (0 لو null) — للتوافق مع كل النداءات
  int get _uid => widget.userId ?? 0;
  String get _uname => widget.username ?? '';

  static const String _prefsKey = 'cashbox_transactions_filter_state';

  bool get _hasActiveFilters =>
      _searchCtrl.text.trim().isNotEmpty ||
      _cashboxId != null ||
      _type != 'الكل' ||
      _refType.isNotEmpty ||
      _from != null ||
      _to != null;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _init();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _restoreFilters();
    await _loadBoxes();
    await _loadData(resetPage: true);
    if (mounted) setState(() => _loading = false);
  }

  // ═══════════════ تحميل البيانات ═══════════════

  Future<void> _loadBoxes() async {
    final boxes = await CashboxService.getAllCashboxes();
    if (mounted) setState(() => _boxes = boxes);
  }

  Future<void> _loadData({bool resetPage = false}) async {
    final page = resetPage ? 1 : _page;
    if (resetPage) {
      setState(() => _tableLoading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final result = await CashboxService.getTransactionsPaged(
        cashboxId: _cashboxId,
        startDate: _from != null ? DateFormat('yyyy-MM-dd').format(_from!) : null,
        endDate: _to != null ? DateFormat('yyyy-MM-dd').format(_to!) : null,
        transactionType: _type,
        referenceType: _refType,
        search: _searchCtrl.text,
        page: page,
        limit: 25,
      );

      if (!mounted) return;
      setState(() {
        if (resetPage) {
          _transactions = result.data;
        } else {
          _transactions = [..._transactions, ...result.data];
        }
        _stats = result.stats;
        _total = result.total;
        _totalPages = result.totalPages;
        _page = result.page;
        _tableLoading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tableLoading = false;
        _loadingMore = false;
        if (resetPage && _transactions.isEmpty) _error = 'فشل تحميل الحركات';
      });
    }
  }

  void _loadMore() {
    if (_loadingMore || _page >= _totalPages) return;
    _page++;
    _loadData();
  }

  // ═══════════════ الفلاتر ═══════════════

  void _onSearchChanged() {
    if (_suppressSearchLoad) return;
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 400), () {
      _saveFilters();
      _loadData(resetPage: true);
    });
  }

  Future<void> _restoreFilters() async {
    try {
      _suppressSearchLoad = true;
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json == null) return;
      final map = jsonDecode(json) as Map<String, dynamic>;
      setState(() {
        _cashboxId = map['cashboxId'] as int?;
        _type = (map['type'] as String?) ?? 'الكل';
        _refType = (map['refType'] as String?) ?? '';
        final from = map['from'] as String?;
        final to = map['to'] as String?;
        _from = from != null ? DateTime.tryParse(from) : null;
        _to = to != null ? DateTime.tryParse(to) : null;
        _filterExpanded = (map['expanded'] as bool?) ?? true;
        if (map['search'] != null) {
          _searchCtrl.text = map['search'] as String;
        }
      });
    } catch (_) {} finally {
      _suppressSearchLoad = false;
    }
  }

  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode({
        'cashboxId': _cashboxId,
        'type': _type,
        'refType': _refType,
        'from': _from?.toIso8601String(),
        'to': _to?.toIso8601String(),
        'search': _searchCtrl.text,
        'expanded': _filterExpanded,
      }));
    } catch (_) {}
  }

  Future<void> _onFilterChange() async {
    await _saveFilters();
    _loadData(resetPage: true);
  }

  Future<void> _resetFilters() async {
    _suppressSearchLoad = true;
    _searchCtrl.clear();
    _suppressSearchLoad = false;
    setState(() {
      _cashboxId = null;
      _type = 'الكل';
      _refType = '';
      _from = null;
      _to = null;
    });
    await _saveFilters();
    _loadData(resetPage: true);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      helpText: isFrom ? 'من تاريخ' : 'إلى تاريخ',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to != null && _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
        if (_from != null && _from!.isAfter(picked)) _from = picked;
      }
    });
    await _onFilterChange();
  }

  // ═══════════════ تصدير Excel ═══════════════

  Future<void> _exportExcel() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      // جلب كل الصفحات حسب الفلتر الحالي (زي بلازور: كل السجلات)
      final all = <Map<String, dynamic>>[];
      var page = 1;
      var totalPages = 1;
      var total = 0;
      do {
        final r = await CashboxService.getTransactionsPaged(
          cashboxId: _cashboxId,
          startDate: _from != null ? DateFormat('yyyy-MM-dd').format(_from!) : null,
          endDate: _to != null ? DateFormat('yyyy-MM-dd').format(_to!) : null,
          transactionType: _type,
          referenceType: _refType,
          search: _searchCtrl.text,
          page: page,
          limit: 200,
        );
        all.addAll(r.data);
        totalPages = r.totalPages;
        total = r.total;
        page++;
      } while (page <= totalPages && all.length < total);

      String? boxName;
      if (_cashboxId != null) {
        for (final b in _boxes) {
          if (b['CashBoxID'] == _cashboxId) {
            boxName = b['CashBoxName']?.toString();
            break;
          }
        }
      }

      final path = await CashboxReportService.generateExcel(
        transactions: all,
        totalIn: (_stats['TotalIn'] ?? 0).toDouble(),
        totalOut: (_stats['TotalOut'] ?? 0).toDouble(),
        balance: (_stats['Net'] ?? 0).toDouble(),
        cashboxName: boxName,
        fromDate: _from != null ? DateFormat('yyyy/MM/dd').format(_from!) : null,
        toDate: _to != null ? DateFormat('yyyy/MM/dd').format(_to!) : null,
      );

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        text: 'تقرير حركات الخزينة',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في التصدير: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ═══════════════ أدوات عرض ═══════════════

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return _fmtShared.format(
      v is num ? v : double.tryParse(v.toString()) ?? 0,
    );
  }

  String _refLabel(String? type) {
    if (type == null || type.isEmpty) return '—';
    for (final o in _refTypeOptions) {
      if (o.value == type) return o.label;
    }
    return type;
  }

  Color _refColor(String? type) {
    final hex = _refColors[type] ?? '#94a3b8';
    return Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
  }

  String _timeAgo(dynamic v) {
    if (v == null) return '';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  // ═══════════════ البناء ═══════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حركات الخزينة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadData(resetPage: true),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: !_canView
          ? _buildNoAccess(theme)
          : _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
              : _error != null && _transactions.isEmpty
                  ? _buildError(theme)
                  : RefreshIndicator(
                      color: HomeAccent.accent,
                      onRefresh: () => _loadData(resetPage: true),
                      child: _buildBody(theme, isDark),
                    ),
    );
  }

  Widget _buildNoAccess(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 60, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text('لا تملك صلاحية عرض حركات الخزينة'),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('رجوع'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 60, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _init,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    final actualBalance = _actualBalance();
    final actualLabel = _actualBalanceLabel();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── الإحصائيات ─────────────────────────────
        _StatsGrid(
          count: _total,
          totalIn: _stats['TotalIn'],
          totalOut: _stats['TotalOut'],
          net: _stats['Net'],
          actualBalance: actualBalance,
          actualLabel: actualLabel,
          isDark: isDark,
        ),

        const SizedBox(height: 14),

        // ── الأزرار السريعة ────────────────────────
        Row(
          children: [
            if (_canAdd) ...[
              Expanded(
                child: _QuickActionBtn(
                  icon: Icons.add_card_rounded,
                  label: 'حركة يدوية',
                  color: HomeAccent.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CashboxManualScreen(
                        userId: _uid,
                        username: _uname,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _QuickActionBtn(
                icon: _exporting ? Icons.hourglass_top_rounded : Icons.file_download_rounded,
                label: _exporting ? 'جاري التصدير...' : 'تصدير Excel',
                color: const Color(0xFF10B981),
                onTap: _exporting ? null : _exportExcel,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── لوحة الفلاتر ───────────────────────────
        _buildFilterPanel(theme),

        const SizedBox(height: 12),

        // ── شريط تقدم أثناء تغيير الفلاتر ──────────
        if (_tableLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(minHeight: 3, borderRadius: BorderRadius.all(Radius.circular(4))),
          ),

        // ── رأس القائمة ────────────────────────────
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: HomeAccent.gold,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'سجل الحركات',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$_total حركة',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── قائمة الحركات ──────────────────────────
        if (_transactions.isEmpty && !_tableLoading)
          _buildEmpty(theme)
        else
          ..._transactions.map((tx) => _TxCard(
                tx: Map<String, dynamic>.from(tx),
                fmt: _fmt,
                refLabel: _refLabel,
                refColor: _refColor,
                timeAgo: _timeAgo,
                canViewSource: _canView,
                onOpenSource: () => _openSource(tx),
                onTap: () => _showDetails(tx),
              )),

        // ── ترقيم الصفحات ──────────────────────────
        if (_totalPages > 1 && !_tableLoading) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'صفحة $_page من $_totalPages',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              if (_page < _totalPages)
                FilledButton.tonalIcon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.more_horiz_rounded, size: 20),
                  label: Text(_loadingMore ? 'جاري التحميل...' : 'عرض المزيد'),
                )
              else
                Chip(
                  avatar: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('كل الحركات ظهرت'),
                  labelStyle: const TextStyle(fontSize: 12),
                  side: BorderSide.none,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ═══════════════ الرصيد الفعلي (مطابق لبلازور) ═══════════════

  double _actualBalance() {
    if (_cashboxId != null) {
      for (final b in _boxes) {
        if (b['CashBoxID'] == _cashboxId) {
          return (b['CurrentBalance'] ?? 0).toDouble();
        }
      }
      return 0;
    }
    double sum = 0;
    for (final b in _boxes) {
      final active = (b['IsActive'] ?? true) == true || !_boxes.any((x) => (x['IsActive'] ?? true) == true);
      if (active) sum += (b['CurrentBalance'] ?? 0).toDouble();
    }
    return sum;
  }

  String _actualBalanceLabel() {
    if (_cashboxId != null) {
      for (final b in _boxes) {
        if (b['CashBoxID'] == _cashboxId) {
          return 'رصيد ${b['CashBoxName'] ?? ''}';
        }
      }
      return 'الرصيد الفعلي';
    }
    return 'إجمالي الأرصدة الفعلية';
  }

  // ═══════════════ لوحة الفلاتر ═══════════════

  Widget _buildFilterPanel(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          // الرأس
          InkWell(
            onTap: () => setState(() => _filterExpanded = !_filterExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded,
                      size: 18, color: HomeAccent.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'بحث وتصفية',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: HomeAccent.gold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'فلتر نشط',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_hasActiveFilters)
                    InkWell(
                      onTap: _resetFilters,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: theme.colorScheme.error),
                      ),
                    ),
                  AnimatedRotation(
                    turns: _filterExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // المحتوى
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _filterExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // بحث
                  TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'بحث في الملاحظات أو المستخدم...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: isDark
                          ? theme.colorScheme.surfaceContainerHighest
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // خزينة + نوع الحركة
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown<int?>(
                          value: _cashboxId,
                          hint: 'الخزينة',
                          icon: Icons.account_balance_wallet_rounded,
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text('الكل',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurfaceVariant)),
                            ),
                            ..._boxes.map((b) => DropdownMenuItem<int?>(
                                  value: (b['CashBoxID'] as num?)?.toInt(),
                                  child: Text(
                                    b['CashBoxName']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() => _cashboxId = v);
                            _onFilterChange();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDropdown<String>(
                          value: _type,
                          hint: 'نوع الحركة',
                          icon: Icons.swap_vert_rounded,
                          items: ['الكل', 'قبض', 'صرف']
                              .map((t) => DropdownMenuItem<String>(
                                    value: t,
                                    child: Text(t,
                                        style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _type = v);
                            _onFilterChange();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // المصدر
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildDropdown<String>(
                      value: _refType,
                      hint: 'المصدر',
                      icon: Icons.source_rounded,
                      isFullWidth: true,
                      items: _refTypeOptions
                          .map((o) => DropdownMenuItem<String>(
                                value: o.value,
                                child: Text(o.label,
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _refType = v);
                        _onFilterChange();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // التواريخ
                  Row(
                    children: [
                      Expanded(
                        child: _DateBtn(
                          icon: Icons.calendar_today_rounded,
                          label: _from != null
                              ? DateFormat('yyyy/MM/dd').format(_from!)
                              : 'من تاريخ',
                          onTap: () => _pickDate(isFrom: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateBtn(
                          icon: Icons.event_rounded,
                          label: _to != null
                              ? DateFormat('yyyy/MM/dd').format(_to!)
                              : 'إلى تاريخ',
                          onTap: () => _pickDate(isFrom: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool isFullWidth = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          items: items,
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: theme.colorScheme.surfaceContainerHigh,
          icon: Icon(Icons.arrow_drop_down_rounded,
              color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.inbox_rounded,
                size: 36, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد حركات',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'لم يتم العثور على حركات بالفلاتر الحالية',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════ فتح المصدر ═══════════════

  void _openSource(Map<String, dynamic> tx) {
    final refType = tx['ReferenceType']?.toString();
    final refId = (tx['ReferenceID'] as num?)?.toInt();
    if (refId == null) return;

    switch (refType) {
      case 'SaleInvoice':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailsScreen(
              transactionId: refId,
              username: _uname,
              invoiceType: 'Sale',
            ),
          ),
        );
        break;
      case 'PurchaseInvoice':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailsScreen(
              transactionId: refId,
              username: _uname,
              invoiceType: 'Purchase',
            ),
          ),
        );
        break;
      case 'Expense':
      case 'AdvanceExpense':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpenseDashboardScreen(
              userId: _uid,
              username: _uname,
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('المصدر: ${_refLabel(refType)}')),
        );
    }
  }

  // ═══════════════ تفاصيل الحركة ═══════════════

  void _showDetails(Map<String, dynamic> tx) {
    final theme = Theme.of(context);
    final isIn = tx['TransactionType'] == 'قبض';
    final color = isIn ? const Color(0xFF43A047) : const Color(0xFFE53935);
    final amount = (tx['Amount'] ?? 0).toDouble();

    String dateStr = '';
    String timeStr = '';
    try {
      final dt = DateTime.parse(tx['TransactionDate'].toString());
      dateStr = DateFormat('yyyy/MM/dd').format(dt);
      timeStr = DateFormat('HH:mm').format(dt);
    } catch (_) {
      dateStr = tx['TransactionDate']?.toString() ?? '';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // العنوان
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isIn ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIn ? 'قبض (دخل)' : 'صرف',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        Text(
                          tx['CashBoxName']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${isIn ? '+' : '-'}${_fmt(amount)} ج.م',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ),
                      Text(
                        _refLabel(tx['ReferenceType']?.toString()),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Divider(
                  height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),

              // التفاصيل
              const SizedBox(height: 10),
              _DetailRow(
                  icon: Icons.calendar_today_rounded, label: 'التاريخ', value: dateStr),
              if (timeStr.isNotEmpty)
                _DetailRow(icon: Icons.access_time_rounded, label: 'الوقت', value: timeStr),
              if ((tx['SourceTitle'] ?? '').toString().isNotEmpty)
                _DetailRow(
                    icon: Icons.description_rounded,
                    label: 'التفاصيل',
                    value: tx['SourceTitle'].toString()),
              if ((tx['PartyName'] ?? '').toString().isNotEmpty)
                _DetailRow(
                    icon: Icons.person_rounded,
                    label: 'الجهة',
                    value: tx['PartyName'].toString()),
              if ((tx['PersonalAccountName'] ?? '').toString().isNotEmpty)
                _DetailRow(
                    icon: Icons.account_balance_rounded,
                    label: 'الحساب',
                    value: tx['PersonalAccountName'].toString()),
              if ((tx['Notes'] ?? '').toString().isNotEmpty)
                _DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'ملاحظات',
                    value: tx['Notes'].toString()),
              _DetailRow(
                  icon: Icons.tag_rounded,
                  label: 'رقم الحركة',
                  value: tx['CashboxTransactionID']?.toString() ?? '—'),
              _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'بواسطة',
                  value: tx['CreatedBy']?.toString() ?? '—'),
              if (tx['CreatedAt'] != null)
                _DetailRow(
                    icon: Icons.history_rounded,
                    label: 'تاريخ الإنشاء',
                    value: _timeAgo(tx['CreatedAt'])),

              const SizedBox(height: 16),
              if ((tx['SourceUrl'] ?? '').toString().isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openSource(tx);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('عرض المصدر'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════

class _StatsGrid extends StatelessWidget {
  final int count;
  final dynamic totalIn;
  final dynamic totalOut;
  final dynamic net;
  final double actualBalance;
  final String actualLabel;
  final bool isDark;

  const _StatsGrid({
    required this.count,
    required this.totalIn,
    required this.totalOut,
    required this.net,
    required this.actualBalance,
    required this.actualLabel,
    required this.isDark,
  });

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return _fmtShared.format(
      v is num ? v : double.tryParse(v.toString()) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final netVal = net is num ? (net as num).toDouble() : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final w = (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: w,
              child: _StatCard(
                icon: Icons.receipt_long_rounded,
                label: 'حركة',
                value: _fmt(count),
                color: HomeAccent.gold,
                bg: HomeAccent.gold.withValues(alpha: 0.10),
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                icon: Icons.trending_up_rounded,
                label: 'إجمالي دخل',
                value: _fmt(totalIn),
                color: const Color(0xFF43A047),
                bg: const Color(0xFF43A047).withValues(alpha: 0.10),
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                icon: Icons.trending_down_rounded,
                label: 'إجمالي صرف',
                value: _fmt(totalOut),
                color: const Color(0xFFE53935),
                bg: const Color(0xFFE53935).withValues(alpha: 0.10),
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                icon: Icons.balance_rounded,
                label: 'الصافي',
                value: '${netVal >= 0 ? '+' : ''}${_fmt(net)}',
                color: netVal >= 0
                    ? const Color(0xFF43A047)
                    : const Color(0xFFE53935),
                bg: (netVal >= 0 ? const Color(0xFF43A047) : const Color(0xFFE53935))
                    .withValues(alpha: 0.10),
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                icon: Icons.account_balance_wallet_rounded,
                label: actualLabel,
                value: _fmt(actualBalance),
                color: actualBalance < 0
                    ? const Color(0xFFE53935)
                    : const Color(0xFF7C5CFC),
                bg: (actualBalance < 0
                        ? const Color(0xFFE53935)
                        : const Color(0xFF7C5CFC))
                    .withValues(alpha: 0.10),
                labelSmall: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final bool labelSmall;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    this.labelSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: labelSmall ? 9.5 : 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasValue = label != 'من تاريخ' && label != 'إلى تاريخ';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: hasValue ? HomeAccent.accent : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: hasValue ? FontWeight.w800 : FontWeight.w500,
                  color: hasValue
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  final String Function(dynamic) fmt;
  final String Function(String?) refLabel;
  final Color Function(String?) refColor;
  final String Function(dynamic) timeAgo;
  final bool canViewSource;
  final VoidCallback onOpenSource;
  final VoidCallback onTap;

  const _TxCard({
    required this.tx,
    required this.fmt,
    required this.refLabel,
    required this.refColor,
    required this.timeAgo,
    required this.canViewSource,
    required this.onOpenSource,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = tx['TransactionType'] == 'قبض';
    final color = isIn ? const Color(0xFF43A047) : const Color(0xFFE53935);
    final refType = tx['ReferenceType']?.toString();
    final refC = refColor(refType);
    final hasSource = (tx['SourceUrl'] ?? '').toString().isNotEmpty;
    final sourceTitle = (tx['SourceTitle'] ?? '').toString();
    final partyName = (tx['PartyName'] ?? '').toString();
    final accountName = (tx['PersonalAccountName'] ?? '').toString();
    final notes = (tx['Notes'] ?? '').toString();
    final createdBy = (tx['CreatedBy'] ?? '').toString();

    String dateStr = '';
    String timeStr = '';
    try {
      final dt = DateTime.parse(tx['TransactionDate'].toString());
      dateStr = DateFormat('yyyy/MM/dd').format(dt);
      timeStr = DateFormat('HH:mm').format(dt);
    } catch (_) {
      dateStr = tx['TransactionDate']?.toString() ?? '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // السطر الأول: شارات + المبلغ
              Row(
                children: [
                  // الاتجاه
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isIn
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 12,
                          color: color,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          isIn ? 'دخل' : 'صرف',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // المصدر
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: refC.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        refLabel(refType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: refC,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // الخزينة
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: HomeAccent.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: HomeAccent.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              tx['CashBoxName']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // المبلغ
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${isIn ? '+' : '-'} ${fmt(tx['Amount'])} ج.م',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),

              // التفاصيل
              if (sourceTitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  sourceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
              if (partyName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded,
                          size: 12, color: HomeAccent.accent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          partyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (accountName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_rounded,
                          size: 12, color: HomeAccent.accent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          accountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

              // السطر الأخير: التاريخ + المستخدم + المصدر
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 13, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '$dateStr $timeStr',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // المستخدم
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [HomeAccent.gold, Color(0xFFB8912A)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      createdBy.length >= 2 ? createdBy.substring(0, 2) : '؟',
                      style: const TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      createdBy.isEmpty ? '—' : createdBy,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (hasSource)
                    GestureDetector(
                      onTap: onOpenSource,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.open_in_new_rounded,
                            size: 14, color: Color(0xFF3B82F6)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: HomeAccent.accent),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
