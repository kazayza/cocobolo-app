import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../constants.dart';
import '../services/permission_service.dart';
import '../core/auth/session_service.dart';

import '../widgets/app_drawer.dart';

class AllShiftsScreen extends StatefulWidget {
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
  final _contentKey = GlobalKey<AllShiftsContentState>();

  bool get _isDark => ThemeService().isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frm_AllShifts'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              AllShiftsContent.isManagerUser() ? 'متابعة الشيفتات' : 'شيفتاتي',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
            ),
          ],
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: const AppDrawerMenuButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            onPressed: () => _contentKey.currentState?.fetchShifts(),
          ),
        ],
      ),
      body: AllShiftsContent(
        key: _contentKey,
        userId: widget.userId,
        username: widget.username,
      ),
    );
  }
}

/// محتوى «متابعة الشيفتات» دون هيكل الشاشة — نفس الجلب والفلاتر
/// والحالة تُستخدم في الشاشة المستقلة وفي تبويب «المتابعة» داخل
/// شاشة «إدارة الشيفتات» الموحّدة دون أي ازدواج في المنطق.
class AllShiftsContent extends StatefulWidget {
  final int? userId;
  final String? username;

  const AllShiftsContent({
    super.key,
    this.userId,
    this.username,
  });

  @override
  State<AllShiftsContent> createState() => AllShiftsContentState();

  /// هل المستخدم الحالي مدير — نفس تعريف الشاشة الأصلي حرفيًا
  static bool isManagerUser() {
    final perms = PermissionService();
    return perms.isAdmin ||
        perms.isSalesManager ||
        perms.isAccountManager ||
        perms.isWarehouse ||
        (perms.role?.toLowerCase() == 'hr');
  }
}

class AllShiftsContentState extends State<AllShiftsContent> {
  List<dynamic> shifts = [];
  bool loading = true;

  int morningCount = 0;
  int eveningCount = 0;
  int dailyCount = 0;
  int activeCount = 0;
  int expiredCount = 0;

  String searchQuery = '';
  String selectedShiftType = 'الكل';
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now().add(const Duration(days: 30));

  Timer? _debounceTimer;

  // اسم الموظف الحقيقي للموظف العادي (يُجلب من سجله)
  String? _employeeFullName;

  bool get _isDark => ThemeService().isDarkMode;

  bool get isManager => AllShiftsContent.isManagerUser();

  /// لون نوع الشيفت — نفس تعريف نموذج الشيفت (ألوان بلازور)
  Color _shiftTypeColor(String? type) {
    switch (type) {
      case 'صباحى':
        return _isDark ? AppColors.successLight : AppColors.success;
      case 'مسائى':
        return _isDark ? AppColors.warningLight : AppColors.warning;
      case 'عمل يومى':
        return _isDark ? AppColors.infoLight : AppColors.info;
      default:
        return _isDark ? AppColors.neutralLight : AppColors.neutral;
    }
  }

