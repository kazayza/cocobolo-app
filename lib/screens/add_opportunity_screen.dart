import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
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
  State<AddOpportunityScreen> createState() => _AddOpportunityScreenState();
}

class _AddOpportunityScreenState extends State<AddOpportunityScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _clientFound = false;
  int? _existingClientId;

  // Controllers
  final _clientNameController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _addressController = TextEditingController();
  final _interestedProductController = TextEditingController();
  final _expectedValueController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _guidanceController = TextEditingController();
  final _emailController = TextEditingController();

  // Dropdown Data
  List<dynamic> sources = [];
  List<dynamic> stages = [];
  List<dynamic> statuses = [];
  List<dynamic> adTypes = [];
  List<dynamic> categories = [];
  List<dynamic> employees = [];
  
  // ✅ إظهار/إخفاء الحقول الاختيارية
  bool _showPhone2 = false;
  bool _showAddress = false;
  bool _showEmail = false;

  // Selected Values
  int? selectedSourceId;
  int? selectedStageId;
  int? selectedStatusId;
  int? selectedAdTypeId;
  int? selectedCategoryId;
  int? selectedEmployeeId;
  DateTime? selectedFollowUpDate;
  TimeOfDay? selectedFollowUpTime;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _interestedProductController.dispose();
    _expectedValueController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _guidanceController.dispose();
    _emailController.dispose();
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
      _fetchEmployees(),
      _fetchCurrentEmployee(),
    ]);
    
     // ✅ التعديل المهم هنا: التأكد من ملء البيانات
    if (widget.opportunityToEdit != null) {
      _fillDataForEdit();
    }


    setState(() => _isLoadingData = false);
  }
  
    void _fillDataForEdit() {
    final opp = widget.opportunityToEdit!;
    // مش محتاجين setState هنا لأننا بالفعل بنناديها جوه setState في _loadAllData
    // أو لأن _loadAllData بتعمل setState بعدها علطول
    
    _clientFound = true;
    _existingClientId = opp['PartyID'];
    
    _clientNameController.text = opp['ClientName'] ?? '';
    _phone1Controller.text = opp['Phone1'] ?? '';
    _phone2Controller.text = opp['Phone2'] ?? '';
    _addressController.text = opp['Address'] ?? '';
    
    _interestedProductController.text = opp['InterestedProduct'] ?? '';
    _expectedValueController.text = opp['ExpectedValue']?.toString() ?? '';
    _locationController.text = opp['Location'] ?? '';
    _notesController.text = opp['Notes'] ?? '';
    _guidanceController.text = opp['Guidance'] ?? '';

    selectedSourceId = opp['SourceID'];
    selectedStageId = opp['StageID'];
    selectedStatusId = opp['StatusID'];
    selectedAdTypeId = opp['AdTypeID'];
    selectedCategoryId = opp['CategoryID'];
    selectedEmployeeId = opp['EmployeeID'];

    if (opp['NextFollowUpDate'] != null) {
      try {
        final dt = DateTime.parse(opp['NextFollowUpDate']);
        selectedFollowUpDate = dt;
        selectedFollowUpTime = TimeOfDay.fromDateTime(dt);
      } catch (_) {}
    }
    
    // ✅ إظهار الحقول الاختيارية لو فيها بيانات
if (opp['Phone2'] != null && opp['Phone2'].toString().isNotEmpty) {
  _showPhone2 = true;
}
if (opp['Address'] != null && opp['Address'].toString().isNotEmpty) {
  _showAddress = true;
}
if (opp['Email'] != null && opp['Email'].toString().isNotEmpty) {
  _showEmail = true;
  _emailController.text = opp['Email'] ?? '';
}

  }

  
  Future<void> _fetchSources() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/sources'));
      if (res.statusCode == 200) {
        sources = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error fetching sources: $e');
    }
  }

  Future<void> _fetchStages() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/stages'));
      if (res.statusCode == 200) {
        stages = jsonDecode(res.body);
        // تحديد المرحلة الافتراضية (جديد)
        if (stages.isNotEmpty) {
          selectedStageId = stages.first['StageID'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching stages: $e');
    }
  }

  Future<void> _fetchStatuses() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/statuses'));
      if (res.statusCode == 200) {
        statuses = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error fetching statuses: $e');
    }
  }

  Future<void> _fetchAdTypes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/ad-types'));
      if (res.statusCode == 200) {
        adTypes = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error fetching ad types: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/categories'));
      if (res.statusCode == 200) {
        categories = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/employees'));
      if (res.statusCode == 200) {
        employees = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
    }
  }

  Future<void> _fetchCurrentEmployee() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/auth/users/${widget.userId}/employee')
      );
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

  Future<void> _searchClientByPhone(String phone) async {
    if (phone.length < 8) return;
    
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/search-by-phone?phone=$phone')
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _clientFound = data['found'];
          if (_clientFound && data['client'] != null) {
            _existingClientId = data['client']['PartyID'];
            _clientNameController.text = data['client']['PartyName'] ?? '';
            _phone2Controller.text = data['client']['Phone2'] ?? '';
            _addressController.text = data['client']['Address'] ?? '';
          } else {
            _existingClientId = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error searching client: $e');
    }
  }

  Future<void> _pickFollowUpDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedFollowUpDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700),
              surface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: selectedFollowUpTime ?? TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFFFD700),
                surface: Color(0xFF1A1A1A),
              ),
            ),
            child: child!,
          );
        },
      );
      
      setState(() {
        selectedFollowUpDate = date;
        selectedFollowUpTime = time;
      });
    }
  }

Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    DateTime? followUpDateTime;
    if (selectedFollowUpDate != null) {
      followUpDateTime = DateTime(
        selectedFollowUpDate!.year,
        selectedFollowUpDate!.month,
        selectedFollowUpDate!.day,
        selectedFollowUpTime?.hour ?? 9,
        selectedFollowUpTime?.minute ?? 0,
      );
    }

    final bool isEdit = widget.opportunityToEdit != null;

    if (isEdit) {
      // 🛠️ حالة التعديل
      final oppId = widget.opportunityToEdit!['OpportunityID'];

      final body = {
        // 🔒 ملاحظة: لا نرسل الموظف أو المصدر أو الإعلان للحفاظ على البيانات الأصلية
        'stageId': selectedStageId ?? 1,
        'statusId': selectedStatusId,
        'categoryId': selectedCategoryId,
        'interestedProduct': _interestedProductController.text.trim(),
        'expectedValue': double.tryParse(_expectedValueController.text) ?? 0,
        'location': _locationController.text.trim(),
        'nextFollowUpDate': followUpDateTime?.toIso8601String(),
        'notes': _notesController.text.trim(),
        'guidance': _guidanceController.text.trim(),
        'updatedBy': widget.username,
      };

      final res = await http.put(
        Uri.parse('$baseUrl/api/opportunities/$oppId'),
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
                  Expanded(child: Text('تم تعديل الفرصة بنجاح', style: GoogleFonts.cairo())),
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

    } else {
      // ➕ حالة الإضافة
      final body = {
        'clientName': _clientNameController.text.trim(),
        'phone1': _phone1Controller.text.trim(),
        'phone2': _phone2Controller.text.trim(),
        'address': _addressController.text.trim(),
        'email': _emailController.text.trim(),
        'employeeId': selectedEmployeeId,
        'sourceId': selectedSourceId,
        'adTypeId': selectedAdTypeId,
        'stageId': selectedStageId ?? 1,
        'statusId': selectedStatusId,
        'categoryId': selectedCategoryId,
        'interestedProduct': _interestedProductController.text.trim(),
        'expectedValue': double.tryParse(_expectedValueController.text) ?? 0,
        'location': _locationController.text.trim(),
        'nextFollowUpDate': followUpDateTime?.toIso8601String(),
        'notes': _notesController.text.trim(),
        'guidance': _guidanceController.text.trim(),
        'createdBy': widget.username,
      };

      final res = await http.post(
        Uri.parse('$baseUrl/api/opportunities/create-with-client'),
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
                  Expanded(
                    child: Text(
                      data['isNewClient'] == true
                          ? 'تم إضافة الفرصة والعميل بنجاح'
                          : 'تم إضافة الفرصة بنجاح',
                      style: GoogleFonts.cairo(),
                    ),
                  ),
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
    }

  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
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
                    _buildSectionTitle('بيانات العميل', FontAwesomeIcons.user),
                    const SizedBox(height: 12),
                    _buildClientSection(),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('بيانات الفرصة', FontAwesomeIcons.lightbulb),
                    const SizedBox(height: 12),
                    _buildOpportunitySection(),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('المتابعة', FontAwesomeIcons.calendarCheck),
                    const SizedBox(height: 12),
                    _buildFollowUpSection(),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('ملاحظات إضافية', FontAwesomeIcons.noteSticky),
                    const SizedBox(height: 12),
                    _buildNotesSection(),
                    
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
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
          Text(
            'فرصة جديدة',
            style: GoogleFonts.cairo(
              color: const Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
            ),
          ),
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
        Text(
          title,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

Widget _buildClientSection() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Column(
      children: [
        // رقم الهاتف الأساسي
        _buildTextField(
          controller: _phone1Controller,
          label: 'رقم الهاتف *',
          hint: '01xxxxxxxxx',
          icon: FontAwesomeIcons.phone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'رقم الهاتف مطلوب';
            }
            return null;
          },
          onChanged: (value) {
            if (value.length >= 8) {
              _searchClientByPhone(value);
            }
          },
        ),
        
        // إشعار العميل موجود
        if (_clientFound)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.circleInfo, color: Colors.orange, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'العميل موجود مسبقاً - سيتم ربط الفرصة به',
                    style: GoogleFonts.cairo(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        
        // اسم العميل
        _buildTextField(
          controller: _clientNameController,
          label: 'اسم العميل *',
          hint: 'أدخل اسم العميل',
          icon: FontAwesomeIcons.user,
          enabled: !_clientFound,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'اسم العميل مطلوب';
            }
            return null;
          },
        ),
        
        // ✅ أزرار إضافة الحقول الاختيارية
        if (!_clientFound)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_showPhone2)
                _buildOptionalFieldButton(
                  label: 'رقم آخر',
                  icon: FontAwesomeIcons.phoneFlip,
                  onTap: () => setState(() => _showPhone2 = true),
                ),
              if (!_showAddress)
                _buildOptionalFieldButton(
                  label: 'العنوان',
                  icon: FontAwesomeIcons.locationDot,
                  onTap: () => setState(() => _showAddress = true),
                ),
              if (!_showEmail)
                _buildOptionalFieldButton(
                  label: 'البريد الإلكتروني',
                  icon: FontAwesomeIcons.envelope,
                  onTap: () => setState(() => _showEmail = true),
                ),
            ],
          ),
        
        if (!_clientFound) const SizedBox(height: 12),

        // ✅ الحقول الاختيارية
        if (_showPhone2)
          _buildTextField(
            controller: _phone2Controller,
            label: 'رقم هاتف آخر',
            hint: 'اختياري',
            icon: FontAwesomeIcons.phoneFlip,
            keyboardType: TextInputType.phone,
            enabled: !_clientFound,
          ),
        
        if (_showAddress)
          _buildTextField(
            controller: _addressController,
            label: 'العنوان',
            hint: 'اختياري',
            icon: FontAwesomeIcons.locationDot,
            enabled: !_clientFound,
          ),
        
        if (_showEmail)
          _buildTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            hint: 'example@email.com',
            icon: FontAwesomeIcons.envelope,
            keyboardType: TextInputType.emailAddress,
            enabled: !_clientFound,
          ),
      ],
    ),
  );
}

