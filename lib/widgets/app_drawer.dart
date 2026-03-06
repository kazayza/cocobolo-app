import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/permission_service.dart';
import '../services/notification_service.dart';
import '../screens/login_screen.dart';
import '../screens/add_client_screen.dart';
import '../screens/add_opportunity_screen.dart';
import '../screens/products_screen.dart';
import '../screens/clients_screen.dart';
import '../screens/expenses_screen.dart';
import '../screens/add_expense_screen.dart';
import '../screens/reports/crm_dashboard_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/opportunities_screen.dart';
import '../screens/pipeline_screen.dart';
import '../screens/client_card_screen.dart';
import '../screens/pricing_margins_screen.dart';
import '../screens/price_requests_screen.dart';
import '../screens/crm_settings_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/employees_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/add_employee_screen.dart';
import '../screens/employee_shifts_screen.dart';
import '../screens/all_shifts_screen.dart';
import '../screens/my_schedule_screen.dart';
import '../screens/exemptions_screen.dart';
import '../screens/attendance_report_screen.dart';
import '../screens/permissions_list_screen.dart';
import '../screens/request_permission_screen.dart';
import '../screens/complaints_screen.dart';
import '../screens/delivery_tracking_screen.dart';
import '../screens/cashbox_transactions_screen.dart';
import '../screens/cashbox_manual_screen.dart';
import '../screens/cashbox_dashboard_screen.dart';

class AppDrawer extends StatefulWidget {
  final int userId;
  final String username;
  
  final String? fullName;
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.userId,
    required this.username,
    
    this.fullName,
    required this.currentRoute,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late final PermissionService _perms;
  late final List<MenuItem> _visibleItems;
  final Set<int> _expandedSections = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _perms = PermissionService();
    _cacheMenuItems();
    _searchController.addListener(_onSearchChanged);
    _loadAppVersion();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  void _cacheMenuItems() {
    _visibleItems = MenuStructure.getItems().where((item) {
      return item.children.any((sub) => _perms.canView(sub.formName));
    }).toList();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  List<MenuItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _visibleItems;
    return _visibleItems.where((item) {
      if (item.title.toLowerCase().contains(_searchQuery)) return true;
      return item.children.any((sub) =>
          sub.title.toLowerCase().contains(_searchQuery) &&
          _perms.canView(sub.formName));
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth * 0.78,
      child: Drawer(
        backgroundColor: const Color(0xFF0F0F0F),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(0)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildQuickActions(),
            _buildSearchField(),
            Expanded(
              child: _filteredItems.isEmpty
                  ? _buildEmptySearch()
                  : _buildMenuList(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D2006), Color(0xFF1A1A1A)],
        ),
      ),
      child: Column(
        children: [
          // Logo + Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'COCOBOLO',
                    style: GoogleFonts.cairo(
                      color: const Color(0xFFE8B923),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.close_rounded,
                      color: Colors.grey[500], size: 18),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // User Card
          _buildUserCard(),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    final roleColor = _getRoleColor();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [roleColor, roleColor.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: roleColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitials(),
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fullName ?? widget.username,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getRoleTitle(),
                    style: GoogleFonts.cairo(
                      color: roleColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.08, end: 0);
  }

  // ═══════════════════════════════════════════════════════════════
  // QUICK ACTIONS - Permission Based
  // ═══════════════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    final List<_QuickAction> actions = [];

    if (_perms.canAdd(FormNames.partiesAdd)) {
      actions.add(_QuickAction(
        icon: Icons.person_add_rounded,
        label: 'عميل',
        color: const Color(0xFF4CAF50),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddClientScreen(username: widget.username),
            ),
          );
        },
      ));
    }

    if (_perms.canAdd(FormNames.newInteraction) ||
        _perms.canView(FormNames.newInteraction)) {
      actions.add(_QuickAction(
        icon: Icons.lightbulb_outline,
        label: 'فرصة',
        color: const Color(0xFFFF9800),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddOpportunityScreen(
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          );
        },
      ));
    }

