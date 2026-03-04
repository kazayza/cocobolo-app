import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/permission_service.dart';
import '../services/app_colors.dart';
import 'reports/crm_dashboard_screen.dart';
import 'products_screen.dart';
import 'expenses_screen.dart';
import 'clients_screen.dart';
import 'tasks_screen.dart';
import 'opportunities_screen.dart';
import 'add_client_screen.dart';
import 'add_expense_screen.dart';
import 'add_opportunity_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class AllAppsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const AllAppsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<AllAppsScreen> createState() => _AllAppsScreenState();
}

class _AllAppsScreenState extends State<AllAppsScreen> {
  // لتتبع القسم المفتوح حالياً
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // تصفية الأقسام (نعرض فقط اللي فيه صلاحية لحاجة جواه)
    final allItems = MenuStructure.getItems();
    final visibleItems = allItems.where((item) {
      return item.children.any((sub) => PermissionService().canView(sub.formName) || PermissionService().canAdd(sub.formName));
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'كل التطبيقات',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: visibleItems.isEmpty
          ? Center(child: Text('لا توجد تطبيقات متاحة', style: GoogleFonts.cairo(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                return _buildExpandableCard(item, index, isDark);
              },
            ),
    );
  }

  // === الكارت القابل للتوسيع (Accordion) ===
  Widget _buildExpandableCard(MenuItem item, int index, bool isDark) {
    final isExpanded = _expandedIndex == index;

    // تصفية الأزرار الفرعية
    final subItems = item.children.where((sub) {
      return PermissionService().canView(sub.formName) || PermissionService().canAdd(sub.formName);
    }).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? item.color.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. رأس الكارت (Header)
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: Radius.circular(isExpanded ? 0 : 16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // الأيقونة الملونة
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  
                  // العنوان
                  Expanded(
                    child: Text(
                      item.title,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),

                  // سهم التوسيع
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0, // 180 درجة
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.grey : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. المحتوى الفرعي (Body)
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Column(
              children: [
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                
                // Grid للأزرار الفرعية
                GridView.builder(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 في الصف
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: subItems.length,
                  itemBuilder: (context, subIndex) {
                    return _buildSubButton(subItems[subIndex], item.color, isDark);
                  },
                ),
              ],
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideY(begin: 0.1, end: 0);
  }

  // === الزر الفرعي الصغير ===
  Widget _buildSubButton(SubMenuItem sub, Color color, bool isDark) {
    return InkWell(
      onTap: () => _navigateToScreen(sub.formName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(sub.icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              sub.title,
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // === التوجيه ===
  void _navigateToScreen(String formName) {
    Widget? screen;

    switch (formName) {
      // --- CRM ---
      case FormNames.dashboardCRM:
        screen = CrmDashboardScreen(userId: widget.userId, username: widget.username);
        break;
      case FormNames.salesPipeline:
        screen = OpportunitiesScreen(userId: widget.userId, username: widget.username);
        break;
      case FormNames.dailyTasks:
        screen = TasksScreen(userId: widget.userId, username: widget.username);
        break;
      case FormNames.newInteraction:
        screen = AddOpportunityScreen(userId: widget.userId, username: widget.username);
        break;
      
      // --- منتجات ---
      case FormNames.productsList:
        screen = ProductsScreen(userId: widget.userId, username: widget.username);
        break;
      
      // --- حسابات ---
      case FormNames.expensesList:
        screen = ExpensesScreen(userId: widget.userId, username: widget.username);
        break;
      case FormNames.expensesAdd:
        screen = AddExpenseScreen(username: widget.username);
        break;
      
      // --- عملاء ---
      case FormNames.partiesList:
        screen = ClientsScreen(userId: widget.userId, username: widget.username);
        break;
      case FormNames.partiesAdd:
        screen = AddClientScreen(username: widget.username);
        break;

      // --- تقارير ---
      case FormNames.reportCustomerBalance:
      case FormNames.reportExpenses:
        screen = ReportsScreen(userId: widget.userId, username: widget.username);
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('قريباً: $formName 🛠️', style: GoogleFonts.cairo()),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
    }

    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }
}