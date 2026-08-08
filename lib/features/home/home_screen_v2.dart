import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_navigator.dart';
import '../../providers/auth_provider.dart';
import '../../screens/add_client_screen.dart';
import '../../screens/leads_screen.dart';
import '../../screens/add_opportunity_screen.dart';
import '../../screens/add_expense_screen.dart';
import '../../screens/tasks_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../services/permission_service.dart';

import 'models/home_dashboard_config.dart';
import 'models/home_quick_action.dart';
import 'providers/home_provider.dart';
import 'services/home_service.dart';
import 'widgets/kpi_card.dart';

class HomeScreenV2 extends StatelessWidget {
  const HomeScreenV2({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // PermissionService عندك Singleton وليس Provider
    final permissions = PermissionService();

    return ChangeNotifierProvider<HomeProvider>(
      create: (_) {
        return HomeProvider(
          service: HomeService(
            permissions: permissions,
          ),
        );
      },
      child: const _HomeView(),
    );
  }
}

// ============================================================
// HOME VIEW
// ============================================================

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  HomeDashboardConfig? _config;
  bool _initialized = false;

  // ✅ Singleton access — بيسعدل من HomeScreenV2
  AuthProvider get _auth => AuthProvider();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    if (!mounted || _initialized) {
      return;
    }

    _initialized = true;

    // ========================================================
    // PermissionService
    // ========================================================
    //
    // مهم:
    // PermissionService عندك Singleton
    // لذلك لا نستخدم:
    // context.read<PermissionService>()
    //
    final permissions = PermissionService();

    setState(() {
      _config = HomeDashboardConfig.fromPermissions(
        permissions,
      );
    });

    // ========================================================
    // AuthProvider
    // ========================================================

    final auth = AuthProvider();

    final userId = auth.userId;
    final username = auth.username ?? '';

    if (userId == null) {
      debugPrint(
        '⚠️ HomeScreenV2: userId غير موجود',
      );
      return;
    }

    // ========================================================
    // HomeProvider
    // ========================================================

    final homeProvider = context.read<HomeProvider>();

