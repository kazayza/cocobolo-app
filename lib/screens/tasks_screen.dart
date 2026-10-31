import 'dart:async';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;

import '../constants.dart';
import 'add_interaction_screen.dart';
import 'opportunity_details_screen.dart';
import '../core/auth/session_service.dart';

import '../widgets/app_drawer.dart';
import '../widgets/design_kit.dart';
// ══════════════════════════════════════════════
//  📱 الشاشة الرئيسية
// ══════════════════════════════════════════════
class TasksScreen extends StatefulWidget {
  final int userId;
  final String username;

  const TasksScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> overdueTasks = [];
  List<dynamic> todayTasks = [];
  List<dynamic> tomorrowTasks = [];
  List<dynamic> upcomingTasks = [];
  List<dynamic> completedTasks = [];
  List<dynamic> employees = [];

  int? selectedEmployeeId;
  String? selectedEmployeeName;
  bool loading = true;
  bool hasError = false;
  String errorMessage = '';
  String searchQuery = '';

  final List<_TabConfig> _tabConfigs = [
    _TabConfig(
        'متأخرة', FontAwesomeIcons.triangleExclamation, AppStatus.overdue),
    _TabConfig('اليوم', FontAwesomeIcons.calendarDay, AppColors.warning),
    _TabConfig('غداً', FontAwesomeIcons.calendarPlus, AppColors.info),
    _TabConfig('قادمة', FontAwesomeIcons.calendarWeek, AppColors.infoLight),
    _TabConfig('مكتملة', FontAwesomeIcons.circleCheck, AppColors.success),
  ];

