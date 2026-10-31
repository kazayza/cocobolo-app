import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // ✅ إضافة المكتبة دي
import '../services/icon_utils.dart';
import './Reports/expense_reports.dart';
import 'reports/crm_dashboard_screen.dart'; // ✅ إضافة شاشة الداشبورد
import 'reports/sales_analytics_screen.dart'; // ✅ تحليلات المبيعات (بند 23)
import 'expenses/expense_dashboard_screen.dart';
import 'cashbox_transactions_screen.dart';
import 'cashbox/cashbox_dashboard_screen.dart';

class ReportsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ReportsScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // دالة فتح تقارير المصروفات
  void _openExpenseReports(String period) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseReportsScreen(
          userId: widget.userId,
          username: widget.username,
          initialPeriod: period,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDark,
      appBar: AppBar(
        title: Text(
          'التقارير',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== تقارير المبيعات =====
            _buildSectionTitle('تقارير المبيعات', Icons.point_of_sale),
            const SizedBox(height: AppSpacing.md),
            _buildReportsGrid([
              _ReportItem(
                title: 'مبيعات اليوم',
                icon: Icons.today,
                color: const Color(0xFF4CAF50),
                onTap: () => _showComingSoon('تقرير مبيعات اليوم'),
              ),
              _ReportItem(
                title: 'مبيعات الشهر',
                icon: Icons.calendar_month,
                color: const Color(0xFF2196F3),
                onTap: () => _showComingSoon('تقرير مبيعات الشهر'),
              ),
              _ReportItem(
                title: 'أفضل المنتجات',
                icon: Icons.star,
                color: const Color(0xFFFF9800),
                onTap: () => _showComingSoon('تقرير أفضل المنتجات'),
              ),
              _ReportItem(
                title: 'تحليلات المبيعات',
                icon: Icons.analytics,
                color: const Color(0xFF9C27B0),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SalesAnalyticsScreen(
                      userId: widget.userId,
                      username: widget.username,
                    ),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: AppSpacing.xl),

            // ===== تقارير العملاء =====
            _buildSectionTitle('تقارير العملاء', Icons.people),
            const SizedBox(height: AppSpacing.md),
            _buildReportsGrid([
              _ReportItem(
                title: 'أرصدة العملاء',
                icon: Icons.account_balance_wallet,
                color: const Color(0xFF00BCD4),
                onTap: () => _showComingSoon('تقرير أرصدة العملاء'),
              ),
              _ReportItem(
                title: 'كشف حساب عميل',
                icon: Icons.receipt_long,
                color: const Color(0xFF8BC34A),
                onTap: () => _showComingSoon('كشف حساب عميل'),
              ),
              _ReportItem(
                title: 'العملاء الجدد',
                icon: Icons.person_add,
                color: const Color(0xFF3F51B5),
                onTap: () => _showComingSoon('تقرير العملاء الجدد'),
              ),
              _ReportItem(
                title: 'تحليل العملاء',
                icon: Icons.pie_chart,
                color: const Color(0xFFE91E63),
                onTap: () => _showComingSoon('تحليل العملاء'),
              ),
            ]),

            const SizedBox(height: AppSpacing.xl),

            // ===== تقارير المصروفات =====
            _buildSectionTitle('تقارير المصروفات', Icons.money_off),
            const SizedBox(height: AppSpacing.md),
            _buildReportsGrid([
              _ReportItem(
                title: 'مصروفات اليوم',
                icon: Icons.today,
                color: Colors.red,
                onTap: () => _openExpenseReports('اليوم'),
              ),
              _ReportItem(
                title: 'مصروفات الشهر',
                icon: Icons.calendar_month,
                color: Colors.redAccent,
                onTap: () => _openExpenseReports('هذا الشهر'),
              ),
              _ReportItem(
                title: 'تحليل المصروفات',
                icon: Icons.donut_large,
                color: Colors.deepOrange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExpenseDashboardScreen(
                      userId: widget.userId,
                      username: widget.username,
                    ),
                  ),
                ),
              ),
              _ReportItem(
                title: 'مقارنة شهرية',
                icon: Icons.compare_arrows,
                color: Colors.orange,
                onTap: () => _openExpenseReports('الشهر الماضي'),
              ),
            ]),

            const SizedBox(height: AppSpacing.xl),

            // ===== تقارير المبيعات والعملاء (CRM) - قسم جديد ✅ =====
            _buildSectionTitle('تحليلات الـ CRM', FontAwesomeIcons.chartLine),
            const SizedBox(height: AppSpacing.md),
            _buildReportsGrid([
              // ✅ ده الكارت الجديد (لوحة القيادة)
              _ReportItem(
                title: 'لوحة القيادة (Dashboard)',
                icon: FontAwesomeIcons.chartPie,
                color: AppColors.gold,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CrmDashboardScreen(
                        userId: widget.userId,
                        username: widget.username,
                      ),
                    ),
                  );
                },
              ),
              // ممكن تضيف تقارير CRM تانية هنا مستقبلاً
            ]),

            const SizedBox(height: AppSpacing.xl),

            // ===== تقارير الخزينة =====
            _buildSectionTitle('تقارير الخزينة', Icons.account_balance),
            const SizedBox(height: AppSpacing.md),
            _buildReportsGrid([
              _ReportItem(
                title: 'حركة الخزينة',
                icon: Icons.swap_horiz,
                color: const Color(0xFF607D8B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CashboxTransactionsScreen(
                        userId: widget.userId,
                        username: widget.username,
                      ),
                    ),
                  );
                },
              ),
              _ReportItem(
                title: 'مؤشرات الخزينة',
                icon: Icons.analytics,
                color: const Color(0xFF795548),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CashBoxDashboardScreen(
                        userId: widget.userId,
                        username: widget.username,
                      ),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 🧩 دوال بناء الواجهة

  Widget _buildSectionTitle(String title, dynamic icon) {
    return Row(
      children: [
        compatIcon(icon, color: AppColors.gold, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildReportsGrid(List<_ReportItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildReportCard(item, index);
      },
    );
  }

  Widget _buildReportCard(_ReportItem item, int index) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              item.color.withOpacity(0.2),
              item.color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: item.color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: item.icon is FaIconData
                  ? FaIcon(item.icon as FaIconData, color: item.color, size: 28)
                  : Icon(item.icon as IconData, color: item.color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: 50 * index),
      duration: 400.ms,
    ).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - قريباً! 🚀', style: GoogleFonts.cairo()),
        backgroundColor: AppColors.navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// كلاس البيانات (مودل صغير)
class _ReportItem {
  final String title;
  final dynamic icon; // غيّرنا النوع ليقبل IconData و FaIconData مع بعض
  final Color color;
  final VoidCallback onTap;

  _ReportItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}