    await homeProvider.load(
      userId: userId,
      username: username,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    final auth = AuthProvider();

    final userId = auth.userId;

    if (userId == null) {
      return;
    }

    final homeProvider = context.read<HomeProvider>();

    await homeProvider.refresh(
      userId: userId,
      username: auth.username ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final homeProvider = context.watch<HomeProvider>();

    // =========================================================
    // LOADING STATE (initial config null = still initializing)
    // =========================================================
    if (config == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text(
                'جاري تحميل لوحة التحكم...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // =========================================================
    // ERROR STATE
    // =========================================================
    if (homeProvider.hasError && !homeProvider.hasData) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'فشل تحميل البيانات',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  homeProvider.errorMessage ?? 'حدث خطأ غير معروف',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    final auth = AuthProvider();
                    if (auth.userId != null) {
                      homeProvider.retry(
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

        return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (homeProvider.isOffline)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off_rounded, color: Colors.orange.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'أنت متصل أوفلاين — البيانات قد تكون قديمة',
                                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              // ==================================================
              // HEADER
              // ==================================================

              SliverToBoxAdapter(
                child: _HomeHeader(
                  onNotificationPressed: () {
                    final auth = AuthProvider();
                    if (auth.userId != null) {
                      navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => NotificationsScreen(
                            userId: auth.userId!,
                            username: auth.username,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  32,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      // ==================================================
                      // KPI / EXECUTIVE SUMMARY
                      // ==================================================

                      _ExecutiveSummary(
                        config: config,
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // QUICK ACTIONS
                      // ==================================================

                      _QuickActions(
                        config: config,
                        onAction: _handleQuickAction,
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // CRM
                      // ==================================================

                      _CrmSection(
                        config: config,
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // ALERTS
                      // ==================================================

                      const _AlertsSection(),

                      const SizedBox(height: 24),

                      // ==================================================
                      // ERP MODULES
                      // ==================================================

                      _DashboardCards(
                        config: config,
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // TASKS
                      // ==================================================

                      const _TasksSection(),

                      const SizedBox(height: 24),

                      // ==================================================
                      // RECENT ACTIVITIES
                      // ==================================================

                      const _RecentActivities(),

                                            const SizedBox(height: 24),
                    ],
                  ),
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

  void _handleQuickAction(HomeQuickAction action) {
    final messenger = ScaffoldMessenger.of(
      navigatorKey.currentContext!,
    );

    switch (action.action) {
      case 'add_client':
        _navigateTo(AddClientScreen(username: _auth.username ?? 'Unknown'));
        break;

      case 'add_lead':
        _navigateTo(LeadsScreen(userId: _auth.userId!, username: _auth.username ?? 'Unknown'));
        break;

      case 'add_opportunity':
        _navigateTo(AddOpportunityScreen(userId: _auth.userId!, username: _auth.username ?? 'Unknown'));
        break;

      case 'add_expense':
        _navigateTo(AddExpenseScreen(username: _auth.username ?? 'Unknown'));
        break;

      case 'add_task':
        _navigateTo(TasksScreen(userId: _auth.userId!, username: _auth.username ?? 'Unknown'));
        break;

      default:
        debugPrint(
          '⚠️ Quick Action غير معروف: ${action.action}',
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text('الإجراء غير مدعوم بعد: ${action.action}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            backgroundColor: Colors.red.shade700,
          ),
        );
                break;
    }
  }

  /// ✅ Helper — يفتح أي شاشة عبر navigatorKey
  /// مهم لأن HomeScreenV2 StatelessWidget وما يقدرش يستخدم Navigator.push مباشرة.
  void _navigateTo(Widget screen) {
    final auth = AuthProvider();
    if (auth.userId == null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('جلسة المستخدم غير صالحة. الرجاء تسجيل الدخول مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _HomeHeader extends StatelessWidget {
  final VoidCallback onNotificationPressed;

  const _HomeHeader({
    required this.onNotificationPressed,
  });

  @override
  Widget build(BuildContext context) {
    // مهم جدًا:
    // تحديد النوع صراحةً بدل context.read() فقط.
    final auth = AuthProvider();

    final username = auth.username ?? 'المستخدم';

    final hour = DateTime.now().hour;

    final greeting = hour < 12
        ? 'صباح الخير'
        : 'مساء الخير';

    final today = DateTime.now();

    final dateText =
        '${today.day}/${today.month}/${today.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                ),

                const SizedBox(height: 4),

                Text(
                  username,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                ),

                const SizedBox(height: 3),

                Text(
                  dateText,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),
          ),

          // ======================================================
          // NOTIFICATIONS
          // ======================================================

          Consumer<HomeProvider>(
            builder: (
              context,
              provider,
              _,
            ) {
              final count = provider.unreadCount;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed:
                        onNotificationPressed,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                    ),
                  ),

                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 5,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .error,
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: Text(
                          count > 99
                              ? '99+'
                              : count.toString(),
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(width: 4),

          // ======================================================
          // USER AVATAR
          // ======================================================

          CircleAvatar(
            radius: 21,
            child: Text(
              username.isNotEmpty
                  ? username.characters.first
                      .toUpperCase()
                  : 'U',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EXECUTIVE SUMMARY / KPI
// ============================================================

class _ExecutiveSummary extends StatelessWidget {
  final HomeDashboardConfig config;

  const _ExecutiveSummary({
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [];

    final provider =
        context.watch<HomeProvider>();

    final summary = provider.summary;

    // --------------------------------------------------------
    // SALES
    // --------------------------------------------------------

    cards.add(
      KpiCard(
        title: 'المبيعات',
        value: _displayValue(
          summary['sales'],
        ),
        subtitle: 'إجمالي المبيعات',
        icon: Icons.point_of_sale_rounded,
      ),
    );

    // --------------------------------------------------------
    // PURCHASES
    // --------------------------------------------------------

    cards.add(
      KpiCard(
        title: 'المشتريات',
        value: _displayValue(
          summary['purchases'],
        ),
        subtitle: 'إجمالي المشتريات',
        icon: Icons.shopping_cart_rounded,
      ),
    );

    // --------------------------------------------------------
    // CLIENTS
    // --------------------------------------------------------

    if (config.hasCard('clients')) {
      cards.add(
        KpiCard(
          title: 'العملاء',
          value: _displayValue(
            summary['totalClients'],
          ),
          subtitle: 'إجمالي العملاء',
          icon: Icons.people_alt_rounded,
        ),
      );
    }

    // --------------------------------------------------------
    // LEADS
    // --------------------------------------------------------

    if (config.hasCard('leads')) {
      cards.add(
        KpiCard(
          title: 'Leads',
          value: _displayValue(
            summary['leads'],
          ),
          subtitle: 'العملاء المحتملون',
          icon: Icons.campaign_rounded,
        ),
      );
    }

    // --------------------------------------------------------
    // INVENTORY
    // --------------------------------------------------------

    if (config.hasCard('inventory')) {
      cards.add(
        KpiCard(
          title: 'المخزون',
          value: _displayValue(
            summary['inventory'],
          ),
          subtitle: 'إجمالي المخزون',
          icon: Icons.inventory_2_rounded,
        ),
      );
    }

    // --------------------------------------------------------
    // EXPENSES
    // --------------------------------------------------------

    if (config.hasCard('expenses')) {
      cards.add(
        KpiCard(
          title: 'المصروفات',
          value: _displayValue(
            summary['expenses'],
          ),
          subtitle: 'إجمالي المصروفات',
          icon:
              Icons.account_balance_wallet_rounded,
        ),
      );
    }

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'ملخص الأعمال',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
        ),

        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final width =
                constraints.maxWidth;

            int columns;

            if (width >= 1400) {
              columns = 5;
            } else if (width >= 1100) {
              columns = 4;
            } else if (width >= 700) {
              columns = 3;
            } else {
              columns = 2;
            }

            return GridView.builder(
              itemCount: cards.length,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.45,
              ),
              itemBuilder: (
                context,
                index,
              ) {
                return cards[index];
              },
            );
          },
        ),
      ],
    );
  }

  static String _displayValue(
    dynamic value,
  ) {
    if (value == null) {
      return '--';
    }

    if (value is num) {
      return value.toString();
    }

    final text = value.toString();

    return text.isEmpty ? '--' : text;
  }
}

// ============================================================
// QUICK ACTIONS
// ============================================================

class _QuickActions extends StatelessWidget {
  final HomeDashboardConfig config;

  final void Function(
    HomeQuickAction action,
  ) onAction;

  const _QuickActions({
    required this.config,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // PermissionService Singleton
    final permissions = PermissionService();

    final actions =
        HomeQuickAction.available(
      permissions,
    );

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'إجراءات سريعة',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection:
                Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (
              _,
              __,
            ) {
              return const SizedBox(
                width: 10,
              );
            },
            itemBuilder: (
              context,
              index,
            ) {
              final action =
                  actions[index];

              return SizedBox(
                width: 130,
                child: Card(
                  elevation: 0,
                  clipBehavior:
                      Clip.antiAlias,
                  child: InkWell(
                    onTap: () =>
                        onAction(action),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration:
                                BoxDecoration(
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                            ),
                            child: Icon(
                              action.icon,
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          Text(
                            action.title,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CRM
// ============================================================

class _CrmSection extends StatelessWidget {
  final HomeDashboardConfig config;

  const _CrmSection({
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    if (!config.hasCard('crm') &&
        !config.hasCard('leads')) {
      return const SizedBox.shrink();
    }

    final summary =
        context.watch<HomeProvider>().summary;

    final leads =
        _toInt(summary['leads']);

    final followUps =
        _toInt(summary['followUpsTotal']);

    final overdue =
        _toInt(summary['followUpsOverdue']);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'CRM',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 0,
          clipBehavior:
              Clip.antiAlias,
          child: InkWell(
            onTap: () {
              // TODO:
              // ربط شاشة CRM الرئيسية.
            },
            child: Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration:
                            BoxDecoration(
                          color: Theme.of(
                            context,
                          )
                              .colorScheme
                              .primaryContainer,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                        child: Icon(
                          Icons.hub_rounded,
                          color: Theme.of(
                            context,
                          )
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'إدارة علاقات العملاء',
                              style: Theme.of(
                                context,
                              )
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                            ),

                            const SizedBox(
                              height: 3,
                            ),

                            Text(
                              'متابعة العملاء المحتملين والفرص والمتابعات',
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style: Theme.of(
                                context,
                              )
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons
                            .arrow_forward_ios_rounded,
                        size: 16,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                            _CrmMetric(
                          title: 'Leads',
                          value: leads,
                        ),
                      ),

                      Expanded(
                        child:
                            _CrmMetric(
                          title: 'المتابعات',
                          value: followUps,
                        ),
                      ),

                      Expanded(
                        child:
                            _CrmMetric(
                          title: 'متأخرة',
                          value: overdue,
                          isAlert:
                              overdue > 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static int _toInt(
    dynamic value,
  ) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

// ============================================================
// CRM METRIC
// ============================================================

class _CrmMetric extends StatelessWidget {
  final String title;
  final int value;
  final bool isAlert;

  const _CrmMetric({
    required this.title,
    required this.value,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isAlert
        ? Theme.of(context)
            .colorScheme
            .error
        : Theme.of(context)
            .colorScheme
            .primary;

    return Column(
      children: [
        Text(
          value.toString(),
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight:
                    FontWeight.w900,
                color: color,
              ),
        ),

        const SizedBox(height: 4),

        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .bodySmall,
        ),
      ],
    );
  }
}

// ============================================================
// ALERTS
// ============================================================

class _AlertsSection extends StatelessWidget {
  const _AlertsSection();

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<HomeProvider>();

    final summary = provider.summary;

    final overdue =
        _toInt(summary['followUpsOverdue']);

    final lowStock =
        _toInt(summary['lowStock']);

    final pending =
        _toInt(summary['pendingApprovals']);

    if (overdue == 0 &&
        lowStock == 0 &&
        pending == 0) {
      return Card(
        elevation: 0,
        child: ListTile(
          leading: const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green,
          ),
          title: const Text(
            'لا توجد تنبيهات عاجلة',
          ),
          subtitle: const Text(
            'كل شيء يبدو جيدًا حاليًا',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'التنبيهات',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
        ),

        const SizedBox(height: 12),

        if (overdue > 0)
          _AlertTile(
            icon:
                Icons.event_busy_rounded,
            title: 'متابعات متأخرة',
            value: overdue,
          ),

        if (lowStock > 0)
          _AlertTile(
            icon:
                Icons.inventory_rounded,
            title: 'أصناف منخفضة المخزون',
            value: lowStock,
          ),

        if (pending > 0)
          _AlertTile(
            icon:
                Icons.pending_actions_rounded,
            title: 'طلبات تحتاج اعتماد',
            value: pending,
          ),
      ],
    );
  }

  static int _toInt(
    dynamic value,
  ) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

// ============================================================
// ALERT TILE
// ============================================================

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int value;

  const _AlertTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      child: ListTile(
        leading: Icon(
          icon,
          color:
              theme.colorScheme.error,
        ),
        title: Text(title),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration:
              BoxDecoration(
            color: theme
                .colorScheme
                .errorContainer,
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
              color: theme
                  .colorScheme
                  .onErrorContainer,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ERP MODULES
// ============================================================

class _DashboardCards extends StatelessWidget {
  final HomeDashboardConfig config;

  const _DashboardCards({
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    if (config.cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'الوحدات',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
        ),

        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final width =
                constraints.maxWidth;

            int columns;

            if (width >= 1400) {
              columns = 5;
            } else if (width >= 1000) {
              columns = 4;
            } else if (width >= 650) {
              columns = 3;
            } else {
              columns = 2;
            }

            return GridView.builder(
              itemCount:
                  config.cards.length,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio:
                    1.35,
              ),
              itemBuilder: (
                context,
                index,
              ) {
                final card =
                    config.cards[index];

                return _ModuleCard(
                  card: card,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ============================================================
// MODULE CARD
// ============================================================

class _ModuleCard extends StatelessWidget {
  final HomeDashboardCard card;

  const _ModuleCard({
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        onTap: () {
          // TODO:
          // ربط Route الوحدة.
        },
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: theme
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: Icon(
                  card.icon,
                  size: 25,
                  color: theme
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),

              const Spacer(),

              Text(
                card.title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                card.subtitle,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: theme
                    .textTheme
                    .bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TASKS
// ============================================================

class _TasksSection extends StatelessWidget {
  const _TasksSection();

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<HomeProvider>();

    final tasks =
        provider.urgentTasks;

    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'مهامي اليوم',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 0,
          child: Column(
            children: tasks
                .take(5)
                .map(
                  (
                    task,
                  ) {
                    return CheckboxListTile(
                      value:
                          task.isCompleted,
                      onChanged:
                          (_) {
                        // TODO:
                        // ربط إتمام المهمة
                        // بالـAPI.
                      },
                      title: Text(
                        task.title,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                      ),
                      subtitle:
                          task.priority !=
                                  null
                              ? Text(
                                  task.priority!,
                                )
                              : null,
                      controlAffinity:
                          ListTileControlAffinity
                              .leading,
                    );
                  },
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// RECENT ACTIVITIES
// ============================================================

class _RecentActivities
    extends StatelessWidget {
  const _RecentActivities();

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<HomeProvider>();

    final activities =
        provider.recentActivities;

    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'آخر العمليات',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 0,
          child: Column(
            children: activities
                .take(8)
                .map(
                  (
                    activity,
                  ) {
                    return ListTile(
                      leading:
                          const CircleAvatar(
                        child: Icon(
                          Icons
                              .receipt_long_rounded,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        activity.title,
                      ),
                      subtitle:
                          activity
                                      .description !=
                                  null
                              ? Text(
                                  activity
                                      .description!,
                                )
                              : null,
                      trailing:
                          activity.amount !=
                                  null
                              ? Text(
                                  activity
                                      .amount
                                      .toString(),
                                )
                              : null,
                    );
                  },
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}