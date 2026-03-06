import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'notifications_screen.dart';
import 'products_screen.dart';
import 'clients_screen.dart';
import 'add_client_screen.dart';
import 'add_expense_screen.dart';
import 'expenses_screen.dart';
import 'opportunities_screen.dart';
import 'add_opportunity_screen.dart';
import 'tasks_screen.dart';
import 'reports/crm_dashboard_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'pipeline_screen.dart';
import 'price_requests_screen.dart';
import 'attendance_screen.dart';
import 'employees_screen.dart';
import '../widgets/app_drawer.dart';
import 'attendance_report_screen.dart';      // أو المسار الصحيح
import 'permissions_list_screen.dart';       // أو المسار الصحيح
import 'delivery_tracking_screen.dart';
import 'my_schedule_screen.dart';
import 'complaints_screen.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String? fullName;

  const HomeScreen({
    Key? key,
    required this.userId,
    required this.username,
    this.fullName,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════
  // VARIABLES
  // ═══════════════════════════════════════════════════════════════
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final NotificationService _notificationService = NotificationService();
  final PermissionService _perms = PermissionService();
  
  // Animation
  late AnimationController _animController;
  
  // Data
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> urgentTasks = [];
  List<Map<String, dynamic>> recentActivities = [];
  int unreadCount = 0;
  
  // States
  bool isLoading = true;
  bool isConnected = true;
  bool isOfflineMode = false;
  bool hasError = false;
  int _selectedNavIndex = 0;
  DateTime lastUpdate = DateTime.now();
  
  // Search
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];

  // Theme
  late String _greeting;
  late IconData _greetingIcon;
  late Color _primaryColor;
  late Color _secondaryColor;
  late List<Color> _gradientColors;

  // Customization
  List<String> cardOrder = [];
  Set<String> hiddenCards = {};
  Set<String> pinnedCards = {};
  
  // Cache
  Map<String, dynamic>? _cachedData;

  // Tips
  final List<String> _tips = [
    '💡 اضغط طويلاً على أي قسم لتثبيته في الأعلى',
    '🔍 استخدم البحث للوصول السريع للأقسام',
    '📊 تابع مهامك اليومية من بطاقة المهام',
    '⚡ استخدم الإجراءات السريعة لتوفير الوقت',
    '🎨 خصص الأقسام حسب احتياجاتك من زر تخصيص',
  ];
  int _currentTipIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
      // فحص التسليمات القريبة
   NotificationService().checkDeliveryNotifications();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _setupTheme();
    _loadCachedData();
    _loadCustomization();
    _loadData();
    _startNotificationService();
    _startTipRotation();
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) UpdateService.checkAndPrompt(context);
    });
  }

  void _setupTheme() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'صباح الخير';
      _greetingIcon = Icons.wb_sunny_rounded;
      _primaryColor = const Color(0xFFFFB347);
      _secondaryColor = const Color(0xFFFF8C42);
      _gradientColors = [const Color(0xFF1A1510), const Color(0xFF0A0A0A)];
    } else if (hour < 17) {
      _greeting = 'مساء الخير';
      _greetingIcon = Icons.wb_twilight_rounded;
      _primaryColor = const Color(0xFFE8B923);
      _secondaryColor = const Color(0xFFD4A017);
      _gradientColors = [const Color(0xFF1A1508), const Color(0xFF0A0A0A)];
    } else {
      _greeting = 'مساء النور';
      _greetingIcon = Icons.nightlight_round;
      _primaryColor = const Color(0xFF7B68EE);
      _secondaryColor = const Color(0xFF6A5ACD);
      _gradientColors = [const Color(0xFF151520), const Color(0xFF0A0A0A)];
    }
  }

  void _startTipRotation() {
    Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // CACHE & OFFLINE
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('dashboard_cache_${widget.userId}');
    if (cached != null) {
      _cachedData = jsonDecode(cached);
    }
  }

  Future<void> _saveCache(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_cache_${widget.userId}', jsonEncode(data));
    _cachedData = data;
  }

  // ═══════════════════════════════════════════════════════════════
  // CUSTOMIZATION
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadCustomization() async {
    final prefs = await SharedPreferences.getInstance();
    
    final savedOrder = prefs.getStringList('card_order_${widget.userId}');
    final savedHidden = prefs.getStringList('hidden_cards_${widget.userId}');
    final savedPinned = prefs.getStringList('pinned_cards_${widget.userId}');
    
    setState(() {
      cardOrder = savedOrder ?? _getDefaultOrder();
      hiddenCards = savedHidden?.toSet() ?? {};
      pinnedCards = savedPinned?.toSet() ?? {};
    });
  }

  Future<void> _saveCustomization() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('card_order_${widget.userId}', cardOrder);
    await prefs.setStringList('hidden_cards_${widget.userId}', hiddenCards.toList());
    await prefs.setStringList('pinned_cards_${widget.userId}', pinnedCards.toList());
  }

  List<String> _getDefaultOrder() {
    final order = <String>[];
    if (_perms.canView(FormNames.partiesList)) order.add('clients');
    if (_perms.canView(FormNames.managerSales)) order.add('opportunities');
    if (_perms.canView(FormNames.dailyTasks)) order.add('tasks');
    if (_perms.canView(FormNames.productsList)) order.add('products');
    if (_perms.canView(FormNames.expensesList)) order.add('expenses');
    if (_perms.canView(FormNames.crmDashboard)) order.add('crm');
    if (_perms.canView(FormNames.salesPipeline)) order.add('pipeline');
    if (_perms.canView(FormNames.priceRequests)) order.add('price_requests');
    if (_perms.canView(FormNames.employeesList)) order.add('employees');
    if (_perms.canView(FormNames.invoiceDeliveryStatus)) order.add('delivery');
    if (_perms.canView(FormNames.complaintsMain)) order.add('complaints');
    if (_perms.canView(FormNames.myschedule)) order.add('my_schedule');
      order.add('attendance_report');   // تقرير الحضور
  order.add('my_permissions'); 
    return order;
  }

  List<String> _getVisibleCards() {
    final pinned = cardOrder.where((c) => pinnedCards.contains(c) && !hiddenCards.contains(c)).toList();
    final others = cardOrder.where((c) => !pinnedCards.contains(c) && !hiddenCards.contains(c)).toList();
    return [...pinned, ...others];
  }

  // ═══════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });
    
    try {
      final res = await http.get(Uri.parse(
        '$baseUrl/api/dashboard?userId=${widget.userId}'
        '&username=${widget.username}'
        '&role=${_perms.role ?? 'User'}'
        '&employeeId=${_perms.employeeId ?? 0}',
      )).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _saveCache(data);
        
        setState(() {
          summary = data['summary'] ?? {};
          unreadCount = data['unreadCount'] ?? 0;
          recentActivities = List<Map<String, dynamic>>.from(data['recentActivities'] ?? []);
          isConnected = true;
          isOfflineMode = false;
          lastUpdate = DateTime.now();
        });
        
        await _loadUrgentTasks();
        await _fetchClientCount(); // make sure clients number is set
        _animController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      
      // استخدام البيانات المحفوظة
      if (_cachedData != null) {
        setState(() {
          summary = _cachedData!['summary'] ?? {};
          recentActivities = List<Map<String, dynamic>>.from(_cachedData!['recentActivities'] ?? []);
          isOfflineMode = true;
          isConnected = false;
        });
        // حاول تحديث عدد العملاء إذا عاد الاتصال لاحقاً
        _fetchClientCount();
      } else {
        setState(() {
          hasError = true;
          isConnected = false;
        });
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadUrgentTasks() async {
    if (!_perms.canView(FormNames.dailyTasks)) return;
    
    try {
      final res = await http.get(Uri.parse(
        '$baseUrl/api/tasks/today?assignedTo=${_perms.employeeId ?? 0}'
      ));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          if (data is Map && data['tasks'] != null) {
            urgentTasks = List<Map<String, dynamic>>.from(data['tasks']);
          } else if (data is List) {
            urgentTasks = List<Map<String, dynamic>>.from(data);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
  }

  // fetch total clients separately if dashboard summary didn't include it
  Future<void> _fetchClientCount() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/clients/summary'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          summary['totalClients'] = data['totalClients'] ?? summary['totalClients'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching client count: $e');
    }
  }

  void _startNotificationService() {
    _notificationService.startPolling(widget.username);
    _notificationService.onNotificationTap = (payload) {
      if (payload != null && mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => NotificationsScreen(
            userId: widget.userId,
            username: widget.username,
          ),
        ));
      }
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // تغيير لون الـ Status Bar
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (isSearching) {
          setState(() {
            isSearching = false;
            _searchController.clear();
            searchResults = [];
          });
        } else {
          _showExitDialog();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF0A0A0A),
        drawer: AppDrawer(
          userId: widget.userId,
          username: widget.username,
          fullName: widget.fullName,
          currentRoute: 'home',
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _gradientColors,
            ),
          ),
          child: SafeArea(
            child: isLoading 
                ? _buildSkeleton()
                : hasError
                    ? _buildErrorState()
                    : _buildBody(),
          ),
        ),
        floatingActionButton: !isLoading && !hasError ? _buildFAB() : null,
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EXIT DIALOG
  // ═══════════════════════════════════════════════════════════════

  void _showExitDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: _primaryColor),
            const SizedBox(width: 10),
            Text('الخروج', style: GoogleFonts.cairo(color: Colors.white)),
          ],
        ),
        content: Text(
          'هل تريد الخروج من التطبيق؟',
          style: GoogleFonts.cairo(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.black,
            ),
            child: Text('خروج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FAB - Floating Action Button
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _showQuickAddSheet,
      backgroundColor: _primaryColor,
      child: const Icon(Icons.add, color: Colors.black),
    );
  }

  void _showQuickAddSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'إضافة سريعة',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_perms.canAdd(FormNames.partiesAdd))
                  _buildFabAction('عميل', Icons.person_add, Colors.green, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AddClientScreen(username: widget.username),
                    )).then((_) => _loadData());
                  }),
                if (_perms.canAdd(FormNames.newInteraction) || _perms.canView(FormNames.newInteraction))
                  _buildFabAction('فرصة', Icons.lightbulb, Colors.orange, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AddOpportunityScreen(
                        userId: widget.userId,
                        username: widget.username,
                      ),
                    )).then((_) => _loadData());
                  }),
                if (_perms.canAdd(FormNames.expensesAdd))
                  _buildFabAction('مصروف', Icons.receipt_long, Colors.pink, () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(username: widget.username),
                    )).then((_) => _loadData());
                  }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFabAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SKELETON LOADING
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header skeleton
          Row(
            children: [
              _skeletonBox(44, 44, 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skeletonBox(100, 14, 6),
                    const SizedBox(height: 6),
                    _skeletonBox(150, 18, 6),
                  ],
                ),
              ),
              _skeletonBox(44, 44, 12),
            ],
          ),
          const SizedBox(height: 24),
          
          // Summary skeleton
          _skeletonBox(double.infinity, 140, 20),
          const SizedBox(height: 20),
          
          // Quick actions skeleton
          Row(
            children: List.generate(4, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                child: _skeletonBox(double.infinity, 80, 12),
              ),
            )),
          ),
          const SizedBox(height: 24),
          
          // Grid skeleton
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: List.generate(6, (i) => _skeletonBox(double.infinity, double.infinity, 16)),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox(double width, double height, double radius) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.6),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(value * 0.1),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ERROR STATE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 60, color: Colors.red[300]),
            ),
            const SizedBox(height: 24),
            Text(
              'تعذر الاتصال',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تأكد من اتصالك بالإنترنت وحاول مرة أخرى',
              style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: Text('إعادة المحاولة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MAIN BODY
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: _primaryColor,
      backgroundColor: const Color(0xFF1A1A1A),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            
            // Offline Banner
            if (isOfflineMode) ...[
              const SizedBox(height: 12),
              _buildOfflineBanner(),
            ],
            
            const SizedBox(height: 20),
            
            if (isSearching) ...[
              _buildSearchField(),
              const SizedBox(height: 16),
              if (searchResults.isNotEmpty) _buildSearchResults(),
            ] else ...[
              // Welcome & Summary
              _buildWelcomeCard(),
              const SizedBox(height: 16),
              
              // Progress Card
              if (urgentTasks.isNotEmpty) ...[
                _buildProgressCard(),
                const SizedBox(height: 16),
              ],
              
              // Quick Actions
              _buildQuickActions(),
              const SizedBox(height: 24),
              
              // Tips
              _buildTipsCard(),
              const SizedBox(height: 24),
              
              // Sections Grid
              _buildSectionsGrid(),
              
              // Urgent Tasks
              if (urgentTasks.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildUrgentTasks(),
              ],
              
              // Recent Activities
              if (recentActivities.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildRecentActivities(),
              ],
              
              const SizedBox(height: 80),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Row(
      children: [
        _buildIconBtn(Icons.menu_rounded, () {
          HapticFeedback.lightImpact();
          _scaffoldKey.currentState?.openDrawer();
        }),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_greetingIcon, color: _primaryColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _greeting,
                    style: GoogleFonts.cairo(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                widget.fullName ?? widget.username,
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _buildConnectionBadge(),
        const SizedBox(width: 8),
        _buildIconBtn(
          isSearching ? Icons.close_rounded : Icons.search_rounded,
          () {
            HapticFeedback.lightImpact();
            setState(() {
              isSearching = !isSearching;
              if (!isSearching) {
                _searchController.clear();
                searchResults = [];
              }
            });
          },
        ),
        const SizedBox(width: 8),
        _buildNotificationBtn(),
      ],
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildConnectionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isConnected ? Colors.green : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? 'متصل' : 'غير متصل',
            style: GoogleFonts.cairo(
              color: isConnected ? Colors.green : Colors.orange,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBtn() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => NotificationsScreen(
            userId: widget.userId,
            username: widget.username,
          ),
        )).then((_) => _loadData());
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_outlined, color: Colors.grey[400], size: 20),
            if (unreadCount > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0A0A0A), width: 2),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // OFFLINE BANNER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.offline_bolt, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'وضع عدم الاتصال - آخر تحديث ${_formatTimeAgo(lastUpdate)}',
              style: GoogleFonts.cairo(color: Colors.orange, fontSize: 11),
            ),
          ),
          GestureDetector(
            onTap: _loadData,
            child: const Icon(Icons.refresh, color: Colors.orange, size: 20),
          ),
        ],
      ),
    );
  }


  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  // ═══════════════════════════════════════════════════════════════
  // WELCOME CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor.withOpacity(0.2), _secondaryColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: _primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(_getFormattedDate(), style: GoogleFonts.cairo(color: _primaryColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStat('المهام', '${summary['tasksToday'] ?? 0}', Icons.task_alt, Colors.purple),
              _buildStatDivider(),
              _buildStat('الفرص', '${summary['openOpportunities'] ?? 0}', Icons.lightbulb, Colors.orange),
              _buildStatDivider(),
              _buildStat('العملاء', '${summary['totalClients'] ?? 0}', Icons.people, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(label, style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 60,
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PROGRESS CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildProgressCard() {
    final completed = urgentTasks.where((t) => 
      t['Status']?.toString().toLowerCase() == 'completed').length;
    final total = urgentTasks.length;
    final progress = total > 0 ? completed / total : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📈 إنجاز المهام اليوم',
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.cairo(color: _primaryColor, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed من $total مهام مكتملة',
            style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TIPS CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTipsCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey(_currentTipIndex),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.tips_and_updates, color: Colors.blue[300], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _tips[_currentTipIndex],
                style: GoogleFonts.cairo(color: Colors.blue[200], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SEARCH
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: GoogleFonts.cairo(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن قسم...',
                hintStyle: GoogleFonts.cairo(color: Colors.grey[600]),
                border: InputBorder.none,
              ),
              onChanged: _doSearch,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => searchResults = []);
              },
              child: Icon(Icons.close, color: Colors.grey[500], size: 20),
            ),
        ],
      ),
    );
  }

  void _doSearch(String query) {
    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    final results = <Map<String, dynamic>>[];
    final q = query.toLowerCase();
    
    final sections = _getAllSectionsData();
    for (var section in sections) {
      if (section['title'].toString().toLowerCase().contains(q) ||
          (section['keywords'] as List).any((k) => k.toString().contains(q))) {
        results.add(section);
      }
    }
    
    setState(() => searchResults = results);
  }

  List<Map<String, dynamic>> _getAllSectionsData() {
    return [
      {'title': 'العملاء', 'icon': Icons.people, 'color': Colors.teal, 'route': 'clients', 'keywords': ['عميل', 'client']},
      {'title': 'الفرص', 'icon': Icons.lightbulb, 'color': Colors.amber, 'route': 'opportunities', 'keywords': ['فرصة', 'opportunity']},
      {'title': 'المهام', 'icon': Icons.task_alt, 'color': Colors.purpleAccent, 'route': 'tasks', 'keywords': ['مهمة', 'task']},
      {'title': 'المنتجات', 'icon': Icons.inventory_2, 'color': Colors.blueAccent, 'route': 'products', 'keywords': ['منتج', 'product']},
      {'title': 'المصروفات', 'icon': Icons.wallet, 'color': Colors.pinkAccent, 'route': 'expenses', 'keywords': ['مصروف', 'expense']},
      {'title': 'لوحة CRM', 'icon': Icons.dashboard, 'color': Colors.cyanAccent, 'route': 'crm', 'keywords': ['crm', 'تحليل']},
      {'title': 'مراحل البيع', 'icon': Icons.trending_up, 'color': Colors.deepPurpleAccent, 'route': 'pipeline', 'keywords': ['بيع', 'pipeline']},
      {'title': 'الموظفين', 'icon': Icons.badge, 'color': Colors.brown.shade400, 'route': 'employees', 'keywords': ['موظف', 'employee']},
      {'title': 'طلبات الأسعار', 'icon': Icons.price_change, 'color': Colors.deepOrangeAccent, 'route': 'price_requests', 'keywords': ['سعر', 'price']},
      {'title': 'الحضور', 'icon': Icons.fingerprint, 'color': Colors.teal.shade300, 'route': 'attendance', 'keywords': ['حضور', 'attendance']},
      {'title': 'التقارير', 'icon': Icons.analytics, 'color': Colors.indigoAccent, 'route': 'reports', 'keywords': ['تقرير', 'report']},
      {'title': 'الإعدادات', 'icon': Icons.settings, 'color': Colors.grey, 'route': 'settings', 'keywords': ['إعداد', 'setting']},
    ];
  }

  Widget _buildSearchResults() {
    return Column(
      children: searchResults.map((result) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              isSearching = false;
              _searchController.clear();
              searchResults = [];
            });
            _navigateTo(result['route']);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (result['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: (result['color'] as Color).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (result['color'] as Color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(result['icon'], color: result['color'], size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    result['title'],
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: result['color'], size: 16),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    final actions = <Widget>[];
    
    if (_perms.canAdd(FormNames.partiesAdd)) {
      actions.add(_buildQuickAction('عميل', Icons.person_add, Colors.green, () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AddClientScreen(username: widget.username),
        )).then((_) => _loadData());
      }));
    }
    
    if (_perms.canAdd(FormNames.newInteraction) || _perms.canView(FormNames.newInteraction)) {
      actions.add(_buildQuickAction('فرصة', Icons.lightbulb_outline, Colors.orange, () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AddOpportunityScreen(userId: widget.userId, username: widget.username),
        )).then((_) => _loadData());
      }));
    }
    
    if (_perms.canAdd(FormNames.expensesAdd)) {
      actions.add(_buildQuickAction('مصروف', Icons.receipt_long, Colors.pink, () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AddExpenseScreen(username: widget.username),
        )).then((_) => _loadData());
      }));
    }
    
    if (_perms.employeeId != null) {
      actions.add(_buildQuickAction('حضور', Icons.fingerprint, Colors.teal, () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AttendanceScreen(userId: widget.userId, username: widget.username),
        ));
      }));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('⚡ إجراءات سريعة', style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: actions),
      ],
    );
  }

  Widget _buildQuickAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text('+ $label', style: GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SECTIONS GRID
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionsGrid() {
    final visibleCards = _getVisibleCards();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('📋 الأقسام', style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showCustomizeDialog();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune, color: _primaryColor, size: 14),
                    const SizedBox(width: 6),
                    Text('تخصيص', style: GoogleFonts.cairo(color: _primaryColor, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: visibleCards.length,
          itemBuilder: (context, index) {
            final cardKey = visibleCards[index];
            final cardData = _getCardDataByKey(cardKey);
            if (cardData == null) return const SizedBox.shrink();
            return _buildSectionCard(cardData, isPinned: pinnedCards.contains(cardKey));
          },
        ),
      ],
    );
  }

  _SectionData? _getCardDataByKey(String key) {
    switch (key) {
      case 'clients':
        return _SectionData('العملاء', Icons.people, Colors.teal, 'clients', '${summary['totalClients'] ?? 0}');
      case 'opportunities':
        return _SectionData('الفرص', Icons.lightbulb, Colors.amber, 'opportunities', '${summary['openOpportunities'] ?? 0}');
      case 'tasks':
        return _SectionData('المهام', Icons.task_alt, Colors.purpleAccent, 'tasks', '${summary['tasksToday'] ?? 0}');
      case 'products':
        return _SectionData('المنتجات', Icons.inventory_2, Colors.blueAccent, 'products', '${summary['totalProducts'] ?? 0}');
      case 'expenses':
        return _SectionData('المصروفات', Icons.wallet, Colors.pinkAccent, 'expenses', null);
      case 'crm':
        return _SectionData('لوحة CRM', Icons.dashboard, Colors.cyanAccent, 'crm', null);
      case 'pipeline':
        return _SectionData('مراحل البيع', Icons.trending_up, Colors.deepPurpleAccent, 'pipeline', null);
      case 'price_requests':
        return _SectionData('طلبات الأسعار', Icons.price_change, Colors.deepOrangeAccent, 'price_requests', '${summary['pendingPriceRequests'] ?? 0}');
      case 'employees':
        return _SectionData('الموظفين', Icons.badge, Colors.brown.shade400, 'employees', null);
      
      case 'attendance_report':
      return _SectionData('تقرير الحضور', Icons.access_time, Colors.teal.shade300, 'attendance_report', null);
    case 'my_permissions':
      return _SectionData('أذوناتي', Icons.verified_user, Colors.indigoAccent, 'my_permissions', null);
    case 'delivery':
      return _SectionData('متابعة التسليم', Icons.local_shipping, Colors.green, 'delivery', null);
    case 'complaints':
      return _SectionData('الشكاوى والصيانه', Icons.report_problem, Colors.redAccent, 'complaints', null);
    case 'my_schedule':
      return _SectionData('جدول مواعيدي', Icons.calendar_month, Colors.blue, 'my_schedule', null);
        default:
        return null;
    }
  }

  Widget _buildSectionCard(_SectionData section, {bool isPinned = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _navigateTo(section.route);
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _togglePin(section.route);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [section.color.withOpacity(0.12), section.color.withOpacity(0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPinned ? section.color.withOpacity(0.5) : section.color.withOpacity(0.15),
            width: isPinned ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: section.color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: section.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(section.icon, color: section.color, size: 20),
                ),
                Row(
                  children: [
                    if (isPinned)
                      Icon(Icons.push_pin, color: section.color, size: 14),
                    if (section.count != null && section.count != '0')
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          section.count!,
                          style: GoogleFonts.cairo(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Text(
              section.title,
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePin(String route) {
    setState(() {
      if (pinnedCards.contains(route)) {
        pinnedCards.remove(route);
      } else {
        pinnedCards.add(route);
      }
    });
    _saveCustomization();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(pinnedCards.contains(route) ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              pinnedCards.contains(route) ? 'تم تثبيت القسم' : 'تم إلغاء التثبيت',
              style: GoogleFonts.cairo(),
            ),
          ],
        ),
        backgroundColor: _primaryColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CUSTOMIZE DIALOG
  // ═══════════════════════════════════════════════════════════════

  void _showCustomizeDialog() {
    List<String> tempOrder = List.from(cardOrder);
    Set<String> tempHidden = Set.from(hiddenCards);
    Set<String> tempPinned = Set.from(pinnedCards);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1E1E1E), const Color(0xFF141414)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.dashboard_customize, color: _primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تخصيص الأقسام', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('اسحب، ثبّت، أو أخفِ الأقسام', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setSheetState(() {
                          tempOrder = _getDefaultOrder();
                          tempHidden.clear();
                          tempPinned.clear();
                        });
                      },
                      icon: Icon(Icons.restore, color: Colors.orange, size: 18),
                      label: Text('إعادة ضبط', style: GoogleFonts.cairo(color: Colors.orange, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              
              // List
              Expanded(
                child: ReorderableListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onReorder: (oldIndex, newIndex) {
                    setSheetState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = tempOrder.removeAt(oldIndex);
                      tempOrder.insert(newIndex, item);
                    });
                  },
                  children: tempOrder.map((cardKey) {
                    final data = _getCardDataByKey(cardKey);
                    if (data == null) return SizedBox.shrink(key: Key(cardKey));
                    
                    final isHidden = tempHidden.contains(cardKey);
                    final isPinned = tempPinned.contains(cardKey);
                    
                    return Container(
                      key: Key(cardKey),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isHidden ? Colors.grey.withOpacity(0.05) : data.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isPinned ? _primaryColor.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                          width: isPinned ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isHidden ? Colors.grey.withOpacity(0.1) : data.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(data.icon, color: isHidden ? Colors.grey : data.color, size: 20),
                        ),
                        title: Text(
                          data.title,
                          style: GoogleFonts.cairo(
                            color: isHidden ? Colors.grey : Colors.white,
                            fontWeight: FontWeight.w600,
                            decoration: isHidden ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: isHidden
                            ? Text('مخفي', style: GoogleFonts.cairo(color: Colors.red[300], fontSize: 10))
                            : isPinned
                                ? Text('مثبت في الأعلى', style: GoogleFonts.cairo(color: _primaryColor, fontSize: 10))
                                : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                color: isPinned ? _primaryColor : Colors.grey,
                                size: 20,
                              ),
                              onPressed: isHidden ? null : () {
                                setSheetState(() {
                                  if (tempPinned.contains(cardKey)) {
                                    tempPinned.remove(cardKey);
                                  } else {
                                    tempPinned.add(cardKey);
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                isHidden ? Icons.visibility_off : Icons.visibility,
                                color: isHidden ? Colors.red : Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                setSheetState(() {
                                  if (tempHidden.contains(cardKey)) {
                                    tempHidden.remove(cardKey);
                                  } else {
                                    tempHidden.add(cardKey);
                                    tempPinned.remove(cardKey);
                                  }
                                });
                              },
                            ),
                            Icon(Icons.drag_handle, color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              // Save Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        cardOrder = tempOrder;
                        hiddenCards = tempHidden;
                        pinnedCards = tempPinned;
                      });
                      _saveCustomization();
                      Navigator.pop(context);
                      
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 10),
                              Text('تم حفظ التخصيص', style: GoogleFonts.cairo()),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: Text('حفظ التغييرات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // URGENT TASKS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildUrgentTasks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('🔥 مهام عاجلة (${urgentTasks.length})', style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () => _navigateTo('tasks'),
              child: Text('عرض الكل', style: GoogleFonts.cairo(color: _primaryColor, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...urgentTasks.take(3).map((task) => _buildTaskItem(task)),
      ],
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final title = task['Title'] ?? task['title'] ?? 'مهمة';
    final clientName = task['ClientName'] ?? task['clientName'];
    final status = task['Status'] ?? task['status'] ?? 'pending';
    
    Color statusColor = Colors.purple;
    if (status.toString().toLowerCase() == 'overdue') {
      statusColor = Colors.red;
    } else if (status.toString().toLowerCase().contains('progress')) {
      statusColor = Colors.orange;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _navigateTo('tasks');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toString(), style: GoogleFonts.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (clientName != null)
                    Text(clientName.toString(), style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: statusColor, size: 14),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RECENT ACTIVITIES
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRecentActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🕐 آخر الأنشطة', style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...recentActivities.take(4).map((activity) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getActivityColor(activity['type']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getActivityIcon(activity['type']), color: _getActivityColor(activity['type']), size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity['description'] ?? '', style: GoogleFonts.cairo(color: Colors.white, fontSize: 12)),
                      Text(activity['time'] ?? '', style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getActivityColor(String? type) {
    switch (type) {
      case 'client': return Colors.green;
      case 'opportunity': return Colors.orange;
      case 'task': return Colors.purple;
      case 'expense': return Colors.pink;
      default: return Colors.blue;
    }
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'client': return Icons.person_add;
      case 'opportunity': return Icons.lightbulb;
      case 'task': return Icons.task;
      case 'expense': return Icons.receipt;
      default: return Icons.notifications;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BOTTOM NAV
  // ═══════════════════════════════════════════════════════════════

Widget _buildBottomNav() {
  // ✅ تحقق من صلاحية التقارير
  final bool canSeeReports = _perms.canView(FormNames.reportCustomerBalance) ||
      _perms.canView(FormNames.reportExpenses) ||
      _perms.canView(FormNames.dashboard) ||
      _perms.canView(FormNames.crmDashboard);

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    decoration: BoxDecoration(
      color: const Color(0xFF0F0F0F),
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -5)),
      ],
    ),
    child: SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_rounded, 'الرئيسية', 0),
          
          // ✅ التقارير تظهر بس لو عنده صلاحية
          if (canSeeReports)
            _buildNavItem(Icons.analytics_rounded, 'التقارير', 1),
          
          _buildNavItem(Icons.settings_rounded, 'الإعدادات', canSeeReports ? 2 : 1),
        ],
      ),
    ),
  );
}

  Widget _buildNavItem(IconData icon, String label, int index) {
  final isSelected = _selectedNavIndex == index;
  
  // ✅ تحقق من صلاحية التقارير
  final bool canSeeReports = _perms.canView(FormNames.reportCustomerBalance) ||
      _perms.canView(FormNames.reportExpenses) ||
      _perms.canView(FormNames.dashboard) ||
      _perms.canView(FormNames.crmDashboard);
  
  return GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      
      if (index == 0) {
        // الرئيسية
        setState(() => _selectedNavIndex = 0);
      } else if (index == 1 && canSeeReports) {
        // التقارير (لو عنده صلاحية)
        setState(() => _selectedNavIndex = 1);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ReportsScreen(userId: widget.userId, username: widget.username),
        )).then((_) => setState(() => _selectedNavIndex = 0));
      } else if ((index == 2 && canSeeReports) || (index == 1 && !canSeeReports)) {
        // الإعدادات
        setState(() => _selectedNavIndex = index);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SettingsScreen(userId: widget.userId, username: widget.username, fullName: widget.fullName),
        )).then((_) => setState(() => _selectedNavIndex = 0));
      }
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? _primaryColor.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: isSelected ? _primaryColor : Colors.grey[600], size: 24),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.cairo(color: _primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    ),
  );
}

  // ═══════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════

  void _navigateTo(String route) {
    Widget? screen;
    
    switch (route) {
      case 'clients':
        screen = ClientsScreen(userId: widget.userId, username: widget.username);
        break;
      case 'opportunities':
        screen = OpportunitiesScreen(userId: widget.userId, username: widget.username);
        break;
      case 'tasks':
        screen = TasksScreen(userId: widget.userId, username: widget.username);
        break;
      case 'products':
        screen = ProductsScreen(userId: widget.userId, username: widget.username);
        break;
      case 'expenses':
        screen = ExpensesScreen(userId: widget.userId, username: widget.username);
        break;
      case 'crm':
        screen = CrmDashboardScreen(userId: widget.userId, username: widget.username);
        break;
      case 'pipeline':
        screen = PipelineScreen(userId: widget.userId, username: widget.username);
        break;
      case 'price_requests':
        screen = PriceRequestsScreen(username: widget.username);
        break;
      case 'employees':
        screen = EmployeesScreen(userId: widget.userId, username: widget.username);
        break;
      case 'attendance':
        screen = AttendanceScreen(userId: widget.userId, username: widget.username);
        break;
      case 'reports':
        screen = ReportsScreen(userId: widget.userId, username: widget.username);
        break;
      case 'settings':
        screen = SettingsScreen(userId: widget.userId, username: widget.username, fullName: widget.fullName);
        break;
      // ✅ الشاشات الجديدة
      case 'delivery':
        screen = DeliveryTrackingScreen(userId: widget.userId, username: widget.username);
        break;
      case 'complaints':
        screen = ComplaintsScreen(userId: widget.userId, username: widget.username);
        break;
      case 'my_schedule':
        screen = MyScheduleScreen(userId: widget.userId, username: widget.username);
        break;
      case 'attendance_report':
        screen = AttendanceReportScreen(userId: widget.userId, username: widget.username);
        break;
      case 'my_permissions':
        screen = PermissionsListScreen(userId: widget.userId);
        break;
    }
    
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!)).then((_) => _loadData());
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${days[now.weekday - 1]}، ${now.day} ${months[now.month - 1]}';
  }

  @override
  void dispose() {
    _animController.dispose();
    _notificationService.stopPolling();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════

class _SectionData {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final String? count;

  _SectionData(this.title, this.icon, this.color, this.route, this.count);
}