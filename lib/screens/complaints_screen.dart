import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/complaint_model.dart';
import '../services/complaints_service.dart';
import '../services/theme_service.dart';
import '../services/app_colors.dart';
import 'complaint_details_screen.dart';
import 'add_complaint_screen.dart';

class ComplaintsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ComplaintsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  bool _isLoading = true;
  List<ComplaintModel> _complaints = [];
  List<ComplaintModel> _filteredComplaints = [];
  String? _error;

  // الفلاتر
  int? _selectedStatus;
  int? _selectedPriority;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===================================
  // تحميل الشكاوى
  // ===================================
  Future<void> _loadComplaints() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final complaints = await ComplaintsService.getAllComplaints();
      setState(() {
        _complaints = complaints;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل في تحميل الشكاوى';
        _isLoading = false;
      });
    }
  }

  // ===================================
  // تطبيق الفلاتر
  // ===================================
  void _applyFilters() {
    List<ComplaintModel> filtered = List.from(_complaints);

    // فلتر الحالة
    if (_selectedStatus != null) {
      filtered = filtered.where((c) => c.status == _selectedStatus).toList();
    }

    // فلتر الأولوية
    if (_selectedPriority != null) {
      filtered = filtered.where((c) => c.priority == _selectedPriority).toList();
    }

    // فلتر البحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((c) =>
          (c.subject.toLowerCase().contains(_searchQuery.toLowerCase())) ||
          (c.clientName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (c.complaintType?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    setState(() {
      _filteredComplaints = filtered;
    });
  }

  // ===================================
  // حساب الإحصائيات
  // ===================================
  Map<String, int> get _stats {
    return {
      'total': _complaints.length,
      'new': _complaints.where((c) => c.status == 1).length,
      'inProgress': _complaints.where((c) => c.status == 2).length,
      'waiting': _complaints.where((c) => c.status == 3).length,
      'resolved': _complaints.where((c) => c.status == 4).length,
      'rejected': _complaints.where((c) => c.status == 5).length,
      'escalated': _complaints.where((c) => c.status == 6).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _buildAppBar(isDark),
      body: _isLoading
          ? _buildLoading(isDark)
          : _error != null
              ? _buildError(isDark)
              : _buildBody(isDark),
      floatingActionButton: _buildFAB(isDark),
    );
  }

  // ===================================
  // AppBar
  // ===================================
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.navy : Colors.white,
      elevation: 0,
      title: Text(
        'الشكاوى',
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.navy,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: isDark ? Colors.white : AppColors.navy,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: isDark ? AppColors.gold : AppColors.navy,
          ),
          onPressed: _loadComplaints,
        ),
      ],
    );
  }

  // ===================================
  // Loading
  // ===================================
  Widget _buildLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.gold),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل الشكاوى...',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  // Error
  // ===================================
  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadComplaints,
            icon: const Icon(Icons.refresh),
            label: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  // Body
  // ===================================
  Widget _buildBody(bool isDark) {
    return Column(
      children: [
        // شريط البحث
        _buildSearchBar(isDark),

        // الإحصائيات
        _buildStatsCards(isDark),

        // فلاتر الحالة
        _buildStatusFilters(isDark),

        // قائمة الشكاوى
        Expanded(
          child: _filteredComplaints.isEmpty
              ? _buildEmptyState(isDark)
              : _buildComplaintsList(isDark),
        ),
      ],
    );
  }

  // ===================================
  // شريط البحث
  // ===================================
  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.cairo(color: AppColors.text(isDark)),
        decoration: InputDecoration(
          hintText: 'بحث بالعنوان أو اسم العميل...',
          hintStyle: GoogleFonts.cairo(color: AppColors.textHint(isDark)),
          prefixIcon: Icon(Icons.search, color: AppColors.textHint(isDark)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppColors.textHint(isDark)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _applyFilters();
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.inputFill(isDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _applyFilters();
          });
        },
      ),
    );
  }

  // ===================================
  // كروت الإحصائيات
  // ===================================
  Widget _buildStatsCards(bool isDark) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatCard(
            isDark: isDark,
            title: 'الكل',
            count: _stats['total']!,
            color: AppColors.gold,
            isSelected: _selectedStatus == null,
            onTap: () {
              setState(() {
                _selectedStatus = null;
                _applyFilters();
              });
            },
          ),
          _buildStatCard(
            isDark: isDark,
            title: 'جديدة',
            count: _stats['new']!,
            color: Colors.blue,
            isSelected: _selectedStatus == 1,
            onTap: () {
              setState(() {
                _selectedStatus = _selectedStatus == 1 ? null : 1;
                _applyFilters();
              });
            },
          ),
          _buildStatCard(
            isDark: isDark,
            title: 'قيد الحل',
            count: _stats['inProgress']!,
            color: Colors.orange,
            isSelected: _selectedStatus == 2,
            onTap: () {
              setState(() {
                _selectedStatus = _selectedStatus == 2 ? null : 2;
                _applyFilters();
              });
            },
          ),
          _buildStatCard(
            isDark: isDark,
            title: 'انتظار',
            count: _stats['waiting']!,
            color: Colors.amber,
            isSelected: _selectedStatus == 3,
            onTap: () {
              setState(() {
                _selectedStatus = _selectedStatus == 3 ? null : 3;
                _applyFilters();
              });
            },
          ),
          _buildStatCard(
            isDark: isDark,
            title: 'محلولة',
            count: _stats['resolved']!,
            color: Colors.green,
            isSelected: _selectedStatus == 4,
            onTap: () {
              setState(() {
                _selectedStatus = _selectedStatus == 4 ? null : 4;
                _applyFilters();
              });
            },
          ),
          _buildStatCard(
            isDark: isDark,
            title: 'مصعدة',
            count: _stats['escalated']!,
            color: Colors.purple,
            isSelected: _selectedStatus == 6,
            onTap: () {
              setState(() {
                _selectedStatus = _selectedStatus == 6 ? null : 6;
                _applyFilters();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required String title,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppColors.card(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count.toString(),
              style: GoogleFonts.cairo(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================
  // فلاتر الأولوية
  // ===================================
  Widget _buildStatusFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'الأولوية:',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary(isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPriorityChip(isDark, null, 'الكل'),
                  _buildPriorityChip(isDark, 1, 'عالية جداً', Colors.red.shade700),
                  _buildPriorityChip(isDark, 2, 'عالية', Colors.orange),
                  _buildPriorityChip(isDark, 3, 'متوسطة', Colors.amber),
                  _buildPriorityChip(isDark, 4, 'منخفضة', Colors.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(bool isDark, int? priority, String label, [Color? color]) {
    final isSelected = _selectedPriority == priority;
    final chipColor = color ?? AppColors.gold;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: isSelected ? Colors.white : AppColors.text(isDark),
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedPriority = selected ? priority : null;
            _applyFilters();
          });
        },
        backgroundColor: AppColors.card(isDark),
        selectedColor: chipColor,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  // ===================================
  // قائمة الشكاوى
  // ===================================
  Widget _buildComplaintsList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadComplaints,
      color: AppColors.gold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredComplaints.length,
        itemBuilder: (context, index) {
          return _buildComplaintCard(_filteredComplaints[index], isDark);
        },
      ),
    );
  }

  // ===================================
  // كارت الشكوى
  // ===================================
  Widget _buildComplaintCard(ComplaintModel complaint, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailsScreen(
              complaintId: complaint.complaintId,
              userId: widget.userId,
              username: widget.username,
            ),
          ),
        );
        if (result == true) {
          _loadComplaints();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header: الأولوية + الحالة
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _getPriorityColor(complaint.priority).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // الأولوية
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(complaint.priority),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      complaint.priorityText,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // الحالة
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(complaint.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(complaint.status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      complaint.statusText,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: _getStatusColor(complaint.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // العنوان
                  Text(
                    complaint.subject,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(isDark),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // معلومات العميل والتاريخ
                  Row(
                    children: [
                      // العميل
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: AppColors.textSecondary(isDark),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                complaint.clientName ?? 'غير محدد',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  color: AppColors.textSecondary(isDark),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // التاريخ
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.textSecondary(isDark),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(complaint.complaintDate),
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // نوع الشكوى
                  if (complaint.complaintType != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 16,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          complaint.complaintType!,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // علامة التصعيد
                  if (complaint.escalated) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_upward,
                            size: 14,
                            color: Colors.purple,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'مصعدة',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: Colors.purple,
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }

  // ===================================
  // حالة فارغة
  // ===================================
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: AppColors.textHint(isDark),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد شكاوى',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على + لإضافة شكوى جديدة',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textHint(isDark),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  // FAB
  // ===================================
  Widget _buildFAB(bool isDark) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddComplaintScreen(
              userId: widget.userId,
              username: widget.username,
            ),
          ),
        );
        if (result == true) {
          _loadComplaints();
        }
      },
      backgroundColor: AppColors.gold,
      icon: Icon(Icons.add, color: AppColors.navy),
      label: Text(
        'شكوى جديدة',
        style: GoogleFonts.cairo(
          color: AppColors.navy,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ===================================
  // Helper Functions
  // ===================================
  Color _getStatusColor(int status) {
    switch (status) {
      case 1: return Colors.blue;
      case 2: return Colors.orange;
      case 3: return Colors.amber;
      case 4: return Colors.green;
      case 5: return Colors.red;
      case 6: return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1: return Colors.red.shade700;
      case 2: return Colors.orange;
      case 3: return Colors.amber.shade700;
      case 4: return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }
}