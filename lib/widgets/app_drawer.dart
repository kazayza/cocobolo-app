import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/permission_service.dart';
import '../services/notification_service.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import 'design_kit.dart';
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
import '../screens/shifts_management_screen.dart';
import '../screens/penalties_screen.dart';
import '../screens/my_schedule_screen.dart';
import '../screens/exemptions_screen.dart';
import '../screens/attendance_report_screen.dart';
import '../screens/permissions_list_screen.dart';
import '../screens/complaints_screen.dart';
import '../screens/hr/payroll_list_screen.dart';
import '../screens/hr/my_payslips_screen.dart';
import '../screens/hr/loans_screen.dart';
import '../screens/hr/hr_dashboard_screen.dart';
import '../screens/hr/off_payroll_screen.dart';
import '../screens/delivery_tracking_screen.dart';
import '../screens/delivery_maintenance_screen.dart';
import '../screens/purchase_receipts_screen.dart';
import '../screens/additional_charges_screen.dart';
import '../screens/customer_care_screen.dart';
import '../screens/customer_care_history_screen.dart';
import '../screens/executive_cockpit_screen.dart';
import '../screens/cashbox_transactions_screen.dart';
import '../screens/cashbox_manual_screen.dart';
import '../screens/cashbox_summary_screen.dart';
import '../screens/cashbox_review_screen.dart';
import '../screens/financial_reports_screen.dart';
import '../screens/payments_screen.dart';
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

/// درج جاهز لأي شاشة رئيسية — يقرأ بيانات المستخدم من جلسة الدخول
/// الحالية (نفس ما تمرره الرئيسية يدويًا) حتى لا تحتاج كل شاشة لتمريرها.
AppDrawer buildAppDrawer({required String currentRoute}) {
  final auth = AuthProvider();
  return AppDrawer(
    userId: auth.userId ?? 0,
    username: auth.username ?? '',
    fullName: auth.fullName,
    currentRoute: currentRoute,
  );
}

/// زر فتح القائمة الجانبية الموحد — يوضع في `leading` شريط عنوان أي
/// شاشة رئيسية (وجهة من وجهات الدرج نفسه) ليصل المستخدم للقائمة
/// بضغطة واحدة من أي مكان.
class AppDrawerMenuButton extends StatelessWidget {
  final Color? color;

