import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/recovery_service.dart';
import '../services/permission_service.dart';
import 'opportunity_detail_screen.dart';
import 'client_card_screen.dart';
import 'lost_recovery_report_screen.dart';

/// استرداد الفرص الخاسرة - مطابق 100% لبلازور LostRecovery.razor (1521 سطر)
/// Workflow: الفرص اللي وصلت خسارة/غير مهتم (4,5) تروح لخدمة العملاء يحاولوا يرجعوها
class LostRecoveryScreen extends StatefulWidget {
  final int userId;
  final String username;

  const LostRecoveryScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<LostRecoveryScreen> createState() => _LostRecoveryScreenState();
}

class _LostRecoveryScreenState extends State<LostRecoveryScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _exporting = false;
  bool _searching = false;
  bool _loadingMore = false;

  Map<String, dynamic> _stats = {
    'LostCount': 0,
    'LostValue': 0,
    'UnassignedCount': 0,
    'RevivedThisMonth': 0,
    'UncontactedCount': 0,
  };
  List<dynamic> _items = [];
  int _total = 0;
  int _page = 1;
  bool _hasMore = false;
  int _lateCount = 0;
  int _pendingNew = 0;
  int _myEmpId = 0;

  List<dynamic> _stages = [];
  List<dynamic> _history = [];

  final _searchCtrl = TextEditingController();
  String _q = '';
  String _kind = 'all'; // all | lost | notinterested
  bool _candidateOnly = false;
  bool _mineOnly = false;
  bool _lateOnly = false;
  bool _unassignedOnly = false;
  bool _uncontactedOnly = false;
  String _sortBy = 'value'; // value | recent | days | followup
  DateTime? _closedFrom;
  DateTime? _closedTo;
  bool _showDate = false;

  // Selected for modals
  Map<String, dynamic>? _sel;
  bool _showContact = false;
  bool _showHistory = false;
  bool _showRevive = false;
  String? _errorMsg;
  String? _successMsg;

  // Contact form
  String _channel = 'اتصال';
  String _outcome = 'تم التواصل';
  final _summaryCtrl = TextEditingController();
  DateTime? _followUp;

  // Revive form
  bool _same = true;
  int _revStageId = 0;
  final _revValueCtrl = TextEditingController();
  final _revProductCtrl = TextEditingController();
  final _revNotesCtrl = TextEditingController();

  bool get _isDark => ThemeService().isDarkMode;
  final _perms = PermissionService();

  bool get _canView => _perms.canViewLostRecovery;
  bool get _canRevive => _perms.canReviveLostOpportunity;
  bool get _canLogContact => _perms.canLogLostRecoveryContact;

  bool get _hasActiveFilters =>
      _q.trim().isNotEmpty ||
      _kind != 'all' ||
      _candidateOnly ||
      _lateOnly ||
      _mineOnly ||
      _unassignedOnly ||
      _uncontactedOnly ||
      _closedFrom != null ||
      _closedTo != null;

  int get _activeFilterCount {
    int c = 0;
    if (_q.trim().isNotEmpty) c++;
    if (_kind != 'all') c++;
    if (_candidateOnly) c++;
    if (_lateOnly) c++;
    if (_mineOnly) c++;
    if (_unassignedOnly) c++;
    if (_uncontactedOnly) c++;
    if (_closedFrom != null) c++;
    if (_closedTo != null) c++;
    return c;
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _q = _searchCtrl.text;
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _summaryCtrl.dispose();
    _revValueCtrl.dispose();
    _revProductCtrl.dispose();
    _revNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await RecoveryService.runMaintenance();
      final results = await Future.wait([
        RecoveryService.getStats(),
        RecoveryService.getQueue(
          search: _q,
          kind: _kind,
          candidateOnly: _candidateOnly,
          mineOnly: _mineOnly,
          lateOnly: _lateOnly,
          unassignedOnly: _unassignedOnly,
          uncontactedOnly: _uncontactedOnly,
          sortBy: _sortBy,
          pageIndex: 1,
          pageSize: 12,
          username: widget.username,
        ),
        RecoveryService.getLateCount(),
        RecoveryService.getUnprocessedCount(),
        RecoveryService.getStages(),
        RecoveryService.getCurrentEmployeeId(widget.username),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        final queue = results[1] as Map<String, dynamic>;
        _items = (queue['Items'] as List?) ?? [];
        _total = queue['TotalCount'] ?? 0;
        _page = queue['PageIndex'] ?? 1;
        _hasMore = queue['HasMore'] ?? false;
        _lateCount = results[2] as int;
        _pendingNew = results[3] as int;
        _stages = results[4] as List<dynamic>;
        _myEmpId = results[5] as int;
        if (_stages.isNotEmpty && _revStageId == 0) {
          _revStageId = _stages.first['StageID'] ?? _stages.first['StageId'] ?? 0;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyFilters() async {
    setState(() => _searching = true);
    try {
      final queue = await RecoveryService.getQueue(
        search: _q,
        kind: _kind,
        candidateOnly: _candidateOnly,
        mineOnly: _mineOnly,
        lateOnly: _lateOnly,
        unassignedOnly: _unassignedOnly,
        uncontactedOnly: _uncontactedOnly,
        sortBy: _sortBy,
        closedFrom: _closedFrom != null ? DateFormat('yyyy-MM-dd').format(_closedFrom!) : null,
        closedTo: _closedTo != null ? DateFormat('yyyy-MM-dd').format(_closedTo!) : null,
        pageIndex: 1,
        pageSize: 12,
        username: widget.username,
      );
      if (!mounted) return;
      setState(() {
        _items = (queue['Items'] as List?) ?? [];
        _total = queue['TotalCount'] ?? 0;
        _page = queue['PageIndex'] ?? 1;
        _hasMore = queue['HasMore'] ?? false;
      });
      // Refresh stats & counts
      final stats = await RecoveryService.getStats();
      final late = await RecoveryService.getLateCount();
      if (mounted) setState(() {
        _stats = stats;
        _lateCount = late;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadMore() async {
    if (_busy || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final queue = await RecoveryService.getQueue(
        search: _q,
        kind: _kind,
        candidateOnly: _candidateOnly,
        mineOnly: _mineOnly,
        lateOnly: _lateOnly,
        unassignedOnly: _unassignedOnly,
        uncontactedOnly: _uncontactedOnly,
        sortBy: _sortBy,
        closedFrom: _closedFrom != null ? DateFormat('yyyy-MM-dd').format(_closedFrom!) : null,
        closedTo: _closedTo != null ? DateFormat('yyyy-MM-dd').format(_closedTo!) : null,
        pageIndex: _page + 1,
        pageSize: 12,
        username: widget.username,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll((queue['Items'] as List?) ?? []);
        _total = queue['TotalCount'] ?? _total;
        _page = queue['PageIndex'] ?? _page + 1;
        _hasMore = queue['HasMore'] ?? false;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _clearAllFilters() {
    setState(() {
      _q = '';
      _searchCtrl.clear();
      _kind = 'all';
      _candidateOnly = false;
      _lateOnly = false;
      _mineOnly = false;
      _unassignedOnly = false;
      _uncontactedOnly = false;
      _sortBy = 'value';
      _closedFrom = null;
      _closedTo = null;
      _showDate = false;
    });
    _applyFilters();
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _wa(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    var p = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.startsWith('0')) p = '2$p';
    final uri = Uri.parse('https://wa.me/$p');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openOpp(int oppId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpportunityDetailScreen(
          opportunityId: oppId,
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    );
  }

  void _openClient(int partyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientCardScreen(
          userId: widget.userId,
          username: widget.username,
          initialPartyId: partyId,
        ),
      ),
    );
  }

  // ── Contact modal
  void _openContact(Map<String, dynamic> it) {
    setState(() {
      _sel = it;
      _channel = 'اتصال';
      _outcome = 'تم التواصل';
      _summaryCtrl.clear();
      _followUp = null;
      _errorMsg = null;
      _showContact = true;
    });
  }

  Future<void> _submitContact() async {
    if (_sel == null) return;
    if (_summaryCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'اكتب ملخص التواصل أولاً');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await RecoveryService.logContact(
        opportunityId: _sel!['OpportunityId'] ?? _sel!['OpportunityID'] ?? 0,
        partyId: _sel!['PartyId'] ?? _sel!['PartyID'] ?? 0,
        channel: _channel,
        outcome: _outcome,
        summary: _summaryCtrl.text.trim(),
        nextFollowUpDate: _followUp,
        userName: widget.username,
      );
      final ok = res['success'] == true;
      if (ok) {
        setState(() {
          _showContact = false;
          _sel = null;
          _successMsg = res['message'] ?? 'تم تسجيل المحاولة';
        });
        await _applyFilters();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _successMsg = null);
        });
      } else {
        setState(() => _errorMsg = res['message'] ?? 'فشل');
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── History modal
  Future<void> _openHistory(Map<String, dynamic> it) async {
    setState(() {
      _sel = it;
      _history = [];
      _errorMsg = null;
      _showHistory = true;
      _busy = true;
    });
    try {
      final h = await RecoveryService.getHistory(it['OpportunityId'] ?? it['OpportunityID'] ?? 0);
      if (mounted) setState(() => _history = h);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Revive modal
  void _openRevive(Map<String, dynamic> it) {
    setState(() {
      _sel = it;
      _same = true;
      _revStageId = _stages.isNotEmpty ? (_stages.first['StageID'] ?? _stages.first['StageId'] ?? 0) : 0;
      _revValueCtrl.text = '${it['ExpectedValue'] ?? ''}';
      _revProductCtrl.text = '${it['InterestedProduct'] ?? ''}';
      _revNotesCtrl.clear();
      _errorMsg = null;
      _showRevive = true;
    });
  }

  Future<void> _submitRevive() async {
    if (_sel == null) return;
    if (_revStageId == 0) {
      setState(() => _errorMsg = 'اختر المرحلة الجديدة');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await RecoveryService.revive(
        opportunityId: _sel!['OpportunityId'] ?? _sel!['OpportunityID'] ?? 0,
        sameOpportunity: _same,
        newStageId: _revStageId,
        expectedValue: double.tryParse(_revValueCtrl.text),
        nextFollowUpDate: DateTime.now().add(const Duration(days: 3)),
        newInterestedProduct: _same ? null : _revProductCtrl.text.trim(),
        notes: _revNotesCtrl.text.trim().isEmpty ? null : _revNotesCtrl.text.trim(),
        userName: widget.username,
      );
      final ok = res['success'] == true;
      if (ok) {
        setState(() {
          _showRevive = false;
          _sel = null;
          _successMsg = res['message'] ?? 'تم الاسترداد';
        });
        await _applyFilters();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _successMsg = null);
        });
      } else {
        setState(() => _errorMsg = res['message'] ?? 'فشل');
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _money(dynamic v) {
    if (v == null) return '—';
    try {
      final numericValue = v is num ? v : double.tryParse('$v') ?? 0;
      return '${NumberFormat('#,###').format(numericValue)} ج.م';
    } catch (_) {
      return '$v';
    }
  }

  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF94A3B8);
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    try {
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        body: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (ctx, inner) => [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 235,
                  backgroundColor: const Color(0xFF312E81),
                  foregroundColor: Colors.white,
                  title: Text('استرداد الفرص الخاسرة',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
                  actions: [
                    IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _bootstrap),
                    IconButton(
                      tooltip: 'تقرير الاسترداد الشامل',
                      icon: const Icon(Icons.assessment_rounded, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LostRecoveryReportScreen(userId: widget.userId, username: widget.username),
                          ),
                        );
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(background: _buildHero()),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (_successMsg != null)
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF065F46), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Expanded(child: Text(_successMsg!, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            InkWell(onTap: () => setState(() => _successMsg = null), child: const Icon(Icons.close, color: Colors.white, size: 16)),
                          ]),
                        ),
                      if (_errorMsg != null && !_showContact && !_showHistory && !_showRevive)
                        InkWell(
                          onTap: () => setState(() => _errorMsg = null),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))),
                            child: Row(children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_errorMsg!, style: GoogleFonts.cairo(color: const Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.bold))),
                            ]),
                          ),
                        ),
                      if (_pendingNew > 0 && !_loading)
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
                          child: Row(children: [
                            const Icon(
                              Icons.notification_important_outlined,
                              color: Color(0xFF1D4ED8),
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'يوجد $_pendingNew فرصة خاسرة جديدة بانتظار الاستقبال',
                                style: GoogleFonts.cairo(
                                  color: const Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () async {
                                setState(() => _pendingNew = 0);
                                await _bootstrap();
                              },
                              child: Text('استقبال الآن', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _pendingNew = 0), color: const Color(0xFF1D4ED8)),
                          ]),
                        ),
                      _buildKpis(),
                      _buildFilters(),
                      if (_searching)
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFC7D2FE), style: BorderStyle.solid)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
                            const SizedBox(width: 8),
                            Text('جارٍ البحث وتحديث القائمة...', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                          ]),
                        ),
                    ],
                  ),
                ),
              ],
              body: _loading
                  ? Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : _items.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: AppColors.gold,
                          onRefresh: _applyFilters,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                            itemCount: _items.length + (_hasMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == _items.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: _loadingMore
                                        ? CircularProgressIndicator(color: AppColors.gold)
                                        : ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                            onPressed: _loadMore,
                                            child: Text('تحميل المزيد', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                  ),
                                );
                              }
                              final raw = _items[i];
                              final item = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                              return _RecoveryCard(
                                item: item,
                                isDark: _isDark,
                                money: _money,
                                hexToColor: _hexToColor,
                                onCall: () => _call(item['Phone']),
                                onWa: () => _wa(item['Phone']),
                                onOpenOpp: () => _openOpp(item['OpportunityId'] ?? 0),
                                onOpenClient: () => _openClient(item['PartyId'] ?? 0),
                                onContact: _canLogContact ? () => _openContact(item) : null,
                                onRevive: _canRevive ? () => _openRevive(item) : null,
                                onHistory: () => _openHistory(item),
                              );
                            },
                          ),
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
            // Modals
            if (_showContact && _sel != null) _buildContactModal(),
            if (_showRevive && _sel != null) _buildReviveModal(),
            if (_showHistory && _sel != null) _buildHistoryModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, const Color(0xFF1E3A5F), const Color(0xFF1E40AF), AppColors.navy.withOpacity(0.85)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles - هوية فلاتر navy+gold
          Positioned(top: -30, right: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle))),
          Positioned(bottom: -30, left: 10, child: Container(width: 140, height: 140, decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.08), shape: BoxShape.circle))),
          Positioned(top: 20, left: 80, child: Container(width: 60, height: 60, decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.05), shape: BoxShape.circle))),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                      boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Center(child: Icon(Icons.restart_alt_rounded, color: AppColors.gold, size: 28)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF34D399), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF34D399).withOpacity(0.5), blurRadius: 6)])),
                        const SizedBox(width: 6),
                        Text('وحدة متابعة العملاء', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 2),
                      Text('استرداد الفرص الخاسرة',
                          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, height: 1.2)),
                      const SizedBox(height: 2),
                      Text('متابعة العملاء اللي وصلوا خسارة/غير مهتم وإعادتهم لدورة البيع',
                          style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11, height: 1.3)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  _heroChip(
                    Icons.trending_down_rounded,
                    '${_stats['LostCount']} خاسرة',
                    Colors.white,
                    Colors.white,
                  ),
                  const SizedBox(width: 8),
                  _heroChip(
                    Icons.payments_outlined,
                    _money(_stats['LostValue']),
                    AppColors.gold,
                    AppColors.gold,
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg == Colors.white
            ? Colors.white.withOpacity(0.12)
            : bg.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.cairo(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    return Container(
      color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _kpiCard(Icons.trending_down_rounded, '${_stats['LostCount']}', 'خاسرة بانتظار المتابعة', const Color(0xFFEF4444), _kind == 'all' && !_unassignedOnly && !_uncontactedOnly && !_candidateOnly && !_lateOnly && !_mineOnly, () {
            setState(() {
              _kind = 'all';
              _candidateOnly = false;
              _lateOnly = false;
              _mineOnly = false;
              _unassignedOnly = false;
              _uncontactedOnly = false;
            });
            _applyFilters();
          }),
          _kpiCard(Icons.payments_outlined, _money(_stats['LostValue']), 'إجمالي القيمة', const Color(0xFF4F46E5), false, () {
            setState(() => _sortBy = 'value');
            _applyFilters();
          }),
          _kpiCard(Icons.pending_actions_rounded, '${_stats['UnassignedCount']}', 'بانتظار التوزيع', const Color(0xFFD97706), _unassignedOnly, () {
            setState(() {
              _unassignedOnly = !_unassignedOnly;
              if (_unassignedOnly) _uncontactedOnly = false;
            });
            _applyFilters();
          }),
          _kpiCard(Icons.restart_alt_rounded, '${_stats['RevivedThisMonth']}', 'استُرد هذا الشهر', const Color(0xFF059669), false, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => LostRecoveryReportScreen(userId: widget.userId, username: widget.username)));
          }),
          _kpiCard(Icons.phone_outlined, '${_stats['UncontactedCount']}', 'لم يُتواصل بعد', const Color(0xFFDB2777), _uncontactedOnly, () {
            setState(() {
              _uncontactedOnly = !_uncontactedOnly;
              if (_uncontactedOnly) _unassignedOnly = false;
            });
            _applyFilters();
          }),
        ]),
      ),
    );
  }

  Widget _kpiCard(IconData icon, String val, String label, Color c, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? c.withOpacity(_isDark ? 0.22 : 0.14) : (_isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? c : (_isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)), width: selected ? 1.6 : 1),
            boxShadow: selected ? [BoxShadow(color: c.withOpacity(0.22), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: c, size: 19)),
              const Spacer(),
              if (selected) Icon(Icons.check_circle_rounded, size: 16, color: c),
            ]),
            const SizedBox(height: 10),
            Text(val, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w900, color: _isDark ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
          ]),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withOpacity(0.06)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _q = v;
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (_q == v) _applyFilters();
                });
              },
              onSubmitted: (_) => _applyFilters(),
              style: GoogleFonts.cairo(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ابحث بالعميل أو الهاتف...',
                hintStyle: GoogleFonts.cairo(fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _q.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _searchCtrl.clear(); _q = ''; _applyFilters(); })
                    : null,
                isDense: true,
                filled: true,
                fillColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
            child: DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox.shrink(),
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text(_isDark)),
              items: [
                DropdownMenuItem(value: 'value', child: Text('الأعلى قيمة', style: GoogleFonts.cairo(fontSize: 12))),
                DropdownMenuItem(value: 'recent', child: Text('الأحدث خسارة', style: GoogleFonts.cairo(fontSize: 12))),
                DropdownMenuItem(value: 'days', child: Text('الأقدم خسارة', style: GoogleFonts.cairo(fontSize: 12))),
                DropdownMenuItem(value: 'followup', child: Text('الأقرب متابعة', style: GoogleFonts.cairo(fontSize: 12))),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _sortBy = v);
                _applyFilters();
              },
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('الكل', _kind == 'all', () { setState(() => _kind = 'all'); _applyFilters(); }),
            _chip('خسارة', _kind == 'lost', () { setState(() => _kind = 'lost'); _applyFilters(); }),
            _chip('غير مهتم', _kind == 'notinterested', () { setState(() => _kind = 'notinterested'); _applyFilters(); }),
            _chip('مرشحة للاسترداد', _candidateOnly, () { setState(() => _candidateOnly = !_candidateOnly); _applyFilters(); }, isSpecial: true),
            _chip('متأخرة${_lateCount > 0 ? ' ($_lateCount)' : ''}', _lateOnly, () { setState(() => _lateOnly = !_lateOnly); _applyFilters(); }, isLate: true),
            if (_myEmpId > 0) _chip('قضاياي', _mineOnly, () { setState(() => _mineOnly = !_mineOnly); _applyFilters(); }),
            _chip('تاريخ الإغلاق${(_closedFrom != null || _closedTo != null) ? ' محدد' : ''}', _closedFrom != null || _closedTo != null || _showDate, () { setState(() => _showDate = !_showDate); }),
            if (_hasActiveFilters) _chip('مسح الكل ($_activeFilterCount)', false, _clearAllFilters, isClear: true),
          ]),
        ),
        if (_showDate) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFC7D2FE), style: BorderStyle.solid)),
            child: Row(children: [
              Text('تاريخ الإغلاق', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4338CA))),
              const SizedBox(width: 8),
              Text('من', style: GoogleFonts.cairo(fontSize: 11)),
              const SizedBox(width: 6),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _closedFrom ?? DateTime.now());
                  if (d != null) { setState(() => _closedFrom = d); _applyFilters(); }
                },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFDBE3F3))), child: Text(_closedFrom == null ? 'اختر' : DateFormat('yyyy/MM/dd').format(_closedFrom!), style: GoogleFonts.cairo(fontSize: 11))),
              ),
              const SizedBox(width: 8),
              Text('إلى', style: GoogleFonts.cairo(fontSize: 11)),
              const SizedBox(width: 6),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _closedTo ?? DateTime.now());
                  if (d != null) { setState(() => _closedTo = d); _applyFilters(); }
                },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFDBE3F3))), child: Text(_closedTo == null ? 'اختر' : DateFormat('yyyy/MM/dd').format(_closedTo!), style: GoogleFonts.cairo(fontSize: 11))),
              ),
              const Spacer(),
              if (_closedFrom != null || _closedTo != null)
                InkWell(onTap: () { setState(() { _closedFrom = null; _closedTo = null; }); _applyFilters(); }, child: Text('مسح التواريخ', style: GoogleFonts.cairo(fontSize: 11, color: Colors.red))),
              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _showDate = false)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {bool isSpecial = false, bool isLate = false, bool isClear = false}) {
    Color bg, fg, border;
    if (isClear) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      border = const Color(0xFFFCA5A5);
    } else if (isLate && selected) {
      bg = const Color(0xFFF59E0B);
      fg = Colors.white;
      border = Colors.transparent;
    } else if (selected) {
      bg = const Color(0xFF4F46E5);
      fg = Colors.white;
      border = Colors.transparent;
    } else if (isSpecial) {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF047857);
      border = const Color(0xFFA7F3D0);
    } else {
      bg = _isDark ? const Color(0xFF1E293B) : Colors.white;
      fg = const Color(0xFF475569);
      border = const Color(0xFFDBE3F3);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
          child: Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    if (_hasActiveFilters) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.search_off_rounded, size: 40, color: AppColors.gold)),
            const SizedBox(height: 16),
            Text('لا توجد نتائج مطابقة للبحث أو الفلاتر الحالية', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('جرّب تعديل كلمات البحث أو إلغاء بعض الفلاتر', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _clearAllFilters, child: Text('مسح الفلاتر والبحث', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold))),
          ]),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.inbox_rounded, size: 40, color: Color(0xFF4F46E5))),
          const SizedBox(height: 16),
          Text('لا توجد فرص خاسرة مطابقة', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('لو فيه فرصة اتقفلت بخسارة هتظهر هنا تلقائياً وبيتواصل معاها فريق خدمة العملاء', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _bootstrap, icon: const Icon(Icons.refresh_rounded), label: Text('فحص الخسائر الجديدة', style: GoogleFonts.cairo())),
        ]),
      ),
    );
  }

  Widget _buildContactModal() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7).withOpacity(_isDark ? 0.15 : 1), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.18), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.phone_in_talk_rounded, color: Colors.orange, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('تسجيل محاولة تواصل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() { _showContact = false; _sel = null; })),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.inputFill(_isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.06))),
                    child: Row(children: [
                      Expanded(child: Text('${_sel!['ClientName']} • #OP-${_sel!['OpportunityId']} • مغلق منذ ${_sel!['DaysSinceClosed']} يوم', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold))),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Text('قناة التواصل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _channel,
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    items: ['اتصال', 'واتساب', 'زيارة', 'بريد'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.cairo(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _channel = v ?? 'اتصال'),
                  ),
                  const SizedBox(height: 12),
                  Text('ملخص التواصل / نتيجة المكالمة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _summaryCtrl,
                    maxLines: 3,
                    style: GoogleFonts.cairo(fontSize: 13),
                    decoration: InputDecoration(hintText: 'مثال: تحدثت مع المدير المالي، طلب عرضًا جديدًا بخصم 10%...', hintStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 12),
                  Text('نتيجة التواصل *', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _outcome,
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    items: ['تم التواصل', 'لم يرد', 'طلب مهلة', 'رفض نهائي'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.cairo(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _outcome = v ?? 'تم التواصل'),
                  ),
                  if (_outcome == 'رفض نهائي') ...[
                    const SizedBox(height: 10),
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.22))), child: Row(children: [Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700), const SizedBox(width: 6), Expanded(child: Text('تنبيه: باختيار \"رفض نهائي\" تُغلق فرصة الاسترداد نهائياً ولا تظهر في القائمة مرة أخرى', style: GoogleFonts.cairo(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)))])),
                  ],
                  const SizedBox(height: 12),
                  Text('موعد المتابعة القادمة (اختياري)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)), initialDate: DateTime.now().add(const Duration(days: 1)));
                      if (d != null) setState(() => _followUp = d);
                    },
                    child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.event_rounded, size: 18, color: AppColors.gold), const SizedBox(width: 8), Text(_followUp == null ? 'اختر تاريخ المتابعة' : DateFormat('yyyy/MM/dd').format(_followUp!), style: GoogleFonts.cairo(fontSize: 13))])),
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Text(_errorMsg!, style: GoogleFonts.cairo(color: Colors.red.shade700, fontSize: 12))),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => setState(() { _showContact = false; _sel = null; }), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)), child: Text('إلغاء', style: GoogleFonts.cairo()))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(onPressed: _busy ? null : _submitContact, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)), child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('حفظ المحاولة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)))),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildReviveModal() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 560),
          decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF059669).withOpacity(0.12), const Color(0xFF10B981).withOpacity(0.08)]), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.18), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.restart_alt_rounded, color: Color(0xFF059669), size: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('العميل راجع — إعادة تفعيل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() { _showRevive = false; _sel = null; })),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFA7F3D0))), child: Text('${_sel!['ClientName']} عاد بعد خسارة #OP-${_sel!['OpportunityId']} بقيمة ${_money(_sel!['ExpectedValue'])}', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF065F46)))),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _same = true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _same ? const Color(0xFF059669).withOpacity(0.12) : AppColors.inputFill(_isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: _same ? const Color(0xFF059669) : Colors.black12)), child: Column(children: [Icon(Icons.refresh_rounded, color: _same ? const Color(0xFF059669) : Colors.grey), const SizedBox(height: 6), Text('نفس الفرصة', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)), Text('نفس الاحتياج والمنتج', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey))])),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _same = false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: !_same ? const Color(0xFF4F46E5).withOpacity(0.12) : AppColors.inputFill(_isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: !_same ? const Color(0xFF4F46E5) : Colors.black12)), child: Column(children: [Icon(Icons.add_circle_outline_rounded, color: !_same ? const Color(0xFF4F46E5) : Colors.grey), const SizedBox(height: 6), Text('فرصة جديدة', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)), Text('احتياج مختلف', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey))])),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('المرحلة الجديدة *', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: _revStageId == 0 ? null : _revStageId,
                          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                          items: _stages.map((s) => DropdownMenuItem<int>(value: s['StageID'] ?? s['StageId'], child: Text(s['StageNameAr'] ?? s['StageName'] ?? '', style: GoogleFonts.cairo(fontSize: 12)))).toList(),
                          onChanged: (v) => setState(() => _revStageId = v ?? 0),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('القيمة المتوقعة', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(controller: _revValueCtrl, keyboardType: TextInputType.number, style: GoogleFonts.cairo(fontSize: 13), decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), hintText: 'ج.م', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
                      ]),
                    ),
                  ]),
                  if (!_same) ...[
                    const SizedBox(height: 12),
                    Text('المنتج / الخدمة المطلوبة', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(controller: _revProductCtrl, style: GoogleFonts.cairo(fontSize: 13), decoration: InputDecoration(hintText: 'مثال: نظام محاسبة لفرع جديد...', hintStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  ],
                  const SizedBox(height: 12),
                  Text('ملاحظات (اختياري)', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(controller: _revNotesCtrl, maxLines: 2, style: GoogleFonts.cairo(fontSize: 13), decoration: InputDecoration(hintText: 'أي تفاصيل عن اتفاق العودة...', hintStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Text(_errorMsg!, style: GoogleFonts.cairo(color: Colors.red.shade700, fontSize: 12))),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => setState(() { _showRevive = false; _sel = null; }), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)), child: Text('إلغاء', style: GoogleFonts.cairo()))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(onPressed: _busy ? null : _submitRevive, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)), child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_same ? 'تفعيل الفرصة' : 'إنشاء فرصة جديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)))),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryModal() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
          decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.history_rounded, color: AppColors.navy, size: 20)),
                const SizedBox(width: 10),
                Expanded(child: Text('سجل التواصل بعد الخسارة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() { _showHistory = false; _sel = null; })),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill(_isDark), borderRadius: BorderRadius.circular(12)), child: Text('${_sel!['ClientName']} • #OP-${_sel!['OpportunityId']} • مغلق منذ ${_sel!['DaysSinceClosed']} يوم${_sel!['RecoveryEmployeeName'] != null ? ' • المتابعة: ${_sel!['RecoveryEmployeeName']}' : ''}', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold))),
            ),
            Expanded(
              child: _busy
                  ? Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : _history.isEmpty
                      ? Center(child: Text('لا توجد محاولات تواصل مسجلة بعد الخسارة حتى الآن', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: _history.length,
                          itemBuilder: (_, i) {
                            final h = Map<String, dynamic>.from(_history[i] as Map);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.inputFill(_isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.06))),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(h['Date'] != null ? DateFormat('yyyy/MM/dd HH:mm').format(DateTime.tryParse(h['Date'].toString())?.toLocal() ?? DateTime.now()) : '—', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary(_isDark))),
                                  const SizedBox(width: 8),
                                  if (h['Channel'] != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text('${h['Channel']}', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)))),
                                  const Spacer(),
                                  Text('${h['EmployeeName'] ?? ''}', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
                                ]),
                                const SizedBox(height: 6),
                                Text('${h['Summary'] ?? ''}', style: GoogleFonts.cairo(fontSize: 13, height: 1.4)),
                              ]),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => setState(() { _showHistory = false; _sel = null; }), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)), child: Text('إغلاق', style: GoogleFonts.cairo()))),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Card
