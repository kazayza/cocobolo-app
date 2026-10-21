import 'package:flutter/material.dart';

import 'app_colors.dart';

class Permission {
  final int permissionId;
  final String permissionName;
  final String formName;
  final String category;
  final bool canView;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;

  Permission({
    required this.permissionId,
    required this.permissionName,
    required this.formName,
    required this.category,
    required this.canView,
    required this.canAdd,
    required this.canEdit,
    required this.canDelete,
  });

  factory Permission.fromJson(String formName, Map<String, dynamic> json) {
    return Permission(
      permissionId: json['permissionId'] ?? 0,
      permissionName: json['permissionName'] ?? '',
      formName: formName,
      category: json['category'] ?? '',
      canView: json['canView'] == true || json['canView'] == 1,
      canAdd: json['canAdd'] == true || json['canAdd'] == 1,
      canEdit: json['canEdit'] == true || json['canEdit'] == 1,
      canDelete: json['canDelete'] == true || json['canDelete'] == 1,
    );
  }
}

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // بيانات المستخدم
  int? userId;
  String? username;
  String? fullName;
  String? email;
  int? employeeId;
  String? role;

  // الصلاحيات + Claims كاملة من الـAPI
  final Map<String, Permission> _permissions = {};
  final Set<String> _claims = {};

  // ✅ تهيئة الصلاحيات بعد تسجيل الدخول
  void initialize({
    required Map<String, dynamic> user,
    required Map<String, dynamic> permissions,
    List<dynamic> claims = const [],
  }) {
    // حفظ بيانات المستخدم
    userId = user['UserID'];
    username = user['Username'];
    fullName = user['FullName'];
    email = user['Email'];
    employeeId = user['employeeID'];
    role = user['Role'];

    // حفظ الصلاحيات
    _permissions.clear();
    permissions.forEach((formName, permData) {
      _permissions[formName] = Permission.fromJson(
        formName,
        permData as Map<String, dynamic>,
      );
    });
    _claims
      ..clear()
      ..addAll(claims.map((e) => e.toString()));

    // توافق مع API أقدم: نولّد Claims القياسية من الأربع صلاحيات.
    _permissions.forEach((formName, permission) {
      if (permission.canView) _claims.add('$formName:View');
      if (permission.canAdd) _claims.add('$formName:Add');
      if (permission.canEdit) _claims.add('$formName:Edit');
      if (permission.canDelete) _claims.add('$formName:Delete');
    });

    print(
        '✅ تم تحميل ${_permissions.length} صلاحية و${_claims.length} claim للمستخدم $username');
  }

  // ✅ مسح البيانات عند تسجيل الخروج
  void clear() {
    userId = null;
    username = null;
    fullName = null;
    email = null;
    employeeId = null;
    role = null;
    _permissions.clear();
    _claims.clear();
    print('🚪 تم مسح بيانات المستخدم والصلاحيات');
  }

  // =====================
  // دوال التحقق من الدور (Role)
  // =====================

  String get _roleNorm =>
      (role ?? '').toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  bool _isRole(String value) =>
      _roleNorm == value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  bool get isAdmin => _isRole('Admin');
  bool get isSalesManager => _isRole('SalesManager');
  bool get isGeneralManager =>
      _isRole('GeneralManager') || _isRole('GM') || _isRole('General');

  // Leads لا يوجد بها طلب موافقة رفض؛ أي مستخدم مصادق يرفض مباشرة.
  bool get canRejectLeadDirectly => userId != null;

  bool get isSales => _isRole('Sales');
  bool get isAccountManager => _isRole('AccountManager');
  bool get isAccount => _isRole('Account') || _isRole('Accountant');
  bool get isWarehouse => _isRole('Warehouse');
  bool get isCashier => _isRole('Cashier');
  bool get isSocial => _isRole('Social');
  bool get isSocialManager => _isRole('SocialManager');
  bool get isViewer => _isRole('Viewer');
  bool get isSocialView => _isRole('SocialView');
  bool get isHrManager => _isRole('HrManager') || _isRole('HRManager');
  bool get isProductionManager => _isRole('ProductionManager');
  bool get isFactoryManager => _isRole('FactoryManager');
  bool get isUserRole => _isRole('User');

  // هل هو خدمة عملاء؟
  bool get isCustomerService =>
      _isRole('CustomerService') || _isRole('CS') || _isRole('خدمة العملاء');

  // هل هو مختص B2B؟
  bool get isB2B => _isRole('B2B');

  // هل يشوف بيانات HR كلها؟ (Admin + HR Manager)
  bool get canSeeAllHR => isAdmin || isHrManager || isGeneralManager;

  // هل يشوف بيانات السوشيال ميديا؟ (Admin + SocialManager)
  bool get canSeeAllSocial => isAdmin || isSocialManager || isGeneralManager;

  // هل هو من الإدارة العليا؟ (يقدر يرفض ليد مباشرة + يشوف كل حاجة)
  bool get isExecutive =>
      isAdmin || isGeneralManager || isSalesManager || isAccountManager;

  // هل يشوف كل البيانات؟ (مش بتاعته بس)
  bool get canSeeAllData =>
      isAdmin ||
      isGeneralManager ||
      isSalesManager ||
      isAccountManager ||
      isHrManager;

  // هل يشوف بيانات المبيعات كلها؟
  bool get canSeeAllSales => isAdmin || isSalesManager;

  // هل يشوف بيانات الحسابات كلها؟
  bool get canSeeAllAccounts => isAdmin || isAccountManager;

  // =====================
  // دوال التحقق من الصلاحيات
  // =====================

  // ✅ هل يمكنه رؤية الشاشة؟
  bool canView(String formName) {
    final perm = _permissions[formName];
    return perm?.canView ?? false;
  }

  // ✅ هل يمكنه الإضافة؟
  bool canAdd(String formName) {
    final perm = _permissions[formName];
    return perm?.canAdd ?? false;
  }

  // ✅ هل يمكنه التعديل؟
  bool canEdit(String formName) {
    final perm = _permissions[formName];
    return perm?.canEdit ?? false;
  }

  // ✅ هل يمكنه الحذف؟
  bool canDelete(String formName) {
    final perm = _permissions[formName];
    return perm?.canDelete ?? false;
  }

  bool hasClaim(String claim) => _claims.contains(claim);
  bool hasAnyClaim(Iterable<String> claims) => claims.any(_claims.contains);
  Set<String> get claims => Set.unmodifiable(_claims);

  // ═══════════════════════════════════════════════════════════
  // Policies مطابقة لمراجع الصلاحيات في Blazor 913cc57
  // ═══════════════════════════════════════════════════════════

  bool get canViewSalesInvoices => isAdmin || canView('frm_PartiesInvoices');
  bool get canViewPurchaseInvoices =>
      isAdmin ||
      isAccountManager ||
      isAccount ||
      isFactory ||
      isProductionManager ||
      isFactoryManager ||
      canView('frm_SupplierInvoices');
  bool get canFullEditInvoices => isAdmin || isAccountManager;
  bool get canApproveInvoiceEdit => isAdmin || isAccountManager;
  bool get canViewInvoiceProfit => isAdmin || isAccountManager;
  bool get canViewInvoiceHistory => isAdmin || isAccountManager;
  bool get canRestoreInvoiceSnapshot => isAdmin || isAccountManager;
  bool get canSeeProtectedAccountManagerInvoices =>
      isAdmin || isAccountManager || isAccount;

  bool get canViewLostRecovery =>
      isAdmin ||
      isGeneralManager ||
      isSalesManager ||
      isCustomerService ||
      canView('frm_LostRecovery');
  bool get canReviveLostOpportunity =>
      isAdmin ||
      isGeneralManager ||
      isSalesManager ||
      isCustomerService ||
      hasClaim('frm_LostRecovery:Revive');
  bool get canLogLostRecoveryContact =>
      isAdmin ||
      isGeneralManager ||
      isSalesManager ||
      isCustomerService ||
      hasClaim('frm_LostRecovery:LogContact');

  // ComplaintPermissions.CanEscalate: Admin + AM + GM فقط.
  bool get canEscalateComplaint =>
      isAdmin || isAccountManager || isGeneralManager;

  bool get canViewCustomerCare =>
      isCustomerService ||
      isAdmin ||
      isAccountManager ||
      isSalesManager ||
      isGeneralManager ||
      isAccount ||
      canView(FormNames.customerCare);
  bool get canLogCustomerCare => canViewCustomerCare;
  bool get canViewAllCustomerCare =>
      isAdmin ||
      isAccountManager ||
      isSalesManager ||
      isGeneralManager ||
      isAccount;
  bool get canExportCustomerCare =>
      isAdmin ||
      isAccountManager ||
      isSalesManager ||
      isGeneralManager ||
      hasClaim('frm_CustomerCare:Export');

  bool get canViewExecutiveCockpit =>
      isAdmin || canView(FormNames.executiveCockpit);
  bool get canExportExecutiveCockpit => canViewExecutiveCockpit;

  bool get canViewDelivery =>
      isAdmin ||
      isAccountManager ||
      isAccount ||
      isSales ||
      isUserRole ||
      canView('frmInvoiceDeliveryStatus');
  bool get canSeeDeliveryAmounts =>
      isAdmin || isAccountManager || isAccount || isSales;
  bool get canEditDeliveryFull =>
      isAdmin ||
      isAccountManager ||
      isSales ||
      canEdit('frmInvoiceDeliveryStatus');
  bool get canConfirmDelivery =>
      isAdmin ||
      isSales ||
      isUserRole ||
      hasClaim('frmInvoiceDeliveryStatus:Deliver');
  bool get canOverrideDeliveryRemaining => isAdmin || isAccountManager;

  bool get canViewPurchaseReceipts =>
      isAdmin ||
      isGeneralManager ||
      isAccountManager ||
      isSales ||
      isUserRole ||
      isFactory ||
      isProductionManager ||
      isFactoryManager ||
      canView(FormNames.purchaseReceiptStatus) ||
      canView(FormNames.supplierInvoices);
  bool get canSeePurchaseReceiptAmounts =>
      isAdmin ||
      isAccountManager ||
      isFactory ||
      isProductionManager ||
      isFactoryManager ||
      canView(FormNames.supplierInvoices);
  bool get canConfirmPurchaseReceipt =>
      canViewPurchaseReceipts &&
      (isAdmin ||
          isGeneralManager ||
          isFactory ||
          isProductionManager ||
          isFactoryManager ||
          canEdit(FormNames.purchaseReceiptStatus));

  bool get canViewAdditionalCharges =>
      isAdmin ||
      isAccountManager ||
      isAccount ||
      canView(FormNames.inspectionCharge);
  bool get canCreateAdditionalCharges =>
      isAdmin ||
      isAccountManager ||
      isAccount ||
      canAdd(FormNames.inspectionCharge) ||
      canAdd('frmInvoices');
  bool get canEditAdditionalCharges =>
      isAdmin ||
      isAccountManager ||
      isAccount ||
      canEdit(FormNames.inspectionCharge);
  bool get canDeleteAdditionalCharges =>
      isAdmin ||
      isAccountManager ||
      canDelete(FormNames.inspectionCharge) ||
      canDelete('frmInvoices');

  // =====================
  // صلاحيات خاصة بالأسعار (للمنتجات)
  // =====================
  // =====================
  // صلاحيات خاصة بالأسعار (للمنتجات) - بالـ Role
  // =====================

  // هل هو مصنع؟
  bool get isFactory => _isRole('factory');

  /// Admin + AccountManager: يشوفوا (تكلفة + بيع + نسبة ربح) + يعدلوا بيع ونسبة
  bool get canSeeFullProductPricing {
    return isAdmin || isAccountManager;
  }

  /// Factory: يشوف ويعدل التكلفة فقط
  bool get canSeeCostOnlyProductPricing {
    return isFactory;
  }

  /// Sales + SalesManager: يشوفوا سعر البيع فقط
  bool get canSeeSaleOnlyProductPricing {
    return !canSeeFullProductPricing && !canSeeCostOnlyProductPricing;
  }

  /// هل يقدر يعدل سعر البيع مباشرة؟ (Admin + AccountManager)
  bool get canEditSalePrice {
    return isAdmin || isAccountManager;
  }

  /// هل يقدر يعدل التكلفة؟ (Factory فقط)
  bool get canEditCostPrice {
    return isFactory;
  }

  /// هل يقدر يعدل نسب الربح؟ (Admin + AccountManager)
  bool get canEditPricingMargins {
    return isAdmin || isAccountManager;
  }

  /// هل يقدر يطلب تعديل سعر؟ (Sales فقط)
  bool get canRequestPriceChange {
    return isSales;
  }

  /// مراجعة طلبات تعديل الأسعار: Admin + AccountManager + SalesManager.
  bool get canReviewPriceRequests {
    return isAdmin || isAccountManager || isSalesManager;
  }

  bool get canViewPriceList => isAdmin || canView(FormNames.priceList);
  bool get canSeePriceListSalePrices => !isFactory;
  bool get canSeePriceListCosts => isAdmin || isAccountManager || isAccount;
  bool get canEditPriceListSalePrice => isAdmin || isAccountManager;
  bool get canEditPriceListCost => isAdmin || isAccountManager || isAccount;
  bool get canViewPriceListHistory => isAdmin || isAccountManager;
  bool get canExportPriceList => isAdmin || isAccountManager;

  bool get isQuotationCostOnlyViewer => isProductionManager || isFactory;
  bool get canViewQuotations =>
      isAdmin || isQuotationCostOnlyViewer || canView(FormNames.quotationsList);
  bool get canAddQuotation =>
      !isQuotationCostOnlyViewer &&
      (isAdmin || canAdd(FormNames.quotationsList));
  bool get canEditQuotation =>
      !isQuotationCostOnlyViewer &&
      (isAdmin || canEdit(FormNames.quotationsList));
  bool get canDeleteQuotation =>
      !isQuotationCostOnlyViewer &&
      (isAdmin || canDelete(FormNames.quotationsList));
  bool get canViewQuotationCost =>
      isAdmin || isAccountManager || isQuotationCostOnlyViewer;
  bool get canEditQuotationCost => isFactory && !isAdmin;
  bool get canViewQuotationSalePrices => !isQuotationCostOnlyViewer;

  bool get canViewJobOrders =>
      isAdmin ||
      isSalesManager ||
      isSales ||
      isAccountManager ||
      isHrManager ||
      isProductionManager ||
      isFactoryManager ||
      isFactory ||
      canView(FormNames.jobOrders);
  bool get canSeeJobOrderAmounts => isAdmin || isAccountManager || isAccount;
  bool get canEditJobOrderDueDate =>
      isAdmin ||
      isProductionManager ||
      isFactoryManager ||
      canEdit(FormNames.jobOrders);
  bool get canOpenJobOrderInvoices =>
      isAdmin || canView(FormNames.partiesInvoices);

  /// هل يشوف ملف PDF؟ (الكل ماعدا Account)
  bool get canSeePDF {
    return !isAccount;
  }

  /// هل يقدر يضيف PDF؟ (Sales + Factory + Admin + AccountManager)
  bool get canAddPDF {
    return isSales || isFactory || isAdmin || isAccountManager;
  }

  // ✅ جلب صلاحية معينة
  Permission? getPermission(String formName) {
    return _permissions[formName];
  }

  // ✅ جلب كل الصلاحيات
  Map<String, Permission> get allPermissions => _permissions;

  // ✅ هل عنده أي صلاحية على الشاشة؟
  bool hasAnyPermission(String formName) {
    final perm = _permissions[formName];
    if (perm == null) return false;
    return perm.canView || perm.canAdd || perm.canEdit || perm.canDelete;
  }

  // ✅ طباعة الصلاحيات (للتجربة)
  void printPermissions() {
    print('📋 صلاحيات المستخدم $username:');
    _permissions.forEach((formName, perm) {
      print(
        '  $formName: View=${perm.canView}, Add=${perm.canAdd}, Edit=${perm.canEdit}, Delete=${perm.canDelete}',
      );
    });
  }

  // =====================
  // صلاحيات الشكاوى
  // =====================

  // عرض قائمة الشكاوى
  bool get canViewComplaints => canView(FormNames.complaintsMain);

  // إضافة شكوى جديدة (نفس الشاشة)
  bool get canAddComplaint => canAdd(FormNames.complaintsMain);

  // التصعيد معرف مركزيًا في Policy أعلاه.
}

