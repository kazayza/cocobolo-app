import 'package:flutter/material.dart';

import '../../../services/permission_service.dart';

class HomeDashboardConfig {
  final List<HomeDashboardCard> cards;

  const HomeDashboardConfig({
    required this.cards,
  });

  factory HomeDashboardConfig.fromPermissions(
    PermissionService permissions,
  ) {
    final cards = <HomeDashboardCard>[];

    // =========================
    // SALES / CRM
    // =========================

    if (permissions.canView(FormNames.partiesList)) {
      cards.add(
        const HomeDashboardCard(
          id: 'clients',
          title: 'العملاء',
          subtitle: 'إجمالي العملاء',
          icon: Icons.people_alt_rounded,
          type: HomeDashboardCardType.clients,
          permission: FormNames.partiesList,
        ),
      );
    }

    if (permissions.canView(FormNames.managerSales)) {
      cards.add(
        const HomeDashboardCard(
          id: 'opportunities',
          title: 'الفرص',
          subtitle: 'فرص البيع',
          icon: Icons.trending_up_rounded,
          type: HomeDashboardCardType.opportunities,
          permission: FormNames.managerSales,
        ),
      );
    }

    if (permissions.canView(FormNames.leadsCrm)) {
      cards.add(
        const HomeDashboardCard(
          id: 'leads',
          title: 'العملاء المحتملين',
          subtitle: 'Leads',
          icon: Icons.campaign_rounded,
          type: HomeDashboardCardType.leads,
          permission: FormNames.leadsCrm,
        ),
      );
    }

    if (permissions.canView(FormNames.crmDashboard)) {
      cards.add(
        const HomeDashboardCard(
          id: 'crm',
          title: 'CRM',
          subtitle: 'لوحة متابعة العملاء',
          icon: Icons.dashboard_rounded,
          type: HomeDashboardCardType.crm,
          permission: FormNames.crmDashboard,
        ),
      );
    }

    if (permissions.canView(FormNames.salesPipeline)) {
      cards.add(
        const HomeDashboardCard(
          id: 'pipeline',
          title: 'مراحل البيع',
          subtitle: 'Sales Pipeline',
          icon: Icons.stacked_line_chart_rounded,
          type: HomeDashboardCardType.pipeline,
          permission: FormNames.salesPipeline,
        ),
      );
    }

    // =========================
    // OPERATIONS
    // =========================

    if (permissions.canView(FormNames.productsList)) {
      cards.add(
        const HomeDashboardCard(
          id: 'inventory',
          title: 'المخزون',
          subtitle: 'المنتجات والأرصدة',
          icon: Icons.inventory_2_rounded,
          type: HomeDashboardCardType.inventory,
          permission: FormNames.productsList,
        ),
      );
    }

    if (permissions.canView(FormNames.priceRequests)) {
      cards.add(
        const HomeDashboardCard(
          id: 'price_requests',
          title: 'طلبات الأسعار',
          subtitle: 'طلبات تحتاج متابعة',
          icon: Icons.request_quote_rounded,
          type: HomeDashboardCardType.priceRequests,
          permission: FormNames.priceRequests,
        ),
      );
    }

    // =========================
    // FINANCE
    // =========================

    if (permissions.canView(FormNames.expensesList)) {
      cards.add(
        const HomeDashboardCard(
          id: 'expenses',
          title: 'المصروفات',
          subtitle: 'المصروفات الحالية',
          icon: Icons.account_balance_wallet_rounded,
          type: HomeDashboardCardType.expenses,
          permission: FormNames.expensesList,
        ),
      );
    }

    // =========================
    // HR
    // =========================

    if (permissions.canView(FormNames.employeesList)) {
      cards.add(
        const HomeDashboardCard(
          id: 'employees',
          title: 'الموظفين',
          subtitle: 'الموارد البشرية',
          icon: Icons.badge_rounded,
          type: HomeDashboardCardType.employees,
          permission: FormNames.employeesList,
        ),
      );
    }

    // =========================
    // TASKS / FOLLOW UPS
    // =========================

    if (permissions.canView(FormNames.dailyTasks)) {
      cards.add(
        const HomeDashboardCard(
          id: 'tasks',
          title: 'مهامي اليوم',
          subtitle: 'المهام والمتابعات',
          icon: Icons.task_alt_rounded,
          type: HomeDashboardCardType.tasks,
          permission: FormNames.dailyTasks,
        ),
      );
    }

    return HomeDashboardConfig(cards: cards);
  }

  bool hasCard(String id) {
    return cards.any((card) => card.id == id);
  }
}


enum HomeDashboardCardType {
  clients,
  opportunities,
  leads,
  crm,
  pipeline,
  inventory,
  priceRequests,
  expenses,
  employees,
  tasks,
}


class HomeDashboardCard {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final HomeDashboardCardType type;
  final String permission;
  final int priority;

  const HomeDashboardCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
    required this.permission,
    this.priority = 0,
  });
}