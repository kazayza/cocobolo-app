import 'dart:convert';
import 'package:flutter/material.dart';

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

  // الصلاحيات
  Map<String, Permission> _permissions = {};

  // ✅ تهيئة الصلاحيات بعد تسجيل الدخول
  void initialize({
    required Map<String, dynamic> user,
    required Map<String, dynamic> permissions,
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

    print('✅ تم تحميل ${_permissions.length} صلاحية للمستخدم $username');
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
    print('🚪 تم مسح بيانات المستخدم والصلاحيات');
  }
  
  // =====================
// دوال التحقق من الدور (Role)
// =====================

// هل هو أدمن؟
bool get isAdmin => role?.toLowerCase() == 'admin';

// هل هو مدير مبيعات؟
bool get isSalesManager => role?.toLowerCase() == 'salesmanager';

// هل هو موظف مبيعات؟
bool get isSales => role?.toLowerCase() == 'sales';

// هل هو مدير حسابات؟
bool get isAccountManager => role?.toLowerCase() == 'accountmanager';

// هل هو موظف حسابات؟
bool get isAccount => role?.toLowerCase() == 'account';

// هل هو أمين مخزن؟
bool get isWarehouse => role?.toLowerCase() == 'warehouse';

// هل هو أمين خزينة؟
bool get isCashier => role?.toLowerCase() == 'cashier';

// هل يشوف كل البيانات؟ (مش بتاعته بس)
bool get canSeeAllData => isAdmin || isSalesManager || isAccountManager;

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
  
    // =====================
  // صلاحيات خاصة بالأسعار (للمنتجات)
  // =====================
// =====================
  // صلاحيات خاصة بالأسعار (للمنتجات) - بالـ Role
  // =====================

  // هل هو مصنع؟
  bool get isFactory => role?.toLowerCase() == 'factory';

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

  /// هل يقدر يوافق/يرفض طلبات تعديل السعر؟ (SalesManager)
  bool get canReviewPriceRequests {
    return isSalesManager;
  }

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
      print('  $formName: View=${perm.canView}, Add=${perm.canAdd}, Edit=${perm.canEdit}, Delete=${perm.canDelete}');
    });
  }


  // =====================
  // صلاحيات الشكاوى
  // =====================

  // عرض قائمة الشكاوى
  bool get canViewComplaints => canView(FormNames.complaintsMain);

  // إضافة شكوى جديدة (نفس الشاشة)
  bool get canAddComplaint => canAdd(FormNames.complaintsMain);

  // التصعيد (حسب الـ Role)
  bool get canEscalateComplaint => isSalesManager || isAccountManager;
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
  static const String rpt_empAttendance='rpt_empAttendance';
  static const String myPermissions='frm_MyPermissions';
  static const String myschedule = 'frm_MySchedule';

  

  // ═══════════════════════════════════════
  // 5. الخزينة
  // ═══════════════════════════════════════
  static const String payments = 'frm_Payments';
  static const String payrollPayment = 'frm_PayrollPayment';
  static const String cashBoxManual = 'frm_CashBoxManual';
  static const String inspectionCharge = 'frmInspectionCharge';
  static const String cashBoxTransaction = 'frm_CashBoxTransaction';
  static const String cashBoxDashboard = 'frm_CashBoxDashboard';

  // ═══════════════════════════════════════
  // 6. التقارير
  // ═══════════════════════════════════════
  static const String dashboard = 'DashBoard';
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
  static const String salesPipeline = 'frmSalesPipeline';
  static const String newQuotation = 'frmNewQuotation';
  static const String interactionsLog = 'frmInteractionsLog';
  static const String clientCard = 'frmClientCard';
  static const String managerSales = 'frmManamgerSales';
  static const String complaintsMain = 'frm_Complaints_Main';
  static const String crmDashboard = 'frmCRM_Dashboard';
  static const String invoiceDeliveryStatus = 'frmInvoiceDeliveryStatus';
  static const String editOpportunity = 'frmEditOpportunity';

  // ═══════════════════════════════════════
  // 8. الإدارة والصلاحيات
  // ═══════════════════════════════════════
  static const String addUser = 'frm_AddUser';
  static const String allUsers = 'frm_AllUsers';
  static const String addPermission = 'frm_AddPermission';
  static const String managePermissions = 'frmManagePermissions';
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

  SubMenuItem(this.title, this.formName, this.icon);
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
      color: const Color(0xFF4CAF50),
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
      color: const Color(0xFFFF9800),
      children: [
        SubMenuItem('أرصدة المخزون', FormNames.stockLevels, Icons.inventory),
        SubMenuItem('حركة المخازن', FormNames.transactionProductGroup, Icons.swap_horiz),
        SubMenuItem('الأصناف الأكثر مبيعاً', FormNames.bestSellingItems, Icons.star),
      ],
    ),
    // جديد المبيعات
    MenuItem(
      title: 'المبيعات',
      icon: Icons.sell, // أيقونة بيع مناسبة أكثر
      color: const Color(0xFF2196F3), // لون أزرق هادئ بدل البرتقالي
      children: [
        SubMenuItem('المنتجات', FormNames.productsList, Icons.inventory_2),
        SubMenuItem('العملاء', FormNames.partiesList, Icons.people),
        SubMenuItem('فواتير العملاء', FormNames.partiesInvoices, Icons.receipt),
        SubMenuItem('فواتير المصنع', FormNames.supplierInvoices, Icons.receipt_long),
        SubMenuItem('متابعة التسليم', FormNames.invoiceDeliveryStatus, Icons.local_shipping),
        SubMenuItem('مدفوعات الفواتير', FormNames.paymentsInvoicesNew, Icons.payment),
        SubMenuItem('عروض الأسعار', FormNames.quotationsList, Icons.request_quote),
        SubMenuItem('طباعة مستندات العميل', FormNames.customerDocs, Icons.print),
        SubMenuItem('طلبات تعديل الأسعار', FormNames.priceRequests, Icons.price_change),
        SubMenuItem('نسب الربح', FormNames.pricingMargins, Icons.percent),
      ],
    ),
    // ═══════════════════════════════════════
    // 3. الحسابات
    // ═══════════════════════════════════════
    MenuItem(
      title: 'الحسابات',
      icon: Icons.account_balance_wallet,
      color: const Color(0xFF2196F3),
      children: [
        SubMenuItem('إضافة مصروف', FormNames.expensesAdd, Icons.add_card),
        SubMenuItem('كافة المصروفات', FormNames.expensesList, Icons.money_off),
        SubMenuItem('مجموعات المصروفات', FormNames.expenseTree, Icons.account_tree),
       ],
    ),

    // ═══════════════════════════════════════
    // 4. الموارد البشرية
    // ═══════════════════════════════════════
    MenuItem(
      title: 'الموارد البشرية',
      icon: Icons.people_alt,
      color: const Color(0xFF9C27B0),
      children: [
        SubMenuItem('الموظفين', FormNames.employeesList, Icons.badge),
        SubMenuItem(' بصمه الموظف', FormNames.empAttendance, Icons.fingerprint),
        SubMenuItem('جدول مواعيدي', FormNames.myschedule, Icons.calendar_month_rounded),
        SubMenuItem('إضافة موظف', FormNames.employeesAdd, Icons.person_add),
        SubMenuItem('طلب اذن', FormNames.myPermissions, Icons.assignment_turned_in),
        //SubMenuItem('الرواتب الشهرية', FormNames.payroll, Icons.attach_money),
        //SubMenuItem('العمولات', FormNames.commissions, Icons.percent),
        //SubMenuItem('البصمة', FormNames.importBiometric, Icons.fingerprint),
        //SubMenuItem('تسجيل راتب جماعي', FormNames.payrollProcessor, Icons.groups),
        SubMenuItem('شيفتات الموظفين', FormNames.employeeShifts, Icons.schedule),
        SubMenuItem('متابعه الحضور والانصراف', FormNames.rpt_empAttendance, Icons.fingerprint),
        SubMenuItem('متابعة الشيفتات', FormNames.allShifts, Icons.calendar_month),
        SubMenuItem('استثناءات الموظفين', FormNames.dailyExemptions, Icons.event_busy),
               
      ],
    ),

    // ═══════════════════════════════════════
    // 5. الخزينة
    // ═══════════════════════════════════════
    MenuItem(
      title: 'الخزينة',
      icon: Icons.savings,
      color: const Color(0xFF009688),
      children: [
        SubMenuItem('مؤشرات الخزينة', FormNames.cashBoxDashboard, Icons.analytics),
        SubMenuItem('سند قبض / صرف', FormNames.cashBoxManual, Icons.receipt),
        SubMenuItem('حركات الخزينة', FormNames.cashBoxTransaction, Icons.history),
        SubMenuItem('مدفوعات الفواتير', FormNames.payments, Icons.payment),
        SubMenuItem('سداد الرواتب', FormNames.payrollPayment, Icons.money),
        SubMenuItem('رسوم المعاينة', FormNames.inspectionCharge, Icons.fact_check),
               
      ],
    ),

    // ═══════════════════════════════════════
    // 6. التقارير
    // ═══════════════════════════════════════
    MenuItem(
      title: 'التقارير',
      icon: Icons.analytics,
      color: const Color(0xFFE91E63),
      children: [
        SubMenuItem('لوحة المعلومات', FormNames.dashboard, Icons.dashboard),
        SubMenuItem('قائمة الدخل', FormNames.filterIncomeStatement, Icons.bar_chart),
        SubMenuItem('التدفقات النقدية', FormNames.cashFlowNew, Icons.water_drop),
        SubMenuItem('مؤشر المصروفات', FormNames.expensesDashboard, Icons.pie_chart),
        SubMenuItem('مؤشر المبيعات', FormNames.dashboardSales, Icons.show_chart),
        SubMenuItem('مقارنة المبيعات', FormNames.comparePeriods, Icons.compare_arrows),
        SubMenuItem('تقرير المصروفات', FormNames.expensesFilter, Icons.filter_list),
        SubMenuItem('استعلام الرواتب', FormNames.payrollReport, Icons.summarize),
      ],
    ),

    // ═══════════════════════════════════════
    // 7. إدارة علاقات العملاء (CRM)
    // ═══════════════════════════════════════
    MenuItem(
      title: 'إدارة العملاء (CRM)',
      icon: Icons.handshake,
      color: const Color(0xFF3F51B5),
      children: [
        SubMenuItem('تواصل جديد', FormNames.newInteraction, Icons.add_call),
        SubMenuItem('المهام اليومية', FormNames.dailyTasks, Icons.task_alt),
        SubMenuItem('متابعة الفرص', FormNames.managerSales, Icons.trending_up),
        SubMenuItem('مراحل البيع', FormNames.salesPipeline, Icons.filter_list),
        //SubMenuItem('إنشاء عرض سعر', FormNames.newQuotation, Icons.request_quote),
        //SubMenuItem('سجل التواصلات', FormNames.interactionsLog, Icons.history),
        SubMenuItem('بطاقة العميل', FormNames.clientCard, Icons.contact_page),
        SubMenuItem('الشكاوى', FormNames.complaintsMain, Icons.report_problem),
        SubMenuItem('لوحة CRM', FormNames.crmDashboard, Icons.dashboard_customize),
        
        //SubMenuItem('تعديل الفرص', FormNames.editOpportunity, Icons.edit),
        SubMenuItem('إعدادات CRM', FormNames.adCampaigns, Icons.settings_rounded),
      ],
    ),

    // ═══════════════════════════════════════
    // 8. الإدارة والصلاحيات
    // ═══════════════════════════════════════
    MenuItem(
      title: 'الإدارة والصلاحيات',
      icon: Icons.admin_panel_settings,
      color: const Color(0xFF607D8B),
      children: [
        SubMenuItem('إضافة مستخدم', FormNames.addUser, Icons.person_add),
        SubMenuItem('جميع المستخدمين', FormNames.allUsers, Icons.people),
        SubMenuItem('إضافة صلاحية', FormNames.addPermission, Icons.add_moderator),
        SubMenuItem('إدارة الصلاحيات', FormNames.managePermissions, Icons.lock),
        SubMenuItem('متابعة النظام', FormNames.auditViewer, Icons.visibility),
      ],
    ),
  ];
}
}