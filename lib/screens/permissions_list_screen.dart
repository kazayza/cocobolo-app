import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../widgets/design_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../constants.dart';
import '../services/permission_service.dart';
import 'request_permission_screen.dart';
import '../core/auth/session_service.dart';

import '../widgets/app_drawer.dart';
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

      final res = await http.get(uri, headers: SessionService.instance.authHeaders);

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
            primary: AppColors.gold,
            surface: AppColors.darkSurface,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: AppColors.darkSurface,
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
        headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
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
            backgroundColor: status == 'Approved' ? AppColors.success : AppColors.error,
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
      backgroundColor: AppColors.darkSurface,
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
                  const Icon(Icons.filter_list, color: AppColors.gold, size: 20),
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
      selectedColor: AppColors.gold,
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
            Icon(Icons.calendar_today, size: 12, color: AppColors.gold),
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
      drawer: buildAppDrawer(currentRoute: 'frm_MyPermissions'),
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_open_rounded, color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'الأذونات والطلبات',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: const AppDrawerMenuButton(),
        actions: [
          if (isManager)
            IconButton(
              icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
              onPressed: _showFilterBottomSheet,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.gold,
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
                        color: AppColors.gold,
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
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatItem('في الانتظار', pendingCount.toString(), Icons.hourglass_empty, AppColors.warning),
          const SizedBox(width: 8),
          _buildStatItem('مقبول', approvedCount.toString(), Icons.check_circle, AppColors.success),
          const SizedBox(width: 8),
          _buildStatItem('مرفوض', rejectedCount.toString(), Icons.cancel, AppColors.error),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: AppStatCard(label: label, value: value, color: color, icon: icon),
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
          prefixIcon: const Icon(Icons.search, color: AppColors.gold, size: 18),
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
          fillColor: Colors.white.withValues(alpha: 0.05),
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
    return const AppLoading(message: 'جاري تحميل الطلبات...');
  }

  Widget _buildPermissionCard(dynamic item, int index) {
    final status = item['Status'];
    final type = item['PermissionType'];
    final permissionDate = DateTime.parse(item['PermissionDate']);
    
    // ترجمة النوع
    String typeAr = type;
    IconData icon = Icons.info;
    Color typeColor = AppColors.gold;
    
    if (type == 'LateIn') { 
      typeAr = 'تأخير صباحي'; 
      icon = Icons.timer_off; 
      typeColor = AppColors.warning;
    } else if (type == 'EarlyOut') { 
      typeAr = 'انصراف مبكر'; 
      icon = Icons.exit_to_app; 
      typeColor = AppColors.info;
    } else if (type == 'Errands') { 
      typeAr = 'مأمورية'; 
      icon = Icons.work; 
      typeColor = AppStatus.editPending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.all(AppRadius.lg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              ),
              child: Row(
                children: [
                  // صورة الموظف
                  if (isManager)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
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
                        color: typeColor.withValues(alpha: 0.1),
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
                      color: Colors.white.withValues(alpha: 0.02),
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
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              status == 'Approved' ? Icons.info : Icons.warning,
                              size: 12,
                              color: status == 'Approved' ? AppColors.success : AppColors.error,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item['ManagerComment'],
                                style: GoogleFonts.cairo(
                                  color: status == 'Approved' ? AppColors.success : AppColors.error,
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
                          backgroundColor: AppColors.success,
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
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
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
    Color color = AppColors.warning;
    String text = 'قيد الانتظار';
    IconData icon = Icons.hourglass_empty;

    if (status == 'Approved') { 
      color = AppColors.success; 
      text = 'مقبول';
      icon = Icons.check_circle;
    }
    if (status == 'Rejected') { 
      color = AppColors.error; 
      text = 'مرفوض';
      icon = Icons.cancel;
    }

    return StatusBadge(label: text, color: color, icon: icon, small: true);
  }

  Widget _buildEmptyState() {
    return AppEmpty(
      message: 'لا توجد طلبات',
      hint: 'اسحب لأسفل للتحديث أو أضف طلب جديد',
      icon: Icons.inbox,
      onRefresh: fetchPermissions,
      refreshLabel: 'تحديث',
    );
  }
}