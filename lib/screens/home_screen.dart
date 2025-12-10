import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import 'notifications_screen.dart';
import 'products_screen.dart';
import 'expenses_screen.dart';
import 'add_expense_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import 'clients_screen.dart';
import 'add_client_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String? fullName;
  
  const HomeScreen({
    super.key, 
    required this.userId, 
    required this.username,
    this.fullName,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int unreadCount = 0;
  Map<String, dynamic> summary = {};
  List<dynamic> recentActivities = [];
  bool loading = true;
  String greeting = '';
  int _currentNavIndex = 0;
  
  // ✅ المتغيرات الجديدة
  bool isConnected = true;
  DateTime lastUpdate = DateTime.now();
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _setGreeting();
    fetchDashboard();
    _startNotificationService();
  }

  @override
  void dispose() {
    _notificationService.stopPolling();
    super.dispose();
  }

  void _startNotificationService() {
    _notificationService.startPolling(widget.username);
    
    _notificationService.onNotificationTap = (payload) {
      if (payload != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NotificationsScreen(
              userId: widget.userId,
              username: widget.username,
            ),
          ),
        );
      }
    };
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = 'صباح الخير';
    } else if (hour < 18) {
      greeting = 'مساء الخير';
    } else {
      greeting = 'مساء النور';
    }
  }

  Future<void> fetchRecentActivities() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/activities/recent?username=${widget.username}'),
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        
        setState(() {
          if (data is Map && data['activities'] != null) {
            recentActivities = List<Map<String, dynamic>>.from(data['activities']);
          } else if (data is List) {
            recentActivities = List<Map<String, dynamic>>.from(data);
          } else {
            recentActivities = [];
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching activities: $e');
    }
  }

  Future<void> fetchDashboard() async {
    try {
      setState(() => isConnected = true);
      
      final res = await http.get(
        Uri.parse('$baseUrl/api/dashboard?userId=${widget.userId}&username=${widget.username}'),
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          summary = data['summary'] ?? {};
          unreadCount = data['unreadCount'] ?? 0;
          loading = false;
          lastUpdate = DateTime.now();
        });
        
        await fetchRecentActivities();
      }
    } catch (e) {
      setState(() {
        loading = false;
        isConnected = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.exit_to_app, color: Color(0xFFFFD700)),
            const SizedBox(width: 10),
            Text(
              'الخروج من التطبيق',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'هل تريد الخروج من التطبيق؟',
          style: GoogleFonts.cairo(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('لا', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('نعم', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  String _getInitials() {
    final name = widget.fullName ?? widget.username;
    if (name.isEmpty) return 'م';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)),
              )
            : RefreshIndicator(
                onRefresh: fetchDashboard,
                color: const Color(0xFFE8B923),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _buildStatsSection(),
                            const SizedBox(height: 30),
                            _buildQuickActionsSection(),
                            const SizedBox(height: 30),
                            _buildMainButtonsSection(),
                            const SizedBox(height: 30),
                            _buildRecentActivitiesSection(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ الـ HEADER الجديد
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: true,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF1A1A1A),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2D2006), Color(0xFF1A1A1A)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopRow(),
                  const SizedBox(height: 12),
                  _buildUserInfoRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildTimeIcon(),
            const SizedBox(width: 8),
            Text(
              greeting,
              style: GoogleFonts.cairo(
                color: Colors.grey[300],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        _buildNotificationButton(),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildTimeIcon() {
    final hour = DateTime.now().hour;
    IconData icon;
    Color color;
    
    if (hour >= 6 && hour < 12) {
      icon = Icons.wb_sunny_rounded;
      color = Colors.orange;
    } else if (hour >= 12 && hour < 18) {
      icon = Icons.wb_cloudy_rounded;
      color = Colors.amber;
    } else {
      icon = Icons.nightlight_round;
      color = Colors.indigo[300]!;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: 0.7, end: 1, duration: 2.seconds);
  }

  Widget _buildUserInfoRow() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFE8B923)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _getInitials(),
              style: GoogleFonts.cairo(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.fullName ?? widget.username,
                style: GoogleFonts.cairo(
                  color: const Color(0xFFFFD700),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _getFormattedDate(),
                style: GoogleFonts.cairo(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _buildConnectionStatus(),
      ],
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildConnectionStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isConnected ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                boxShadow: isConnected
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isConnected ? 'متصل' : 'غير متصل',
              style: GoogleFonts.cairo(
                color: isConnected ? Colors.green : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sync,
              color: Colors.grey[600],
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              _getLastUpdateText(),
              style: GoogleFonts.cairo(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final dayName = _getArabicDayName(now.weekday);
    final monthName = _getArabicMonthName(now.month);
    return '$dayName، ${now.day} $monthName';
  }

  String _getArabicDayName(int weekday) {
    const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[weekday - 1];
  }

  String _getArabicMonthName(int month) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month - 1];
  }

  String _getLastUpdateText() {
    final difference = DateTime.now().difference(lastUpdate);
    
    if (difference.inSeconds < 30) {
      return 'الآن';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds} ث';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} د';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} س';
    } else {
      return '${difference.inDays} ي';
    }
  }

  Widget _buildNotificationButton() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationsScreen(
                    userId: widget.userId,
                    username: widget.username,
                  ),
                ),
              ).then((_) => fetchDashboard());
            },
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ قسم الإحصائيات
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFFFFD700), size: 22),
            const SizedBox(width: 8),
            Text(
              'إحصائيات اليوم',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'عملاء جدد',
                '${summary['newClientsToday'] ?? 0}',
                Icons.person_add_outlined,
                const Color(0xFF4CAF50),
                0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'فرص مفتوحة',
                '${summary['openOpportunities'] ?? 0}',
                Icons.lightbulb_outline,
                const Color(0xFFFF9800),
                1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'مهام اليوم',
                '${summary['tasksToday'] ?? 0}',
                Icons.task_alt_outlined,
                const Color(0xFF9C27B0),
                2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'مبيعات اليوم',
                _formatCurrency(summary['salesToday']),
                Icons.payments_outlined,
                const Color(0xFF2196F3),
                3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 100 * index), duration: 500.ms)
        .slideY(begin: 0.2, end: 0);
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 ج.م';
    final num = double.tryParse(amount.toString()) ?? 0;
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M ج.م';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K ج.م';
    return '${num.toInt()} ج.م';
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ قسم الإجراءات السريعة
  // ═══════════════════════════════════════════════════════════════

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on, color: Color(0xFFFFD700), size: 22),
            const SizedBox(width: 8),
            Text(
              'إجراءات سريعة',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildQuickAction('عميل جديد', Icons.person_add, const Color(0xFF4CAF50), () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddClientScreen(username: widget.username),
                  ),
                ).then((result) {
                  if (result == true) fetchDashboard();
                });
              }),
              _buildQuickAction('فرصة جديدة', Icons.lightbulb, const Color(0xFFFF9800), () {
                _showComingSoon('الفرص');
              }),
              _buildQuickAction('مهمة جديدة', Icons.add_task, const Color(0xFF9C27B0), () {
                _showComingSoon('المهام');
              }),
              _buildQuickAction('مصروف', Icons.money_off, Colors.red, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExpenseScreen(username: widget.username),
                  ),
                ).then((result) {
                  if (result == true) fetchDashboard();
                });
              }),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - قريباً! 🚀', style: GoogleFonts.cairo()),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ قسم الأزرار الرئيسية
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMainButtonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.apps, color: Color(0xFFFFD700), size: 22),
            const SizedBox(width: 8),
            Text(
              'الأقسام الرئيسية',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildMainButton(
              'المنتجات',
              Icons.inventory_2_outlined,
              const Color(0xFFE8B923),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductsScreen(
                      userId: widget.userId,
                      username: widget.username,
                    ),
                  ),
                );
              },
              0,
            ),
            _buildMainButton(
              'المصروفات',
              Icons.money_off,
              Colors.red,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExpensesScreen(
                      userId: widget.userId,
                      username: widget.username,
                    ),
                  ),
                );
              },
              1,
            ),
            _buildMainButton(
              'العملاء',
              Icons.people_outline,
              const Color(0xFF4CAF50),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientsScreen(
                      userId: widget.userId,
                      username: widget.username,
                    ),
                  ),
                );
              },
              2,
            ),
            _buildMainButton(
              'الفرص',
              Icons.trending_up,
              const Color(0xFFFF9800),
              () {
                _showComingSoon('الفرص');
              },
              3,
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 500.ms, duration: 500.ms);
  }

  Widget _buildMainButton(String label, IconData icon, Color color, VoidCallback onTap, int index) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.25), color.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 100 * index), duration: 400.ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ قسم آخر النشاطات
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRecentActivitiesSection() {
    if (recentActivities.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFFFFD700), size: 22),
                const SizedBox(width: 8),
                Text(
                  'آخر النشاطات',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                // TODO: فتح صفحة كل النشاطات
              },
              child: Text(
                'عرض الكل',
                style: GoogleFonts.cairo(
                  color: const Color(0xFFFFD700),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentActivities.length > 5 ? 5 : recentActivities.length,
          itemBuilder: (context, index) {
            final activity = recentActivities[index];
            return _buildActivityItem(activity, index);
          },
        ),
      ],
    ).animate().fadeIn(delay: 600.ms, duration: 500.ms);
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, int index) {
    final String type = activity['type']?.toString() ?? 'info';
    final String title = activity['title']?.toString() ?? 'نشاط';
    final String description = activity['description']?.toString() ?? '';
    final String timeAgo = activity['timeAgo']?.toString() ?? '';
    
    Color color;
    IconData icon;
    
    switch (type) {
      case 'client':
        color = const Color(0xFF4CAF50);
        icon = Icons.person_add;
        break;
      case 'expense':
        color = Colors.red;
        icon = Icons.money_off;
        break;
      case 'opportunity':
        color = const Color(0xFFFF9800);
        icon = Icons.lightbulb;
        break;
      case 'task':
        color = const Color(0xFF9C27B0);
        icon = Icons.task_alt;
        break;
      case 'sale':
        color = const Color(0xFF2196F3);
        icon = Icons.shopping_cart;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: GoogleFonts.cairo(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: GoogleFonts.cairo(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 100 * index), duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ شريط التنقل السفلي
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_filled, 'الرئيسية', _currentNavIndex == 0, () {
                setState(() => _currentNavIndex = 0);
              }),
              _buildNavItem(Icons.people_outline, 'العملاء', _currentNavIndex == 1, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClientsScreen(
                      userId: widget.userId,
                      username: widget.username,
                    ),
                  ),
                );
              }),
              _buildNavItem(Icons.add_circle, '', false, () {
                _showQuickAddMenu();
              }, isCenter: true),
              _buildNavItem(Icons.analytics_outlined, 'التقارير', _currentNavIndex == 3, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportsScreen(
                      userId: widget.userId,
                      username: widget.username,
                    ),
                  ),
                );
              }),
              _buildNavItem(Icons.settings_outlined, 'الإعدادات', _currentNavIndex == 4, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      userId: widget.userId,
                      username: widget.username,
                      fullName: widget.fullName,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap, {bool isCenter = false}) {
    if (isCenter) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFE8B923)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.black, size: 32),
        ),
      );
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFFFFD700) : Colors.grey[600],
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: isActive ? const Color(0xFFFFD700) : Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ قائمة الإضافة السريعة
  // ═══════════════════════════════════════════════════════════════

  void _showQuickAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'إضافة جديد',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildQuickAddItem(
              icon: Icons.person_add,
              label: 'عميل جديد',
              color: const Color(0xFF4CAF50),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddClientScreen(username: widget.username),
                  ),
                ).then((result) {
                  if (result == true) fetchDashboard();
                });
              },
            ),
            _buildQuickAddItem(
              icon: Icons.lightbulb,
              label: 'فرصة جديدة',
              color: const Color(0xFFFF9800),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('الفرص');
              },
            ),
            _buildQuickAddItem(
              icon: Icons.add_task,
              label: 'مهمة جديدة',
              color: const Color(0xFF9C27B0),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('المهام');
              },
            ),
            _buildQuickAddItem(
              icon: Icons.money_off,
              label: 'مصروف جديد',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExpenseScreen(username: widget.username),
                  ),
                ).then((result) {
                  if (result == true) fetchDashboard();
                });
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        label,
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 16),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
      onTap: onTap,
    );
  }
}