    if (_perms.canAdd(FormNames.expensesAdd)) {
      actions.add(_QuickAction(
        icon: Icons.receipt_long_rounded,
        label: 'مصروف',
        color: const Color(0xFFE91E63),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddExpenseScreen(username: widget.username),
            ),
          );
        },
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: actions.asMap().entries.map((entry) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: entry.key == 0 ? 0 : 8),
              child: _buildQuickActionButton(entry.value),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildQuickActionButton(_QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: action.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: action.color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(action.icon, color: action.color, size: 20),
            const SizedBox(height: 4),
            Text(
              '+ ${action.label}',
              style: GoogleFonts.cairo(
                color: action.color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
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
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'بحث في القائمة...',
          hintStyle: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 12),
          prefixIcon:
              Icon(Icons.search_rounded, color: Colors.grey[600], size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                  child: Icon(Icons.close_rounded,
                      color: Colors.grey[500], size: 16),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════════════
  // EMPTY SEARCH
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded,
                size: 36, color: Colors.grey[700]),
          ),
          const SizedBox(height: 14),
          Text(
            'لا توجد نتائج',
            style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'جرب كلمة بحث مختلفة',
            style: GoogleFonts.cairo(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MENU LIST
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMenuList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        return _buildSection(_filteredItems[index], index);
      },
    );
  }

