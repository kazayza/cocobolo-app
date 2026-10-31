import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../../widgets/design_kit.dart';
import '../../core/responsive.dart';
import '../../widgets/app_drawer.dart';

import 'models/home_dashboard_config.dart';
import 'models/home_quick_action.dart';
import 'providers/home_provider.dart';
import 'services/home_service.dart';
import 'widgets/activities_section.dart';
import 'widgets/alerts_section.dart';
import 'widgets/latest_invoices_section.dart';
import 'widgets/latest_quotations_section.dart';
import 'widgets/my_tasks_strip.dart';
import 'widgets/upcoming_deliveries_section.dart';
import 'widgets/finance_carousel.dart';
import 'widgets/home_stats_carousel.dart';
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

class _HomeViewState extends State<_HomeView>
    with RouteAware, WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    // عند اكتشاف الفاحص الدوري إشعارات جديدة نزامن شارة الرئيسية فورًا.
    NotificationService.onUnreadCountMayHaveChanged = _syncUnreadCount;
    // تحميل الصورة الشخصية المحفوظة (حتى لو main.dart قديم في مشروعك)
    ProfileAvatarService().load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    if (NotificationService.onUnreadCountMayHaveChanged == _syncUnreadCount) {
      NotificationService.onUnreadCountMayHaveChanged = null;
    }
    super.dispose();
  }

  /// مزامنة عدّاد غير المقروء من الخادم (مصدر الحقيقة الوحيد).
  void _syncUnreadCount() {
    if (!mounted) return;
    context.read<HomeProvider>().refreshUnreadCount();
  }

  /// عودة المستخدم للرئيسية بعد إغلاق شاشة فوقها — أهمها شاشة الإشعارات
  /// (تعليم كمقروء/قراءة الكل) وهدف أي إشعار مفتوح من تنبيه.
  @override
  void didPopNext() {
    _syncUnreadCount();
  }

  /// عودة التطبيق للمقدمة (قد تكون إشعارات قُرئت أو وصلت أثناء الخلفية).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncUnreadCount();
    }
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
                color: HomeAccent.teal,
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
                backgroundColor: HomeAccent.teal,
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
            backgroundColor: AppColors.error,
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

    final showCrm = config.hasCard('crm') ||
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

                        // ── شريط «مهامي» (مقابل بلازور — للحساب المرتبط بموظف) ──
                        const MyTasksStrip(),

                        // ── التسليمات القادمة — 10 أيام (مقابل بلازور) ──
                        const UpcomingDeliveriesSection(),

                        // ── كاروسيل الإحصائيات: CRM + حركة الخزينة
                        // في موضع واحد قابل للسحب (حسب الصلاحية) ──
                        StaggeredReveal(
                          index: 3,
                          child: HomeStatsCarousel(showCrm: showCrm),
                        ),

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

                        // ── آخر فواتير المبيعات + آخر عروض الأسعار (مقابل بلازور) ──
                        const LatestInvoicesSection(),

                        const LatestQuotationsSection(),

                        const SizedBox(height: 16),

                        _LastUpdated(provider: homeProvider),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            // زر عائم قابل للسحب لفتح القائمة الجانبية — في الرئيسية
            // فقط، وزر القائمة الأصلي في الترويسة باقٍ كما هو
            const _DraggableDrawerButton(onTap: _openMenuPlaceholder),
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
    backgroundColor: isDark ? AppColors.navy : Colors.white,
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
        border:
            Border.all(color: AppColors.warningLight.withValues(alpha: 0.5)),
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
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 42,
                  color: AppColors.error,
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
                  foregroundColor: AppColors.navy,
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

/// ─────────────────────────────────────────────────────────────
///  زر القائمة العائم القابل للسحب (الرئيسية فقط)
///  - أيقونة: شبكة نقاط ذهبية 2×2 مرسومة بتدرّج ذهبي على قرص كحلي.
///  - حركة: ظهور نابض (مقياس + شفافية) بعد استقرار الرئيسية بقليل،
///    ونبض خفيف جدًا لحلقة ذهبية حوله (يتوقف أثناء اللمس/السحب)،
///    وانضغاط عند الضغط، وارتفاع طفيف عند السحب، والتصاق بالحافة
///    بمنحنى نابض (تجاوز بسيط مقيّد بحدود الطبقة).
///  - نقرة: فتح القائمة الجانبية بنفس آلية زر الترويسة.
///  - سحب: نقل الزر، وبحدّ حركة (6px) ينفصل السحب عن النقرة.
///  - عند الإفلات: يلتصق بأقرب حافة أفقية (12px)، ويبقى موضعه
///    العمودي كما أُفلت (مقيّدًا بحدود المنطقة الآمنة).
///  - الموضع محفوظ ككسور نسبية في SharedPreferences حتى يصمد
///    أمام اختلاف مقاس الشاشة أو تدويرها.
/// ─────────────────────────────────────────────────────────────
class _DraggableDrawerButton extends StatefulWidget {
  const _DraggableDrawerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DraggableDrawerButton> createState() => _DraggableDrawerButtonState();
}

