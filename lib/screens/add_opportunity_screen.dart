import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/network/api_client.dart';
import '../services/app_colors.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../widgets/speech_text_field.dart';

class AddOpportunityScreen extends StatefulWidget {
  final int userId;
  final String username;
  final Map<String, dynamic>? opportunityToEdit;

  const AddOpportunityScreen({
    super.key,
    required this.userId,
    required this.username,
    this.opportunityToEdit,
  });

  @override
  State<AddOpportunityScreen> createState() =>
      _AddOpportunityScreenState();
}

class _AddOpportunityScreenState extends State<AddOpportunityScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ApiClient _api = ApiClient.instance;
  final PermissionService _permissions = PermissionService();

  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _phone1Controller = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _interestedProductController =
      TextEditingController();
  final TextEditingController _expectedValueController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _guidanceController = TextEditingController();
  final TextEditingController _lostNotesController = TextEditingController();

  List<dynamic> sources = <dynamic>[];
  List<dynamic> stages = <dynamic>[];
  List<dynamic> statuses = <dynamic>[];
  List<dynamic> adTypes = <dynamic>[];
  List<dynamic> categories = <dynamic>[];
  List<dynamic> employees = <dynamic>[];
  List<dynamic> lostReasons = <dynamic>[];
  List<dynamic> taskTypes = <dynamic>[];

  int? selectedSourceId;
  int? selectedStageId;
  int? selectedStatusId;
  int? selectedAdTypeId;
  int? selectedCategoryId;
  int? selectedEmployeeId;
  int? selectedLostReasonId;
  int? selectedTaskTypeId;
  DateTime? selectedFirstContactDate;
  DateTime? selectedFollowUpDate;
  TimeOfDay? selectedFollowUpTime;

  int? _initialStageId;
  int? _initialTaskTypeId;
  DateTime? _initialFollowUpDate;
  TimeOfDay? _initialFollowUpTime;

  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _isSearchingClient = false;
  bool _clientFound = false;
  bool _showPhone2 = false;
  bool _showAddress = false;
  bool _showEmail = false;
  int? _existingClientId;
  String? _loadError;
  String? _lastPhoneQuery;
  Timer? _phoneSearchDebounce;

  bool get isEdit => widget.opportunityToEdit != null;
  bool get _isDark => ThemeService().isDarkMode;
  bool get _isLostStage => selectedStageId == 4 || selectedStageId == 5;
  bool get _isWonStage => selectedStageId == 3;
  bool get _isClosedStage =>
      selectedStageId == 3 || selectedStageId == 4 || selectedStageId == 5;
  bool get _needsFollowUp => !_isClosedStage;
  bool get _canDirectCloseOpportunity =>
      _permissions.isAdmin ||
      _permissions.isSalesManager ||
      _permissions.isGeneralManager;

  Color get _surfaceColor => AppColors.card(_isDark);
  Color get _textColor => AppColors.text(_isDark);
  Color get _secondaryTextColor => AppColors.textSecondary(_isDark);

  @override
  void initState() {
    super.initState();
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    selectedFirstContactDate = today;
    selectedFollowUpDate = today.add(const Duration(days: 1));
    selectedFollowUpTime = const TimeOfDay(hour: 10, minute: 0);
    _expectedValueController.addListener(_refreshExpectedValuePreview);
    _loadAllData();
  }

  @override
  void dispose() {
    _phoneSearchDebounce?.cancel();
    _expectedValueController.removeListener(_refreshExpectedValuePreview);
    _clientNameController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _interestedProductController.dispose();
    _expectedValueController.dispose();
    _locationController.dispose();
    _summaryController.dispose();
    _notesController.dispose();
    _guidanceController.dispose();
    _lostNotesController.dispose();
    super.dispose();
  }

  void _refreshExpectedValuePreview() {
    if (mounted) setState(() {});
  }

  int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  int? _readIntFrom(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        return _readInt(data[key]);
      }
    }
    return null;
  }

  String _readStringFrom(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = data[key];
      if (value != null) return value.toString();
    }
    return '';
  }

  DateTime? _readDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  List<dynamic> _decodeList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) {
      return List<dynamic>.from(data['data'] as List);
    }
    return <dynamic>[];
  }

  Future<List<dynamic>> _fetchLookup(String path) async {
    final response = await _api.get(path);
    return _decodeList(_api.decode(response));
  }

  Future<List<dynamic>> _fetchSources() =>
      _fetchLookup('/api/opportunities/sources');

  Future<List<dynamic>> _fetchStages() =>
      _fetchLookup('/api/opportunities/stages');

  Future<List<dynamic>> _fetchStatuses() =>
      _fetchLookup('/api/opportunities/statuses');

  Future<List<dynamic>> _fetchAdTypes() =>
      _fetchLookup('/api/opportunities/ad-types');

  Future<List<dynamic>> _fetchCategories() =>
      _fetchLookup('/api/opportunities/categories');

  Future<List<dynamic>> _fetchEmployees() =>
      _fetchLookup('/api/opportunities/employees');

  Future<List<dynamic>> _fetchLostReasons() =>
      _fetchLookup('/api/opportunities/lost-reasons');

  Future<List<dynamic>> _fetchTaskTypes() =>
      _fetchLookup('/api/opportunities/task-types');

  Future<int?> _fetchCurrentEmployee() async {
    final int? employeeFromSession = _permissions.employeeId;
    if (employeeFromSession != null) return employeeFromSession;

    final response = await _api.get(
      '/api/auth/users/${widget.userId}/employee',
    );
    final dynamic data = _api.decode(response);
    if (data is Map) {
      return _readInt(data['employeeID'] ?? data['employeeId']);
    }
    return null;
  }

  Future<void> _loadAllData() async {
    if (mounted) {
      setState(() {
        _isLoadingData = true;
        _loadError = null;
      });
    }

    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _fetchSources(),
        _fetchStages(),
        _fetchStatuses(),
        _fetchAdTypes(),
        _fetchCategories(),
        _fetchEmployees(),
        _fetchLostReasons(),
        _fetchTaskTypes(),
        _fetchCurrentEmployee(),
      ]);

      if (!mounted) return;

      sources = results[0] as List<dynamic>;
      stages = results[1] as List<dynamic>;
      statuses = results[2] as List<dynamic>;
      adTypes = results[3] as List<dynamic>;
      categories = results[4] as List<dynamic>;
      employees = results[5] as List<dynamic>;
      lostReasons = results[6] as List<dynamic>;
      taskTypes = results[7] as List<dynamic>;

      final int? currentEmployee = results[8] as int?;
      if (selectedEmployeeId == null && currentEmployee != null) {
        selectedEmployeeId = currentEmployee;
      }

      if (isEdit) {
        _fillDataForEdit();
      } else {
        _setNewOpportunityDefaults();
      }

      setState(() => _isLoadingData = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        _loadError = error.toString();
      });
    }
  }

  void _setNewOpportunityDefaults() {
    if (selectedStageId == null && stages.isNotEmpty) {
      final dynamic firstStage = stages.firstWhere(
        (dynamic stage) =>
            _readInt(stage['StageOrder'] ?? stage['stageOrder']) == 1,
        orElse: () => stages.first,
      );
      selectedStageId = _readInt(
        firstStage['StageID'] ?? firstStage['StageId'],
      );
    }

    if (selectedStatusId == null && statuses.length == 1) {
      selectedStatusId = _readInt(
        statuses.first['StatusID'] ?? statuses.first['StatusId'],
      );
    }

    if (selectedTaskTypeId == null && taskTypes.length == 1) {
      selectedTaskTypeId = _readInt(
        taskTypes.first['TaskTypeID'] ?? taskTypes.first['TaskTypeId'],
      );
    }
  }

  void _fillDataForEdit() {
    final Map<String, dynamic> opportunity = widget.opportunityToEdit!;

    _clientFound = true;
    _existingClientId = _readIntFrom(
      opportunity,
      <String>['PartyID', 'PartyId', 'partyId'],
    );

    _clientNameController.text = _readStringFrom(
      opportunity,
      <String>['ClientName', 'PartyName', 'clientName', 'partyName'],
    );
    _phone1Controller.text = _readStringFrom(
      opportunity,
      <String>['Phone1', 'Phone', 'phone1', 'phone'],
    );
    _phone2Controller.text = _readStringFrom(
      opportunity,
      <String>['Phone2', 'phone2'],
    );
    _addressController.text = _readStringFrom(
      opportunity,
      <String>['Address', 'address'],
    );
    _emailController.text = _readStringFrom(
      opportunity,
      <String>['Email', 'email'],
    );
    _interestedProductController.text = _readStringFrom(
      opportunity,
      <String>['InterestedProduct', 'interestedProduct'],
    );
    _expectedValueController.text = _readStringFrom(
      opportunity,
      <String>['ExpectedValue', 'expectedValue'],
    );
    _locationController.text = _readStringFrom(
      opportunity,
      <String>['Location', 'location'],
    );
    _summaryController.text = _readStringFrom(
      opportunity,
      <String>['Summary', 'summary', 'Notes', 'notes'],
    );
    _notesController.text = _readStringFrom(
      opportunity,
      <String>['AdditionalNotes', 'additionalNotes'],
    );
    _guidanceController.text = _readStringFrom(
      opportunity,
      <String>['Guidance', 'guidance'],
    );
    _lostNotesController.text = _readStringFrom(
      opportunity,
      <String>['LostNotes', 'lostNotes'],
    );

    selectedSourceId = _readIntFrom(
      opportunity,
      <String>['SourceID', 'SourceId', 'sourceId'],
    );
    selectedStageId = _readIntFrom(
      opportunity,
      <String>['StageID', 'StageId', 'stageId'],
    );
    selectedStatusId = _readIntFrom(
      opportunity,
      <String>['StatusID', 'StatusId', 'statusId'],
    );
    selectedAdTypeId = _readIntFrom(
      opportunity,
      <String>['AdTypeID', 'AdTypeId', 'adTypeId'],
    );
    selectedCategoryId = _readIntFrom(
      opportunity,
      <String>['CategoryID', 'CategoryId', 'categoryId'],
    );
    selectedEmployeeId = _readIntFrom(
          opportunity,
          <String>['EmployeeID', 'EmployeeId', 'employeeId'],
        ) ??
        selectedEmployeeId;
    selectedLostReasonId = _readIntFrom(
      opportunity,
      <String>['LostReasonID', 'LostReasonId', 'lostReasonId'],
    );
    selectedTaskTypeId = _readIntFrom(
      opportunity,
      <String>['TaskTypeID', 'TaskTypeId', 'taskTypeId'],
    );

    selectedFirstContactDate = _readDate(
          opportunity['FirstContactDate'] ?? opportunity['firstContactDate'],
        ) ??
        selectedFirstContactDate;

    final DateTime? followUp = _readDate(
      opportunity['NextFollowUpDate'] ?? opportunity['nextFollowUpDate'],
    );
    if (followUp != null) {
      selectedFollowUpDate = DateUtils.dateOnly(followUp);
      selectedFollowUpTime = TimeOfDay.fromDateTime(followUp);
    } else if (_isClosedStage) {
      selectedFollowUpDate = null;
      selectedFollowUpTime = null;
    }

    _initialStageId = selectedStageId;
    _initialTaskTypeId = selectedTaskTypeId;
    _initialFollowUpDate = selectedFollowUpDate;
    _initialFollowUpTime = selectedFollowUpTime;

    _showPhone2 = _phone2Controller.text.trim().isNotEmpty;
    _showAddress = _addressController.text.trim().isNotEmpty;
    _showEmail = _emailController.text.trim().isNotEmpty;
  }

  void _queueClientSearch(String rawPhone) {
    if (isEdit) return;
    final String phone = rawPhone.replaceAll(RegExp(r'\D'), '');
    _phoneSearchDebounce?.cancel();

    if (phone.length < 8) {
      if (_clientFound) {
        setState(() {
          _clientFound = false;
          _existingClientId = null;
        });
      }
      return;
    }

    _phoneSearchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchClientByPhone(phone),
    );
  }

  Future<void> _searchClientByPhone(String phone) async {
    if (isEdit || phone == _lastPhoneQuery) return;
    _lastPhoneQuery = phone;

    if (mounted) setState(() => _isSearchingClient = true);
    try {
      final response = await _api.get(
        '/api/opportunities/search-by-phone',
        query: <String, dynamic>{'phone': phone},
      );
      final dynamic decoded = _api.decode(response);
      final Map<String, dynamic> data = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);

      if (!mounted || _phone1Controller.text.replaceAll(RegExp(r'\D'), '') != phone) {
        return;
      }

      final bool found = data['found'] == true && data['client'] is Map;
      setState(() {
        if (found) {
          final Map<String, dynamic> client =
              Map<String, dynamic>.from(data['client'] as Map);
          _clientFound = true;
          _existingClientId = _readInt(
            client['PartyID'] ?? client['PartyId'],
          );
          _clientNameController.text =
              (client['PartyName'] ?? client['ClientName'] ?? '').toString();
          _phone2Controller.text = (client['Phone2'] ?? '').toString();
          _addressController.text = (client['Address'] ?? '').toString();
          _emailController.text = (client['Email'] ?? '').toString();
          _showPhone2 = _phone2Controller.text.trim().isNotEmpty;
          _showAddress = _addressController.text.trim().isNotEmpty;
          _showEmail = _emailController.text.trim().isNotEmpty;
        } else {
          if (_clientFound) {
            _clientNameController.clear();
            _phone2Controller.clear();
            _addressController.clear();
            _emailController.clear();
          }
          _clientFound = false;
          _existingClientId = null;
        }
      });
    } catch (error) {
      if (mounted) {
        _showSnack('تعذر التحقق من رقم الهاتف. يمكنك استكمال البيانات.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSearchingClient = false);
    }
  }

  Future<void> _pickFirstContactDate() async {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime initial = selectedFirstContactDate == null ||
            selectedFirstContactDate!.isAfter(today)
        ? today
        : DateUtils.dateOnly(selectedFirstContactDate!);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'اختيار تاريخ أول تواصل',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
      builder: _datePickerTheme,
    );

    if (picked != null && mounted) {
      setState(() => selectedFirstContactDate = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _pickFollowUpDate() async {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime initial = selectedFollowUpDate == null ||
            selectedFollowUpDate!.isBefore(today)
        ? today.add(const Duration(days: 1))
        : DateUtils.dateOnly(selectedFollowUpDate!);

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'اختيار تاريخ المتابعة',
      cancelText: 'إلغاء',
      confirmText: 'التالي',
      builder: _datePickerTheme,
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime:
          selectedFollowUpTime ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: 'اختيار وقت المتابعة',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
      builder: _timePickerTheme,
    );
    if (!mounted) return;

    setState(() {
      selectedFollowUpDate = DateUtils.dateOnly(date);
      selectedFollowUpTime =
          time ?? selectedFollowUpTime ?? const TimeOfDay(hour: 10, minute: 0);
    });
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.navy,
              secondary: AppColors.gold,
            ),
      ),
      child: child!,
    );
  }

  Widget _timePickerTheme(BuildContext context, Widget? child) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _datePickerTheme(context, child),
    );
  }

  void _clearFollowUp() {
    setState(() {
      selectedFollowUpDate = null;
      selectedFollowUpTime = null;
      selectedTaskTypeId = null;
    });
  }

  void _onStageChanged(int? stageId) {
    setState(() {
      selectedStageId = stageId;

      if (_isClosedStage) {
        selectedFollowUpDate = null;
        selectedFollowUpTime = null;
        selectedTaskTypeId = null;
      } else {
        final DateTime today = DateUtils.dateOnly(DateTime.now());
        if (selectedFollowUpDate == null ||
            selectedFollowUpDate!.isBefore(today)) {
          selectedFollowUpDate = today.add(const Duration(days: 1));
          selectedFollowUpTime = const TimeOfDay(hour: 10, minute: 0);
        }
      }

      if (!_isLostStage) {
        selectedLostReasonId = null;
        _lostNotesController.clear();
      }
    });
  }

  String? _validatePhone(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'رقم الهاتف مطلوب';
    if (digits.length < 8) return 'رقم الهاتف غير مكتمل';
    return null;
  }

  String? _validateEmail(String? value) {
    final String email = (value ?? '').trim();
    if (email.isEmpty) return null;
    final bool valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    return valid ? null : 'البريد الإلكتروني غير صحيح';
  }

  bool _validateWorkflow() {
    if (!isEdit && _existingClientId == null) {
      if (_clientNameController.text.trim().isEmpty) {
        _showSnack('أدخل اسم العميل', isError: true);
        return false;
      }
      if (_phone1Controller.text.trim().isEmpty) {
        _showSnack('أدخل رقم الهاتف', isError: true);
        return false;
      }
    }

    if (selectedSourceId == null) {
      _showSnack('حدد مصدر التواصل', isError: true);
      return false;
    }
    if (selectedStatusId == null) {
      _showSnack('اختر حالة التواصل', isError: true);
      return false;
    }
    if (selectedFirstContactDate == null) {
      _showSnack('حدد تاريخ أول تواصل', isError: true);
      return false;
    }
    if (selectedStageId == null) {
      _showSnack('اختر مرحلة الفرصة', isError: true);
      return false;
    }
    if (_isLostStage && selectedLostReasonId == null) {
      _showSnack('اختر سبب الإغلاق', isError: true);
      return false;
    }
    if (_summaryController.text.trim().isEmpty) {
      _showSnack('اكتب ملخص التواصل', isError: true);
      return false;
    }
    if (_needsFollowUp && selectedEmployeeId == null) {
      _showSnack('حدد الموظف المسؤول عن المتابعة', isError: true);
      return false;
    }
    if (_needsFollowUp && selectedTaskTypeId == null) {
      _showSnack('اختر نوع مهمة المتابعة القادمة', isError: true);
      return false;
    }
    if (_needsFollowUp && selectedFollowUpDate == null) {
      _showSnack('حدد موعد المتابعة القادمة', isError: true);
      return false;
    }

    final double? expectedValue = double.tryParse(
      _expectedValueController.text.replaceAll(',', '').trim(),
    );
    if (expectedValue != null && expectedValue < 0) {
      _showSnack('القيمة المتوقعة لا يمكن أن تكون سالبة', isError: true);
      return false;
    }

    return true;
  }

  DateTime? _buildFollowUpDateTime({
    DateTime? dateOverride,
    TimeOfDay? timeOverride,
  }) {
    final DateTime? date = dateOverride ?? selectedFollowUpDate;
    final TimeOfDay? time = timeOverride ?? selectedFollowUpTime;
    if (date == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 10,
      time?.minute ?? 0,
    );
  }

  String _combinedSummary() {
    final String summary = _summaryController.text.trim();
    final String additionalNotes = _notesController.text.trim();
    if (additionalNotes.isEmpty) return summary;
    return '$summary\n\nملاحظات إضافية:\n$additionalNotes';
  }

  Map<String, dynamic> _buildEditBody({
    int? stageOverride,
    int? taskTypeOverride,
    DateTime? followUpDateOverride,
    TimeOfDay? followUpTimeOverride,
  }) {
    final int stage = stageOverride ?? selectedStageId!;
    final bool stageIsLost = stage == 4 || stage == 5;
    final bool stageIsClosed = stage == 3 || stage == 4 || stage == 5;
    final DateTime? followUp = stageIsClosed
        ? null
        : _buildFollowUpDateTime(
            dateOverride: followUpDateOverride,
            timeOverride: followUpTimeOverride,
          );

    return <String, dynamic>{
      'employeeId': selectedEmployeeId,
      'sourceId': selectedSourceId,
      'adTypeId': selectedAdTypeId,
      'categoryId': selectedCategoryId,
      'stageId': stage,
      'statusId': selectedStatusId,
      'taskTypeId': stageIsClosed
          ? null
          : (taskTypeOverride ?? selectedTaskTypeId),
      'interestedProduct': _interestedProductController.text.trim(),
      'expectedValue': double.tryParse(
            _expectedValueController.text.replaceAll(',', '').trim(),
          ) ??
          0,
      'location': _locationController.text.trim(),
      'summary': _combinedSummary(),
      'notes': _combinedSummary(),
      'additionalNotes': _notesController.text.trim(),
      'guidance': _guidanceController.text.trim(),
      'firstContactDate': selectedFirstContactDate?.toIso8601String(),
      'nextFollowUpDate': followUp?.toIso8601String(),
      'lostReasonId': stageIsLost ? selectedLostReasonId : null,
      'lostNotes': stageIsLost ? _lostNotesController.text.trim() : null,
      'updatedBy': widget.username,
      'actorRole': _permissions.role ?? '',
    };
  }

  Map<String, dynamic> _buildCreateBody({
    int? stageOverride,
    bool includeClosureData = true,
  }) {
    final int stage = stageOverride ?? selectedStageId!;
    final bool stageIsLost = stage == 4 || stage == 5;
    final bool stageIsClosed = stage == 3 || stage == 4 || stage == 5;
    final DateTime? followUp =
        stageIsClosed ? null : _buildFollowUpDateTime();

    return <String, dynamic>{
      'isNewClient': _existingClientId == null,
      'clientName': _clientNameController.text.trim(),
      'phone1': _phone1Controller.text.trim(),
      'phone2': _phone2Controller.text.trim(),
      'address': _addressController.text.trim(),
      'email': _emailController.text.trim(),
      'partyId': _existingClientId,
      'employeeId': selectedEmployeeId,
      'sourceId': selectedSourceId,
      'adTypeId': selectedAdTypeId,
      'categoryId': selectedCategoryId,
      'stageId': stage,
      'statusId': selectedStatusId,
      'taskTypeId': stageIsClosed ? null : selectedTaskTypeId,
      'interestedProduct': _interestedProductController.text.trim(),
      'expectedValue': double.tryParse(
            _expectedValueController.text.replaceAll(',', '').trim(),
          ) ??
          0,
      'location': _locationController.text.trim(),
      'summary': _combinedSummary(),
      'notes': _combinedSummary(),
      'additionalNotes': _notesController.text.trim(),
      'guidance': _guidanceController.text.trim(),
      'firstContactDate': selectedFirstContactDate?.toIso8601String(),
      'nextFollowUpDate': followUp?.toIso8601String(),
      'lostReasonId': includeClosureData && stageIsLost
          ? selectedLostReasonId
          : null,
      'lostNotes': includeClosureData && stageIsLost
          ? _lostNotesController.text.trim()
          : null,
      'createdBy': widget.username,
      'actorRole': _permissions.role ?? '',
    };
  }

  int? _opportunityIdFromEdit() {
    final Map<String, dynamic>? data = widget.opportunityToEdit;
    if (data == null) return null;
    return _readIntFrom(
      data,
      <String>['OpportunityID', 'OpportunityId', 'opportunityId'],
    );
  }

  int? _extractCreatedOpportunityId(dynamic decoded) {
    if (decoded is! Map) return null;
    final Map<dynamic, dynamic> data = decoded;
    final int? direct = _readInt(
      data['opportunityId'] ?? data['OpportunityID'] ?? data['OpportunityId'],
    );
    if (direct != null) return direct;

    final dynamic nested = data['data'];
    if (nested is Map) {
      return _readInt(
        nested['opportunityId'] ??
            nested['OpportunityID'] ??
            nested['OpportunityId'],
      );
    }
    return null;
  }

  bool _isSuccessful(dynamic decoded) {
    return decoded is Map && decoded['success'] == true;
  }

  String _responseMessage(dynamic decoded, String fallback) {
    if (decoded is Map && decoded['message'] != null) {
      return decoded['message'].toString();
    }
    return fallback;
  }

  Future<bool> _confirmClosureRequest() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.approval_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'إرسال طلب اعتماد الإغلاق',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'تحويل الفرصة إلى خسارة أو غير مهتم يحتاج اعتماد الإدارة. سيتم حفظ البيانات وإرسال طلب الاعتماد مع سبب الإغلاق.',
            style: GoogleFonts.cairo(height: 1.6),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('رجوع', style: GoogleFonts.cairo()),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text('إرسال الطلب', style: GoogleFonts.cairo()),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<dynamic> _requestClosureApproval(int opportunityId) async {
    final response = await _api.post(
      '/api/opportunities/$opportunityId/request-closure',
      body: <String, dynamic>{
        'requestedStageId': selectedStageId,
        'lostReasonId': selectedLostReasonId,
        'requestReasonNotes': _lostNotesController.text.trim().isEmpty
            ? _summaryController.text.trim()
            : _lostNotesController.text.trim(),
        'userName': widget.username,
        'requestSource': isEdit ? 'Flutter-Edit' : 'Flutter-Create',
      },
    );
    return _api.decode(response);
  }

  Future<void> _submitForm() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_validateWorkflow()) return;

    final bool requiresApproval =
        _isLostStage && !_canDirectCloseOpportunity;
    if (requiresApproval && !await _confirmClosureRequest()) return;

    setState(() => _isLoading = true);

    try {
      if (isEdit) {
        final int? opportunityId = _opportunityIdFromEdit();
        if (opportunityId == null || opportunityId <= 0) {
          throw const FormatException('رقم الفرصة غير صالح');
        }

        if (requiresApproval) {
          final int safeStage = _initialStageId == 4 || _initialStageId == 5
              ? 1
              : (_initialStageId ?? 1);
          final response = await _api.put(
            '/api/opportunities/$opportunityId',
            body: _buildEditBody(
              stageOverride: safeStage,
              taskTypeOverride: _initialTaskTypeId,
              followUpDateOverride: _initialFollowUpDate,
              followUpTimeOverride: _initialFollowUpTime,
            ),
          );
          final dynamic savedData = _api.decode(response);
          if (!_isSuccessful(savedData)) {
            throw StateError(
              _responseMessage(savedData, 'تعذر حفظ تعديلات الفرصة'),
            );
          }

          final dynamic requestData =
              await _requestClosureApproval(opportunityId);
          if (!_isSuccessful(requestData)) {
            throw StateError(
              _responseMessage(requestData, 'تعذر إرسال طلب الاعتماد'),
            );
          }

          if (!mounted) return;
          _showSnack(_responseMessage(
            requestData,
            'تم حفظ التعديلات وإرسال طلب الاعتماد',
          ));
          Navigator.pop(context, true);
          return;
        }

        final response = await _api.put(
          '/api/opportunities/$opportunityId',
          body: _buildEditBody(),
        );
        final dynamic data = _api.decode(response);
        if (!_isSuccessful(data)) {
          throw StateError(_responseMessage(data, 'تعذر تعديل الفرصة'));
        }

        if (!mounted) return;
        _showSnack(_responseMessage(data, 'تم تعديل الفرصة بنجاح'));
        Navigator.pop(context, true);
        return;
      }

      if (requiresApproval) {
        final response = await _api.post(
          '/api/interactions/create',
          body: _buildCreateBody(
            stageOverride: 1,
            includeClosureData: false,
          ),
        );
        final dynamic createdData = _api.decode(response);
        if (!_isSuccessful(createdData)) {
          throw StateError(
            _responseMessage(createdData, 'تعذر إنشاء الفرصة'),
          );
        }

        final int? opportunityId = _extractCreatedOpportunityId(createdData);
        if (opportunityId == null || opportunityId <= 0) {
          throw const FormatException(
            'تم الحفظ لكن لم يتم استلام رقم الفرصة لإرسال طلب الاعتماد',
          );
        }

        final dynamic requestData =
            await _requestClosureApproval(opportunityId);
        if (!_isSuccessful(requestData)) {
          throw StateError(
            _responseMessage(requestData, 'تعذر إرسال طلب الاعتماد'),
          );
        }

        if (!mounted) return;
        _showSnack(_responseMessage(
          requestData,
          'تم إنشاء الفرصة وإرسال طلب الاعتماد',
        ));
        Navigator.pop(context, true);
        return;
      }

      final response = await _api.post(
        '/api/interactions/create',
        body: _buildCreateBody(),
      );
      final dynamic data = _api.decode(response);
      if (!_isSuccessful(data)) {
        throw StateError(_responseMessage(data, 'تعذر حفظ الفرصة'));
      }

      if (!mounted) return;
      _showSnack(_responseMessage(data, 'تم تسجيل الفرصة بنجاح'));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showSnack('تعذر الحفظ: ${error.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        tooltip: 'رجوع',
        onPressed: _isLoading ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            isEdit ? 'تعديل فرصة بيعية' : 'إضافة فرصة بيعية',
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            isEdit ? 'تحديث بيانات ومسار الفرصة' : 'تسجيل تواصل وفرصة جديدة',
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        if (!_isLoadingData && !_isLoading)
          IconButton(
            tooltip: 'إعادة تحميل القوائم',
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: Container(
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                AppColors.goldDark,
                AppColors.goldLight,
                AppColors.goldDark,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(height: 16),
            Text(
              'جاري تجهيز بيانات الفرصة...',
              style: GoogleFonts.cairo(color: _secondaryTextColor),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return _buildLoadError();
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          14,
          14,
          14,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHero(),
            const SizedBox(height: 14),
            if (stages.isNotEmpty) _buildPipeline(),
            if (stages.isNotEmpty) const SizedBox(height: 14),
            _buildSectionCard(
              title: 'بيانات العميل',
              subtitle: isEdit
                  ? 'العميل المرتبط بالفرصة الحالية'
                  : 'يتم البحث تلقائياً باستخدام رقم الهاتف',
              icon: Icons.person_rounded,
              accent: const Color(0xFF4D8DFF),
              child: _buildClientSection(),
              animationDelay: 50,
            ),
            const SizedBox(height: 14),
            _buildSectionCard(
              title: 'بيانات الفرصة',
              subtitle: 'المسؤول والمصدر والقيمة وبيانات الاهتمام',
              icon: Icons.trending_up_rounded,
              accent: AppColors.gold,
              child: _buildOpportunitySection(),
              animationDelay: 100,
            ),
            const SizedBox(height: 14),
            if (_needsFollowUp) ...<Widget>[
              _buildSectionCard(
                title: 'المتابعة القادمة',
                subtitle: 'نوع المهمة والموعد مطلوبان للمرحلة الحالية',
                icon: Icons.event_available_rounded,
                accent: const Color(0xFF22A06B),
                child: _buildFollowUpSection(),
                animationDelay: 150,
              ),
              const SizedBox(height: 14),
            ],
            if (_isLostStage) ...<Widget>[
              _buildSectionCard(
                title: 'بيانات الإغلاق',
                subtitle: 'حدد سبب الخسارة أو عدم الاهتمام بوضوح',
                icon: Icons.do_not_disturb_on_rounded,
                accent: Colors.red.shade600,
                child: _buildLostSection(),
                animationDelay: 180,
              ),
              const SizedBox(height: 14),
            ],
            _buildSectionCard(
              title: 'ملخص التواصل',
              subtitle: 'سجل ما تم وتوجيهات المتابعة باستخدام الكتابة أو الصوت',
              icon: Icons.notes_rounded,
              accent: const Color(0xFF8B5CF6),
              child: _buildNotesSection(),
              animationDelay: 220,
            ),
            const SizedBox(height: 22),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.red.withOpacity(0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.red.shade400,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'تعذر تحميل بيانات الفرصة',
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: _secondaryTextColor,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loadAllData,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final double expectedValue = double.tryParse(
          _expectedValueController.text.replaceAll(',', '').trim(),
        ) ??
        0;
    final NumberFormat moneyFormat = NumberFormat('#,##0', 'en_US');
    final String stageName = _selectedStageName();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.navy, AppColors.navyLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: -35,
            top: -45,
            child: Container(
              width: 135,
              height: 135,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.gold.withOpacity(0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isEdit ? 'الفرصة الحالية' : 'فرصة بيع جديدة',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          stageName.isEmpty ? 'حدد مرحلة البيع' : stageName,
                          style: GoogleFonts.cairo(
                            color: AppColors.goldLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isWonStage)
                    _buildHeroStatusChip(
                      'تم البيع',
                      Icons.verified_rounded,
                      const Color(0xFF4ADE80),
                    )
                  else if (_isLostStage)
                    _buildHeroStatusChip(
                      'إغلاق',
                      Icons.lock_rounded,
                      const Color(0xFFFCA5A5),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'القيمة المتوقعة',
                style: GoogleFonts.cairo(
                  color: Colors.white60,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        moneyFormat.format(expectedValue),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'ج.م',
                      style: GoogleFonts.cairo(
                        color: AppColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.06, end: 0);
  }

  Widget _buildHeroStatusChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _selectedStageName() {
    if (selectedStageId == null) return '';
    for (final dynamic stage in stages) {
      final int? id = _readInt(stage['StageID'] ?? stage['StageId']);
      if (id == selectedStageId) {
        return (stage['StageNameAr'] ?? stage['StageName'] ?? '').toString();
      }
    }
    return '';
  }

  Widget _buildPipeline() {
    final List<dynamic> sortedStages = List<dynamic>.from(stages)
      ..sort((dynamic a, dynamic b) {
        final int first = _readInt(a['StageOrder'] ?? a['stageOrder']) ?? 0;
        final int second = _readInt(b['StageOrder'] ?? b['stageOrder']) ?? 0;
        return first.compareTo(second);
      });

    int currentOrder = 0;
    int maxOrder = 1;
    for (final dynamic stage in sortedStages) {
      final int order = _readInt(stage['StageOrder'] ?? stage['stageOrder']) ?? 0;
      if (order > maxOrder) maxOrder = order;
      if (_readInt(stage['StageID'] ?? stage['StageId']) == selectedStageId) {
        currentOrder = order;
      }
    }
    final double progress =
        (currentOrder / maxOrder).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.route_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                'مسار البيع',
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.cairo(
                  color: AppColors.goldDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.divider(_isDark),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sortedStages.map<Widget>((dynamic stage) {
                final int? stageId =
                    _readInt(stage['StageID'] ?? stage['StageId']);
                final int order =
                    _readInt(stage['StageOrder'] ?? stage['stageOrder']) ?? 0;
                final bool selected = stageId == selectedStageId;
                final bool completed = order < currentOrder;
                final Color stageColor = _parseColor(
                  (stage['StageColor'] ?? stage['stageColor'])?.toString(),
                );

                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: InkWell(
                    onTap: _isLoading ? null : () => _onStageChanged(stageId),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? stageColor
                            : completed
                                ? stageColor.withOpacity(0.16)
                                : AppColors.inputFill(_isDark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? stageColor
                              : completed
                                  ? stageColor.withOpacity(0.35)
                                  : AppColors.divider(_isDark),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (completed) ...<Widget>[
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: selected ? Colors.white : stageColor,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            (stage['StageNameAr'] ??
                                    stage['StageName'] ??
                                    '')
                                .toString(),
                            style: GoogleFonts.cairo(
                              color: selected
                                  ? Colors.white
                                  : completed
                                      ? stageColor
                                      : _secondaryTextColor,
                              fontSize: 11,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
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
        ],
      ),
    ).animate().fadeIn(delay: 40.ms, duration: 350.ms);
  }

  Color _parseColor(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppColors.navyLight;
    }
    try {
      final String normalized = value.replaceAll('#', '').trim();
      final String withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
      return Color(int.parse(withAlpha, radix: 16));
    } catch (_) {
      return AppColors.navyLight;
    }
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Widget child,
    required int animationDelay,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.divider(_isDark)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildSectionTitle(title, subtitle, icon, accent),
          const SizedBox(height: 16),
          child,
        ],
      ),
    )
        .animate()
        .fadeIn(delay: animationDelay.ms, duration: 330.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _buildSectionTitle(
    String title,
    String subtitle,
    IconData icon,
    Color accent,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.cairo(
                  color: _secondaryTextColor,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildClientSection() {
    return Column(
      children: <Widget>[
        _buildTextField(
          controller: _phone1Controller,
          label: 'رقم الهاتف *',
          hint: '01xxxxxxxxx',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          enabled: !isEdit,
          validator: isEdit ? null : _validatePhone,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
            LengthLimitingTextInputFormatter(20),
          ],
          onChanged: _queueClientSearch,
          suffixIcon: _isSearchingClient
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  ),
                )
              : null,
        ),
        if (_clientFound) _buildExistingClientBanner(),
        _buildTextField(
          controller: _clientNameController,
          label: 'اسم العميل *',
          hint: 'أدخل اسم العميل',
          icon: Icons.person_rounded,
          enabled: !_clientFound && !isEdit,
          validator: (String? value) {
            if (!isEdit &&
                _existingClientId == null &&
                (value == null || value.trim().isEmpty)) {
              return 'اسم العميل مطلوب';
            }
            return null;
          },
        ),
        if (!isEdit && !_clientFound) ...<Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (!_showPhone2)
                  _buildOptionalFieldButton(
                    label: 'رقم آخر',
                    icon: Icons.phone_android_rounded,
                    onTap: () => setState(() => _showPhone2 = true),
                  ),
                if (!_showAddress)
                  _buildOptionalFieldButton(
                    label: 'العنوان',
                    icon: Icons.location_on_rounded,
                    onTap: () => setState(() => _showAddress = true),
                  ),
                if (!_showEmail)
                  _buildOptionalFieldButton(
                    label: 'البريد الإلكتروني',
                    icon: Icons.alternate_email_rounded,
                    onTap: () => setState(() => _showEmail = true),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_showPhone2)
          _buildTextField(
            controller: _phone2Controller,
            label: 'رقم هاتف آخر',
            hint: 'اختياري',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            enabled: !_clientFound && !isEdit,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
              LengthLimitingTextInputFormatter(20),
            ],
          ),
        if (_showAddress)
          _buildTextField(
            controller: _addressController,
            label: 'العنوان',
            hint: 'اختياري',
            icon: Icons.location_on_rounded,
            enabled: !_clientFound && !isEdit,
          ),
        if (_showEmail)
          _buildTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            hint: 'name@example.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            enabled: !_clientFound && !isEdit,
            validator: _validateEmail,
          ),
      ],
    );
  }

  Widget _buildExistingClientBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF22A06B).withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF22A06B).withOpacity(0.30),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFF22A06B),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isEdit
                  ? 'هذه الفرصة مرتبطة بالعميل رقم ${_existingClientId ?? '-'}'
                  : 'تم العثور على العميل وسيتم ربط التواصل والفرصة بملفه الحالي',
              style: GoogleFonts.cairo(
                color: _isDark
                    ? const Color(0xFF8CE0BB)
                    : const Color(0xFF137A4F),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalFieldButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withOpacity(0.32)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: AppColors.goldDark, size: 14),
            const SizedBox(width: 5),
            Text(
              'إضافة $label',
              style: GoogleFonts.cairo(
                color: _isDark ? AppColors.goldLight : AppColors.goldDark,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpportunitySection() {
    return Column(
      children: <Widget>[
        _buildDropdown<int>(
          label: 'الموظف المسؤول',
          icon: Icons.badge_rounded,
          value: selectedEmployeeId,
          items: employees.map<DropdownMenuItem<int>>((dynamic employee) {
            final int? id =
                _readInt(employee['EmployeeID'] ?? employee['EmployeeId']);
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                (employee['FullName'] ?? '').toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (int? value) =>
              setState(() => selectedEmployeeId = value),
        ),
        _buildDropdown<int>(
          label: 'مصدر التواصل *',
          icon: Icons.hub_rounded,
          value: selectedSourceId,
          items: sources.map<DropdownMenuItem<int>>((dynamic source) {
            final int? id = _readInt(source['SourceID'] ?? source['SourceId']);
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                (source['SourceNameAr'] ?? source['SourceName'] ?? '')
                    .toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (int? value) =>
              setState(() => selectedSourceId = value),
          validator: (int? value) => value == null ? 'مصدر التواصل مطلوب' : null,
        ),
        _buildDropdown<int>(
          label: 'الحملة أو نوع الإعلان',
          icon: Icons.campaign_rounded,
          value: selectedAdTypeId,
          includeEmptyOption: true,
          items: adTypes.map<DropdownMenuItem<int>>((dynamic adType) {
            final int? id =
                _readInt(adType['AdTypeID'] ?? adType['AdTypeId']);
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                (adType['AdTypeNameAr'] ?? adType['AdTypeName'] ?? '')
                    .toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (int? value) =>
              setState(() => selectedAdTypeId = value),
        ),
        _buildDropdown<int>(
          label: 'مرحلة البيع *',
          icon: Icons.stairs_rounded,
          value: selectedStageId,
          items: stages.map<DropdownMenuItem<int>>((dynamic stage) {
            final int? id = _readInt(stage['StageID'] ?? stage['StageId']);
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                (stage['StageNameAr'] ?? stage['StageName'] ?? '').toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _onStageChanged,
          validator: (int? value) => value == null ? 'مرحلة البيع مطلوبة' : null,
        ),
        _buildDropdown<int>(
          label: 'حالة التواصل *',
          icon: Icons.info_rounded,
          value: selectedStatusId,
          items: statuses.map<DropdownMenuItem<int>>((dynamic status) {
            final int? id =
                _readInt(status['StatusID'] ?? status['StatusId']);
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                (status['StatusNameAr'] ?? status['StatusName'] ?? '')
                    .toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (int? value) =>
              setState(() => selectedStatusId = value),
          validator: (int? value) => value == null ? 'حالة التواصل مطلوبة' : null,
        ),
        _buildDropdown<int>(
          label: 'فئة الاهتمام',
          icon: Icons.category_rounded,
          value: selectedCategoryId,
          includeEmptyOption: true,
          items: categories.map<DropdownMenuItem<int>>((dynamic category) {
            final int? id =
                _readInt(category['CategoryID'] ?? category['CategoryId']);
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                (category['CategoryNameAr'] ?? category['CategoryName'] ?? '')
                    .toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (int? value) =>
              setState(() => selectedCategoryId = value),
        ),
        SpeechTextField(
          controller: _interestedProductController,
          label: 'المنتج المهتم به',
          hint: 'اكتب المنتج أو استخدم الإدخال الصوتي',
          icon: Icons.inventory_2_rounded,
        ),
        _buildTextField(
          controller: _expectedValueController,
          label: 'القيمة المتوقعة',
          hint: '0',
          icon: Icons.payments_rounded,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffixText: 'ج.م',
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
        ),
        _buildTextField(
          controller: _locationController,
          label: 'الموقع أو المنطقة',
          hint: 'مثال: القاهرة الجديدة',
          icon: Icons.location_city_rounded,
        ),
        _buildDateTile(
          title: 'تاريخ أول تواصل *',
          value: selectedFirstContactDate == null
              ? 'حدد التاريخ'
              : DateFormat('yyyy/MM/dd').format(selectedFirstContactDate!),
          icon: Icons.today_rounded,
          accent: AppColors.goldDark,
          onTap: _pickFirstContactDate,
        ),
      ],
    );
  }

  Widget _buildFollowUpSection() {
    return Column(
      children: <Widget>[
        _buildDropdown<int>(
          label: 'نوع مهمة المتابعة *',
          icon: Icons.task_alt_rounded,
          value: selectedTaskTypeId,
          items: taskTypes.map<DropdownMenuItem<int>>((dynamic taskType) {
            final int? id = _readInt(
              taskType['TaskTypeID'] ?? taskType['TaskTypeId'],
            );
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                (taskType['TaskTypeNameAr'] ??
                        taskType['TaskTypeName'] ??
                        '')
                    .toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (int? value) =>
              setState(() => selectedTaskTypeId = value),
          validator: (int? value) {
            if (_needsFollowUp && value == null) return 'نوع المهمة مطلوب';
            return null;
          },
        ),
        _buildDateTile(
          title: 'موعد المتابعة القادمة *',
          value: selectedFollowUpDate == null
              ? 'حدد التاريخ والوقت'
              : '${DateFormat('yyyy/MM/dd').format(selectedFollowUpDate!)}  ${selectedFollowUpTime?.format(context) ?? ''}',
          icon: Icons.event_note_rounded,
          accent: selectedFollowUpDate == null
              ? Colors.orange.shade700
              : const Color(0xFF22A06B),
          onTap: _pickFollowUpDate,
          trailing: selectedFollowUpDate == null
              ? null
              : IconButton(
                  tooltip: 'مسح موعد المتابعة',
                  onPressed: _clearFollowUp,
                  icon: const Icon(Icons.close_rounded, size: 19),
                  color: _secondaryTextColor,
                ),
        ),
        if (selectedFollowUpDate == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.orange.shade700,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'موعد المتابعة مطلوب ما دامت الفرصة في مرحلة مفتوحة.',
                    style: GoogleFonts.cairo(
                      color: Colors.orange.shade700,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLostSection() {
    return Column(
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (_canDirectCloseOpportunity ? Colors.red : Colors.orange)
                .withOpacity(0.09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (_canDirectCloseOpportunity ? Colors.red : Colors.orange)
                  .withOpacity(0.26),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                _canDirectCloseOpportunity
                    ? Icons.info_outline_rounded
                    : Icons.approval_rounded,
                color: _canDirectCloseOpportunity
                    ? Colors.red.shade400
                    : Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _canDirectCloseOpportunity
                      ? 'سيتم إغلاق الفرصة وإيقاف المتابعات المفتوحة بعد الحفظ.'
                      : 'سيتم حفظ البيانات وإرسال طلب اعتماد للإدارة، ولن تتغير المرحلة قبل الموافقة.',
                  style: GoogleFonts.cairo(
                    color: _canDirectCloseOpportunity
                        ? Colors.red.shade400
                        : Colors.orange.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildDropdown<int>(
          label: 'سبب الإغلاق *',
          icon: Icons.cancel_rounded,
          value: selectedLostReasonId,
          items: lostReasons.map<DropdownMenuItem<int>>((dynamic reason) {
            final int? id = _readInt(
              reason['LostReasonID'] ?? reason['LostReasonId'],
            );
            return DropdownMenuItem<int>(
              value: id,
              child: Text(
                (reason['ReasonNameAr'] ?? reason['ReasonName'] ?? '')
                    .toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (int? value) =>
              setState(() => selectedLostReasonId = value),
          validator: (int? value) {
            if (_isLostStage && value == null) return 'سبب الإغلاق مطلوب';
            return null;
          },
        ),
        SpeechTextField(
          controller: _lostNotesController,
          label: 'تفاصيل سبب الإغلاق',
          hint: 'أضف تفاصيل تساعد في الاسترداد والمتابعة لاحقاً',
          icon: Icons.comment_rounded,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      children: <Widget>[
        SpeechTextField(
          controller: _summaryController,
          label: 'ملخص التواصل *',
          hint: 'اكتب ما تم مع العميل أو استخدم الإدخال الصوتي',
          icon: Icons.summarize_rounded,
          maxLines: 4,
          validator: (String? value) {
            if (value == null || value.trim().isEmpty) {
              return 'ملخص التواصل مطلوب';
            }
            return null;
          },
        ),
        SpeechTextField(
          controller: _notesController,
          label: 'ملاحظات إضافية',
          hint: 'تفاصيل داخلية اختيارية',
          icon: Icons.note_alt_rounded,
          maxLines: 3,
        ),
        SpeechTextField(
          controller: _guidanceController,
          label: 'توجيهات المتابعة',
          hint: 'ما المطلوب في التواصل القادم؟',
          icon: Icons.assistant_direction_rounded,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildDateTile({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.inputFill(_isDark),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent.withOpacity(0.30)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        color: _secondaryTextColor,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.cairo(
                        color: _textColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_left_rounded,
                    color: _secondaryTextColor,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    String? suffixText,
    Widget? suffixIcon,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: AppColors.divider(_isDark)),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.cairo(
        color: _secondaryTextColor,
        fontSize: 12,
      ),
      hintStyle: GoogleFonts.cairo(
        color: AppColors.textHint(_isDark),
        fontSize: 11.5,
      ),
      prefixIcon: Icon(icon, color: AppColors.goldDark, size: 19),
      suffixText: suffixText,
      suffixStyle: GoogleFonts.cairo(
        color: AppColors.goldDark,
        fontWeight: FontWeight.w700,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.inputFill(_isDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: border,
      enabledBorder: border,
      disabledBorder: border.copyWith(
        borderSide: BorderSide(
          color: AppColors.divider(_isDark).withOpacity(0.55),
        ),
      ),
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: Colors.red.shade500),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: Colors.red.shade500, width: 1.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool enabled = true,
    String? suffixText,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        textInputAction:
            maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        style: GoogleFonts.cairo(color: _textColor, fontSize: 13),
        decoration: _inputDecoration(
          label: label,
          hint: hint,
          icon: icon,
          suffixText: suffixText,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
    bool includeEmptyOption = false,
  }) {
    final List<DropdownMenuItem<T>> effectiveItems = <DropdownMenuItem<T>>[
      if (includeEmptyOption)
        DropdownMenuItem<T>(
          value: null,
          child: Text(
            'بدون اختيار',
            style: GoogleFonts.cairo(color: _secondaryTextColor),
          ),
        ),
      ...items,
    ];

    final bool valueExists = value == null ||
        effectiveItems.any((DropdownMenuItem<T> item) => item.value == value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<T>(
        value: valueExists ? value : null,
        isExpanded: true,
        items: effectiveItems,
        onChanged: _isLoading ? null : onChanged,
        validator: validator,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        dropdownColor: _surfaceColor,
        style: GoogleFonts.cairo(color: _textColor, fontSize: 13),
        decoration: _inputDecoration(
          label: label,
          hint: 'اختر',
          icon: icon,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool isApprovalAction =
        _isLostStage && !_canDirectCloseOpportunity;
    final Color buttonColor =
        isApprovalAction ? Colors.orange.shade700 : AppColors.navy;
    final String label = _isLoading
        ? 'جاري الحفظ...'
        : isApprovalAction
            ? 'حفظ وإرسال طلب الاعتماد'
            : isEdit
                ? 'حفظ التعديلات'
                : 'حفظ الفرصة';

    return Column(
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: buttonColor.withOpacity(0.55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : Icon(
                    isApprovalAction
                        ? Icons.send_rounded
                        : Icons.check_circle_rounded,
                    size: 21,
                  ),
            label: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (_isWonStage)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF22A06B),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'مرحلة تم البيع تُحفظ مباشرة ولا تحتاج طلب اعتماد.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: const Color(0xFF22A06B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    )
        .animate()
        .fadeIn(delay: 260.ms, duration: 350.ms)
        .slideY(begin: 0.08, end: 0);
  }
}
