import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/permission_service.dart';
import '../services/notification_service.dart';
import '../services/app_colors.dart';
import '../features/home/widgets/profile_avatar.dart';
import '../screens/login_screen.dart';
import '../services/update_service.dart';
import '../core/auth/session_service.dart';
import '../providers/auth_provider.dart';
import '../screens/add_client_screen.dart';
import '../screens/add_opportunity_screen.dart';
import '../screens/products_screen.dart';
import '../screens/price_list_screen.dart';
import '../screens/quotations_screen.dart';
import '../screens/job_orders_screen.dart';
import '../screens/clients_screen.dart';
import '../screens/expenses/expense_dashboard_screen.dart';
import '../screens/expenses/expense_groups_screen.dart';
import '../screens/personal_accounts/personal_accounts_screen.dart';
import '../screens/add_expense_screen.dart';
import '../screens/reports/crm_dashboard_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/opportunities_screen.dart';
import '../screens/closure_approval_requests_screen.dart'
    show ClosureApprovalRequestsScreen;
import '../screens/general_tasks_screen.dart';
import '../screens/lost_recovery_screen.dart';
import '../screens/lost_recovery_report_screen.dart';
import '../screens/invoice/invoices_list_screen.dart';
import '../screens/invoice/add_invoice_screen.dart';
import '../screens/factory_purchases_screen.dart';
import '../screens/factory_purchase_form_screen.dart';
import '../screens/inventory/stock_transactions_screen.dart';
import '../screens/inventory/stock_levels_screen.dart';
import '../screens/inventory/warehouses_screen.dart';
import '../screens/inventory/stock_transfer_screen.dart';
import '../screens/inventory/stock_entry_screen.dart';
import '../screens/inventory/stock_value_screen.dart';
import '../screens/inventory/stock_count_screen.dart';
import '../screens/pipeline_screen.dart';
import '../screens/client_card_screen.dart';
import '../screens/pricing_margins_screen.dart';
import '../screens/price_requests_screen.dart';
import '../screens/crm_settings_screen.dart';
import '../screens/employees_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/add_employee_screen.dart';
import '../screens/employee_shifts_screen.dart';
import '../screens/all_shifts_screen.dart';
import '../screens/my_schedule_screen.dart';
import '../screens/exemptions_screen.dart';
import '../screens/attendance_report_screen.dart';
import '../screens/permissions_list_screen.dart';
import '../screens/complaints_screen.dart';
import '../screens/delivery_tracking_screen.dart';
import '../screens/purchase_receipts_screen.dart';
import '../screens/additional_charges_screen.dart';
import '../screens/customer_care_screen.dart';
import '../screens/customer_care_history_screen.dart';
import '../screens/executive_cockpit_screen.dart';
import '../screens/cashbox_transactions_screen.dart';
import '../screens/cashbox_manual_screen.dart';
import '../screens/cashbox/cashbox_dashboard_screen.dart';
import '../screens/leads_screen.dart';
import '../screens/followups_screen.dart';
import '../screens/admin/users_admin_screen.dart';
import '../screens/admin/broadcast_notification_screen.dart';
import '../screens/admin/user_form_screen.dart';

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

  /// الأقسام التي تُعرض بعلامة "جديد" مرة واحدة فقط لكل مستخدم.
  static const Set<String> _highlightedSections = <String>{
    'قائمة الأسعار',
  };
  static const String _seenNewKey = 'drawer_seen_new_sections';

  /// الأقسام التي لم يشاهدها المستخدم بعد (تُحمّل من التخزين المحلي).
  final Set<String> _unseenNewSections = <String>{};

  @override
  void initState() {
    super.initState();
    _perms = PermissionService();
    _cacheMenuItems();
    _searchController.addListener(_onSearchChanged);
    _loadAppVersion();
    _loadUnseenNewSections();
  }

  /// قراءة الأقسام الجديدة غير المُشاهدة من SharedPreferences.
  Future<void> _loadUnseenNewSections() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenNewKey) ?? const <String>[];
    final unseen = _highlightedSections
        .where((String title) => !seen.contains(title))
        .toSet();
    if (!mounted || unseen.isEmpty) return;
    setState(() {
      _unseenNewSections
        ..clear()
        ..addAll(unseen);
    });
  }

  /// حفظ القسم كمُشاهد عند توسيعه.
  Future<void> _markSectionSeen(String title) async {
    if (!_unseenNewSections.contains(title)) return;
    setState(() {
      _unseenNewSections.remove(title);
    });
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenNewKey) ?? <String>[];
    if (!seen.contains(title)) {
      seen.add(title);
      await prefs.setStringList(_seenNewKey, seen);
    }
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
    _visibleItems = MenuStructure.getItems()
        .map((item) {
          final kids = item.children
              .where((sub) => sub.isHeader || _canViewMenu(sub.formName))
              .toList();
          return MenuItem(
            title: item.title,
            icon: item.icon,
            color: item.color,
            children: kids,
          );
        })
        .where((item) => item.children.isNotEmpty)
        .toList();
  }

  bool _canViewMenu(String formName) {
    final perms = PermissionService();
    if (formName == 'frmCrmTasksLegacy') {
      // Legacy CRM tasks list: same audience as daily tasks / opportunities
      return perms.canView(FormNames.dailyTasks) ||
          perms.canView(FormNames.managerSales) ||
          perms.isAdmin ||
          perms.isSalesManager;
    }
    // My Leads uses same permission as leads list (Blazor /crm/leads/my)
    if (formName == FormNames.myLeads || formName == 'frm_MyLeads') {
      return perms.canView(FormNames.leadsCrm) ||
          perms.isSales ||
          perms.isSalesManager ||
          perms.isAdmin ||
          perms.isGeneralManager;
    }
    // مؤشر المصروفات / المجموعات / تقرير المصروفات:
    // نفس جمهور "كافة المصروفات" — أي حد يشوف المصروفات يشوفهم
    if (formName == FormNames.expensesDashboard ||
        formName == FormNames.expenseTree ||
        formName == FormNames.expensesFilter) {
      return perms.isAdmin ||
          perms.canView(FormNames.expensesList) ||
          perms.canView(FormNames.expensesAdd);
    }
    if (formName == FormNames.priceList) {
      return perms.canViewPriceList;
    }
    if (formName == FormNames.quotationsList ||
        formName == FormNames.newQuotation) {
      return perms.canViewQuotations;
    }
    if (formName == FormNames.jobOrders) {
      return perms.canViewJobOrders;
    }
    if (formName == FormNames.supplierInvoices) {
      return perms.canViewFactoryPurchases;
    }
    if (formName == FormNames.executiveCockpit) {
      return perms.canViewExecutiveCockpit;
    }
    if (formName == FormNames.invoiceDeliveryStatus) {
      return perms.canViewDelivery;
    }
    if (formName == FormNames.purchaseReceiptStatus) {
      return perms.canViewPurchaseReceipts;
    }
    if (formName == FormNames.additionalCharges) {
      return perms.canViewAdditionalCharges;
    }

    // الحسابات الشخصية: الادمن + مدير الحسابات فقط.
    if (formName == FormNames.personalAccounts) {
      return perms.isAdmin || perms.isAccountManager;
    }

    // المخازن: نفس قواعد العرض في Blazor حتى لو لم تُضف الصلاحيات الجديدة للمستخدم بعد.
    if (formName == FormNames.stockEntry ||
        formName == FormNames.stockTransfer ||
        formName == FormNames.stockTransactions ||
        formName == FormNames.stockLevels) {
      return perms.isAdmin ||
          perms.isGeneralManager ||
          perms.isAccountManager ||
          perms.isProductionManager ||
          perms.isFactory ||
          perms.isWarehouse ||
          perms.canView(formName);
    }
    if (formName == FormNames.warehouses) {
      return perms.isAdmin || perms.canView(formName);
    }
    if (formName == FormNames.stockCount) {
      return perms.isAdmin || perms.canView(formName);
    }
    if (formName == FormNames.stockValue) {
      return perms.isAdmin || perms.isAccountManager || perms.canView(formName);
    }

    // الاسترداد والتكليفات تظهر حسب Policy الأدوار وليس Claim العرض فقط.
    if (formName == FormNames.lostRecovery ||
        formName == FormNames.lostRecoveryReport) {
      return perms.canViewLostRecovery;
    }
    if (formName == FormNames.customerCare ||
        formName == FormNames.customerCareHistory) {
      return perms.canViewCustomerCare;
    }
    if (formName == FormNames.generalTasks) {
      return perms.isAdmin ||
          perms.isGeneralManager ||
          perms.isAccountManager ||
          perms.canView(formName);
    }

    return perms.canView(formName);
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
      return item.children.any(
        (sub) =>
            sub.title.toLowerCase().contains(_searchQuery) &&
            _canViewMenu(sub.formName),
      );
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0D1A2A)
            : Colors.white,
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
            _buildUpdateCheckTile(),
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
          colors: const [
            AppColors.navyDark,
            AppColors.navy,
            AppColors.navyLight,
          ],
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
                      color: AppColors.gold,
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
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.neutral,
                    size: 18,
                  ),
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
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.navy.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          // Avatar (صورة المستخدم أو الحرف)
          ProfileAvatar(initial: _getInitials(), size: 44, circle: true),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fullName ?? widget.username,
                  style: GoogleFonts.cairo(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
      actions.add(
        _QuickAction(
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
        ),
      );
    }

    if (_perms.canAdd(FormNames.newInteraction) ||
        _perms.canView(FormNames.newInteraction)) {
      actions.add(
        _QuickAction(
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
        ),
      );
    }

    if (_perms.canAdd(FormNames.expensesAdd)) {
      actions.add(
        _QuickAction(
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
        ),
      );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.inputFill(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.divider(isDark).withValues(alpha: 0.4),
        ),
      ),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        style: GoogleFonts.cairo(
          color: AppColors.text(isDark),
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: 'بحث في القائمة...',
          hintStyle: GoogleFonts.cairo(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(
                        Icons.close_rounded,
                        color: AppColors.neutral,
                        size: 20,
                      ),
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
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
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 36,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'لا توجد نتائج',
            style: GoogleFonts.cairo(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'جرب كلمة بحث مختلفة',
            style: GoogleFonts.cairo(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 12,
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visibleChildren = item.children.where((sub) {
      if (sub.isHeader) return _searchQuery.isEmpty;
      return _canViewMenu(sub.formName) &&
          (_searchQuery.isEmpty ||
              sub.title.toLowerCase().contains(_searchQuery));
    }).toList();

    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedSections.contains(index) ||
        (_searchQuery.isNotEmpty && visibleChildren.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isExpanded
            ? item.color.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? item.color.withValues(alpha: 0.20)
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.4),
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
            if (expanded) _markSectionSeen(item.title);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              if (_unseenNewSections.contains(item.title))
                Positioned(
                  top: -3,
                  left: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'جديد',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            item.title,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isExpanded ? item.color : AppColors.text(isDark),
            ),
          ),
          subtitle: Text(
            '${visibleChildren.where((SubMenuItem sub) => !sub.isHeader).length} عناصر',
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: AppColors.textSecondary(isDark),
            ),
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
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: item.color,
                size: 16,
              ),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          children: visibleChildren
              .map((sub) => _buildSubItem(sub, item.color))
              .toList(),
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 40 * index),
          duration: 300.ms,
        );
  }

  Widget _buildSubItem(SubMenuItem sub, Color sectionColor) {
    // عنوان تجميع: يظهر كنص فاصل وليس عنصراً قابلاً للنقر.
    if (sub.isHeader) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4, right: 12, left: 12),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 13,
              decoration: BoxDecoration(
                color: sectionColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sub.title,
                style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary(isDark),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                    color:
                        isActive ? sectionColor : sectionColor.withOpacity(0.6),
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sub.title,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? sectionColor
                          : Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF334155),
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
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔄 البحث عن التحديثات
  // ═══════════════════════════════════════════════════════════════

  Widget _buildUpdateCheckTile() {
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.system_update_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: 20,
      ),
      title: Text(
        'البحث عن التحديثات',
        style: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _appVersion.isNotEmpty
            ? 'الإصدار الحالي: v$_appVersion'
            : 'تحقق من وجود نسخة أحدث',
        style: GoogleFonts.cairo(fontSize: 10),
      ),
      onTap: () async {
        try {
          final info = await UpdateService.checkForUpdate();
          if (!mounted) return;
          if (info != null && info['hasUpdate'] == true) {
            await UpdateService.showUpdateDialog(
                context: context, updateInfo: info);
          } else {
            // مفيش تحديث → رسالة مطمئنة
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'أنت على أحدث إصدار ✅',
                  style: GoogleFonts.cairo(),
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('تعذر التحقق من التحديثات', style: GoogleFonts.cairo()),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
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
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
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
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تسجيل الخروج',
                      style: GoogleFonts.cairo(
                        color: AppColors.error,
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
                Icon(
                  Icons.code_rounded,
                  size: 10,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  _appVersion.isNotEmpty ? 'v$_appVersion' : '...',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                if (_buildNumber.isNotEmpty)
                  Text(
                    ' ($_buildNumber)',
                    style: GoogleFonts.cairo(
                      fontSize: 9,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  '© ${DateTime.now().year}',
                  style: GoogleFonts.cairo(
                    fontSize: 9,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF13273F)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.cairo(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من تسجيل الخروج؟',
          style: GoogleFonts.cairo(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'خروج',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    _perms.clear();
    AuthProvider().clear();
    NotificationService().stopPolling();
    await SessionService.instance.clear();

    final prefs = await SharedPreferences.getInstance();
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
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_PriceList':
      case 'products/price-list':
      case 'sales/price-list':
        screen = PriceListScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmQuotationsList':
      case 'frmNewQuotation':
      case 'quotations':
      case 'sales/quotations':
        screen = QuotationsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_JobOrders':
      case 'production/job-orders':
      case 'factory/job-orders':
        screen = JobOrdersScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_StockLevels':
      case 'inventory/stock-levels':
      case 'inventory/movements':
        screen = StockLevelsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_StockTransactions':
      case 'inventory/transactions':
        screen = StockTransactionsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_Warehouses':
      case 'inventory/warehouses':
        screen =
            WarehousesScreen(userId: widget.userId, username: widget.username);
        break;
      case 'frm_StockTransfer':
      case 'inventory/transfer':
      case 'inventory/warehouse-transfer':
        screen = StockTransferScreen(
            userId: widget.userId, username: widget.username);
        break;
      case 'frm_StockEntry':
      case 'inventory/stock-entry':
      case 'inventory/opening-balance':
        screen =
            StockEntryScreen(userId: widget.userId, username: widget.username);
        break;
      case 'frm_StockValue':
      case 'inventory/stock-value':
        screen =
            StockValueScreen(userId: widget.userId, username: widget.username);
        break;
      case 'frm_StockCount':
      case 'inventory/count':
      case 'inventory/stock-count':
        screen =
            StockCountScreen(userId: widget.userId, username: widget.username);
        break;
      case 'frm_PartiesList':
        screen = ClientsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_PricingMargins':
        screen = PricingMarginsScreen(username: widget.username);
        break;
      case 'frm_PriceRequests':
        screen = PriceRequestsScreen(username: widget.username);
        break;
      case 'frm_ExpensesList':
        screen = ExpenseDashboardScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_Expenses':
        screen = AddExpenseScreen(username: widget.username);
        break;
      case 'frmExpensesDashboard':
        // مؤشر المصروفات (الداشبورد الجديد)
        screen = ExpenseDashboardScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmExpenseTree':
        // مجموعات المصروفات
        screen = ExpenseGroupsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmExpensesFilter':
        // تقرير المصروفات → الداشبورد (فيه كل التفاصيل)
        screen = ExpenseDashboardScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmPersonalAccounts':
        // الحسابات الشخصية (ادمن + مدير حسابات فقط)
        screen = PersonalAccountsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_ExecutiveCockpit':
        screen = ExecutiveCockpitScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmCRM_Dashboard':
        screen = CrmDashboardScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmDailyTasks':
        // Unified follow-ups (Leads + CRM + Tasks) — Blazor daily tasks entry
        screen = FollowUpsScreen(
          userId: widget.userId,
          username: widget.username,
          employeeId: (PermissionService().isAdmin ||
                  PermissionService().isSalesManager ||
                  PermissionService().isGeneralManager)
              ? null
              : PermissionService().employeeId,
        );
        break;
      case 'frmCrmTasksLegacy':
        screen = TasksScreen(userId: widget.userId, username: widget.username);
        break;
      case 'frm_MyLeads':
        screen = LeadsScreen(
          userId: widget.userId,
          username: widget.username,
          myLeadsOnly: true,
          title: 'My Leads',
        );
        break;
      case 'frmClientCard':
        screen = ClientCardScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmManamgerSales':
        screen = OpportunitiesScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_ClosureApprovalRequests':
        screen = ClosureApprovalRequestsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_LostRecovery':
      case 'crm/lost-recovery':
        screen = LostRecoveryScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_LostRecoveryReport':
      case 'crm/lost-recovery/report':
        screen = LostRecoveryReportScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'crm/general-tasks':
      case 'frm_GeneralTasks':
        screen = GeneralTasksScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmSalesPipeline':
        screen = PipelineScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmNewInteraction':
        screen = AddOpportunityScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmAdCampain':
        screen = CrmSettingsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_LeadsCRM':
        screen = LeadsScreen(userId: widget.userId, username: widget.username);
        break;
      case 'frm_Employeeslist':
        screen = EmployeesScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_empAttendance':
        screen = AttendanceScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_Employees':
        screen = AddEmployeeScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_EmpolyeeShifts':
        screen = EmployeeShiftsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_AllShifts':
        screen = AllShiftsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_MySchedule':
        screen = MyScheduleScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmDailyExemptions':
        screen = ExemptionsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'rpt_empAttendance':
        screen = AttendanceReportScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_MyPermissions':
        screen = PermissionsListScreen(userId: widget.userId);
        break;
      case 'frm_Complaints_Main':
        screen = ComplaintsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_CustomerCare':
        screen = CustomerCareScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_CustomerCare_History':
        screen = CustomerCareHistoryScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmInvoiceDeliveryStatus':
        screen = DeliveryTrackingScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_PurchaseReceiptStatus':
        screen = PurchaseReceiptsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmInspectionCharge':
        screen = AdditionalChargesScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_CashBoxTransaction':
        screen = CashboxTransactionsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;

      case 'frm_CashBoxManual':
        screen = CashboxManualScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_CashBoxDashboard':
        screen = CashBoxDashboardScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;

      // ── إدارة المستخدمين والصلاحيات ───────────────────
      case 'frm_PartiesInvoices':
        screen = SalesInvoicesScreen(
          userId: widget.userId,
          username: widget.username,
          initialTab: 'Sale',
        );
        break;
      case 'frm_SupplierInvoices':
      case 'factory/purchases':
        screen = FactoryPurchasesScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'factory/purchases/new':
        screen = FactoryPurchaseFormScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_SalesInvoiveNew':
      case 'sales/invoices/new':
        screen = AddInvoiceScreen(
            userId: widget.userId,
            username: widget.username,
            initialType: 'Sale');
        break;
      case 'frm_AllUsers':
        screen = UsersAdminScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      // 📢 بث إشعار عام (خاص بالأدمن — مش بيظهر لغير الأدمن)
      case 'frm_BroadcastNotification':
        screen = BroadcastNotificationScreen(
          username: widget.username,
        );
        break;
      case 'frm_AddUser':
        screen = UserFormScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frmManagePermissions':
        screen = UsersAdminScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_AddPermission':
        screen = UserFormScreen(
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
              const Icon(
                Icons.construction_rounded,
                color: AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'هذه الشاشة قيد التطوير',
                style: GoogleFonts.cairo(fontSize: 13),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2A2A2A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
  final dynamic icon;
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
