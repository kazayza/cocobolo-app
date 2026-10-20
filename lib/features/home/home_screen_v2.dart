import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/navigation/app_navigator.dart';
import '../../providers/auth_provider.dart';
import '../../screens/add_client_screen.dart';
import '../../screens/add_expense_screen.dart';
import '../../screens/add_opportunity_screen.dart';
import '../../screens/complaints_screen.dart';
import '../../screens/delivery_tracking_screen.dart';
import '../../screens/followups_screen.dart';
import '../../screens/global_search_screen.dart';
import '../../screens/attendance_screen.dart';
import '../../screens/leads_screen.dart';
import '../../screens/add_lead_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/tasks_screen.dart';
import '../../services/notification_service.dart';
import '../../services/permission_service.dart';
import '../../services/update_service.dart';
import '../../services/user_service.dart';
import '../../services/profile_avatar_service.dart';
import '../../services/theme_service.dart';
import '../../services/app_colors.dart';
import '../../core/responsive.dart';
import '../../widgets/app_drawer.dart';

import 'models/home_dashboard_config.dart';
import 'models/home_quick_action.dart';
import 'providers/home_provider.dart';
import 'services/home_service.dart';
import 'widgets/activities_section.dart';
import 'widgets/alerts_section.dart';
import 'widgets/crm_summary_card.dart';
import 'widgets/finance_carousel.dart';
import 'widgets/home_accent.dart';
import 'widgets/home_hero_header.dart';
import 'widgets/home_skeleton.dart';
import 'widgets/modules_section.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/staggered_reveal.dart';
import 'widgets/summary_section.dart';
import 'widgets/tasks_section.dart';

/// ─────────────────────────────────────────────────────────────
///  COCOBOLO HOME V2 — "Premium 2026"
///  - هوية Navy × Gold للعلامة التجارية
///  - كل قسم يظهر حسب صلاحيات المستخدم
///  - متجاوبة: موبايل / تابلت / شاشات عريضة
///  - Skeleton loading + دخول متدرج للأقسام
/// ─────────────────────────────────────────────────────────────
class HomeScreenV2 extends StatelessWidget {
  const HomeScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    final permissions = PermissionService();

    return ChangeNotifierProvider<HomeProvider>(
      create: (_) =>
          HomeProvider(service: HomeService(permissions: permissions)),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

/// مفتاح الـ Scaffold — لفتح القائمة الجانبية من الترويسة
final GlobalKey<ScaffoldState> homeScaffoldKey = GlobalKey<ScaffoldState>();

class _HomeViewState extends State<_HomeView> {
  HomeDashboardConfig? _config;
  bool _initialized = false;
  bool _showAttendance = false;
  int? _employeeId;
  bool _reminderShown = false;

  /// فحص التحديثات: مرة واحدة لكل تشغيل للتطبيق
  static bool _updateChecked = false;

  AuthProvider get _auth => AuthProvider();

  @override
  void initState() {
    super.initState();
    // تحميل الصورة الشخصية المحفوظة (حتى لو main.dart قديم في مشروعك)
    ProfileAvatarService().load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    if (!mounted || _initialized) return;
    _initialized = true;

    // بناء الوحدات حسب صلاحيات المستخدم
    final permissions = PermissionService();
    setState(() {
      _config = HomeDashboardConfig.fromPermissions(permissions);
    });

    final auth = AuthProvider();
    final userId = auth.userId;
    final username = auth.username ?? '';

    if (userId == null) {
      debugPrint('⚠️ HomeScreenV2: userId غير موجود');
      return;
    }

    // ── فحص البصمة: اليوزر عنده موظف مربوط؟ ──────────
    // (employeeId مش بييجي مع اللوجن — بنجيبه من الـ API)
    try {
      final employeeId =
          auth.employeeId ?? await UserService.getEmployeeId(userId);
      final canAttendance =
          PermissionService().canView(FormNames.empAttendance);

      if (employeeId != null) {
        _employeeId = employeeId;
        if (canAttendance && mounted) {
          setState(() => _showAttendance = true);
        }
      }
    } catch (e) {
      debugPrint('⚠️ فشل فحص موظف المستخدم: $e');
    }

    await context.read<HomeProvider>().load(userId: userId, username: username);

    // ✅ بدء فحص الإشعارات الدوري (كل 30 ثانية)
    NotificationService().startPolling(username);

    // ✅ فحص التحديثات تلقائيًا (مرة واحدة لكل تشغيل)
    _checkForUpdatesOnce();

    // ✅ تذكير صباحي ذكي — لو موظف ولم يبصم بعد قبل 10 ص
    _maybeShowAttendanceReminder();
  }

  /// فحص التحديثات — يشتغل مرة واحدة بس لكل تشغيل تطبيق
  void _checkForUpdatesOnce() {
    if (_updateChecked || !mounted) return;
    _updateChecked = true;

    // نأجل الفحص شوية عشان الشاشة تظهر الأول والديالوج يجي فوقها
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      UpdateService.checkAndPrompt(context);
    });
  }