// =====================
// أسماء الشاشات (Constants)
// =====================
class FormNames {
  // ═══════════════════════════════════════
  // 1. البيانات الأساسية
  // ═══════════════════════════════════════
  static const String companyInfo = 'frm_CompanyInfo';
  static const String productGroups = 'frm_ProductGroups';
  static const String productsList = 'frm_ProductList';
  static const String partiesList = 'frm_PartiesList';
  static const String employeesList = 'frm_Employeeslist';
  static const String expenseTree = 'frmExpenseTree';
  static const String partiesAdd = 'frm_Parties';
  static const String productsAdd = 'frm_Products';
  static const String pricingMargins = 'frm_PricingMargins';
  static const String priceRequests = 'frm_PriceRequests';
  static const String priceHistory = 'frm_PriceHistory';
  static const String priceList = 'frm_PriceList';

  // ═══════════════════════════════════════
  // 2. المخازن
  // ═══════════════════════════════════════
  static const String stockLevels = 'frm_StockLevels';
  static const String transactionProductGroup = 'frm_TransactionProductGroup';
  static const String bestSellingItems = 'frm_Bestsellingitems';

  // ═══════════════════════════════════════
  // 3. الحسابات
  // ═══════════════════════════════════════
  static const String quotationsList = 'frmQuotationsList';
  static const String jobOrders = 'frm_JobOrders';
  static const String partiesInvoices = 'frm_PartiesInvoices';
  static const String supplierInvoices = 'frm_SupplierInvoices';
  static const String expensesAdd = 'frm_Expenses';
  static const String expensesList = 'frm_ExpensesList';
  static const String paymentsInvoicesNew = 'frm_PaymentsInvoicesNew';
  static const String customerDocs = 'frmCustomerDocs';

