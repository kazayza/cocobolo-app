import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../services/permission_service.dart';
import 'add_shift_screen.dart';
import 'all_shifts_screen.dart';
import '../core/auth/session_service.dart';

import '../widgets/app_drawer.dart';

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
  final _contentKey = GlobalKey<EmployeeShiftsContentState>();

  // بوابة العرض كما كانت: من لا يملك canView يُطرد برسالة فور الفتح
  bool _denied = false;

  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    // التحقق من الصلاحية
    if (!PermissionService().canView(FormNames.employeeShifts)) {
      _denied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ليس لديك صلاحية لعرض هذه الشاشة')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frm_EmpolyeeShifts'),
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
              child: const Icon(Icons.schedule_rounded,
                  color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'إدارة الشيفتات',
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
            icon: const Icon(Icons.history_edu_rounded, size: 18),
            tooltip: 'سجل الشيفتات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AllShiftsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            onPressed: () => _contentKey.currentState?.fetchData(),
          ),
        ],
      ),
      body: _denied
          ? const AppLoading(message: 'جاري تحميل البيانات...')
          : EmployeeShiftsContent(
              key: _contentKey,
              userId: widget.userId,
              username: widget.username,
            ),
    );
  }
}

/// محتوى «شيفتات الموظفين» (قائمة الموظفين وحالة شيفت كل منهم) دون
/// هيكل الشاشة — نفس الجلب والبحث والفلاتر والإجراءات تُستخدم في
/// الشاشة المستقلة وفي تبويب «حسب الموظف» داخل «إدارة الشيفتات».
class EmployeeShiftsContent extends StatefulWidget {
  final int userId;
  final String username;