  /// تذكير لطيف لتسجيل الحضور (مرة واحدة لكل فتحة هوم)
  void _maybeShowAttendanceReminder() {
    if (!_showAttendance || !mounted) return;

    final now = DateTime.now();
    // قبل 10 صباحاً فقط
    if (now.hour >= 10) return;

    // منع التكرار: نتأكد إن مفيش ديالوج ظاهر
    if (_reminderShown) return;
    _reminderShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.fingerprint_rounded,
                color: Color(0xFF26A69A),
                size: 28,
              ),
              SizedBox(width: 10),
              Text('تسجيل الحضور'),
            ],
          ),
          content: const Text(
            'يبدو أنك لم تسجل حضورك اليوم بعد.\nهل تريد التسجيل الآن؟',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('لاحقاً'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF26A69A),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _openAttendance();
              },
              icon: const Icon(Icons.fingerprint_rounded, size: 18),
              label: const Text('تسجيل الآن'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final auth = AuthProvider();
    final userId = auth.userId;
    if (userId == null) return;

    await context.read<HomeProvider>().refresh(
      userId: userId,
      username: auth.username ?? '',
    );
  }

  /// فتح شاشة الحضور (للموظف المرتبط)
  void _openAttendance() {
    final auth = AuthProvider();
    if (auth.userId == null) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AttendanceScreen(
          userId: auth.userId!,
          username: auth.username ?? '',
        ),
      ),
    );
  }

  void _handleQuickAction(HomeQuickAction action) {
    switch (action.action) {
      case 'attendance':
        _openAttendance();
        break;

      case 'add_client':
        _navigateTo(AddClientScreen(username: _auth.username ?? 'Unknown'));
        break;

      case 'add_lead':
        // مباشرة لشاشة إضافة ليد يدوي (أسرع للمستخدم)
        _navigateTo(
          AddLeadScreen(
            userId: _auth.userId,
            username: _auth.username ?? 'Unknown',
          ),
        );
        break;

      case 'add_opportunity':
        _navigateTo(
          AddOpportunityScreen(
            userId: _auth.userId!,
            username: _auth.username ?? 'Unknown',
          ),
        );
        break;

      case 'add_expense':
        _navigateTo(AddExpenseScreen(username: _auth.username ?? 'Unknown'));
        break;

      case 'add_task':
        _navigateTo(
          TasksScreen(
            userId: _auth.userId!,
            username: _auth.username ?? 'Unknown',
          ),
        );
        break;

      case 'add_complaint':
        _navigateTo(
          ComplaintsScreen(
            userId: _auth.userId!,
            username: _auth.username ?? 'Unknown',
          ),
        );
        break;

      case 'delivery_tracking':
        _navigateTo(
          DeliveryTrackingScreen(
            userId: _auth.userId!,
            username: _auth.username ?? 'Unknown',
          ),
        );
        break;

      case 'follow_ups':
        _navigateTo(
          FollowUpsScreen(
            userId: _auth.userId!,
            username: _auth.username ?? 'Unknown',
          ),
        );
        break;

      default:
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('الإجراء غير مدعوم بعد: ${action.action}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
    }
  }

  void _navigateTo(Widget screen) {
    final auth = AuthProvider();
    if (auth.userId == null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text(
            'جلسة المستخدم غير صالحة. الرجاء تسجيل الدخول مرة أخرى.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final homeProvider = context.watch<HomeProvider>();

    // ── تحميل أولي: سكلتون متلألئ ─────────────────────────
    if (config == null || (homeProvider.isLoading && !homeProvider.hasData)) {
      return const Scaffold(body: SafeArea(child: HomeSkeleton()));
    }

    // ── خطأ أولي ──────────────────────────────────────────
    if (homeProvider.hasError && !homeProvider.hasData) {
      return _ErrorView(provider: homeProvider);
    }

    final showCrm =
        config.hasCard('crm') ||
        config.hasCard('leads') ||
        config.hasCard('opportunities') ||
        config.hasCard('pipeline');
    final showTasks = config.hasCard('tasks');

    final auth = AuthProvider();

    return Scaffold(
      key: homeScaffoldKey,
      drawer: AppDrawer(
        userId: auth.userId ?? 0,
        username: auth.username ?? '',
        fullName: auth.fullName,
        currentRoute: 'home',
      ),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (homeProvider.isOffline)
                    const SliverToBoxAdapter(child: _OfflineBanner()),

                  SliverToBoxAdapter(
                    child: HomeHeroHeader(
                      onNotificationPressed: _openNotificationsPlaceholder,
                      onMenuPressed: _openMenuPlaceholder,
                      onSettingsPressed: _openSettingsPlaceholder,
                      onSearchPressed: _openSearchPlaceholder,
                      onThemeToggle: _toggleThemePlaceholder,
                      onAccentPressed: _openAccentSheetPlaceholder,
                      onAvatarTap: _openSettingsPlaceholder,
                    ),
                  ),

                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.horizontalPadding(context),
                      16,
                      Responsive.horizontalPadding(context),
                      32,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── كاروسيل مالي متحرك (خزينة/مبيعات/مصروفات) ──
                        StaggeredReveal(
                          index: 0,
                          child: const FinanceCarousel(),
                        ),

                        const SizedBox(height: 24),

                        // ── مؤشرات الكميات (عملاء/ليدز/مخزون/مهام...) ──
                        StaggeredReveal(
                          index: 1,
                          child: SummarySection(config: config),
                        ),

                        const SizedBox(height: 24),

                        StaggeredReveal(
                          index: 2,
                          child: QuickActionsRow(
                            onAction: _handleQuickAction,
                            employeeId: _employeeId,
                          ),
                        ),

                        if (showCrm) ...[
                          const SizedBox(height: 24),
                          StaggeredReveal(
                            index: 3,
                            child: const CrmSummaryCard(),
                          ),
                        ],

                        const SizedBox(height: 24),

                        StaggeredReveal(
                          index: 4,
                          child: AlertsSection(config: config),
                        ),

                        const SizedBox(height: 24),

                        StaggeredReveal(
                          index: 5,
                          child: ModulesSection(config: config),
                        ),

                        if (showTasks) ...[
                          const SizedBox(height: 24),
                          StaggeredReveal(
                            index: 6,
                            child: const TasksSection(),
                          ),
                        ],

                        const SizedBox(height: 24),

                        StaggeredReveal(
                          index: 7,
                          child: const ActivitiesSection(),
                        ),

                        const SizedBox(height: 16),

                        _LastUpdated(provider: homeProvider),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ربط جرس الإشعارات ──────────────────────────────────────
// (دوال عامة حتى نستخدمها داخل const widget — الـ tear-off للدوال العامة ثابت)
void _openNotificationsPlaceholder() {
  final auth = AuthProvider();
  if (auth.userId == null) return;

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) =>
          NotificationsScreen(userId: auth.userId!, username: auth.username),
    ),
  );
}

// ── فتح القائمة الجانبية (Drawer) ──────────────────────────
void _openMenuPlaceholder() {
  homeScaffoldKey.currentState?.openDrawer();
}

// ── فتح الإعدادات (فيها تغيير كلمة المرور) ─────────────────
void _openSettingsPlaceholder() {
  final auth = AuthProvider();
  if (auth.userId == null) return;

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => SettingsScreen(
        userId: auth.userId!,
        username: auth.username ?? '',
        fullName: auth.fullName,
      ),
    ),
  );
}