  // ═══════════════════════════════════════
  // 4. الموارد البشرية
  // ═══════════════════════════════════════
  static const String employeesAdd = 'frm_Employees';
  static const String payroll = 'frm_Payroll';
  static const String commissions = 'frm_Commissions';
  static const String importBiometric = 'frm_ImportBiometric';
  static const String payrollProcessor = 'frmPayrollProcessor';
  static const String employeeShifts = 'frm_EmpolyeeShifts';
  static const String dailyExemptions = 'frmDailyExemptions';
  static const String allShifts = 'frm_AllShifts';
  static const String empAttendance = 'frm_empAttendance';
  static const String rpt_empAttendance = 'rpt_empAttendance';
  static const String myPermissions = 'frm_MyPermissions';
  static const String myschedule = 'frm_MySchedule';

  // ═══════════════════════════════════════
  // 5. الخزينة
  // ═══════════════════════════════════════
  static const String payments = 'frm_Payments';
  static const String payrollPayment = 'frm_PayrollPayment';
  static const String personalAccounts = 'frmPersonalAccounts';
  static const String cashBoxManual = 'frm_CashBoxManual';
  static const String inspectionCharge = 'frmInspectionCharge';
  static const String cashBoxTransaction = 'frm_CashBoxTransaction';
  static const String cashBoxDashboard = 'frm_CashBoxDashboard';