  /// أيقونات Material لحالات التبويبات الفارغة — AppEmpty يقبل IconData فقط
  static const List<IconData> _tabEmptyIcons = [
    Icons.warning_amber_rounded,
    Icons.today_rounded,
    Icons.event_rounded,
    Icons.calendar_month_rounded,
    Icons.check_circle_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════
  //  🔄 تحميل البيانات
  // ══════════════════════════════════════════

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => searchQuery = _searchController.text.toLowerCase());
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      hasError = false;
    });

    try {
      await Future.wait([
        _fetchEmployees(),
        _fetchTasks(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          hasError = true;
          errorMessage = 'حدث خطأ أثناء تحميل البيانات';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/api/opportunities/employees'),
            headers: SessionService.instance.authHeaders,
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() => employees = data is List ? data : []);
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching employees: $e');
    }
  }

  Future<void> _fetchTasks() async {
    try {
      String url = '$baseUrl/api/tasks';
      if (selectedEmployeeId != null) {
        url += '?opportunityEmployeeId=$selectedEmployeeId';
      }

      final res = await http
          .get(
            Uri.parse(url),
            headers: SessionService.instance.authHeaders,
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final List<dynamic> allTasks = jsonDecode(res.body);

        final overdue = <dynamic>[];
        final today = <dynamic>[];
        final tomorrow = <dynamic>[];
        final upcoming = <dynamic>[];
        final completed = <dynamic>[];

        for (final task in allTasks) {
          final status = task['TaskDueStatus'] ?? '';
          final taskStatus = task['Status'] ?? '';

          if (taskStatus == 'Completed') {
            completed.add(task);
          } else if (status == 'Overdue') {
            overdue.add(task);
          } else if (status == 'Today') {
            today.add(task);
          } else if (status == 'Tomorrow') {
            tomorrow.add(task);
          } else {
            upcoming.add(task);
          }
        }

        if (mounted) {
          setState(() {
            overdueTasks = overdue;
            todayTasks = today;
            tomorrowTasks = tomorrow;
            upcomingTasks = upcoming;
            completedTasks = completed;
          });
        }
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching tasks: $e');
      rethrow;
    }
  }

  List<dynamic> _filterTasks(List<dynamic> tasks) {
    if (searchQuery.isEmpty) return tasks;

    return tasks.where((task) {
      final name = (task['ClientName'] ?? '').toString().toLowerCase();
      final phone = (task['Phone'] ?? '').toString().toLowerCase();
      final desc = (task['TaskDescription'] ?? '').toString().toLowerCase();
      final owner = (task['OpportunityOwnerName'] ?? '').toString().toLowerCase();
      final assigned = (task['AssignedToName'] ?? '').toString().toLowerCase();

      return name.contains(searchQuery) ||
          phone.contains(searchQuery) ||
          desc.contains(searchQuery) ||
          owner.contains(searchQuery) ||
          assigned.contains(searchQuery);
    }).toList();
  }

  List<List<dynamic>> get _allFilteredLists => [
        _filterTasks(overdueTasks),
        _filterTasks(todayTasks),
        _filterTasks(tomorrowTasks),
        _filterTasks(upcomingTasks),
        _filterTasks(completedTasks),
      ];

  // ══════════════════════════════════════════
  //  📞 دوال الاتصال والواتساب
  // ══════════════════════════════════════════

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required FaIconData icon,
    required Color color,
  }) async {
    HapticFeedback.lightImpact();
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final dialogTheme = Theme.of(ctx);
            return AlertDialog(
              backgroundColor: dialogTheme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.all(AppRadius.xxl),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: AppRadius.all(AppRadius.xs),
                    ),
                    child: FaIcon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(title,
                      style: GoogleFonts.cairo(
                          color: dialogTheme.colorScheme.onSurface,
                          fontSize: 16)),
                ],
              ),
              content: Text(
                message,
                style: GoogleFonts.cairo(
                    color: dialogTheme.colorScheme.onSurfaceVariant,
                    fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('إلغاء',
                      style: GoogleFonts.cairo(
                          color: dialogTheme.colorScheme.onSurfaceVariant)),
                ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.all(AppRadius.xs),
                  ),
                ),
                child: Text('تأكيد',
                    style: GoogleFonts.cairo(color: Colors.white)),
              ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      _showSnackBar('لا يوجد رقم هاتف متاح', AppColors.error,
          FontAwesomeIcons.phoneSlash);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'اتصال',
      message: 'هل تريد الاتصال بـ $phone؟',
      icon: FontAwesomeIcons.phone,
      color: AppColors.success,
    );
    if (!confirmed) return;

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('فشل في فتح تطبيق الهاتف', AppColors.error,
          FontAwesomeIcons.circleExclamation);
    }
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      _showSnackBar('لا يوجد رقم هاتف متاح', AppColors.error,
          FontAwesomeIcons.phoneSlash);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'واتساب',
      message: 'هل تريد مراسلة $phone عبر واتساب؟',
      icon: FontAwesomeIcons.whatsapp,
      color: AppColors.whatsapp,
    );
    if (!confirmed) return;

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('00')) {
      cleanPhone = cleanPhone.substring(2);
    } else if (cleanPhone.startsWith('0')) {
      cleanPhone = '20${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 10 && !cleanPhone.startsWith('20')) {
      cleanPhone = '20$cleanPhone';
    }

    final businessUri = Uri.parse('whatsapp://send?phone=$cleanPhone');
    final normalUri = Uri.parse('https://wa.me/$cleanPhone');

    if (await canLaunchUrl(businessUri)) {
      await launchUrl(businessUri);
    } else if (await canLaunchUrl(normalUri)) {
      await launchUrl(normalUri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('فشل في فتح واتساب', AppColors.error,
          FontAwesomeIcons.circleExclamation);
    }
  }

  // ══════════════════════════════════════════
  //  🔧 دوال مساعدة
  // ══════════════════════════════════════════

  String _formatTime(dynamic time) {
    if (time == null) return '';
    try {
      if (time.toString().contains(':')) {
        final parts = time.toString().split(':');
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'م' : 'ص';
        final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$hour12:$minute $period';
      }
    } catch (_) {}
    return time.toString();
  }

  String _formatLastContact(dynamic lastContactDate) {
    if (lastContactDate == null) return 'لا يوجد تواصل سابق';
    try {
      final dt = DateTime.parse(lastContactDate.toString());
      final days = DateTime.now().difference(dt).inDays;

      String relative;
      if (days == 0) {
        relative = 'اليوم';
      } else if (days == 1) {
        relative = 'أمس';
      } else if (days == 2) {
        relative = 'من يومين';
      } else if (days <= 7) {
        relative = 'من $days أيام';
      } else if (days <= 30) {
        relative = 'من ${(days / 7).floor()} أسبوع';
      } else {
        relative = 'من ${(days / 30).floor()} شهر';
      }

      return '$relative • ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'غير محدد';
    }
  }

  void _showSnackBar(String message, Color color, FaIconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: color.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.all(AppRadius.sm)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openOpportunityDetails(dynamic task) async {
    if (task['OpportunityID'] == null) {
      _showSnackBar('لا توجد فرصة مرتبطة', AppColors.warning,
          FontAwesomeIcons.circleExclamation);
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/${task['OpportunityID']}'),
       headers: SessionService.instance.authHeaders,);

      if (res.statusCode == 200) {
        final opportunity = jsonDecode(res.body);
        if (mounted) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OpportunityDetailsScreen(
                opportunity: opportunity,
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          );
          if (result == true) _loadData();
        }
      }
    } catch (e) {
      _showSnackBar('خطأ في تحميل الفرصة', AppColors.error,
          FontAwesomeIcons.circleExclamation);
    }
  }

  void _openAddInteraction(dynamic task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInteractionScreen(
          userId: widget.userId,
          username: widget.username,
          preSelectedPartyId: task['PartyID'],
          preSelectedOpportunityId: task['OpportunityID'],
        ),
      ),
    );

    if (result == true) _loadData();
  }

   // ══════════════════════════════════════════
  //  🎨 بناء الواجهة الرئيسية
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frmCrmTasksLegacy'),
      backgroundColor: AppColors.background(isDark),
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
        child: const Icon(Icons.refresh_rounded),
      ).animate().scale(delay: 500.ms),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: const AppDrawerMenuButton(),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FaIcon(FontAwesomeIcons.listCheck,
                color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إدارة المهام',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                'متابعة مهام العملاء والفرص',
                style: GoogleFonts.cairo(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        _buildFilterButton(),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(108),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppGradients.identityHeader,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSearchBar(),
              _buildTabBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── زر الفلتر ───
  Widget _buildFilterButton() {
    final bool hasFilter = selectedEmployeeId != null;
    return GestureDetector(
      onTap: _showEmployeeFilter,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: hasFilter
              ? AppColors.gold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: AppRadius.all(AppRadius.xs),
          border: hasFilter
              ? Border.all(color: AppColors.gold.withValues(alpha: 0.5))
              : null,
        ),
        child: Stack(
          children: [
            FaIcon(
              FontAwesomeIcons.filter,
              color: hasFilter ? AppColors.gold : Colors.white,
              size: 16,
            ),
            if (hasFilter)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── شريط البحث ───
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page, vertical: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: AppRadius.all(AppRadius.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'بحث بالاسم، الهاتف، الوصف...',
            hintStyle:
                GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Colors.white70, size: 20),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  // ─── التابات ───
  Widget _buildTabBar() {
    final filtered = _allFilteredLists;
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      indicatorColor: AppColors.gold,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      labelPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      dividerColor: Colors.transparent,
      tabs: List.generate(5, (i) {
        return _buildTab(
          _tabConfigs[i].label,
          filtered[i].length,
          _tabConfigs[i].color,
          _tabConfigs[i].icon,
        );
      }),
    );
  }

  Widget _buildTab(String label, int count, Color color, FaIconData icon) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 11, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.cairo(fontSize: 12)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            StatusBadge(label: '$count', color: color, filled: true, small: true),
          ],
        ],
      ),
    );
  }

  // ─── الجسم ───
  Widget _buildBody() {
    if (loading) return const AppLoading();
    if (hasError) return _buildErrorView();

    final filtered = _allFilteredLists;

    return TabBarView(
      controller: _tabController,
      children: List.generate(5, (i) {
        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          onRefresh: _loadData,
          child: _buildTaskList(filtered[i], i),
        );
      }),
    );
  }

  Widget _buildErrorView() {
    return AppError(
      message: '$errorMessage\nتأكد من اتصالك بالإنترنت وحاول مرة أخرى',
      onRetry: _loadData,
      retryLabel: 'إعادة المحاولة',
    );
  }

  Widget _buildTaskList(List<dynamic> tasks, int tabIndex) {
    if (tasks.isEmpty) return _buildEmptyState(tabIndex);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, 80),
      itemCount: tasks.length,
      itemBuilder: (_, index) => _TaskCard(
        task: tasks[index],
        index: index,
        onCall: () => _makePhoneCall(tasks[index]['Phone']),
        onWhatsApp: () => _openWhatsApp(tasks[index]['Phone']),
        onInteraction: () => _openAddInteraction(tasks[index]),
        onDetails: () => _openOpportunityDetails(tasks[index]),
        formatTime: _formatTime,
        formatLastContact: _formatLastContact,
      ),
    );
  }

  Widget _buildEmptyState(int tabIndex) {
    final config = _tabConfigs[tabIndex];
    final messages = [
      'لا توجد مهام متأخرة ',
      'لا توجد مهام لليوم',
      'لا توجد مهام للغد',
      'لا توجد مهام قادمة',
      'لا توجد مهام مكتملة',
    ];

    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: AppEmpty(
            message: messages[tabIndex],
            hint: searchQuery.isNotEmpty ? 'جرب تغيير كلمة البحث' : null,
            icon: _tabEmptyIcons[tabIndex],
          ).animate().fadeIn(duration: 400.ms).scale(
                begin: const Offset(0.9, 0.9),
              ),
        ),
      ],
    );
  }

  // ─── فلتر الموظفين ───
  void _showEmployeeFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: sheetTheme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xxxl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetTheme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: AppRadius.all(AppRadius.xs),
                      ),
                      child: FaIcon(FontAwesomeIcons.filter,
                          color: AppColors.gold, size: 16),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'فلتر حسب صاحب الفرصة',
                      style: GoogleFonts.cairo(
                        color: sheetTheme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const Spacer(),
                  if (selectedEmployeeId != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selectedEmployeeId = null;
                          selectedEmployeeName = null;
                        });
                        Navigator.pop(ctx);
                        _fetchTasks();
                      },
                      child: Text('مسح',
                          style: GoogleFonts.cairo(
                              color: AppColors.error, fontSize: 13)),
                    ),
                ],
              ),
            ),
            Divider(
                color: sheetTheme.colorScheme.outlineVariant, height: 1),
            _buildEmployeeOption(
              name: 'كل الموظفين',
              icon: Icons.groups_rounded,
              isSelected: selectedEmployeeId == null,
              onTap: () {
                setState(() {
                  selectedEmployeeId = null;
                  selectedEmployeeName = null;
                });
                Navigator.pop(ctx);
                _fetchTasks();
              },
            ),
            Divider(
                color: sheetTheme.colorScheme.outlineVariant, height: 1),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                itemCount: employees.length,
                itemBuilder: (_, i) {
                  final emp = employees[i];
                  final isSelected =
                      selectedEmployeeId == emp['EmployeeID'];
                  return _buildEmployeeOption(
                    name: emp['FullName'] ?? '',
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        selectedEmployeeId = emp['EmployeeID'];
                        selectedEmployeeName = emp['FullName'];
                      });
                      Navigator.pop(ctx);
                      _fetchTasks();
                    },
                  );
                },
              ),
            ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmployeeOption({
    required String name,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        color: isSelected ? AppColors.gold.withValues(alpha: 0.08) : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.2)
                    : onSurface.withValues(alpha: 0.06),
                borderRadius: AppRadius.all(AppRadius.sm),
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon,
                        color: isSelected ? AppColors.gold : onSurface,
                        size: 20)
                    : Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.cairo(
                          color: isSelected ? AppColors.gold : onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.cairo(
                  color: isSelected ? AppColors.gold : onSurface,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              FaIcon(FontAwesomeIcons.circleCheck,
                  color: AppColors.gold, size: 16),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  🃏 كارد المهمة
// ══════════════════════════════════════════════
class _TaskCard extends StatelessWidget {
  final dynamic task;
  final int index;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onInteraction;
  final VoidCallback onDetails;
  final String Function(dynamic) formatTime;
  final String Function(dynamic) formatLastContact;

  const _TaskCard({
    required this.task,
    required this.index,
    required this.onCall,
    required this.onWhatsApp,
    required this.onInteraction,
    required this.onDetails,
    required this.formatTime,
    required this.formatLastContact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isHigh = task['Priority'] == 'High';
    final bool isCompleted = task['Status'] == 'Completed';
    final Color priorityColor =
        isHigh ? AppColors.error : AppColors.warning;
    final Color accentColor = isCompleted
        ? theme.colorScheme.onSurfaceVariant
        : priorityColor;

    return Dismissible(
      key: Key('task_${task['TaskID']}'),
      background: _SwipeBackground(
        color: AppColors.success,
        icon: FontAwesomeIcons.phone,
        label: 'اتصال',
        alignment: Alignment.centerRight,
      ),
      secondaryBackground: _SwipeBackground(
        color: AppColors.whatsapp,
        icon: FontAwesomeIcons.whatsapp,
        label: 'واتساب',
        alignment: Alignment.centerLeft,
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.startToEnd) {
          onCall();
        } else {
          onWhatsApp();
        }
        return false;
      },
      child: GestureDetector(
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            radius: AppRadius.xl,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // الشريط الجانبي
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // المحتوى
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, isCompleted, isHigh,
                            priorityColor),
                        const SizedBox(height: AppSpacing.md),
                        _buildClientInfo(context),
                        const SizedBox(height: AppSpacing.md),
                        _buildMetaInfo(context),
                        // ← أزرار الإجراءات بدون زر إنهاء
                        if (!isCompleted) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md),
                            child: Divider(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                              height: 1,
                            ),
                          ),
                          _buildActions(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 40 * index),
          duration: 400.ms,
        )
        .slideX(begin: 0.06);
  }

  Widget _buildHeader(BuildContext context, bool isCompleted, bool isHigh,
      Color priorityColor) {
    final theme = Theme.of(context);
    final Color headerColor = isCompleted
        ? theme.colorScheme.onSurfaceVariant
        : priorityColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: headerColor.withValues(alpha: 0.12),
            borderRadius: AppRadius.all(AppRadius.sm),
          ),
          child: FaIcon(
            isCompleted
                ? FontAwesomeIcons.circleCheck
                : (isHigh
                    ? FontAwesomeIcons.fire
                    : FontAwesomeIcons.clipboard),
            color: headerColor,
            size: 16,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task['TaskDescription'] ?? 'مهمة',
                style: GoogleFonts.cairo(
                  color: isCompleted
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusBadge(
                    label: task['TaskTypeNameAr'] ?? 'متابعة',
                    color: priorityColor,
                    small: true,
                  ),
                  if (isHigh)
                    StatusBadge(
                      label: 'عاجل',
                      color: AppColors.error,
                      icon: Icons.arrow_upward_rounded,
                      small: true,
                    ),
                ],
              ),
            ],
          ),
        ),
        _buildDateBadge(context),
      ],
    );
  }

  Widget _buildDateBadge(BuildContext context) {
    final theme = Theme.of(context);
    String dateText = '';
    String timeText = '';

    try {
      final dt = DateTime.parse(task['DueDate']);
      dateText = intl.DateFormat('dd/MM').format(dt);
    } catch (_) {
      dateText = '--/--';
    }

    timeText = formatTime(task['DueTime']);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.all(AppRadius.sm),
        border: Border.all(
            color:
                theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            dateText,
            style: GoogleFonts.cairo(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
          if (timeText.isNotEmpty)
            Text(
              timeText,
              style: GoogleFonts.cairo(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _buildClientInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        FaIcon(FontAwesomeIcons.userLarge,
            color: theme.colorScheme.onSurfaceVariant, size: 12),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            task['ClientName'] ?? 'بدون اسم',
            style: GoogleFonts.cairo(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (task['Phone'] != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            task['Phone'],
            style: GoogleFonts.cairo(
                color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaInfo(BuildContext context) {
    final theme = Theme.of(context);
    final oppOwner = task['OpportunityOwnerName'] ?? 'غير محدد';
    final assignedTo =
        task['AssignedToName']?.toString().split(' ').first ?? 'مجهول';
    final lastContact = formatLastContact(task['LastContactDate']);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 6,
      children: [
        StatusBadge(
          label: oppOwner,
          color: AppColors.gold,
          icon: Icons.workspace_premium_rounded,
          small: true,
        ),
        StatusBadge(
          label: assignedTo,
          color: AppColors.info,
          icon: Icons.how_to_reg_rounded,
          small: true,
        ),
        StatusBadge(
          label: lastContact,
          color: theme.colorScheme.onSurfaceVariant,
          icon: Icons.history_rounded,
          small: true,
        ),
      ],
    );
  }

  // ✅ 3 أزرار فقط بدون زر إنهاء
  Widget _buildActions() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppButton(
            label: 'اتصال',
            icon: Icons.call_rounded,
            color: AppColors.success,
            onTap: onCall,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _FaAppButton(
            label: 'واتساب',
            icon: FontAwesomeIcons.whatsapp,
            color: AppColors.whatsapp,
            onTap: onWhatsApp,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppButton(
            label: 'تسجيل تواصل',
            icon: Icons.forum_rounded,
            color: AppColors.gold,
            onTap: onInteraction,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════
//  🧩 Widgets مساعدة
// ══════════════════════════════════════════════

class _SwipeBackground extends StatelessWidget {
  final Color color;
  final FaIconData icon;
  final String label;
  final Alignment alignment;

  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.all(AppRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Text(label,
                style: GoogleFonts.cairo(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, color: color, size: 20),
          ),
          if (alignment == Alignment.centerRight) ...[
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.cairo(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

class _TabConfig {
  final String label;
  final FaIconData icon;
  final Color color;

  const _TabConfig(this.label, this.icon, this.color);
}

/// زر إجراء بأيقونة FontAwesome — مرآة AppButton شكليًا لأن أيقونات
/// FontAwesome (FaIconData) لا تدخل في خانة IconData الخاصة بالكيت.
class _FaAppButton extends StatelessWidget {
  final String label;
  final FaIconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FaAppButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: AppRadius.all(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.all(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.all(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
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
