import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/leads_service.dart';
import '../services/opportunities_service.dart';
import '../services/permission_service.dart';
import 'opportunity_detail_screen.dart';

/// Lead details — Blazor LeadDetailsV2 workflow parity
class LeadDetailScreen extends StatefulWidget {
  final int leadId;
  final int userId;
  final String username;

  const LeadDetailScreen({
    super.key,
    required this.leadId,
    required this.userId,
    required this.username,
  });

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _lead;
  Map<String, dynamic>? _pendingReject;
  List<dynamic> _interactions = [];
  List<dynamic> _employees = [];
  List<dynamic> _sources = [];
  List<dynamic> _categories = [];
  List<dynamic> _taskTypes = [];
  List<dynamic> _adTypes = [];
  final _oppService = OpportunitiesService();

  final _perms = PermissionService();
  bool get _canEdit =>
      _perms.canEdit('frm_LeadsCRM') ||
      _perms.isAdmin ||
      _perms.isSalesManager ||
      _perms.isSales ||
      _perms.isGeneralManager;

  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        LeadsService.getLeadById(widget.leadId),
        LeadsService.getInteractions(widget.leadId),
        LeadsService.getEmployees(),
        LeadsService.getPendingReject(widget.leadId),
        _sources.isEmpty ? _oppService.getSources() : Future.value(_sources),
        _categories.isEmpty ? _oppService.getCategories() : Future.value(_categories),
        _taskTypes.isEmpty ? _oppService.getTaskTypes() : Future.value(_taskTypes),
        _adTypes.isEmpty ? _oppService.getAdTypes() : Future.value(_adTypes),
      ]);
      if (!mounted) return;
      setState(() {
        _lead = results[0] as Map<String, dynamic>?;
        _interactions = results[1] as List<dynamic>;
        _employees = results[2] as List<dynamic>;
        _pendingReject = results[3] as Map<String, dynamic>?;
        _sources = List<dynamic>.from(results[4] as List? ?? const []);
        _categories = List<dynamic>.from(results[5] as List? ?? const []);
        _taskTypes = List<dynamic>.from(results[6] as List? ?? const []);
        _adTypes = List<dynamic>.from(results[7] as List? ?? const []);
        _loading = false;
        if (_lead == null) _error = 'الـ Lead غير موجود';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'فشل تحميل البيانات';
      });
    }
  }

  String get _status => '${_lead?['LeadStatus'] ?? LeadsService.statusNew}';
  bool get _locked => LeadsService.isLocked(_lead);
  bool get _canConvert => _canEdit && LeadsService.canConvert(_lead);

  Color _statusColor(String s) {
    switch (s) {
      case LeadsService.statusNew:
        return const Color(0xFF3B82F6);
      case LeadsService.statusAssigned:
        return const Color(0xFF8B5CF6);
      case LeadsService.statusContacted:
        return const Color(0xFFF59E0B);
      case LeadsService.statusConverted:
        return const Color(0xFF22C55E);
      case LeadsService.statusRejected:
        return const Color(0xFFEF4444);
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case LeadsService.statusNew:
        return Icons.fiber_new_rounded;
      case LeadsService.statusAssigned:
        return Icons.assignment_ind_rounded;
      case LeadsService.statusContacted:
        return Icons.phone_callback_rounded;
      case LeadsService.statusConverted:
        return Icons.check_circle_rounded;
      case LeadsService.statusRejected:
        return Icons.cancel_rounded;
      default:
        return Icons.circle;
    }
  }

  Future<void> _launchTel(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    var p = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (p.startsWith('00')) p = p.substring(2);
    if (p.startsWith('0')) p = '20${p.substring(1)}';
    final uri = Uri.parse('https://wa.me/$p');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _quickStatus(String status, {String? rejectedReason}) async {
    if (_busy || _locked || !_canEdit) return;
    setState(() => _busy = true);
    final res = await LeadsService.updateLead(
      leadId: widget.leadId,
      userName: widget.username,
      leadStatus: status,
      rejectedReason: rejectedReason,
      feedback: status == LeadsService.statusContacted
          ? 'تم التواصل من تطبيق الموبايل'
          : null,
      actorRole: _perms.role,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    final ok = res['success'] == true;
    _toast(ok ? (res['message'] ?? 'تم التحديث') : (res['message'] ?? 'فشل'),
        ok: ok);
    if (ok) await _loadAll();
  }

  Future<void> _saveNotes(String notes) async {
    setState(() => _busy = true);
    final res = await LeadsService.updateLead(
      leadId: widget.leadId,
      userName: widget.username,
      notes: notes,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    final ok = res['success'] == true;
    _toast(ok ? 'تم حفظ الملاحظات' : (res['message'] ?? 'فشل الحفظ'), ok: ok);
    if (ok) await _loadAll();
  }

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo()),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════
  Future<void> _openInteractionSheet() async {
    if (!_canEdit || _locked) return;
    String type = LeadsService.typeCall;
    String? newStatus;
    final summaryCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final rejectCtrl = TextEditingController();
    DateTime? followUp;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(_isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('تسجيل تواصل',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('نوع التواصل', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: LeadsService.interactionTypes
                          .where((t) => t != LeadsService.typeConverted)
                          .map((t) {
                        final sel = type == t;
                        return ChoiceChip(
                          label: Text(t, style: GoogleFonts.cairo(fontSize: 12)),
                          selected: sel,
                          onSelected: (_) => setModal(() => type = t),
                          selectedColor: AppColors.gold.withOpacity(0.35),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: summaryCtrl,
                      decoration: _inputDeco('ملخص سريع'),
                      style: GoogleFonts.cairo(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: _inputDeco('تفاصيل / ملاحظات'),
                      style: GoogleFonts.cairo(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: newStatus,
                      decoration: _inputDeco('تحديث الحالة (اختياري)'),
                      items: [
                        DropdownMenuItem(
                            value: null,
                            child: Text('تلقائي حسب نوع التواصل',
                                style: GoogleFonts.cairo(fontSize: 13))),
                        DropdownMenuItem(
                            value: LeadsService.statusContacted,
                            child: Text(LeadsService.statusContacted,
                                style: GoogleFonts.cairo())),
                        DropdownMenuItem(
                            value: LeadsService.statusRejected,
                            child: Text(LeadsService.statusRejected,
                                style: GoogleFonts.cairo())),
                      ],
                      onChanged: (v) => setModal(() => newStatus = v),
                    ),
                    if (newStatus == LeadsService.statusRejected) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: rejectCtrl,
                        decoration: _inputDeco('سبب الرفض *'),
                        style: GoogleFonts.cairo(),
                      ),
                    ],
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event),
                      title: Text(
                        followUp == null
                            ? 'موعد متابعة (اختياري)'
                            : DateFormat('yyyy/MM/dd HH:mm').format(followUp!),
                        style: GoogleFonts.cairo(fontSize: 13),
                      ),
                      trailing: followUp != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setModal(() => followUp = null),
                            )
                          : null,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (d == null) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        setModal(() {
                          followUp = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t?.hour ?? 10,
                            t?.minute ?? 0,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لو لم تُختر حالة: الاتصال / واتساب / متابعة / ملاحظة يحوّلون الحالة إلى «تم التواصل» تلقائيًا.',
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textSecondary(_isDark)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('إلغاء', style: GoogleFonts.cairo()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              if (newStatus == LeadsService.statusRejected &&
                                  rejectCtrl.text.trim().isEmpty) {
                                return;
                              }
                              Navigator.pop(ctx, true);
                            },
                            child: Text('حفظ', style: GoogleFonts.cairo()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;
    setState(() => _busy = true);
    final res = await LeadsService.addInteraction(
      leadId: widget.leadId,
      userName: widget.username,
      interactionType: type,
      summary: summaryCtrl.text.trim().isEmpty ? null : summaryCtrl.text.trim(),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      newLeadStatus: newStatus,
      rejectedReason: rejectCtrl.text.trim().isEmpty
          ? null
          : rejectCtrl.text.trim(),
      nextFollowUpDate: followUp,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    final ok = res['success'] == true;
    _toast(ok ? (res['message'] ?? 'تم') : (res['message'] ?? 'فشل'), ok: ok);
    if (ok) await _loadAll();
  }

  Future<void> _openAssignSheet() async {
    if (!_canEdit || _locked) return;
    int? selected = _lead?['AssignedEmployeeId'] is int
        ? _lead!['AssignedEmployeeId'] as int
        : int.tryParse('${_lead?['AssignedEmployeeId'] ?? ''}');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface(_isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('إسناد الموظف المسؤول',
                    style: GoogleFonts.cairo(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: _employees.length,
                    itemBuilder: (_, i) {
                      final e = _employees[i] as Map;
                      final id = e['EmployeeId'] ?? e['EmployeeID'];
                      final idInt = id is int ? id : int.tryParse('$id');
                      final name = '${e['FullName'] ?? ''}';
                      return RadioListTile<int>(
                        value: idInt ?? -1,
                        groupValue: selected,
                        title: Text(name, style: GoogleFonts.cairo()),
                        subtitle: e['Department'] != null
                            ? Text('${e['Department']}',
                                style: GoogleFonts.cairo(fontSize: 11))
                            : null,
                        onChanged: (v) => setModal(() => selected = v),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('إلغاء', style: GoogleFonts.cairo()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: selected == null
                            ? null
                            : () => Navigator.pop(ctx, true),
                        child: Text('حفظ الإسناد', style: GoogleFonts.cairo()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );

    if (ok != true || selected == null) return;
    setState(() => _busy = true);
    final res = await LeadsService.updateLead(
      leadId: widget.leadId,
      userName: widget.username,
      assignedEmployeeId: selected,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    final success = res['success'] == true;
    _toast(success ? 'تم الإسناد' : (res['message'] ?? 'فشل'), ok: success);
    if (success) await _loadAll();
  }

  Future<void> _openConvertSheet() async {
    if (!_canConvert) {
      _toast('يجب تسجيل تواصل قبل التحويل', ok: false);
      return;
    }
    // Ensure lookups
    if (_sources.isEmpty || _categories.isEmpty || _taskTypes.isEmpty) {
      setState(() => _busy = true);
      try {
        final looks = await Future.wait([
          _oppService.getSources(),
          _oppService.getCategories(),
          _oppService.getTaskTypes(),
          _oppService.getAdTypes(),
          _employees.isEmpty ? LeadsService.getEmployees() : Future.value(_employees),
        ]);
        if (!mounted) return;
        setState(() {
          _sources = looks[0] as List<dynamic>;
          _categories = looks[1] as List<dynamic>;
          _taskTypes = looks[2] as List<dynamic>;
          _adTypes = looks[3] as List<dynamic>;
          _employees = looks[4] as List<dynamic>;
          _busy = false;
        });
      } catch (e) {
        setState(() => _busy = false);
        _toast('فشل تحميل قوائم التحويل', ok: false);
        return;
      }
    }

    int? empId = _lead?['AssignedEmployeeId'] is int
        ? _lead!['AssignedEmployeeId'] as int
        : int.tryParse('${_lead?['AssignedEmployeeId'] ?? ''}');
    int? sourceId;
    int? categoryId;
    int? adTypeId;
    int? taskTypeId;
    final valueCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: '${_lead?['Notes'] ?? ''}');

    int? _idOf(dynamic m, List<String> keys) {
      if (m is! Map) return null;
      for (final k in keys) {
        final v = m[k];
        if (v == null) continue;
        if (v is int) return v;
        final p = int.tryParse('$v');
        if (p != null) return p;
      }
      return null;
    }

    String _nameOf(dynamic m) {
      if (m is! Map) return '';
      return '${m['SourceNameAr'] ?? m['SourceName'] ?? m['CategoryNameAr'] ?? m['CategoryName'] ?? m['AdTypeNameAr'] ?? m['AdTypeName'] ?? m['TaskTypeNameAr'] ?? m['TaskTypeName'] ?? m['nameAr'] ?? m['name'] ?? m['Name'] ?? ''}';
    }

    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(_isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('تحويل Lead → عميل + فرصة',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'مثل بلازور: موظف + مصدر + فئة + نوع مهمة + قيمة متوقعة',
                    style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary(_isDark)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: empId,
                    isExpanded: true,
                    decoration: _inputDeco('الموظف المسؤول عن الفرصة *'),
                    items: _employees.map((e) {
                      final m = e as Map;
                      final id = _idOf(m, ['EmployeeId', 'EmployeeID']);
                      return DropdownMenuItem(
                        value: id ?? 0,
                        child: Text('${m['FullName']}',
                            style: GoogleFonts.cairo(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setModal(() => empId = v),
                  ),
                  const SizedBox(height: 10),
                  if (_sources.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: sourceId,
                      isExpanded: true,
                      decoration: _inputDeco('مصدر التواصل'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('—')),
                        ..._sources.map((e) {
                          final id = _idOf(e, ['SourceID', 'SourceId', 'id']);
                          return DropdownMenuItem(
                            value: id,
                            child: Text(_nameOf(e),
                                style: GoogleFonts.cairo(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (v) => setModal(() => sourceId = v),
                    ),
                  if (_sources.isNotEmpty) const SizedBox(height: 10),
                  if (_categories.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: categoryId,
                      isExpanded: true,
                      decoration: _inputDeco('فئة الاهتمام'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('—')),
                        ..._categories.map((e) {
                          final id = _idOf(e, ['CategoryID', 'CategoryId', 'id']);
                          return DropdownMenuItem(
                            value: id,
                            child: Text(_nameOf(e),
                                style: GoogleFonts.cairo(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (v) => setModal(() => categoryId = v),
                    ),
                  if (_categories.isNotEmpty) const SizedBox(height: 10),
                  if (_adTypes.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: adTypeId,
                      isExpanded: true,
                      decoration: _inputDeco('نوع الإعلان'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('—')),
                        ..._adTypes.map((e) {
                          final id = _idOf(e, ['AdTypeID', 'AdTypeId', 'id']);
                          return DropdownMenuItem(
                            value: id,
                            child: Text(_nameOf(e),
                                style: GoogleFonts.cairo(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (v) => setModal(() => adTypeId = v),
                    ),
                  if (_adTypes.isNotEmpty) const SizedBox(height: 10),
                  if (_taskTypes.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: taskTypeId,
                      isExpanded: true,
                      decoration: _inputDeco('نوع مهمة المتابعة'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('—')),
                        ..._taskTypes.map((e) {
                          final id = _idOf(e, ['TaskTypeID', 'TaskTypeId', 'id']);
                          return DropdownMenuItem(
                            value: id,
                            child: Text(_nameOf(e),
                                style: GoogleFonts.cairo(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (v) => setModal(() => taskTypeId = v),
                    ),
                  if (_taskTypes.isNotEmpty) const SizedBox(height: 10),
                  TextField(
                    controller: valueCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDeco('القيمة المتوقعة (ج.م)'),
                    style: GoogleFonts.cairo(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: _inputDeco('ملاحظات'),
                    style: GoogleFonts.cairo(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('إلغاء', style: GoogleFonts.cairo()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: empId == null
                              ? null
                              : () => Navigator.pop(ctx, true),
                          child:
                              Text('تأكيد التحويل', style: GoogleFonts.cairo()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (go != true || empId == null) return;
    setState(() => _busy = true);
    final res = await LeadsService.convertLeadToClient(
      leadId: widget.leadId,
      userName: widget.username,
      employeeId: empId!,
      expectedValue: double.tryParse(valueCtrl.text) ?? 0,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      sourceId: sourceId,
      categoryId: categoryId,
      adTypeId: adTypeId,
      taskTypeId: taskTypeId,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    final success = res['success'] == true;
    _toast(
      success
          ? (res['message'] ?? 'تم التحويل بنجاح 🎉')
          : (res['message'] ?? 'فشل التحويل'),
      ok: success,
    );
    if (success) {
      await _loadAll();
      final oppId = res['opportunityId'] ?? res['OpportunityId'];
      if (oppId != null && mounted) {
        final id = oppId is int ? oppId : int.tryParse('$oppId');
        if (id != null) {
          final open = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text('تم التحويل',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              content: Text('هل تريد فتح فرصة البيع #$id؟',
                  style: GoogleFonts.cairo()),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text('لاحقاً', style: GoogleFonts.cairo())),
                ElevatedButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text('فتح الفرصة', style: GoogleFonts.cairo())),
              ],
            ),
          );
          if (open == true && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OpportunityDetailScreen(
                  opportunityId: id,
                  userId: widget.userId,
                  username: widget.username,
                ),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _confirmReject() async {
    final ctrl = TextEditingController();
    final direct = _perms.canRejectLeadDirectly;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          direct ? 'رفض الـ Lead' : 'طلب رفض Lead',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!direct)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'سيتم إرسال الطلب للمدير العام (GeneralManager) للموافقة. لن تتغير الحالة إلا بعد الاعتماد.',
                  style: GoogleFonts.cairo(
                      fontSize: 12, color: Colors.orange.shade800),
                ),
              ),
            TextField(
              controller: ctrl,
              decoration: _inputDeco('سبب الرفض *'),
              style: GoogleFonts.cairo(),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              direct ? 'رفض' : 'إرسال الطلب',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final reason = ctrl.text.trim();
    if (reason.isEmpty) {
      _toast('سبب الرفض مطلوب', ok: false);
      return;
    }

    if (direct) {
      await _quickStatus(LeadsService.statusRejected, rejectedReason: reason);
      return;
    }

    setState(() => _busy = true);
    final res = await LeadsService.requestReject(
      leadId: widget.leadId,
      userName: widget.username,
      reason: reason,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    final success = res['success'] == true;
    _toast(success ? (res['message'] ?? 'تم إرسال الطلب') : (res['message'] ?? 'فشل'),
        ok: success);
    if (success) await _loadAll();
  }

  Future<void> _editNotes() async {
    final ctrl = TextEditingController(text: '${_lead?['Notes'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('الملاحظات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          style: GoogleFonts.cairo(),
          decoration: _inputDeco('اكتب ملاحظاتك'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('حفظ', style: GoogleFonts.cairo())),
        ],
      ),
    );
    if (ok == true) await _saveNotes(ctrl.text);
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          title: Text('تفاصيل Lead',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          actions: [
            if (!_loading)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _busy ? null : _loadAll,
              ),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: GoogleFonts.cairo()),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _loadAll,
                            child: Text('إعادة المحاولة',
                                style: GoogleFonts.cairo())),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: _loadAll,
                        color: AppColors.gold,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                          children: [
                            _buildHeaderCard(),
                            const SizedBox(height: 12),
                            if (_canEdit && !_locked) _buildActionsRow(),
                            if (_canEdit && !_locked) const SizedBox(height: 12),
                            if (_pendingReject != null) ...[
                              _buildPendingRejectBanner(),
                              const SizedBox(height: 12),
                            ],
                            _buildSection(
                              'بيانات العميل',
                              Icons.person_rounded,
                              [
                                _info('الاسم', _lead!['FullName']),
                                _info('الهاتف', _lead!['Phone'], ltr: true),
                                if (_lead!['Phone2'] != null)
                                  _info('هاتف 2', _lead!['Phone2'], ltr: true),
                                if (_lead!['Email'] != null)
                                  _info('البريد', _lead!['Email'], ltr: true),
                                if (_lead!['City'] != null)
                                  _info('المدينة', _lead!['City']),
                                if (_lead!['Area'] != null)
                                  _info('المنطقة', _lead!['Area']),
                                if (_lead!['Address'] != null)
                                  _info('العنوان', _lead!['Address']),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildSection(
                              'الحملة والإعلان',
                              Icons.campaign_rounded,
                              [
                                _info('المنصة', _lead!['Platform']),
                                _info('الحملة', _lead!['CampaignName']),
                                _info('الإعلان', _lead!['AdName']),
                                _info('المجموعة', _lead!['AdSetName']),
                                _info('الفورم', _lead!['FormName']),
                                _info('نوع المشروع', _lead!['ProjectType']),
                                _info('مرحلة المشروع', _lead!['ProjectStage']),
                                _info('الميزانية', _lead!['Budget']),
                                _info('متخذ القرار', _lead!['DecisionMaker']),
                                _info('أفضل وقت', _lead!['BestTimeToReach']),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildAssignmentCard(),
                            const SizedBox(height: 12),
                            _buildNotesCard(),
                            const SizedBox(height: 12),
                            if (_lead!['IsConverted'] == true ||
                                _lead!['IsConverted'] == 1)
                              _buildConvertedLinks(),
                            if (_lead!['IsConverted'] == true ||
                                _lead!['IsConverted'] == 1)
                              const SizedBox(height: 12),
                            _buildTimeline(),
                          ],
                        ),
                      ),
                      if (_busy)
                        Container(
                          color: Colors.black26,
                          child: const Center(
                              child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final s = _status;
    final color = _statusColor(s);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(_statusIcon(s), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_lead!['FullName'] ?? ''}',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text(_isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(s,
                          style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: color)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _quickActionBtn(
                  Icons.phone,
                  'اتصال',
                  Colors.blue,
                  () => _launchTel('${_lead!['Phone'] ?? ''}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickActionBtn(
                  Icons.chat,
                  'واتساب',
                  const Color(0xFF25D366),
                  () => _launchWhatsApp('${_lead!['Phone'] ?? ''}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickActionBtn(
                  Icons.copy_rounded,
                  'نسخ',
                  Colors.blueGrey,
                  () async {
                    await Clipboard.setData(
                        ClipboardData(text: '${_lead!['Phone'] ?? ''}'));
                    _toast('تم نسخ الرقم');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _metaChip(Icons.tag, '#${_lead!['LeadId']}'),
              if (_lead!['LeadDate'] != null)
                _metaChip(Icons.event, _fmtDate(_lead!['LeadDate'])),
              if (_lead!['LastContactDate'] != null)
                _metaChip(Icons.history, 'آخر تواصل: ${_fmtDate(_lead!['LastContactDate'])}'),
              if (_lead!['Platform'] != null)
                _metaChip(Icons.public, '${_lead!['Platform']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionBtn(
      IconData icon, String label, Color c, VoidCallback onTap) {
    return Material(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: c, size: 20),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.cairo(
                      fontSize: 11, fontWeight: FontWeight.w700, color: c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary(_isDark)),
          const SizedBox(width: 4),
          Text(text,
              style: GoogleFonts.cairo(
                  fontSize: 11, color: AppColors.textSecondary(_isDark))),
        ],
      ),
    );
  }

  Widget _buildActionsRow() {
    // ألوان واضحة على الوضع الداكن والفاتح (تجنب navy الغامق كنص)
    final contactColor = _isDark ? AppColors.gold : const Color(0xFF1D4ED8);
    final contactedColor = const Color(0xFFEA580C);
    final assignColor = const Color(0xFF7C3AED);
    final convertColor = const Color(0xFF15803D);
    final rejectColor = const Color(0xFFDC2626);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _actionChip(Icons.record_voice_over, 'تواصل', contactColor,
            _openInteractionSheet),
        if (_status != LeadsService.statusContacted)
          _actionChip(Icons.phone_callback, 'تم التواصل', contactedColor,
              () => _quickStatus(LeadsService.statusContacted)),
        _actionChip(
            Icons.assignment_ind, 'إسناد', assignColor, _openAssignSheet),
        if (_canConvert)
          _actionChip(
              Icons.transform, 'تحويل', convertColor, _openConvertSheet),
        if (_status != LeadsService.statusRejected && _pendingReject == null)
          _actionChip(
            Icons.cancel,
            _perms.canRejectLeadDirectly ? 'رفض' : 'طلب رفض',
            rejectColor,
            _confirmReject,
          ),
      ],
    );
  }

  Widget _buildPendingRejectBanner() {
    final reason = '${_pendingReject?['Reason'] ?? ''}';
    final by = '${_pendingReject?['RequestedBy'] ?? ''}';
    final reqId = _pendingReject?['RequestId'];
    final canDecide = _perms.canRejectLeadDirectly;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⏳ طلب رفض معلّق',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900, color: Colors.orange.shade900)),
          const SizedBox(height: 4),
          Text('من: $by', style: GoogleFonts.cairo(fontSize: 12)),
          if (reason.isNotEmpty)
            Text('السبب: $reason', style: GoogleFonts.cairo(fontSize: 12)),
          if (canDecide && reqId != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white),
                    onPressed: _busy
                        ? null
                        : () => _decideReject(
                              reqId is int ? reqId : int.parse('$reqId'),
                              true,
                            ),
                    child: Text('اعتماد الرفض', style: GoogleFonts.cairo()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _decideReject(
                              reqId is int ? reqId : int.parse('$reqId'),
                              false,
                            ),
                    child: Text('رفض الطلب', style: GoogleFonts.cairo()),
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'بانتظار موافقة المدير العام',
                style: GoogleFonts.cairo(
                    fontSize: 11, color: Colors.orange.shade800),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _decideReject(int requestId, bool approve) async {
    setState(() => _busy = true);
    final res = await LeadsService.decideRejectRequest(
      requestId: requestId,
      approve: approve,
      userName: widget.username,
      actorRole: _perms.role,
    );
    setState(() => _busy = false);
    if (!mounted) return;
    final ok = res['success'] == true;
    _toast(ok ? (res['message'] ?? 'تم') : (res['message'] ?? 'فشل'), ok: ok);
    if (ok) await _loadAll();
  }

  Widget _actionChip(
      IconData icon, String label, Color c, VoidCallback onTap) {
    // Material 3 ActionChip أحيانًا يطغى على لون النص — نثبّت التباين يدويًا
    final bg = c.withOpacity(_isDark ? 0.22 : 0.14);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.withOpacity(0.55), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: c),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: c,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    final visible = children.whereType<Widget>().toList();
    // filter empty infos — _info returns SizedBox.shrink
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.gold),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          const Divider(height: 18),
          ...visible,
        ],
      ),
    );
  }

  Widget _info(String label, dynamic value, {bool ltr = false}) {
    if (value == null || '$value'.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary(_isDark),
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(
              '$value',
              textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
              style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(_isDark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard() {
    final name = '${_lead?['AssignedEmployeeName'] ?? 'غير مسند'}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.15),
            child: const Icon(Icons.badge, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الموظف المسؤول',
                    style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary(_isDark))),
                Text(name,
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ),
          if (_canEdit && !_locked)
            TextButton.icon(
              onPressed: _openAssignSheet,
              icon: const Icon(Icons.edit, size: 16),
              label: Text('تغيير', style: GoogleFonts.cairo(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    final notes = '${_lead?['Notes'] ?? ''}';
    final feedback = '${_lead?['Feedback'] ?? ''}';
    final rejected = '${_lead?['RejectedReason'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_rounded, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('ملاحظات',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
              ),
              if (_canEdit && !_locked)
                IconButton(
                  icon: const Icon(Icons.edit_note, size: 20),
                  onPressed: _editNotes,
                ),
            ],
          ),
          Text(
            notes.isEmpty ? 'لا توجد ملاحظات' : notes,
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: notes.isEmpty
                  ? AppColors.textSecondary(_isDark)
                  : AppColors.text(_isDark),
              height: 1.5,
            ),
          ),
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('فيدباك',
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary(_isDark))),
            Text(feedback, style: GoogleFonts.cairo(fontSize: 13)),
          ],
          if (rejected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('سبب الرفض',
                style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.red)),
            Text(rejected,
                style: GoogleFonts.cairo(fontSize: 13, color: Colors.red.shade700)),
          ],
        ],
      ),
    );
  }

  Widget _buildConvertedLinks() {
    final oppId = _lead?['ConvertedOpportunityId'];
    final partyId = _lead?['ConvertedPartyId'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تم التحويل',
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900, color: const Color(0xFF166534))),
          if (_lead?['ConvertedDate'] != null)
            Text('بتاريخ ${_fmtDate(_lead!['ConvertedDate'])} بواسطة ${_lead!['ConvertedBy'] ?? ''}',
                style: GoogleFonts.cairo(fontSize: 12)),
          const SizedBox(height: 8),
          if (oppId != null)
            TextButton.icon(
              onPressed: () {
                final id = oppId is int ? oppId : int.tryParse('$oppId');
                if (id == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OpportunityDetailScreen(
                      opportunityId: id,
                      userId: widget.userId,
                      username: widget.username,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.trending_up),
              label: Text('فتح الفرصة #$oppId', style: GoogleFonts.cairo()),
            ),
          if (partyId != null)
            Text('معرف العميل: #$partyId',
                style: GoogleFonts.cairo(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('سجل التواصل',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_interactions.length}',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              if (_canEdit && !_locked) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _openInteractionSheet,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (_interactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('لا يوجد تواصلات بعد',
                    style: GoogleFonts.cairo(
                        color: AppColors.textSecondary(_isDark))),
              ),
            )
          else
            ..._interactions.map(_timelineItem),
        ],
      ),
    );
  }

  Widget _timelineItem(dynamic raw) {
    final item = raw as Map<String, dynamic>;
    final type = '${item['InteractionType'] ?? item['interactionType'] ?? 'ملاحظة'}';
    final color = _interactionColor(type);
    final date = item['InteractionDate'] ?? item['CreatedAt'];
    final summary = '${item['Summary'] ?? ''}';
    final notes = '${item['Notes'] ?? ''}';
    final emp = '${item['EmployeeName'] ?? item['CreatedBy'] ?? ''}';
    final oldS = item['OldLeadStatus'];
    final newS = item['NewLeadStatus'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_interactionIcon(type), color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputFill(_isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  right: BorderSide(color: color, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(type,
                            style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w900,
                                color: color,
                                fontSize: 13)),
                      ),
                      Text(_fmtDate(date),
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.textSecondary(_isDark))),
                    ],
                  ),
                  if (summary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(summary,
                          style: GoogleFonts.cairo(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  if (notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(notes,
                          style: GoogleFonts.cairo(fontSize: 12, height: 1.4)),
                    ),
                  if (emp.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(emp,
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary(_isDark))),
                    ),
                  if (oldS != null || newS != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'الحالة: ${oldS ?? '—'} ← ${newS ?? '—'}',
                        style: GoogleFonts.cairo(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _interactionColor(String type) {
    switch (type) {
      case LeadsService.typeCall:
        return const Color(0xFF3B82F6);
      case LeadsService.typeWhatsApp:
        return const Color(0xFF22C55E);
      case LeadsService.typeAssigned:
        return const Color(0xFF0EA5E9);
      case LeadsService.typeRejected:
        return const Color(0xFFEF4444);
      case LeadsService.typeConverted:
        return const Color(0xFF8B5CF6);
      case LeadsService.typeFollowUp:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _interactionIcon(String type) {
    switch (type) {
      case LeadsService.typeCall:
        return Icons.phone;
      case LeadsService.typeWhatsApp:
        return Icons.chat;
      case LeadsService.typeAssigned:
        return Icons.assignment_ind;
      case LeadsService.typeRejected:
        return Icons.cancel;
      case LeadsService.typeConverted:
        return Icons.transform;
      case LeadsService.typeFollowUp:
        return Icons.event_repeat;
      default:
        return Icons.sticky_note_2;
    }
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    try {
      final dt = v is DateTime ? v : DateTime.tryParse(v.toString());
      if (dt == null) return '$v';
      return DateFormat('yyyy/MM/dd HH:mm').format(dt.toLocal());
    } catch (_) {
      return '$v';
    }
  }
}