// ✅ زرار إضافة حقل اختياري
Widget _buildOptionalFieldButton({
  required String label,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, color: const Color(0xFFFFD700), size: 12),
          const SizedBox(width: 6),
          Text(
            '+ $label',
            style: GoogleFonts.cairo(
              color: const Color(0xFFFFD700),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildOpportunitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
                    // الموظف المسؤول
          _buildDropdown<int>(
            label: 'الموظف المسؤول',
            icon: FontAwesomeIcons.userTie,
            value: selectedEmployeeId,
            items: employees.map((e) => DropdownMenuItem<int>(
              value: e['EmployeeID'],
              child: Text(e['FullName']),
            )).toList(),
            onChanged: (value) => setState(() => selectedEmployeeId = value),
          ),

          // المصدر
          _buildDropdown<int>(
            label: 'مصدر التواصل',
            icon: FontAwesomeIcons.share,
            value: selectedSourceId,
            items: sources.map((s) => DropdownMenuItem<int>(
              value: s['SourceID'],
              child: Text(s['SourceNameAr'] ?? s['SourceName']),
            )).toList(),
            onChanged: (value) => setState(() => selectedSourceId = value),
          ),
          
          // نوع الإعلان
          _buildDropdown<int>(
            label: 'نوع الإعلان',
            icon: FontAwesomeIcons.ad,
            value: selectedAdTypeId,
            items: adTypes.map((t) => DropdownMenuItem<int>(
              value: t['AdTypeID'],
              child: Text(t['AdTypeNameAr'] ?? t['AdTypeName']),
            )).toList(),
            onChanged: (value) => setState(() => selectedAdTypeId = value),
          ),
          
          // المرحلة
          _buildDropdown<int>(
            label: 'المرحلة',
            icon: FontAwesomeIcons.stairs,
            value: selectedStageId,
            items: stages.map((s) => DropdownMenuItem<int>(
              value: s['StageID'],
              child: Text(s['StageNameAr'] ?? s['StageName']),
            )).toList(),
            onChanged: (value) => setState(() => selectedStageId = value),
          ),
          
          // فئة الاهتمام
          _buildDropdown<int>(
            label: 'فئة الاهتمام',
            icon: FontAwesomeIcons.tags,
            value: selectedCategoryId,
            items: categories.map((c) => DropdownMenuItem<int>(
              value: c['CategoryID'],
              child: Text(c['CategoryNameAr'] ?? c['CategoryName']),
            )).toList(),
            onChanged: (value) => setState(() => selectedCategoryId = value),
          ),
          
         
          // المنتج المهتم به
SpeechTextField(
  controller: _interestedProductController,
  label: 'المنتج المهتم به',
  hint: 'مثال: مطبخ ألوميتال... أو اضغط المايك 🎤',
  icon: FontAwesomeIcons.box,
),
          
          // القيمة المتوقعة
          _buildTextField(
            controller: _expectedValueController,
            label: 'القيمة المتوقعة',
            hint: 'بالجنيه المصري',
            icon: FontAwesomeIcons.coins,
            keyboardType: TextInputType.number,
            suffixText: 'ج.م',
          ),
          
          // الموقع
          _buildTextField(
            controller: _locationController,
            label: 'الموقع / المنطقة',
            hint: 'مثال: مدينة نصر',
            icon: FontAwesomeIcons.mapLocationDot,
          ),
          

        ],
      ),
    );
  }

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
          // حالة التواصل
          _buildDropdown<int>(
            label: 'حالة التواصل',
            icon: FontAwesomeIcons.circleInfo,
            value: selectedStatusId,
            items: statuses.map((s) => DropdownMenuItem<int>(
              value: s['StatusID'],
              child: Text(s['StatusNameAr'] ?? s['StatusName']),
            )).toList(),
            onChanged: (value) => setState(() => selectedStatusId = value),
          ),
          
          // تاريخ المتابعة
          InkWell(
            onTap: _pickFollowUpDate,
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
                        Text(
                          'موعد المتابعة القادمة',
                          style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedFollowUpDate != null
                              ? '${DateFormat('yyyy/MM/dd').format(selectedFollowUpDate!)} - ${selectedFollowUpTime?.format(context) ?? ''}'
                              : 'اضغط لاختيار التاريخ والوقت',
                          style: GoogleFonts.cairo(
                            color: selectedFollowUpDate != null ? Colors.white : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedFollowUpDate != null)
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.xmark, color: Colors.grey, size: 16),
                      onPressed: () => setState(() {
                        selectedFollowUpDate = null;
                        selectedFollowUpTime = null;
                      }),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildNotesSection() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Column(
      children: [
        SpeechTextField(
          controller: _notesController,
          label: 'ملاحظات',
          hint: 'أي ملاحظات إضافية... أو اضغط المايك 🎤',
          icon: FontAwesomeIcons.noteSticky,
          maxLines: 3,
        ),
        SpeechTextField(
          controller: _guidanceController,
          label: 'توجيهات',
          hint: 'توجيهات للمتابعة... أو اضغط المايك 🎤',
          icon: FontAwesomeIcons.compass,
          maxLines: 2,
        ),
      ],
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
    void Function(String)? onChanged,
    int maxLines = 1,
    bool enabled = true,
    String? suffixText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.cairo(color: Colors.white),
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        maxLines: maxLines,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.cairo(color: Colors.grey),
          hintStyle: GoogleFonts.cairo(color: Colors.grey[600]),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: FaIcon(icon, color: Colors.grey, size: 18),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
            child: FaIcon(icon, color: Colors.grey, size: 18),
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.check, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'حفظ الفرصة',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }
}