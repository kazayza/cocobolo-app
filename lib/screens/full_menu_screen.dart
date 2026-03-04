import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/permission_service.dart';
import 'login_screen.dart';

class FullMenuScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String? fullName;

  const FullMenuScreen({
    super.key,
    required this.userId,
    required this.username,
    this.fullName,
  });

  @override
  State<FullMenuScreen> createState() => _FullMenuScreenState();
}

class _FullMenuScreenState extends State<FullMenuScreen> {
  final perms = PermissionService();
  
  // القسم المختار
  int? _selectedSectionIndex;
  
  // الأقسام المرئية
  late List<MenuItem> _visibleSections;

  @override
  void initState() {
    super.initState();
    _loadVisibleSections();
  }

  void _loadVisibleSections() {
    final allItems = MenuStructure.getItems();
    _visibleSections = allItems.where((item) {
      return item.children.any((sub) => perms.canView(sub.formName));
    }).toList();
  }

  String _getInitials() {
    final name = widget.fullName ?? widget.username;
    if (name.isEmpty) return 'م';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getRoleTitle() {
    switch (perms.role?.toLowerCase()) {
      case 'admin': return 'المدير العام';
      case 'salesmanager': return 'مدير المبيعات';
      case 'sales': return 'موظف مبيعات';
      case 'accountmanager': return 'مدير الحسابات';
      case 'account': return 'موظف حسابات';
      case 'warehouse': return 'أمين المخزن';
      case 'cashier': return 'أمين الخزينة';
      default: return 'مستخدم';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // الهيدر
            _buildHeader(isDark),
            
            // المحتوى
            Expanded(
              child: _selectedSectionIndex == null
                  ? _buildSectionsGrid(isDark)
                  : _buildSubItemsGrid(isDark),
            ),
            
            // تسجيل الخروج
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }

    // ═══════════════════════════════════════════════════════════════
  // الهيدر
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // زرار الرجوع أو القفل
          GestureDetector(
            onTap: () {
              if (_selectedSectionIndex != null) {
                setState(() => _selectedSectionIndex = null);
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _selectedSectionIndex != null ? Icons.arrow_back_ios_new : Icons.close,
                color: isDark ? Colors.white : Colors.black,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // معلومات المستخدم
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedSectionIndex != null
                      ? _visibleSections[_selectedSectionIndex!].title
                      : widget.fullName ?? widget.username,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (_selectedSectionIndex == null)
                  Text(
                    _getRoleTitle(),
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: const Color(0xFFE8B923),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          // صورة المستخدم (تظهر في الصفحة الرئيسية فقط)
          if (_selectedSectionIndex == null)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFE8B923)],
                ),
                borderRadius: BorderRadius.circular(14),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ).animate().scale(duration: 400.ms),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ═══════════════════════════════════════════════════════════════
  // الفوتر (تسجيل الخروج)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
          ),
        ),
      ),
      child: GestureDetector(
        onTap: () => _showLogoutDialog(isDark),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
              const SizedBox(width: 10),
              Text(
                'تسجيل الخروج',
                style: GoogleFonts.cairo(
                  color: Colors.red,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد تسجيل الخروج من التطبيق؟',
          style: GoogleFonts.cairo(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              PermissionService().clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('تسجيل الخروج', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

    // ═══════════════════════════════════════════════════════════════
  // شبكة الأقسام الرئيسية
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionsGrid(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          // عنوان
          Text(
            'الأقسام',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 16),

          // الشبكة
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.95,
              ),
              itemCount: _visibleSections.length,
              itemBuilder: (context, index) {
                return _buildSectionCard(
                  _visibleSections[index],
                  isDark,
                  index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(MenuItem item, bool isDark, int index) {
    // عدد الفرعيات المتاحة
    final visibleCount = item.children.where((sub) {
      return perms.canView(sub.formName);
    }).length;

    return GestureDetector(
      onTap: () => setState(() => _selectedSectionIndex = index),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.color.withOpacity(0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الأيقونة
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    item.color.withOpacity(0.2),
                    item.color.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.icon,
                color: item.color,
                size: 26,
              ),
            ),

            const SizedBox(height: 10),

            // الاسم
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.title,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 4),

            // عدد العناصر
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$visibleCount',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 60 * index), duration: 400.ms)
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          duration: 400.ms,
        );
  }

    // ═══════════════════════════════════════════════════════════════
  // شبكة الفرعيات
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSubItemsGrid(bool isDark) {
    if (_selectedSectionIndex == null) return const SizedBox.shrink();

    final section = _visibleSections[_selectedSectionIndex!];
    
    final visibleItems = section.children.where((sub) {
      return perms.canView(sub.formName);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          // وصف القسم
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  section.color.withOpacity(0.15),
                  section.color.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: section.color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(section.icon, color: section.color, size: 24),
                const SizedBox(width: 10),
                Text(
                  '${visibleItems.length} عنصر متاح',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: section.color,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 16),

          // الشبكة
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                return _buildSubItemCard(
                  visibleItems[index],
                  section.color,
                  isDark,
                  index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItemCard(SubMenuItem item, Color sectionColor, bool isDark, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // نقفل الشاشة
        _navigateToScreen(item.formName);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: sectionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                item.icon,
                color: sectionColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.title,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms)
        .slideY(begin: 0.15, end: 0, duration: 300.ms);
  }

  // ═══════════════════════════════════════════════════════════════
  // التنقل للشاشات
  // ═══════════════════════════════════════════════════════════════

  void _navigateToScreen(String formName) {
    Widget? screen;

    switch (formName) {
      // ─────────── البيانات الأساسية ───────────
      // case 'frm_CompanyInfo':
      //   screen = CompanyInfoScreen();
      //   break;
      // case 'frm_ProductList':
      //   screen = ProductsScreen(userId: widget.userId, username: widget.username);
      //   break;
      // case 'frm_PartiesList':
      //   screen = ClientsScreen(userId: widget.userId, username: widget.username);
      //   break;

      // ─────────── الحسابات ───────────
      // case 'frm_ExpensesList':
      //   screen = ExpensesScreen(userId: widget.userId, username: widget.username);
      //   break;
      // case 'frm_Expenses':
      //   screen = AddExpenseScreen(username: widget.username);
      //   break;

      // ─────────── CRM ───────────
      // case 'frmCRM_Dashboard':
      //   screen = CrmDashboardScreen(userId: widget.userId, username: widget.username);
      //   break;
      // case 'frmDailyTasks':
      //   screen = TasksScreen(userId: widget.userId, username: widget.username);
      //   break;
      // case 'frmSalesPipeline':
      //   screen = OpportunitiesScreen(userId: widget.userId, username: widget.username);
      //   break;

      default:
        break;
    }

    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هذه الشاشة قيد التطوير 🛠️',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}