  Widget _buildSection(MenuItem item, int index) {
    final visibleChildren = item.children.where((sub) {
      return _perms.canView(sub.formName) &&
          (_searchQuery.isEmpty ||
              sub.title.toLowerCase().contains(_searchQuery));
    }).toList();

    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedSections.contains(index) ||
        (_searchQuery.isNotEmpty && visibleChildren.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isExpanded
            ? item.color.withOpacity(0.04)
            : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? item.color.withOpacity(0.15)
              : Colors.white.withOpacity(0.03),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedSections.add(index);
              } else {
                _expandedSections.remove(index);
              }
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          title: Text(
            item.title,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isExpanded ? item.color : Colors.white,
            ),
          ),
          subtitle: Text(
            '${visibleChildren.length} عناصر',
            style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey[600]),
          ),
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: item.color, size: 16),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          children: visibleChildren
              .map((sub) => _buildSubItem(sub, item.color))
              .toList(),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 40 * index),
          duration: 300.ms,
        );
  }

  Widget _buildSubItem(SubMenuItem sub, Color sectionColor) {
    final isActive = widget.currentRoute == sub.formName;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          splashColor: sectionColor.withOpacity(0.1),
          highlightColor: sectionColor.withOpacity(0.05),
          onTap: () {
            Navigator.pop(context);
            _navigateToScreen(sub.formName);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? sectionColor.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? sectionColor.withOpacity(0.2)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isActive
                        ? sectionColor.withOpacity(0.15)
                        : sectionColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    sub.icon,
                    color: isActive
                        ? sectionColor
                        : sectionColor.withOpacity(0.6),
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sub.title,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? sectionColor : Colors.grey[400],
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: sectionColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: sectionColor.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  )
                else
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 10, color: Colors.grey[700]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FOOTER (Logout + Version)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Logout Button
            GestureDetector(
              onTap: _showLogoutDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded,
                        color: Colors.red[400], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'تسجيل الخروج',
                      style: GoogleFonts.cairo(
                        color: Colors.red[400],
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Version
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.code_rounded, size: 10, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text(
                  _appVersion.isNotEmpty ? 'v$_appVersion' : '...',
                  style: GoogleFonts.cairo(
                      fontSize: 10, color: Colors.grey[700]),
                ),
                if (_buildNumber.isNotEmpty)
                  Text(
                    ' ($_buildNumber)',
                    style: GoogleFonts.cairo(
                        fontSize: 9, color: Colors.grey[800]),
                  ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  '© ${DateTime.now().year}',
                  style: GoogleFonts.cairo(
                      fontSize: 9, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من تسجيل الخروج؟',
          style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء',
                style: GoogleFonts.cairo(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('خروج',
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    _perms.clear();
    NotificationService().stopPolling();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('fullName');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

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
    switch (_perms.role?.toLowerCase()) {
      case 'admin':
        return 'المدير العام';
      case 'SalesManager':
        return 'مدير المبيعات';
      case 'sales':
        return 'موظف مبيعات';
      case 'accountmanager':
        return 'مدير الحسابات';
      case 'account':
        return 'موظف حسابات';
      case 'warehouse':
        return 'أمين المخزن';
      case 'cashier':
        return 'أمين الخزينة';
      case 'social':
        return 'سوشيال ميديا';
      default:
        return 'مستخدم';
    }
  }

  Color _getRoleColor() {
    switch (_perms.role?.toLowerCase()) {
      case 'admin':
        return const Color(0xFFFFD700);
      case 'salesmanager':
        return const Color(0xFF4CAF50);
      case 'sales':
        return const Color(0xFF2196F3);
      case 'accountmanager':
        return const Color(0xFF9C27B0);
      case 'account':
        return const Color(0xFF00BCD4);
      case 'social':
        return const Color(0xFFFF6F61);
      default:
        return const Color(0xFF607D8B);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════

  void _navigateToScreen(String formName) {
    Widget? screen;

    switch (formName) {
      case 'frm_ProductList':
        screen = ProductsScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_PartiesList':
        screen = ClientsScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_PricingMargins':
        screen = PricingMarginsScreen(username: widget.username);
        break;
      case 'frm_PriceRequests':
        screen = PriceRequestsScreen(username: widget.username);
        break;
      case 'frm_ExpensesList':
        screen = ExpensesScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_Expenses':
        screen = AddExpenseScreen(username: widget.username);
        break;
      case 'frmCRM_Dashboard':
        screen = CrmDashboardScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frmDailyTasks':
        screen = TasksScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frmClientCard':
        screen = ClientCardScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frmManamgerSales':
        screen = OpportunitiesScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frmSalesPipeline':
        screen = PipelineScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frmNewInteraction':
        screen = AddOpportunityScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frmAdCampain':
        screen = CrmSettingsScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_Employeeslist':
        screen = EmployeesScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_empAttendance':
        screen = AttendanceScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_Employees':
        screen = AddEmployeeScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_EmpolyeeShifts':
        screen = EmployeeShiftsScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_AllShifts':
        screen = AllShiftsScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_MySchedule':
        screen = MyScheduleScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frmDailyExemptions':
        screen = ExemptionsScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'rpt_empAttendance':
        screen = AttendanceReportScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_MyPermissions':
    screen = PermissionsListScreen(userId: widget.userId,   );
    break;
    case 'frm_Complaints_Main':
      screen = ComplaintsScreen(userId: widget.userId,username: widget.username,);
      break;
      case 'frmInvoiceDeliveryStatus':
    screen = DeliveryTrackingScreen(
        userId: widget.userId,
        username: widget.username);
    break;
    case 'frm_CashBoxTransaction':
  screen = CashboxTransactionsScreen(
    userId: widget.userId, 
    username: widget.username
  );
  break;

case 'frm_CashBoxManual':
  screen = CashboxManualScreen(
    userId: widget.userId, 
    username: widget.username
  );
  break;
  case 'frm_CashBoxDashboard':
  screen = CashboxDashboardScreen(
    userId: widget.userId,
    username: widget.username,
  );
  break;
    }

    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.construction_rounded,
                  color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text('هذه الشاشة قيد التطوير',
                  style: GoogleFonts.cairo(fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF2A2A2A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// QUICK ACTION DATA
// ═══════════════════════════════════════════════════════════════

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}