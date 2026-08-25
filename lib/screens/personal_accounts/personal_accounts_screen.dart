import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/home/widgets/home_accent.dart';
import '../../services/personal_account_service.dart';
import 'personal_account_form_screen.dart';
import 'personal_account_statement_screen.dart';
import 'personal_account_transaction_screen.dart';

/// مُنسّق أرقام مشترك
final NumberFormat _fmtShared = NumberFormat('#,##0');

/// ─────────────────────────────────────────────────────────────
/// 👤 الحسابات الشخصية — نسخة فخمة 2026
///  - إحصائيات: إجمالي الحسابات + دائنون (عليكم) + مدينون (لكم) + الصافي
///  - كروت حساب (الاسم + النوع + الرصيد + آخر حركة)
///  - بحث + فلتر نوع + فلتر رصيد (محفوظة)
///  - فتح الكشف / إضافة حركة / تعديل
/// ─────────────────────────────────────────────────────────────
class PersonalAccountsScreen extends StatefulWidget {
  final int? userId;
  final String? username;

  const PersonalAccountsScreen({super.key, this.userId, this.username});

  @override
  State<PersonalAccountsScreen> createState() => _PersonalAccountsScreenState();
}

class _PersonalAccountsScreenState extends State<PersonalAccountsScreen> {
  List<Map<String, dynamic>> _accounts = [];
  Map<String, dynamic> _totals = {'TotalCreditors': 0, 'TotalDebtors': 0, 'Net': 0};
  List<Map<String, dynamic>> _types = [];
  bool _loading = true;
  bool _tableLoading = false;
  String? _error;

  // فلاتر
  final TextEditingController _searchCtrl = TextEditingController();
  String? _typeFilter;
  String _balanceFilter = 'All';
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

  static const String _prefsKey = 'personal_accounts_filters_v1';

  String get _uname => widget.username ?? '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _restoreFilters();
    await _loadTypes();
    await _loadTotals();
    await _loadAccounts(reset: true);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTypes() async {
    final types = await PersonalAccountService.getTypes();
    if (mounted) setState(() => _types = types);
  }

  Future<void> _loadTotals() async {
    final totals = await PersonalAccountService.getTotals();
    if (mounted) setState(() => _totals = totals);
  }

  Future<void> _loadAccounts({bool reset = false}) async {
    final page = reset ? 1 : _page;
    if (mounted) {
      setState(() {
        if (reset) {
          _tableLoading = true;
        }
      });
    }

    final result = await PersonalAccountService.getAccounts(
      search: _searchCtrl.text,
      accountType: _typeFilter,
      balanceFilter: _balanceFilter,
      page: page,
      limit: 25,
    );

    if (!mounted) return;
    setState(() {
      _accounts = reset ? result.items : [..._accounts, ...result.items];
      _total = result.total;
      _totalPages = result.totalPages;
      _page = result.page;
      _tableLoading = false;
      _error = null;
    });
  }

  void _loadMore() {
    if (_page >= _totalPages || _tableLoading) return;
    _page++;
    _loadAccounts();
  }

  Future<void> _onFilterChanged() async {
    await _saveFilters();
    _loadAccounts(reset: true);
  }

