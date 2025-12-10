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
  bool loading = true;
  String greeting = '';
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _setGreeting();
    fetchDashboard();
    _startNotificationService();
  }

  @override
  void dispose() {
    NotificationService().stopPolling();
    super.dispose();
  }

  void _startNotificationService() {
    final notificationService = NotificationService();
    
    notificationService.startPolling(widget.username);
    
    notificationService.onNotificationTap = (payload) {
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

  Future<void> fetchDashboard() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/dashboard?userId=${widget.userId}&username=${widget.username}'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          summary = data['summary'] ?? {};
          unreadCount = data['unreadCount'] ?? 0;
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
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

  // ✅ الحصول على الحرف الأول من الاسم
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

  // ✅ AppBar الجديد - محسّن
  // ✅ AppBar الجديد - محسّن
Widget _buildSliverAppBar() {
  final now = DateTime.now();
  final dayName = _getArabicDayName(now.weekday);
  final date = '${now.day}/${now.month}/${now.year}';
  
  return SliverAppBar(
    expandedHeight: 155, // ✅ تم زيادة الارتفاع من 140 إلى 155
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min, // ✅ إضافة هذا السطر
              children: [
                // ===== الصف العلوي: الإشعارات فقط =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildNotificationButton(),
                  ],
                ),
                
                const SizedBox(height: 8), // ✅ تقليل المسافة من 12 إلى 8
                
                // ===== صورة اليوزر + التحية + التاريخ =====
                Row(
                  children: [
                    // صورة اليوزر (الحرف الأول)
                    Container(
                      width: 50, // ✅ تقليل من 55 إلى 50
                      height: 50, // ✅ تقليل من 55 إلى 50
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
                            fontSize: 22, // ✅ تقليل من 24 إلى 22
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12), // ✅ تقليل من 14 إلى 12
                    
                    // التحية والاسم والتاريخ
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$greeting 👋',
                            style: GoogleFonts.cairo(
                              color: Colors.grey[400],
                              fontSize: 12, // ✅ تقليل من 13 إلى 12
                            ),
                          ),
                          Text(
                            widget.fullName ?? widget.username,
                            style: GoogleFonts.cairo(
                              color: const Color(0xFFFFD700),
                              fontSize: 18, // ✅ تقليل من 20 إلى 18
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$dayName، $date',
                            style: GoogleFonts.cairo(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  String _getArabicDayName(int weekday) {
    const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[weekday - 1];
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
                '$unreadCount',
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
              child: _buildStatCard('عملاء جدد', '${summary['newClientsToday'] ?? 0}', Icons.person_add_outlined, const Color(0xFF4CAF50), 0),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard('فرص مفتوحة', '${summary['openOpportunities'] ?? 0}', Icons.lightbulb_outline, const Color(0xFFFF9800), 1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard('مهام اليوم', '${summary['tasksToday'] ?? 0}', Icons.task_alt_outlined, const Color(0xFF9C27B0), 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard('مبيعات اليوم', _formatCurrency(summary['salesToday']), Icons.payments_outlined, const Color(0xFF2196F3), 3),
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
          Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 * index), duration: 500.ms).slideY(begin: 0.2, end: 0);
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 ج.م';
    final num = double.tryParse(amount.toString()) ?? 0;
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M ج.م';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K ج.م';
    return '${num.toInt()} ج.م';
  }

  // ✅ الإجراءات السريعة - مع تفعيل الأزرار
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on, color: Color(0xFFFFD700), size: 22),
            const SizedBox(width: 8),
            Text('إجراءات سريعة', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // ✅ عميل جديد
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
              
              // فرصة جديدة
              _buildQuickAction('فرصة جديدة', Icons.lightbulb, const Color(0xFFFF9800), () {
                _showComingSoon('الفرص');
              }),
              
              // مهمة جديدة
              _buildQuickAction('مهمة جديدة', Icons.add_task, const Color(0xFF9C27B0), () {
                _showComingSoon('المهام');
              }),
              
              // ✅ مصروف جديد
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
              Text(label, style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButtonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.apps, color: Color(0xFFFFD700), size: 22),
            const SizedBox(width: 8),
            Text('الأقسام الرئيسية', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
            _buildMainButton('المنتجات', Icons.inventory_2_outlined, const Color(0xFFE8B923), () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsScreen(userId: widget.userId, username: widget.username)));
            }, 0),
            _buildMainButton('المصروفات', Icons.money_off, Colors.red, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ExpensesScreen(userId: widget.userId, username: widget.username)));
            }, 1),
            _buildMainButton('العملاء', Icons.people_outline, const Color(0xFF4CAF50), () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientsScreen(
                    userId: widget.userId,
                    username: widget.username,
                  ),
                ),
              );
            }, 2),
            _buildMainButton('الفرص', Icons.trending_up, const Color(0xFFFF9800), () {
              _showComingSoon('الفرص');
            }, 3),
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
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(label, style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 * index), duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  // ✅ Bottom Navigation Bar - مفعّل
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -5))],
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

  // ✅ قائمة الإضافة السريعة
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
            
            // عميل جديد
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
            
            // فرصة جديدة
            _buildQuickAddItem(
              icon: Icons.lightbulb,
              label: 'فرصة جديدة',
              color: const Color(0xFFFF9800),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('الفرص');
              },
            ),
            
            // مهمة جديدة
            _buildQuickAddItem(
              icon: Icons.add_task,
              label: 'مهمة جديدة',
              color: const Color(0xFF9C27B0),
              onTap: () {
                Navigator.pop(context);
                _showComingSoon('المهام');
              },
            ),
            
            // مصروف جديد
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

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap, {bool isCenter = false}) {
    if (isCenter) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFE8B923)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
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
          Icon(icon, color: isActive ? const Color(0xFFFFD700) : Colors.grey[600], size: 26),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.cairo(color: isActive ? const Color(0xFFFFD700) : Colors.grey[600], fontSize: 11)),
        ],
      ),
    );
  }
}