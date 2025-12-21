import 'dart:convert';

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
    _permissions.clear();
    print('🚪 تم مسح بيانات المستخدم والصلاحيات');
  }

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

  /// المستخدمين اللي يشوفوا (تكلفة + بيع + نسبة ربح)
  bool get canSeeFullProductPricing {
    final name = (username ?? '').toLowerCase();
    return name == 'admin' || name == 'nabil' || name == 'hassan';
  }

  /// المستخدم اللي يشوف (سعر التكلفة فقط)
  bool get canSeeCostOnlyProductPricing {
    final name = (username ?? '').toLowerCase();
    return name == 'factory';
  }

  /// الباقي يشوف (سعر البيع فقط)
  bool get canSeeSaleOnlyProductPricing {
    return !canSeeFullProductPricing && !canSeeCostOnlyProductPricing;
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
}

// =====================
// أسماء الشاشات (Constants)
// =====================
class FormNames {
  // الشاشات الرئيسية
  static const String dashboard = 'DashBoard';
  static const String notifications = 'frm_NotificationsAll';
  
  // المنتجات
  static const String productsList = 'frm_ProductList';
  static const String productsAdd = 'frm_Products';
  static const String productGroups = 'frm_ProductGroups';
  
  // المصروفات
  static const String expensesList = 'frm_ExpensesList';
  static const String expensesAdd = 'frm_Expenses';
  static const String expenseGroups = 'frm_ExpensesGroup';
  
  // العملاء والموردين
  static const String partiesList = 'frm_PartiesList';
  static const String partiesAdd = 'frm_Parties';
  
  // الفواتير
  static const String salesInvoice = 'frm_SalesInvoiveNew';
  static const String salesInvoiceView = 'frm_SalesInvoiveView';
  
  // المدفوعات
  static const String payments = 'frm_Payments';
  static const String cashBoxTransactions = 'frm_CashBoxTransaction';
  
  // الموظفين
  static const String employees = 'frm_Employeeslist';
  static const String employeesAdd = 'frm_Employees';
  
  // التقارير
  static const String reportCustomerBalance = 'rpt_BalanseCustomer';
  static const String reportExpenses = 'rptExpensesReport';
  static const String reportCashbox = 'rptCashboxTransactions';
}