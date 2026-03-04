import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../constants.dart';
import '../services/permission_service.dart'; // ✅ استيراد الصلاحيات

class AllShiftsScreen extends StatefulWidget {
  // ✅ إضافة المتغيرات دي
  final int? userId;
  final String? username;

  const AllShiftsScreen({
    Key? key,
    this.userId,
    this.username,
  }) : super(key: key);

  @override
  State<AllShiftsScreen> createState() => _AllShiftsScreenState();
}

class _AllShiftsScreenState extends State<AllShiftsScreen> {
  List<dynamic> shifts = [];
  bool loading = true;

  // إحصائيات
  int morningCount = 0;
  int eveningCount = 0;
  int activeCount = 0;
  int expiredCount = 0;

  // Filters
  String searchQuery = '';
  String selectedShiftType = 'الكل';
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now().add(const Duration(days: 30));
  
  // للـ Debounce
  Timer? _debounceTimer;

  // ✅ التحقق من الصلاحيات (هل هو مدير؟)
  bool get isManager {
    final perms = PermissionService();
    // حدد الأدوار اللي مسموح لها تشوف كل الشيفتات
    return perms.isAdmin || 
           perms.isSalesManager || 
           perms.isAccountManager || 
           perms.isWarehouse ||
           (perms.role?.toLowerCase() == 'hr'); // لو عندك دور HR
  }