  // ═══════════════════════════════════════
  // 6. التقارير
  // ═══════════════════════════════════════
  static const String dashboard = 'DashBoard';
  static const String executiveCockpit = 'frm_ExecutiveCockpit';
  static const String filterIncomeStatement = 'frmFilterIncomeStatment';
  static const String cashFlowNew = 'frm_CashFlowNew';
  static const String expensesDashboard = 'frmExpensesDashboard';
  static const String dashboardSales = 'frmDashboard';
  static const String comparePeriods = 'frmComparePeriods';
  static const String expensesFilter = 'frmExpensesFilter';
  static const String payrollReport = 'frmPayrollReport';
  static const String dashboardMain = 'DashBoard';
  static const String dashboardCRM = 'frmCRM_Dashboard';
  static const String reportCustomerBalance = 'rpt_BalanseCustomer';
  static const String reportExpenses = 'rptExpensesReport';

  // ═══════════════════════════════════════
  // 7. إدارة علاقات العملاء (CRM)
  // ═══════════════════════════════════════
  static const String newInteraction = 'frmNewInteraction';
  static const String dailyTasks = 'frmDailyTasks';
  static const String crmTasksLegacy = 'frmCrmTasksLegacy';
  static const String salesPipeline = 'frmSalesPipeline';
  static const String newQuotation = 'frmNewQuotation';
  static const String interactionsLog = 'frmInteractionsLog';
  static const String clientCard = 'frmClientCard';
  static const String managerSales = 'frmManamgerSales';
  static const String closureApprovalRequests = 'frm_ClosureApprovalRequests';
  static const String lostRecovery = 'frm_LostRecovery';
  static const String lostRecoveryReport = 'frm_LostRecoveryReport';
  static const String generalTasks = 'frm_GeneralTasks';
  static const String stockTransactions = 'frm_StockTransactions';
  static const String stockEntry = 'frm_StockEntry';
  static const String stockTransfer = 'frm_StockTransfer';
  static const String warehouses = 'frm_Warehouses';
  static const String stockCount = 'frm_StockCount';
  static const String stockValue = 'frm_StockValue';
  static const String complaintsMain = 'frm_Complaints_Main';
  static const String customerCare = 'frm_CustomerCare';
  static const String customerCareHistory = 'frm_CustomerCare_History';
  static const String crmDashboard = 'frmCRM_Dashboard';
  static const String invoiceDeliveryStatus = 'frmInvoiceDeliveryStatus';
  static const String purchaseReceiptStatus = 'frm_PurchaseReceiptStatus';
  static const String additionalCharges = inspectionCharge;
  static const String editOpportunity = 'frmEditOpportunity';

