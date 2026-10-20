import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/icon_utils.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import '../services/pipeline_service.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/opportunities_service.dart';
import '../services/permission_service.dart';
import 'add_interaction_screen.dart';
import 'add_opportunity_screen.dart';

/// تفاصيل الفرصة - مطابق 100% لبلازور CrmOpportunityDetail.razor
/// Workflow: الفرص المغلقة (3=تم البيع, 4,5=خسارة) تحتاج موافقة GM/SalesManager
/// بانر طلب معلق + معتمد + تنفيذ مطابق لبلازور
class OpportunityDetailScreen extends StatefulWidget {
  final int opportunityId;
  final int userId;
  final String username;

  const OpportunityDetailScreen({
    Key? key,
    required this.opportunityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<OpportunityDetailScreen> createState() => _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  Map<String, dynamic>? _opportunity;
  List<dynamic> _interactions = [];
  List<dynamic> _stages = [];
  Map<String, dynamic>? _pendingClosure;
  bool _isLoading = true;
  bool _busy = false;

  final _perms = PermissionService();
  final _oppService = OpportunitiesService();

  bool get _isDark => ThemeService().isDarkMode;

  bool get _canDirectCloseOpportunity =>
      _perms.isAdmin || _perms.isSalesManager || _perms.isGeneralManager;

  bool get _canApproveClosure =>
      _perms.isAdmin || _perms.isSalesManager || _perms.isGeneralManager;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        PipelineService.getOpportunityById(widget.opportunityId),
        PipelineService.getInteractions(widget.opportunityId),
        PipelineService.getStages(),
        _oppService.getPendingClosureRequest(widget.opportunityId),
      ]);
      if (!mounted) return;
      setState(() {
        _opportunity = results[0] as Map<String, dynamic>?;
        _interactions = results[1] as List<dynamic>;
        _stages = results[2] as List<dynamic>;
        _pendingClosure = results[3] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════
  //  🔍 هل الفرصة خسارة؟
  // ═══════════════════════════════════
  bool get _isLost {
    if (_opportunity == null) return false;
    final stageId = _opportunity!['StageID'] ?? _opportunity!['StageId'] ?? 0;
    if (stageId == 4 || stageId == 5) return true;
    final stageName = (_opportunity!['StageNameAr'] ?? '').toString().toLowerCase();
    final stageNameEn = (_opportunity!['StageName'] ?? '').toString().toLowerCase();
    final status = (_opportunity!['Status'] ?? '').toString().toLowerCase();
    return stageName.contains('خسارة') ||
        stageName.contains('خسار') ||
        stageName.contains('غير مهتم') ||
        stageNameEn.contains('lost') ||
        status.contains('lost') ||
        status.contains('خسارة');
  }

  bool get _isWon {
    if (_opportunity == null) return false;
    final stageId = _opportunity!['StageID'] ?? _opportunity!['StageId'] ?? 0;
    return stageId == 3;
  }

  bool get _isClosed {
    if (_opportunity == null) return false;
    final stageId = _opportunity!['StageID'] ?? _opportunity!['StageId'] ?? 0;
    return stageId == 3 || stageId == 4 || stageId == 5;
  }

  // ═══════════════════════════════════
  //  📝 سبب الخسارة
  // ═══════════════════════════════════
  String get _lossReason {
    if (_opportunity == null) return '';
    final reasonName = _opportunity!['LostReasonNameAr'] ??
        _opportunity!['LostReasonName'] ??
        _opportunity!['LostReason'] ??
        '';
    final lostNotes = (_opportunity!['LostNotes'] ?? '').toString().trim();
    String result = reasonName.toString().trim();
    if (result.isNotEmpty && lostNotes.isNotEmpty) {
      result += '\n📝 $lostNotes';
    } else if (result.isEmpty && lostNotes.isNotEmpty) {
      result = lostNotes;
    }
    return result;
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.cairo()),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ═══════════════════════════════════
  //  ✏️ فتح شاشة تعديل الفرصة
  // ═══════════════════════════════════
  void _openEditOpportunity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddOpportunityScreen(
          userId: widget.userId,
          username: widget.username,
          opportunityToEdit: _opportunity,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  // ═══════════════════════════════════
  //  💬 فتح شاشة تسجيل تواصل
  // ═══════════════════════════════════
  void _openAddInteraction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInteractionScreen(
          userId: widget.userId,
          username: widget.username,
          preSelectedPartyId: _opportunity!['PartyID'] ?? _opportunity!['PartyId'],
          preSelectedOpportunityId:
              _opportunity!['OpportunityID'] ?? _opportunity!['OpportunityId'],
        ),
      ),
    );
    if (result == true) _loadData();
  }