class _DraggableDrawerButtonState extends State<_DraggableDrawerButton>
    with TickerProviderStateMixin {
  static const double _size = 56;
  static const double _edgeMargin = 12;
  static const double _bottomMargin = 24;
  static const double _dragSlop = 6;
  static const String _prefsX = 'home_drawer_fab_x';
  static const String _prefsY = 'home_drawer_fab_y';

  /// كسرا الموضع المحفوظان (يسار الزر وعلاه كنسبة من أقصى إزاحة)
  double? _fx;
  double? _fy;
  bool _loaded = false;

  /// آخر مقاس معروف لطبقة الزر (يُحدّث من LayoutBuilder كل بناء)
  Size _area = Size.zero;

  /// موضع مباشر أثناء السحب أو انزلاق الالتصاق؛ null = من الكسور
  Offset? _live;
  Offset _downGlobal = Offset.zero;
  Offset _startPos = Offset.zero;
  bool _dragging = false;
  bool _pressed = false;

  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  /// ظهور نابض عند استقرار الرئيسية + نبض الحلقة الهادئ بعده
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        final anim = _snapAnimation;
        if (anim != null && mounted) {
          final maxX = _area.width - _size;
          final maxY = _area.height - _size;
          final v = anim.value;
          // تقييد التجاوز النابض داخل الطبقة: يضغط الزر في الحافة
          // ثم يرتدّ إلى هامشه دون أن يغادر الشاشة أبدًا
          setState(() {
            _live = Offset(
              maxX > 0 ? v.dx.clamp(0.0, maxX) : v.dx,
              maxY > 0 ? v.dy.clamp(0.0, maxY) : v.dy,
            );
          });
        }
      });
    _snapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _settleSnap();
    });
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _entranceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _resumePulse();
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _restore();
  }

  @override
  void dispose() {
    _snapController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// النبض يعمل فقط في السكون: يبدأ بعد اكتمال الظهور، ويتوقف مع
  /// أي لمس أو سحب، ويستأنف بعد الاستقرار
  void _resumePulse() {
    if (_entranceController.isCompleted &&
        !_dragging &&
        !_pressed &&
        !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fx = prefs.getDouble(_prefsX);
      _fy = prefs.getDouble(_prefsY);
      _loaded = true;
    });
    // الظهور النابض يتأخر قليلًا عن استقرار محتوى الرئيسية
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_entranceController.isCompleted) {
        _entranceController.forward();
      }
    });
  }

  Future<void> _persist(Offset pos, double maxX, double maxY) async {
    final fx = maxX > 0 ? (pos.dx / maxX).clamp(0.0, 1.0) : 0.0;
    final fy = maxY > 0 ? (pos.dy / maxY).clamp(0.0, 1.0) : 0.0;
    _fx = fx;
    _fy = fy;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsX, fx);
    await prefs.setDouble(_prefsY, fy);
  }

  /// الموضع الحالي (أعلى-يسار الزر) داخل طبقة بمقاس [area]
  Offset _positionFor(Size area) {
    if (_live != null) return _live!;
    final maxX = area.width - _size;
    final maxY = area.height - _size;
    if (maxX <= 0 || maxY <= 0) return Offset.zero;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // الافتراضي: ملتصق بحافة البداية (جهة فتح القائمة) وقريب من الأسفل
    final fx = _fx ?? (rtl ? (maxX - _edgeMargin) / maxX : _edgeMargin / maxX);
    final fy = _fy ?? (maxY - _bottomMargin) / maxY;
    return Offset(
      (fx * maxX).clamp(0.0, maxX),
      (fy * maxY).clamp(0.0, maxY),
    );
  }

  void _handleDown(PointerDownEvent event) {
    _snapController.stop();
    _snapAnimation = null;
    _pulseController.stop();
    _startPos = _positionFor(_area);
    _live = _startPos;
    _downGlobal = event.position;
    _dragging = false;
    setState(() => _pressed = true);
  }

  void _handleMove(PointerMoveEvent event) {
    final delta = event.position - _downGlobal;
    if (!_dragging && delta.distance <= _dragSlop) return;
    _dragging = true;
    final maxX = _area.width - _size;
    final maxY = _area.height - _size;
    if (maxX <= 0 || maxY <= 0) return;
    final next = _startPos + delta;
    setState(() {
      _live = Offset(
        next.dx.clamp(0.0, maxX),
        next.dy.clamp(0.0, maxY),
      );
    });
  }

  void _handleUp(PointerUpEvent event) {
    setState(() => _pressed = false);
    if (!_dragging) {
      _live = null;
      _resumePulse();
      widget.onTap();
      return;
    }
    _dragging = false;
    _snapToEdge();
  }

  void _handleCancel(PointerCancelEvent event) {
    setState(() => _pressed = false);
    if (_dragging) {
      _dragging = false;
      _snapToEdge();
    } else {
      _resumePulse();
    }
  }

  /// الالتصاق بأقرب حافة أفقية مع بقاء الموضع العمودي كما أُفلت
  void _snapToEdge() {
    final maxX = _area.width - _size;
    final maxY = _area.height - _size;
    if (maxX <= 0 || maxY <= 0) return;
    final pos = _live ?? _positionFor(_area);
    final targetX = (pos.dx + _size / 2) <= _area.width / 2
        ? _edgeMargin
        : maxX - _edgeMargin;
    final target = Offset(targetX, pos.dy.clamp(0.0, maxY));
    _snapAnimation = Tween<Offset>(begin: pos, end: target).animate(
      CurvedAnimation(
        parent: _snapController,
        curve: const Cubic(0.25, 1.3, 0.45, 1),
      ),
    );
    _snapController.forward(from: 0);
  }

  /// بعد اكتمال الالتصاق: طيّ الموضع في الكسور وحفظه واستئناف النبض
  void _settleSnap() {
    final anim = _snapAnimation;
    if (anim == null) return;
    final maxX = _area.width - _size;
    final maxY = _area.height - _size;
    final end = anim.value;
    _snapAnimation = null;
    _live = null;
    if (maxX > 0 && maxY > 0) {
      _persist(end, maxX, maxY);
    }
    if (mounted) setState(() {});
    _resumePulse();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _area = Size(constraints.maxWidth, constraints.maxHeight);
          // حتى تُقرأ التفضيلات لا يظهر الزر (وميض موضع خاطئ ممنوع)
          if (!_loaded) return const SizedBox.shrink();
          final pos = _positionFor(_area);
          final interactionScale = _dragging ? 1.08 : (_pressed ? 0.92 : 1.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: pos.dx,
                top: pos.dy,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _handleDown,
                  onPointerMove: _handleMove,
                  onPointerUp: _handleUp,
                  onPointerCancel: _handleCancel,
                  child: AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      final t = _entranceController.value;
                      final scale = Curves.easeOutBack.transform(t);
                      final opacity =
                          Curves.easeOut.transform(t.clamp(0.0, 1.0));
                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(scale: scale, child: child),
                      );
                    },
                    child: AnimatedScale(
                      scale: interactionScale,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: Semantics(
                        button: true,
                        label: 'فتح القائمة الجانبية',
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // هالة النبض الذهبية الهادئة حول القرص
                            AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (context, _) {
                                final v = _pulseAnim.value;
                                return Transform.scale(
                                  scale: 1 + 0.11 * v,
                                  child: Container(
                                    width: _size,
                                    height: _size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.45 * (1 - v)),
                                        width: 1.6,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            AnimatedContainer(
                              key: const ValueKey('home_drawer_fab'),
                              width: _size,
                              height: _size,
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: AppColors.navy,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.gold,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.navyDark.withValues(
                                      alpha: _dragging ? 0.5 : 0.35,
                                    ),
                                    blurRadius: _dragging ? 20 : 12,
                                    offset: Offset(0, _dragging ? 8 : 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: CustomPaint(
                                  size: const Size.square(23),
                                  painter: _GoldDotsPainter(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// شبكة نقاط ذهبية 2×2 بحواف مستديرة وبتدرّج ذهبي قطري — علامة
/// الزر العائم بدل رمز القائمة التقليدي
class _GoldDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = size.width * 0.38;
    final gap = size.width * 0.24;
    final radius = Radius.circular(dot * 0.34);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.goldLight, AppColors.gold],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    for (final dx in [0.0, dot + gap]) {
      for (final dy in [0.0, dot + gap]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(dx, dy, dot, dot),
            radius,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