  const EmployeeShiftsContent({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<EmployeeShiftsContent> createState() => EmployeeShiftsContentState();
}

class EmployeeShiftsContentState extends State<EmployeeShiftsContent> {
  List<dynamic> employees = [];
  List<dynamic> filteredEmployees = [];
  bool loading = true;
  String searchQuery = '';

  // فلتر إضافي
  String? selectedFilter; // null = الكل, assigned = لهم شيفت, missing = بدون

  // إحصائيات
  int totalEmployees = 0;
  int assignedShifts = 0;
  int missingShifts = 0;

  bool get _isDark => ThemeService().isDarkMode;

  // أسماء أيام الأسبوع بأرقام .NET DayOfWeek: 0=الأحد .. 6=السبت
  static const List<String> _weekdayNames = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  /// نص أيام الراحة من سجل الحالة (OffDay1/OffDay2) أو null عند غيابها
  static String? _offDaysText(Map<String, dynamic> emp) {
    final days = <String>[];
    for (final key in ['OffDay1', 'OffDay2', 'offDay1', 'offDay2']) {
      final v = emp[key];
      int? i;
      if (v is num) {
        i = v.toInt();
      } else if (v != null) {
        i = int.tryParse(v.toString().trim());
      }
      if (i != null && i >= 0 && i <= 6) {
        final name = _weekdayNames[i];
        if (!days.contains(name)) days.add(name);
      }
    }
    return days.isEmpty ? null : days.join(' و ');
  }

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

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/shifts/status'),
          headers: SessionService.instance.authHeaders);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          employees = data;
          filteredEmployees = data;

          // حساب الإحصائيات
          totalEmployees = data.length;
          assignedShifts =
              data.where((e) => e['EmployeeShiftID'] != null).length;
          missingShifts = totalEmployees - assignedShifts;

          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
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
            (emp['FullName']
                    ?.toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()) ??
                false) ||
            (emp['JobTitle']
                    ?.toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()) ??
                false);

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
    return loading
        ? const AppLoading(message: 'جاري تحميل البيانات...')
        : Column(
            children: [
              _buildStatsHeader(),
              _buildSearchBar(),
              Expanded(
                child: filteredEmployees.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filteredEmployees.length,
                        itemBuilder: (context, index) {
                          return _buildEmployeeCard(
                              filteredEmployees[index], index);
                        },
                      ),
              ),
            ],
          );
  }

  // بطاقة مرساة كحلية بالإحصائيات — هوية الشاشة في الوضعين
  Widget _buildStatsHeader() {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -30,
                start: -30,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.10),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.people_alt_rounded,
                              color: AppColors.gold, size: 19),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'إحصائيات الشيفتات',
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '$totalEmployees موظف',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                              'الموظفين',
                              '$totalEmployees',
                              Icons.people_rounded,
                              _isDark ? AppColors.infoLight : AppColors.info),
                        ),
                        Container(
                            width: 1,
                            height: 38,
                            color: Colors.white.withValues(alpha: 0.12)),
                        Expanded(
                          child: _buildStatItem(
                              'لهم شيفت',
                              '$assignedShifts',
                              Icons.check_circle_rounded,
                              AppColors.successLight),
                        ),
                        Container(
                            width: 1,
                            height: 38,
                            color: Colors.white.withValues(alpha: 0.12)),
                        Expanded(
                          child: _buildStatItem('بدون شيفت', '$missingShifts',
                              Icons.warning_rounded, AppColors.gold),
                        ),
                      ],
                    ),
                    if (missingShifts > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.goldLight, size: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'يوجد $missingShifts موظفين بدون شيفت',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.goldLight,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
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
        ),
      ),
    ).animate().fadeIn(duration: 260.ms).slideY(begin: -0.08, end: 0);
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(height: 5),
        AmountText(value: value, color: Colors.white, size: 20),
        const SizedBox(height: 2),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
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
                        _filterEmployees('');
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
            onChanged: _filterEmployees,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildFilterChip('الكل', null),
              const SizedBox(width: 8),
              _buildFilterChip('لهم شيفت', 'assigned'),
              const SizedBox(width: 8),
              _buildFilterChip('بدون شيفت', 'missing'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? filterValue) {
    final isSelected = selectedFilter == filterValue;
    // حبة ممتلئة عند الاختيار: ذهبي بنص كحلي ليليًا، كحلي بنص أبيض نهاريًا
    final bg = isSelected
        ? (_isDark ? AppColors.gold : AppColors.navy)
        : (_isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark));
    final fg = isSelected
        ? (_isDark ? AppColors.navy : Colors.white)
        : AppColors.textSecondary(_isDark);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            selectedFilter = selectedFilter == filterValue ? null : filterValue;
            _applyFilters();
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp, int index) {
    final bool hasShift = emp['EmployeeShiftID'] != null;
    final statusColor = hasShift
        ? (_isDark ? AppColors.successLight : AppColors.success)
        : (_isDark ? AppColors.warningLight : AppColors.warning);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: hasShift ? () => _confirmDeleteShift(emp) : null,
        child: AppCard(
          padding: const EdgeInsets.all(14),
          color: AppColors.surface(_isDark),
          onTap: () => _openAddShiftScreen(emp),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEmployeeAvatar(emp, hasShift),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                emp['FullName'] ?? '',
                                style: textTheme.titleMedium?.copyWith(
                                  color: AppColors.text(_isDark),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(
                              label: hasShift ? 'مسجل' : 'بدون',
                              color: statusColor,
                              icon: hasShift
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_amber_rounded,
                              small: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.work_outline_rounded,
                                size: 12,
                                color: AppColors.textSecondary(_isDark)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                emp['JobTitle'] ?? 'بدون مسمى وظيفي',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary(_isDark),
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (emp['DepartmentName'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.business_center_rounded,
                                  size: 12,
                                  color: AppColors.textSecondary(_isDark)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  emp['DepartmentName'],
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary(_isDark),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (hasShift) _buildShiftDetails(emp) else _buildAddShiftButton(),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 240.ms, delay: (index * 40).ms)
        .slideX(begin: 0.04);
  }

  Widget _buildEmployeeAvatar(Map<String, dynamic> emp, bool hasShift) {
    final String initial = (emp['FullName'] ?? '?').toString().isNotEmpty
        ? (emp['FullName'] as String)[0].toUpperCase()
        : '?';
    final Color avatarColor = hasShift
        ? (_isDark ? AppColors.successLight : AppColors.success)
        : (_isDark ? AppColors.gold : AppColors.goldDark);

    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: _isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: avatarColor.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: avatarColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
        if (hasShift)
          PositionedDirectional(
            bottom: -1,
            end: -1,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _isDark ? AppColors.successLight : AppColors.success,
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.surface(_isDark), width: 1.5),
              ),
              child:
                  const Icon(Icons.check_rounded, color: Colors.white, size: 9),
            ),
          ),
      ],
    );
  }

  Widget _buildShiftDetails(Map<String, dynamic> emp) {
    final textTheme = Theme.of(context).textTheme;
    final typeColor = _shiftTypeColor(emp['ShiftType']?.toString());
    final offDays = _offDaysText(emp);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withValues(alpha: 0.03)
            : AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:
                      AppColors.gold.withValues(alpha: _isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.access_time_rounded,
                    color: AppColors.gold, size: 14),
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
                      (emp['StartTime'] != null && emp['EndTime'] != null)
                          ? '${emp['StartTime']} - ${emp['EndTime']}'
                          : 'الوقت غير محدد',
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.text(_isDark),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: emp['ShiftType']?.toString() ?? 'شيفت',
                color: typeColor,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.divider(_isDark)),
          const SizedBox(height: 10),
          _buildDetailRow(
            Icons.play_circle_rounded,
            _isDark ? AppColors.successLight : AppColors.success,
            'بداية الشيفت',
            emp['EffectiveFrom']?.toString() ?? 'غير محدد',
          ),
          const SizedBox(height: 9),
          _buildDetailRow(
            Icons.stop_circle_rounded,
            _isDark ? AppColors.warningLight : AppColors.warning,
            'نهاية الشيفت',
            emp['EffectiveTo']?.toString() ?? 'حتى تاريخه',
            trailing: Icon(Icons.edit_calendar_rounded,
                color: AppColors.textSecondary(_isDark), size: 16),
          ),
          if (offDays != null) ...[
            const SizedBox(height: 9),
            _buildDetailRow(
              Icons.weekend_rounded,
              _isDark ? AppColors.infoLight : AppColors.info,
              'الراحة الأسبوعية',
              offDays,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, Color color, String label, String value,
      {Widget? trailing}) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: _isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.text(_isDark),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildAddShiftButton() {
    return Material(
      color: AppColors.gold.withValues(alpha: _isDark ? 0.14 : 0.08),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  color: _isDark ? AppColors.gold : AppColors.goldDark,
                  size: 16),
              const SizedBox(width: 8),
              Text(
                'إضافة شيفت جديد',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _isDark ? AppColors.gold : AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmpty(
      icon: Icons.search_off_rounded,
      message: 'لا توجد نتائج',
      hint: 'حاول تعديل كلمات البحث أو الفلاتر',
    );
  }

  /// حذف شيفت بضغطة مطوّلة — يُعرض رد الخادم كما هو (رسالة صادقة منه)
  Future<void> _confirmDeleteShift(Map<String, dynamic> emp) async {
    if (!PermissionService().canEdit(FormNames.employeeShifts)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية التعديل')),
      );
      return;
    }
    final shiftId = (emp['EmployeeShiftID'] as num?)?.toInt() ?? 0;
    if (shiftId <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(_isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف الشيفت',
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  color: AppColors.text(_isDark),
                  fontWeight: FontWeight.bold,
                )),
        content: Text(
            'سيتم حذف شيفت الموظف ${emp['FullName'] ?? ''} نهائيًا. متابعة؟',
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('تراجع',
                  style: TextStyle(color: AppColors.textSecondary(_isDark)))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/shifts/$shiftId'),
        headers: SessionService.instance.authHeaders,
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${data['message'] ?? 'تم حذف الشيفت'}'),
                backgroundColor: AppColors.success),
          );
          fetchData();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${data['message'] ?? 'فشل حذف الشيفت'}'),
                backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل الاتصال بالخادم: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
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
          currentShift: emp['EmployeeShiftID'] != null ? emp : null,
        ),
      ),
    );

    if (result == true) {
      fetchData(); // تحديث القائمة
    }
  }
}
