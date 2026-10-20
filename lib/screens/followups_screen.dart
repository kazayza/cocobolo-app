import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_colors.dart';
import '../services/followups_service.dart';
import '../services/icon_utils.dart';
import '../services/leads_service.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import 'lead_detail_screen.dart';
import 'opportunity_detail_screen.dart';

/// متابعاتي — احترافي مطابق بلازور MyCalendar.razor + TaskService
/// يدمج: متابعات الليدز + مهام العملاء/الفرص بدون تكرار
/// تصميم: Premium header + Achievement tracker + Smart toggle + Agenda grouped by date
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

  // Monthly progress - مطابق بلازور month-progress-box
  int _totalMonthTasks = 0;
  int _completedMonthTasks = 0;
  int get _monthProgressPercent =>
      _totalMonthTasks > 0 ? ((_completedMonthTasks / _totalMonthTasks) * 100).round() : 0;

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
    if (!_canFilterAllEmployees && _employeeId == null) {
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
    final results = await Future.wait([
      FollowUpsService.getFollowUps(
        scope: _scope,
        source: _source,
        employeeId: _employeeId,
        search: _searchCtrl.text.trim(),
        limit: 200,
      ),
      FollowUpsService.getSummary(employeeId: _employeeId, source: _source),
    ]);
    if (!mounted) return;
    final data = results[0];
    final sum = results[1];

    // ── FIX: منع تكرار نفس العميل مرتين في نفس التاريخ (Task + Opportunity) - مطابق بلازور TaskService ──
    List<dynamic> rawItems = (data['items'] as List?) ?? [];
    final Map<String, Map<String, dynamic>> seen = {};
    final List<dynamic> deduped = [];
    for (final raw in rawItems) {
      final item = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final relatedId = item['relatedId'] ?? item['RelatedId'];
      final followUpDate = item['followUpDate'] ?? item['FollowUpDate'];
      if (relatedId == null || followUpDate == null) {
        deduped.add(item);
        continue;
      }
      try {
        final dt = DateTime.tryParse(followUpDate.toString());
        final dateKey = dt == null ? followUpDate.toString() : DateFormat('yyyy-MM-dd').format(dt);
        final key = '${relatedId}_$dateKey';
        if (!seen.containsKey(key)) {
          seen[key] = item;
          deduped.add(item);
        } else {
          final existing = seen[key]!;
          final existingType = '${existing['itemType'] ?? ''}';
          final newType = '${item['itemType'] ?? ''}';
          if (existingType == 'opportunity' && (newType == 'task' || newType == 'lead')) {
            final idx = deduped.indexWhere((e) => e is Map && (e['relatedId'] ?? e['RelatedId']) == relatedId);
            if (idx != -1) deduped[idx] = item;
            seen[key] = item;
          }
        }
      } catch (_) {
        deduped.add(item);
      }
    }

    // حساب إنجاز الشهر - مطابق بلازور
    final total = sum.isNotEmpty ? sum : ((data['summary'] as Map?)?.cast<String, dynamic>() ?? {});
    final totalCount = (total['total'] ?? total['Total'] ?? deduped.length) is int ? (total['total'] ?? total['Total'] ?? deduped.length) : int.tryParse('${total['total'] ?? total['Total'] ?? deduped.length}') ?? deduped.length;
    final overdue = (total['overdue'] ?? 0) is int ? total['overdue'] : int.tryParse('${total['overdue'] ?? 0}') ?? 0;

    setState(() {
      _items = deduped;
      _summary = total;
      _totalMonthTasks = totalCount + (totalCount ~/ 3); // تقديري للشهر
      _completedMonthTasks = (totalCount - overdue).clamp(0, totalCount);
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
    final ok = await FollowUpsService.completeLeadFollowUp(id, widget.username);
    setState(() => _busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'تم إنهاء متابعة الـ Lead' : 'تعذّر الإنهاء',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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

  String _fmtDateOnly(dynamic v) {
    if (v == null) return '—';
    final dt = v is DateTime ? v : DateTime.tryParse(v.toString());
    if (dt == null) return '$v';
    return DateFormat('yyyy/MM/dd').format(dt.toLocal());
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

  // Group items by date - مطابق بلازور mobile-agenda
  Map<String, List<Map<String, dynamic>>> _groupedByDate() {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final raw in _items) {
      final item = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final followUpDate = item['followUpDate'] ?? item['FollowUpDate'];
      String dateKey = 'بدون تاريخ';
      try {
        final dt = followUpDate != null ? DateTime.tryParse(followUpDate.toString()) : null;
        if (dt != null) dateKey = DateFormat('yyyy-MM-dd').format(dt);
      } catch (_) {}
      groups.putIfAbsent(dateKey, () => []).add(item);
    }
    // Sort keys: overdue first, then today, then future
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'بدون تاريخ') return 1;
        if (b == 'بدون تاريخ') return -1;
        try {
          final da = DateTime.parse(a);
          final db = DateTime.parse(b);
          return da.compareTo(db);
        } catch (_) {
          return a.compareTo(b);
        }
      });
    final Map<String, List<Map<String, dynamic>>> sorted = {};
    for (final k in sortedKeys) {
      sorted[k] = groups[k]!;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
        body: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (ctx, inner) => [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 310,
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  title: Text('متابعاتي', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
                  actions: [
                    IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _load),
                  ],
                  flexibleSpace: FlexibleSpaceBar(background: _buildPremiumHeader()),
                ),
                SliverToBoxAdapter(child: _buildKpiStrip()),
                SliverToBoxAdapter(child: _buildFilterBar()),
              ],
              body: _loading
                  ? Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : _items.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: AppColors.gold,
                          onRefresh: _load,
                          child: _buildAgendaGrouped(),
                        ),
            ),
            if (_busy)
              Container(
                color: Colors.black38,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(16)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(color: AppColors.gold),
                      const SizedBox(height: 12),
                      Text('جاري التنفيذ...', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════
  //  Premium Header - مطابق بلازور MyCalendar
  // ═══════════════════════════════════
  Widget _buildPremiumHeader() {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy', 'ar').format(now);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF1E40AF), Color(0xFF2563EB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // Orbs
          Positioned(top: -40, right: -30, child: Container(width: 120, height: 120, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle))),
          Positioned(bottom: -20, left: 20, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), shape: BoxShape.circle))),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Title icon box with pulse
                  Stack(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.20))),
                      child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 26),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.gold.withOpacity(0.35), width: 1.5)),
                      ),
                    ),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF34D399), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF34D399).withOpacity(0.5), blurRadius: 6)]) ),
                        const SizedBox(width: 6),
                        Text('تقويم مبيعات متقدم', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 2),
                      Text('مهامي وجدولي اليومي', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2)),
                      Text('إدارة المهام ومتابعات العملاء والليدز في واجهة تقويم تفاعلية', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10, height: 1.3)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                // Month banner + smart toggle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.18), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.12))),
                  child: Column(children: [
                    Row(children: [
                      Icon(Icons.event_note_rounded, color: AppColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          monthName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'إجمالي ${_items.length} متابعة',
                            style: GoogleFonts.cairo(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ]),
                    if (_totalMonthTasks > 0) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: Text('إنجاز الشهر: $_completedMonthTasks / $_totalMonthTasks ($_monthProgressPercent%)', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: _monthProgressPercent / 100, minHeight: 6, backgroundColor: Colors.white.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(_monthProgressPercent >= 100 ? const Color(0xFF34D399) : AppColors.gold)),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _headerStat('ليدز', _kpi('leads'), const Color(0xFFF472B6)),
                  const SizedBox(width: 8),
                  _headerStat('عملاء', _kpi('clients'), const Color(0xFF60A5FA)),
                  const SizedBox(width: 8),
                  _headerStat('الإجمالي', _kpi('total'), AppColors.gold),
                  const SizedBox(width: 8),
                  _headerStat('متأخر', _kpi('overdue'), const Color(0xFFEF4444)),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, int n, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$n', style: GoogleFonts.cairo(color: c, fontSize: 14, fontWeight: FontWeight.w900)),
          Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildKpiStrip() {
    return Container(
      color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
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
                  width: 110,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sel ? color.withOpacity(_isDark ? 0.22 : 0.12) : (_isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sel ? color : (_isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)), width: sel ? 1.6 : 1),
                    boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.20), blurRadius: 10, offset: const Offset(0, 4))] : null,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(icon, size: 16, color: color),
                      const Spacer(),
                      if (sel) Icon(Icons.check_circle_rounded, size: 14, color: color),
                    ]),
                    const SizedBox(height: 6),
                    Text('$count', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w900, color: _isDark ? Colors.white : const Color(0xFF0F172A))),
                    Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.06)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        // Smart toggle bar - مطابق بلازور smart-toggle-bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _smartToggleBtn(
              'all',
              'الكل (${_kpi('total')})',
              Icons.view_agenda_outlined,
              _source == 'all',
            ),
            _smartToggleBtn(
              'lead',
              'ليدز (${_kpi('leads')})',
              Icons.campaign_outlined,
              _source == 'lead',
            ),
            _smartToggleBtn(
              'client',
              'عملاء (${_kpi('clients')})',
              Icons.people_outline_rounded,
              _source == 'client',
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _load(),
              style: GoogleFonts.cairo(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'بحث: اسم، موبايل، حملة...',
                hintStyle: GoogleFonts.cairo(fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { _searchCtrl.clear(); _load(); })
                    : null,
                isDense: true,
                filled: true,
                fillColor: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_canFilterAllEmployees) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: _pickEmployee,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: _employeeId != null ? const Color(0xFF059669).withOpacity(0.12) : (_isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _employeeId != null ? const Color(0xFF059669) : (_isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(children: [
                  Icon(Icons.badge_outlined, size: 18, color: _employeeId != null ? const Color(0xFF059669) : const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 90), child: Text(_empLabel(), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700))),
                ]),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _smartToggleBtn(
    String key,
    String label,
    IconData icon,
    bool selected,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _source = key);
          _load();
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? (_isDark ? AppColors.navy : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? AppColors.gold
                    : AppColors.textSecondary(_isDark),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: GoogleFonts.cairo(
                      fontSize: 10.5,
                      fontWeight:
                          selected ? FontWeight.w900 : FontWeight.w600,
                      color: selected
                          ? AppColors.gold
                          : AppColors.textSecondary(_isDark),
                    ),
                  ),
                ),
              ),
            ],
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
      backgroundColor: _isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Text('تقويم / فلتر الموظف', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
          ListTile(
            title: Text('كل الموظفين', style: GoogleFonts.cairo()),
            leading: Icon(_employeeId == null ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: AppColors.gold),
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
                  title: Text('${e['FullName']}', style: GoogleFonts.cairo(fontWeight: sel ? FontWeight.w800 : FontWeight.w600)),
                  subtitle: e['Department'] != null ? Text('${e['Department']}', style: GoogleFonts.cairo(fontSize: 11)) : null,
                  leading: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: sel ? AppColors.gold : Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _employeeId = idInt);
                    _load();
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // Agenda grouped by date - مطابق بلازور mobile-agenda
  Widget _buildAgendaGrouped() {
    final grouped = _groupedByDate();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
      itemCount: grouped.keys.length,
      itemBuilder: (_, gi) {
        final dateKey = grouped.keys.elementAt(gi);
        final items = grouped[dateKey]!;
        DateTime? date;
        try {
          if (dateKey != 'بدون تاريخ') date = DateTime.parse(dateKey);
        } catch (_) {}
        final isToday = date != null && date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: AppColors.card(_isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isToday ? const Color(0xFF3B82F6).withOpacity(0.35) : Colors.black.withOpacity(0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.15 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            // Sticky header - مطابق بلازور agenda-sticky-header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06))),
              ),
              child: Row(children: [
                if (date != null) ...[
                  Text('${date.day}', style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.text(_isDark), height: 1)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(DateFormat('EEEE', 'ar').format(date), style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text(_isDark))),
                    Text(DateFormat('MMMM yyyy', 'ar').format(date), style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary(_isDark))),
                  ]),
                ] else ...[
                  Icon(Icons.event_busy_rounded, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(dateKey, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                ],
                const Spacer(),
                if (isToday)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.3), blurRadius: 6)]), child: Text('اليوم', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(10)), child: Text('${items.length}', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold))),
              ]),
            ),
            // Events
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(children: items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _FollowUpCardPro(item: item, isDark: _isDark, formatDate: _fmtDate, formatDateOnly: _fmtDateOnly, onOpen: () => _open(item), onCall: () => _call('${item['phone'] ?? item['Phone'] ?? ''}'), onWa: () => _wa('${item['phone'] ?? item['Phone'] ?? ''}'), onCompleteLead: (item['isLeadTask'] == true || '${item['itemType']}' == 'lead') ? () => _completeLead(item) : null))).toList()),
            ),
          ]),
        );
      },
    );
  }

  Widget _emptyState() {
    final msg = switch (_scope) {
      'overdue' => 'لا توجد متابعات متأخرة',
      'today' => 'لا توجد متابعات اليوم',
      'tomorrow' => 'لا توجد متابعات غداً',
      'upcoming' => 'لا توجد متابعات قادمة',
      _ => 'لا توجد متابعات',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.event_available_rounded, size: 40, color: AppColors.gold)),
          const SizedBox(height: 14),
          Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('غيّر التبويب أو الفلتر لعرض المزيد', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary(_isDark))),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _load, icon: Icon(Icons.refresh_rounded, color: AppColors.gold), label: Text('تحديث', style: GoogleFonts.cairo(color: AppColors.gold)), style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.gold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Card Pro - مطابق بلازور mobile-ev-row + event-card-v2