// ── فتح البحث الشامل ────────────────────────────────────────
void _openSearchPlaceholder() {
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
  );
}

// ── تبديل الوضع الليلي / النهاري ───────────────────────────
void _toggleThemePlaceholder() {
  ThemeService().toggleTheme();
}

// ── فتح شيت اختيار اللون ────────────────────────────────────
void _openAccentSheetPlaceholder() {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  final themeService = ThemeService();
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لون التطبيق',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'اختر اللون الأساسي للأزرار والمفاتيح',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            // شبكة الألوان
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < ThemeService.accentOptions.length; i++) ...[
                  GestureDetector(
                    onTap: () {
                      themeService.setAccent(i);
                      Navigator.pop(sheetContext);
                    },
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: ThemeService.accentOptions[i].color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: themeService.accentIndex == i
                                  ? scheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ThemeService.accentOptions[i].color
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: themeService.accentIndex == i
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ThemeService.accentOptions[i].name,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: themeService.accentIndex == i
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningLight.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'أنت متصل أوفلاين — البيانات قد تكون قديمة',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastUpdated extends StatelessWidget {
  final HomeProvider provider;

  const _LastUpdated({required this.provider});

  @override
  Widget build(BuildContext context) {
    final t = provider.lastUpdated;
    if (t == null) return const SizedBox.shrink();

    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');

    return Center(
      child: Text(
        'آخر تحديث: $h:$m',
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final HomeProvider provider;

  const _ErrorView({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 42,
                  color: Color(0xFFE53935),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'فشل تحميل البيانات',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                provider.errorMessage ?? 'حدث خطأ غير معروف',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: HomeAccent.accent,
                  foregroundColor: const Color(0xFF13273F),
                ),
                onPressed: () {
                  final auth = AuthProvider();
                  if (auth.userId != null) {
                    provider.retry(
                      userId: auth.userId!,
                      username: auth.username ?? '',
                    );
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
