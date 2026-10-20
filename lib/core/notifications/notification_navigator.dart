import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'blazor_form_routes.dart';
import '../network/api_client.dart';
import '../../services/permission_service.dart';
import '../../screens/add_expense_screen.dart';
import '../../screens/attendance_screen.dart';
import '../../screens/cashbox/cashbox_dashboard_screen.dart';
import '../../screens/cashbox_manual_screen.dart';
import '../../screens/cashbox_transactions_screen.dart';
import '../../screens/clients_screen.dart';
import '../../screens/complaint_details_screen.dart';
import '../../screens/complaints_screen.dart';
import '../../screens/delivery_tracking_screen.dart';
import '../../screens/expenses/expense_dashboard_screen.dart';
import '../../screens/lead_detail_screen.dart';
import '../../screens/leads_screen.dart';
import '../../screens/my_schedule_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../screens/opportunities_screen.dart';
import '../../screens/opportunity_detail_screen.dart';
import '../../screens/permissions_list_screen.dart';
import '../../screens/pipeline_screen.dart';
import '../../screens/price_requests_screen.dart';
import '../../screens/price_list_screen.dart';
import '../../screens/quotations_screen.dart';
import '../../screens/quotation_details_screen.dart';
import '../../screens/job_orders_screen.dart';
import '../../screens/job_order_details_screen.dart';
import '../../screens/pricing_margins_screen.dart';
import '../../screens/products_screen.dart';
import '../../screens/product_details_screen.dart';
import '../../screens/client_card_screen.dart';
import '../../screens/delivery_details_screen.dart';
import '../../screens/invoice/invoice_details_screen.dart';
import '../../screens/followups_screen.dart';
import '../../screens/general_tasks_screen.dart';
import '../../screens/invoice/invoices_list_screen.dart';
import '../../screens/closure_approval_requests_screen.dart'
    show ClosureApprovalRequestsScreen;
import '../../screens/lost_recovery_screen.dart';
import '../../screens/lost_recovery_report_screen.dart';
import '../../screens/inventory/stock_transactions_screen.dart';
import '../../screens/inventory/warehouses_screen.dart';
import '../../screens/inventory/stock_transfer_screen.dart';
import 'notification_access_denied_screen.dart';

/// Opens the correct Flutter screen from a notification payload.
/// FormName keys follow **Blazor** naming; this file only maps.
class NotificationNavigator {
  NotificationNavigator._();

  static const _pendingKey = 'pending_notification_payload';
  static String? _lastPayload;
  static DateTime? _lastHandledAt;
  static bool _opening = false;