  Future<void> _restoreFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json == null || json.isEmpty) return;
      final map = jsonDecode(json) as Map<String, dynamic>;
      setState(() {
        _typeFilter = map['type'] as String?;
        _balanceFilter = (map['balance'] as String?) ?? 'All';
        _searchCtrl.text = (map['search'] as String?) ?? '';
      });
    } catch (_) {}
  }

  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode({
        'type': _typeFilter,
        'balance': _balanceFilter,
        'search': _searchCtrl.text,
      }));
    } catch (_) {}
  }

  void _onSearch() {
    _saveFilters();
    _loadAccounts(reset: true);
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return _fmtShared.format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  Color _typeColor(String? type) {
    final hex = _typeColorHex(type);
    return Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
  }

  String _typeColorHex(String? type) {
    for (final t in _types) {
      if (t['value'] == type) return (t['color'] as String?) ?? '#6b7280';
    }
    return '#6b7280';
  }

  String _typeLabel(String? type) {
    for (final t in _types) {
      if (t['value'] == type) return (t['label'] as String?) ?? type ?? 'أخرى';
    }
    return type ?? 'أخرى';
  }

  String _timeAgo(dynamic v) {
    if (v == null) return 'لا حركات بعد';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحسابات الشخصية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _loadTotals();
              _loadAccounts(reset: true);
            },
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _error != null && _accounts.isEmpty
              ? _buildError(theme)
              : RefreshIndicator(
                  color: HomeAccent.accent,
                  onRefresh: () async {
                    await _loadTotals();
                    await _loadAccounts(reset: true);
                  },
                  child: _buildBody(theme, isDark),
                ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 60, color: theme.colorScheme.error),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── الإحصائيات ───────────────────────────
        _buildStatsGrid(isDark),

        const SizedBox(height: 14),

        // ── الأزرار السريعة ──────────────────────
        Row(
          children: [
            Expanded(
              child: _QuickBtn(
                icon: Icons.person_add_alt_1_rounded,
                label: 'حساب جديد',
                color: HomeAccent.teal,
                onTap: () => _openForm(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickBtn(
                icon: Icons.swap_vert_rounded,
                label: 'حركة جديدة',
                color: HomeAccent.indigo,
                onTap: () {
                  if (_accounts.isEmpty) {
                    _showSnack('أضف حساباً أولاً');
                    return;
                  }
                  _openTransaction(_accounts.first);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── الفلاتر ──────────────────────────────
        _buildFilterPanel(theme, isDark),

        const SizedBox(height: 12),

        if (_tableLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(minHeight: 3),
          ),

        // ── رأس القائمة ──────────────────────────
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: HomeAccent.gold, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Text('الحسابات', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$_total حساب',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── الكروت ───────────────────────────────
        if (_accounts.isEmpty && !_tableLoading)
          _buildEmpty(theme)
        else
          ..._accounts.map((acc) => _AccountCard(
                account: acc,
                typeLabel: _typeLabel,
                typeColor: _typeColor,
                fmt: _fmt,
                timeAgo: _timeAgo,
                onTap: () => _openStatement(acc),
                onTx: () => _openTransaction(acc),
              )),

        // ── عرض المزيد ───────────────────────────
        if (_totalPages > 1 && !_tableLoading) ...[
          const SizedBox(height: 14),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: _loadMore,
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
              label: Text('عرض المزيد (${_page}/$_totalPages)'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    final creditors = (_totals['TotalCreditors'] ?? 0).toDouble();
    final debtors = (_totals['TotalDebtors'] ?? 0).toDouble();
    final net = (_totals['Net'] ?? 0).toDouble();

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
                icon: Icons.groups_rounded,
                label: 'إجمالي الحسابات',
                value: _fmt(_total),
                color: HomeAccent.gold,
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                icon: Icons.arrow_downward_rounded,
                label: 'عليكم (دائن)',
                value: _fmt(creditors),
                color: const Color(0xFFE53935),
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                icon: Icons.arrow_upward_rounded,
                label: 'لكم (مدين)',
                value: _fmt(debtors),
                color: const Color(0xFF43A047),
              ),
            ),
            SizedBox(
              width: w,
              child: _StatCard(
                icon: Icons.balance_rounded,
                label: 'الصافي (${(_totals['NetLabel'] ?? 'عليكم')})',
                value: _fmt(net.abs()),
                color: net >= 0 ? const Color(0xFF43A047) : const Color(0xFFE53935),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterPanel(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _onSearch(),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو الهاتف أو الرقم القومي...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearch();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _filterDropdown<String?>(
                  value: _typeFilter,
                  hint: 'النوع: الكل',
                  icon: Icons.category_rounded,
                  items: [
                    DropdownMenuItem<String?>(value: null, child: const Text('الكل', style: TextStyle(fontSize: 12.5))),
                    ..._types.map((t) => DropdownMenuItem<String?>(
                          value: t['value'] as String?,
                          child: Text(t['label'] as String? ?? '', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() => _typeFilter = v);
                    _onFilterChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterDropdown<String>(
                  value: _balanceFilter,
                  hint: 'الرصيد: الكل',
                  icon: Icons.balance_rounded,
                  items: const [
                    DropdownMenuItem<String>(value: 'All', child: Text('الكل', style: TextStyle(fontSize: 12.5))),
                    DropdownMenuItem<String>(value: 'Positive', child: Text('له على الشركة', style: TextStyle(fontSize: 12.5))),
                    DropdownMenuItem<String>(value: 'Negative', child: Text('عليه للشركة', style: TextStyle(fontSize: 12.5))),
                    DropdownMenuItem<String>(value: 'Zero', child: Text('مسوى', style: TextStyle(fontSize: 12.5))),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _balanceFilter = v);
                    _onFilterChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
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
              Flexible(child: Text(hint, style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
            ],
          ),
          items: items,
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: theme.colorScheme.surfaceContainerHigh,
          icon: Icon(Icons.arrow_drop_down_rounded, color: theme.colorScheme.onSurfaceVariant),
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
            child: Icon(Icons.people_outline_rounded, size: 36, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const Text('لا توجد حسابات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'ابدأ بإضافة حساب جديد (مالك، مستثمر، مقرض، موظف...)',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════ التنقل ═══════════

  Future<void> _openForm([Map<String, dynamic>? account]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalAccountFormScreen(
          account: account,
          username: _uname,
        ),
      ),
    );
    if (changed == true && mounted) {
      _loadTotals();
      _loadAccounts(reset: true);
    }
  }

  void _openStatement(Map<String, dynamic> account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalAccountStatementScreen(
          account: account,
          username: _uname,
        ),
      ),
    );
  }

  Future<void> _openTransaction(Map<String, dynamic> account) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalAccountTransactionScreen(
          account: account,
          username: _uname,
        ),
      ),
    );
    if (changed == true && mounted) {
      _loadTotals();
      _loadAccounts(reset: true);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
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
                  child: Text(value, maxLines: 1, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickBtn({
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
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final String Function(String?) typeLabel;
  final Color Function(String?) typeColor;
  final String Function(dynamic) fmt;
  final String Function(dynamic) timeAgo;
  final VoidCallback onTap;
  final VoidCallback onTx;

  const _AccountCard({
    required this.account,
    required this.typeLabel,
    required this.typeColor,
    required this.fmt,
    required this.timeAgo,
    required this.onTap,
    required this.onTx,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = account['AccountType']?.toString();
    final color = typeColor(type);
    final balance = (account['CurrentBalance'] ?? 0).toDouble();
    final isPositive = balance > 0;
    final balanceColor = isPositive ? const Color(0xFFE53935) : (balance < 0 ? const Color(0xFF43A047) : theme.colorScheme.onSurfaceVariant);
    final name = account['AccountName']?.toString() ?? '—';
    final phone = account['Phone']?.toString() ?? '';
    final isActive = (account['IsActive'] ?? true) == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.4)
              : theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // شارة النوع
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      typeLabel(type),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (!isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('معطل', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: theme.colorScheme.error)),
                    ),
                  const Spacer(),
                  // زر حركة
                  GestureDetector(
                    onTap: onTx,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: HomeAccent.indigo.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.swap_vert_rounded, size: 15, color: HomeAccent.indigo),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // الاسم
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
                        if (phone.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              phone,
                              textAlign: TextAlign.left,
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // الرصيد
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${fmt(balance.abs())} ج.م',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: balanceColor),
                        ),
                      ),
                      Text(
                        balance > 0 ? 'له على الشركة' : (balance < 0 ? 'عليه للشركة' : 'مسوى'),
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 13, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${account['TransactionsCount'] ?? 0} حركة • آخر حركة: ${timeAgo(account['LastTransactionDate'])}',
                    style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_left_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
