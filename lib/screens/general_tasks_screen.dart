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

/// التكليفات العامة - مهام إدارية بعيدة عن الفرص البيعية
/// الهدف: تكليف موظف بمهمة عامة مع إشعارات ومتابعة تنفيذ
class GeneralTasksScreen extends StatefulWidget {
  final int userId;
  final String username;

  const GeneralTasksScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<GeneralTasksScreen> createState() => _GeneralTasksScreenState();
}

class _GeneralTasksScreenState extends State<GeneralTasksScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _showCreatePanel = false;
  bool _busy = false;

  String _activeTab = 'mine'; // mine | created | all
  String _statusFilter = 'open'; // open | completed | all
  String _searchText = '';

  List<dynamic> _allTasks = [];
  List<dynamic> _employees = [];
  List<dynamic> _taskTypes = [];

  int? _selectedAssignedTo;
  String _newPriority = 'Medium';
  int? _newTaskTypeId;
  final _descCtrl = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _dueTime = const TimeOfDay(hour: 10, minute: 0);

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
    await Future.wait([_loadEmployees(), _loadTaskTypes(), _loadCurrentEmployee()]);
    await _loadTasks();
  }

  Future<void> _loadCurrentEmployee() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/auth/users/${widget.userId}/employee'));
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
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/employees'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) _employees = data;
      }
    } catch (_) {}
  }

  Future<void> _loadTaskTypes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/task-types'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) _taskTypes = data;
      }
    } catch (_) {}
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/tasks/general?userName=${widget.username}'));
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

  List<dynamic> get _filteredTasks {
    List<dynamic> query;
    switch (_activeTab) {
      case 'created':
        query = _createdByMe;
        break;
      case 'all':
        query = _canCreateGeneralTasks ? _allTasks : _assignedToMe;
        break;
      default:
        query = _assignedToMe;
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'assignedTo': _selectedAssignedTo,
          'taskTypeId': _newTaskTypeId,
          'taskDescription': _descCtrl.text.trim(),
          'dueDate': dueDateTime.toIso8601String(),
          'dueTime': '${_dueTime.hour.toString().padLeft(2, '0')}:${_dueTime.minute.toString().padLeft(2, '0')}',
          'priority': _newPriority,
          'assignmentSource': _perms.role,
          'userName': widget.username,
        }),
      );
      final data = jsonDecode(res.body);
      final ok = data['success'] == true;
      _toast(data['message'] ?? (ok ? 'تم إرسال التكليف' : 'فشل'), ok: ok);
      if (ok) {
        _descCtrl.clear();
        _selectedAssignedTo = null;
        _newTaskTypeId = null;
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
      final res = await http.post(Uri.parse('$baseUrl/api/tasks/$taskId/start'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'notes': ctrl.text.trim(), 'userName': widget.username}));
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
      final res = await http.post(Uri.parse('$baseUrl/api/tasks/$taskId/complete'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'notes': ctrl.text.trim(), 'userName': widget.username}));
      final data = jsonDecode(res.body);
      _toast(data['message'] ?? 'تم الإتمام', ok: data['success'] == true);
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
    if (status == 'Completed') return Colors.green;
    if (status == 'In Progress') return Colors.blue;
    try {
      final due = DateTime.tryParse(task['DueDate']?.toString() ?? '');
      if (due != null && due.isBefore(DateTime.now()) && status != 'Completed') return Colors.red;
    } catch (_) {}
    return Colors.orange;
  }

  String _statusText(String? s) => switch (s) {
    'Completed' => 'مكتملة',
    'In Progress' => 'جاري التنفيذ',
    'Cancelled' => 'ملغية',
    _ => 'معلقة',
  };

  Color _priorityColor(String? p) => switch (p) {
    'High' => Colors.red,
    'Low' => Colors.blue,
    _ => Colors.orange,
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
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(title: Text('التكليفات العامة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), backgroundColor: AppColors.navy, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _loadTasks)]),
        body: Stack(children: [
          _loading ? Center(child: CircularProgressIndicator(color: AppColors.gold)) : CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _buildHeaderPro()),
            if (_canCreateGeneralTasks && _showCreatePanel) SliverToBoxAdapter(child: _buildCreatePanelPro()),
            SliverToBoxAdapter(child: _buildFilterPro()),
            SliverToBoxAdapter(child: _filteredTasks.isEmpty ? _emptyPro() : Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 100), child: Column(children: _filteredTasks.map((t) => _buildTaskCardPro(t)).toList()))),
          ]),
          if (_busy) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ]),
        floatingActionButton: _canCreateGeneralTasks ? FloatingActionButton.extended(onPressed: () => setState(() => _showCreatePanel = !_showCreatePanel), backgroundColor: AppColors.navy, foregroundColor: Colors.white, icon: Icon(_showCreatePanel ? Icons.close_rounded : Icons.add_task_rounded), label: Text(_showCreatePanel ? 'إخفاء' : 'تكليف جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold))) : null,
      ),
    );
  }

  Widget _buildHeaderPro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, const Color(0xFF1E3A5F)]), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
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

  Widget _emptyPro() => Padding(padding: const EdgeInsets.all(32), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.assignment_late_rounded, size: 40, color: Colors.blue)),
    const SizedBox(height: 16),
    Text('لا توجد تكليفات مطابقة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
    Text('التكليفات العامة هي مهام إدارية بعيدة عن الفرص البيعية', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
  ])));

  Widget _buildTaskCardPro(dynamic task) {
    final color = _statusColor(task);
    final isPending = task['Status'] == 'Pending';
    final isInProgress = task['Status'] == 'In Progress';
    final isCompleted = task['Status'] == 'Completed';
    final canStart = _currentEmployeeId != null && task['AssignedTo'] == _currentEmployeeId && isPending;
    final canComplete = _currentEmployeeId != null && task['AssignedTo'] == _currentEmployeeId && !isCompleted && task['Status'] != 'Cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(isCompleted ? Icons.check_circle_rounded : (isInProgress ? Icons.play_circle_rounded : Icons.assignment_rounded), color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(task['TaskDescription'] ?? 'مهمة عامة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 14, height: 1.4))),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(_statusText(task['Status']), style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chipPro(_priorityColor(task['Priority']), _priorityText(task['Priority']), Icons.flag_rounded),
          _chipPro(Colors.grey, _sourceText(task['AssignmentSource']), Icons.person_rounded),
          if (task['TaskTypeNameAr'] != null) _chipPro(Colors.blue, '${task['TaskTypeNameAr']}', Icons.category_rounded),
        ]),
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
    );
  }

  Widget _chipPro(Color c, String text, IconData icon) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.20))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: c), const SizedBox(width: 4), Text(text, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: c))]));
  Widget _infoPro(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Icon(icon, size: 14, color: AppColors.textSecondary(_isDark)), const SizedBox(width: 6), SizedBox(width: 90, child: Text('$label:', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary(_isDark), fontWeight: FontWeight.w700))), Expanded(child: Text(value, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))]));
  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(labelText: label, labelStyle: GoogleFonts.cairo(fontSize: 13), prefixIcon: Icon(icon, size: 18, color: AppColors.gold), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: AppColors.card(_isDark), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12));
}