  @override
  void initState() {
    super.initState();
    // ✅ لو موظف عادي، نثبت البحث على اسمه
    if (!isManager) {
      searchQuery = PermissionService().fullName ?? '';
    }
    fetchShifts();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchShifts() async {
    setState(() => loading = true);
    try {
      final queryParams = {
        'fromDate': DateFormat('yyyy-MM-dd').format(fromDate),
        'toDate': DateFormat('yyyy-MM-dd').format(toDate),
        if (selectedShiftType != 'الكل') 'shiftType': selectedShiftType,
        if (searchQuery.isNotEmpty) 'employeeName': searchQuery,
      };

      final uri = Uri.parse('$baseUrl/api/shifts/search').replace(queryParameters: queryParams);
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          shifts = data;
          _calculateStats(data);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
      print('Error fetching shifts: $e');
    }
  }

  void _calculateStats(List<dynamic> shiftsData) {
    morningCount = shiftsData.where((s) => s['ShiftType'] == 'صباحى').length;
    eveningCount = shiftsData.where((s) => s['ShiftType'] == 'مسائى').length;
    
    final now = DateTime.now();
    activeCount = shiftsData.where((s) {
      if (s['EndDate'] == null) return true;
      try {
        final endDate = DateTime.parse(s['EndDate']);
        return endDate.isAfter(now);
      } catch (e) {
        return true;
      }
    }).length;
    
    expiredCount = shiftsData.length - activeCount;
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE8B923),
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1E1E1E),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) fromDate = picked; else toDate = picked;
      });
      fetchShifts();
    }
  }

  void _onSearchChanged(String query) {
    // ✅ لو موظف عادي، نمنعه يغير البحث
    if (!isManager) return;

    setState(() => searchQuery = query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      fetchShifts();
    });
  }

  void _clearFilters() {
    setState(() {
      // ✅ لو موظف عادي، نرجع اسمه في البحث
      searchQuery = isManager ? '' : (PermissionService().fullName ?? '');
      selectedShiftType = 'الكل';
      fromDate = DateTime.now().subtract(const Duration(days: 30));
      toDate = DateTime.now().add(const Duration(days: 30));
    });
    fetchShifts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B923).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month, color: Color(0xFFE8B923), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'متابعة الشيفتات',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: fetchShifts,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsHeader(),
          _buildFiltersBar(),
          Expanded(
            child: loading
                ? _buildLoadingState()
                : shifts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: shifts.length,
                        itemBuilder: (context, index) {
                          return _buildShiftCard(shifts[index], index);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('صباحى', morningCount.toString(), Icons.wb_sunny, Colors.orange),
          _buildStatItem('مسائى', eveningCount.toString(), Icons.nights_stay, Colors.blue),
          _buildStatItem('ساري', activeCount.toString(), Icons.check_circle, Colors.green),
          _buildStatItem('منتهي', expiredCount.toString(), Icons.history, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        children: [
          // ✅ شريط البحث (يظهر فقط للمدير)
          if (isManager)
            TextField(
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الموظف...',
                hintStyle: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE8B923), size: 20),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                        onPressed: () {
                          setState(() => searchQuery = '');
                          fetchShifts();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: _onSearchChanged,
            )
          else
            // ✅ للموظف العادي: عرض اسمه فقط
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE8B923).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFFE8B923), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'شيفتاتك الخاصة: ${PermissionService().fullName ?? widget.username ?? ""}',
                      style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // صف التاريخ والفلتر
          Row(
            children: [
              // أزرار التاريخ
              Expanded(
                child: _buildDateButton(
                  'من: ${DateFormat('yyyy/MM/dd').format(fromDate)}',
                  Icons.calendar_today,
                  () => _selectDate(context, true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateButton(
                  'إلى: ${DateFormat('yyyy/MM/dd').format(toDate)}',
                  Icons.calendar_month,
                  () => _selectDate(context, false),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // صف الأنواع ومسح الفلاتر
          Row(
            children: [
              // أنواع الشيفت
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypeChip('الكل'),
                      const SizedBox(width: 8),
                      _buildTypeChip('صباحى'),
                      const SizedBox(width: 8),
                      _buildTypeChip('مسائى'),
                    ],
                  ),
                ),
              ),
              
              // زر مسح الفلاتر (يظهر لو فيه فلتر نشط)
              if (isManager && (searchQuery.isNotEmpty || selectedShiftType != 'الكل' || 
                  fromDate != DateTime.now().subtract(const Duration(days: 30)) ||
                  toDate != DateTime.now().add(const Duration(days: 30))))
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.clear_all, color: Colors.red, size: 18),
                    onPressed: _clearFilters,
                    tooltip: 'مسح الفلاتر',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE8B923), size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label) {
    final isSelected = selectedShiftType == label;
    final Color color = label == 'صباحى' ? Colors.orange : (label == 'مسائى' ? Colors.blue : Colors.grey);
    
    return GestureDetector(
      onTap: () {
        setState(() => selectedShiftType = label);
        fetchShifts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? color : Colors.grey[400],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift, int index) {
    final isMorning = shift['ShiftType'] == 'صباحى';
    final Color shiftColor = isMorning ? Colors.orange : Colors.blue;
    
    // التحقق من انتهاء الشيفت
    bool isExpired = false;
    if (shift['EndDate'] != null) {
      try {
        final endDate = DateTime.parse(shift['EndDate']);
        isExpired = endDate.isBefore(DateTime.now());
      } catch (e) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border(
          left: BorderSide(color: shiftColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: shiftColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // السطر الأول: الاسم والحالة
            Row(
              children: [
                // الصورة المصغرة
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: shiftColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (shift['FullName'] ?? '?')[0].toUpperCase(),
                      style: GoogleFonts.cairo(
                        color: shiftColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // الاسم والوظيفة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift['FullName'] ?? '',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shift['JobTitle'] ?? '',
                        style: GoogleFonts.cairo(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // حالة الشيفت
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpired ? Icons.history : Icons.check_circle,
                        size: 10,
                        color: isExpired ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired ? 'منتهي' : 'ساري',
                        style: GoogleFonts.cairo(
                          color: isExpired ? Colors.red : Colors.green,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            const SizedBox(height: 12),

            // وقت الشيفت
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8B923).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.access_time, size: 14, color: Color(0xFFE8B923)),
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
                        '${shift['StartTime']} - ${shift['EndTime']}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: shiftColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    shift['ShiftType'] ?? '',
                    style: GoogleFonts.cairo(
                      color: shiftColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),

            // تاريخ الشيفت
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.date_range, size: 14, color: Colors.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تاريخ السريان',
                        style: GoogleFonts.cairo(
                          color: Colors.grey[500],
                          fontSize: 9,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            shift['StartDate'] ?? '',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward, color: Colors.grey, size: 10),
                          const SizedBox(width: 6),
                          Text(
                            shift['EndDate'] ?? 'الى تاريخه',
                            style: GoogleFonts.cairo(
                              color: shift['EndDate'] == null ? Colors.green : Colors.grey[400],
                              fontSize: 12,
                              fontWeight: shift['EndDate'] == null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 50)).slideX();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFE8B923), strokeWidth: 2)
              .animate().fadeIn().scale(),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل الشيفتات...',
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_month, size: 50, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد شيفتات',
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'جرب تغيير نطاق التاريخ أو الفلاتر',
            style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              'إعادة تعيين الفلاتر',
              style: GoogleFonts.cairo(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE8B923),
              side: const BorderSide(color: Color(0xFFE8B923)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}