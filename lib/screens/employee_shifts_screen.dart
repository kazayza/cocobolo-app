import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/permission_service.dart';
import 'add_shift_screen.dart'; // هنعملها الخطوة الجاية
import 'all_shifts_screen.dart';

class EmployeeShiftsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const EmployeeShiftsScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<EmployeeShiftsScreen> createState() => _EmployeeShiftsScreenState();
}

class _EmployeeShiftsScreenState extends State<EmployeeShiftsScreen> {
  List<dynamic> employees = [];
  List<dynamic> filteredEmployees = [];
  bool loading = true;
  String searchQuery = '';
  
  // فلتر إضافي
  String? selectedFilter; // null = الكل, true = لهم شيفت, false = بدون شيفت

  // إحصائيات
  int totalEmployees = 0;
  int assignedShifts = 0;
  int missingShifts = 0;

  // حالة الطي للإحصائيات
  bool _isStatsExpanded = true;

  @override
  void initState() {
    super.initState();
    // التحقق من الصلاحية
    if (!PermissionService().canView(FormNames.employeeShifts)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ليس لديك صلاحية لعرض هذه الشاشة')),
        );
      });
      return;
    }
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => loading = true);
    try {
      // ✅ بننادي الـ API الجديد اللي عملناه
      final res = await http.get(Uri.parse('$baseUrl/api/shifts/status'));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          employees = data;
          filteredEmployees = data;
          
          // حساب الإحصائيات
          totalEmployees = data.length;
          assignedShifts = data.where((e) => e['EmployeeShiftID'] != null).length;
          missingShifts = totalEmployees - assignedShifts;
          
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
      print('Error: $e');
    }
  }

  void _filterEmployees(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      filteredEmployees = employees.where((emp) {
        // فلتر البحث
        final matchesSearch = searchQuery.isEmpty || 
            (emp['FullName']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
            (emp['JobTitle']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
        
        // فلتر الحالة
        final hasShift = emp['EmployeeShiftID'] != null;
        bool matchesFilter = true;
        
        if (selectedFilter == 'assigned') {
          matchesFilter = hasShift;
        } else if (selectedFilter == 'missing') {
          matchesFilter = !hasShift;
        }
        
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B923).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule, color: Color(0xFFE8B923), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'إدارة الشيفتات',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu, size: 18),
            tooltip: 'سجل الشيفتات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AllShiftsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: fetchData,
          ),
        ],
      ),
      body: loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFE8B923), strokeWidth: 2)
                      .animate().fadeIn().scale(),
                  const SizedBox(height: 15),
                  Text(
                    'جاري تحميل البيانات...',
                    style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13),
                  ).animate().fadeIn(delay: 300.ms),
                ],
              ),
            )
          : Column(
              children: [
                _buildStatsHeader(),
                _buildSearchBar(),
                Expanded(
                  child: filteredEmployees.isEmpty
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
    );
  }

  // 1️⃣ لوحة الإحصائيات العلوية (قابلة للطي)
  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF2A2A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: _isStatsExpanded,
        onExpansionChanged: (expanded) => setState(() => _isStatsExpanded = expanded),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B923).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.people_alt, color: Color(0xFFE8B923), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'إحصائيات الشيفتات',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('الموظفين', '$totalEmployees', Icons.people, Colors.blue),
                    ),
                    Container(width: 1, height: 40, color: Colors.white10),
                    Expanded(
                      child: _buildStatItem('لهم شيفت', '$assignedShifts', Icons.check_circle, const Color(0xFF4CAF50)),
                    ),
                    Container(width: 1, height: 40, color: Colors.white10),
                    Expanded(
                      child: _buildStatItem('بدون شيفت', '$missingShifts', Icons.warning, const Color(0xFFE8B923)),
                    ),
                  ],
                ),
                if (missingShifts > 0) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8B923).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8B923).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFE8B923), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يوجد $missingShifts موظفين بدون شيفت',
                            style: GoogleFonts.cairo(
                              color: const Color(0xFFE8B923),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }

  // دالة الإحصاء الواحد (بأيقونة)
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // 2️⃣ شريط البحث (مطور)
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // شريط البحث
          TextField(
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث باسم الموظف...',
              hintStyle: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFE8B923), size: 20),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                      onPressed: () => _filterEmployees(''),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: _filterEmployees,
          ),
          const SizedBox(height: 12),
          // أزرار الفلتر
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل', null),
                const SizedBox(width: 8),
                _buildFilterChip('لهم شيفت', 'assigned'),
                const SizedBox(width: 8),
                _buildFilterChip('بدون شيفت', 'missing'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? filterValue) {
    final isSelected = selectedFilter == filterValue;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = selectedFilter == filterValue ? null : filterValue;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFE8B923) 
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFE8B923) 
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? Colors.black : Colors.grey[400],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // 3️⃣ كارت الموظف (مطور)
  Widget _buildEmployeeCard(Map<String, dynamic> emp, int index) {
    final bool hasShift = emp['EmployeeShiftID'] != null;
    final Color cardColor = hasShift ? const Color(0xFF1E1E1E) : const Color(0xFF1A1A1A);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor,
            hasShift ? const Color(0xFF222222) : const Color(0xFF202020),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasShift 
              ? Colors.transparent 
              : const Color(0xFFE8B923).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (hasShift ? const Color(0xFF4CAF50) : const Color(0xFFE8B923)).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openAddShiftScreen(emp),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // صورة محسنة
                    _buildEmployeeAvatar(emp, hasShift),
                    const SizedBox(width: 16),
                    
                    // الاسم والوظيفة
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  emp['FullName'] ?? '',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: hasShift 
                                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                                      : const Color(0xFFE8B923).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasShift ? Icons.check_circle : Icons.warning_amber_rounded,
                                      size: 12,
                                      color: hasShift ? const Color(0xFF4CAF50) : const Color(0xFFE8B923),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasShift ? 'مسجل' : 'بدون',
                                      style: GoogleFonts.cairo(
                                        color: hasShift ? const Color(0xFF4CAF50) : const Color(0xFFE8B923),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.work_outline, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                emp['JobTitle'] ?? 'بدون مسمى وظيفي',
                                style: GoogleFonts.cairo(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          if (emp['DepartmentName'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.business_center, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  emp['DepartmentName'],
                                  style: GoogleFonts.cairo(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                
                // تفاصيل الشيفت محسنة
                if (hasShift) ...[
                  const SizedBox(height: 16),
                  _buildShiftDetails(emp),
                ] else ...[
                  const SizedBox(height: 16),
                  _buildAddShiftButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 50)).slideX();
  }

  Widget _buildEmployeeAvatar(Map<String, dynamic> emp, bool hasShift) {
    final String initial = (emp['FullName'] ?? '?')[0].toUpperCase();
    final Color avatarColor = hasShift 
        ? const Color(0xFF4CAF50) 
        : const Color(0xFFE8B923);
    
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                avatarColor.withOpacity(0.2),
                avatarColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: avatarColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.cairo(
                color: avatarColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (hasShift)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildShiftDetails(Map<String, dynamic> emp) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.2),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFFE8B923).withOpacity(0.1),
      ),
    ),
    child: Column(
      children: [
        // وقت الشيفت
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B923).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.access_time, color: Color(0xFFE8B923), size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'موعد الشيفت',
                    style: GoogleFonts.cairo(
                      color: Colors.grey[500],
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    (emp['StartTime'] != null && emp['EndTime'] != null)
                        ? '${emp['StartTime']} - ${emp['EndTime']}'
                        : 'الوقت غير محدد',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B923).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                emp['ShiftType'] ?? 'شيفت',
                style: GoogleFonts.cairo(
                  color: const Color(0xFFE8B923),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Divider(color: Colors.white.withOpacity(0.05), height: 1),
        const SizedBox(height: 10),
        
        // ✅ تاريخ البداية - الاسم الصحيح
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_circle, color: Color(0xFF4CAF50), size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بداية الشيفت',
                    style: GoogleFonts.cairo(
                      color: Colors.grey[500],
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    emp['EffectiveFrom'] ?? 'غير محدد',  // ✅ الاسم الصحيح
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // ✅ تاريخ النهاية - جديد
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.stop_circle, color: Color(0xFFE91E63), size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نهاية الشيفت',
                    style: GoogleFonts.cairo(
                      color: Colors.grey[500],
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    emp['EffectiveTo'] ?? 'حتى تاريخه',  // ✅ الاسم الصحيح
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_calendar, color: Colors.grey[600], size: 16),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildAddShiftButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE8B923).withOpacity(0.1),
            const Color(0xFFE8B923).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8B923).withOpacity(0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, color: const Color(0xFFE8B923), size: 16),
          const SizedBox(width: 8),
          Text(
            'إضافة شيفت جديد',
            style: GoogleFonts.cairo(
              color: const Color(0xFFE8B923),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 50, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'لا توجد نتائج',
            style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'حاول تعديل كلمات البحث أو الفلاتر',
            style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openAddShiftScreen(Map<String, dynamic> emp) async {
    // التحقق من صلاحية التعديل
    if (!PermissionService().canEdit(FormNames.employeeShifts)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية التعديل')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddShiftScreen(
          username: widget.username,
          employeeId: emp['EmployeeID'],
          employeeName: emp['FullName'],
          currentShift: emp['EmployeeShiftID'] != null ? emp : null, // بنبعت الشيفت الحالي لو موجود
        ),
      ),
    );

    if (result == true) {
      fetchData(); // تحديث القائمة
    }
  }
}