import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/opportunities_service.dart';
import '../services/permission_service.dart';
import 'opportunity_detail_screen.dart';

/// شاشة طلبات موافقة إغلاق الفرص - مطابقة 100% لـ Blazor CrmClosureApprovalRequests.razor
/// للـ GeneralManager و SalesManager و Admin فقط
class ClosureApprovalRequestsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ClosureApprovalRequestsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ClosureApprovalRequestsScreen> createState() => _ClosureApprovalRequestsScreenState();
}

class _ClosureApprovalRequestsScreenState extends State<ClosureApprovalRequestsScreen> {
  bool _loading = true;
  bool _busy = false;
  String _filter = 'Pending'; // all | Pending | Approved | Rejected | Executed
  List<dynamic> _requests = [];
  final _oppService = OpportunitiesService();
  final _perms = PermissionService();

  bool get _isDark => ThemeService().isDarkMode;
  bool get _canApprove => _perms.isAdmin || _perms.isSalesManager || _perms.isGeneralManager;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _oppService.getClosureRequests(status: _filter == 'all' ? null : _filter);
      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(int requestId) async {
    setState(() => _busy = true);
    final res = await _oppService.approveClosureRequest(requestId: requestId, userName: widget.username, actorRole: _perms.role);
    setState(() => _busy = false);
    if (!mounted) return;
    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? (ok ? 'تم الاعتماد' : 'فشل'), style: GoogleFonts.cairo()), backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700, behavior: SnackBarBehavior.floating));
    if (ok) _load();
  }

  Future<void> _reject(int requestId) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text('رفض طلب الإغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      content: TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(labelText: 'ملاحظات الرفض', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), style: GoogleFonts.cairo()),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: GoogleFonts.cairo())), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: Text('رفض الطلب', style: GoogleFonts.cairo(color: Colors.white)))],
    ));
    if (confirm != true) return;
    setState(() => _busy = true);
    final res = await _oppService.rejectClosureRequest(requestId: requestId, userName: widget.username, actorRole: _perms.role, reviewNotes: ctrl.text.trim());
    setState(() => _busy = false);
    if (!mounted) return;
    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? (ok ? 'تم الرفض' : 'فشل'), style: GoogleFonts.cairo()), backgroundColor: ok ? Colors.orange.shade700 : Colors.red.shade700, behavior: SnackBarBehavior.floating));
    if (ok) _load();
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    try {
      final dt = DateTime.tryParse(v.toString());
      if (dt == null) return '$v';
      return DateFormat('yyyy/MM/dd HH:mm').format(dt.toLocal());
    } catch (_) {
      return '$v';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Pending': return Colors.orange;
      case 'Approved': return Colors.green;
      case 'Rejected': return Colors.red;
      case 'Executed': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _statusText(String s) {
    switch (s) {
      case 'Pending': return 'معلق';
      case 'Approved': return 'معتمد - بانتظار التنفيذ';
      case 'Rejected': return 'مرفوض';
      case 'Executed': return 'تم التنفيذ';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          title: Text('طلبات موافقة إغلاق الفرص', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _load)],
        ),
        body: Stack(children: [
          Column(children: [
            // Filter chips
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.card(_isDark),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _filterChip('Pending', 'معلق', Colors.orange),
                _filterChip('Approved', 'معتمد', Colors.green),
                _filterChip('Rejected', 'مرفوض', Colors.red),
                _filterChip('Executed', 'تم التنفيذ', Colors.blue),
                _filterChip('all', 'الكل', Colors.grey),
              ])),
            ),
            // Summary
            if (!_loading && _requests.isNotEmpty)
              Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                _summaryChip('معلق', _requests.where((r) => r['Status'] == 'Pending').length, Colors.orange),
                const SizedBox(width: 8),
                _summaryChip('معتمد', _requests.where((r) => r['Status'] == 'Approved').length, Colors.green),
                const SizedBox(width: 8),
                _summaryChip('مرفوض', _requests.where((r) => r['Status'] == 'Rejected').length, Colors.red),
              ])),
            Expanded(child: _loading ? Center(child: CircularProgressIndicator(color: AppColors.gold)) : _requests.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade400), const SizedBox(height: 12), Text('لا توجد طلبات', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)), Text('الفلتر الحالي: ${_statusText(_filter)}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600))])) : RefreshIndicator(color: AppColors.gold, onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.fromLTRB(12, 4, 12, 20), itemCount: _requests.length, itemBuilder: (_, i) => _buildRequestCard(_requests[i])))),
          ]),
          if (_busy) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ]),
      ),
    );
  }

  Widget _filterChip(String key, String label, Color c) {
    final sel = _filter == key;
    return Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.w600, color: sel ? Colors.white : c)), selected: sel, selectedColor: c, backgroundColor: c.withOpacity(0.12), onSelected: (_) { setState(() => _filter = key); _load(); }));
  }

  Widget _summaryChip(String label, int count, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.3))), child: Text('$label: $count', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: c)));

  Widget _buildRequestCard(dynamic raw) {
    final r = Map<String, dynamic>.from(raw as Map);
    final status = '${r['Status'] ?? 'Pending'}';
    final color = _statusColor(status);
    final isPending = status == 'Pending';
    final oppId = r['OpportunityID'] ?? r['OpportunityId'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.25)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(16), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () {
        if (oppId != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => OpportunityDetailScreen(opportunityId: oppId is int ? oppId : int.tryParse('$oppId') ?? 0, userId: widget.userId, username: widget.username))).then((_) => _load());
        }
      }, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(status == 'Pending' ? Icons.hourglass_top_rounded : (status == 'Approved' ? Icons.verified_rounded : Icons.cancel_rounded), color: color)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['ClientName'] ?? 'عميل'}', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
            Text('فرصة #${r['OpportunityID']} - ${r['CurrentStageName'] ?? ''} → ${r['RequestedStageName'] ?? ''}', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary(_isDark))),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(_statusText(status), style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
        ]),
        const SizedBox(height: 10),
        if (r['LostReasonName'] != null) _infoRow(Icons.info_outline_rounded, 'سبب الخسارة', '${r['LostReasonName']}'),
        if (r['RequestReasonNotes'] != null && '${r['RequestReasonNotes']}'.trim().isNotEmpty) _infoRow(Icons.notes_rounded, 'ملاحظات', '${r['RequestReasonNotes']}'),
        _infoRow(Icons.person_rounded, 'طلب بواسطة', '${r['RequestedBy'] ?? ''}'),
        _infoRow(Icons.event_rounded, 'تاريخ الطلب', _fmtDate(r['RequestedAt'])),
        if (r['ReviewedBy'] != null) _infoRow(Icons.verified_user_rounded, 'راجع بواسطة', '${r['ReviewedBy']} - ${_fmtDate(r['ReviewedAt'])}'),
        if (r['ReviewNotes'] != null && '${r['ReviewNotes']}'.trim().isNotEmpty) _infoRow(Icons.comment_rounded, 'ملاحظات المراجعة', '${r['ReviewNotes']}'),
        if (isPending && _canApprove) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _busy ? null : () => _approve(r['RequestID'] ?? r['RequestId'] ?? 0), icon: const Icon(Icons.check_rounded, size: 18), label: Text('اعتماد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _busy ? null : () => _reject(r['RequestID'] ?? r['RequestId'] ?? 0), icon: const Icon(Icons.close_rounded, size: 18), label: Text('رفض', style: GoogleFonts.cairo()))),
          ]),
        ],
      ])))),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: AppColors.textSecondary(_isDark)),
      const SizedBox(width: 6),
      SizedBox(width: 90, child: Text('$label:', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary(_isDark), fontWeight: FontWeight.w700))),
      Expanded(child: Text(value, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600))),
    ]));
  }
}