// ═══════════════════════════════════════════════════════════
class _RecoveryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final String Function(dynamic) money;
  final Color Function(String?) hexToColor;
  final VoidCallback onCall;
  final VoidCallback onWa;
  final VoidCallback onOpenOpp;
  final VoidCallback onOpenClient;
  final VoidCallback? onContact;
  final VoidCallback? onRevive;
  final VoidCallback onHistory;

  const _RecoveryCard({
    required this.item,
    required this.isDark,
    required this.money,
    required this.hexToColor,
    required this.onCall,
    required this.onWa,
    required this.onOpenOpp,
    required this.onOpenClient,
    this.onContact,
    this.onRevive,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final clientName = '${item['ClientName'] ?? '—'}';
    final phone = '${item['Phone'] ?? ''}';
    final stageName = '${item['StageNameAr'] ?? 'خسارة'}';
    final stageColor = hexToColor(item['StageColor']);
    final isCandidate = item['IsRecoveryCandidate'] == true || item['IsRecoveryCandidate'] == 1;
    final isNotInterested = item['IsNotInterested'] == true;
    final value = item['ExpectedValue'];
    final days = item['DaysSinceClosed'] ?? 0;
    final closedAt = item['ClosedAt'];
    final prevEmp = '${item['PreviousEmployeeName'] ?? ''}';
    final recEmp = '${item['RecoveryEmployeeName'] ?? ''}';
    final lostReason = '${item['LostReasonNameAr'] ?? ''}';
    final lostNotes = '${item['LostNotes'] ?? ''}';
    final lastCsSummary = '${item['LastCsSummary'] ?? ''}';
    final lastCsDate = item['LastCsDate'];
    final lastCsBy = '${item['LastCsBy'] ?? ''}';
    final nextFollow = item['NextFollowUpDate'];
    final isOverdue = item['IsFollowUpOverdue'] == true;
    final initials = clientName.trim().isEmpty ? '؟' : clientName.trim().substring(0, 1).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCandidate ? const Color(0xFFA7F3D0) : Colors.black.withOpacity(0.06), width: isCandidate ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.20 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: stageColor.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(initials, style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w900, color: stageColor))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(clientName, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  if (isCandidate) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(20)), child: Text('⭐ قابل للاسترداد', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF047857)))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: isNotInterested ? const Color(0xFFE2E8F0) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(20)), child: Text(stageName, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: isNotInterested ? const Color(0xFF475569) : const Color(0xFFB91C1C)))),
                  if (phone.isNotEmpty) InkWell(onTap: onCall, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(20)), child: Text(phone, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5))))),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  InkWell(onTap: onOpenOpp, child: Text('#OP-${item['OpportunityId']} ↗', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5), decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dashed))),
                  Text('•', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
                  Text('مغلق منذ $days يوم', style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  if (closedAt != null) ...[
                    Text('•', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
                    Text(() {
                      try {
                        final dt = DateTime.tryParse(closedAt.toString());
                        return dt == null ? '' : DateFormat('yyyy/MM/dd').format(dt);
                      } catch (_) {
                        return '';
                      }
                    }(), style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B))),
                  ],
                  if (prevEmp.isNotEmpty) ...[
                    Text('•', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
                    Text('المندوب: $prevEmp', style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF64748B))),
                  ],
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (lostReason.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)), child: Text('السبب: $lostReason', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)))),
                  if (lostNotes.isNotEmpty) Container(constraints: const BoxConstraints(maxWidth: 260), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFDBE3F3), style: BorderStyle.solid)), child: Text(lostNotes, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFF475569)))),
                ]),
                if (lastCsSummary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.06))), child: Row(children: [
                    Text('آخر تواصل بعد الخسارة:', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    const SizedBox(width: 6),
                    Expanded(child: Text(lastCsSummary.length > 60 ? '${lastCsSummary.substring(0, 60)}...' : lastCsSummary, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700))),
                    if (lastCsDate != null) ...[
                      const SizedBox(width: 6),
                      Text(() {
                        try {
                          final dt = DateTime.tryParse(lastCsDate.toString());
                          return dt == null ? '' : DateFormat('yyyy/MM/dd HH:mm').format(dt.toLocal());
                        } catch (_) {
                          return '';
                        }
                      }(), style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey)),
                    ],
                    if (lastCsBy.isNotEmpty) ...[
                      Text(' • $lastCsBy', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey)),
                    ],
                  ])),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(value), style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              Text('قيمة متوقعة', style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFF64748B))),
              if (nextFollow != null) ...[
                const SizedBox(height: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: isOverdue ? const Color(0xFFFEE2E2) : const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(20)), child: Text('${() { try { final dt = DateTime.tryParse(nextFollow.toString()); return dt == null ? '' : DateFormat('yyyy/MM/dd').format(dt); } catch (_) { return ''; } }()}${isOverdue ? ' • متأخرة' : ''}', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: isOverdue ? const Color(0xFFB91C1C) : const Color(0xFF4F46E5)))),
              ],
              const SizedBox(height: 6),
              recEmp.isNotEmpty ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(20)), child: Text(recEmp, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF047857)))) : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(20)), child: Text('سيُتابع تلقائياً', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)))),
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _smallIconBtn(Icons.phone_rounded, const Color(0xFF4F46E5), onCall),
                const SizedBox(width: 4),
                _smallIconBtn(Icons.chat_rounded, const Color(0xFF25D366), onWa),
                const SizedBox(width: 4),
                _smallIconBtn(Icons.person_rounded, const Color(0xFFD97706), onOpenClient),
                const SizedBox(width: 4),
                _smallIconBtn(Icons.history_rounded, const Color(0xFFDB2777), onHistory),
              ]),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            if (onContact != null) Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: onContact, icon: const Icon(Icons.edit_note_rounded, size: 18), label: Text('سجّل محاولة تواصل', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)))),
            if (onContact != null && onRevive != null) const SizedBox(width: 10),
            if (onRevive != null) Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: onRevive, icon: const Icon(Icons.restart_alt_rounded, size: 18), label: Text('العميل راجع — استرداد', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)))),
          ]),
        ]),
      ),
    );
  }

  Widget _smallIconBtn(IconData icon, Color c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(width: 32, height: 32, decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.22))), child: Icon(icon, size: 16, color: c)),
    );
  }
}
