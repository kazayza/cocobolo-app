import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../constants.dart';
import '../services/permission_service.dart';
import 'request_permission_screen.dart';

class PermissionsListScreen extends StatefulWidget {
  final int userId;

  const PermissionsListScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<PermissionsListScreen> createState() => _PermissionsListScreenState();
}

class _PermissionsListScreenState extends State<PermissionsListScreen> with SingleTickerProviderStateMixin {
  List<dynamic> permissions = [];
  List<dynamic> filteredPermissions = [];
  bool loading = true;
  String selectedFilter = 'Pending';
  
  // إحصائيات
  int pendingCount = 0;
  int approvedCount = 0;
  int rejectedCount = 0;

  // فلتر إضافي
  String selectedTypeFilter = 'All';
  String searchQuery = '';
  DateTime? fromDate;
  DateTime? toDate;

  Timer? _debounceTimer;
  late TabController _tabController;

  bool get isManager {
    final perms = PermissionService();
    final role = (perms.role ?? '').toLowerCase();
    return perms.isAdmin || 
           perms.isSalesManager || 
           perms.isAccountManager ||
           role == 'hr' ||
           role == 'manager';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0: selectedFilter = 'Pending'; break;
            case 1: selectedFilter = 'Approved'; break;
            case 2: selectedFilter = 'Rejected'; break;
            case 3: selectedFilter = ''; break;
          }
        });
        _applyFilters();
      }
    });
    fetchPermissions();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchPermissions() async {
    setState(() => loading = true);
    try {
      final queryParams = {
        'role': PermissionService().role ?? 'User',
        'userId': widget.userId.toString(),
        if (selectedFilter.isNotEmpty) 'status': selectedFilter,
        if (selectedTypeFilter != 'All') 'type': selectedTypeFilter,
        if (searchQuery.isNotEmpty && isManager) 'employeeName': searchQuery,
        if (fromDate != null) 'fromDate': DateFormat('yyyy-MM-dd').format(fromDate!),
        if (toDate != null) 'toDate': DateFormat('yyyy-MM-dd').format(toDate!),
      };

      final uri = Uri.parse('$baseUrl/api/permissions/list').replace(queryParameters: queryParams);
      print('🌐 Fetching: $uri');

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        print('📦 Received ${data.length} permissions');
        
        setState(() {
          permissions = data;
          _calculateStats();
          _applyFilters();
          loading = false;
        });
      } else {
        print('❌ Error ${res.statusCode}: ${res.body}');
        setState(() => loading = false);
      }
    } catch (e) {
      print('🔥 Exception: $e');
      setState(() => loading = false);
    }
  }

  void _calculateStats() {
    pendingCount = permissions.where((p) => p['Status'] == 'Pending').length;
    approvedCount = permissions.where((p) => p['Status'] == 'Approved').length;
    rejectedCount = permissions.where((p) => p['Status'] == 'Rejected').length;
  }

  void _applyFilters() {
    setState(() {
      filteredPermissions = permissions.where((item) {
        // فلتر البحث
        if (searchQuery.isNotEmpty && isManager) {
          final name = item['FullName']?.toString().toLowerCase() ?? '';
          if (!name.contains(searchQuery.toLowerCase())) return false;
        }
        
        // فلتر النوع
        if (selectedTypeFilter != 'All') {
          if (item['PermissionType'] != selectedTypeFilter) return false;
        }
        
        return true;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    if (!isManager) return;
    setState(() => searchQuery = query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      fetchPermissions();
    });
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (fromDate ?? DateTime.now()) : (toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
      fetchPermissions();
    }
  }

  Future<void> takeAction(int id, String status) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/permissions/action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'permissionId': id,
          'status': status,
          'userId': widget.userId,
          'comment': status == 'Approved' ? 'تمت الموافقة' : 'تم الرفض',
        }),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(status == 'Approved' ? Icons.check_circle : Icons.cancel, color: Colors.white),
                const SizedBox(width: 8),
                Text(status == 'Approved' ? 'تمت الموافقة ✅' : 'تم الرفض ❌'),
              ],
            ),
            backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        fetchPermissions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ')),
      );
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.filter_list, color: Color(0xFFE8B923), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'تصفية الطلبات',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // فلتر النوع
              Text('نوع الطلب', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTypeChip('الكل', 'All', setModalState),
                  _buildTypeChip('تأخير صباحي', 'LateIn', setModalState),
                  _buildTypeChip('انصراف مبكر', 'EarlyOut', setModalState),
                  _buildTypeChip('مأمورية', 'Errands', setModalState),
                ],
              ),

              const SizedBox(height: 20),

              // فلتر التاريخ
              Text('الفترة الزمنية', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDateChip('من: ${fromDate != null ? DateFormat('yyyy/MM/dd').format(fromDate!) : 'غير محدد'}', () async {
                      await _selectDate(context, true);
                      Navigator.pop(context);
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDateChip('إلى: ${toDate != null ? DateFormat('yyyy/MM/dd').format(toDate!) : 'غير محدد'}', () async {
                      await _selectDate(context, false);
                      Navigator.pop(context);
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // زر إعادة تعيين
              TextButton.icon(
                onPressed: () {
                  setModalState(() {
                    selectedTypeFilter = 'All';
                    fromDate = null;
                    toDate = null;
                  });
                  setState(() {
                    selectedTypeFilter = 'All';
                    fromDate = null;
                    toDate = null;
                  });
                  fetchPermissions();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.refresh, color: Colors.grey),
                label: Text('إعادة تعيين', style: GoogleFonts.cairo(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String value, StateSetter setModalState) {
    final isSelected = selectedTypeFilter == value;
    return FilterChip(
      label: Text(label, style: GoogleFonts.cairo(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() => selectedTypeFilter = selected ? value : 'All');
        setState(() => selectedTypeFilter = selected ? value : 'All');
        fetchPermissions();
        Navigator.pop(context);
      },
      backgroundColor: Colors.grey[800],
      selectedColor: const Color(0xFFE8B923),
      checkmarkColor: Colors.black,
    );
  }

  Widget _buildDateChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 12, color: const Color(0xFFE8B923)),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.cairo(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
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
              child: const Icon(Icons.lock_open_rounded, color: Color(0xFFE8B923), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'الأذونات والطلبات',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isManager)
            IconButton(
              icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
              onPressed: _showFilterBottomSheet,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFE8B923),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFE8B923),
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: 'قيد الانتظار'),
            Tab(text: 'مقبولة'),
            Tab(text: 'مرفوضة'),
            Tab(text: 'الكل'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (isManager) _buildStatsRow(),
          if (isManager) _buildSearchBar(),
          Expanded(
            child: loading
                ? _buildLoadingState()
                : filteredPermissions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: fetchPermissions,
                        color: const Color(0xFFE8B923),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredPermissions.length,
                          itemBuilder: (context, index) => _buildPermissionCard(filteredPermissions[index], index),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RequestPermissionScreen(
                userId: widget.userId,
              ),
            ),
          );
          if (result == true) fetchPermissions();
        },
        label: Text('طلب جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFFE8B923),
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatItem('في الانتظار', pendingCount.toString(), Icons.hourglass_empty, Colors.orange),
          const SizedBox(width: 8),
          _buildStatItem('مقبول', approvedCount.toString(), Icons.check_circle, Colors.green),
          const SizedBox(width: 8),
          _buildStatItem('مرفوض', rejectedCount.toString(), Icons.cancel, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 8)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'بحث باسم الموظف...',
          hintStyle: GoogleFonts.cairo(color: Colors.grey[600]),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFE8B923), size: 18),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 16),
                  onPressed: () {
                    setState(() => searchQuery = '');
                    fetchPermissions();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFE8B923)),
          const SizedBox(height: 16),
          Text('جاري تحميل الطلبات...', style: GoogleFonts.cairo(color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(dynamic item, int index) {
    final status = item['Status'];
    final type = item['PermissionType'];
    final permissionDate = DateTime.parse(item['PermissionDate']);
    
    // ترجمة النوع
    String typeAr = type;
    IconData icon = Icons.info;
    Color typeColor = const Color(0xFFE8B923);
    
    if (type == 'LateIn') { 
      typeAr = 'تأخير صباحي'; 
      icon = Icons.timer_off; 
      typeColor = Colors.orange;
    } else if (type == 'EarlyOut') { 
      typeAr = 'انصراف مبكر'; 
      icon = Icons.exit_to_app; 
      typeColor = Colors.blue;
    } else if (type == 'Errands') { 
      typeAr = 'مأمورية'; 
      icon = Icons.work; 
      typeColor = Colors.purple;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // صورة الموظف
                  if (isManager)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          (item['FullName']?[0] ?? 'م').toUpperCase(),
                          style: GoogleFonts.cairo(
                            color: typeColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: typeColor, size: 18),
                    ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isManager)
                          Text(
                            item['FullName'] ?? 'موظف',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        Row(
                          children: [
                            Icon(icon, color: typeColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              typeAr,
                              style: GoogleFonts.cairo(
                                color: typeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  _buildStatusBadge(status),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // التاريخ والوقت
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('yyyy/MM/dd').format(permissionDate),
                        style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'من ${item['FromTime'] ?? '--'} إلى ${item['ToTime'] ?? '--'}',
                        style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 12),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // المدة
                  Row(
                    children: [
                      Icon(Icons.timer, size: 14, color: typeColor),
                      const SizedBox(width: 6),
                      Text(
                        'المدة: ${item['DurationMinutes'] ?? 0} دقيقة',
                        style: GoogleFonts.cairo(color: typeColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // السبب
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.message, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['Reason'] ?? 'لا يوجد سبب',
                            style: GoogleFonts.cairo(
                              color: Colors.grey[400],
                              fontSize: 12,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // تعليق المدير (لو موجود)
                  if (item['ManagerComment'] != null && item['ManagerComment'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: status == 'Approved' 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              status == 'Approved' ? Icons.info : Icons.warning,
                              size: 12,
                              color: status == 'Approved' ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item['ManagerComment'],
                                style: GoogleFonts.cairo(
                                  color: status == 'Approved' ? Colors.green : Colors.red,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Actions (للمدير فقط وفقط لو الحالة Pending)
            if (isManager && status == 'Pending')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => takeAction(item['PermissionID'], 'Approved'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('موافقة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => takeAction(item['PermissionID'], 'Rejected'),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('رفض'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, delay: (index * 50).ms);
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    String text = 'قيد الانتظار';
    IconData icon = Icons.hourglass_empty;

    if (status == 'Approved') { 
      color = Colors.green; 
      text = 'مقبول';
      icon = Icons.check_circle;
    }
    if (status == 'Rejected') { 
      color = Colors.red; 
      text = 'مرفوض';
      icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(color: color, fontSize: 9, fontWeight: FontWeight.bold),
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
          Icon(Icons.inbox, size: 60, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
            'لا توجد طلبات',
            style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'اسحب لأسفل للتحديث أو أضف طلب جديد',
            style: GoogleFonts.cairo(color: Colors.grey[700], fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: fetchPermissions,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8B923),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}