  // ═══════════════════════════════════════
  // 8. الإدارة والصلاحيات
  // ═══════════════════════════════════════
  static const String addUser = 'frm_AddUser';
  static const String allUsers = 'frm_AllUsers';
  static const String addPermission = 'frm_AddPermission';
  static const String managePermissions = 'frmManagePermissions';
  static const String broadcastNotification = 'frm_BroadcastNotification';
  static const String auditViewer = 'frm_AuditViewer';

  // ═══════════════════════════════════════
  // 9. User Profile (في الإعدادات)
  // ═══════════════════════════════════════
  static const String notificationsAll = 'frm_NotificationsAll';
  static const String changePassword = 'frm_ChangePassword';

  // ═══════════════════════════════════════
  // 10. إعدادات CRM
  // ═══════════════════════════════════════
  static const String adCampaigns = 'frmAdCampain';
  static const String leadsCrm = 'frm_LeadsCRM';

  /// My Leads entry (Blazor /crm/leads/my) — uses same permission as leads list
  static const String myLeads = 'frm_MyLeads';
  static const String contactSources = 'frmContactSourses';
  //static const String adCampaigns = 'frmAdCampain';
  //static const String contactSources = 'frmContactSourses';
  static const String salesStages = 'frmSalesStages';
  static const String interestCategories = 'frmInterestCategories';
  static const String contactStatuses = 'frmContactStatus';
  static const String taskTypes = 'frmTaskTypes';
  static const String lostReasons = 'frmLostReasons';
}