  static Future<void> queuePayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, payload);
  }

  static Future<void> flushPending(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = prefs.getString(_pendingKey);
    if (payload == null || payload.isEmpty) return;
    await openFromPayload(navigatorKey, payload, fromPending: true);
  }

  /// يعمل في الحالات الثلاث: Foreground / Background / Terminated.
  /// لو الـNavigator أو الجلسة غير جاهزين، يحتفظ بالـpayload ويفتحه بعد تسجيل الدخول.
  static Future<void> openFromPayload(
    GlobalKey<NavigatorState> navigatorKey,
    String? payload, {
    bool fromPending = false,
  }) async {
    if (payload == null || payload.trim().isEmpty || _opening) return;

    final now = DateTime.now();
    if (_lastPayload == payload &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 2)) {
      return;
    }

    try {
      final dynamic decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') == true;
      final userId = prefs.getInt('userId') ?? 0;
      final username = prefs.getString('username') ?? '';
      final nav = navigatorKey.currentState;

      if (!isLoggedIn || userId <= 0 || username.isEmpty || nav == null) {
        await queuePayload(payload);
        return;
      }

      _opening = true;
      final formName = (data['formName'] ?? data['FormName'])?.toString();
      final relatedTable =
          (data['relatedTable'] ?? data['RelatedTable'])?.toString();
      final relatedId =
          data['relatedId'] ?? data['RelatedID'] ?? data['relatedID'];

      final decision = BlazorNotificationRouter.resolve(
        formName: formName,
        relatedTable: relatedTable,
        relatedId: relatedId,
      );

      final page = _isAllowed(decision)
          ? _buildPage(decision, userId: userId, username: username)
          : const NotificationAccessDeniedScreen();

      // تعليم الإشعار كمقروء لا يعطل فتح الشاشة لو الشبكة فشلت.
      final notificationId = int.tryParse(
        (data['notificationId'] ?? data['NotificationID'] ?? '').toString(),
      );
      if (notificationId != null && notificationId > 0) {
        try {
          await ApiClient.instance.put(
            '/api/notifications/$notificationId/read',
          );
        } catch (_) {}
      }

      await prefs.remove(_pendingKey);
      _lastPayload = payload;
      _lastHandledAt = DateTime.now();
      nav.push(MaterialPageRoute(builder: (_) => page));
    } catch (e) {
      print('NotificationNavigator error: $e');
      if (!fromPending) await queuePayload(payload);
    } finally {
      _opening = false;
    }
  }

  static bool _isAllowed(NotifRouteDecision d) {
    final p = PermissionService();
    switch (d.target) {
      case MobileNotifTarget.lostRecovery:
      case MobileNotifTarget.lostRecoveryReport:
        return p.canViewLostRecovery;
      case MobileNotifTarget.priceList:
        return p.canViewPriceList;
      case MobileNotifTarget.quotationsList:
      case MobileNotifTarget.quotationDetail:
        return p.canViewQuotations;
      case MobileNotifTarget.jobOrders:
      case MobileNotifTarget.jobOrderDetail:
        return p.canViewJobOrders;
      case MobileNotifTarget.invoiceDetail:
      case MobileNotifTarget.invoices:
        final raw = (d.rawFormName ?? '').toLowerCase();
        final purchase = raw.contains('purchase') || raw.contains('supplier');
        return purchase ? p.canViewPurchaseInvoices : p.canViewSalesInvoices;
      case MobileNotifTarget.delivery:
      case MobileNotifTarget.deliveryDetail:
        return p.canViewDelivery;
      case MobileNotifTarget.complaintsList:
      case MobileNotifTarget.complaintDetail:
        return p.userId != null; // ComplaintPermissions.CanView
      default:
        return true;
    }
  }

  /// دالة عامة لبناء الشاشة من قرار الراوتر (يستخدمها كمان شاشة الإشعارات)
  static Widget buildPage(
    NotifRouteDecision d, {
    required int userId,
    required String username,
  }) {
    if (!_isAllowed(d)) return const NotificationAccessDeniedScreen();
    return _buildPage(d, userId: userId, username: username);
  }

  static Widget _buildPage(
    NotifRouteDecision d, {
    required int userId,
    required String username,
  }) {
    switch (d.target) {
      case MobileNotifTarget.leadDetail:
        return LeadDetailScreen(
          leadId: d.relatedId ?? 0,
          userId: userId,
          username: username,
        );
      case MobileNotifTarget.leadsList:
        return LeadsScreen(userId: userId, username: username);
      case MobileNotifTarget.opportunityDetail:
        return OpportunityDetailScreen(
          opportunityId: d.relatedId ?? 0,
          userId: userId,
          username: username,
        );
      case MobileNotifTarget.opportunitiesList:
        return OpportunitiesScreen(userId: userId, username: username);
      case MobileNotifTarget.expensesAdd:
        return AddExpenseScreen(
          username: username,
          expenseId: d.relatedId,
        );
      case MobileNotifTarget.expensesList:
        return ExpenseDashboardScreen(userId: userId, username: username);
      case MobileNotifTarget.products:
        return ProductsScreen(userId: userId, username: username);
      case MobileNotifTarget.productDetail:
        return ProductDetailsScreen(
          productId: d.relatedId ?? 0,
          username: username,
        );
      case MobileNotifTarget.priceRequests:
        return PriceRequestsScreen(username: username);
      case MobileNotifTarget.priceList:
        return PriceListScreen(userId: userId, username: username);
      case MobileNotifTarget.quotationsList:
        return QuotationsScreen(userId: userId, username: username);
      case MobileNotifTarget.quotationDetail:
        return QuotationDetailsScreen(
          userId: userId,
          username: username,
          quotationId: d.relatedId ?? 0,
        );
      case MobileNotifTarget.jobOrders:
        return JobOrdersScreen(userId: userId, username: username);
      case MobileNotifTarget.jobOrderDetail:
        return JobOrderDetailsScreen(
          userId: userId,
          username: username,
          transactionId: d.relatedId ?? 0,
        );
      case MobileNotifTarget.pricingMargins:
        return PricingMarginsScreen(username: username);
      case MobileNotifTarget.complaintsList:
        return ComplaintsScreen(userId: userId, username: username);
      case MobileNotifTarget.complaintDetail:
        return ComplaintDetailsScreen(
          complaintId: d.relatedId ?? 0,
          userId: userId,
          username: username,
        );
      case MobileNotifTarget.delivery:
        return DeliveryTrackingScreen(userId: userId, username: username);
      case MobileNotifTarget.deliveryDetail:
        return DeliveryDetailsScreen(
          transactionId: d.relatedId ?? 0,
          username: username,
        );
      case MobileNotifTarget.attendance:
        return AttendanceScreen(userId: userId, username: username);
      case MobileNotifTarget.tasks:
        return FollowUpsScreen(userId: userId, username: username);
      case MobileNotifTarget.pipeline:
        return PipelineScreen(userId: userId, username: username);
      case MobileNotifTarget.clients:
        return ClientsScreen(userId: userId, username: username);
      case MobileNotifTarget.clientCard:
        return ClientCardScreen(
          userId: userId,
          username: username,
          initialPartyId: d.relatedId,
        );
      case MobileNotifTarget.cashboxDashboard:
        return CashBoxDashboardScreen(userId: userId, username: username);
      case MobileNotifTarget.cashboxManual:
        return CashboxManualScreen(userId: userId, username: username);
      case MobileNotifTarget.cashboxTransactions:
        return CashboxTransactionsScreen(userId: userId, username: username);
      case MobileNotifTarget.permissions:
        return PermissionsListScreen(userId: userId);
      case MobileNotifTarget.invoices:
        final raw = (d.rawFormName ?? '').toLowerCase();
        final purchase = raw.contains('purchase') || raw.contains('supplier');
        return SalesInvoicesScreen(
          userId: userId,
          username: username,
          initialTab: purchase ? 'Purchase' : 'Sale',
        );
      case MobileNotifTarget.invoiceDetail:
        final raw = (d.rawFormName ?? '').toLowerCase();
        final purchase = raw.contains('purchase') || raw.contains('supplier');
        return InvoiceDetailsScreen(
          transactionId: d.relatedId ?? 0,
          username: username,
          invoiceType: purchase ? 'Purchase' : 'Sale',
        );
      case MobileNotifTarget.closureRequests:
        return ClosureApprovalRequestsScreen(
          userId: userId,
          username: username,
        );
      case MobileNotifTarget.generalTasks:
        return GeneralTasksScreen(
          userId: userId,
          username: username,
        );
      case MobileNotifTarget.lostRecovery:
        return LostRecoveryScreen(
          userId: userId,
          username: username,
        );
      case MobileNotifTarget.lostRecoveryReport:
        return LostRecoveryReportScreen(
          userId: userId,
          username: username,
        );
      case MobileNotifTarget.stockTransactions:
        return StockTransactionsScreen(userId: userId, username: username);
      case MobileNotifTarget.warehouses:
        return WarehousesScreen(userId: userId, username: username);
      case MobileNotifTarget.stockTransfer:
        return StockTransferScreen(userId: userId, username: username);
      case MobileNotifTarget.mySchedule:
        return MyScheduleScreen(userId: userId, username: username);
      case MobileNotifTarget.home:
      case MobileNotifTarget.notifications:
        return NotificationsScreen(userId: userId, username: username);
    }
  }
}
