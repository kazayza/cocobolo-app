import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_colors.dart';
import '../services/followups_service.dart';
import '../services/leads_service.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import 'lead_detail_screen.dart';
import 'opportunity_detail_screen.dart';

/// متابعاتي — احترافي (مرآة Blazor MyCalendar + CrmTasks + TaskService merge)
/// يدمج: متابعات الليدز + مهام العملاء/الفرص + NextFollowUp الفرص
class FollowUpsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? employeeId;

  const FollowUpsScreen({
    super.key,
    required this.userId,
    required this.username,
    this.employeeId,
  });

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> {
  static const _prefsKey = 'followups_filters_v1';

  bool _loading = true;
  bool _busy = false;

  /// overdue | today | tomorrow | upcoming | all
  String _scope = 'today';

  /// all | lead | client
  String _source = 'all';

  int? _employeeId;
  List<dynamic> _employees = [];
  List<dynamic> _items = [];
  Map<String, dynamic> _summary = {};
  final _searchCtrl = TextEditingController();
  final _perms = PermissionService();

  bool get _isDark => ThemeService().isDarkMode;
  bool get _canFilterAllEmployees =>
      _perms.isAdmin || _perms.isSalesManager || _perms.isGeneralManager;

  final _scopes = const [
    ('overdue', 'متأخر', Color(0xFFEF4444), Icons.warning_amber_rounded),
    ('today', 'اليوم', Color(0xFFF59E0B), Icons.today_rounded),
    ('tomorrow', 'غداً', Color(0xFF3B82F6), Icons.event_rounded),
    ('upcoming', 'قادم', Color(0xFF22C55E), Icons.upcoming_rounded),
    ('all', 'الكل', Color(0xFF64748B), Icons.select_all_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _employeeId = widget.employeeId;
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadEmployees(), _restorePrefs()]);
    // Non-admin defaults to own work if employee linked later; keep null = all allowed for managers
    if (!_canFilterAllEmployees && _employeeId == null) {
      // try permission service employeeId
      _employeeId = _perms.employeeId;
    }
    await _load();
  }

  Future<void> _loadEmployees() async {
    final list = await LeadsService.getEmployees();
    if (mounted) setState(() => _employees = list);
  }

  Future<void> _restorePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final scope = p.getString('${_prefsKey}_scope');
      final source = p.getString('${_prefsKey}_source');
      final emp = p.getInt('${_prefsKey}_emp');
      if (scope != null) _scope = scope;
      if (source != null) _source = source;
      if (emp != null && emp > 0) _employeeId = emp;
      if (p.containsKey('${_prefsKey}_emp') && emp == -1) _employeeId = null;
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('${_prefsKey}_scope', _scope);
      await p.setString('${_prefsKey}_source', _source);
      await p.setInt('${_prefsKey}_emp', _employeeId ?? -1);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _savePrefs();
    // Load selected scope list + full summary for KPIs
    final results = await Future.wait([
      FollowUpsService.getFollowUps(
        scope: _scope,
        source: _source,
        employeeId: _employeeId,
        search: _searchCtrl.text.trim(),
        limit: 200,
      ),
      FollowUpsService.getSummary(
        employeeId: _employeeId,
        source: _source,
      ),
    ]);
    if (!mounted) return;
    final data = results[0];
    final sum = results[1];
    setState(() {
      _items = (data['items'] as List?) ?? [];
      _summary = sum.isNotEmpty
          ? sum
          : ((data['summary'] as Map?)?.cast<String, dynamic>() ?? {});
      _loading = false;
    });
  }

  int _kpi(String key) {
    final v = _summary[key];
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final u = Uri.parse('tel:$phone');
    if (await canLaunchUrl(u)) await launchUrl(u);
  }

  Future<void> _wa(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    var p = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (p.startsWith('00')) p = p.substring(2);
    if (p.startsWith('0')) p = '20${p.substring(1)}';
    final u = Uri.parse('https://wa.me/$p');
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  void _open(Map item) {
    final type = '${item['itemType'] ?? item['ItemType'] ?? ''}';
    final isLead = item['isLeadTask'] == true || type == 'lead';
    final relatedId = item['relatedId'] ?? item['RelatedId'];
    final id = relatedId is int ? relatedId : int.tryParse('$relatedId') ?? 0;

    if (isLead && id > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LeadDetailScreen(
            leadId: id,
            userId: widget.userId,
            username: widget.username,
          ),
        ),
      ).then((_) => _load());
      return;
    }
    if ((type == 'opportunity' || type == 'task') && id > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OpportunityDetailScreen(
            opportunityId: id,
            userId: widget.userId,
            username: widget.username,
          ),
        ),
      ).then((_) => _load());
    }
  }

  Future<void> _completeLead(Map item) async {
    final itemId = item['itemId'] ?? item['ItemId'];
    final id = itemId is int ? itemId : int.tryParse('$itemId');
    if (id == null) return;
    setState(() => _busy = true);
    final ok =
        await FollowUpsService.completeLeadFollowUp(id, widget.username);
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'تم إنهاء متابعة الـ Lead' : 'تعذّر الإنهاء',
          style: GoogleFonts.cairo()),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
    if (ok) _load();
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final dt = v is DateTime ? v : DateTime.tryParse(v.toString());
    if (dt == null) return '$v';
    final local = dt.toLocal();
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(local.year, local.month, local.day);
    final diff = d1.difference(d0).inDays;
    final time = DateFormat('HH:mm').format(local);
    if (diff == 0) return 'اليوم $time';
    if (diff == 1) return 'غداً $time';
    if (diff == -1) return 'أمس $time';
    return DateFormat('dd/MM/yyyy HH:mm').format(local);
  }

  String _empLabel() {
    if (_employeeId == null) return 'كل الموظفين';
    for (final e in _employees) {
      final m = e as Map;
      final id = m['EmployeeId'] ?? m['EmployeeID'];
      final idInt = id is int ? id : int.tryParse('$id');
      if (idInt == _employeeId) return '${m['FullName']}';
    }
    return 'موظف';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            _isDark ? const Color(0xFF0f172a) : const Color(0xFFF4F7FB),
        body: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (ctx, inner) => [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 168,
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  title: Text('متابعاتي',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _loading ? null : _load,
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHeader(),
                  ),
                ),
                // KPI strip
                SliverToBoxAdapter(child: _buildKpiStrip()),
                // Filters
                SliverToBoxAdapter(child: _buildFilterBar()),
              ],
              body: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.gold))
                  : _items.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: AppColors.gold,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final raw = _items[i];
                              final item = raw is Map
                                  ? Map<String, dynamic>.from(raw)
                                  : <String, dynamic>{};
                              return _FollowUpCard(
                                item: item,
                                isDark: _isDark,
                                formatDate: _fmtDate,
                                onOpen: () => _open(item),
                                onCall: () => _call(
                                    '${item['phone'] ?? item['Phone'] ?? ''}'),
                                onWa: () => _wa(
                                    '${item['phone'] ?? item['Phone'] ?? ''}'),
                                onCompleteLead: (item['isLeadTask'] == true ||
                                        '${item['itemType']}' == 'lead')
                                    ? () => _completeLead(item)
                                    : null,
                              );
                            },
                          ),
                        ),
            ),
            if (_busy)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0f172a), Color(0xFF1e3a8a), Color(0xFF2563eb)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إدارة متابعات الليدز والعملاء',
                  style: GoogleFonts.cairo(
                      color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _headerStat('ليدز', _kpi('leads'), const Color(0xFFF472B6)),
                  const SizedBox(width: 10),
                  _headerStat(
                      'عملاء/فرص', _kpi('clients'), const Color(0xFF60A5FA)),
                  const SizedBox(width: 10),
                  _headerStat('الإجمالي', _kpi('total'), AppColors.gold),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStat(String label, int n, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$n',
                style: GoogleFonts.cairo(
                    color: c, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label,
                style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiStrip() {
    return Container(
      color: _isDark ? const Color(0xFF0f172a) : const Color(0xFFF4F7FB),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _scopes.map((s) {
            final key = s.$1;
            final label = s.$2;
            final color = s.$3;
            final icon = s.$4;
            final count = key == 'all' ? _kpi('total') : _kpi(key);
            final sel = _scope == key;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() => _scope = key);
                  _load();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 108,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sel
                        ? color.withOpacity(_isDark ? 0.22 : 0.12)
                        : (_isDark ? const Color(0xFF1e293b) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sel
                          ? color
                          : (_isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                      width: sel ? 1.6 : 1,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color: color.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(height: 6),
                      Text('$count',
                          style: GoogleFonts.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _isDark ? Colors.white : const Color(0xFF0f172a))),
                      Text(label,
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          // Source toggles like Blazor: All / Client / Lead
          Row(
            children: [
              _sourceChip('all', '🌐 الكل', null),
              const SizedBox(width: 6),
              _sourceChip('lead', '📣 ليدز', _kpi('leads')),
              const SizedBox(width: 6),
              _sourceChip('client', '👤 عملاء', _kpi('clients')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _load(),
                  style: GoogleFonts.cairo(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'بحث: اسم، موبايل، حملة...',
                    hintStyle: GoogleFonts.cairo(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _load();
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: _isDark ? const Color(0xFF1e293b) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_canFilterAllEmployees) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: _pickEmployee,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: _employeeId != null
                          ? const Color(0xFF059669).withOpacity(0.12)
                          : (_isDark ? const Color(0xFF1e293b) : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _employeeId != null
                            ? const Color(0xFF059669)
                            : (_isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined,
                            size: 18,
                            color: _employeeId != null
                                ? const Color(0xFF059669)
                                : const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(
                            _empLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                                fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(String key, String label, int? count) {
    final sel = _source == key;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _source = key);
          _load();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.navy.withOpacity(_isDark ? 0.5 : 0.08)
                : (_isDark ? const Color(0xFF1e293b) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel
                  ? AppColors.navy
                  : (_isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Center(
            child: Text(
              count == null ? label : '$label ($count)',
              style: GoogleFonts.cairo(
                fontSize: 11.5,
                fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
                color: sel
                    ? (_isDark ? AppColors.gold : AppColors.navy)
                    : AppColors.textSecondary(_isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickEmployee() async {
    if (_employees.isEmpty) await _loadEmployees();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1e293b) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text('تقويم / فلتر الموظف',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900, fontSize: 16)),
            ListTile(
              title: Text('كل الموظفين', style: GoogleFonts.cairo()),
              leading: Icon(_employeeId == null
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _employeeId = null);
                _load();
              },
            ),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: _employees.length,
                itemBuilder: (_, i) {
                  final e = _employees[i] as Map;
                  final id = e['EmployeeId'] ?? e['EmployeeID'];
                  final idInt = id is int ? id : int.tryParse('$id');
                  final sel = idInt == _employeeId;
                  return ListTile(
                    title: Text('${e['FullName']}',
                        style: GoogleFonts.cairo(
                            fontWeight:
                                sel ? FontWeight.w800 : FontWeight.w600)),
                    subtitle: e['Department'] != null
                        ? Text('${e['Department']}',
                            style: GoogleFonts.cairo(fontSize: 11))
                        : null,
                    leading: Icon(sel
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _employeeId = idInt);
                      _load();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    final msg = switch (_scope) {
      'overdue' => '✅ لا توجد متابعات متأخرة — أحسنت!',
      'today' => '😊 لا توجد متابعات اليوم',
      'tomorrow' => '📅 لا متابعات غداً',
      'upcoming' => '🟢 لا متابعات قادمة',
      _ => 'لا توجد متابعات',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded,
                size: 64, color: AppColors.textSecondary(_isDark)),
            const SizedBox(height: 14),
            Text(msg,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('غيّر التبويب أو الفلتر لعرض المزيد',
                style: GoogleFonts.cairo(
                    fontSize: 12, color: AppColors.textSecondary(_isDark))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Card widget
// ═══════════════════════════════════════════════════════════
class _FollowUpCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final String Function(dynamic) formatDate;
  final VoidCallback onOpen;
  final VoidCallback onCall;
  final VoidCallback onWa;
  final VoidCallback? onCompleteLead;

  const _FollowUpCard({
    required this.item,
    required this.isDark,
    required this.formatDate,
    required this.onOpen,
    required this.onCall,
    required this.onWa,
    this.onCompleteLead,
  });

  bool get _isLead =>
      item['isLeadTask'] == true || '${item['itemType']}' == 'lead';

  Color get _accent {
    if (_isLead) return const Color(0xFFEC4899);
    final t = '${item['itemType']}';
    if (t == 'opportunity') return const Color(0xFF2563EB);
    return const Color(0xFF059669);
  }

  Color get _bucketColor {
    switch ('${item['bucket']}') {
      case 'overdue':
        return const Color(0xFFEF4444);
      case 'today':
        return const Color(0xFFF59E0B);
      case 'tomorrow':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF22C55E);
    }
  }

  String get _bucketLabel {
    switch ('${item['bucket']}') {
      case 'overdue':
        final d = item['daysOverdue'];
        return d != null && d is int && d > 0 ? 'متأخر $d يوم' : 'متأخر';
      case 'today':
        return 'اليوم';
      case 'tomorrow':
        return 'غداً';
      default:
        return 'قادم';
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = '${item['phone'] ?? ''}';
    final client = '${item['clientName'] ?? '—'}';
    final title = '${item['title'] ?? ''}';
    final emp = '${item['employeeName'] ?? ''}';
    final status = '${item['statusLabel'] ?? ''}';
    final best = '${item['bestTimeToReach'] ?? ''}';
    final campaign = '${item['campaignName'] ?? ''}';
    final platform = '${item['platform'] ?? ''}';
    final city = '${item['city'] ?? ''}';
    final subType = '${item['subType'] ?? ''}';
    final overdue = '${item['bucket']}' == 'overdue';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: overdue
              ? const Color(0xFFEF4444).withOpacity(0.35)
              : _accent.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // accent bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                ),
              ),
              if (overdue)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  child: Text('⚠️ $_bucketLabel — يحتاج إجراء الآن',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB91C1C))),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _accent.withOpacity(0.25)),
                          ),
                          child: Text(
                            _isLead ? '📣 متابعة Lead' : '👤 متابعة عميل',
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: _accent),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _bucketColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_bucketLabel,
                              style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _bucketColor)),
                        ),
                        const Spacer(),
                        Text(formatDate(item['followUpDate']),
                            style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(client,
                        style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A))),
                    if (title.isNotEmpty && title != client)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (phone.isNotEmpty) _chip(Icons.phone, phone),
                        if (emp.isNotEmpty) _chip(Icons.person_outline, emp),
                        if (status.isNotEmpty) _chip(Icons.flag_outlined, status),
                        if (city.isNotEmpty) _chip(Icons.location_city, city),
                        if (best.isNotEmpty)
                          _chip(Icons.access_time_filled, 'أفضل وقت: $best',
                              highlight: true),
                        if (campaign.isNotEmpty)
                          _chip(Icons.campaign, campaign),
                        if (platform.isNotEmpty)
                          _chip(Icons.public, platform),
                        if (subType.isNotEmpty)
                          _chip(Icons.label_outline, subType),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (phone.isNotEmpty) ...[
                          _iconBtn(Icons.phone_rounded, Colors.green, onCall),
                          const SizedBox(width: 6),
                          _iconBtn(
                              Icons.chat_rounded, const Color(0xFF25D366), onWa),
                          const SizedBox(width: 6),
                        ],
                        if (onCompleteLead != null) ...[
                          _iconBtn(Icons.done_all_rounded, Colors.teal,
                              onCompleteLead!),
                          const SizedBox(width: 6),
                        ],
                        const Spacer(),
                        TextButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: Text('فتح',
                              style: GoogleFonts.cairo(
                                  fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, {bool highlight = false}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF2563EB).withOpacity(isDark ? 0.2 : 0.08)
            : (isDark ? const Color(0xFF0f172a) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? const Color(0xFF2563EB).withOpacity(0.35)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: highlight
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight:
                        highlight ? FontWeight.w800 : FontWeight.w600,
                    color: highlight
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: c),
      ),
    );
  }
}
