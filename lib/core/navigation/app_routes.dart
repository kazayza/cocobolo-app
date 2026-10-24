import 'package:flutter/material.dart';

import '../../screens/login_screen.dart';
import '../../screens/onboarding_screen.dart';

/// مسارات التطبيق المسماة — استبدل MaterialPageRoute المتداخلة.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String splash = '/splash';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String clients = '/clients';
  static const String addClient = '/clients/add';
  static const String clientCard = '/clients/card';
  static const String leads = '/leads';
  static const String addLead = '/leads/add';
  static const String leadDetail = '/leads/detail';
  static const String opportunities = '/opportunities';
  static const String addOpportunity = '/opportunities/add';
  static const String opportunityDetail = '/opportunities/detail';
  static const String pipeline = '/pipeline';
  static const String products = '/products';
  static const String addProduct = '/products/add';
  static const String productDetail = '/products/detail';
  static const String priceList = '/price-list';
  static const String quotations = '/quotations';
  static const String addQuotation = '/quotations/add';
  static const String quotationDetail = '/quotations/detail';
  static const String jobOrders = '/job-orders';
  static const String jobOrderDetail = '/job-orders/detail';
  static const String tasks = '/tasks';
  static const String addTask = '/tasks/add';
  static const String followUps = '/follow-ups';
  static const String addInteraction = '/interactions/add';
  static const String complaints = '/complaints';
  static const String addComplaint = '/complaints/add';
  static const String complaintDetail = '/complaints/detail';
  static const String expenses = '/expenses';
  static const String addExpense = '/expenses/add';
  static const String expenseDashboard = '/expenses/dashboard';
  static const String attendance = '/attendance';
  static const String employees = '/employees';
  static const String addEmployee = '/employees/add';
  static const String shifts = '/shifts';
  static const String mySchedule = '/schedule';
  static const String invoices = '/invoices';
  static const String addInvoice = '/invoices/add';
  static const String invoiceDetail = '/invoices/detail';
  static const String inventory = '/inventory';
  static const String stockLevels = '/inventory/stock-levels';
  static const String stockTransactions = '/inventory/stock-transactions';
  static const String warehouses = '/inventory/warehouses';
  static const String cashbox = '/cashbox';
  static const String cashboxDashboard = '/cashbox/dashboard';
  static const String cashboxTransactions = '/cashbox/transactions';
  static const String cashboxManual = '/cashbox/manual';
  static const String reports = '/reports';
  static const String notifications = '/notifications';
  static const String globalSearch = '/search';
  static const String deliveryTracking = '/delivery';
  static const String permissions = '/permissions';
  static const String changePassword = '/change-password';
  static const String crmSettings = '/crm-settings';
  static const String usersAdmin = '/admin/users';
  static const String lostRecovery = '/lost-recovery';
  static const String exemptions = '/exemptions';
  static const String personalAccounts = '/personal-accounts';

  /// جميع المسارات للنشر في MaterialApp.
  static Map<String, WidgetBuilder> get all => {
        login: (_) => const LoginScreen(),
        onboarding: (_) => const OnboardingScreen(),
        splash: (_) => const SplashScreenPlaceholder(),
        home: (_) => const HomeScreenPlaceholder(),
        settings: (_) => const SettingsScreenPlaceholder(),
        clients: (_) => const ClientsScreenPlaceholder(),
        addClient: (_) => const AddClientScreenPlaceholder(),
        clientCard: (_) => const ClientCardScreenPlaceholder(),
        leads: (_) => const LeadsScreenPlaceholder(),
        addLead: (_) => const AddLeadScreenPlaceholder(),
        leadDetail: (_) => const LeadDetailScreenPlaceholder(),
        opportunities: (_) => const OpportunitiesScreenPlaceholder(),
        addOpportunity: (_) => const AddOpportunityScreenPlaceholder(),
        opportunityDetail: (_) => const OpportunityDetailScreenPlaceholder(),
        pipeline: (_) => const PipelineScreenPlaceholder(),
        products: (_) => const ProductsScreenPlaceholder(),
        addProduct: (_) => const AddProductScreenPlaceholder(),
        productDetail: (_) => const ProductDetailScreenPlaceholder(),
        priceList: (_) => const PriceListScreenPlaceholder(),
        quotations: (_) => const QuotationsScreenPlaceholder(),
        addQuotation: (_) => const AddQuotationScreenPlaceholder(),
        quotationDetail: (_) => const QuotationDetailScreenPlaceholder(),
        jobOrders: (_) => const JobOrdersScreenPlaceholder(),
        jobOrderDetail: (_) => const JobOrderDetailScreenPlaceholder(),
        tasks: (_) => const TasksScreenPlaceholder(),
        addTask: (_) => const AddTaskScreenPlaceholder(),
        followUps: (_) => const FollowUpsScreenPlaceholder(),
        addInteraction: (_) => const AddInteractionScreenPlaceholder(),
        complaints: (_) => const ComplaintsScreenPlaceholder(),
        addComplaint: (_) => const AddComplaintScreenPlaceholder(),
        complaintDetail: (_) => const ComplaintDetailScreenPlaceholder(),
        expenses: (_) => const ExpensesScreenPlaceholder(),
        addExpense: (_) => const AddExpenseScreenPlaceholder(),
        expenseDashboard: (_) => const ExpenseDashboardScreenPlaceholder(),
        attendance: (_) => const AttendanceScreenPlaceholder(),
        employees: (_) => const EmployeesScreenPlaceholder(),
        addEmployee: (_) => const AddEmployeeScreenPlaceholder(),
        shifts: (_) => const ShiftsScreenPlaceholder(),
        mySchedule: (_) => const MyScheduleScreenPlaceholder(),
        invoices: (_) => const InvoicesScreenPlaceholder(),
        addInvoice: (_) => const AddInvoiceScreenPlaceholder(),
        invoiceDetail: (_) => const InvoiceDetailScreenPlaceholder(),
        inventory: (_) => const InventoryScreenPlaceholder(),
        stockLevels: (_) => const StockLevelsScreenPlaceholder(),
        stockTransactions: (_) => const StockTransactionsScreenPlaceholder(),
        warehouses: (_) => const WarehousesScreenPlaceholder(),
        cashbox: (_) => const CashboxScreenPlaceholder(),
        cashboxDashboard: (_) => const CashboxDashboardScreenPlaceholder(),
        cashboxTransactions: (_) => const CashboxTransactionsScreenPlaceholder(),
        cashboxManual: (_) => const CashboxManualScreenPlaceholder(),
        reports: (_) => const ReportsScreenPlaceholder(),
        notifications: (_) => const NotificationsScreenPlaceholder(),
        globalSearch: (_) => const GlobalSearchScreenPlaceholder(),
        deliveryTracking: (_) => const DeliveryTrackingScreenPlaceholder(),
        permissions: (_) => const PermissionsScreenPlaceholder(),
        changePassword: (_) => const ChangePasswordScreenPlaceholder(),
        crmSettings: (_) => const CrmSettingsScreenPlaceholder(),
        usersAdmin: (_) => const UsersAdminScreenPlaceholder(),
        lostRecovery: (_) => const LostRecoveryScreenPlaceholder(),
        exemptions: (_) => const ExemptionsScreenPlaceholder(),
        personalAccounts: (_) => const PersonalAccountsScreenPlaceholder(),
      };

  /// التنقل باسم المسار مع تمرير аргументы اختيارية.
  static Future<void> push(BuildContext context, String routeName,
      {Object? arguments}) {
    return Navigator.of(context).pushNamed(routeName, arguments: arguments);
  }

  static Future<void> pushReplacement(BuildContext context, String routeName,
      {Object? arguments}) {
    return Navigator.of(context)
        .pushReplacementNamed(routeName, arguments: arguments);
  }

  static Future<void> pushAndRemoveUntil(BuildContext context, String routeName,
      {Object? arguments}) {
    return Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  static void pop(BuildContext context, [Object? result]) {
    Navigator.of(context).pop(result);
  }
}