  IconData _shiftTypeIcon(String? type) {
    switch (type) {
      case 'صباحى':
        return Icons.wb_sunny_rounded;
      case 'مسائى':
        return Icons.nights_stay_rounded;
      case 'عمل يومى':
        return Icons.work_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!isManager) {
      _loadEmployeeDataThenFetch();
    } else {
      fetchShifts();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // الموظف العادي: يجلب اسمه الحقيقي أولًا ثم يبحث به في الشيفتات
  Future<void> _loadEmployeeDataThenFetch() async {
    setState(() => loading = true);
    try {
      final perms = PermissionService();
      final int? empId = perms.employeeId;

      if (empId != null) {
        try {
          final empRes = await http.get(
            Uri.parse('$baseUrl/api/employees/$empId'),
            headers: SessionService.instance.authHeaders,
          );

          if (empRes.statusCode == 200) {
            final empData = jsonDecode(empRes.body);
            _employeeFullName = empData['FullName'] ??
                empData['fullName'] ??
                empData['full_name'] ??
                empData['Name'] ??
                empData['name'] ??
                '';
          }
        } catch (e) {
          // الاسم استكمال عرضي — البحث يمضي بدونه
        }
      }

      final queryParams = <String, String>{
        'fromDate': DateFormat('yyyy-MM-dd').format(fromDate),
        'toDate': DateFormat('yyyy-MM-dd').format(toDate),
      };

      if (selectedShiftType != 'الكل') {
        queryParams['shiftType'] = selectedShiftType;
      }

      if (_employeeFullName != null && _employeeFullName!.isNotEmpty) {
        queryParams['employeeName'] = _employeeFullName!;
      }

      final uri = Uri.parse('$baseUrl/api/shifts/search')
          .replace(queryParameters: queryParams);

      final res =
          await http.get(uri, headers: SessionService.instance.authHeaders);

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);

        setState(() {
          shifts = data;
          _calculateStats(data);
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> fetchShifts() async {
    // لو موظف عادي، نستخدم الدالة الخاصة به
    if (!isManager) {
      _loadEmployeeDataThenFetch();
      return;
    }

    // المدير يجلب كل الشيفتات
    setState(() => loading = true);
    try {
      final queryParams = <String, String>{
        'fromDate': DateFormat('yyyy-MM-dd').format(fromDate),
        'toDate': DateFormat('yyyy-MM-dd').format(toDate),
      };

      if (selectedShiftType != 'الكل') {
        queryParams['shiftType'] = selectedShiftType;
      }
      if (searchQuery.isNotEmpty) {
        queryParams['employeeName'] = searchQuery;
      }

      final uri = Uri.parse('$baseUrl/api/shifts/search')
          .replace(queryParameters: queryParams);
      final res =
          await http.get(uri, headers: SessionService.instance.authHeaders);

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          shifts = data;
          _calculateStats(data);
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void _calculateStats(List<dynamic> shiftsData) {
    morningCount = shiftsData.where((s) => s['ShiftType'] == 'صباحى').length;
    eveningCount = shiftsData.where((s) => s['ShiftType'] == 'مسائى').length;
    dailyCount = shiftsData.where((s) => s['ShiftType'] == 'عمل يومى').length;

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
      lastDate: DateTime(2035, 12, 31),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: ThemeService().accentColor,
                surface: AppColors.surface(_isDark),
                onSurface: AppColors.text(_isDark),
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
      fetchShifts();
    }
  }

  void _onSearchChanged(String query) {
    if (!isManager) return;

    setState(() => searchQuery = query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      fetchShifts();
    });
  }

  void _clearFilters() {
    setState(() {
      searchQuery = '';
      selectedShiftType = 'الكل';
      fromDate = DateTime.now().subtract(const Duration(days: 30));
      toDate = DateTime.now().add(const Duration(days: 30));
    });
    fetchShifts();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatsHeader(),
        _buildFiltersBar(),
        Expanded(
          child: loading
              ? _buildLoadingState()
              : shifts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: shifts.length,
                      itemBuilder: (context, index) {
                        return _buildShiftCard(shifts[index], index);
                      },
                    ),
        ),
      ],
    );
  }

  // بطاقة مرساة كحلية بإحصائيات الأنواع والحالة — هوية الشاشة
  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppGradients.identityHeader,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyDark.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem('صباحى', morningCount.toString(),
                  Icons.wb_sunny_rounded, AppColors.successLight),
            ),
            Expanded(
              child: _buildStatItem('مسائى', eveningCount.toString(),
                  Icons.nights_stay_rounded, AppColors.warningLight),
            ),
            Expanded(
              child: _buildStatItem('عمل يومى', dailyCount.toString(),
                  Icons.work_rounded, AppColors.infoLight),
            ),
            Expanded(
              child: _buildStatItem('ساري', activeCount.toString(),
                  Icons.check_circle_rounded, AppColors.gold),
            ),
            Expanded(
              child: _buildStatItem('منتهي', expiredCount.toString(),
                  Icons.history_rounded, AppColors.neutralLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(height: 4),
        AmountText(value: value, color: Colors.white, size: 15),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
              ),
        ),
      ],
    );
  }

  Widget _buildFiltersBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          // البحث للمدير فقط
          if (isManager)
            TextField(
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.text(_isDark),
                    fontSize: 14,
                  ),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الموظف...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _isDark
                          ? AppColors.textSecondary(_isDark)
                          : AppColors.textHint(_isDark),
                      fontSize: 14,
                    ),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.gold, size: 20),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            color: AppColors.textSecondary(_isDark), size: 18),
                        onPressed: () {
                          setState(() => searchQuery = '');
                          fetchShifts();
                        },
                      )
                    : null,
                filled: true,
                fillColor: _isDark
                    ? AppColors.card(_isDark)
                    : AppColors.inputFill(_isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: _isDark
                      ? BorderSide(color: Colors.white.withValues(alpha: 0.12))
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide(color: ThemeService().accentColor),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: _onSearchChanged,
            )
          else
            // للموظف العادي: اسمه الحقيقي + عدد شيفتاته
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface(_isDark),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.gold
                          .withValues(alpha: _isDark ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.gold, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'شيفتاتك الخاصة',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary(_isDark),
                                    fontSize: 10.5,
                                  ),
                        ),
                        Text(
                          _employeeFullName ?? 'جاري التحميل...',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.text(_isDark),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${shifts.length} شيفت',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.navy,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // صف التاريخ
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  'من: ${DateFormat('yyyy/MM/dd').format(fromDate)}',
                  Icons.calendar_today_rounded,
                  () => _selectDate(context, true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateButton(
                  'إلى: ${DateFormat('yyyy/MM/dd').format(toDate)}',
                  Icons.calendar_month_rounded,
                  () => _selectDate(context, false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // صف الأنواع
          Row(
            children: [
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
                      const SizedBox(width: 8),
                      _buildTypeChip('عمل يومى'),
                    ],
                  ),
                ),
              ),
              if (searchQuery.isNotEmpty || selectedShiftType != 'الكل')
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: (_isDark ? AppColors.errorLight : AppColors.error)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.clear_all_rounded,
                        color: _isDark ? AppColors.errorLight : AppColors.error,
                        size: 18),
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider(_isDark)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.gold, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.text(_isDark),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label) {
    final isSelected = selectedShiftType == label;
    final Color color =
        label == 'الكل' ? ThemeService().accentColor : _shiftTypeColor(label);

    return GestureDetector(
      onTap: () {
        setState(() => selectedShiftType = label);
        fetchShifts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: _isDark ? 0.22 : 0.12)
              : AppColors.surface(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? color : AppColors.divider(_isDark),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected ? color : AppColors.textSecondary(_isDark),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
        ),
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift, int index) {
    final typeColor = _shiftTypeColor(shift['ShiftType']?.toString());
    final textTheme = Theme.of(context).textTheme;

    bool isExpired = false;
    if (shift['EndDate'] != null) {
      try {
        final endDate = DateTime.parse(shift['EndDate']);
        isExpired = endDate.isBefore(DateTime.now());
      } catch (e) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        color: AppColors.surface(_isDark),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: typeColor.withValues(
                                  alpha: _isDark ? 0.18 : 0.10),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Center(
                              child: Text(
                                (shift['FullName'] ?? '?').toString().isNotEmpty
                                    ? (shift['FullName'] as String)[0]
                                        .toUpperCase()
                                    : '?',
                                style: textTheme.titleMedium?.copyWith(
                                  color: typeColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shift['FullName'] ?? '',
                                  style: textTheme.titleSmall?.copyWith(
                                    color: AppColors.text(_isDark),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  shift['JobTitle'] ?? '',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary(_isDark),
                                    fontSize: 11.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: isExpired ? 'منتهي' : 'ساري',
                            color: isExpired
                                ? (_isDark
                                    ? AppColors.errorLight
                                    : AppColors.error)
                                : (_isDark
                                    ? AppColors.successLight
                                    : AppColors.success),
                            icon: isExpired
                                ? Icons.history_rounded
                                : Icons.check_circle_rounded,
                            small: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(height: 1, color: AppColors.divider(_isDark)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.gold
                                  .withValues(alpha: _isDark ? 0.18 : 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.access_time_rounded,
                                size: 14, color: AppColors.gold),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'موعد الشيفت',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary(_isDark),
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  '${shift['StartTime']} - ${shift['EndTime']}',
                                  style: textTheme.titleSmall?.copyWith(
                                    color: AppColors.text(_isDark),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: shift['ShiftType']?.toString() ?? '',
                            color: typeColor,
                            icon:
                                _shiftTypeIcon(shift['ShiftType']?.toString()),
                            small: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (_isDark
                                      ? AppColors.successLight
                                      : AppColors.success)
                                  .withValues(alpha: _isDark ? 0.18 : 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.date_range_rounded,
                                size: 14,
                                color: _isDark
                                    ? AppColors.successLight
                                    : AppColors.success),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تاريخ السريان',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary(_isDark),
                                    fontSize: 10,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      shift['StartDate'] ?? '',
                                      style: textTheme.titleSmall?.copyWith(
                                        color: AppColors.text(_isDark),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded,
                                        color: AppColors.textSecondary(_isDark),
                                        size: 11),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        shift['EndDate'] ?? 'الى تاريخه',
                                        style: textTheme.titleSmall?.copyWith(
                                          color: shift['EndDate'] == null
                                              ? (_isDark
                                                  ? AppColors.successLight
                                                  : AppColors.success)
                                              : AppColors.textSecondary(
                                                  _isDark),
                                          fontSize: 12,
                                          fontWeight: shift['EndDate'] == null
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                        ),
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
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 240.ms, delay: (index * 40).ms)
        .slideX(begin: 0.04);
  }

  Widget _buildLoadingState() {
    return const AppLoading(message: 'جاري تحميل الشيفتات...');
  }

  Widget _buildEmptyState() {
    return AppEmpty(
      icon: Icons.calendar_month_rounded,
      message: 'لا توجد شيفتات',
      hint: 'جرب تغيير نطاق التاريخ أو الفلاتر',
      onRefresh: _clearFilters,
      refreshLabel: 'إعادة تعيين الفلاتر',
    );
  }
}
