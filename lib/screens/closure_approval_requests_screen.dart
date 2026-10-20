import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/opportunities_service.dart';
import '../services/permission_service.dart';
import 'opportunity_detail_screen.dart';

/// شاشة طلبات موافقة إغلاق الفرص - مطابقة 100% لـ Blazor CrmClosureApprovalRequests.razor
/// للـ GeneralManager و SalesManager و Admin فقط
/// تفتح من: قائمة الفرص → زر طلبات الإغلاق (يظهر للمدير فقط) + من الإشعارات
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
      // نستخدم getPendingClosureRequests للـ pending، و getClosureRequests للباقي لو موجود
      List<dynamic> list;
      if (_filter == 'Pending') {
        list = await _oppService.getPendingClosureRequests();
      } else {
        list = await _oppService.getClosureRequests(status: _filter == 'all' ? null : _filter);
      }
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? (ok ? 'تم الاعتماد وإرسال إشعار للمندوب' : 'فشل'), style: GoogleFonts.cairo()),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    if (ok) _load();
  }

  Future<void> _reject(int requestId) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('رفض طلب الإغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('سيتم رفض الطلب وإرسال إشعار للمندوب', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(labelText: 'ملاحظات الرفض (اختياري)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), style: GoogleFonts.cairo()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(c, true), child: Text('رفض الطلب', style: GoogleFonts.cairo(color: Colors.white))),
        ],
      ),
    );
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
      case 'Pending': return const Color(0xFFEA580C);
      case 'Approved': return const Color(0xFF16A34A);
      case 'Rejected': return const Color(0xFFDC2626);
      case 'Executed': return const Color(0xFF2563EB);
      default: return Colors.grey;
    }
  }

  String _statusText(String s) {
    switch (s) {
      case 'Pending': return 'معلق بانتظارك';
      case 'Approved': return 'معتمد - بانتظار التنفيذ';
      case 'Rejected': return 'مرفوض';
      case 'Executed': return 'تم التنفيذ';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          title: Text('طلبات موافقة إغلاق الفرص', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _load)],
        ),
        body: Stack(children: [
          Column(children: [
            // Header info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.navy, const Color(0xFF1E3A5F)]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('مركز موافقات الإغلاق', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('طلبات تحويل الفرص إلى خسارة أو تم البيع - للـ GM و SalesManager فقط', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11)),
                  ])),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _summaryChipPro('معلق', _requests.where((r) => (r['Status'] ?? '') == 'Pending').length, Colors.orange),
                  const SizedBox(width: 8),
                  _summaryChipPro('معتمد', _requests.where((r) => (r['Status'] ?? '') == 'Approved').length, Colors.green),
                  const SizedBox(width: 8),
                  _summaryChipPro('مرفوض', _requests.where((r) => (r['Status'] ?? '') == 'Rejected').length, Colors.red),
                  const SizedBox(width: 8),
                  _summaryChipPro('تم', _requests.where((r) => (r['Status'] ?? '') == 'Executed').length, Colors.blue),
                ]),
              ]),
            ),
            // Filters
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: AppColors.card(_isDark),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _filterChipPro('Pending', 'معلق بانتظارك', Colors.orange),
                _filterChipPro('Approved', 'معتمد', Colors.green),
                _filterChipPro('Rejected', 'مرفوض', Colors.red),
                _filterChipPro('Executed', 'تم التنفيذ', Colors.blue),
                _filterChipPro('all', 'الكل', Colors.grey),
              ])),
            ),
            Expanded(child: _loading ? Center(child: CircularProgressIndicator(color: AppColors.gold)) : _requests.isEmpty ? _emptyPro() : RefreshIndicator(color: AppColors.gold, onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.fromLTRB(12, 8, 12, 20), itemCount: _requests.length, itemBuilder: (_, i) => _buildRequestCardPro(_requests[i])))),
          ]),
          if (_busy) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ]),
      ),
    );
  }

  Widget _filterChipPro(String key, String label, Color c) {
    final sel = _filter == key;
    return Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.w600, color: sel ? Colors.white : c)), selected: sel, selectedColor: c, backgroundColor: c.withOpacity(0.12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), onSelected: (_) { setState(() => _filter = key); _load(); }));
  }

  Widget _summaryChipPro(String label, int count, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.15))), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 6), Text('$label: $count', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))]));

  Widget _emptyPro() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.inbox_rounded, size: 40, color: AppColors.gold)),
    const SizedBox(height: 16),
    Text('لا توجد طلبات إغلاق', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    Text('الفلتر الحالي: ${_statusText(_filter)}\nعندما يطلب مندوب تحويل فرصة لخسارة/بيع، سيظهر هنا مع إشعار', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
  ])));

  Widget _buildRequestCardPro(dynamic raw) {
    final r = Map<String, dynamic>.from(raw as Map);
    final status = '${r['Status'] ?? 'Pending'}';
    final color = _statusColor(status);
    final isPending = status == 'Pending';
    final oppId = r['OpportunityID'] ?? r['OpportunityId'];
    final clientName = '${r['ClientName'] ?? 'عميل'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.22)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(18), child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () {
        if (oppId != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => OpportunityDetailScreen(opportunityId: oppId is int ? oppId : int.tryParse('$oppId') ?? 0, userId: widget.userId, username: widget.username))).then((_) => _load());
        }
      }, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.25))), child: Icon(isPending ? Icons.hourglass_top_rounded : (status == 'Approved' ? Icons.verified_rounded : Icons.cancel_rounded), color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(clientName, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 2),
            Text('فرصة #${r['OpportunityID']} • ${r['CurrentStageName'] ?? ''} → ${r['RequestedStageName'] ?? ''}', style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textSecondary(_isDark), fontWeight: FontWeight.w600)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.30))), child: Text(_statusText(status), style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
        ]),
        const SizedBox(height: 12),
        Divider(height: 1, color: Colors.black.withOpacity(0.06)),
        const SizedBox(height: 12),
        _infoRowPro(Icons.category_rounded, 'المرحلة المطلوبة', '${r['RequestedStageName'] ?? ''}', color: color),
        if (r['LostReasonName'] != null) _infoRowPro(Icons.info_outline_rounded, 'سبب الخسارة', '${r['LostReasonName']}', color: Colors.red),
        if (r['RequestReasonNotes'] != null && '${r['RequestReasonNotes']}'.trim().isNotEmpty) _infoRowPro(Icons.notes_rounded, 'ملاحظات الطلب', '${r['RequestReasonNotes']}'),
        _infoRowPro(Icons.person_rounded, 'طلب بواسطة', '${r['RequestedBy'] ?? ''}'),
        _infoRowPro(Icons.event_rounded, 'تاريخ الطلب', _fmtDate(r['RequestedAt'])),
        if (r['ReviewedBy'] != null) _infoRowPro(Icons.verified_user_rounded, 'راجع بواسطة', '${r['ReviewedBy']} • ${_fmtDate(r['ReviewedAt'])}'),
        if (r['ReviewNotes'] != null && '${r['ReviewNotes']}'.trim().isNotEmpty) _infoRowPro(Icons.comment_rounded, 'ملاحظات المراجعة', '${r['ReviewNotes']}'),
        if (isPending && _canApprove) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _busy ? null : () => _approve(r['RequestID'] ?? r['RequestId'] ?? 0), icon: const Icon(Icons.check_circle_rounded, size: 18), label: Text('اعتماد وإشعار المندوب', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _busy ? null : () => _reject(r['RequestID'] ?? r['RequestId'] ?? 0), icon: const Icon(Icons.close_rounded, size: 18), label: Text('رفض الطلب', style: GoogleFonts.cairo(fontSize: 12)))) ,
          ]),
        ],
        const SizedBox(height: 6),
        Row(children: [Icon(Icons.open_in_new_rounded, size: 12, color: Colors.grey), const SizedBox(width: 4), Text('اضغط لفتح تفاصيل الفرصة وتنفيذ الإغلاق بعد الاعتماد', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey))]),
      ])))),
    );
  }

  Widget _infoRowPro(IconData icon, String label, String value, {Color? color}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: (color ?? AppColors.gold).withOpacity(0.10), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: color ?? AppColors.gold)),
      const SizedBox(width: 10),
      SizedBox(width: 90, child: Text('$label:', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary(_isDark), fontWeight: FontWeight.w700))),
      Expanded(child: Text(value, style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3))),
    ]));
  }
}
