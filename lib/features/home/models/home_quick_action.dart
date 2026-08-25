import 'package:flutter/material.dart';

import '../../../services/permission_service.dart';

class HomeQuickAction {
  final String title;
  final String action;
  final IconData icon;

  const HomeQuickAction({
    required this.title,
    required this.action,
    required this.icon,
  });

  static List<HomeQuickAction> available(
    PermissionService permissions, {
    int? employeeId,
  }) {
    final actions = <HomeQuickAction>[];

    // تسجيل الحضور — للموظف المرتبط فقط (مش لأي حد)
    if (employeeId != null &&
        (permissions.canView(FormNames.empAttendance) || permissions.isAdmin)) {
      actions.add(
        const HomeQuickAction(
          title: 'تسجيل الحضور',
          action: 'attendance',
          icon: Icons.fingerprint_rounded,
        ),
      );
    }

    // إضافة عميل
    if (permissions.canAdd(FormNames.partiesAdd)) {
      actions.add(
        const HomeQuickAction(
          title: 'إضافة عميل',
          action: 'add_client',
          icon: Icons.person_add_alt_1_rounded,
        ),
      );
    }

    // إضافة Lead
    if (permissions.canAdd(FormNames.leadsCrm)) {
      actions.add(
        const HomeQuickAction(
          title: 'إضافة Lead',
          action: 'add_lead',
          icon: Icons.person_search_rounded,
        ),
      );
    }

    // إضافة Opportunity
    if (permissions.canAdd(FormNames.editOpportunity)) {
      actions.add(
        const HomeQuickAction(
          title: 'فرصة جديدة',
          action: 'add_opportunity',
          icon: Icons.trending_up_rounded,
        ),
      );
    }

    // إضافة مصروف
    if (permissions.canAdd(FormNames.expensesAdd)) {
      actions.add(
        const HomeQuickAction(
          title: 'إضافة مصروف',
          action: 'add_expense',
          icon: Icons.account_balance_wallet_rounded,
        ),
      );
    }

    // إضافة مهمة
    if (permissions.canAdd(FormNames.dailyTasks)) {
      actions.add(
        const HomeQuickAction(
          title: 'إضافة مهمة',
          action: 'add_task',
          icon: Icons.add_task_rounded,
        ),
      );
    }

    // شكوى جديدة
    if (permissions.canAdd(FormNames.complaintsMain)) {
      actions.add(
        const HomeQuickAction(
          title: 'شكوى جديدة',
          action: 'add_complaint',
          icon: Icons.report_problem_rounded,
        ),
      );
    }

    // متابعة التسليم
    if (permissions.canView(FormNames.invoiceDeliveryStatus)) {
      actions.add(
        const HomeQuickAction(
          title: 'متابعة التسليم',
          action: 'delivery_tracking',
          icon: Icons.local_shipping_rounded,
        ),
      );
    }

    // المتابعات (ليدز + CRM معاً)
    if (permissions.canView(FormNames.dailyTasks) ||
        permissions.canView(FormNames.leadsCrm)) {
      actions.add(
        const HomeQuickAction(
          title: 'المتابعات',
          action: 'follow_ups',
          icon: Icons.event_available_rounded,
        ),
      );
    }

    return actions;
  }
}
