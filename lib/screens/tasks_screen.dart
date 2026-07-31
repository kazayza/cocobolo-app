import 'dart:async';
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

// ══════════════════════════════════════════════
//  🎨 ثوابت التصميم
// ══════════════════════════════════════════════
class _AppColors {
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF141420);
  static const Color card = Color(0xFF1C1C2E);
  static const Color gold = Color(0xFFFFD700);
  static const Color red = Color(0xFFFF4757);
  static const Color orange = Color(0xFFFF9F43);
  static const Color green = Color(0xFF2ED573);
  static const Color blue = Color(0xFF54A0FF);
  static const Color whatsapp = Color(0xFF25D366);
  static const Color textSecondary = Color(0xFF8A8A9A);
  static const Color divider = Color(0xFF2A2A3E);
}

class _AppGradients {
  static const LinearGradient appBar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
  );
}

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
    _TabConfig('متأخرة', FontAwesomeIcons.triangleExclamation, _AppColors.red),
    _TabConfig('اليوم', FontAwesomeIcons.calendarDay, _AppColors.orange),
    _TabConfig('غداً', FontAwesomeIcons.calendarPlus, _AppColors.blue),
    _TabConfig('قادمة', FontAwesomeIcons.calendarWeek, _AppColors.green),
    _TabConfig('مكتملة', FontAwesomeIcons.circleCheck, _AppColors.textSecondary),
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
          .get(Uri.parse('$baseUrl/api/opportunities/employees'))
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
          .get(Uri.parse(url))
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
    required IconData icon,
    required Color color,
  }) async {
    HapticFeedback.lightImpact();
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FaIcon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style:
                        GoogleFonts.cairo(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Text(
              message,
              style: GoogleFonts.cairo(
                  color: _AppColors.textSecondary, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('إلغاء',
                    style:
                        GoogleFonts.cairo(color: _AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('تأكيد',
                    style: GoogleFonts.cairo(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      _showSnackBar('لا يوجد رقم هاتف متاح', _AppColors.red,
          FontAwesomeIcons.phoneSlash);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'اتصال',
      message: 'هل تريد الاتصال بـ $phone؟',
      icon: FontAwesomeIcons.phone,
      color: _AppColors.green,
    );
    if (!confirmed) return;

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('فشل في فتح تطبيق الهاتف', _AppColors.red,
          FontAwesomeIcons.circleExclamation);
    }
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      _showSnackBar('لا يوجد رقم هاتف متاح', _AppColors.red,
          FontAwesomeIcons.phoneSlash);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'واتساب',
      message: 'هل تريد مراسلة $phone عبر واتساب؟',
      icon: FontAwesomeIcons.whatsapp,
      color: _AppColors.whatsapp,
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
      _showSnackBar('فشل في فتح واتساب', _AppColors.red,
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

  void _showSnackBar(String message, Color color, IconData icon) {
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
        backgroundColor: color.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openOpportunityDetails(dynamic task) async {
    if (task['OpportunityID'] == null) {
      _showSnackBar('لا توجد فرصة مرتبطة', _AppColors.orange,
          FontAwesomeIcons.circleExclamation);
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/${task['OpportunityID']}'),
      );

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
      _showSnackBar('خطأ في تحميل الفرصة', _AppColors.red,
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
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        backgroundColor: _AppColors.gold,
        child: const Icon(Icons.refresh_rounded, color: Colors.black),
      ).animate().scale(delay: 500.ms),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const FaIcon(FontAwesomeIcons.listCheck,
                color: Colors.black, size: 14),
          ),
          const SizedBox(width: 10),
          Text(
            'إدارة المهام',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
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
          decoration: const BoxDecoration(gradient: _AppGradients.appBar),
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasFilter
              ? _AppColors.gold.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: hasFilter
              ? Border.all(color: _AppColors.gold.withOpacity(0.5))
              : null,
        ),
        child: Stack(
          children: [
            FaIcon(
              FontAwesomeIcons.filter,
              color: hasFilter ? _AppColors.gold : Colors.white,
              size: 16,
            ),
            if (hasFilter)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _AppColors.gold,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'بحث بالاسم، الهاتف، الوصف...',
            hintStyle: GoogleFonts.cairo(
                color: _AppColors.textSecondary, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded,
                color: _AppColors.textSecondary, size: 20),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: _AppColors.textSecondary, size: 18),
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
      indicatorColor: _AppColors.gold,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
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

  Widget _buildTab(String label, int count, Color color, IconData icon) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 11, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.cairo(fontSize: 12)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── الجسم ───
  Widget _buildBody() {
    if (loading) return _buildLoadingShimmer();
    if (hasError) return _buildErrorView();

    final filtered = _allFilteredLists;

    return TabBarView(
      controller: _tabController,
      children: List.generate(5, (i) {
        return RefreshIndicator(
          color: _AppColors.gold,
          backgroundColor: _AppColors.card,
          onRefresh: _loadData,
          child: _buildTaskList(filtered[i], i),
        );
      }),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 160,
        decoration: BoxDecoration(
          color: _AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            duration: 1200.ms,
            color: Colors.white.withOpacity(0.05),
          ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _AppColors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(FontAwesomeIcons.triangleExclamation,
                  color: _AppColors.red, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              errorMessage,
              style:
                  GoogleFonts.cairo(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تأكد من اتصالك بالإنترنت وحاول مرة أخرى',
              style: GoogleFonts.cairo(
                  color: _AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: Text('إعادة المحاولة',
                  style:
                      GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            ),
          ],
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }

  Widget _buildTaskList(List<dynamic> tasks, int tabIndex) {
    if (tasks.isEmpty) return _buildEmptyState(tabIndex);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
      'لا توجد مهام متأخرة 🎉',
      'لا توجد مهام لليوم',
      'لا توجد مهام للغد',
      'لا توجد مهام قادمة',
      'لا توجد مهام مكتملة',
    ];

    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(config.icon,
                      size: 40, color: config.color.withOpacity(0.5)),
                ),
                const SizedBox(height: 20),
                Text(
                  messages[tabIndex],
                  style: GoogleFonts.cairo(
                      color: _AppColors.textSecondary, fontSize: 16),
                ),
                if (searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'جرب تغيير كلمة البحث',
                    style: GoogleFonts.cairo(
                        color: _AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ).animate().fadeIn(duration: 400.ms).scale(
                  begin: const Offset(0.9, 0.9),
                ),
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
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: _AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _AppColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(FontAwesomeIcons.filter,
                        color: _AppColors.gold, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'فلتر حسب صاحب الفرصة',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
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
                              color: _AppColors.red, fontSize: 13)),
                    ),
                ],
              ),
            ),
            const Divider(color: _AppColors.divider, height: 1),
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
            const Divider(color: _AppColors.divider, height: 1),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
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
      ),
    );
  }

  Widget _buildEmployeeOption({
    required String name,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: isSelected ? _AppColors.gold.withOpacity(0.08) : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? _AppColors.gold.withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon,
                        color: isSelected
                            ? _AppColors.gold
                            : Colors.white,
                        size: 20)
                    : Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.cairo(
                          color: isSelected
                              ? _AppColors.gold
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.cairo(
                  color: isSelected ? _AppColors.gold : Colors.white,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              const FaIcon(FontAwesomeIcons.circleCheck,
                  color: _AppColors.gold, size: 16),
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
    final bool isHigh = task['Priority'] == 'High';
    final bool isCompleted = task['Status'] == 'Completed';
    final Color priorityColor =
        isHigh ? _AppColors.red : _AppColors.orange;
    final Color cardBorderColor =
        isCompleted ? _AppColors.textSecondary : priorityColor;

    return Dismissible(
      key: Key('task_${task['TaskID']}'),
      background: const _SwipeBackground(
        color: _AppColors.green,
        icon: FontAwesomeIcons.phone,
        label: 'اتصال',
        alignment: Alignment.centerRight,
      ),
      secondaryBackground: const _SwipeBackground(
        color: _AppColors.whatsapp,
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
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: cardBorderColor.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: cardBorderColor.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // الشريط الجانبي
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cardBorderColor,
                          cardBorderColor.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                  // المحتوى
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(
                              isCompleted, isHigh, priorityColor),
                          const SizedBox(height: 14),
                          _buildClientInfo(),
                          const SizedBox(height: 12),
                          _buildMetaInfo(),
                          // ← أزرار الإجراءات بدون زر إنهاء
                          if (!isCompleted) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              child: Divider(
                                color: Colors.white.withOpacity(0.06),
                                height: 1,
                              ),
                            ),
                            _buildActions(),
                          ],
                        ],
                      ),
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

  Widget _buildHeader(
      bool isCompleted, bool isHigh, Color priorityColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (isCompleted
                        ? _AppColors.textSecondary
                        : priorityColor)
                    .withOpacity(0.2),
                (isCompleted
                        ? _AppColors.textSecondary
                        : priorityColor)
                    .withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FaIcon(
            isCompleted
                ? FontAwesomeIcons.circleCheck
                : (isHigh
                    ? FontAwesomeIcons.fire
                    : FontAwesomeIcons.clipboard),
            color: isCompleted
                ? _AppColors.textSecondary
                : priorityColor,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task['TaskDescription'] ?? 'مهمة',
                style: GoogleFonts.cairo(
                  color: isCompleted
                      ? _AppColors.textSecondary
                      : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task['TaskTypeNameAr'] ?? 'متابعة',
                      style: GoogleFonts.cairo(
                          color: priorityColor, fontSize: 10),
                    ),
                  ),
                  if (isHigh) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _AppColors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(FontAwesomeIcons.arrowUp,
                              color: _AppColors.red, size: 8),
                          const SizedBox(width: 3),
                          Text('عاجل',
                              style: GoogleFonts.cairo(
                                  color: _AppColors.red,
                                  fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        _buildDateBadge(),
      ],
    );
  }

  Widget _buildDateBadge() {
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
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Text(
            dateText,
            style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
          if (timeText.isNotEmpty)
            Text(
              timeText,
              style: GoogleFonts.cairo(
                  color: _AppColors.textSecondary, fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _buildClientInfo() {
    return Row(
      children: [
        const FaIcon(FontAwesomeIcons.userLarge,
            color: _AppColors.textSecondary, size: 12),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            task['ClientName'] ?? 'بدون اسم',
            style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (task['Phone'] != null) ...[
          const SizedBox(width: 8),
          Text(
            task['Phone'],
            style: GoogleFonts.cairo(
                color: _AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaInfo() {
    final oppOwner = task['OpportunityOwnerName'] ?? 'غير محدد';
    final assignedTo =
        task['AssignedToName']?.toString().split(' ').first ?? 'مجهول';
    final lastContact = formatLastContact(task['LastContactDate']);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _MetaChip(
          icon: FontAwesomeIcons.crown,
          text: oppOwner,
          color: _AppColors.gold,
        ),
        _MetaChip(
          icon: FontAwesomeIcons.userCheck,
          text: assignedTo,
          color: _AppColors.blue,
        ),
        _MetaChip(
          icon: FontAwesomeIcons.clockRotateLeft,
          text: lastContact,
          color: _AppColors.textSecondary,
        ),
      ],
    );
  }

  // ✅ 3 أزرار فقط بدون زر إنهاء
  Widget _buildActions() {
    return Row(
      children: [
        _ActionBtn(
          label: 'اتصال',
          icon: FontAwesomeIcons.phone,
          color: _AppColors.green,
          onTap: onCall,
        ),
        const SizedBox(width: 8),
        _ActionBtn(
          label: 'واتساب',
          icon: FontAwesomeIcons.whatsapp,
          color: _AppColors.whatsapp,
          onTap: onWhatsApp,
        ),
        const SizedBox(width: 8),
        _ActionBtn(
          label: 'تسجيل تواصل',
          icon: FontAwesomeIcons.commentDots,
          color: _AppColors.gold,
          onTap: onInteraction,
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════
//  🧩 Widgets مساعدة
// ══════════════════════════════════════════════

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 10, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.cairo(color: color, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                FaIcon(icon, color: color, size: 13),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
              color: color.withOpacity(0.2),
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
  final IconData icon;
  final Color color;

  const _TabConfig(this.label, this.icon, this.color);
}