  const AppDrawerMenuButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.menu_rounded, color: color),
      tooltip: 'القائمة',
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
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
    // الأقسام مطوية عند فتح الدرج؛ يُفتح فقط قسم الشاشة الحالية —
    // يُزرع فهرسه وحده في مجموعة التوسيع قبل أول بناء فيقرأه
    // ExpansionTile عبر initiallyExpanded، ويبقى الفتح/الطي
    // اليدوي داخل الجلسة عبر onExpansionChanged كما كان.
    _seedCurrentSection();
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
    setState(() => _searchQuery = _normalizeArabic(_searchController.text));
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

  /// هل ينتمي مسار الشاشة الحالية إلى عنصر القائمة هذا؟ العناصر
  /// التي تستضيف شاشات موحّدة تملك أيضًا مسارات الشاشات التي
  /// حلّت محلها (إدارة الشيفتات تستضيف المتابعة وشيفتات الموظفين،
  /// وقائمة الموظفين تستضيف إضافة موظف بعد حذف مدخلها المنفصل).
  bool _routeBelongsToItem(String itemFormName, String route) {
    if (itemFormName == route) return true;
    if (itemFormName == FormNames.shiftsManagement) {
      return route == FormNames.employeeShifts || route == FormNames.allShifts;
    }
    if (itemFormName == FormNames.employeesList) {
      return route == FormNames.employeesAdd;
    }
    return false;
  }

  /// زرع قسم الشاشة الحالية وحده في مجموعة التوسيع عند فتح الدرج؛
  /// بلا مطابقة تبقى كل الأقسام مطوية.
  void _seedCurrentSection() {
    for (var i = 0; i < _visibleItems.length; i++) {
      final ownsCurrent = _visibleItems[i].children.any(
            (sub) =>
                !sub.isHeader &&
                _routeBelongsToItem(sub.formName, widget.currentRoute),
          );
      if (ownsCurrent) {
        _expandedSections.add(i);
        break;
      }
    }
  }

  bool _canViewMenu(String formName) {
    final perms = PermissionService();
    // HR — بوابات مرآة لصفحات بلازور لكل وحدة (لا كتلة أدوار واحدة):
    // الكتلة القديمة كانت تحجب الرواتب والسلف وخارج الراتب واللوحة
    // كليًا عن دور «المحاسب» (Accountant) وعن صيغة «AccountsManager»
    // وعن كل حامل مطالبة، لأنها لم تعرف إلا مدير الحسابات بصيغته
    // الأولى ولم تسأل عن المطالبات إطلاقًا.
    if (formName == FormNames.payrollList) {
      // سجل المرتبات: عائلة بلازور كاملة (تشمل المحاسب) أو المطالبة،
      // ويبقى المدير العام ظاهرًا له كما استقر في التطبيق.
      return perms.canViewPayrollModule ||
          perms.canSeeAllHR ||
          perms.isGeneralManager;
    }
    if (formName == FormNames.payslip) {
      // قسيمتي: خدمة ذاتية — كل حساب مرتبط بموظف يرى قسائمه،
      // ومديرو الرواتب يرون الكل (الشاشة والخادم يفرضان النطاق).
      return perms.canViewPayrollModule ||
          perms.canSeeAllHR ||
          perms.isGeneralManager ||
          perms.employeeId != null;
    }
    if (formName == FormNames.loansPage) {
      // السلف: مطالبتها frmEmployeeLoans:View (بوابة بلازور الوحيدة)
      // مع بقاء ظهورها لمديري الموارد/الحسابات كما هو مستقر.
      return perms.canViewLoansModule ||
          perms.canSeeAllHR ||
          perms.isAdmin ||
          perms.isAccountManager ||
          perms.isGeneralManager;
    }
    if (formName == FormNames.hrDashboard) {
      return perms.canViewHrDashboard ||
          perms.canSeeAllHR ||
          perms.isAdmin ||
          perms.isAccountManager;
    }
    if (formName == FormNames.offPayroll) {
      return perms.canEnterOffPayrollModule ||
          perms.canSeeAllHR ||
          perms.isGeneralManager;
    }
    if (formName == FormNames.dailyExemptions) {
      // الاستثناءات: مديروها أو حامل المطالبة أو الموظف المرتبط
      // (نطاقه هو فقط) — مرآة صفحتي بلازور معًا.
      return perms.canViewExemptions;
    }
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
    // التقارير المالية: بوابات بلازور الحقيقية للقوائم الثلاث
    // (frmIncomeStatement / frm_CashFlowNew / frmCashBoxDashboard /
    // rpt_IncomeStatement) — الأسماء القديمة هنا كانت مخترعة وغير قابلة للمنح.
    if (formName == FormNames.financialReports) {
      return perms.isAdmin ||
          perms.isAccountManager ||
          perms.canView('frmIncomeStatement') ||
          perms.canView('frm_CashFlowNew') ||
          perms.canView('rpt_IncomeStatement') ||
          perms.canView(FormNames.cashBoxDashboard);
    }
    // ملخص الخزينة: نفس جمهور مؤشرات/حركات الخزينة
    if (formName == FormNames.cashBoxSummary) {
      return perms.isAdmin ||
          perms.isAccountManager ||
          perms.canView(FormNames.cashBoxDashboard) ||
          perms.canView(FormNames.cashBoxTransaction);
    }
    // مراجعة الخزينة: مطابقة لبوابة الخادم (Item 27)
    if (formName == FormNames.cashBoxReview) {
      return perms.isAdmin ||
          perms.isAccountManager ||
          perms.isAccount ||
          perms.canView('frmCashBoxReview');
    }
    if (formName == FormNames.invoiceDeliveryStatus) {
      return perms.canViewDelivery;
    }
    // صيانة التسليمات: مطابقة لبوابة الخادم (canViewMaintenance)
    if (formName == FormNames.deliveryMaintenance) {
      return perms.isAdmin ||
          perms.isAccountManager ||
          perms.isProductionManager ||
          perms.isFactoryManager ||
          perms.isDeliveryOfficer ||
          perms.canView(formName);
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

    // إدارة الشيفتات الموحّدة: نفس جمهور المدخلين القديمين معًا —
    // تظهر لمن كان يرى «شيفتات الموظفين» أو «متابعة الشيفتات».
    // الجزاءات: بوابة مركّبة على نمط مداخل HR الجديدة — مطالبة
    // الشاشة الجديدة أو توقيع مباشر أو أحد أدوار الإدارة ذات الصلة،
    // حتى لا يختفي المدخل عن المديرين قبل زرع المطالبات؛ الخادم
    // يحدّد نطاق القائمة ويفرض الإنشاء/الاعتماد فعليًا.
    if (formName == FormNames.employeePenalties) {
      return perms.canViewPenalties;
    }

    if (formName == FormNames.shiftsManagement) {
      return perms.canView(FormNames.employeeShifts) ||
          perms.canView(FormNames.allShifts);
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

  /// تطبيع عربي موحّد لبحث القائمة — نفس خوارزمية بحث قائمة الأسعار
  /// في التطبيق: حذف التشكيل والتطويل، توحيد الألف (أإآ←ا) والهاء
  /// (ة←ه) والياء (ى←ي)، حتى يجد البحث العناوين مهما اختلف الإملاء
  /// (مثال: «فواتير» تجد «الفواتير»، و«الاسعار» تجد «الأسعار»).
  static String _normalizeArabic(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9]'), '');
  }

  List<MenuItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _visibleItems;
    return _visibleItems.where((item) {
      if (_normalizeArabic(item.title).contains(_searchQuery)) return true;
      return item.children.any(
        (sub) =>
            !sub.isHeader &&
            _normalizeArabic(sub.title).contains(_searchQuery) &&
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
            ? AppColors.navyDark
            : AppColors.lightSurface,
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
          colors: AppGradients.identityHeader,
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
                    color: AppColors.text(
                      Theme.of(context).brightness == Brightness.dark,
                    ),
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
          color: AppColors.gold,
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
          color: AppColors.gold,
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
          color: AppColors.gold,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                color: isDark ? action.color : AppColors.goldDark,
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
    return const AppEmpty(
      message: 'لا توجد نتائج',
      hint: 'جرّب كلمة بحث مختلفة',
      icon: Icons.search_off_rounded,
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
    final searching = _searchQuery.isNotEmpty;
    // مطابقة عنوان القسم نفسه تجلب كل عناصره (وليس المطابقة فقط).
    final titleMatches =
        searching && _normalizeArabic(item.title).contains(_searchQuery);

    final visibleChildren = item.children.where((sub) {
      if (sub.isHeader) return !searching || titleMatches;
      if (!_canViewMenu(sub.formName)) return false;
      if (!searching || titleMatches) return true;
      return _normalizeArabic(sub.title).contains(_searchQuery);
    }).toList();

    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    final isExpanded = _expandedSections.contains(index) ||
        (_searchQuery.isNotEmpty && visibleChildren.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isExpanded
            ? AppColors.gold.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? AppColors.gold.withValues(alpha: 0.20)
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // المفتاح يتغيّر عند الدخول/الخروج من وضع البحث حتى تُعاد
          // تهيئة البلاطة وتُقرأ initiallyExpanded من جديد — فتظهر
          // الأقسام المطابقة مفتوحة أثناء البحث كما في V2.
          key: ValueKey<String>(
            'drawer-section-${item.title}-$searching',
          ),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            // أثناء البحث تكون فهارس القائمة المُصفّاة غير فهارس
            // القائمة الكاملة؛ لا نكتبها في مجموعة التوسيع حتى لا
            // تتلوّث حالة أقسام أخرى بعد مسح البحث.
            if (searching) return;
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
                  color: isExpanded
                      ? AppColors.gold.withValues(alpha: 0.12)
                      : AppColors.textSecondary(
                          isDark,
                        ).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  color: isExpanded
                      ? AppColors.gold
                      : AppColors.textSecondary(isDark),
                  size: 18,
                ),
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
              color: isExpanded
                  ? (isDark ? AppColors.gold : AppColors.goldDark)
                  : AppColors.text(isDark),
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
                color: isExpanded
                    ? AppColors.gold.withValues(alpha: 0.12)
                    : AppColors.textSecondary(isDark).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isExpanded
                    ? AppColors.gold
                    : AppColors.textSecondary(isDark),
                size: 16,
              ),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          children: visibleChildren
              .map((sub) => _buildSubItem(sub, AppColors.gold))
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

    final isActive = _routeBelongsToItem(sub.formName, widget.currentRoute);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        : AppColors.textSecondary(
                            isDark,
                          ).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    sub.icon,
                    color: isActive
                        ? sectionColor
                        : AppColors.textSecondary(isDark),
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
                          ? (isDark ? sectionColor : AppColors.goldDark)
                          : AppColors.textSecondary(isDark),
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
            ? AppColors.navy
            : AppColors.lightSurface,
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

  // لون شارة الدور في الترويسة: ذهبي الهوية لجميع الأدوار (الشارة فوق
  // تدرّج كحلي في الوضعين، فالذهبي يعمل في النهاري والليلي معًا).
  Color _getRoleColor() {
    return AppColors.gold;
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
      case 'frm_FinancialReports':
        screen = FinancialReportsScreen(
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
      case 'frm_ShiftsManagement':
        screen = ShiftsManagementScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_EmployeePenalties':
        screen = PenaltiesScreen(
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
      case 'frm_PayrollList':
        screen = PayrollListScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_Payslip':
        screen = MyPayslipsScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_LoansPage':
        screen = LoansScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_HRDashboard':
        screen = HrDashboardScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_OffPayroll':
      case 'frm_PayrollPayment':
        screen = OffPayrollScreen(
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
      case 'frmDeliveryMaintenance':
        screen = DeliveryMaintenanceScreen(
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
      case 'frmCashBoxSummary':
        screen = CashboxSummaryScreen(username: widget.username);
        break;
      case 'frmCashBoxReview':
        screen = CashboxReviewScreen(username: widget.username);
        break;
      case 'frmCashBoxDashboard':
        screen = CashBoxDashboardScreen(
          userId: widget.userId,
          username: widget.username,
        );
        break;
      case 'frm_Payments':
        screen = PaymentsScreen(
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
          backgroundColor: AppColors.navyDark,
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
