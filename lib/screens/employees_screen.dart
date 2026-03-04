import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../services/permission_service.dart';
import 'add_employee_screen.dart'; // هننشئها بعدين

class EmployeesScreen extends StatefulWidget {
  final int userId;
  final String username;

  const EmployeesScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<dynamic> employees = [];
  List<dynamic> filteredEmployees = [];
  List<String> departments = [];
  bool loading = true;
  String searchQuery = '';
  String? selectedDepartment;
  String selectedStatus = 'الكل'; // الكل، نشط، موقوف

  @override
  void initState() {
    super.initState();
    fetchEmployees();
    fetchLookups();
  }

  Future<void> fetchEmployees() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/employees'));
      if (res.statusCode == 200) {
        setState(() {
          employees = jsonDecode(res.body);
          _filterEmployees();
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
      _showErrorSnackBar('فشل في تحميل الموظفين');
    }
  }

  Future<void> fetchLookups() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/employees/lookups'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          departments = List<String>.from(data['departments']);
        });
      }
    } catch (e) {
      print('Error fetching lookups: $e');
    }
  }

  void _filterEmployees() {
    setState(() {
      filteredEmployees = employees.where((emp) {
        // فلترة البحث
        final name = emp['FullName']?.toString().toLowerCase() ?? '';
        final phone = emp['MobilePhone']?.toString() ?? '';
        final job = emp['JobTitle']?.toString().toLowerCase() ?? '';
        final matchesSearch = searchQuery.isEmpty ||
            name.contains(searchQuery.toLowerCase()) ||
            phone.contains(searchQuery) ||
            job.contains(searchQuery.toLowerCase());

        // فلترة القسم
        final matchesDept = selectedDepartment == null ||
            emp['Department'] == selectedDepartment;

        // فلترة الحالة
        final matchesStatus = selectedStatus == 'الكل' ||
            (selectedStatus == 'نشط' && emp['Status'] == 'نشط') ||
            (selectedStatus == 'موقوف' && emp['Status'] != 'نشط');

        return matchesSearch && matchesDept && matchesStatus;
      }).toList();
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    var phone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.startsWith('0')) phone = '2$phone';
    final Uri uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = PermissionService().canAdd(FormNames.employeesAdd);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          'الموظفين',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              fetchEmployees();
              fetchLookups();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          _buildStatusTabs(),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8B923)))
                : filteredEmployees.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredEmployees.length,
                        itemBuilder: (context, index) {
                          return _buildEmployeeCard(filteredEmployees[index], index);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEmployeeScreen(
                      userId: widget.userId,
                      username: widget.username,
                    ),
                  ),
                );
                if (result == true) fetchEmployees();
              },
              backgroundColor: const Color(0xFF4CAF50),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // شريط البحث
          TextField(
            style: GoogleFonts.cairo(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم، الوظيفة، أو الهاتف...',
              hintStyle: GoogleFonts.cairo(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFE8B923)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              searchQuery = value;
              _filterEmployees();
            },
          ),
          const SizedBox(height: 12),
          // فلتر الأقسام
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('الكل', selectedDepartment == null, () {
                  setState(() {
                    selectedDepartment = null;
                    _filterEmployees();
                  });
                }),
                ...departments.map((dept) => _buildFilterChip(
                      dept,
                      selectedDepartment == dept,
                      () {
                        setState(() {
                          selectedDepartment = dept;
                          _filterEmployees();
                        });
                      },
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 1),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          _buildStatusTab('الكل', employees.length),
          _buildStatusTab('نشط', employees.where((e) => e['Status'] == 'نشط').length),
          _buildStatusTab('موقوف', employees.where((e) => e['Status'] != 'نشط').length),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String title, int count) {
    final isSelected = selectedStatus == title;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedStatus = title;
            _filterEmployees();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(bottom: BorderSide(color: Color(0xFFE8B923), width: 2))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: isSelected ? const Color(0xFFE8B923) : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                '$count',
                style: GoogleFonts.cairo(
                  color: isSelected ? const Color(0xFFE8B923) : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFE8B923),
        backgroundColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp, int index) {
    final isActive = emp['Status'] == 'نشط';
    final canEdit = PermissionService().canEdit(FormNames.employeesAdd);

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // فتح التفاصيل (لاحقاً)
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // الصورة / الحرف الأول
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF4CAF50).withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        (emp['FullName'] ?? '?')[0].toUpperCase(),
                        style: GoogleFonts.cairo(
                          color: isActive ? const Color(0xFF4CAF50) : Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // البيانات
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp['FullName'] ?? 'بدون اسم',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          emp['JobTitle'] ?? 'بدون وظيفة',
                          style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13),
                        ),
                        if (emp['Department'] != null)
                          Text(
                            emp['Department'],
                            style: GoogleFonts.cairo(color: const Color(0xFFE8B923), fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  // الحالة
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF4CAF50).withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF4CAF50).withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      isActive ? 'نشط' : 'موقوف',
                      style: GoogleFonts.cairo(
                        color: isActive ? const Color(0xFF4CAF50) : Colors.red,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // أزرار الإجراءات
              Row(
                children: [
                  if (emp['MobilePhone'] != null) ...[
                    _buildActionButton(Icons.phone, const Color(0xFF4CAF50), () {
                      _makePhoneCall(emp['MobilePhone']);
                    }),
                    const SizedBox(width: 8),
                    _buildActionButton(Icons.chat, const Color(0xFF25D366), () {
                      _openWhatsApp(emp['MobilePhone']);
                    }),
                    const SizedBox(width: 8),
                  ],
                  if (canEdit)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEmployeeScreen(
                                userId: widget.userId,
                                username: widget.username,
                                existingEmployee: emp,
                              ),
                            ),
                          );
                          if (result == true) fetchEmployees();
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text('تعديل', style: GoogleFonts.cairo()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE8B923),
                          side: const BorderSide(color: Color(0xFFE8B923)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: index * 50));
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'لا يوجد موظفين',
            style: GoogleFonts.cairo(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: Colors.red,
      ),
    );
  }
}