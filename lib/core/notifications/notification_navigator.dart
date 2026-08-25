import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'blazor_form_routes.dart';
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
import '../../screens/pricing_margins_screen.dart';
import '../../screens/products_screen.dart';
import '../../screens/followups_screen.dart';
import '../../screens/invoice/invoices_list_screen.dart';

/// Opens the correct Flutter screen from a notification payload.
/// FormName keys follow **Blazor** naming; this file only maps.
class NotificationNavigator {
  NotificationNavigator._();

  static Future<void> openFromPayload(
    GlobalKey<NavigatorState> navigatorKey,
    String? payload,
  ) async {
    if (payload == null || payload.isEmpty) return;

    try {
      final dynamic decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);

      final formName = (data['formName'] ?? data['FormName'])?.toString();
      final relatedTable =
          (data['relatedTable'] ?? data['RelatedTable'])?.toString();
      final relatedId = data['relatedId'] ?? data['RelatedID'] ?? data['relatedID'];

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'User';
      final userId = prefs.getInt('userId') ?? 0;

      final decision = BlazorNotificationRouter.resolve(
        formName: formName,
        relatedTable: relatedTable,
        relatedId: relatedId,
      );

      final nav = navigatorKey.currentState;
      if (nav == null) return;

      final page = _buildPage(decision, userId: userId, username: username);
      nav.push(MaterialPageRoute(builder: (_) => page));
    } catch (e) {
      print('NotificationNavigator error: $e');
    }
  }

  /// دالة عامة لبناء الشاشة من قرار الراوتر (يستخدمها كمان شاشة الإشعارات)
  static Widget buildPage(
    NotifRouteDecision d, {
    required int userId,
    required String username,
  }) {
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
      case MobileNotifTarget.priceRequests:
        return PriceRequestsScreen(username: username);
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
      case MobileNotifTarget.attendance:
        return AttendanceScreen(userId: userId, username: username);
      case MobileNotifTarget.tasks:
        return FollowUpsScreen(userId: userId, username: username);
      case MobileNotifTarget.pipeline:
        return PipelineScreen(userId: userId, username: username);
      case MobileNotifTarget.clients:
        return ClientsScreen(userId: userId, username: username);
      case MobileNotifTarget.clientCard:
        // Fallback to clients list if card needs more args
        return ClientsScreen(userId: userId, username: username);
      case MobileNotifTarget.cashboxDashboard:
        return CashBoxDashboardScreen(userId: userId, username: username);
      case MobileNotifTarget.cashboxManual:
        return CashboxManualScreen(userId: userId, username: username);
      case MobileNotifTarget.cashboxTransactions:
        return CashboxTransactionsScreen(userId: userId, username: username);
      case MobileNotifTarget.permissions:
        return PermissionsListScreen(userId: userId);
      case MobileNotifTarget.invoices:
        return SalesInvoicesScreen(
          userId: userId,
          username: username,
          initialTab: 'Sale',
        );
      case MobileNotifTarget.mySchedule:
        return MyScheduleScreen(userId: userId, username: username);
      case MobileNotifTarget.home:
      case MobileNotifTarget.notifications:
        return NotificationsScreen(userId: userId, username: username);
    }
  }
}