// ═══════════════════════════════════════════════════════════
class _FollowUpCardPro extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final String Function(dynamic) formatDate;
  final String Function(dynamic) formatDateOnly;
  final VoidCallback onOpen;
  final VoidCallback onCall;
  final VoidCallback onWa;
  final VoidCallback? onCompleteLead;

  const _FollowUpCardPro({
    required this.item,
    required this.isDark,
    required this.formatDate,
    required this.formatDateOnly,
    required this.onOpen,
    required this.onCall,
    required this.onWa,
    this.onCompleteLead,
  });

  bool get _isLead => item['isLeadTask'] == true || '${item['itemType']}' == 'lead';
  String get _type => '${item['itemType'] ?? ''}';

  Color get _accent {
    if (_isLead) return const Color(0xFFEC4899);
    if (_type == 'opportunity') return const Color(0xFF2563EB);
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

  IconData get _bucketIcon {
    switch ('${item['bucket']}') {
      case 'overdue':
        return Icons.warning_amber_rounded;
      case 'today':
        return Icons.today_rounded;
      case 'tomorrow':
        return Icons.event_rounded;
      default:
        return Icons.upcoming_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = '${item['phone'] ?? item['Phone'] ?? ''}';
    final client = '${item['clientName'] ?? item['ClientName'] ?? '—'}';
    final title = '${item['title'] ?? ''}';
    final emp = '${item['employeeName'] ?? item['AssignedToName'] ?? ''}';
    final status = '${item['statusLabel'] ?? ''}';
    final best = '${item['bestTimeToReach'] ?? ''}';
    final campaign = '${item['campaignName'] ?? ''}';
    final platform = '${item['platform'] ?? ''}';
    final city = '${item['city'] ?? ''}';
    final subType = '${item['subType'] ?? item['TaskDescription'] ?? ''}';
    final overdue = '${item['bucket']}' == 'overdue';
    final initials = client.trim().isEmpty ? '?' : client.trim().substring(0, 1).toUpperCase();
    final followUpDate = item['followUpDate'] ?? item['FollowUpDate'];
    String timeText = '';
    try {
      final dt = followUpDate != null ? DateTime.tryParse(followUpDate.toString()) : null;
      if (dt != null) timeText = DateFormat('HH:mm').format(dt.toLocal());
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: overdue ? const Color(0xFFEF4444).withOpacity(0.30) : Colors.black.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.18 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Accent left border - مطابق بلازور mer-accent
          Container(width: 5, decoration: BoxDecoration(color: _accent, borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)))),
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Top row: badge + time + bucket
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _accent.withOpacity(0.28), blurRadius: 6, offset: const Offset(0, 2))]),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_isLead ? Icons.campaign_rounded : Icons.people_rounded, size: 11, color: Colors.white),
                          const SizedBox(width: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isLead
                                    ? Icons.campaign_outlined
                                    : Icons.person_outline_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isLead ? 'متابعة Lead' : 'متابعة عميل',
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      if (timeText.isNotEmpty)
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(8)), child: Text(timeText, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _bucketColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _bucketColor.withOpacity(0.22))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_bucketIcon, size: 10, color: _bucketColor),
                          const SizedBox(width: 3),
                          Text(_bucketLabel, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w800, color: _bucketColor)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: _accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _accent.withOpacity(0.20))),
                        child: Center(child: Text(initials, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w900, color: _accent))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(client, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A), height: 1.2)),
                          if (title.isNotEmpty && title != client)
                            Padding(padding: const EdgeInsets.only(top: 2), child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.3))),
                          const SizedBox(height: 6),
                          Text(subType.isNotEmpty ? subType : 'متابعة', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155), height: 1.3)),
                          const SizedBox(height: 6),
                          Row(children: [
                            if (emp.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.badge_outlined,
                                      size: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      emp,
                                      style: GoogleFonts.cairo(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(spacing: 5, runSpacing: 5, children: [
                            if (phone.isNotEmpty) _chip(Icons.phone_rounded, phone, isDark),
                            if (status.isNotEmpty) _chip(Icons.flag_outlined, status, isDark),
                            if (city.isNotEmpty) _chip(Icons.location_city_rounded, city, isDark),
                            if (best.isNotEmpty) _chip(Icons.access_time_filled_rounded, 'أفضل: $best', isDark, highlight: true),
                            if (campaign.isNotEmpty) _chip(Icons.campaign_rounded, campaign, isDark),
                            if (platform.isNotEmpty) _chip(Icons.public_rounded, platform, isDark),
                          ]),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    // Footer with WhatsApp + actions
                    Row(children: [
                      if (phone.isNotEmpty) ...[
                        _iconBtn(Icons.phone_rounded, const Color(0xFF16A34A), onCall),
                        const SizedBox(width: 6),
                        _iconBtn(FontAwesomeIcons.whatsapp, const Color(0xFF25D366), onWa),
                        const SizedBox(width: 6),
                      ],
                      if (onCompleteLead != null) ...[
                        _iconBtn(Icons.done_all_rounded, Colors.teal, onCompleteLead!),
                        const SizedBox(width: 6),
                      ],
                      if (phone.isNotEmpty)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA7F3D0))),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const FaIcon(FontAwesomeIcons.whatsapp, size: 12, color: Color(0xFF25D366)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF047857)))),
                            ]),
                          ),
                        ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _accent.withOpacity(0.12), foregroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        onPressed: onOpen,
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: Text('فتح', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String text, bool isDark, {bool highlight = false}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF2563EB).withOpacity(isDark ? 0.18 : 0.08) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? const Color(0xFF2563EB).withOpacity(0.30) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: highlight ? const Color(0xFF2563EB) : const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 10, fontWeight: highlight ? FontWeight.w800 : FontWeight.w600, color: highlight ? const Color(0xFF1D4ED8) : const Color(0xFF64748B)))),
      ]),
    );
  }

  Widget _iconBtn(dynamic icon, Color c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withOpacity(0.22)),
        ),
        child: compatIcon(icon, size: 16, color: c),
      ),
    );
  }
}
