import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

class AddInteractionScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? initialPartyId; // لو جاي من شاشة العميل

  const AddInteractionScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialPartyId,
  });

  @override
  State<AddInteractionScreen> createState() => _AddInteractionScreenState();
}

class _AddInteractionScreenState extends State<AddInteractionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;

  // نوع العميل
  bool _isNewClient = false;
  
  // بيانات العميل الموجود
  int? _selectedPartyId;
  String? _selectedClientName;
  String? _selectedClientPhone;
  bool _hasOpenOpportunity = false;
  Map<String, dynamic>? _openOpportunity;

  // Controllers
  final _searchController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _addressController = TextEditingController();
  final _interestedProductController = TextEditingController();
  final _expectedValueController = TextEditingController();
  final _summaryController = TextEditingController();
  final _guidanceController = TextEditingController();

  // Dropdown Data
  List<dynamic> sources = [];
  List<dynamic> stages = [];
  List<dynamic> statuses = [];
  List<dynamic> adTypes = [];
  List<dynamic> categories = [];
  List<dynamic> lostReasons = [];
  List<dynamic> taskTypes = [];
  List<dynamic> employees = [];
  List<dynamic> searchResults = [];

  // Selected Values
  int? selectedSourceId;
  int? selectedStageId;
  int? selectedStatusId;
  int? selectedAdTypeId;
  int? selectedCategoryId;
  int? selectedLostReasonId;
  int? selectedTaskTypeId;
  int? selectedEmployeeId;
  DateTime? selectedFollowUpDate;
  TimeOfDay? selectedFollowUpTime;

  // Debounce للبحث
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    
    // لو جاي من شاشة العميل
    if (widget.initialPartyId != null) {
      _loadClientData(widget.initialPartyId!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _clientNameController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _interestedProductController.dispose();
    _expectedValueController.dispose();
    _summaryController.dispose();
    _guidanceController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoadingData = true);
    
    await Future.wait([
      _fetchSources(),
      _fetchStages(),
      _fetchStatuses(),
      _fetchAdTypes(),
      _fetchCategories(),
      _fetchLostReasons(),
      _fetchTaskTypes(),
      _fetchEmployees(),
      _fetchCurrentEmployee(),
    ]);
    
    // تحديد القيم الافتراضية
    if (stages.isNotEmpty) {
      selectedStageId = stages.first['StageID'];
    }
    if (statuses.isNotEmpty) {
      selectedStatusId = statuses.first['StatusID'];
    }
    
    setState(() => _isLoadingData = false);
  }

  Future<void> _fetchSources() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/sources'));
      if (res.statusCode == 200) sources = jsonDecode(res.body);
    } catch (e) {
      debugPrint('Error fetching sources: $e');
    }
  }

  Future<void> _fetchStages() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/stages'));
      if (res.statusCode == 200) stages = jsonDecode(res.body);
    } catch (e) {
      debugPrint('Error fetching stages: $e');
    }
  }

  Future<void> _fetchStatuses() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/statuses'));
      if (res.statusCode == 200) statuses = jsonDecode(res.body);
    } catch (e) {
      debugPrint('Error fetching statuses: $e');
    }
  }

  Future<void> _fetchAdTypes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/ad-types'));
      if (res.statusCode == 200) adTypes = jsonDecode(res.body);
    } catch (e) {
      debugPrint('Error fetching ad types: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/categories'));
      if (res.statusCode == 200) categories = jsonDecode(res.body);
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _fetchLostReasons() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/lost-reasons'));
      if (res.statusCode == 200) lostReasons = jsonDecode(res.body);
    } catch (e) {
      debugPrint('Error fetching lost reasons: $e');
    }
  }

  Future<void> _fetchTaskTypes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/task-types'));
      if (res.statusCode == 200) taskTypes = jsonDecode(res.body);
    } catch (e) {
      debugPrint('Error fetching task types: $e');
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/employees'));
      if (res.statusCode == 200) employees = jsonDecode(res.body);
    } catch (e) {
      debugPrint('Error fetching employees: $e');
    }
  }

  Future<void> _fetchCurrentEmployee() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/users/${widget.userId}/employee'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['employeeID'] != null) {
          selectedEmployeeId = data['employeeID'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching current employee: $e');
    }
  }

  // البحث عن عميل
  void _searchClients(String query) {
    _searchDebounce?.cancel();
    
    if (query.length < 2) {
      setState(() => searchResults = []);
      return;
    }
    
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await http.get(Uri.parse('$baseUrl/api/clients/search?q=$query'));
        if (res.statusCode == 200) {
          setState(() => searchResults = jsonDecode(res.body));
        }
      } catch (e) {
        debugPrint('Error searching clients: $e');
      }
    });
  }

  // اختيار عميل من نتائج البحث
  Future<void> _selectClient(Map<String, dynamic> client) async {
    setState(() {
      _selectedPartyId = client['PartyID'];
      _selectedClientName = client['PartyName'];
      _selectedClientPhone = client['Phone'];
      _searchController.text = client['PartyName'];
      searchResults = [];
    });
    
    await _checkOpenOpportunity(client['PartyID']);
  }

  // تحميل بيانات عميل (لو جاي من شاشة تانية)
  Future<void> _loadClientData(int partyId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/clients/$partyId'));
      if (res.statusCode == 200) {
        final client = jsonDecode(res.body);
        _selectClient(client);
      }
    } catch (e) {
      debugPrint('Error loading client: $e');
    }
  }

  // التحقق من فرصة مفتوحة
  Future<void> _checkOpenOpportunity(int partyId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/check-open/$partyId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _hasOpenOpportunity = data['hasOpenOpportunity'] ?? false;
          _openOpportunity = data['opportunity'];
          
          // تحميل بيانات الفرصة المفتوحة
          if (_hasOpenOpportunity && _openOpportunity != null) {
            selectedEmployeeId = _openOpportunity!['EmployeeID'];
            selectedStageId = _openOpportunity!['StageID'];
            selectedCategoryId = _openOpportunity!['CategoryID'];
            _interestedProductController.text = _openOpportunity!['InterestedProduct'] ?? '';
            if (_openOpportunity!['ExpectedValue'] != null) {
              _expectedValueController.text = _openOpportunity!['ExpectedValue'].toString();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking open opportunity: $e');
    }
  }

  // اختيار تاريخ ووقت المتابعة
  Future<void> _pickFollowUpDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedFollowUpDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFD700),
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: selectedFollowUpTime ?? const TimeOfDay(hour: 10, minute: 0),
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700),
              surface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        ),
      );
      
      setState(() {
        selectedFollowUpDate = date;
        selectedFollowUpTime = time ?? const TimeOfDay(hour: 10, minute: 0);
      });
    }
  }

  // التحقق من صحة البيانات
  bool _validateForm() {
    if (_isNewClient) {
      if (_clientNameController.text.trim().isEmpty) {
        _showError('برجاء إدخال اسم العميل');
        return false;
      }
      if (_phone1Controller.text.trim().isEmpty) {
        _showError('برجاء إدخال رقم التليفون');
        return false;
      }
    } else {
      if (_selectedPartyId == null) {
        _showError('برجاء اختيار العميل');
        return false;
      }
    }
    
    if (selectedSourceId == null) {
      _showError('برجاء اختيار مصدر التواصل');
      return false;
    }
    
    if (selectedStageId == null) {
      _showError('برجاء اختيار المرحلة');
      return false;
    }
    
    // لو المرحلة خسارة أو غير مهتم، لازم سبب
    if ((selectedStageId == 4 || selectedStageId == 5) && selectedLostReasonId == null) {
      _showError('برجاء اختيار سبب الخسارة');
      return false;
    }
    
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const FaIcon(FontAwesomeIcons.circleExclamation, color: Colors.white, size: 16),
            const SizedBox(width: 10),
            Text(message, style: GoogleFonts.cairo()),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // حفظ البيانات
  Future<void> _submitForm() async {
    if (!_validateForm()) return;
    
    setState(() => _isLoading = true);
    
    try {
      DateTime? followUpDateTime;
      if (selectedFollowUpDate != null && selectedStageId != 3 && selectedStageId != 4 && selectedStageId != 5) {
        followUpDateTime = DateTime(
          selectedFollowUpDate!.year,
          selectedFollowUpDate!.month,
          selectedFollowUpDate!.day,
          selectedFollowUpTime?.hour ?? 10,
          selectedFollowUpTime?.minute ?? 0,
        );
      }
      
      final body = {
        'isNewClient': _isNewClient,
        'clientName': _clientNameController.text.trim(),
        'phone1': _phone1Controller.text.trim(),
        'phone2': _phone2Controller.text.trim(),
        'address': _addressController.text.trim(),
        'partyId': _selectedPartyId,
        'employeeId': selectedEmployeeId,
        'sourceId': selectedSourceId,
        'adTypeId': selectedAdTypeId,
        'stageId': selectedStageId,
        'statusId': selectedStatusId,
        'categoryId': selectedCategoryId,
        'interestedProduct': _interestedProductController.text.trim(),
        'expectedValue': double.tryParse(_expectedValueController.text) ?? 0,
        'summary': _summaryController.text.trim(),
        'guidance': _guidanceController.text.trim(),
        'lostReasonId': selectedLostReasonId,
        'nextFollowUpDate': followUpDateTime?.toIso8601String(),
        'taskTypeId': selectedTaskTypeId,
        'createdBy': widget.username,
      };
      
      final res = await http.post(
        Uri.parse('$baseUrl/api/interactions/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      final data = jsonDecode(res.body);
      
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.circleCheck, color: Colors.white, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(data['message'], style: GoogleFonts.cairo())),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(data['message'] ?? 'حدث خطأ');
      }
    } catch (e) {
      if (mounted) {
        _showError('خطأ: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppBar(),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildClientTypeSelector(),
                    const SizedBox(height: 16),
                    
                    if (_isNewClient) _buildNewClientSection() else _buildExistingClientSection(),
                    
                    if (_hasOpenOpportunity) _buildOpenOpportunityAlert(),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('بيانات التواصل', FontAwesomeIcons.phoneVolume),
                    const SizedBox(height: 12),
                    _buildContactSection(),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('المرحلة والحالة', FontAwesomeIcons.stairs),
                    const SizedBox(height: 12),
                    _buildStageSection(),
                    
                    // سبب الخسارة (يظهر فقط لو المرحلة خسارة)
                    if (selectedStageId == 4 || selectedStageId == 5) ...[
                      const SizedBox(height: 16),
                      _buildLostReasonSection(),
                    ],
                    
                    // المتابعة (تختفي لو المرحلة خسارة)
                    if (selectedStageId != 3 && selectedStageId != 4 && selectedStageId != 5) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('المتابعة', FontAwesomeIcons.calendarCheck),
                      const SizedBox(height: 12),
                      _buildFollowUpSection(),
                    ],
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('التفاصيل', FontAwesomeIcons.clipboardList),
                    const SizedBox(height: 12),
                    _buildDetailsSection(),
                    
                    const SizedBox(height: 32),
                    _buildSubmitButtons(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(FontAwesomeIcons.plus, color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 10),
          Text('تسجيل تواصل', style: GoogleFonts.cairo(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        ],
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        FaIcon(icon, color: const Color(0xFFFFD700), size: 16),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  // اختيار نوع العميل
  Widget _buildClientTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isNewClient = false;
                _clearNewClientFields();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isNewClient ? const Color(0xFFFFD700) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.userCheck,
                      size: 14,
                      color: !_isNewClient ? Colors.black : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'عميل موجود',
                      style: GoogleFonts.cairo(
                        color: !_isNewClient ? Colors.black : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isNewClient = true;
                _clearExistingClientFields();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isNewClient ? const Color(0xFFFFD700) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.userPlus,
                      size: 14,
                      color: _isNewClient ? Colors.black : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'عميل جديد',
                      style: GoogleFonts.cairo(
                        color: _isNewClient ? Colors.black : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearNewClientFields() {
    _clientNameController.clear();
    _phone1Controller.clear();
    _phone2Controller.clear();
    _addressController.clear();
  }

  void _clearExistingClientFields() {
    _selectedPartyId = null;
    _selectedClientName = null;
    _selectedClientPhone = null;
    _searchController.clear();
    searchResults = [];
    _hasOpenOpportunity = false;
    _openOpportunity = null;
  }

  // قسم العميل الموجود (البحث)
  Widget _buildExistingClientSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // حقل البحث
          TextField(
            controller: _searchController,
            style: GoogleFonts.cairo(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو رقم التليفون...',
              hintStyle: GoogleFonts.cairo(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          searchResults = [];
                          _clearExistingClientFields();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _searchClients,
          ),
          
          // نتائج البحث
          if (searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final client = searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFD700).withOpacity(0.2),
                      child: const FaIcon(FontAwesomeIcons.user, color: Color(0xFFFFD700), size: 14),
                    ),
                    title: Text(client['PartyName'], style: GoogleFonts.cairo(color: Colors.white)),
                    subtitle: Text(client['Phone'] ?? '', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
                    onTap: () => _selectClient(client),
                  );
                },
              ),
            ),
          
          // العميل المختار
          if (_selectedPartyId != null && searchResults.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.circleCheck, color: Color(0xFFFFD700), size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedClientName ?? '', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(_selectedClientPhone ?? '', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.xmark, color: Colors.grey, size: 14),
                    onPressed: () => setState(() => _clearExistingClientFields()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // قسم العميل الجديد
  Widget _buildNewClientSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _clientNameController,
            label: 'اسم العميل *',
            icon: FontAwesomeIcons.user,
          ),
          _buildTextField(
            controller: _phone1Controller,
            label: 'رقم التليفون *',
            icon: FontAwesomeIcons.phone,
            keyboardType: TextInputType.phone,
          ),
          _buildTextField(
            controller: _phone2Controller,
            label: 'رقم تليفون آخر',
            icon: FontAwesomeIcons.phoneFlip,
            keyboardType: TextInputType.phone,
          ),
          _buildTextField(
            controller: _addressController,
            label: 'العنوان',
            icon: FontAwesomeIcons.locationDot,
          ),
        ],
      ),
    );
  }

  // تنبيه فرصة مفتوحة
  Widget _buildOpenOpportunityAlert() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.triangleExclamation, color: Colors.orange, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'يوجد فرصة مفتوحة لهذا العميل',
                  style: GoogleFonts.cairo(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'سيتم إضافة التواصل لنفس الفرصة (${_openOpportunity?['StageNameAr'] ?? ''})',
                  style: GoogleFonts.cairo(color: Colors.orange.withOpacity(0.8), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().shake();
  }

  // قسم بيانات التواصل
  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildDropdown<int>(
            label: 'مصدر التواصل *',
            icon: FontAwesomeIcons.share,
            value: selectedSourceId,
            items: sources.map((s) => DropdownMenuItem<int>(
              value: s['SourceID'],
              child: Text(s['SourceNameAr'] ?? s['SourceName']),
            )).toList(),
            onChanged: (v) => setState(() => selectedSourceId = v),
          ),
          _buildDropdown<int>(
            label: 'نوع الإعلان',
            icon: FontAwesomeIcons.ad,
            value: selectedAdTypeId,
            items: adTypes.map((t) => DropdownMenuItem<int>(
              value: t['AdTypeID'],
              child: Text(t['AdTypeNameAr'] ?? t['AdTypeName']),
            )).toList(),
            onChanged: (v) => setState(() => selectedAdTypeId = v),
          ),
          _buildDropdown<int>(
            label: 'الموظف المسؤول',
            icon: FontAwesomeIcons.userTie,
            value: selectedEmployeeId,
            items: employees.map((e) => DropdownMenuItem<int>(
              value: e['EmployeeID'],
              child: Text(e['FullName']),
            )).toList(),
            onChanged: (v) => setState(() => selectedEmployeeId = v),
          ),
        ],
      ),
    );
  }

  // قسم المرحلة والحالة
  Widget _buildStageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildDropdown<int>(
            label: 'المرحلة *',
            icon: FontAwesomeIcons.stairs,
            value: selectedStageId,
            items: stages.map((s) => DropdownMenuItem<int>(
              value: s['StageID'],
              child: Text(s['StageNameAr'] ?? s['StageName']),
            )).toList(),
            onChanged: (v) => setState(() {
              selectedStageId = v;
              // لو المرحلة مكسب أو خسر، امسح تاريخ المتابعة
              if (v == 3 || v == 4 || v == 5) {
                selectedFollowUpDate = null;
                selectedFollowUpTime = null;
                selectedTaskTypeId = null;
              }
              // لو المرحلة مش خسر، امسح سبب الخسارة
              if (v != 4 && v != 5) {
                selectedLostReasonId = null;
              }
            }),
          ),
          _buildDropdown<int>(
            label: 'حالة التواصل',
            icon: FontAwesomeIcons.circleInfo,
            value: selectedStatusId,
            items: statuses.map((s) => DropdownMenuItem<int>(
              value: s['StatusID'],
              child: Text(s['StatusNameAr'] ?? s['StatusName']),
            )).toList(),
            onChanged: (v) => setState(() => selectedStatusId = v),
          ),
          _buildDropdown<int>(
            label: 'فئة الاهتمام',
            icon: FontAwesomeIcons.tags,
            value: selectedCategoryId,
            items: categories.map((c) => DropdownMenuItem<int>(
              value: c['CategoryID'],
              child: Text(c['CategoryNameAr'] ?? c['CategoryName']),
            )).toList(),
            onChanged: (v) => setState(() => selectedCategoryId = v),
          ),
        ],
      ),
    );
  }

  // قسم سبب الخسارة
  Widget _buildLostReasonSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: _buildDropdown<int>(
        label: 'سبب الخسارة *',
        icon: FontAwesomeIcons.circleXmark,
        value: selectedLostReasonId,
        items: lostReasons.map((r) => DropdownMenuItem<int>(
          value: r['LostReasonID'],
          child: Text(r['ReasonNameAr'] ?? r['ReasonName']),
        )).toList(),
        onChanged: (v) => setState(() => selectedLostReasonId = v),
      ),
    ).animate().fadeIn().shake();
  }

  // قسم المتابعة
  Widget _buildFollowUpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // تاريخ المتابعة
          InkWell(
            onTap: _pickFollowUpDateTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.calendarDays, color: Colors.grey, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('موعد المتابعة', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          selectedFollowUpDate != null
                              ? '${selectedFollowUpDate!.day}/${selectedFollowUpDate!.month}/${selectedFollowUpDate!.year} - ${selectedFollowUpTime?.format(context) ?? ''}'
                              : 'اختر التاريخ والوقت',
                          style: GoogleFonts.cairo(
                            color: selectedFollowUpDate != null ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedFollowUpDate != null)
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.xmark, color: Colors.grey, size: 14),
                      onPressed: () => setState(() {
                        selectedFollowUpDate = null;
                        selectedFollowUpTime = null;
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildDropdown<int>(
            label: 'نوع المهمة',
            icon: FontAwesomeIcons.listCheck,
            value: selectedTaskTypeId,
            items: taskTypes.map((t) => DropdownMenuItem<int>(
              value: t['TaskTypeID'],
              child: Text(t['TaskTypeNameAr'] ?? t['TaskTypeName']),
            )).toList(),
            onChanged: (v) => setState(() => selectedTaskTypeId = v),
          ),
        ],
      ),
    );
  }

  // قسم التفاصيل
  Widget _buildDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _interestedProductController,
            label: 'المنتج المهتم به',
            icon: FontAwesomeIcons.box,
          ),
          _buildTextField(
            controller: _expectedValueController,
            label: 'القيمة المتوقعة',
            icon: FontAwesomeIcons.coins,
            keyboardType: TextInputType.number,
            suffixText: 'ج.م',
          ),
          _buildTextField(
            controller: _summaryController,
            label: 'ملخص المكالمة',
            icon: FontAwesomeIcons.comment,
            maxLines: 3,
          ),
          _buildTextField(
            controller: _guidanceController,
            label: 'توجيهات للمتابعة',
            icon: FontAwesomeIcons.compass,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // أزرار الحفظ
  Widget _buildSubmitButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const FaIcon(FontAwesomeIcons.check, size: 16),
                        const SizedBox(width: 8),
                        Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  // TextField مشترك
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? suffixText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: GoogleFonts.cairo(color: Colors.white),
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(color: Colors.grey),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: FaIcon(icon, color: Colors.grey, size: 16),
          ),
          suffixText: suffixText,
          suffixStyle: GoogleFonts.cairo(color: Colors.grey),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFD700)),
          ),
        ),
      ),
    );
  }

  // Dropdown مشترك
  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        style: GoogleFonts.cairo(color: Colors.white),
        dropdownColor: const Color(0xFF1A1A1A),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(color: Colors.grey),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: FaIcon(icon, color: Colors.grey, size: 16),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFD700)),
          ),
        ),
      ),
    );
  }
}