// ═══════════════════════════════════════
// 10. إعدادات CRM
// ═══════════════════════════════════════

//static const String adCampaigns = 'frmAdCampain';
//static const String contactSources = 'frmContactSourses';
// ✅ لما تضيف الباقي في القاعدة ضيفهم هنا:
// static const String salesStages = 'frmSalesStages';
// static const String interestCategories = 'frmInterestCategories';
// static const String contactStatuses = 'frmContactStatus';
// static const String taskTypes = 'frmTaskTypes';
// static const String lostReasons = 'frmLostReasons';

// =====================
// هيكل القائمة (Menu Structure) - لازم يكون برا FormNames
// =====================

class MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final List<SubMenuItem> children;

  MenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });
}

class SubMenuItem {
  final String title;
  final String formName;
  final IconData icon;

  /// هل هذا العنوان مجرد عنوان تجميع داخل القسم (غير قابل للنقر)؟
  final bool isHeader;

  SubMenuItem(this.title, this.formName, this.icon, {this.isHeader = false});

  /// عنوان تجميع يوضح بداية مجموعة فرعية داخل القسم.
  SubMenuItem.header(this.title)
      : formName = '',
        icon = Icons.chevron_right_rounded,
        isHeader = true;
}

class MenuStructure {
  static List<MenuItem> getItems() {
    return [
      // ═══════════════════════════════════════
      // 1. البيانات الأساسية
      // ═══════════════════════════════════════
      MenuItem(
        title: 'البيانات الأساسية',
        icon: Icons.domain,
        color: AppColors.success,
        children: [
          //SubMenuItem('بيانات الشركة', FormNames.companyInfo, Icons.business),
          //SubMenuItem('مجموعة المنتجات', FormNames.productGroups, Icons.category),
        ],
      ),

      // ═══════════════════════════════════════
      // 2. المخازن
      // ═══════════════════════════════════════
      MenuItem(
        title: 'المخازن',
        icon: Icons.warehouse,
        color: AppColors.warning,
        children: [
          SubMenuItem(
              'المنتجات', FormNames.productsList, Icons.inventory_2_rounded),
          SubMenuItem(
              'أرصدة المخزون', FormNames.stockLevels, Icons.inventory_rounded),
          SubMenuItem(
              'إضافة رصيد', FormNames.stockEntry, Icons.add_box_rounded),
          SubMenuItem('حركة المخزون', FormNames.stockTransactions,
              Icons.history_rounded),
          SubMenuItem(
              'تحويل مخزني', FormNames.stockTransfer, Icons.swap_horiz_rounded),
          SubMenuItem(
              'جرد فعلي', FormNames.stockCount, Icons.fact_check_rounded),
          SubMenuItem(
              'قيمة المخزون', FormNames.stockValue, Icons.attach_money_rounded),
          SubMenuItem(
              'إدارة المخازن', FormNames.warehouses, Icons.warehouse_rounded),
          SubMenuItem('حركة المخازن', FormNames.transactionProductGroup,
              Icons.swap_horiz),
          SubMenuItem('الأصناف الأكثر مبيعاً', FormNames.bestSellingItems,
              Icons.star_rounded),
        ],
      ),
      // جديد المبيعات
      MenuItem(
        title: 'المبيعات',
        icon: Icons.sell,
        color: AppColors.gold,
        children: [
          // ── الأسعار والعروض ──
          SubMenuItem.header('الأسعار والعروض'),
          SubMenuItem('المنتجات', FormNames.productsList, Icons.inventory_2),
          SubMenuItem('قائمة الأسعار', FormNames.priceList, Icons.sell_rounded),
          SubMenuItem('طلبات تعديل الأسعار', FormNames.priceRequests,
              Icons.price_change),
          SubMenuItem('نسب الربح', FormNames.pricingMargins, Icons.percent),
          SubMenuItem(
              'عروض الأسعار', FormNames.quotationsList, Icons.request_quote),
          // ── الفواتير والتحصيل ──
          SubMenuItem.header('الفواتير والتحصيل'),
          SubMenuItem(
            'فواتير العملاء',
            FormNames.partiesInvoices,
            Icons.receipt,
          ),
          SubMenuItem(
            'فواتير المصنع',
            FormNames.supplierInvoices,
            Icons.receipt_long,
          ),
          SubMenuItem(
            'متابعة التسليم',
            FormNames.invoiceDeliveryStatus,
            Icons.local_shipping,
          ),
          SubMenuItem(
            'استلامات الشراء',
            FormNames.purchaseReceiptStatus,
            Icons.inventory_rounded,
          ),
          SubMenuItem(
            'الرسوم والدفعات المقدمة',
            FormNames.additionalCharges,
            Icons.account_balance_wallet_rounded,
          ),
          SubMenuItem(
            'مدفوعات الفواتير',
            FormNames.paymentsInvoicesNew,
            Icons.payment,
          ),
          // ── العملاء والإنتاج ──
          SubMenuItem.header('العملاء والإنتاج'),
          SubMenuItem('العملاء', FormNames.partiesList, Icons.people),
          SubMenuItem(
            'أوامر التشغيل',
            FormNames.jobOrders,
            Icons.factory_rounded,
          ),
          SubMenuItem(
            'طباعة مستندات العميل',
            FormNames.customerDocs,
            Icons.print,
          ),
        ],
      ),
      // ══════════════════════════════════════════════════════════════════════
      // قائمة الأسعار (مستقلة للوصول السريع من المبيعات)
      // ══════════════════════════════════════════════════════════════════════
      MenuItem(
        title: 'قائمة الأسعار',
        icon: Icons.sell_rounded,
        color: AppColors.gold,
        children: [
          SubMenuItem('قائمة الأسعار', FormNames.priceList, Icons.sell_rounded),
        ],
      ),
      // ══════════════════════════════════════════════════════════════════════
      // 3. المالية (الخزينة + المصروفات + الحسابات)
      // ══════════════════════════════════════════════════════════════════════
      MenuItem(
        title: 'المالية',
        icon: Icons.account_balance_wallet,
        color: AppColors.navy,
        children: [
          // ── الخزينة ──
          SubMenuItem(
            'مؤشرات الخزينة',
            FormNames.cashBoxDashboard,
            Icons.analytics,
          ),
          SubMenuItem(
            'حركات الخزينة',
            FormNames.cashBoxTransaction,
            Icons.history,
          ),
          SubMenuItem('سند قبض / صرف', FormNames.cashBoxManual, Icons.receipt),
          // ── المصروفات ──
          SubMenuItem(
            'كافة المصروفات',
            FormNames.expensesList,
            Icons.money_off,
          ),
          SubMenuItem('إضافة مصروف', FormNames.expensesAdd, Icons.add_card),
          SubMenuItem(
            'مجموعات المصروفات',
            FormNames.expenseTree,
            Icons.account_tree,
          ),
          // ── الحسابات الشخصية ──
          SubMenuItem(
            'الحسابات الشخصية',
            FormNames.personalAccounts,
            Icons.people_alt,
          ),
          // ── مدفوعات ──
          SubMenuItem('مدفوعات الفواتير', FormNames.payments, Icons.payment),
          SubMenuItem('سداد الرواتب', FormNames.payrollPayment, Icons.money),
          SubMenuItem(
            'رسوم المعاينة',
            FormNames.inspectionCharge,
            Icons.fact_check,
          ),
        ],
      ),

      // ═══════════════════════════════════════
      // 4. الموارد البشرية
      // ═══════════════════════════════════════
      MenuItem(
        title: 'الموارد البشرية',
        icon: Icons.people_alt,
        color: AppColors.info,
        children: [
          SubMenuItem('الموظفين', FormNames.employeesList, Icons.badge),
          SubMenuItem(
            ' بصمه الموظف',
            FormNames.empAttendance,
            Icons.fingerprint,
          ),
          SubMenuItem(
            'جدول مواعيدي',
            FormNames.myschedule,
            Icons.calendar_month_rounded,
          ),
          SubMenuItem('إضافة موظف', FormNames.employeesAdd, Icons.person_add),
          SubMenuItem(
            'طلب اذن',
            FormNames.myPermissions,
            Icons.assignment_turned_in,
          ),
          //SubMenuItem('الرواتب الشهرية', FormNames.payroll, Icons.attach_money),
          //SubMenuItem('العمولات', FormNames.commissions, Icons.percent),
          //SubMenuItem('البصمة', FormNames.importBiometric, Icons.fingerprint),
          //SubMenuItem('تسجيل راتب جماعي', FormNames.payrollProcessor, Icons.groups),
          SubMenuItem(
            'شيفتات الموظفين',
            FormNames.employeeShifts,
            Icons.schedule,
          ),
          SubMenuItem(
            'متابعه الحضور والانصراف',
            FormNames.rpt_empAttendance,
            Icons.fingerprint,
          ),
          SubMenuItem(
            'متابعة الشيفتات',
            FormNames.allShifts,
            Icons.calendar_month,
          ),
          SubMenuItem(
            'استثناءات الموظفين',
            FormNames.dailyExemptions,
            Icons.event_busy,
          ),
        ],
      ),

      // ═══════════════════════════════════════
      // 5. التقارير
      // ═══════════════════════════════════════
      MenuItem(
        title: 'التقارير',
        icon: Icons.analytics,
        color: AppColors.error,
        children: [
          SubMenuItem(
            'لوحة القيادة التنفيذية',
            FormNames.executiveCockpit,
            Icons.workspace_premium_rounded,
          ),
          SubMenuItem('لوحة المعلومات', FormNames.dashboard, Icons.dashboard),
          SubMenuItem(
            'قائمة الدخل',
            FormNames.filterIncomeStatement,
            Icons.bar_chart,
          ),
          SubMenuItem(
            'التدفقات النقدية',
            FormNames.cashFlowNew,
            Icons.water_drop,
          ),
          SubMenuItem(
            'مؤشر المصروفات',
            FormNames.expensesDashboard,
            Icons.pie_chart,
          ),
          SubMenuItem(
            'مؤشر المبيعات',
            FormNames.dashboardSales,
            Icons.show_chart,
          ),
          SubMenuItem(
            'مقارنة المبيعات',
            FormNames.comparePeriods,
            Icons.compare_arrows,
          ),
          SubMenuItem(
            'تقرير المصروفات',
            FormNames.expensesFilter,
            Icons.filter_list,
          ),
          SubMenuItem(
            'استعلام الرواتب',
            FormNames.payrollReport,
            Icons.summarize,
          ),
        ],
      ),

      // ═══════════════════════════════════════
      // 7. إدارة علاقات العملاء (CRM)
      // ═══════════════════════════════════════
      MenuItem(
        title: 'إدارة العملاء (CRM)',
        icon: Icons.handshake,
        color: AppColors.info,
        children: [
          SubMenuItem('تواصل جديد', FormNames.newInteraction, Icons.add_call),
          SubMenuItem(
            'المتابعات (ليدز + CRM)',
            FormNames.dailyTasks,
            Icons.event_available,
          ),
          SubMenuItem('مهام CRM', FormNames.crmTasksLegacy, Icons.task_alt),
          SubMenuItem(
            'متابعة الفرص',
            FormNames.managerSales,
            Icons.trending_up,
          ),
          SubMenuItem(
            'مراحل البيع',
            FormNames.salesPipeline,
            Icons.filter_list,
          ),
          //SubMenuItem('إنشاء عرض سعر', FormNames.newQuotation, Icons.request_quote),
          //SubMenuItem('سجل التواصلات', FormNames.interactionsLog, Icons.history),
          SubMenuItem('بطاقة العميل', FormNames.clientCard, Icons.contact_page),
          SubMenuItem(
            'الشكاوى',
            FormNames.complaintsMain,
            Icons.report_problem,
          ),
          SubMenuItem(
            'خدمة العملاء',
            FormNames.customerCare,
            Icons.support_agent_rounded,
          ),
          SubMenuItem(
            'سجل خدمة العملاء',
            FormNames.customerCareHistory,
            Icons.history_rounded,
          ),
          SubMenuItem(
            'لوحة CRM',
            FormNames.crmDashboard,
            Icons.dashboard_customize,
          ),
          SubMenuItem('My Leads', FormNames.myLeads, Icons.assignment_ind),
          SubMenuItem(
              'طلبات موافقة إغلاق الفرص',
              FormNames.closureApprovalRequests,
              Icons.admin_panel_settings_rounded),
          SubMenuItem('استرداد الفرص الخاسرة', FormNames.lostRecovery,
              Icons.restart_alt_rounded),
          SubMenuItem('تقرير الاسترداد', FormNames.lostRecoveryReport,
              Icons.assessment_rounded),
          SubMenuItem('التكليفات العامة', FormNames.generalTasks,
              Icons.assignment_ind_rounded),
          //SubMenuItem('تعديل الفرص', FormNames.editOpportunity, Icons.edit),
          SubMenuItem(
            'إعدادات CRM',
            FormNames.adCampaigns,
            Icons.settings_rounded,
          ),
          SubMenuItem(
            'كل الـ Leads (Meta)',
            FormNames.leadsCrm,
            Icons.campaign,
          ),
        ],
      ),

      // ═══════════════════════════════════════
      // 8. الإدارة والصلاحيات
      // ═══════════════════════════════════════
      MenuItem(
        title: 'الإدارة والصلاحيات',
        icon: Icons.admin_panel_settings,
        color: AppColors.neutral,
        children: [
          SubMenuItem('إضافة مستخدم', FormNames.addUser, Icons.person_add),
          SubMenuItem('جميع المستخدمين', FormNames.allUsers, Icons.people),
          SubMenuItem(
            'إضافة صلاحية',
            FormNames.addPermission,
            Icons.add_moderator,
          ),
          SubMenuItem(
            'إدارة الصلاحيات',
            FormNames.managePermissions,
            Icons.lock,
          ),
          SubMenuItem('متابعة النظام', FormNames.auditViewer, Icons.visibility),
          SubMenuItem(
            '📢 إشعار عام (بث)',
            FormNames.broadcastNotification,
            Icons.campaign_rounded,
          ),
        ],
      ),
    ];
  }
}
