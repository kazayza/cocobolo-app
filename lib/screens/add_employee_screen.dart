import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' as intl;
import '../constants.dart';

class AddEmployeeScreen extends StatefulWidget {
  final int userId;
  final String username;
  final Map<String, dynamic>? existingEmployee;

  const AddEmployeeScreen({
    Key? key,
    required this.userId,
    required this.username,
    this.existingEmployee,
  }) : super(key: key);

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;

  // Controllers
  final _nameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _salaryController = TextEditingController();
  final _notesController = TextEditingController();
  final _bioIdController = TextEditingController(); // ✅ كود البصمة

  // Dropdowns Lists
  List<String> departments = [];
  List<String> jobTitles = [];
  
  // Selected Values
  String? selectedDepartment;
  String? selectedJobTitle;
  String? selectedGender;
  String selectedStatus = 'نشط';
  bool isExemptFromAttendance = false; // ✅ الإعفاء من البصمة
  
  // Dates
  DateTime? birthDate;
  DateTime? hireDate;
  DateTime? endDate;

  bool get isEditing => widget.existingEmployee != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/employees/lookups'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          departments = List<String>.from(data['departments']);
          jobTitles = List<String>.from(data['jobTitles']);
        });
      }

      if (isEditing) {
        _fillExistingData();
      }

      setState(() => _isLoadingData = false);
    } catch (e) {
      setState(() => _isLoadingData = false);
      _showErrorSnackBar('فشل تحميل البيانات');
    }
  }

  void _fillExistingData() {
    final emp = widget.existingEmployee!;
    _nameController.text = emp['FullName'] ?? '';
    _nationalIdController.text = emp['NationalID'] ?? '';
    _phoneController.text = emp['MobilePhone'] ?? '';
    _phone2Controller.text = emp['MobilePhone2'] ?? '';
    _emailController.text = emp['EmailAddress'] ?? '';
    _addressController.text = emp['Address'] ?? '';
    _qualificationController.text = emp['qualification'] ?? '';
    _salaryController.text = emp['CurrentSalaryBase']?.toString() ?? '';
    _notesController.text = emp['Notes'] ?? '';
    _bioIdController.text = emp['BioEmployeeID']?.toString() ?? ''; // ✅
    
    selectedDepartment = emp['Department'];
    selectedJobTitle = emp['JobTitle'];
    selectedGender = emp['Gender'];
    selectedStatus = emp['Status'] ?? 'نشط';
    isExemptFromAttendance = emp['IsPermanentlyExempt'] ?? false; // ✅
    
    if (emp['BirthDate'] != null) birthDate = DateTime.parse(emp['BirthDate']);
    if (emp['HireDate'] != null) hireDate = DateTime.parse(emp['HireDate']);
    if (emp['EndDate'] != null) endDate = DateTime.parse(emp['EndDate']);
  }

  void _analyzeNationalId(String id) {
    if (id.length != 14) return;
    try {
      int century = int.parse(id[0]);
      int year = int.parse(id.substring(1, 3));
      int month = int.parse(id.substring(3, 5));
      int day = int.parse(id.substring(5, 7));
      year += (century == 2 ? 1900 : 2000);

      int genderCode = int.parse(id.substring(12, 13));
      String gender = (genderCode % 2 != 0) ? 'ذكر' : 'أنثى';

      setState(() {
        birthDate = DateTime(year, month, day);
        selectedGender = gender;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم استخراج البيانات تلقائياً ✅', style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('خطأ في تحليل الرقم القومي');
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final body = {
        'fullName': _nameController.text.trim(),
        'nationalId': _nationalIdController.text.trim(),
        'department': selectedDepartment,
        'jobTitle': selectedJobTitle,
        'gender': selectedGender,
        'mobilePhone': _phoneController.text.trim(),
        'mobilePhone2': _phone2Controller.text.trim(),
        'emailAddress': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'qualification': _qualificationController.text.trim(),
        'currentSalaryBase': double.tryParse(_salaryController.text) ?? 0,
        'bioEmployeeId': int.tryParse(_bioIdController.text), // ✅
        'isPermanentlyExempt': isExemptFromAttendance, // ✅
        'status': selectedStatus,
        'notes': _notesController.text.trim(),
        'createdBy': widget.username,
        if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
        if (hireDate != null) 'hireDate': hireDate!.toIso8601String(),
        'endDate': (selectedStatus == 'موقوف' && endDate != null) 
            ? endDate!.toIso8601String() 
            : null,
      };

      http.Response res;
      if (isEditing) {
        res = await http.put(
          Uri.parse('$baseUrl/api/employees/${widget.existingEmployee!['EmployeeID']}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else {
        res = await http.post(
          Uri.parse('$baseUrl/api/employees'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      }

      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        _showSuccessDialog();
      } else {
        _showErrorSnackBar(result['message'] ?? 'فشل الحفظ');
      }
    } catch (e) {
      _showErrorSnackBar('فشل الاتصال بالسيرفر');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 60)
                .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              isEditing ? 'تم التعديل بنجاح!' : 'تم الإضافة بنجاح!',
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      Navigator.pop(context);
      Navigator.pop(context, true);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.cairo()), backgroundColor: Colors.red),
    );
  }

  Future<void> _selectDate(BuildContext context, int type) async {
    DateTime initial = DateTime.now();
    if (type == 1 && birthDate != null) initial = birthDate!;
    if (type == 2 && hireDate != null) initial = hireDate!;
    if (type == 3 && endDate != null) initial = endDate!;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFE8B923), surface: Color(0xFF1E1E1E)),
        ),
        child: child!,
      ),
    );
    
    if (picked != null) {
      setState(() {
        if (type == 1) birthDate = picked;
        if (type == 2) hireDate = picked;
        if (type == 3) endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8B923)))
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // 1. البيانات الشخصية
                          _buildExpansionSection(
                            title: 'البيانات الشخصية',
                            icon: Icons.person_outline,
                            color: const Color(0xFF4CAF50),
                            isExpanded: true,
                            children: [
                              _buildTextField(
                                controller: _nameController,
                                label: 'الاسم الكامل',
                                icon: Icons.person,
                                isRequired: true,
                              ),
                              _buildTextField(
                                controller: _nationalIdController,
                                label: 'الرقم القومي (14 رقم)',
                                icon: Icons.badge_outlined,
                                keyboardType: TextInputType.number,
                                maxLength: 14,
                                isRequired: true,
                                onChanged: (val) {
                                  if (val.length == 14) _analyzeNationalId(val);
                                },
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDatePicker(
                                      label: 'تاريخ الميلاد',
                                      date: birthDate,
                                      onTap: () => _selectDate(context, 1),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDropdown(
                                      label: 'النوع',
                                      value: selectedGender,
                                      items: ['ذكر', 'أنثى'],
                                      onChanged: (v) => setState(() => selectedGender = v),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _qualificationController,
                                label: 'المؤهل الدراسي',
                                icon: Icons.school_outlined,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // 2. بيانات الوظيفة
                          _buildExpansionSection(
                            title: 'بيانات الوظيفة',
                            icon: Icons.work_outline,
                            color: const Color(0xFF2196F3),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDropdown(
                                      label: 'القسم',
                                      value: selectedDepartment,
                                      items: departments,
                                      onChanged: (v) => setState(() => selectedDepartment = v),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDropdown(
                                      label: 'المسمى الوظيفي',
                                      value: selectedJobTitle,
                                      items: jobTitles,
                                      onChanged: (v) => setState(() => selectedJobTitle = v),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // ✅ كود البصمة والإعفاء
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _bioIdController,
                                      label: 'كود البصمة',
                                      icon: Icons.fingerprint,
                                      keyboardType: TextInputType.number,
                                      isSmall: true,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      height: 55,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: isExemptFromAttendance 
                                            ? Colors.orange.withOpacity(0.1) 
                                            : Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isExemptFromAttendance 
                                              ? Colors.orange.withOpacity(0.3) 
                                              : Colors.transparent
                                        ),
                                      ),
                                      child: SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          'معفى من البصمة',
                                          style: GoogleFonts.cairo(
                                            fontSize: 12, 
                                            color: isExemptFromAttendance ? Colors.orange : Colors.grey[400],
                                            fontWeight: isExemptFromAttendance ? FontWeight.bold : FontWeight.normal
                                          ),
                                        ),
                                        value: isExemptFromAttendance,
                                        onChanged: (val) => setState(() => isExemptFromAttendance = val),
                                        activeColor: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // ✅ الراتب وتاريخ التعيين
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildDatePicker(
                                        label: 'تاريخ التعيين',
                                        date: hireDate,
                                        onTap: () => _selectDate(context, 2),
                                        isSmall: true,
                                        iconColor: Colors.green, // لون مختلف للتمييز
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.white.withOpacity(0.1),
                                      margin: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: _salaryController,
                                        label: 'الراتب الأساسي',
                                        icon: Icons.monetization_on_outlined,
                                        keyboardType: TextInputType.number,
                                        isSmall: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // ✅ الحالة وتاريخ النهاية
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedStatus == 'موقوف' 
                                        ? Colors.red.withOpacity(0.3) 
                                        : Colors.green.withOpacity(0.3)
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: selectedStatus == 'موقوف'
                                      ? Colors.red.withOpacity(0.05)
                                      : Colors.green.withOpacity(0.05),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStatusDropdown(),
                                    AnimatedCrossFade(
                                      firstChild: Container(),
                                      secondChild: Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: _buildDatePicker(
                                          label: 'تاريخ نهاية العمل',
                                          date: endDate,
                                          onTap: () => _selectDate(context, 3),
                                          isWarning: true,
                                        ),
                                      ),
                                      crossFadeState: selectedStatus == 'موقوف'
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      duration: const Duration(milliseconds: 300),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // 3. بيانات الاتصال (أرقام تحت بعض)
                          _buildExpansionSection(
                            title: 'بيانات الاتصال',
                            icon: Icons.contact_phone_outlined,
                            color: const Color(0xFFFF9800),
                            children: [
                              _buildTextField(
                                controller: _phoneController,
                                label: 'رقم الهاتف 1 (أساسي)',
                                icon: Icons.phone_android,
                                keyboardType: TextInputType.phone,
                              ),
                              _buildTextField(
                                controller: _phone2Controller,
                                label: 'رقم الهاتف 2 (اختياري)',
                                icon: Icons.phone_iphone, // أيقونة مختلفة
                                keyboardType: TextInputType.phone,
                              ),
                              _buildTextField(
                                controller: _emailController,
                                label: 'البريد الإلكتروني',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              _buildTextField(
                                controller: _addressController,
                                label: 'العنوان',
                                icon: Icons.location_on_outlined,
                                maxLines: 2,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          _buildSaveButton(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: const Color(0xFF1E1E1E),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          isEditing ? 'تعديل موظف' : 'موظف جديد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildExpansionSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    bool isExpanded = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          collapsedIconColor: Colors.grey,
          iconColor: color,
          children: children,
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    bool isRequired = false,
    bool isSmall = false,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13)),
              if (isRequired) Text(' *', style: GoogleFonts.cairo(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            onChanged: onChanged,
            style: GoogleFonts.cairo(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              counterText: "",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE8B923)),
              ),
              contentPadding: isSmall ? const EdgeInsets.symmetric(vertical: 8, horizontal: 12) : null,
            ),
            validator: isRequired
                ? (value) => value!.isEmpty ? 'هذا الحقل مطلوب' : null
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text('اختر...', style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 12)),
              dropdownColor: const Color(0xFF2A2A2A),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              style: GoogleFonts.cairo(color: Colors.white),
              items: items.map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('حالة الموظف', style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildStatusOption('نشط', Colors.green),
              _buildStatusOption('موقوف', Colors.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusOption(String status, Color color) {
    final isSelected = selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedStatus = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: color) : null,
          ),
          child: Center(
            child: Text(
              status,
              style: GoogleFonts.cairo(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool isSmall = false,
    bool isWarning = false,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isSmall) ...[
          Text(label, style: GoogleFonts.cairo(color: isWarning ? Colors.red[300] : Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isSmall ? Colors.transparent : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: isWarning ? Border.all(color: Colors.red.withOpacity(0.3)) : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today, 
                  size: 18, 
                  color: iconColor ?? (isWarning ? Colors.red[300] : (isSmall ? Colors.grey[600] : Colors.grey)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date != null ? intl.DateFormat('yyyy/MM/dd').format(date) : (isSmall ? label : '--/--/----'),
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveEmployee,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8B923),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : Text(
                isEditing ? 'حفظ التعديلات' : 'إضافة الموظف',
                style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
              ),
      ),
    );
  }
}