// Plätze مؤقتة ستُستبدل بالشاشات الفعلية عند الترحيل الكامل.
class LoginScreenPlaceholder extends StatelessWidget {
  const LoginScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('شاشة الدخول — قيد الترحيل')),
      );
}
class SplashScreenPlaceholder extends StatelessWidget {
  const SplashScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الشاشة_INITIAL — قيد الترحيل')),
      );
}
class HomeScreenPlaceholder extends StatelessWidget {
  const HomeScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الرئيسية — قيد الترحيل')),
      );
}
class SettingsScreenPlaceholder extends StatelessWidget {
  const SettingsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الإعدادات — قيد الترحيل')),
      );
}
class ClientsScreenPlaceholder extends StatelessWidget {
  const ClientsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('العملاء — قيد الترحيل')),
      );
}
class AddClientScreenPlaceholder extends StatelessWidget {
  const AddClientScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة عميل — قيد الترحيل')),
      );
}
class ClientCardScreenPlaceholder extends StatelessWidget {
  const ClientCardScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('بطاقة العميل — قيد الترحيل')),
      );
}
class LeadsScreenPlaceholder extends StatelessWidget {
  const LeadsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الليדים — قيد الترحيل')),
      );
}
class AddLeadScreenPlaceholder extends StatelessWidget {
  const AddLeadScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة ليد — قيد الترحيل')),
      );
}
class LeadDetailScreenPlaceholder extends StatelessWidget {
  const LeadDetailScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('تفاصيل الليد — قيد الترحيل')),
      );
}
class OpportunitiesScreenPlaceholder extends StatelessWidget {
  const OpportunitiesScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الفرص — قيد الترحيل')),
      );
}
class AddOpportunityScreenPlaceholder extends StatelessWidget {
  const AddOpportunityScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة فرصة — قيد الترحيل')),
      );
}
class OpportunityDetailScreenPlaceholder extends StatelessWidget {
  const OpportunityDetailScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('تفاصيل الفرصة — قيد الترحيل')),
      );
}
class PipelineScreenPlaceholder extends StatelessWidget {
  const PipelineScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('أنبوب المبيعات — قيد الترحيل')),
      );
}
class ProductsScreenPlaceholder extends StatelessWidget {
  const ProductsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('المنتجات — قيد الترحيل')),
      );
}
class AddProductScreenPlaceholder extends StatelessWidget {
  const AddProductScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة منتج — قيد الترحيل')),
      );
}
class ProductDetailScreenPlaceholder extends StatelessWidget {
  const ProductDetailScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('تفاصيل المنتج — قيد الترحيل')),
      );
}
class PriceListScreenPlaceholder extends StatelessWidget {
  const PriceListScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('قائمة الأسعار — قيد الترحيل')),
      );
}
class QuotationsScreenPlaceholder extends StatelessWidget {
  const QuotationsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('العروض — قيد الترحيل')),
      );
}
class AddQuotationScreenPlaceholder extends StatelessWidget {
  const AddQuotationScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة عرض — قيد الترحيل')),
      );
}
class QuotationDetailScreenPlaceholder extends StatelessWidget {
  const QuotationDetailScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('تفاصيل العرض — قيد الترحيل')),
      );
}
class JobOrdersScreenPlaceholder extends StatelessWidget {
  const JobOrdersScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('أوامر التشغيل — قيد الترحيل')),
      );
}
class JobOrderDetailScreenPlaceholder extends StatelessWidget {
  const JobOrderDetailScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('تفاصيل أمر التشغيل — قيد الترحيل')),
      );
}
class TasksScreenPlaceholder extends StatelessWidget {
  const TasksScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('المهمات — قيد الترحيل')),
      );
}
class AddTaskScreenPlaceholder extends StatelessWidget {
  const AddTaskScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة مهمة — قيد الترحيل')),
      );
}
class FollowUpsScreenPlaceholder extends StatelessWidget {
  const FollowUpsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('المتابعات — قيد الترحيل')),
      );
}
class AddInteractionScreenPlaceholder extends StatelessWidget {
  const AddInteractionScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة تفاعل — قيد الترحيل')),
      );
}
class ComplaintsScreenPlaceholder extends StatelessWidget {
  const ComplaintsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الشكاوى — قيد الترحيل')),
      );
}
class AddComplaintScreenPlaceholder extends StatelessWidget {
  const AddComplaintScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة شكوى — قيد الترحيل')),
      );
}
class ComplaintDetailScreenPlaceholder extends StatelessWidget {
  const ComplaintDetailScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('تفاصيل الشكوى — قيد الترحيل')),
      );
}
class ExpensesScreenPlaceholder extends StatelessWidget {
  const ExpensesScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('المصروفات — قيد الترحيل')),
      );
}
class AddExpenseScreenPlaceholder extends StatelessWidget {
  const AddExpenseScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة مصروف — قيد الترحيل')),
      );
}
class ExpenseDashboardScreenPlaceholder extends StatelessWidget {
  const ExpenseDashboardScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('لوحة المصروفات — قيد الترحيل')),
      );
}
class AttendanceScreenPlaceholder extends StatelessWidget {
  const AttendanceScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الحضور — قيد الترحيل')),
      );
}
class EmployeesScreenPlaceholder extends StatelessWidget {
  const EmployeesScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الموظفين — قيد الترحيل')),
      );
}
class AddEmployeeScreenPlaceholder extends StatelessWidget {
  const AddEmployeeScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة موظف — قيد الترحيل')),
      );
}
class ShiftsScreenPlaceholder extends StatelessWidget {
  const ShiftsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('النوبات — قيد الترحيل')),
      );
}
class MyScheduleScreenPlaceholder extends StatelessWidget {
  const MyScheduleScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('جدولتي — قيد الترحيل')),
      );
}
class InvoicesScreenPlaceholder extends StatelessWidget {
  const InvoicesScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الفواتير — قيد الترحيل')),
      );
}
class AddInvoiceScreenPlaceholder extends StatelessWidget {
  const AddInvoiceScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إضافة فاتورة — قيد الترحيل')),
      );
}
class InvoiceDetailScreenPlaceholder extends StatelessWidget {
  const InvoiceDetailScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('تفاصيل الفاتورة — قيد الترحيل')),
      );
}
class InventoryScreenPlaceholder extends StatelessWidget {
  const InventoryScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('المخزون — قيد الترحيل')),
      );
}
class StockLevelsScreenPlaceholder extends StatelessWidget {
  const StockLevelsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('مستويات المخزون — قيد الترحيل')),
      );
}
class StockTransactionsScreenPlaceholder extends StatelessWidget {
  const StockTransactionsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('معاملات المخزون — قيد الترحيل')),
      );
}
class WarehousesScreenPlaceholder extends StatelessWidget {
  const WarehousesScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('المخازن — قيد الترحيل')),
      );
}
class CashboxScreenPlaceholder extends StatelessWidget {
  const CashboxScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الخزينة — قيد الترحيل')),
      );
}
class CashboxDashboardScreenPlaceholder extends StatelessWidget {
  const CashboxDashboardScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('لوحة الخزينة — قيد الترحيل')),
      );
}
class CashboxTransactionsScreenPlaceholder extends StatelessWidget {
  const CashboxTransactionsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('معاملات الخزينة — قيد الترحيل')),
      );
}
class CashboxManualScreenPlaceholder extends StatelessWidget {
  const CashboxManualScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الخزينة اليدوية — قيد الترحيل')),
      );
}
class ReportsScreenPlaceholder extends StatelessWidget {
  const ReportsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('التقارير — قيد الترحيل')),
      );
}
class NotificationsScreenPlaceholder extends StatelessWidget {
  const NotificationsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الإشعارات — قيد الترحيل')),
      );
}
class GlobalSearchScreenPlaceholder extends StatelessWidget {
  const GlobalSearchScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('البحث الشامل — قيد الترحيل')),
      );
}
class DeliveryTrackingScreenPlaceholder extends StatelessWidget {
  const DeliveryTrackingScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('تتبع التوصيل — قيد الترحيل')),
      );
}
class PermissionsScreenPlaceholder extends StatelessWidget {
  const PermissionsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الصلاحيات — قيد الترحيل')),
      );
}
class ChangePasswordScreenPlaceholder extends StatelessWidget {
  const ChangePasswordScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('تغيير كلمة المرور — قيد الترحيل')),
      );
}
class CrmSettingsScreenPlaceholder extends StatelessWidget {
  const CrmSettingsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إعدادات CRM — قيد الترحيل')),
      );
}
class UsersAdminScreenPlaceholder extends StatelessWidget {
  const UsersAdminScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('إدارة المستخدمين — قيد الترحيل')),
      );
}
class LostRecoveryScreenPlaceholder extends StatelessWidget {
  const LostRecoveryScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الاسترداد — قيد الترحيل')),
      );
}
class ExemptionsScreenPlaceholder extends StatelessWidget {
  const ExemptionsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الإعفاءات — قيد الترحيل')),
      );
}
class PersonalAccountsScreenPlaceholder extends StatelessWidget {
  const PersonalAccountsScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('الحسابات الشخصية — قيد الترحيل')),
      );
}
