import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../features/home/widgets/home_accent.dart';
import '../providers/auth_provider.dart';
import '../services/leads_service.dart';
import '../services/permission_service.dart';
import 'client_card_screen.dart';
import 'employees_screen.dart';
import 'expenses/expense_dashboard_screen.dart';
import 'lead_detail_screen.dart';
import 'products_screen.dart';

/// ─────────────────────────────────────────────────────────────
///  بحث شامل (Spotlight) — يبحث في كل الأقسام مرة واحدة
///  حسب صلاحيات المستخدم فقط.
///  الأقسام: العملاء • الليدز • المنتجات • المصروفات • الموظفين
/// ─────────────────────────────────────────────────────────────

enum SearchSectionType { clients, leads, products, expenses, employees }

class SearchItem {
  final SearchSectionType type;
  final dynamic id;
  final String title;
  final String subtitle;

  const SearchItem({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
  });
}

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  List<SearchItem> _results = [];
  String _query = '';

  // ── إعدادات الأقسام حسب الصلاحيات ─────────────────────────
  late final List<_SectionConfig> _sections = _buildSections();

  List<_SectionConfig> _buildSections() {
    final perms = PermissionService();
    final sections = <_SectionConfig>[];

    if (perms.canView(FormNames.partiesList)) {
      sections.add(
        const _SectionConfig(
          type: SearchSectionType.clients,
          label: 'العملاء',
          icon: Icons.people_alt_rounded,
          accent: HomeAccent.indigo,
        ),
      );
    }
    if (perms.canView(FormNames.leadsCrm)) {
      sections.add(
        const _SectionConfig(
          type: SearchSectionType.leads,
          label: 'العملاء المحتملين',
          icon: Icons.campaign_rounded,
          accent: HomeAccent.amber,
        ),
      );
    }
    if (perms.canView(FormNames.productsList)) {
      sections.add(
        const _SectionConfig(
          type: SearchSectionType.products,
          label: 'المنتجات',
          icon: Icons.inventory_2_rounded,
          accent: HomeAccent.orange,
        ),
      );
    }
    if (perms.canView(FormNames.expensesList)) {
      sections.add(
        const _SectionConfig(
          type: SearchSectionType.expenses,
          label: 'المصروفات',
          icon: Icons.account_balance_wallet_rounded,
          accent: HomeAccent.red,
        ),
      );
    }
    if (perms.canView(FormNames.employeesList)) {
      sections.add(
        const _SectionConfig(
          type: SearchSectionType.employees,
          label: 'الموظفين',
          icon: Icons.badge_rounded,
          accent: HomeAccent.purple,
        ),
      );
    }
    return sections;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() {
        _query = query;
        _results = [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _query = query;
      _loading = true;
    });

    final futures = <Future<List<SearchItem>?>>[
      for (final section in _sections) _searchSection(section, query),
    ];

    final results = await Future.wait(futures);

    if (!mounted) return;

    final flat = <SearchItem>[
      for (final r in results)
        if (r != null) ...r,
    ];

    setState(() {
      _results = flat;
      _loading = false;
    });
  }

  // ── بحث في قسم واحد ────────────────────────────────────────
  Future<List<SearchItem>?> _searchSection(
    _SectionConfig section,
    String query,
  ) async {
    try {
      switch (section.type) {
        case SearchSectionType.clients:
          return _searchClients(query);
        case SearchSectionType.leads:
          return _searchLeads(query);
        case SearchSectionType.products:
          return _searchProducts(query);
        case SearchSectionType.expenses:
          return _searchExpenses(query);
        case SearchSectionType.employees:
          return _searchEmployees(query);
      }
    } catch (_) {
      // قسم فشل → لا نوقف البحث كله
      return null;
    }
  }

  static String _lower(String s) => s.toLowerCase();

  Future<List<SearchItem>?> _searchClients(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http
        .get(
          Uri.parse('$baseUrl/api/clients/list'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final list = jsonDecode(res.body) as List<dynamic>;
    final ql = _lower(q);

    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((c) {
          final name = _lower((c['PartyName'] ?? '').toString());
          final phone = _lower((c['Phone'] ?? '').toString());
          return name.contains(ql) || phone.contains(ql);
        })
        .take(8)
        .map(
          (c) => SearchItem(
            type: SearchSectionType.clients,
            id: c['PartyID'],
            title: (c['PartyName'] ?? 'عميل').toString(),
            subtitle: [
              (c['Phone'] ?? '').toString(),
              (c['Address'] ?? '').toString(),
            ].where((s) => s.isNotEmpty).join(' • '),
          ),
        )
        .toList();
  }

  Future<List<SearchItem>?> _searchLeads(String q) async {
    final result = await LeadsService.getLeads(
      search: q,
      limit: 15,
    ).timeout(const Duration(seconds: 8));

    return result.items.whereType<Map>().take(15).map((m) {
      final lead = Map<String, dynamic>.from(m);
      return SearchItem(
        type: SearchSectionType.leads,
        id: lead['LeadId'] ?? lead['LeadID'],
        title: (lead['FullName'] ?? lead['AdName'] ?? 'Lead').toString(),
        subtitle: [
          (lead['City'] ?? '').toString(),
          (lead['LeadStatus'] ?? '').toString(),
        ].where((s) => s.isNotEmpty).join(' • '),
      );
    }).toList();
  }

  Future<List<SearchItem>?> _searchProducts(String q) async {
    final url =
        '$baseUrl/api/products?search=${Uri.encodeComponent(q)}&limit=20';
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .take(12)
        .map(
          (p) => SearchItem(
            type: SearchSectionType.products,
            id: p['ProductID'],
            title: (p['ProductName'] ?? 'منتج').toString(),
            subtitle: [
              (p['GroupName'] ?? '').toString(),
              (p['CustomerName'] ?? '').toString(),
            ].where((s) => s.isNotEmpty).join(' • '),
          ),
        )
        .toList();
  }

  Future<List<SearchItem>?> _searchExpenses(String q) async {
    final url =
        '$baseUrl/api/expenses?search=${Uri.encodeComponent(q)}&limit=20';
    final res = await http
        .get(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .take(12)
        .map(
          (e) => SearchItem(
            type: SearchSectionType.expenses,
            id: e['ExpenseID'],
            title: (e['ExpenseName'] ?? 'مصروف').toString(),
            subtitle: [
              (e['ExpenseGroupName'] ?? '').toString(),
              if (e['Amount'] != null)
                '${(e['Amount'] as num).toStringAsFixed(2)} ج.م',
            ].where((s) => s.isNotEmpty).join(' • '),
          ),
        )
        .toList();
  }

  Future<List<SearchItem>?> _searchEmployees(String q) async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/employees/active'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final list = jsonDecode(res.body) as List<dynamic>;
    final ql = _lower(q);

    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((e) {
          final name = _lower((e['FullName'] ?? '').toString());
          final phone = _lower((e['MobilePhone'] ?? '').toString());
          return name.contains(ql) || phone.contains(ql);
        })
        .take(8)
        .map(
          (e) => SearchItem(
            type: SearchSectionType.employees,
            id: e['EmployeeID'] ?? e['employeeID'],
            title: (e['FullName'] ?? 'موظف').toString(),
            subtitle: [
              (e['JobTitle'] ?? '').toString(),
              (e['Department'] ?? '').toString(),
            ].where((s) => s.isNotEmpty).join(' • '),
          ),
        )
        .toList();
  }

  // ── فتح النتيجة ────────────────────────────────────────────
  void _open(SearchItem item) {
    final auth = AuthProvider();
    final userId = auth.userId ?? 0;
    final username = auth.username ?? '';

    final Widget screen = switch (item.type) {
      SearchSectionType.clients => ClientCardScreen(
        userId: userId,
        username: username,
        initialPartyId: item.id,
      ),
      SearchSectionType.leads => LeadDetailScreen(
        leadId: int.tryParse(item.id?.toString() ?? '') ?? 0,
        userId: userId,
        username: username,
      ),
      SearchSectionType.products => ProductsScreen(
        userId: userId,
        username: username,
      ),
      SearchSectionType.expenses => ExpenseDashboardScreen(
        userId: userId,
        username: username,
      ),
      SearchSectionType.employees => EmployeesScreen(
        userId: userId,
        username: username,
      ),
    };

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ── الواجهة ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث شامل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'إغلاق',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث في العملاء، الليدز، المنتجات...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          // شارات الأقسام المتاحة
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = _sections[i];
                return Chip(
                  avatar: Icon(s.icon, size: 16, color: s.accent),
                  label: Text(s.label),
                  labelStyle: const TextStyle(fontSize: 12),
                  backgroundColor: s.accent.withValues(alpha: 0.10),
                  side: BorderSide(color: s.accent.withValues(alpha: 0.30)),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    // تحميل
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    // استعلام قصير
    if (_query.length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'اكتب حرفين على الأقل للبحث',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // لا نتائج
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد نتائج لـ "$_query"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // تجميع النتائج حسب القسم
    final grouped = <SearchSectionType, List<SearchItem>>{};
    for (final item in _results) {
      grouped.putIfAbsent(item.type, () => []).add(item);
    }

    final configs = {for (final s in _sections) s.type: s};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (final entry in grouped.entries) ...[
          _SectionLabel(
            icon: configs[entry.key]!.icon,
            label: configs[entry.key]!.label,
            accent: configs[entry.key]!.accent,
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: configs[entry.key]!.accent.withValues(alpha: 0.06),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: configs[entry.key]!.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 60,
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  _ResultTile(
                    item: entry.value[i],
                    accent: configs[entry.key]!.accent,
                    icon: configs[entry.key]!.icon,
                    onTap: () => _open(entry.value[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// مكونات مساعدة
// ═══════════════════════════════════════════════════════════

class _SectionConfig {
  final SearchSectionType type;
  final String label;
  final IconData icon;
  final Color accent;

  const _SectionConfig({
    required this.type,
    required this.label,
    required this.icon,
    required this.accent,
  });
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final SearchItem item;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _ResultTile({
    required this.item,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: accent, size: 20),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      subtitle: item.subtitle.isNotEmpty
          ? Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Icon(
        Directionality.of(context) == TextDirection.rtl
            ? Icons.chevron_left_rounded
            : Icons.chevron_right_rounded,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
