import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/leads_service.dart';
import '../services/permission_service.dart';
import 'lead_detail_screen.dart';
import 'add_lead_screen.dart';
import 'dart:async';
import 'dart:convert';

class LeadsScreen extends StatefulWidget {
  final int userId;
  final String username;

  /// My Leads mode (Blazor /crm/leads/my): locked to current employee.
  final bool myLeadsOnly;

  /// Optional custom app bar title.
  final String? title;

  const LeadsScreen({
    Key? key,
    required this.userId,
    required this.username,
    this.myLeadsOnly = false,
    this.title,
  }) : super(key: key);

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  bool _isLoading = true;
  bool _actionBusy = false;
  bool _filtersReady = false;
  List<dynamic> _allLeads = [];
  List<dynamic> _leads = [];
  List<dynamic> _employees = [];
  List<String> _cities = [];
  List<String> _projectTypes = [];
  Map<String, dynamic> _serverStats = {};
  String _selectedStatus = 'الكل';
  String _sortBy = 'الأحدث';
  String _dateFilter = 'الكل';
  String _selectedCity = 'الكل';
  String _selectedProjectType = 'الكل';
  int? _selectedEmployeeId; // null = الكل
  // فلاتر المصدر والحملة (جديدة — زي بلازور)
  List<Map<String, dynamic>> _sources = [];
  List<Map<String, dynamic>> _adTypes = [];
  int? _selectedSourceId;   // null = الكل
  int? _selectedAdTypeId;   // null = الكل
  DateTimeRange? _customDateRange;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final _perms = PermissionService();

  String get _prefsKey => widget.myLeadsOnly
      ? 'my_leads_screen_filters_v1'
      : 'leads_screen_filters_v1';

  bool get _isMyLeads => widget.myLeadsOnly;

  bool get _canPickEmployee {
    if (_isMyLeads) return false;
    return _perms.isAdmin ||
        _perms.isSalesManager ||
        _perms.isGeneralManager ||
        _perms.canSeeAllSales;
  }

  String get _screenTitle {
    if (widget.title != null && widget.title!.trim().isNotEmpty) {
      return widget.title!;
    }
    if (_isMyLeads) return 'My Leads';
    return 'العملاء المحتملين';
  }

  bool get _canEditLead =>
      _perms.canEdit('frm_LeadsCRM') ||
      _perms.isAdmin ||
      _perms.isSalesManager ||
      _perms.isSales ||
      _perms.isGeneralManager;

  final List<Map<String, dynamic>> _statuses = [
    {'label': 'الكل', 'icon': Icons.all_inclusive, 'color': Colors.blueGrey},
    {'label': 'جديد', 'icon': Icons.fiber_new_rounded, 'color': Colors.blue},
    {
      'label': 'تم التواصل',
      'icon': Icons.phone_callback,
      'color': Colors.orange,
    },
    {
      'label': 'تم الإسناد',
      'icon': Icons.assignment_ind,
      'color': Colors.purple,
    },
    {'label': 'محول', 'icon': Icons.check_circle, 'color': Colors.green},
    {'label': 'مرفوض', 'icon': Icons.cancel, 'color': Colors.red},
  ];

  final List<Map<String, dynamic>> _dateFilters = [
    {'label': 'الكل', 'icon': Icons.all_inclusive},
    {'label': 'اليوم', 'icon': Icons.today_rounded},
    {'label': 'آخر أسبوع', 'icon': Icons.date_range_rounded},
    {'label': 'آخر شهر', 'icon': Icons.calendar_month_rounded},
    {'label': 'مخصص', 'icon': Icons.edit_calendar_rounded},
  ];

