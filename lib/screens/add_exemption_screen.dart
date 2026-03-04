import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

class AddExemptionScreen extends StatefulWidget {
  final String username;

  const AddExemptionScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<AddExemptionScreen> createState() => _AddExemptionScreenState();
}

class _AddExemptionScreenState extends State<AddExemptionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Data
  List<dynamic> employees = [];
  int? selectedBioId;
  DateTime selectedDate = DateTime.now();
  String selectedReason = 'إذن تأخير';
  final _descriptionController = TextEditingController();

  final List<String> reasons = [
    'إذن تأخير',
    'إذن انصراف مبكر',
    'مأمورية',
    'إجازة اعتيادي',
    'إجازة عارضة',
    'إجازة مرضي',
    'عمل من المنزل'
  ];

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/employees/active'));
      if (res.statusCode == 200) {
        setState(() {
          employees = jsonDecode(res.body);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveExemption() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedBioId == null) {
      _showErrorSnackBar('يرجى اختيار الموظف');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // لازم نجيب كود البصمة للموظف المختار
      // في قائمة الموظفين (active) إحنا بنرجع EmployeeID
      // هنحتاج نجيب BioEmployeeID من الـ API أو نكون بنرجعه أصلاً
      
      // ⚠️ ملاحظة: تأكد إن API /employees/active بيرجع BioEmployeeID
      // لو مش بيرجعه، هنحتاج نعدل الـ Backend أو نستخدم EmployeeID ونعمل Join في الـ Backend
      
      // الحل الأسهل: نعتمد إن الـ Backend (createExemption) بياخد bioEmployeeId
      // فاحنا محتاجين BioCode من القائمة.
      
      // البحث عن الموظف المختار للحصول على BioCode
      final emp = employees.firstWhere((e) => e['EmployeeID'] == selectedBioId);
      final bioCode = emp['BioEmployeeID']; // ⚠️ تأكد إن الحقل ده راجع من الـ API

      if (bioCode == null) {
        _showErrorSnackBar('هذا الموظف ليس له كود بصمة');
        setState(() => _isLoading = false);
        return;
      }

      final body = {
        'bioEmployeeId': bioCode,
        'exemptionDate': selectedDate.toIso8601String(),
        'reasonCode': selectedReason,
        'description': _descriptionController.text,
        'approvedBy': widget.username,
      };

      final res = await http.post(
        Uri.parse('$baseUrl/api/attendance/exemptions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final result = jsonDecode(res.body);

      if (res.statusCode == 200 && result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _showErrorSnackBar(result['message'] ?? 'فشل الحفظ');
      }
    } catch (e) {
      _showErrorSnackBar('فشل الاتصال بالسيرفر');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFE8B923), surface: Color(0xFF1E1E1E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.cairo()), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text('إضافة استثناء', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الموظف
              Text('الموظف', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedBioId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A2A2A),
                    hint: Text('اختر الموظف', style: GoogleFonts.cairo(color: Colors.grey)),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE8B923)),
                    style: GoogleFonts.cairo(color: Colors.white),
                    items: employees.map<DropdownMenuItem<int>>((e) {
                      return DropdownMenuItem<int>(
                        value: e['EmployeeID'],
                        child: Text(e['FullName']),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedBioId = val),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // التاريخ
              Text('التاريخ', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFFE8B923), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('yyyy-MM-dd').format(selectedDate),
                        style: GoogleFonts.cairo(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // نوع العذر
              Text('نوع العذر', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedReason,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A2A2A),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE8B923)),
                    style: GoogleFonts.cairo(color: Colors.white),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setState(() => selectedReason = val!),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ملاحظات
              Text('ملاحظات (اختياري)', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: GoogleFonts.cairo(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  hintText: 'اكتب تفاصيل إضافية...',
                  hintStyle: GoogleFonts.cairo(color: Colors.grey[600]),
                ),
              ),

              const SizedBox(height: 40),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveExemption,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8B923),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          'حفظ',
                          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}