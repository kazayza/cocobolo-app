import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/permission_service.dart';
import '../core/auth/session_service.dart';

import '../widgets/app_drawer.dart';
import '../widgets/design_kit.dart';
import 'client_card_screen.dart';
/// التكليفات العامة - مهام إدارية بعيدة عن الفرص البيعية
/// الهدف: تكليف موظف بمهمة عامة مع إشعارات ومتابعة تنفيذ
class GeneralTasksScreen extends StatefulWidget {
  final int userId;
  final String username;
  // إنشاء سريع مربوط مسبقًا بمستند (من شاشات الأعمال) + فتح تكليف بعينه
  // من رابط إشعار عميق — مرآة CreateGeneralTaskDialog و?taskId= في بلازور.
  final String? presetLinkedType;
  final int? presetLinkedId;
  final bool autoOpenCreate;
  final int? initialTaskId;

  const GeneralTasksScreen({
    super.key,
    required this.userId,
    required this.username,
    this.presetLinkedType,
    this.presetLinkedId,
    this.autoOpenCreate = false,
    this.initialTaskId,
  });

  @override
  State<GeneralTasksScreen> createState() => _GeneralTasksScreenState();
}

class _GeneralTasksScreenState extends State<GeneralTasksScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _showCreatePanel = false;
  bool _busy = false;

  String _activeTab = 'mine'; // mine | created | all | mentions | completed
  String _statusFilter = 'open'; // open | completed | all
  String _searchText = '';

  List<dynamic> _allTasks = [];
  List<dynamic> _mentions = [];
  List<dynamic> _employees = [];
  List<dynamic> _taskTypes = [];

  int? _selectedAssignedTo;
  String _newPriority = 'Medium';
  int? _newTaskTypeId;
  final _descCtrl = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _dueTime = const TimeOfDay(hour: 10, minute: 0);

  // ربط اختياري بمستند — العنوان يُحسم خادميًا عند الحفظ (لا يُرسل عنوان)
  static const List<String> _linkTypes = ['Invoice', 'Delivery', 'JobOrder', 'Quotation', 'Customer', 'Maintenance'];
  String? _linkType;
  int? _linkId;
  String? _linkCustomerName;
  final _linkIdCtrl = TextEditingController();
  final _linkSearchCtrl = TextEditingController();
  List<dynamic> _linkSearchResults = [];
  bool _initialTaskHandled = false;

  final _perms = PermissionService();
  bool get _isDark => ThemeService().isDarkMode;
  bool get _canCreateGeneralTasks =>
      _perms.isGeneralManager || _perms.isAccountManager || _perms.isAdmin;
  int? _currentEmployeeId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // إنشاء سريع مربوط مسبقًا: الربط مضبوط ونموذج الإنشاء مفتوح من البداية
    if (widget.presetLinkedType != null && widget.presetLinkedId != null) {
      _linkType = widget.presetLinkedType;
      _linkId = widget.presetLinkedId;
      _linkIdCtrl.text = '${widget.presetLinkedId}';
    }
    if (widget.autoOpenCreate) _showCreatePanel = true;
    await Future.wait([_loadEmployees(), _loadTaskTypes(), _loadCurrentEmployee()]);
    await _loadTasks();
    await _loadMentions();
    _handleInitialTask();
  }

  // رابط الإشعار العميق: فتح حوار التكليف المقصود إن كان ضمن المرئي
  // للمستخدم، وإلا رسالة بلازور الحرفية.
  void _handleInitialTask() {
    if (_initialTaskHandled || widget.initialTaskId == null || !mounted) return;
    _initialTaskHandled = true;
    final id = widget.initialTaskId!;
    dynamic found;
    for (final t in [..._allTasks, ..._mentions]) {
      if (t['TaskID'] == id) { found = t; break; }
    }
    if (found != null) {
      _showTaskDetail(found);
    } else {
      _toast('التكليف غير موجود أو لا تملك صلاحية عرضه', ok: false);
    }
  }

  Future<void> _loadMentions() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/tasks/my-mentions'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && mounted) setState(() => _mentions = data);
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentEmployee() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/auth/users/${widget.userId}/employee'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _currentEmployeeId = data['employeeID'] as int?;
        if (_currentEmployeeId == null && _canCreateGeneralTasks) {
          _activeTab = 'all';
        }
      }
    } catch (_) {}
  }

  Future<void> _loadEmployees() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/employees'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) _employees = data;
      }
    } catch (_) {}
  }

  Future<void> _loadTaskTypes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/task-types'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) _taskTypes = data;
      }
    } catch (_) {}
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/tasks/general?userName=${widget.username}'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          _allTasks = data;
        }
      }
    } catch (e) {
      debugPrint('load general tasks error $e');
    }
    setState(() => _loading = false);
  }

  List<dynamic> get _assignedToMe => _currentEmployeeId != null ? _allTasks.where((t) => t['AssignedTo'] == _currentEmployeeId).toList() : [];
  List<dynamic> get _createdByMe => _allTasks.where((t) => (t['CreatedBy']?.toString() ?? '').toLowerCase() == widget.username.toLowerCase()).toList();

  // «المكتملة» — مرآة إصلاح بلازور في «مهامي»: اجتماع الوارد ∪ الصادر
  // من المكتملة، بلا تكرار (برقم التكليف)، الأحدث إتمامًا أولًا.
  List<dynamic> get _completedUnion {
    final byId = <int, dynamic>{};
    for (final t in [..._assignedToMe, ..._createdByMe]) {
      if (t['Status'] == 'Completed' && t['TaskID'] != null) byId[t['TaskID'] as int] = t;
    }
    final list = byId.values.toList();
    list.sort((a, b) {
      final da = DateTime.tryParse(a['CompletedDate']?.toString() ?? '') ?? DateTime(1970);
      final db = DateTime.tryParse(b['CompletedDate']?.toString() ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });
    return list;
  }

  List<dynamic> get _filteredTasks {
    List<dynamic> query;
    switch (_activeTab) {
      case 'created':
        query = _createdByMe;
        break;
      case 'all':
        query = _canCreateGeneralTasks ? _allTasks : _assignedToMe;
        break;
      case 'mentions':
        query = List<dynamic>.from(_mentions);
        break;
      case 'completed':
        query = _completedUnion;
        break;
      default:
        query = _assignedToMe;
    }
    if (_activeTab == 'mentions' || _activeTab == 'completed') {
      // تبويبا الإشارات والمكتملة لهما ترتيبهما الخاص (الأحدث أولًا) —
      // تُطبق عليهما التصفية النصية فقط دون إعادة الترتيب العامة.
      if (_searchText.trim().isNotEmpty) {
        final s = _searchText.trim().toLowerCase();
        query = query.where((t) {
          final desc = (t['TaskDescription'] ?? '').toString().toLowerCase();
          final assigned = (t['AssignedToName'] ?? '').toString().toLowerCase();
          final created = (t['CreatedBy'] ?? '').toString().toLowerCase();
          return desc.contains(s) || assigned.contains(s) || created.contains(s);
        }).toList();
      }
      return query;
    }

    query = switch (_statusFilter) {
      'completed' => query.where((t) => t['Status'] == 'Completed').toList(),
      'open' => query.where((t) => t['Status'] != 'Completed' && t['Status'] != 'Cancelled').toList(),
      _ => query,
    };

    if (_searchText.trim().isNotEmpty) {
      final s = _searchText.trim().toLowerCase();
      query = query.where((t) {
        final desc = (t['TaskDescription'] ?? '').toString().toLowerCase();
        final assigned = (t['AssignedToName'] ?? '').toString().toLowerCase();
        final created = (t['CreatedBy'] ?? '').toString().toLowerCase();
        return desc.contains(s) || assigned.contains(s) || created.contains(s);
      }).toList();
    }

    query.sort((a, b) {
      final aCompleted = a['Status'] == 'Completed' ? 1 : 0;
      final bCompleted = b['Status'] == 'Completed' ? 1 : 0;
      if (aCompleted != bCompleted) return aCompleted - bCompleted;
      final da = DateTime.tryParse(a['DueDate']?.toString() ?? '') ?? DateTime.now();
      final db = DateTime.tryParse(b['DueDate']?.toString() ?? '') ?? DateTime.now();
      return da.compareTo(db);
    });

    return query;
  }

  Future<void> _saveGeneralTask() async {
    if (_selectedAssignedTo == null || _selectedAssignedTo! <= 0) {
      _toast('اختر الموظف المكلف', ok: false);
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _toast('اكتب وصف المهمة', ok: false);
      return;
    }
    setState(() => _saving = true);
    try {
      final dueDateTime = DateTime(_dueDate.year, _dueDate.month, _dueDate.day);
      final res = await http.post(
        Uri.parse('$baseUrl/api/tasks/general'),
        headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'assignedTo': _selectedAssignedTo,
          'taskTypeId': _newTaskTypeId,
          'taskDescription': _descCtrl.text.trim(),
          'dueDate': dueDateTime.toIso8601String(),
          'dueTime': '${_dueTime.hour.toString().padLeft(2, '0')}:${_dueTime.minute.toString().padLeft(2, '0')}',
          'priority': _newPriority,
          'assignmentSource': _perms.role,
          'userName': widget.username,
          // الربط: النوع والرقم فقط — العنوان يحسمه الخادم وقت الحفظ
          if (_linkType != null && _linkId != null) 'linkedEntityType': _linkType,
          if (_linkType != null && _linkId != null) 'linkedEntityId': _linkId,
        }),
      );
      final data = jsonDecode(res.body);
      final ok = data['success'] == true;
      _toast(data['message'] ?? (ok ? 'تم إرسال التكليف' : 'فشل'), ok: ok);
      if (ok) {
        _descCtrl.clear();
        _selectedAssignedTo = null;
        _newTaskTypeId = null;
        _linkType = null;
        _linkId = null;
        _linkCustomerName = null;
        _linkIdCtrl.clear();
        _linkSearchCtrl.clear();
        _linkSearchResults = [];
        _showCreatePanel = false;
        await _loadTasks();
      }
    } catch (e) {
      _toast('خطأ: $e', ok: false);
    }
    setState(() => _saving = false);
  }

  Future<void> _startTask(int taskId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('بدء تنفيذ المهمة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      content: TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(labelText: 'ماذا ستبدأ؟ *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), style: GoogleFonts.cairo()),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: GoogleFonts.cairo())), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text('بدء', style: GoogleFonts.cairo()))],
    ));
    if (ok != true || ctrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/tasks/$taskId/start'), headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'}, body: jsonEncode({'notes': ctrl.text.trim(), 'userName': widget.username}));
      final data = jsonDecode(res.body);
      _toast(data['message'] ?? 'تم بدء التنفيذ', ok: data['success'] == true);
      if (data['success'] == true) await _loadTasks();
    } catch (_) {}
    setState(() => _busy = false);
  }

  Future<void> _completeTask(int taskId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('إتمام تنفيذ المهمة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      content: TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(labelText: 'ماذا تم تنفيذه؟ *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), style: GoogleFonts.cairo()),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: GoogleFonts.cairo())), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700), onPressed: () => Navigator.pop(c, true), child: Text('تم التنفيذ', style: GoogleFonts.cairo()))],
    ));
    if (ok != true || ctrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/tasks/$taskId/complete'), headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'}, body: jsonEncode({'notes': ctrl.text.trim(), 'userName': widget.username}));
      final data = jsonDecode(res.body);
      _toast(data['message'] ?? 'تم الإتمام', ok: data['success'] == true);
      if (data['success'] == true) await _loadTasks();
    } catch (_) {}
    setState(() => _busy = false);
  }

  // ── أدوار العارض على تكليف بعينه (مرآة بلازور) ──
  bool _isAssigneeOf(dynamic task) => _currentEmployeeId != null && task['AssignedTo'] == _currentEmployeeId;
  bool _canAdminister(dynamic task) => _canCreateGeneralTasks || (task['CreatedBy']?.toString() ?? '').toLowerCase() == widget.username.toLowerCase();

  String _linkTypeLabel(String? t) => switch (t) {
    'Invoice' => 'فاتورة',
    'Delivery' => 'تسليمة',
    'JobOrder' => 'أمر تشغيل',
    'Quotation' => 'عرض سعر',
    'Customer' => 'عميل',
    'Maintenance' => 'صيانة',
    _ => 'مستند',
  };

  Future<void> _searchLinkCustomers(String q) async {
    if (q.trim().length < 2) {
      setState(() => _linkSearchResults = []);
      return;
    }
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/clients/search?q=${Uri.encodeQueryComponent(q.trim())}'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && mounted) setState(() => _linkSearchResults = data);
      }
    } catch (_) {}
  }

  // منتقي الربط في نموذج الإنشاء: نوع + (بحث عميل بالاسم/الهاتف للعملاء،
  // أو رقم مستند لغيرهم يحسم الخادم عنوانه وقت الحفظ)
  Widget _buildLinkPicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _linkType,
          isExpanded: true,
          decoration: _inputDeco('ربط بمستند (اختياري)', Icons.link_rounded),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('— بدون ربط —')),
            ..._linkTypes.map((t) => DropdownMenuItem<String>(value: t, child: Text(_linkTypeLabel(t), style: GoogleFonts.cairo(fontSize: 12)))),
          ],
          onChanged: (v) => setState(() {
            _linkType = v;
            _linkId = null;
            _linkCustomerName = null;
            _linkIdCtrl.clear();
            _linkSearchResults = [];
          }),
        )),
      ]),
      if (_linkType == 'Customer') ...[
        const SizedBox(height: 10),
        TextField(
          controller: _linkSearchCtrl,
          style: GoogleFonts.cairo(fontSize: 13),
          decoration: _inputDeco('بحث العميل بالاسم أو الهاتف', Icons.search_rounded),
          onChanged: _searchLinkCustomers,
        ),
        if (_linkId != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: _chipPro(AppColors.gold, 'العميل المختار: ${_linkCustomerName ?? '#$_linkId'}', Icons.person_rounded)),
        ..._linkSearchResults.take(5).map((c) => ListTile(
              dense: true,
              title: Text(c['PartyName'] ?? '', style: GoogleFonts.cairo(fontSize: 12)),
              subtitle: Text('${c['Phone'] ?? ''}', style: GoogleFonts.cairo(fontSize: 11)),
              onTap: () => setState(() {
                _linkId = c['PartyID'];
                _linkCustomerName = c['PartyName'];
                _linkSearchResults = [];
              }),
            )),
      ] else if (_linkType != null) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _linkIdCtrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.cairo(fontSize: 13),
          decoration: _inputDeco('رقم ${_linkTypeLabel(_linkType)}', Icons.numbers_rounded),
          onChanged: (v) => _linkId = int.tryParse(v.trim()),
        ),
        Padding(padding: const EdgeInsets.only(top: 6), child: Text('يتحقق الخادم من المستند ويحسم عنوانه عند الحفظ', style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary(_isDark)))),
      ],
    ]);
  }

  Future<String?> _promptReason(String title) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      content: TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(labelText: 'السبب *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), style: GoogleFonts.cairo()),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: GoogleFonts.cairo())), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text('تأكيد', style: GoogleFonts.cairo()))],
    ));
    if (ok != true || ctrl.text.trim().isEmpty) return null;
    return ctrl.text.trim();
  }

  Future<bool> _postTaskAction(int taskId, String action, {Map<String, dynamic>? body}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/tasks/$taskId/$action'),
        headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(body ?? {}),
      );
      final data = jsonDecode(res.body);
      _toast(data['message'] ?? 'تم', ok: data['success'] == true);
      if (data['success'] == true) {
        await _loadTasks();
        await _loadMentions();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _acknowledgeTask(dynamic task) async {
    await _postTaskAction(task['TaskID'], 'acknowledge');
  }

  Future<void> _returnTask(dynamic task) async {
    final reason = await _promptReason('إرجاع التكليف');
    if (reason == null) return;
    await _postTaskAction(task['TaskID'], 'return', body: {'reason': reason});
  }

  Future<void> _cancelTask(dynamic task) async {
    final reason = await _promptReason('إلغاء التكليف');
    if (reason == null) return;
    await _postTaskAction(task['TaskID'], 'cancel', body: {'reason': reason});
  }

  void _openLinkedCustomer(dynamic task) {
    final id = task['LinkedEntityId'];
    if (id == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ClientCardScreen(userId: widget.userId, username: widget.username, initialPartyId: id as int)));
  }

  // حوار التفاصيل الموحّد — مرآة GeneralTaskDetailDialog في بلازور:
  // ترويسة كحلية بالحالة، ختم الاستلام، سببا الإرجاع/الإلغاء، شريط
  // إجراءات حسب الدور والحالة، وخيط النقاش أسفله.
  Future<void> _showTaskDetail(dynamic task) async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        dynamic current = task;
        for (final t in _allTasks) {
          if (t['TaskID'] == task['TaskID']) current = t;
        }
        final status = '${current['Status'] ?? ''}';
        final isOpen = status != 'Completed' && status != 'Cancelled';
        final isAssignee = _isAssigneeOf(current);
        final canAdmin = _canAdminister(current);
        Future<void> act(Future<void> Function() fn) async {
          await fn();
          if (ctx.mounted) setDlg(() {});
        }
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
            child: Row(children: [
              Icon(Icons.assignment_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('تفاصيل التكليف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
              StatusBadge(label: _statusText(status), color: _statusColor(current)),
            ]),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${current['TaskDescription'] ?? ''}', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 14, height: 1.5)),
              const SizedBox(height: 10),
              _infoPro(Icons.badge_rounded, 'المكلف', '${current['AssignedToName'] ?? 'غير محدد'}'),
              _infoPro(Icons.person_outline_rounded, 'أنشئت بواسطة', '${current['CreatedBy'] ?? '—'}'),
              _infoPro(Icons.event_rounded, 'التنفيذ', '${_fmtDate(current['DueDate'])}'),
              _infoPro(Icons.flag_rounded, 'الأولوية', _priorityText(current['Priority'])),
              if (current['LinkedEntityTitle'] != null)
                Padding(padding: const EdgeInsets.only(top: 4, bottom: 6), child: InkWell(
                  onTap: current['LinkedEntityType'] == 'Customer' ? () => _openLinkedCustomer(current) : null,
                  child: _chipPro(AppColors.gold, '${current['LinkedEntityTitle']}', Icons.link_rounded),
                )),
              if (current['AcknowledgedAt'] != null)
                Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.visibility_rounded, size: 15, color: Colors.teal), const SizedBox(width: 6), Expanded(child: Text('استلمها ${current['AcknowledgedBy'] ?? ''} — ${_fmtDate(current['AcknowledgedAt'])}', style: GoogleFonts.cairo(fontSize: 11, color: Colors.teal.shade800)))])),
              if (current['ReturnReason'] != null)
                Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.undo_rounded, size: 15, color: Colors.orange), const SizedBox(width: 6), Expanded(child: Text('سبب الإرجاع: ${current['ReturnReason']}', style: GoogleFonts.cairo(fontSize: 11, color: Colors.orange.shade900)))])),
              if (current['CancellationReason'] != null)
                Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.block_rounded, size: 15, color: Colors.red), const SizedBox(width: 6), Expanded(child: Text('سبب الإلغاء: ${current['CancellationReason']}', style: GoogleFonts.cairo(fontSize: 11, color: Colors.red.shade900)))])),
              if (current['CompletionNotes'] != null)
                Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_rounded, size: 15, color: Colors.green), const SizedBox(width: 6), Expanded(child: Text('تم التنفيذ: ${current['CompletionNotes']}', style: GoogleFonts.cairo(fontSize: 11, color: Colors.green.shade800)))])),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (isAssignee && isOpen && current['AcknowledgedAt'] == null)
                  OutlinedButton.icon(onPressed: () => act(() => _acknowledgeTask(current)), icon: const Icon(Icons.visibility_rounded, size: 16), label: Text('استلام', style: GoogleFonts.cairo(fontSize: 12))),
                if (isAssignee && isOpen && status == 'Pending')
                  OutlinedButton.icon(onPressed: () => act(() => _startTask(current['TaskID'])), icon: const Icon(Icons.play_arrow_rounded, size: 16), label: Text('بدء التنفيذ', style: GoogleFonts.cairo(fontSize: 12))),
                if (isAssignee && isOpen)
                  ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: () => act(() => _completeTask(current['TaskID'])), icon: const Icon(Icons.check_rounded, size: 16), label: Text('تم التنفيذ', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold))),
                if (isAssignee && isOpen)
                  OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800, side: BorderSide(color: Colors.orange.withOpacity(0.5))), onPressed: () => act(() => _returnTask(current)), icon: const Icon(Icons.undo_rounded, size: 16), label: Text('إرجاع', style: GoogleFonts.cairo(fontSize: 12))),
                if (canAdmin && isOpen)
                  OutlinedButton.icon(onPressed: () async { Navigator.pop(ctx); await _showEditTask(current); }, icon: const Icon(Icons.edit_rounded, size: 16), label: Text('تعديل', style: GoogleFonts.cairo(fontSize: 12))),
                if (canAdmin && isOpen)
                  OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red.withOpacity(0.5))), onPressed: () => act(() => _cancelTask(current)), icon: const Icon(Icons.block_rounded, size: 16), label: Text('إلغاء', style: GoogleFonts.cairo(fontSize: 12))),
              ]),
              const Divider(height: 24),
              _TaskThread(taskId: current['TaskID'] as int, employees: _employees, currentUsername: widget.username),
            ])),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إغلاق', style: GoogleFonts.cairo()))],
        );
      }),
    );
  }

  // حوار التعديل/إعادة الإسناد الكامل — للمنشئ أو مدير فقط (الخادم يحرس
  // أيضًا): المكلف/النوع/الوصف/الأولوية/التاريخ/الربط عبر PUT /:id.
  Future<void> _showEditTask(dynamic task) async {
    int? assignedTo = task['AssignedTo'] as int?;
    int? typeId = task['TaskTypeID'] as int?;
    String priority = switch (task['Priority']) { 'High' => 'High', 'Low' => 'Low', _ => 'Medium' };
    final descCtrl = TextEditingController(text: task['TaskDescription']?.toString() ?? '');
    DateTime dueDate = DateTime.tryParse(task['DueDate']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 1));
    String? linkType = task['LinkedEntityType']?.toString();
    final linkIdCtrl = TextEditingController(text: task['LinkedEntityId']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setDlg) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تعديل التكليف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(value: assignedTo, isExpanded: true, decoration: _inputDeco('الموظف المكلف *', Icons.person_rounded), items: _employees.map((e) => DropdownMenuItem<int>(value: e['EmployeeID'] ?? e['EmployeeId'], child: Text(e['FullName'] ?? '', style: GoogleFonts.cairo(fontSize: 13)))).toList(), onChanged: (v) => setDlg(() => assignedTo = v)),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(value: typeId, isExpanded: true, decoration: _inputDeco('نوع المهمة', Icons.category_rounded), items: [const DropdownMenuItem<int>(value: null, child: Text('—')), ..._taskTypes.map((tt) => DropdownMenuItem<int>(value: tt['TaskTypeID'] ?? tt['TaskTypeId'], child: Text(tt['TaskTypeNameAr'] ?? tt['TaskTypeName'] ?? '', style: GoogleFonts.cairo(fontSize: 12))))], onChanged: (v) => setDlg(() => typeId = v)),
          const SizedBox(height: 10),
          TextField(controller: descCtrl, maxLines: 3, style: GoogleFonts.cairo(fontSize: 13), decoration: _inputDeco('وصف المهمة *', Icons.description_rounded)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: priority, isExpanded: true, decoration: _inputDeco('الأولوية', Icons.flag_rounded), items: [DropdownMenuItem(value: 'High', child: Text('عاجلة', style: GoogleFonts.cairo())), DropdownMenuItem(value: 'Medium', child: Text('متوسطة', style: GoogleFonts.cairo())), DropdownMenuItem(value: 'Low', child: Text('منخفضة', style: GoogleFonts.cairo()))], onChanged: (v) => setDlg(() => priority = v ?? 'Medium')),
          const SizedBox(height: 10),
          InkWell(onTap: () async {
            final d = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) setDlg(() => dueDate = d);
          }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill(_isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.08))), child: Row(children: [Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gold), const SizedBox(width: 8), Text(DateFormat('yyyy/MM/dd').format(dueDate), style: GoogleFonts.cairo(fontSize: 12))]))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: linkType, isExpanded: true, decoration: _inputDeco('ربط بمستند', Icons.link_rounded), items: [const DropdownMenuItem<String>(value: null, child: Text('— بدون ربط —')), ..._linkTypes.map((t) => DropdownMenuItem<String>(value: t, child: Text(_linkTypeLabel(t), style: GoogleFonts.cairo(fontSize: 12))))], onChanged: (v) => setDlg(() => linkType = v)),
          if (linkType != null) ...[
            const SizedBox(height: 10),
            TextField(controller: linkIdCtrl, keyboardType: TextInputType.number, style: GoogleFonts.cairo(fontSize: 13), decoration: _inputDeco('رقم ${_linkTypeLabel(linkType)}', Icons.numbers_rounded)),
          ],
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
        ],
      )),
    );
    if (saved != true) return;
    if (assignedTo == null || descCtrl.text.trim().isEmpty) {
      _toast('اختر الموظف واكتب وصف المهمة', ok: false);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/tasks/${task['TaskID']}'),
        headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'assignedTo': assignedTo,
          'taskTypeId': typeId,
          'taskDescription': descCtrl.text.trim(),
          'dueDate': DateTime(dueDate.year, dueDate.month, dueDate.day).toIso8601String(),
          'priority': priority,
          'linkedEntityType': linkType,
          'linkedEntityId': linkType == null ? null : int.tryParse(linkIdCtrl.text.trim()),
        }),
      );
      final data = jsonDecode(res.body);
      _toast(data['message'] ?? 'تم التعديل', ok: data['success'] == true);
      if (data['success'] == true) await _loadTasks();
    } catch (_) {}
    setState(() => _busy = false);
  }

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.cairo()), backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    try {
      final dt = DateTime.tryParse(v.toString());
      if (dt == null) return '$v';
      return DateFormat('yyyy/MM/dd').format(dt.toLocal());
    } catch (_) {
      return '$v';
    }
  }

  Color _statusColor(dynamic task) {
    final status = '${task['Status'] ?? ''}';
    if (status == 'Completed') return AppColors.success;
    if (status == 'In Progress') return AppColors.info;
    try {
      final due = DateTime.tryParse(task['DueDate']?.toString() ?? '');
      if (due != null && due.isBefore(DateTime.now()) && status != 'Completed') return AppColors.error;
    } catch (_) {}
    return AppColors.warning;
  }

  String _statusText(String? s) => switch (s) {
    'Completed' => 'مكتملة',
    'In Progress' => 'جاري التنفيذ',
    'Cancelled' => 'ملغية',
    _ => 'معلقة',
  };

  Color _priorityColor(String? p) => switch (p) {
    'High' => AppColors.error,
    'Low' => AppColors.info,
    _ => AppColors.warning,
  };

  String _priorityText(String? p) => switch (p) {
    'High' => 'عاجلة',
    'Low' => 'منخفضة',
    _ => 'متوسطة',
  };

  String _sourceText(String? src) {
    final s = (src ?? '').toLowerCase();
    if (s.contains('generalmanager') || s == 'gm') return 'المدير العام';
    if (s.contains('accountmanager')) return 'مدير الحسابات';
    if (s.contains('admin')) return 'الإدارة';
    return src ?? 'الإدارة';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        drawer: buildAppDrawer(currentRoute: 'crm/general-tasks'),
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar( leading: const AppDrawerMenuButton(),title: Text('التكليفات العامة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), backgroundColor: AppColors.navy, foregroundColor: Colors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _loadTasks)]),
        body: Stack(children: [
          _loading ? const AppLoading() : CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _buildHeaderPro()),
            if (_canCreateGeneralTasks && _showCreatePanel) SliverToBoxAdapter(child: _buildCreatePanelPro()),
            SliverToBoxAdapter(child: _buildFilterPro()),
            SliverToBoxAdapter(child: _filteredTasks.isEmpty ? _emptyPro() : Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 100), child: Column(children: _filteredTasks.map((t) => _buildTaskCardPro(t)).toList()))),
          ]),
          if (_busy) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ]),
        floatingActionButton: _canCreateGeneralTasks ? FloatingActionButton.extended(onPressed: () => setState(() => _showCreatePanel = !_showCreatePanel), backgroundColor: AppColors.gold, foregroundColor: AppColors.navy, icon: Icon(_showCreatePanel ? Icons.close_rounded : Icons.add_task_rounded), label: Text(_showCreatePanel ? 'إخفاء' : 'تكليف جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold))) : null,
      ),
    );
  }

  Widget _buildHeaderPro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.navyLight]), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.assignment_rounded, color: AppColors.gold, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('التكليفات العامة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            Text('مهام إدارية للموظفين بعيدا عن الفرص البيعية مع نظام إشعارات ومتابعة', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11)),
          ])),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _headerChip('الإجمالي', '${_allTasks.length}', Colors.white),
          const SizedBox(width: 8),
          _headerChip('المطلوبة مني', '${_assignedToMe.length}', Colors.orange),
          const SizedBox(width: 8),
          _headerChip('المرسلة مني', '${_createdByMe.length}', Colors.blue),
          const SizedBox(width: 8),
          if (_canCreateGeneralTasks) _headerChip('متأخرة', '${_allTasks.where((t) => t['Status'] != 'Completed' && DateTime.tryParse(t['DueDate']?.toString() ?? '') != null && DateTime.tryParse(t['DueDate'].toString())!.isBefore(DateTime.now())).length}', Colors.red),
        ]),
      ]),
    );
  }

  Widget _headerChip(String label, String value, Color c) => Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))), child: Column(children: [Text(value, style: GoogleFonts.cairo(color: c, fontWeight: FontWeight.w900, fontSize: 16)), Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 9))])));

  Widget _buildCreatePanelPro() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _isDark ? const Color(0xFF1e293b) : const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.blue.withOpacity(0.20))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.send_rounded, color: Colors.blue, size: 18), const SizedBox(width: 8), Text('إرسال تكليف عام جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14))]),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(value: _selectedAssignedTo, isExpanded: true, decoration: _inputDeco('الموظف المكلف *', Icons.person_rounded), items: _employees.map((e) => DropdownMenuItem<int>(value: e['EmployeeID'] ?? e['EmployeeId'], child: Text(e['FullName'] ?? '', style: GoogleFonts.cairo(fontSize: 13)))).toList(), onChanged: (v) => setState(() => _selectedAssignedTo = v)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(value: _newTaskTypeId, isExpanded: true, decoration: _inputDeco('نوع المهمة', Icons.category_rounded), items: [const DropdownMenuItem<int>(value: null, child: Text('—')), ..._taskTypes.map((tt) => DropdownMenuItem<int>(value: tt['TaskTypeID'] ?? tt['TaskTypeId'], child: Text(tt['TaskTypeNameAr'] ?? tt['TaskTypeName'] ?? '', style: GoogleFonts.cairo(fontSize: 12))))], onChanged: (v) => setState(() => _newTaskTypeId = v))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: _newPriority, decoration: _inputDeco('الأولوية', Icons.flag_rounded), items: [DropdownMenuItem(value: 'High', child: Text('عاجلة', style: GoogleFonts.cairo(color: Colors.red))), DropdownMenuItem(value: 'Medium', child: Text('متوسطة', style: GoogleFonts.cairo(color: Colors.orange))), DropdownMenuItem(value: 'Low', child: Text('منخفضة', style: GoogleFonts.cairo(color: Colors.blue)))], onChanged: (v) => setState(() => _newPriority = v ?? 'Medium'))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _descCtrl, maxLines: 3, style: GoogleFonts.cairo(fontSize: 13), decoration: _inputDeco('وصف المهمة *', Icons.description_rounded)),
        const SizedBox(height: 10),
        _buildLinkPicker(),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: InkWell(onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) setState(() => _dueDate = d);
          }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill(_isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.08))), child: Row(children: [Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gold), const SizedBox(width: 8), Text(DateFormat('yyyy/MM/dd').format(_dueDate), style: GoogleFonts.cairo(fontSize: 12))])))),
          const SizedBox(width: 10),
          Expanded(child: InkWell(onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _dueTime);
            if (t != null) setState(() => _dueTime = t);
          }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill(_isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.08))), child: Row(children: [Icon(Icons.access_time_rounded, size: 16, color: AppColors.gold), const SizedBox(width: 8), Text(_dueTime.format(context), style: GoogleFonts.cairo(fontSize: 12))])))),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _saving ? null : _saveGeneralTask, icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded), label: Text(_saving ? 'جاري الإرسال...' : 'إرسال التكليف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)))),
      ]),
    );
  }

  Widget _buildFilterPro() => Container(
    padding: const EdgeInsets.all(12),
    color: AppColors.card(_isDark),
    child: Column(children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _tabChip('mine', 'المطلوبة مني', Icons.assignment_ind_rounded, Colors.orange),
        _tabChip('created', 'المرسلة مني', Icons.send_rounded, Colors.blue),
        _tabChip('completed', 'المكتملة', Icons.check_circle_rounded, Colors.green),
        _tabChip('mentions', 'إشاراتي (${_mentions.length})', Icons.alternate_email_rounded, AppColors.gold),
        if (_canCreateGeneralTasks) _tabChip('all', 'كل التكليفات', Icons.dashboard_rounded, Colors.green),
      ])),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _statusChipPro('open', 'المفتوحة', Colors.orange),
          _statusChipPro('completed', 'المكتملة', Colors.green),
          _statusChipPro('all', 'الكل', Colors.grey),
        ]))),
        const SizedBox(width: 8),
        SizedBox(width: 160, child: TextField(onChanged: (v) => setState(() => _searchText = v), style: GoogleFonts.cairo(fontSize: 12), decoration: InputDecoration(hintText: 'بحث...', hintStyle: GoogleFonts.cairo(fontSize: 11), prefixIcon: const Icon(Icons.search_rounded, size: 18), isDense: true, filled: true, fillColor: AppColors.inputFill(_isDark), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)))),
      ]),
    ]),
  );

  Widget _tabChip(String key, String label, IconData icon, Color c) {
    final sel = _activeTab == key;
    return Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: sel ? Colors.white : c), const SizedBox(width: 6), Text(label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.w600, color: sel ? Colors.white : c))]), selected: sel, selectedColor: c, backgroundColor: c.withOpacity(0.12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), onSelected: (_) => setState(() => _activeTab = key)));
  }

  Widget _statusChipPro(String key, String label, Color c) {
    final sel = _statusFilter == key;
    return Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(label: Text(label, style: GoogleFonts.cairo(fontSize: 11, color: sel ? Colors.white : c)), selected: sel, selectedColor: c, backgroundColor: c.withOpacity(0.12), onSelected: (_) => setState(() => _statusFilter = key)));
  }

  Widget _emptyPro() => const AppEmpty(
    icon: Icons.assignment_late_rounded,
    message: 'لا توجد تكليفات مطابقة',
    hint: 'التكليفات العامة هي مهام إدارية بعيدة عن الفرص البيعية',
  );

  Widget _buildTaskCardPro(dynamic task) {
    final color = _statusColor(task);
    final isPending = task['Status'] == 'Pending';
    final isInProgress = task['Status'] == 'In Progress';
    final isCompleted = task['Status'] == 'Completed';
    final canStart = _currentEmployeeId != null && task['AssignedTo'] == _currentEmployeeId && isPending;
    final canComplete = _currentEmployeeId != null && task['AssignedTo'] == _currentEmployeeId && !isCompleted && task['Status'] != 'Cancelled';

    return GestureDetector(
      onTap: () => _showTaskDetail(task),
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(isCompleted ? Icons.check_circle_rounded : (isInProgress ? Icons.play_circle_rounded : Icons.assignment_rounded), color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(task['TaskDescription'] ?? 'مهمة عامة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 14, height: 1.4))),
          const SizedBox(width: 8),
          StatusBadge(label: _statusText(task['Status']), color: color),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chipPro(_priorityColor(task['Priority']), _priorityText(task['Priority']), Icons.flag_rounded),
          _chipPro(Colors.grey, _sourceText(task['AssignmentSource']), Icons.person_rounded),
          if (task['TaskTypeNameAr'] != null) _chipPro(Colors.blue, '${task['TaskTypeNameAr']}', Icons.category_rounded),
          if (task['AcknowledgedAt'] != null) _chipPro(Colors.teal, 'تم الاستلام', Icons.visibility_rounded),
        ]),
        // الشريحة الذهبية للمستند المرتبط — تنقل العميل لملفه
        if (task['LinkedEntityTitle'] != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: task['LinkedEntityType'] == 'Customer' ? () => _openLinkedCustomer(task) : () => _showTaskDetail(task),
            child: _chipPro(AppColors.gold, '${task['LinkedEntityTitle']}', Icons.link_rounded),
          ),
        ],
        const SizedBox(height: 12),
        Divider(height: 1, color: Colors.black.withOpacity(0.06)),
        const SizedBox(height: 12),
        _infoPro(Icons.badge_rounded, 'المكلف', '${task['AssignedToName'] ?? 'غير محدد'}'),
        _infoPro(Icons.person_outline_rounded, 'أنشئت بواسطة', '${task['CreatedBy'] ?? '—'}'),
        _infoPro(Icons.event_rounded, 'التنفيذ', '${_fmtDate(task['DueDate'])} ${task['DueTime'] != null ? '- ${task['DueTime']}' : ''}'),
        if (task['StartNotes'] != null && isInProgress) Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.18))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.play_arrow_rounded, size: 16, color: Colors.blue), const SizedBox(width: 6), Expanded(child: Text('بدأ التنفيذ: ${task['StartNotes']}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.blue.shade800)))])),
        if (task['CompletionNotes'] != null && isCompleted) Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.18))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_rounded, size: 16, color: Colors.green), const SizedBox(width: 6), Expanded(child: Text('تم التنفيذ: ${task['CompletionNotes']}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.green.shade800)))])),
        if (canStart || canComplete) ...[
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (canStart) OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: BorderSide(color: Colors.blue.withOpacity(0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _startTask(task['TaskID']), icon: const Icon(Icons.play_arrow_rounded, size: 18), label: Text('بدء التنفيذ', style: GoogleFonts.cairo(fontSize: 12))),
            if (canStart && canComplete) const SizedBox(width: 8),
            if (canComplete) ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _completeTask(task['TaskID']), icon: const Icon(Icons.check_rounded, size: 18), label: Text('تم التنفيذ', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold))),
          ]),
        ],
      ])),
      ),
    );
  }

  Widget _chipPro(Color c, String text, IconData icon) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.20))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: c), const SizedBox(width: 4), Text(text, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: c))]));
  Widget _infoPro(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Icon(icon, size: 14, color: AppColors.textSecondary(_isDark)), const SizedBox(width: 6), SizedBox(width: 90, child: Text('$label:', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary(_isDark), fontWeight: FontWeight.w700))), Expanded(child: Text(value, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))]));
  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(labelText: label, labelStyle: GoogleFonts.cairo(fontSize: 13), prefixIcon: Icon(icon, size: 18, color: AppColors.gold), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: AppColors.card(_isDark), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12));
}