  final List<String> _sortOptions = ['الأحدث', 'الأقدم', 'الاسم', 'الحالة'];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadEmployees(),
      _loadFilterOptions(),
      _restoreFilters(),
    ]);

    // My Leads (Blazor /crm/leads/my): always lock to linked employee
    if (_isMyLeads) {
      _selectedEmployeeId = _perms.employeeId;
    } else {
      // All Leads: sales default to own scope; managers see all
      final bool canSeeAll = _canPickEmployee;
      if (!canSeeAll &&
          _selectedEmployeeId == null &&
          _perms.employeeId != null) {
        _selectedEmployeeId = _perms.employeeId;
      }
    }

    if (!mounted) return;
    setState(() => _filtersReady = true);
    await _fetchLeads();
  }

  Future<void> _loadEmployees() async {
    final list = await LeadsService.getEmployees();
    if (mounted) setState(() => _employees = list);
  }

  Future<void> _loadFilterOptions() async {
    final opts = await LeadsService.getFilterOptions();
    if (!mounted) return;
    setState(() {
      _cities = (opts['cities'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      _projectTypes = (opts['projectTypes'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    });

    // المصادر والحملات (من نفس جداول الفرص — زي بلازور)
    final sources = await LeadsService.getSources();
    final adTypes = await LeadsService.getAdTypes();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _adTypes = adTypes;
    });
  }

  Future<void> _restoreFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final m = jsonDecode(raw);
      if (m is! Map) return;
      _selectedStatus = (m['status'] ?? 'الكل').toString();
      _sortBy = (m['sortBy'] ?? 'الأحدث').toString();
      _dateFilter = (m['dateFilter'] ?? 'الكل').toString();
      _selectedCity = (m['city'] ?? 'الكل').toString();
      _selectedProjectType = (m['projectType'] ?? 'الكل').toString();
      final srcId = m['sourceId'];
      if (srcId is int) {
        _selectedSourceId = srcId;
      } else if (srcId != null) {
        _selectedSourceId = int.tryParse('$srcId');
      }
      final adId = m['adTypeId'];
      if (adId is int) {
        _selectedAdTypeId = adId;
      } else if (adId != null) {
        _selectedAdTypeId = int.tryParse('$adId');
      }
      final emp = m['employeeId'];
      if (emp == null) {
        _selectedEmployeeId = null;
      } else if (emp is int) {
        _selectedEmployeeId = emp;
      } else {
        _selectedEmployeeId = int.tryParse('$emp');
      }
      final search = (m['search'] ?? '').toString();
      if (search.isNotEmpty) _searchController.text = search;
      if (m['customFrom'] != null && m['customTo'] != null) {
        final from = DateTime.tryParse(m['customFrom'].toString());
        final to = DateTime.tryParse(m['customTo'].toString());
        if (from != null && to != null) {
          _customDateRange = DateTimeRange(start: from, end: to);
        }
      }
    } catch (e) {
      print('restore filters: $e');
    }
  }

  Future<void> _persistFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'status': _selectedStatus,
          'sortBy': _sortBy,
          'dateFilter': _dateFilter,
          'city': _selectedCity,
          'projectType': _selectedProjectType,
          'sourceId': _selectedSourceId,
          'adTypeId': _selectedAdTypeId,
          'employeeId': _selectedEmployeeId,
          'search': _searchController.text.trim(),
          'customFrom': _customDateRange?.start.toIso8601String(),
          'customTo': _customDateRange?.end.toIso8601String(),
        }),
      );
    } catch (e) {
      print('persist filters: $e');
    }
  }

  Future<void> _launchTel(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWa(String phone) async {
    var p = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (p.startsWith('00')) p = p.substring(2);
    if (p.startsWith('0')) p = '20${p.substring(1)}';
    final uri = Uri.parse('https://wa.me/$p');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _toast(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo()),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int? _leadIdOf(dynamic lead) {
    final id = lead['LeadId'];
    if (id is int) return id;
    return int.tryParse('$id');
  }

  Future<void> _openDetail(dynamic lead) async {
    final leadId = _leadIdOf(lead);
    if (leadId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadDetailScreen(
          leadId: leadId,
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    );
    if (mounted) _fetchLeads();
  }

  Future<void> _quickAssign(dynamic lead) async {
    if (!_canEditLead || _actionBusy) return;
    final leadId = _leadIdOf(lead);
    if (leadId == null) return;
    if (_employees.isEmpty) await _loadEmployees();
    if (_employees.isEmpty) {
      _toast('لا يوجد موظفون متاحون', ok: false);
      return;
    }

    int? selected = lead['AssignedEmployeeId'] is int
        ? lead['AssignedEmployeeId'] as int
        : int.tryParse('${lead['AssignedEmployeeId'] ?? ''}');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: ThemeService().isDarkMode
          ? const Color(0xFF1e293b)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'إسناد Lead',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    lead['FullName'] ?? '',
                    style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: _employees.length,
                      itemBuilder: (_, i) {
                        final e = _employees[i] as Map;
                        final id = e['EmployeeId'] ?? e['EmployeeID'];
                        final idInt = id is int ? id : int.tryParse('$id');
                        return RadioListTile<int>(
                          value: idInt ?? -1,
                          groupValue: selected,
                          title: Text(
                            '${e['FullName']}',
                            style: GoogleFonts.cairo(fontSize: 13),
                          ),
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
                          onPressed: selected == null
                              ? null
                              : () => Navigator.pop(ctx, true),
                          child: Text('حفظ', style: GoogleFonts.cairo()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true || selected == null) return;
    setState(() => _actionBusy = true);
    final res = await LeadsService.updateLead(
      leadId: leadId,
      userName: widget.username,
      assignedEmployeeId: selected,
    );
    setState(() => _actionBusy = false);
    final success = res['success'] == true;
    _toast(success ? 'تم الإسناد' : (res['message'] ?? 'فشل'), ok: success);
    if (success) _fetchLeads();
  }

  Future<void> _quickConvert(dynamic lead) async {
    if (!_canEditLead || _actionBusy) return;
    final leadId = _leadIdOf(lead);
    if (leadId == null) return;
    if (!LeadsService.canConvert(Map<String, dynamic>.from(lead as Map))) {
      _toast('لازم يتم التواصل أولاً قبل التحويل', ok: false);
      return;
    }
    // Open detail convert is richer — but support quick path
    int? empId = lead['AssignedEmployeeId'] is int
        ? lead['AssignedEmployeeId'] as int
        : int.tryParse('${lead['AssignedEmployeeId'] ?? ''}');
    if (_employees.isEmpty) await _loadEmployees();

    final valueCtrl = TextEditingController();
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeService().isDarkMode
          ? const Color(0xFF1e293b)
          : Colors.white,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'تحويل سريع لفرصة',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: empId,
                    decoration: InputDecoration(
                      labelText: 'الموظف *',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _employees.map((e) {
                      final m = e as Map;
                      final id = m['EmployeeId'] ?? m['EmployeeID'];
                      final idInt = id is int ? id : int.tryParse('$id') ?? 0;
                      return DropdownMenuItem(
                        value: idInt,
                        child: Text(
                          '${m['FullName']}',
                          style: GoogleFonts.cairo(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setModal(() => empId = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: valueCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'القيمة المتوقعة',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: GoogleFonts.cairo(),
                  ),
                  const SizedBox(height: 14),
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
                          child: Text('تحويل', style: GoogleFonts.cairo()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (go != true || empId == null) return;
    setState(() => _actionBusy = true);
    final res = await LeadsService.convertLeadToClient(
      leadId: leadId,
      userName: widget.username,
      employeeId: empId!,
      expectedValue: double.tryParse(valueCtrl.text) ?? 0,
    );
    setState(() => _actionBusy = false);
    final success = res['success'] == true;
    _toast(
      success ? (res['message'] ?? 'تم التحويل') : (res['message'] ?? 'فشل'),
      ok: success,
    );
    if (success) _fetchLeads();
  }

  Future<void> _quickReject(dynamic lead) async {
    if (!_canEditLead || _actionBusy) return;
    final leadId = _leadIdOf(lead);
    if (leadId == null) return;
    final status = '${lead['LeadStatus'] ?? ''}';
    if (status == LeadsService.statusRejected ||
        status == LeadsService.statusConverted) {
      _toast('لا يمكن رفض هذا الـ Lead', ok: false);
      return;
    }

    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          _perms.canRejectLeadDirectly ? 'رفض Lead' : 'طلب رفض Lead',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_perms.canRejectLeadDirectly)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'سيتم إرسال طلب للمدير العام (GeneralManager) للموافقة على الرفض.',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                labelText: 'سبب الرفض *',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              _perms.canRejectLeadDirectly ? 'رفض' : 'إرسال الطلب',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      _toast('السبب مطلوب', ok: false);
      return;
    }

    setState(() => _actionBusy = true);
    Map<String, dynamic> res;
    if (_perms.canRejectLeadDirectly) {
      res = await LeadsService.updateLead(
        leadId: leadId,
        userName: widget.username,
        leadStatus: LeadsService.statusRejected,
        rejectedReason: reason,
        actorRole: _perms.role,
      );
    } else {
      res = await LeadsService.requestReject(
        leadId: leadId,
        userName: widget.username,
        reason: reason,
      );
    }
    setState(() => _actionBusy = false);
    final success = res['success'] == true;
    _toast(
      success ? (res['message'] ?? 'تم') : (res['message'] ?? 'فشل'),
      ok: success,
    );
    if (success) _fetchLeads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _fetchLeads();
    });
  }

  bool get _hasActiveFilters =>
      _selectedStatus != 'الكل' ||
      _searchController.text.trim().isNotEmpty ||
      _dateFilter != 'الكل' ||
      _selectedCity != 'الكل' ||
      _selectedProjectType != 'الكل' ||
      _selectedSourceId != null ||
      _selectedAdTypeId != null ||
      (_canPickEmployee && _selectedEmployeeId != null);

  int get _activeFilterCount {
    int count = 0;
    if (_selectedStatus != 'الكل') count++;
    if (_dateFilter != 'الكل') count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    if (_selectedCity != 'الكل') count++;
    if (_selectedProjectType != 'الكل') count++;
    if (_selectedSourceId != null) count++;
    if (_selectedAdTypeId != null) count++;
    if (_canPickEmployee && _selectedEmployeeId != null) count++;
    return count;
  }

  String get _selectedEmployeeLabel {
    if (_selectedEmployeeId == null) return 'كل الموظفين';
    for (final e in _employees) {
      final m = e as Map;
      final id = m['EmployeeId'] ?? m['EmployeeID'];
      final idInt = id is int ? id : int.tryParse('$id');
      if (idInt == _selectedEmployeeId) {
        return '${m['FullName'] ?? 'موظف'}';
      }
    }
    return 'موظف #$_selectedEmployeeId';
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatus = 'الكل';
      _dateFilter = 'الكل';
      _customDateRange = null;
      _selectedCity = 'الكل';
      _selectedProjectType = 'الكل';
      _selectedSourceId = null;
      _selectedAdTypeId = null;
      // My Leads keeps employee lock
      if (_canPickEmployee) {
        _selectedEmployeeId = null;
      } else if (_isMyLeads) {
        _selectedEmployeeId = _perms.employeeId;
      }
      _sortBy = 'الأحدث';
    });
    _persistFilters();
    _fetchLeads();
  }

  /// فتح شاشة إضافة Lead يدوي (زي بلازور)
  Future<void> _openAddLead() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLeadScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    );
    // لو اتضاف Lead جديد → نحدّث القائمة فوراً
    if (added == true && mounted) {
      _fetchLeads();
    }
  }

  Future<void> _fetchLeads() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _persistFilters();

    String? dateFrom;
    String? dateTo;
    final now = DateTime.now();
    if (_dateFilter == 'اليوم') {
      dateFrom = DateTime(now.year, now.month, now.day).toIso8601String();
      dateTo = now.toIso8601String();
    } else if (_dateFilter == 'آخر أسبوع') {
      dateFrom = now.subtract(const Duration(days: 7)).toIso8601String();
      dateTo = now.toIso8601String();
    } else if (_dateFilter == 'آخر شهر') {
      dateFrom = now.subtract(const Duration(days: 30)).toIso8601String();
      dateTo = now.toIso8601String();
    } else if (_dateFilter == 'مخصص' && _customDateRange != null) {
      dateFrom = _customDateRange!.start.toIso8601String();
      dateTo = _customDateRange!.end.toIso8601String();
    }

    final city = _selectedCity == 'الكل' ? null : _selectedCity;
    final projectType = _selectedProjectType == 'الكل'
        ? null
        : _selectedProjectType;
    final srcId = _selectedSourceId;
    final adId = _selectedAdTypeId;
    final empId = _selectedEmployeeId;
    final search = _searchController.text.trim();

    // KPIs without status filter (but with other filters) + filtered list
    final results = await Future.wait([
      LeadsService.getLeads(
        search: search,
        employeeId: empId,
        city: city,
        projectType: projectType,
        sourceId: srcId,
        adTypeId: adId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: 200,
      ),
      LeadsService.getLeads(
        status: _selectedStatus == 'الكل' ? null : _selectedStatus,
        search: search,
        employeeId: empId,
        city: city,
        projectType: projectType,
        sourceId: srcId,
        adTypeId: adId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: 200,
      ),
      LeadsService.getStats(
        employeeId: empId,
        city: city,
        projectType: projectType,
        sourceId: srcId,
        adTypeId: adId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
    ]);

    if (!mounted) return;
    final allResult = results[0] as LeadsListResult;
    final filteredResult = results[1] as LeadsListResult;
    final stats = results[2] as Map<String, dynamic>;

    setState(() {
      _allLeads = allResult.items;
      _leads = List<dynamic>.from(filteredResult.items);
      _serverStats = stats;
      _sortLeads();
      _isLoading = false;
    });
  }

  int _kpiCount(String label) {
    if (label == 'الكل') {
      return _serverStats['totalLeads'] is int
          ? _serverStats['totalLeads'] as int
          : _allLeads.length;
    }
    final map = {
      'جديد': 'newLeads',
      'تم الإسناد': 'assignedLeads',
      'تم التواصل': 'contactedLeads',
      'محول': 'convertedLeads',
      'مرفوض': 'rejectedLeads',
    };
    final key = map[label];
    if (key != null && _serverStats[key] != null) {
      final v = _serverStats[key];
      if (v is int) return v;
      return int.tryParse('$v') ??
          _allLeads.where((l) => l['LeadStatus'] == label).length;
    }
    return _allLeads.where((l) => l['LeadStatus'] == label).length;
  }

  void _sortLeads() {
    switch (_sortBy) {
      case 'الأحدث':
        _leads.sort(
          (a, b) => (b['LeadDate'] ?? '').compareTo(a['LeadDate'] ?? ''),
        );
        break;
      case 'الأقدم':
        _leads.sort(
          (a, b) => (a['LeadDate'] ?? '').compareTo(b['LeadDate'] ?? ''),
        );
        break;
      case 'الاسم':
        _leads.sort(
          (a, b) => (a['FullName'] ?? '').compareTo(b['FullName'] ?? ''),
        );
        break;
      case 'الحالة':
        _leads.sort(
          (a, b) => (a['LeadStatus'] ?? '').compareTo(b['LeadStatus'] ?? ''),
        );
        break;
    }
  }

  List<dynamic> _applyDateFilter(List<dynamic> leads) {
    if (_dateFilter == 'الكل') return List.from(leads);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return leads.where((lead) {
      final dateStr = lead['LeadDate'] as String?;
      if (dateStr == null || dateStr.isEmpty) return false;

      DateTime? leadDate;
      try {
        leadDate = DateTime.tryParse(dateStr);
        if (leadDate == null) {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            leadDate = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
          }
        }
      } catch (_) {}

      if (leadDate == null) return true;

      switch (_dateFilter) {
        case 'اليوم':
          return leadDate.year == today.year &&
              leadDate.month == today.month &&
              leadDate.day == today.day;
        case 'آخر أسبوع':
          return leadDate.isAfter(today.subtract(const Duration(days: 7)));
        case 'آخر شهر':
          return leadDate.isAfter(today.subtract(const Duration(days: 30)));
        case 'مخصص':
          if (_customDateRange == null) return true;
          final start = DateTime(
            _customDateRange!.start.year,
            _customDateRange!.start.month,
            _customDateRange!.start.day,
          );
          final end = DateTime(
            _customDateRange!.end.year,
            _customDateRange!.end.month,
            _customDateRange!.end.day,
            23,
            59,
            59,
          );
          return leadDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
              leadDate.isBefore(end.add(const Duration(seconds: 1)));
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _pickCustomDateRange() async {
    final isDark = ThemeService().isDarkMode;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF60a5fa),
                    onPrimary: Color(0xFF0f172a),
                    surface: Color(0xFF1e293b),
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: const Color(0xFF1e293b),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF60a5fa),
                    ),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF2563eb),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF0f172a),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563eb),
                    ),
                  ),
                ),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: child!,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _customDateRange = picked;
        _dateFilter = 'مخصص';
      });
      _fetchLeads();
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'جديد':
        return Colors.blue;
      case 'تم التواصل':
        return Colors.orange;
      case 'تم الإسناد':
        return Colors.purple;
      case 'محول':
        return Colors.green;
      case 'مرفوض':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'جديد':
        return Icons.fiber_new_rounded;
      case 'تم التواصل':
        return Icons.phone_callback;
      case 'تم الإسناد':
        return Icons.assignment_ind;
      case 'محول':
        return Icons.check_circle;
      case 'مرفوض':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  // ══════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0f172a)
          : const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _screenTitle,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            if (_isMyLeads)
              Text(
                _perms.fullName?.isNotEmpty == true
                    ? 'المسندة إليك — ${_perms.fullName}'
                    : 'Leads المسندة لك للمتابعة اليومية',
                style: GoogleFonts.cairo(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isMyLeads)
            IconButton(
              tooltip: 'كل الـ Leads',
              icon: const Icon(Icons.list_alt_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeadsScreen(
                      userId: widget.userId,
                      username: widget.username,
                      myLeadsOnly: false,
                      title: 'كل الـ Leads',
                    ),
                  ),
                );
              },
            ),
          // ➕ إضافة Lead يدوي
          IconButton(
            tooltip: 'إضافة Lead يدوي',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: _openAddLead,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchLeads,
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchLeads,
          color: const Color(0xFF2563eb),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeroSummary(isDark)),
              SliverToBoxAdapter(child: _buildFilterSection(isDark)),
              SliverToBoxAdapter(child: _buildResultsBar(isDark)),

              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563eb)),
                  ),
                )
              else if (_leads.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(isDark),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildLeadCard(_leads[index], isDark),
                      childCount: _leads.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // HERO SUMMARY (Clickable)
  // ══════════════════════════════════════════════
  Widget _buildHeroSummary(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0f172a), Color(0xFF1e3a8a), Color(0xFF2563eb)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0f172a).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Total — clickable
            GestureDetector(
              onTap: () {
                setState(() => _selectedStatus = 'الكل');
                _fetchLeads();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedStatus == 'الكل'
                      ? Colors.white.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: _selectedStatus == 'الكل'
                      ? Border.all(color: Colors.white.withOpacity(0.25))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                        ),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إجمالي العملاء المحتملين',
                            style: GoogleFonts.cairo(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_kpiCount('الكل')}',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedStatus == 'الكل')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'مفعّل',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Status mini cards — clickable
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _statuses.where((s) => s['label'] != 'الكل').length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filtered = _statuses
                      .where((s) => s['label'] != 'الكل')
                      .toList();
                  final item = filtered[index];
                  final label = item['label'] as String;
                  final color = item['color'] as Color;
                  final icon = item['icon'] as IconData;
                  final count = _kpiCount(label);
                  final isSelected = _selectedStatus == label;

                  return GestureDetector(
                    onTap: () {
                      setState(
                        () => _selectedStatus = isSelected ? 'الكل' : label,
                      );
                      _fetchLeads();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.18)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(
                                color: color.withOpacity(0.6),
                                width: 1.5,
                              )
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 13,
                                color: isSelected ? color : Colors.white54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$count',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: GoogleFonts.cairo(
                              color: isSelected ? Colors.white : Colors.white54,
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // FILTER SECTION
  // ══════════════════════════════════════════════
  Widget _buildFilterSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0f172a)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFe4eaf3),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) {
                        setState(() {});
                        _onSearchChanged();
                      },
                      onSubmitted: (_) => _fetchLeads(),
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0f172a),
                      ),
                      decoration: InputDecoration(
                        hintText: 'اسم · موبايل · مدينة · نوع مشروع · حملة...',
                        hintStyle: GoogleFonts.cairo(
                          fontSize: 12,
                          color: const Color(0xFF94a3b8),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF94a3b8),
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Color(0xFF94a3b8),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                  _fetchLeads();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionIcon(
                  icon: Icons.sort_rounded,
                  isDark: isDark,
                  onTap: () => _showSortSheet(isDark),
                ),
                const SizedBox(width: 6),
                _buildActionIcon(
                  icon: Icons.tune_rounded,
                  isDark: isDark,
                  badge: _hasActiveFilters,
                  onTap: () => _showAdvancedFilters(isDark),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Date filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _dateFilters.map((df) {
                  final label = df['label'] as String;
                  final icon = df['icon'] as IconData;
                  final isSelected = _dateFilter == label;

                  return Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: GestureDetector(
                      onTap: () {
                        if (label == 'مخصص') {
                          _pickCustomDateRange();
                        } else {
                          setState(() {
                            _dateFilter = label;
                            _customDateRange = null;
                          });
                          _fetchLeads();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563eb).withOpacity(0.12)
                              : (isDark
                                    ? const Color(0xFF0f172a)
                                    : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563eb)
                                : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFe4eaf3)),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 13,
                              color: isSelected
                                  ? const Color(0xFF2563eb)
                                  : const Color(0xFF94a3b8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _dateFilter == 'مخصص' &&
                                      label == 'مخصص' &&
                                      _customDateRange != null
                                  ? '${_customDateRange!.start.day}/${_customDateRange!.start.month} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}'
                                  : label,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF2563eb)
                                    : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Status chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuses.map((status) {
                  final label = status['label'] as String;
                  final color = status['color'] as Color;
                  final icon = status['icon'] as IconData;
                  final isSelected = _selectedStatus == label;

                  return Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedStatus = label);
                        _fetchLeads();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.15)
                              : (isDark
                                    ? const Color(0xFF0f172a)
                                    : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFe4eaf3)),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 14,
                              color: isSelected
                                  ? color
                                  : const Color(0xFF94a3b8),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: GoogleFonts.cairo(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? color
                                    : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // City / Project / Employee quick filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDropdownFilterChip(
                    isDark: isDark,
                    icon: Icons.location_city_rounded,
                    label: _selectedCity == 'الكل' ? 'المدينة' : _selectedCity,
                    active: _selectedCity != 'الكل',
                    onTap: () => _pickStringFilter(
                      title: 'المدينة',
                      options: ['الكل', ..._cities],
                      current: _selectedCity,
                      onSelected: (v) {
                        setState(() => _selectedCity = v);
                        _fetchLeads();
                      },
                    ),
                  ),
                  const SizedBox(width: 7),
                  _buildDropdownFilterChip(
                    isDark: isDark,
                    icon: Icons.category_rounded,
                    label: _selectedProjectType == 'الكل'
                        ? 'نوع المشروع'
                        : _selectedProjectType,
                    active: _selectedProjectType != 'الكل',
                    onTap: () => _pickStringFilter(
                      title: 'نوع المشروع',
                      options: ['الكل', ..._projectTypes],
                      current: _selectedProjectType,
                      onSelected: (v) {
                        setState(() => _selectedProjectType = v);
                        _fetchLeads();
                      },
                    ),
                  ),
                  if (_canPickEmployee) ...[
                    const SizedBox(width: 7),
                    _buildDropdownFilterChip(
                      isDark: isDark,
                      icon: Icons.badge_outlined,
                      label: _selectedEmployeeId == null
                          ? 'الموظف'
                          : _selectedEmployeeLabel,
                      active: _selectedEmployeeId != null,
                      onTap: () => _pickEmployeeFilter(isDark),
                    ),
                  ] else if (_isMyLeads) ...[
                    const SizedBox(width: 7),
                    _buildDropdownFilterChip(
                      isDark: isDark,
                      icon: Icons.assignment_ind_rounded,
                      label: 'مسنَدة لي',
                      active: true,
                      onTap: () {},
                    ),
                  ],
                ],
              ),
            ),
            if (_isMyLeads && _perms.employeeId == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: Text(
                    'حسابك غير مربوط بموظف (employeeID). تواصل مع الإدارة لربط المستخدم بموظف حتى تظهر My Leads.',
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilterChip({
    required bool isDark,
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = const Color(0xFF0ea5e9);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? color.withOpacity(0.12)
              : (isDark ? const Color(0xFF0f172a) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? color
                : (isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3)),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? color : const Color(0xFF94a3b8),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active
                      ? color
                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: active ? color : const Color(0xFF94a3b8),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStringFilter({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) async {
    final isDark = ThemeService().isDarkMode;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.65,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFcbd5e1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final v = options[i];
                  final sel = v == current;
                  return ListTile(
                    title: Text(
                      v,
                      style: GoogleFonts.cairo(
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    trailing: sel
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF2563eb),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelected(v);
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

  Future<void> _pickEmployeeFilter(bool isDark) async {
    if (!_canPickEmployee) return;
    if (_employees.isEmpty) await _loadEmployees();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFcbd5e1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'فلتر بالموظف',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                _selectedEmployeeId == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: const Color(0xFF2563eb),
              ),
              title: Text(
                'كل الموظفين',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _selectedEmployeeId = null);
                _fetchLeads();
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _employees.length,
                itemBuilder: (_, i) {
                  final e = _employees[i] as Map;
                  final id = e['EmployeeId'] ?? e['EmployeeID'];
                  final idInt = id is int ? id : int.tryParse('$id');
                  final sel = idInt != null && idInt == _selectedEmployeeId;
                  return ListTile(
                    leading: Icon(
                      sel
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: const Color(0xFF2563eb),
                    ),
                    title: Text(
                      '${e['FullName'] ?? ''}',
                      style: GoogleFonts.cairo(
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    subtitle: e['Department'] != null
                        ? Text(
                            '${e['Department']}',
                            style: GoogleFonts.cairo(fontSize: 11),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedEmployeeId = idInt);
                      _fetchLeads();
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

  Widget _buildActionIcon({
    required IconData icon,
    required bool isDark,
    bool badge = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0f172a) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: badge
                    ? const Color(0xFF2563eb).withOpacity(0.5)
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFe4eaf3)),
              ),
            ),
            child: Icon(
              icon,
              color: badge
                  ? const Color(0xFF2563eb)
                  : (isDark ? Colors.white70 : const Color(0xFF64748b)),
              size: 20,
            ),
          ),
          if (badge && icon == Icons.tune_rounded && _activeFilterCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563eb),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$_activeFilterCount',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // RESULTS BAR
  // ══════════════════════════════════════════════
  Widget _buildResultsBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1 — count + sort
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: const Color(0xFF64748b),
                    ),
                    children: [
                      const TextSpan(text: 'عرض '),
                      TextSpan(
                        text: '${_leads.length}',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0f172a),
                        ),
                      ),
                      const TextSpan(text: ' عميل محتمل'),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showSortSheet(isDark),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1e293b) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFe4eaf3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sort_rounded,
                        size: 13,
                        color: Color(0xFF64748b),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _sortBy,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Row 2 — active filter chips
          if (_hasActiveFilters) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedStatus != 'الكل')
                    _buildActiveFilterChip(
                      label: _selectedStatus,
                      color: _getStatusColor(_selectedStatus),
                      isDark: isDark,
                      onRemove: () {
                        setState(() => _selectedStatus = 'الكل');
                        _fetchLeads();
                      },
                    ),
                  if (_dateFilter != 'الكل')
                    _buildActiveFilterChip(
                      label: _dateFilter == 'مخصص' && _customDateRange != null
                          ? '${_customDateRange!.start.day}/${_customDateRange!.start.month} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}'
                          : _dateFilter,
                      color: const Color(0xFF2563eb),
                      isDark: isDark,
                      onRemove: () {
                        setState(() {
                          _dateFilter = 'الكل';
                          _customDateRange = null;
                        });
                        _fetchLeads();
                      },
                    ),
                  if (_selectedCity != 'الكل')
                    _buildActiveFilterChip(
                      label: _selectedCity,
                      color: const Color(0xFF0ea5e9),
                      isDark: isDark,
                      onRemove: () {
                        setState(() => _selectedCity = 'الكل');
                        _fetchLeads();
                      },
                    ),
                  if (_selectedProjectType != 'الكل')
                    _buildActiveFilterChip(
                      label: _selectedProjectType,
                      color: const Color(0xFF8b5cf6),
                      isDark: isDark,
                      onRemove: () {
                        setState(() => _selectedProjectType = 'الكل');
                        _fetchLeads();
                      },
                    ),
                  if (_canPickEmployee && _selectedEmployeeId != null)
                    _buildActiveFilterChip(
                      label: _selectedEmployeeLabel,
                      color: const Color(0xFF059669),
                      isDark: isDark,
                      onRemove: () {
                        setState(() => _selectedEmployeeId = null);
                        _fetchLeads();
                      },
                    ),
                  if (_isMyLeads)
                    _buildActiveFilterChip(
                      label: 'مسنَدة لي',
                      color: const Color(0xFF7C3AED),
                      isDark: isDark,
                      onRemove: () {},
                    ),
                  if (_searchController.text.trim().isNotEmpty)
                    _buildActiveFilterChip(
                      label: '"${_searchController.text.trim()}"',
                      color: const Color(0xFF64748b),
                      isDark: isDark,
                      onRemove: () {
                        _searchController.clear();
                        setState(() {});
                        _fetchLeads();
                      },
                    ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _clearAllFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF450a0a)
                            : const Color(0xFFfef2f2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFfca5a5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.restart_alt_rounded,
                            size: 13,
                            color: Color(0xFFdc2626),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'مسح الكل',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFdc2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, size: 10, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0f172a)
                    : const Color(0xFFf1f5f9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 32,
                color: Color(0xFF94a3b8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج مطابقة',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0f172a),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'جرّب تغيير كلمات البحث أو إعادة تعيين الفلاتر.',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: const Color(0xFF64748b),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            if (_hasActiveFilters)
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(
                  'مسح الفلاتر',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563eb),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // LEAD CARD
  // ══════════════════════════════════════════════
  Widget _buildLeadCard(dynamic lead, bool isDark) {
    final status = lead['LeadStatus'] ?? 'جديد';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final name = lead['FullName'] ?? 'بدون اسم';
    final phone = lead['Phone'] ?? '';

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDetail(lead),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── شريط الحالة المتدرج ─────────────────────
              Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [statusColor, statusColor.withValues(alpha: 0.25)],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── الاسم + الحالة ─────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // أفاتار بتدرج لون الحالة
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                statusColor,
                                Color.lerp(statusColor, Colors.black, 0.25)!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.cairo(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: GoogleFonts.cairo(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: scheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              if (phone.isNotEmpty)
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.phone_rounded,
                                        size: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          phone,
                                          style: GoogleFonts.cairo(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if ((lead['Phone2'] ?? '').toString().isNotEmpty)
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    '${lead['Phone2']}',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // شارة الحالة (Pill)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                status,
                                style: GoogleFonts.cairo(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── الـ chips ───────────────────────────
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if ((lead['Platform'] ?? '').toString().isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.public,
                            text: '${lead['Platform']}',
                            isDark: isDark,
                          ),
                        _buildMetaChip(
                          icon: Icons.campaign_rounded,
                          text:
                              lead['CampaignName'] ??
                              lead['AdName'] ??
                              'إعلان عام',
                          isDark: isDark,
                        ),
                        if ((lead['City'] ?? '').toString().isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.location_city_rounded,
                            text: '${lead['City']}',
                            isDark: isDark,
                          ),
                        if ((lead['ProjectType'] ?? '').toString().isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.category_rounded,
                            text: '${lead['ProjectType']}',
                            isDark: isDark,
                          ),
                        if ((lead['BestTimeToReach'] ?? '')
                            .toString()
                            .isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.access_time_filled_rounded,
                            text: 'أفضل وقت: ${lead['BestTimeToReach']}',
                            isDark: isDark,
                            highlight: true,
                          ),
                        if ((lead['Budget'] ?? '').toString().isNotEmpty)
                          _buildMetaChip(
                            icon: Icons.payments_outlined,
                            text: '${lead['Budget']}',
                            isDark: isDark,
                          ),
                        _buildMetaChip(
                          icon: Icons.calendar_today_rounded,
                          text:
                              '${lead['LeadDate'] ?? lead['CreatedAt'] ?? ''}',
                          isDark: isDark,
                        ),
                        _buildMetaChip(
                          icon: Icons.person_outline_rounded,
                          text:
                              (lead['AssignedEmployeeName'] ??
                                  lead['EmployeeName']) ??
                              'غير مسند',
                          isDark: isDark,
                          highlight:
                              (lead['AssignedEmployeeName'] ??
                                  lead['EmployeeName']) !=
                              null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── أزرار الإجراءات ────────────────────
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          children: [
                            if (phone.isNotEmpty) ...[
                              _buildQuickAction(
                                icon: Icons.phone_rounded,
                                color: Colors.green,
                                isDark: isDark,
                                tooltip: 'اتصال',
                                onTap: () => _launchTel(phone),
                              ),
                              const SizedBox(width: 8),
                              _buildQuickAction(
                                icon: FontAwesomeIcons.whatsapp.data,
                                color: const Color(0xFF25D366),
                                isDark: isDark,
                                tooltip: 'واتساب',
                                onTap: () => _launchWa(phone),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (_canEditLead &&
                                status != LeadsService.statusConverted &&
                                status != LeadsService.statusRejected) ...[
                              _buildQuickAction(
                                icon: Icons.assignment_ind_rounded,
                                color: Colors.purple,
                                isDark: isDark,
                                tooltip: 'إسناد',
                                onTap: () => _quickAssign(lead),
                              ),
                              const SizedBox(width: 8),
                              if (LeadsService.canConvert(
                                Map<String, dynamic>.from(lead as Map),
                              )) ...[
                                _buildQuickAction(
                                  icon: Icons.transform_rounded,
                                  color: Colors.teal,
                                  isDark: isDark,
                                  tooltip: 'تحويل',
                                  onTap: () => _quickConvert(lead),
                                ),
                                const SizedBox(width: 8),
                              ],
                              _buildQuickAction(
                                icon: Icons.cancel_outlined,
                                color: Colors.red,
                                isDark: isDark,
                                tooltip: _perms.canRejectLeadDirectly
                                    ? 'رفض'
                                    : 'طلب رفض',
                                onTap: () => _quickReject(lead),
                              ),
                              const SizedBox(width: 8),
                            ],
                            _buildQuickAction(
                              icon: Icons.open_in_new_rounded,
                              color: const Color(0xFF2563eb),
                              isDark: isDark,
                              tooltip: 'التفاصيل',
                              onTap: () => _openDetail(lead),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    required bool isDark,
    bool highlight = false,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12.5,
            color: highlight ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 10.5,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required Color color,
    required bool isDark,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: color.withValues(alpha: 0.25),
          highlightColor: color.withValues(alpha: 0.12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              ),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // SORT BOTTOM SHEET
  // ══════════════════════════════════════════════
  void _showSortSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFcbd5e1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Text(
              'ترتيب النتائج',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0f172a),
              ),
            ),
            const SizedBox(height: 14),
            ..._sortOptions.map(
              (option) => ListTile(
                leading: Icon(
                  _sortBy == option
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _sortBy == option
                      ? const Color(0xFF2563eb)
                      : const Color(0xFF94a3b8),
                  size: 20,
                ),
                title: Text(
                  option,
                  style: GoogleFonts.cairo(
                    fontWeight: _sortBy == option
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0f172a),
                  ),
                ),
                onTap: () {
                  setState(() {
                    _sortBy = option;
                    _sortLeads();
                  });
                  Navigator.pop(ctx);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ADVANCED FILTERS
  // ══════════════════════════════════════════════
  void _showAdvancedFilters(bool isDark) {
    String tempStatus = _selectedStatus;
    String tempSort = _sortBy;
    String tempDate = _dateFilter;
    String tempCity = _selectedCity;
    String tempProject = _selectedProjectType;
    int? tempSourceId = _selectedSourceId;
    int? tempAdTypeId = _selectedAdTypeId;
    int? tempEmp = _selectedEmployeeId;

    Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        t,
        style: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF0f172a),
        ),
      ),
    );

    Widget choiceChip({
      required String label,
      required bool selected,
      required Color color,
      IconData? icon,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.15)
                : (isDark ? const Color(0xFF0f172a) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color
                  : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFe4eaf3)),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? color : const Color(0xFF94a3b8),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? color
                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.78,
            maxChildSize: 0.92,
            minChildSize: 0.45,
            builder: (ctx, scrollController) => Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1e293b) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFcbd5e1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'فلاتر متقدمة',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0f172a),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempStatus = 'الكل';
                              tempSort = 'الأحدث';
                              tempDate = 'الكل';
                              tempCity = 'الكل';
                              tempProject = 'الكل';
                              tempSourceId = null;
                              tempAdTypeId = null;
                              tempEmp = null;
                            });
                          },
                          child: Text(
                            'إعادة تعيين',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFdc2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        sectionTitle('الحالة'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _statuses.map((s) {
                            final label = s['label'] as String;
                            return choiceChip(
                              label: label,
                              selected: tempStatus == label,
                              color: s['color'] as Color,
                              icon: s['icon'] as IconData,
                              onTap: () =>
                                  setSheetState(() => tempStatus = label),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),
                        sectionTitle('المدينة'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['الكل', ..._cities].map((c) {
                            return choiceChip(
                              label: c,
                              selected: tempCity == c,
                              color: const Color(0xFF0ea5e9),
                              icon: Icons.location_city_rounded,
                              onTap: () => setSheetState(() => tempCity = c),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),
                        sectionTitle('نوع المشروع'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['الكل', ..._projectTypes].map((c) {
                            return choiceChip(
                              label: c,
                              selected: tempProject == c,
                              color: const Color(0xFF8b5cf6),
                              icon: Icons.category_rounded,
                              onTap: () => setSheetState(() => tempProject = c),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),
                        sectionTitle('المصدر'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            choiceChip(
                              label: 'كل المصادر',
                              selected: tempSourceId == null,
                              color: const Color(0xFF0ea5e9),
                              icon: Icons.contact_phone_rounded,
                              onTap: () =>
                                  setSheetState(() => tempSourceId = null),
                            ),
                            ..._sources.map((s) {
                              final label = (s['SourceNameAr'] ??
                                      s['SourceName'] ??
                                      '')
                                  .toString();
                              return choiceChip(
                                label: label,
                                selected: tempSourceId ==
                                    (s['SourceID'] as num?)?.toInt(),
                                color: const Color(0xFF0ea5e9),
                                icon: Icons.contact_phone_rounded,
                                onTap: () => setSheetState(() =>
                                    tempSourceId =
                                        (s['SourceID'] as num?)?.toInt()),
                              );
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 22),
                        sectionTitle('الحملة الإعلانية'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            choiceChip(
                              label: 'كل الحملات',
                              selected: tempAdTypeId == null,
                              color: const Color(0xFF8b5cf6),
                              icon: Icons.campaign_rounded,
                              onTap: () =>
                                  setSheetState(() => tempAdTypeId = null),
                            ),
                            ..._adTypes.map((a) {
                              final label = (a['AdTypeNameAr'] ??
                                      a['AdTypeName'] ??
                                      '')
                                  .toString();
                              return choiceChip(
                                label: label,
                                selected: tempAdTypeId ==
                                    (a['AdTypeID'] as num?)?.toInt(),
                                color: const Color(0xFF8b5cf6),
                                icon: Icons.campaign_rounded,
                                onTap: () => setSheetState(() =>
                                    tempAdTypeId =
                                        (a['AdTypeID'] as num?)?.toInt()),
                              );
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 22),
                        if (_canPickEmployee) ...[
                          sectionTitle('الموظف'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              choiceChip(
                                label: 'كل الموظفين',
                                selected: tempEmp == null,
                                color: const Color(0xFF059669),
                                icon: Icons.groups_rounded,
                                onTap: () =>
                                    setSheetState(() => tempEmp = null),
                              ),
                              ..._employees.map((e) {
                                final m = e as Map;
                                final id = m['EmployeeId'] ?? m['EmployeeID'];
                                final idInt = id is int
                                    ? id
                                    : int.tryParse('$id');
                                return choiceChip(
                                  label: '${m['FullName'] ?? ''}',
                                  selected: tempEmp != null && tempEmp == idInt,
                                  color: const Color(0xFF059669),
                                  icon: Icons.person_rounded,
                                  onTap: () =>
                                      setSheetState(() => tempEmp = idInt),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 22),
                        ],
                        sectionTitle('الفترة الزمنية'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _dateFilters.map((df) {
                            final label = df['label'] as String;
                            final icon = df['icon'] as IconData;
                            return choiceChip(
                              label: label,
                              selected: tempDate == label,
                              color: const Color(0xFF2563eb),
                              icon: icon,
                              onTap: () {
                                if (label == 'مخصص') {
                                  Navigator.pop(ctx);
                                  _pickCustomDateRange();
                                } else {
                                  setSheetState(() => tempDate = label);
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 22),
                        sectionTitle('ترتيب'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _sortOptions.map((option) {
                            return choiceChip(
                              label: option,
                              selected: tempSort == option,
                              color: const Color(0xFF2563eb),
                              onTap: () =>
                                  setSheetState(() => tempSort = option),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFe4eaf3),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedStatus = tempStatus;
                            _sortBy = tempSort;
                            _dateFilter = tempDate;
                            _selectedCity = tempCity;
                            _selectedProjectType = tempProject;
                            _selectedSourceId = tempSourceId;
                            _selectedAdTypeId = tempAdTypeId;
                            _selectedEmployeeId = _canPickEmployee
                                ? tempEmp
                                : (_isMyLeads ? _perms.employeeId : tempEmp);
                            if (tempDate != 'مخصص') _customDateRange = null;
                          });
                          _fetchLeads();
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563eb),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'تطبيق الفلاتر',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