  // ═══════════════════════════════════
  //  🛑 طلبات الإغلاق - مطابق بلازور
  // ═══════════════════════════════════
  Future<void> _approveClosure() async {
    if (_pendingClosure == null) return;
    final requestId = _pendingClosure!['RequestID'] ?? _pendingClosure!['RequestId'] ?? 0;
    if (requestId == 0) return;
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.verified_rounded, color: Colors.green, size: 20)),
          const SizedBox(width: 10),
          Text('اعتماد طلب الإغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('سيتم اعتماد الطلب وإرسال إشعار للمندوب لتنفيذ الإغلاق بنفسه',
              style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: 'ملاحظات المراجعة (اختياري)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              style: GoogleFonts.cairo()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(c, true),
              child: Text('اعتماد', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final res = await _oppService.approveClosureRequest(
        requestId: requestId is int ? requestId : int.tryParse('$requestId') ?? 0,
        userName: widget.username,
        actorRole: _perms.role,
        reviewNotes: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
      );
      final ok = res['success'] == true;
      _showSnack(res['message'] ?? (ok ? 'تم الاعتماد وإرسال إشعار للمندوب' : 'فشل'), isError: !ok);
      if (ok) await _loadData();
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rejectClosure() async {
    if (_pendingClosure == null) return;
    final requestId = _pendingClosure!['RequestID'] ?? _pendingClosure!['RequestId'] ?? 0;
    if (requestId == 0) return;
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration:
                  BoxDecoration(color: Colors.red.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 20)),
          const SizedBox(width: 10),
          Text('رفض طلب الإغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('سيتم رفض الطلب وإرسال إشعار للمندوب',
              style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: 'سبب الرفض *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              style: GoogleFonts.cairo()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(c, true),
              child: Text('رفض الطلب', style: GoogleFonts.cairo(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;
    if (ctrl.text.trim().isEmpty) {
      _showSnack('اكتب سبب الرفض', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _oppService.rejectClosureRequest(
        requestId: requestId is int ? requestId : int.tryParse('$requestId') ?? 0,
        userName: widget.username,
        actorRole: _perms.role,
        reviewNotes: ctrl.text.trim(),
      );
      final ok = res['success'] == true;
      _showSnack(res['message'] ?? (ok ? 'تم الرفض' : 'فشل'), isError: !ok);
      if (ok) await _loadData();
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _executeClosure() async {
    if (_opportunity == null) return;
    final oppId = _opportunity!['OpportunityID'] ?? _opportunity!['OpportunityId'] ?? 0;
    if (oppId == 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF2563EB), size: 20)),
          const SizedBox(width: 10),
          Text('تنفيذ الإغلاق المعتمد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
            'تم اعتماد طلبك من الإدارة. سيتم الآن تحويل الفرصة إلى المرحلة المطلوبة وإغلاق جميع المهام المعلقة.',
            style: GoogleFonts.cairo(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(c, true),
              child: Text('تنفيذ الآن', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final res = await _oppService.executeClosure(
        opportunityId: oppId is int ? oppId : int.tryParse('$oppId') ?? 0,
        userName: widget.username,
      );
      final ok = res['success'] == true;
      _showSnack(res['message'] ?? (ok ? 'تم تنفيذ الإغلاق بنجاح' : 'فشل التنفيذ'), isError: !ok);
      if (ok) await _loadData();
    } catch (e) {
      _showSnack('خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stageColor = _hexToColor(_opportunity?['StageColor'] ?? '#DBBF74');

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          backgroundColor: _isLost
              ? (_isDark ? const Color(0xFF3D1515) : Colors.red[700])
              : _isWon
                  ? (_isDark ? const Color(0xFF0F3D1F) : const Color(0xFF15803D))
                  : (_isDark ? AppColors.navy : stageColor),
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isLost
                    ? Icons.cancel_rounded
                    : _isWon
                        ? Icons.emoji_events_rounded
                        : Icons.assignment_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isLost
                    ? 'فرصة خاسرة'
                    : _isWon
                        ? 'فرصة مكتملة'
                        : 'تفاصيل الفرصة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            if (_opportunity != null)
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: _isLost && !_canDirectCloseOpportunity ? null : _openEditOpportunity,
                tooltip: 'تعديل الفرصة',
              ),
          ],
        ),
        body: Stack(
          children: [
            _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.gold))
                : _opportunity == null
                    ? _buildErrorView()
                    : RefreshIndicator(
                        color: AppColors.gold,
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (_isLost) ...[
                                _buildLossBanner(),
                                const SizedBox(height: 16),
                              ],
                              if (_pendingClosure != null) ...[
                                _buildPendingClosureBanner(),
                                const SizedBox(height: 16),
                              ],
                              if (_stages.isNotEmpty) ...[
                                _buildPipeline(),
                                const SizedBox(height: 16),
                              ],
                              _buildStatusHeader(),
                              const SizedBox(height: 16),
                              _buildClientInfo(),
                              const SizedBox(height: 16),
                              _buildOpportunityInfo(),
                              const SizedBox(height: 16),
                              _buildInteractionTimeline(),
                              const SizedBox(height: 16),
                              _buildActionButtons(),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
            if (_busy)
              Container(
                color: Colors.black38,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card(_isDark),
                      borderRadius: BorderRadius.circular(16),
                    ),
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
  //  🟠🟢 بانر طلبات الإغلاق - مطابق بلازور CrmClosureApprovalRequests
  // ═══════════════════════════════════
  Widget _buildPendingClosureBanner() {
    if (_pendingClosure == null) return const SizedBox.shrink();
    final status = '${_pendingClosure!['Status'] ?? 'Pending'}';
    final isPending = status == 'Pending';
    final isApproved = status == 'Approved';
    final isRejected = status == 'Rejected';
    final isExecuted = status == 'Executed';

    Color bannerColor;
    Color bg1, bg2;
    IconData bannerIcon;
    String bannerTitle;
    String bannerSub;

    if (isPending) {
      bannerColor = const Color(0xFFEA580C);
      bg1 = const Color(0xFFFFF7ED);
      bg2 = const Color(0xFFFFEDD5);
      bannerIcon = Icons.hourglass_top_rounded;
      bannerTitle = 'طلب إغلاق معلق بانتظار موافقة الإدارة';
      bannerSub = 'المندوب طلب تحويل الفرصة - بانتظار اعتماد مدير المبيعات أو المدير العام';
    } else if (isApproved) {
      bannerColor = const Color(0xFF16A34A);
      bg1 = const Color(0xFFF0FDF4);
      bg2 = const Color(0xFFDCFCE7);
      bannerIcon = Icons.verified_rounded;
      bannerTitle = 'تم اعتماد طلب الإغلاق - بانتظار تنفيذك';
      bannerSub = 'وافقت الإدارة على الإغلاق - برجاء تنفيذ الإغلاق بنفسك الآن';
    } else if (isRejected) {
      bannerColor = const Color(0xFFDC2626);
      bg1 = const Color(0xFFFEF2F2);
      bg2 = const Color(0xFFFEE2E2);
      bannerIcon = Icons.block_rounded;
      bannerTitle = 'تم رفض طلب الإغلاق';
      bannerSub = 'رفضت الإدارة طلب الإغلاق - راجع ملاحظات المراجعة';
    } else {
      bannerColor = const Color(0xFF2563EB);
      bg1 = const Color(0xFFEFF6FF);
      bg2 = const Color(0xFFDBEAFE);
      bannerIcon = Icons.check_circle_rounded;
      bannerTitle = 'تم تنفيذ الإغلاق';
      bannerSub = 'تم إغلاق الفرصة بعد موافقة الإدارة';
    }

    if (_isDark) {
      bg1 = bannerColor.withOpacity(0.18);
      bg2 = bannerColor.withOpacity(0.10);
    }

    final requestedStageId = _pendingClosure!['RequestedStageID'] ?? _pendingClosure!['RequestedStageId'] ?? 0;
    final currentStageId = _pendingClosure!['CurrentStageID'] ?? _pendingClosure!['CurrentStageId'] ?? 0;
    final currentStageName = _stages.isNotEmpty
        ? (_stages.firstWhere((s) => s['StageID'] == currentStageId, orElse: () => {'StageNameAr': '—'})['StageNameAr'] ?? '—')
        : '—';
    final requestedStageName = _stages.isNotEmpty
        ? (_stages.firstWhere((s) => s['StageID'] == requestedStageId, orElse: () => {'StageNameAr': '—'})['StageNameAr'] ?? '—')
        : (requestedStageId == 3 ? 'تم البيع' : 'خسارة');

    final requestedBy = '${_pendingClosure!['RequestedBy'] ?? ''}';
    final reviewedBy = '${_pendingClosure!['ReviewedBy'] ?? ''}';
    final requestedAt = _pendingClosure!['RequestedAt'];
    final reviewedAt = _pendingClosure!['ReviewedAt'];
    final reasonNotes = '${_pendingClosure!['RequestReasonNotes'] ?? ''}';
    final reviewNotes = '${_pendingClosure!['ReviewNotes'] ?? ''}';
    final lostReason = '${_pendingClosure!['LostReasonName'] ?? _pendingClosure!['ReasonNameAr'] ?? ''}';

    final isRequester = requestedBy.toLowerCase() == widget.username.toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bg1, bg2]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bannerColor.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: bannerColor.withOpacity(_isDark ? 0.22 : 0.12), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bannerColor.withOpacity(_isDark ? 0.28 : 0.15), shape: BoxShape.circle),
            child: Icon(bannerIcon, color: bannerColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bannerTitle,
                  style: GoogleFonts.cairo(
                      fontSize: 14, fontWeight: FontWeight.w900, color: _isDark ? Colors.white : bannerColor)),
              const SizedBox(height: 2),
              Text(bannerSub,
                  style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: _isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: bannerColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: bannerColor.withOpacity(0.28))),
            child: Text(
              status == 'Pending'
                  ? 'معلق'
                  : status == 'Approved'
                      ? 'معتمد'
                      : status == 'Rejected'
                          ? 'مرفوض'
                          : 'تم التنفيذ',
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: bannerColor),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isDark ? Colors.black.withOpacity(0.20) : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bannerColor.withOpacity(0.18)),
          ),
          child: Column(children: [
            _closureInfoRow(Icons.swap_horiz_rounded, 'من مرحلة', currentStageName),
            _closureInfoRow(Icons.flag_rounded, 'إلى مرحلة', requestedStageName, highlight: true, color: bannerColor),
            if (lostReason.isNotEmpty) _closureInfoRow(Icons.info_outline_rounded, 'سبب الخسارة', lostReason, color: Colors.red),
            if (reasonNotes.isNotEmpty) _closureInfoRow(Icons.notes_rounded, 'ملاحظات الطلب', reasonNotes),
            _closureInfoRow(Icons.person_rounded, 'مقدم الطلب', requestedBy),
            _closureInfoRow(Icons.event_rounded, 'تاريخ الطلب', _formatDate(requestedAt)),
            if (reviewedBy.isNotEmpty) _closureInfoRow(Icons.verified_user_rounded, 'راجع بواسطة', '$reviewedBy • ${_formatDate(reviewedAt)}'),
            if (reviewNotes.isNotEmpty) _closureInfoRow(Icons.comment_rounded, 'ملاحظات المراجعة', reviewNotes),
          ]),
        ),
        if (isPending) ...[
          const SizedBox(height: 14),
          if (_canApproveClosure) ...[
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _busy ? null : _approveClosure,
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text('اعتماد وإشعار المندوب', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _busy ? null : _rejectClosure,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text('رفض الطلب', style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ] else if (isRequester) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.hourglass_bottom_rounded, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('طلبك قيد المراجعة لدى مدير المبيعات والمدير العام - سيصلك إشعار عند الاعتماد',
                        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange.shade800))),
              ]),
            ),
          ],
        ],
        if (isApproved) ...[
          const SizedBox(height: 14),
          if (isRequester || _canDirectCloseOpportunity) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _busy ? null : _executeClosure,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text('تنفيذ الإغلاق الآن - إغلاق المهام وتحويل الحالة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(color: Colors.green.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
              child: Text('تم اعتماد الطلب - بانتظار تنفيذ المندوب مقدم الطلب',
                  style: GoogleFonts.cairo(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
        if (isRejected) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_rounded, size: 16, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('تم رفض الطلب - يمكنك تعديل الفرصة أو إعادة الطلب بسبب جديد',
                      style: GoogleFonts.cairo(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _closureInfoRow(IconData icon, String label, String value,
      {bool highlight = false, Color? color}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: (color ?? AppColors.gold).withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color ?? AppColors.gold),
        ),
        const SizedBox(width: 10),
        SizedBox(
            width: 85,
            child: Text('$label:',
                style: GoogleFonts.cairo(
                    fontSize: 11, color: AppColors.textSecondary(_isDark), fontWeight: FontWeight.w700))),
        Expanded(
            child: Text(value,
                style: GoogleFonts.cairo(
                    fontSize: highlight ? 13 : 12.5,
                    fontWeight: highlight ? FontWeight.w900 : FontWeight.w600,
                    color: highlight ? (color ?? AppColors.navy) : AppColors.text(_isDark),
                    height: 1.3))),
      ]),
    );
  }

  // ═══════════════════════════════════
  //  🔵 مراحل البيع Pipeline - مطابق بلازور
  // ═══════════════════════════════════
  Widget _buildPipeline() {
    final sorted = [..._stages]..sort((a, b) => (a['StageOrder'] ?? 0).compareTo(b['StageOrder'] ?? 0));
    final currentId = _opportunity!['StageID'] ?? _opportunity!['StageId'] ?? 0;
    final currentOrder = sorted.firstWhere((s) => s['StageID'] == currentId, orElse: () => {'StageOrder': 0})['StageOrder'] ?? 0;
    final maxOrder = sorted.isEmpty ? 1 : sorted.map((s) => s['StageOrder'] as int? ?? 0).reduce((a, b) => a > b ? a : b);
    final pct = maxOrder > 0 ? currentOrder / maxOrder : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.stairs_rounded, size: 18, color: AppColors.gold)),
          const SizedBox(width: 10),
          Expanded(child: Text('مراحل البيع - التقدم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration:
                  BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('${(pct * 100).toStringAsFixed(0)}% مكتمل',
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gold))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.black.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(AppColors.gold))),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: sorted.map((st) {
            final id = st['StageID'] as int?;
            final isActive = id == currentId;
            final isPast = (st['StageOrder'] ?? 0) < currentOrder;
            final colStr = st['StageColor']?.toString() ?? '#94a3b8';
            Color col;
            try {
              col = Color(int.parse(colStr.replaceAll('#', '0xFF')));
            } catch (_) {
              col = const Color(0xFF94A3B8);
            }
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                    color: isActive
                        ? col
                        : (isPast ? col.withOpacity(0.28) : Colors.black.withOpacity(0.06)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isActive ? col : Colors.transparent, width: 1.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isPast) const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  if (isPast) const SizedBox(width: 4),
                  Text(st['StageNameAr'] ?? st['StageName'] ?? '',
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                          color: isActive || isPast ? Colors.white : AppColors.textSecondary(_isDark))),
                ]),
              ),
            );
          }).toList()),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════
  //  🔴 بانر الخسارة
  // ═══════════════════════════════════
  Widget _buildLossBanner() {
    final reason = _lossReason;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDark
              ? [const Color(0xFF3D1515), const Color(0xFF2A0E0E)]
              : [Colors.red.shade50, Colors.red.shade100],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _isDark ? Colors.red.withOpacity(0.4) : Colors.red.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(_isDark ? 0.2 : 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withOpacity(_isDark ? 0.3 : 0.15), shape: BoxShape.circle),
            child: Icon(Icons.cancel_rounded, color: _isDark ? Colors.red[300] : Colors.red[700], size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تم خسارة هذه الفرصة',
                  style: GoogleFonts.cairo(
                      fontSize: 15, fontWeight: FontWeight.bold, color: _isDark ? Colors.red[300] : Colors.red[800])),
              Text('الفرصة مغلقة ولم تتحول لصفقة',
                  style: GoogleFonts.cairo(
                      fontSize: 11, color: _isDark ? Colors.red[200]?.withOpacity(0.7) : Colors.red[600])),
            ]),
          ),
        ]),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isDark ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 18, color: _isDark ? Colors.red[300] : Colors.red[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('سبب الخسارة:',
                        style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isDark ? Colors.red[300] : Colors.red[800])),
                    const SizedBox(height: 2),
                    ...reason.split('\n').map((line) {
                      final isNote = line.startsWith('📝');
                      return Padding(
                        padding: EdgeInsets.only(top: isNote ? 8 : 0),
                        child: Text(line,
                            style: GoogleFonts.cairo(
                                fontSize: isNote ? 13 : 14,
                                color: _isDark
                                    ? (isNote ? Colors.orange[200] : Colors.red[200])
                                    : (isNote ? Colors.orange[900] : Colors.red[900]),
                                fontWeight: isNote ? FontWeight.normal : FontWeight.w600,
                                height: 1.5)),
                      );
                    }),
                  ]),
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  // ═══════════════════════════════════
  //  🔵 هيدر الحالة
  // ═══════════════════════════════════
  Widget _buildStatusHeader() {
    final stageNameAr = _opportunity!['StageNameAr'] ?? _opportunity!['StageName'] ?? '';
    final stageColor = _hexToColor(_opportunity!['StageColor'] ?? '#3498db');
    final followUpDate = _opportunity!['NextFollowUpDate'];

    String followUpText = 'غير محدد';
    Color followUpColor = AppColors.textHint(_isDark);
    IconData followUpIcon = Icons.remove_circle_outline;

    if (followUpDate != null) {
      try {
        final dt = DateTime.parse(followUpDate.toString());
        final now = DateTime.now();
        final diff = dt.difference(DateTime(now.year, now.month, now.day)).inDays;
        if (diff < 0) {
          followUpText = 'متأخر ${diff.abs()} يوم';
          followUpColor = Colors.red;
          followUpIcon = Icons.warning_amber_rounded;
        } else if (diff == 0) {
          followUpText = 'اليوم';
          followUpColor = Colors.orange;
          followUpIcon = Icons.today_rounded;
        } else if (diff == 1) {
          followUpText = 'غداً';
          followUpColor = Colors.blue;
          followUpIcon = Icons.event_rounded;
        } else {
          followUpText = 'بعد $diff يوم';
          followUpColor = Colors.green;
          followUpIcon = Icons.upcoming_rounded;
        }
      } catch (_) {}
    }

    final headerColor = _isLost
        ? Colors.red
        : _isWon
            ? const Color(0xFF16A34A)
            : stageColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: _isDark ? [AppColors.darkCard, headerColor.withOpacity(0.3)] : [headerColor, headerColor.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(18),
        border: _isDark ? Border.all(color: headerColor.withOpacity(0.4)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.22 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(_isDark ? 0.1 : 0.2), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_isLost ? Icons.cancel_rounded : _isWon ? Icons.emoji_events_rounded : Icons.flag_rounded,
                size: 16, color: _isDark ? headerColor : Colors.white),
            const SizedBox(width: 6),
            Text(stageNameAr,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold, color: _isDark ? headerColor : Colors.white, fontSize: 14)),
          ]),
        ),
        const Spacer(),
        if (!_isLost && !_isWon)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isDark ? followUpColor.withOpacity(0.2) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: _isDark ? Border.all(color: followUpColor.withOpacity(0.4)) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(followUpIcon, size: 14, color: followUpColor),
              const SizedBox(width: 4),
              Text(followUpText,
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: followUpColor)),
            ]),
          ),
        if (_isWon)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
              const SizedBox(width: 4),
              Text('مكتملة - تم البيع',
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
            ]),
          ),
      ]),
    );
  }

  // ═══════════════════════════════════
  //  👤 بيانات العميل
  // ═══════════════════════════════════
  Widget _buildClientInfo() {
    final clientName = _opportunity!['ClientName'] ?? _opportunity!['PartyName'] ?? 'بدون اسم';
    final phone1 = _opportunity!['Phone1'] ?? _opportunity!['Phone'] ?? '';
    final phone2 = _opportunity!['Phone2'] ?? '';
    final address = _opportunity!['Address'] ?? '';
    final email = _opportunity!['Email'] ?? '';

    return _buildSection(
      icon: Icons.person_rounded,
      title: 'بيانات العميل',
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _isDark ? [AppColors.gold.withOpacity(0.10), AppColors.gold.withOpacity(0.05)] : [AppColors.gold.withOpacity(0.08), AppColors.gold.withOpacity(0.03)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withOpacity(0.2)),
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: AppColors.gold.withOpacity(0.25))),
              child: Center(
                  child: Text(clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                      style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.gold))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(clientName,
                    style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.text(_isDark))),
                if (phone1.isNotEmpty)
                  Text(phone1,
                      style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary(_isDark))),
              ]),
            ),
            if (phone1.isNotEmpty) ...[
              _buildMiniAction(Icons.phone_rounded, const Color(0xFF27AE60), () => _makeCall(phone1)),
              const SizedBox(width: 8),
              _buildMiniAction(FontAwesomeIcons.whatsapp, const Color(0xFF25D366), () => _openWhatsApp(phone1)),
            ],
          ]),
        ),
        if (phone2.isNotEmpty)
          _buildContactRow(
            icon: Icons.phone_android_rounded,
            text: 'هاتف 2: $phone2',
            actions: [
              _buildMiniAction(Icons.phone_rounded, const Color(0xFF27AE60), () => _makeCall(phone2)),
              const SizedBox(width: 8),
              _buildMiniAction(FontAwesomeIcons.whatsapp, const Color(0xFF25D366), () => _openWhatsApp(phone2)),
            ],
          ),
        if (address.isNotEmpty) _buildInfoRow(Icons.location_on_rounded, 'العنوان: $address'),
        if (email.isNotEmpty) _buildInfoRow(Icons.email_rounded, 'البريد: $email'),
      ],
    );
  }

  // ═══════════════════════════════════
  //  📊 بيانات الفرصة
  // ═══════════════════════════════════
  Widget _buildOpportunityInfo() {
    final sourceName = _opportunity!['SourceNameAr'] ?? _opportunity!['SourceName'] ?? '';
    final adTypeName = _opportunity!['AdTypeNameAr'] ?? _opportunity!['AdTypeName'] ?? '';
    final categoryName = _opportunity!['CategoryNameAr'] ?? _opportunity!['CategoryName'] ?? '';
    final employeeName = _opportunity!['EmployeeName'] ?? '';
    final expectedValue = (_opportunity!['ExpectedValue'] ?? 0).toDouble();
    final interestedProduct = _opportunity!['InterestedProduct'] ?? '';
    final location = _opportunity!['Location'] ?? '';
    final notes = _opportunity!['Notes'] ?? '';
    final guidance = _opportunity!['Guidance'] ?? '';
    final firstContact = _opportunity!['FirstContactDate'];
    final lastContact = _opportunity!['LastContactDate'];
    final nextFollowUp = _opportunity!['NextFollowUpDate'];
    final closedAt = _opportunity!['ClosedAt'];
    final closedBy = _opportunity!['ClosedBy'] ?? '';

    return _buildSection(
      icon: Icons.analytics_rounded,
      title: 'بيانات الفرصة',
      children: [
        if (employeeName.isNotEmpty) _buildInfoRow(Icons.person_outline_rounded, 'المسؤول: $employeeName'),
        if (sourceName.isNotEmpty) _buildInfoRow(Icons.source_rounded, 'المصدر: $sourceName'),
        if (adTypeName.isNotEmpty) _buildInfoRow(Icons.campaign_rounded, 'الإعلان: $adTypeName'),
        if (categoryName.isNotEmpty) _buildInfoRow(Icons.category_rounded, 'الفئة: $categoryName'),
        if (expectedValue > 0)
          _buildInfoRow(Icons.payments_rounded,
              'القيمة المتوقعة: ${NumberFormat('#,###').format(expectedValue)} ج.م'),
        if (interestedProduct.isNotEmpty) _buildInfoRow(Icons.shopping_bag_rounded, 'المنتج: $interestedProduct'),
        if (location.isNotEmpty) _buildInfoRow(Icons.location_on_rounded, 'الموقع: $location'),
        if (firstContact != null) _buildInfoRow(Icons.event_rounded, 'أول تواصل: ${_formatDate(firstContact)}'),
        if (lastContact != null) _buildInfoRow(Icons.event_available_rounded, 'آخر تواصل: ${_formatDate(lastContact)}'),
        if (nextFollowUp != null && !_isClosed) _buildInfoRow(Icons.event_note_rounded, 'المتابعة القادمة: ${_formatDate(nextFollowUp)}'),
        if (closedAt != null) _buildInfoRow(Icons.lock_rounded, 'تاريخ الإغلاق: ${_formatDate(closedAt)} بواسطة $closedBy'),
        if (notes.isNotEmpty) _buildInfoRow(Icons.notes_rounded, 'ملاحظات: $notes'),
        if (guidance.isNotEmpty) _buildInfoRow(Icons.lightbulb_rounded, 'توجيهات: $guidance'),
      ],
    );
  }

  // ═══════════════════════════════════
  //  💬 سجل التواصل
  // ═══════════════════════════════════
  Widget _buildInteractionTimeline() {
    return _buildSection(
      icon: Icons.timeline_rounded,
      title: 'سجل التواصل (${_interactions.length})',
      children: [
        if (_interactions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textHint(_isDark)),
                const SizedBox(height: 8),
                Text('لا يوجد سجل تواصل بعد', style: GoogleFonts.cairo(color: AppColors.textHint(_isDark))),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openAddInteraction,
                  icon: Icon(Icons.add_rounded, color: AppColors.gold),
                  label: Text('سجل أول تواصل', style: GoogleFonts.cairo(color: AppColors.gold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.gold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ]),
            ),
          )
        else
          ...List.generate(_interactions.length, (index) {
            final interaction = _interactions[index];
            final isLast = index == _interactions.length - 1;
            return _buildTimelineItem(interaction, isLast);
          }),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> interaction, bool isLast) {
    final date = interaction['InteractionDate'];
    final employeeName = interaction['EmployeeName'] ?? interaction['CreatedBy'] ?? '';
    final summary = interaction['Summary'] ?? '';
    final notes = interaction['Notes'] ?? '';
    final stageBefore = interaction['StageBefore'] ?? interaction['StageBeforeName'] ?? '';
    final stageAfter = interaction['StageAfter'] ?? interaction['StageAfterName'] ?? '';
    final statusName = interaction['StatusNameAr'] ?? interaction['StatusName'] ?? '';
    final sourceIcon = interaction['SourceIcon'] ?? '📞';

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 30,
          child: Column(children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 3),
              ),
            ),
            if (!isLast) Expanded(child: Container(width: 2, color: AppColors.divider(_isDark))),
          ]),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.inputFill(_isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider(_isDark)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(sourceIcon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(_formatDate(date),
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gold),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(employeeName,
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary(_isDark)),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              if (statusName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(statusName, style: GoogleFonts.cairo(fontSize: 10, color: AppColors.gold)),
                  ),
                ),
              if (stageBefore.isNotEmpty && stageAfter.isNotEmpty && stageBefore != stageAfter)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(_isDark ? 0.15 : 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.swap_horiz_rounded, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('$stageBefore ← $stageAfter',
                            style: GoogleFonts.cairo(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                ),
              if (summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(summary, style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text(_isDark))),
                ),
              if (notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.lightbulb_rounded, size: 14, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Expanded(child: Text(notes, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary(_isDark)))),
                  ]),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════
  //  🔘 أزرار الأكشن
  // ═══════════════════════════════════
  Widget _buildActionButtons() {
    final phone = _opportunity?['Phone1'] ?? _opportunity?['Phone'] ?? '';
    // ✅ مطابق بلازور: تم البيع (3) يقدر أي موظف يقفله مباشر، الخسارة فقط (4,5) تحتاج موافقة
    // المرجع: CrmStages.IsExitStage = 4,5 فقط + OpportunityService.MoveStageAsync
    final canEdit = !_isLost || _canDirectCloseOpportunity;
    return Column(children: [
      Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: AppColors.buttonGradient(_isDark)), borderRadius: BorderRadius.circular(12)),
            child: ElevatedButton.icon(
              onPressed: canEdit ? _openAddInteraction : null,
              icon: const Icon(Icons.add_comment_rounded, size: 20),
              label: Text('تسجيل تواصل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: _isDark ? AppColors.navy : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canEdit ? _openEditOpportunity : null,
            icon: Icon(Icons.edit_rounded, size: 20, color: canEdit ? AppColors.gold : Colors.grey),
            label: Text('تعديل الفرصة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: canEdit ? AppColors.gold : Colors.grey)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: canEdit ? AppColors.gold : Colors.grey),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60).withOpacity(_isDark ? 0.2 : 1),
              borderRadius: BorderRadius.circular(12),
              border: _isDark ? Border.all(color: const Color(0xFF27AE60).withOpacity(0.4)) : null,
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                if (phone.isNotEmpty) _makeCall(phone);
              },
              icon: Icon(Icons.phone_rounded, color: _isDark ? const Color(0xFF27AE60) : Colors.white, size: 20),
              label: Text('اتصال',
                  style: GoogleFonts.cairo(
                      color: _isDark ? const Color(0xFF27AE60) : Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(_isDark ? 0.2 : 1),
              borderRadius: BorderRadius.circular(12),
              border: _isDark ? Border.all(color: const Color(0xFF25D366).withOpacity(0.4)) : null,
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                if (phone.isNotEmpty) _openWhatsApp(phone);
              },
              icon: FaIcon(FontAwesomeIcons.whatsapp,
                  color: _isDark ? const Color(0xFF25D366) : Colors.white, size: 20),
              label: Text('واتساب',
                  style: GoogleFonts.cairo(
                      color: _isDark ? const Color(0xFF25D366) : Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ]),
      if (_isLost && !_canDirectCloseOpportunity) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.lock_rounded, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
                child: Text('الفرصة خاسرة (4,5) - التعديل متاح فقط لـ Admin و مدير المبيعات والمدير العام. تم البيع (3) يمكن لأي موظف تعديله.',
                    style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade700))),
          ]),
        ),
      ],
      if (_isWon) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 6),
            Expanded(
                child: Text('تم البيع (3) - يمكن لأي موظف إغلاقه مباشر بدون موافقة. الخسارة فقط (4,5) تحتاج موافقة.',
                    style: GoogleFonts.cairo(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600))),
          ]),
        ),
      ],
    ]);
  }

  // ═══════════════════════════════════
  //  🔧 Widgets مشتركة
  // ═══════════════════════════════════
  Widget _buildSection({required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.20 : 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.gold, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text(_isDark)))),
          Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4))),
        ]),
        const SizedBox(height: 12),
        Divider(height: 1, color: Colors.black.withOpacity(0.06)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _buildContactRow({required IconData icon, required String text, required List<Widget> actions}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.textSecondary(_isDark).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: AppColors.textSecondary(_isDark))),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text(_isDark), fontWeight: FontWeight.w600))),
        ...actions,
      ]),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: AppColors.textSecondary(_isDark).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: AppColors.textSecondary(_isDark))),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text(_isDark), height: 1.4))),
      ]),
    );
  }

  Widget _buildMiniAction(dynamic icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(_isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Center(child: compatIcon(icon, size: 16, color: color)),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: AppColors.textHint(_isDark).withOpacity(0.10), shape: BoxShape.circle),
            child: Icon(Icons.error_outline_rounded, size: 40, color: AppColors.textHint(_isDark))),
        const SizedBox(height: 16),
        Text('فشل تحميل البيانات', style: GoogleFonts.cairo(fontSize: 16, color: AppColors.textSecondary(_isDark), fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('تأكد من الاتصال وحاول مرة أخرى', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textHint(_isDark))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    try {
      final dt = date is DateTime ? date : DateTime.tryParse(date.toString());
      if (dt == null) return '$date';
      return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
    } catch (_) {
      return '$date';
    }
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    String formattedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedPhone.startsWith('0')) formattedPhone = '2$formattedPhone';
    final uri = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF94A3B8);
    }
  }
}