// ═══════════════════════════════════════════════════════════
// خيط نقاش التكليف — مرآة مرحلة النقاش في بلازور: تعليقات وتحديثات
// تقدم للمشاركين فقط، مع مناداة (@) صريحة بمنتقي موظفين تُشعر
// المذكورين. القائمة والكاتب في نفس ملف شاشة التكليفات.
// ═══════════════════════════════════════════════════════════
class _TaskThread extends StatefulWidget {
  final int taskId;
  final List<dynamic> employees;
  final String currentUsername;

  const _TaskThread({
    required this.taskId,
    required this.employees,
    required this.currentUsername,
  });

  @override
  State<_TaskThread> createState() => _TaskThreadState();
}

class _TaskThreadState extends State<_TaskThread> {
  List<dynamic> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _kind = 'Comment'; // Comment | Progress
  final _bodyCtrl = TextEditingController();
  final List<int> _mentionIds = [];
  final List<String> _mentionNames = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/tasks/${widget.taskId}/comments'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && mounted) setState(() { _comments = data; _loading = false; });
      } else {
        final data = jsonDecode(res.body);
        if (mounted) setState(() { _error = data['message']?.toString(); _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMentions() async {
    final selected = Set<int>.from(_mentionIds);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setDlg) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('مناداة زميل (@)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
        content: SizedBox(width: double.maxFinite, child: ListView(
          shrinkWrap: true,
          children: widget.employees.map((e) {
            final id = (e['EmployeeID'] ?? e['EmployeeId']) as int?;
            if (id == null) return const SizedBox.shrink();
            return CheckboxListTile(
              dense: true,
              value: selected.contains(id),
              title: Text(e['FullName'] ?? '', style: GoogleFonts.cairo(fontSize: 12)),
              onChanged: (v) => setDlg(() => v == true ? selected.add(id) : selected.remove(id)),
            );
          }).toList(),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text('تم', style: GoogleFonts.cairo())),
        ],
      )),
    );
    if (ok != true) return;
    setState(() {
      _mentionIds
        ..clear()
        ..addAll(selected);
      _mentionNames
        ..clear()
        ..addAll(widget.employees.where((e) => selected.contains(e['EmployeeID'] ?? e['EmployeeId'])).map((e) => '${e['FullName'] ?? ''}'));
    });
  }

  Future<void> _send() async {
    if (_bodyCtrl.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/tasks/${widget.taskId}/comments'),
        headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'body': _bodyCtrl.text.trim(),
          'kind': _kind,
          'mentionEmployeeIds': _mentionIds,
        }),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _bodyCtrl.clear();
        setState(() {
          _mentionIds.clear();
          _mentionNames.clear();
        });
        await _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'فشل إرسال التعليق', style: GoogleFonts.cairo()), backgroundColor: Colors.red.shade700));
      }
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  String _fmtDateTime(dynamic v) {
    if (v == null) return '';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return '$v';
    return DateFormat('yyyy/MM/dd HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Icon(Icons.forum_rounded, size: 16, color: AppColors.gold),
        const SizedBox(width: 6),
        Text('النقاش والتقدم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
      const SizedBox(height: 10),
      if (_loading)
        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
      else if (_error != null)
        Text(_error!, style: GoogleFonts.cairo(fontSize: 11, color: Colors.red))
      else if (_comments.isEmpty)
        Text('لا توجد تعليقات بعد — كن أول من يضيف تحديثًا.', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey))
      else
        ..._comments.map((c) {
          final isProgress = c['Kind'] == 'Progress';
          final mentions = (c['MentionedNames'] as List?) ?? const [];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isProgress ? Colors.blue.withOpacity(0.06) : Colors.grey.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (isProgress ? Colors.blue : Colors.grey).withOpacity(0.15)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(isProgress ? Icons.trending_up_rounded : Icons.chat_bubble_outline_rounded, size: 13, color: isProgress ? Colors.blue : Colors.grey),
                const SizedBox(width: 5),
                Expanded(child: Text('${c['AuthorName'] ?? c['AuthorUserName'] ?? ''}', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold))),
                Text(isProgress ? 'تحديث تقدم' : 'تعليق', style: GoogleFonts.cairo(fontSize: 10, color: isProgress ? Colors.blue : Colors.grey)),
                const SizedBox(width: 6),
                Text(_fmtDateTime(c['CreatedAt']), style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey)),
              ]),
              const SizedBox(height: 5),
              Text('${c['Body'] ?? ''}', style: GoogleFonts.cairo(fontSize: 12, height: 1.5)),
              if (mentions.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 5), child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text('📣 ${mentions.join('، ')}', style: GoogleFonts.cairo(fontSize: 10, color: AppColors.navy, fontWeight: FontWeight.w700)))),
            ]),
          );
        }),
      const SizedBox(height: 8),
      Row(children: [
        ChoiceChip(label: Text('تعليق', style: GoogleFonts.cairo(fontSize: 11)), selected: _kind == 'Comment', onSelected: (_) => setState(() => _kind = 'Comment')),
        const SizedBox(width: 6),
        ChoiceChip(label: Text('تحديث تقدم', style: GoogleFonts.cairo(fontSize: 11)), selected: _kind == 'Progress', onSelected: (_) => setState(() => _kind = 'Progress')),
        const Spacer(),
        IconButton(onPressed: _pickMentions, icon: Icon(Icons.alternate_email_rounded, size: 18, color: _mentionIds.isEmpty ? Colors.grey : AppColors.gold), tooltip: 'مناداة'),
      ]),
      if (_mentionNames.isNotEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('المذكورون: ${_mentionNames.join('، ')}', style: GoogleFonts.cairo(fontSize: 10, color: AppColors.gold))),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(controller: _bodyCtrl, maxLines: 3, maxLength: 2000, style: GoogleFonts.cairo(fontSize: 12), decoration: InputDecoration(hintText: 'اكتب تعليقًا أو تحديث تقدم...', hintStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.all(10)))),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _sending ? null : _send,
          icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
          color: AppColors.navy,
        ),
      ]),
    ]);
  }
}
