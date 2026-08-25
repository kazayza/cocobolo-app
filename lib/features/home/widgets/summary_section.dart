import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../services/permission_service.dart';
import '../models/home_dashboard_config.dart';
import '../providers/home_provider.dart';
import 'home_accent.dart';
import 'sparkline.dart';
import 'kpi_card.dart';
import 'section_header.dart';

/// ملخص الأعمال — شبكة مؤشرات مبنية بالكامل على الصلاحيات:
/// - بطاقات الوحدات تظهر حسب صلاحيات المستخدم (من config)
/// - المؤشرات المالية (مبيعات/مشتريات) حسب الدور فقط
/// - مؤشر لا يظهر إلا إذا كانت البيانات موجودة فعلًا
class SummarySection extends StatelessWidget {
  final HomeDashboardConfig config;

  const SummarySection({super.key, required this.config});

  static final NumberFormat _fmt = NumberFormat('#,##0');

  static String _num(dynamic v) {
    if (v == null) return '--';
    if (v is num) return _fmt.format(v);
    final s = v.toString();
    return s.isEmpty ? '--' : s;
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  KpiCard? _kpiFor(
    HomeDashboardCard card,
    Map<String, dynamic> summary,
    HomeProvider provider,
  ) {
    final accent = HomeAccent.of(card.type);

    switch (card.type) {
      case HomeDashboardCardType.clients:
        if (!summary.containsKey('totalClients')) return null;
        return KpiCard(
          title: 'العملاء',
          value: _num(summary['totalClients']),
          subtitle: 'إجمالي العملاء',
          icon: card.icon,
          accent: accent,
          trend: parseTrend(summary['clientsTrend7']),
        );

      case HomeDashboardCardType.leads:
        if (!summary.containsKey('leads')) return null;
        final overdue = _toInt(summary['followUpsOverdue']);
        return KpiCard(
          title: 'العملاء المحتملين',
          value: _num(summary['leads']),
          subtitle: 'Leads',
          icon: card.icon,
          accent: accent,
          trend: parseTrend(summary['leadsTrend7']),
          chipText: overdue > 0 ? '${_fmt.format(overdue)} متأخرة' : null,
          chipColor: overdue > 0 ? const Color(0xFFE53935) : null,
        );

      case HomeDashboardCardType.opportunities:
        if (!summary.containsKey('opportunities')) return null;
        return KpiCard(
          title: 'الفرص',
          value: _num(summary['opportunities']),
          subtitle: 'فرص البيع',
          icon: card.icon,
          accent: accent,
        );

      case HomeDashboardCardType.inventory:
        if (!summary.containsKey('inventory')) return null;
        return KpiCard(
          title: 'المخزون',
          value: _num(summary['inventory']),
          subtitle: 'المنتجات والأرصدة',
          icon: card.icon,
          accent: accent,
        );

      case HomeDashboardCardType.expenses:
        if (!summary.containsKey('expenses')) return null;
        return KpiCard(
          title: 'المصروفات',
          value: _num(summary['expenses']),
          subtitle: 'إجمالي المصروفات',
          icon: card.icon,
          accent: accent,
        );

      case HomeDashboardCardType.employees:
        if (!summary.containsKey('employees')) return null;
        return KpiCard(
          title: 'الموظفين',
          value: _num(summary['employees']),
          subtitle: 'الموارد البشرية',
          icon: card.icon,
          accent: accent,
        );

      case HomeDashboardCardType.tasks:
        final urgent = provider.urgentTasks.length;
        final today = summary['tasksToday'];
        if (urgent == 0 && !summary.containsKey('tasksToday')) return null;
        return KpiCard(
          title: 'مهام اليوم',
          value: _num(today ?? urgent),
          subtitle: 'مهام ومتابعات',
          icon: card.icon,
          accent: accent,
          trend: parseTrend(summary['tasksTrend7']),
          chipText: urgent > 0 ? '${_fmt.format(urgent)} عاجلة' : null,
          chipColor: urgent > 0 ? const Color(0xFFE53935) : null,
        );

      // هذه الأنواع تُعرض في الوحدات أو قسم CRM
      case HomeDashboardCardType.crm:
      case HomeDashboardCardType.pipeline:
      case HomeDashboardCardType.priceRequests:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final summary = provider.summary;
    final permissions = PermissionService();

    final cards = <KpiCard>[];

    for (final card in config.cards) {
      final kpi = _kpiFor(card, summary, provider);
      if (kpi != null) cards.add(kpi);
    }

    // ملاحظة: المؤشرات المالية (خزينة/مبيعات/مصروفات الشهر)
    // أصبحت في FinanceCarousel أعلى الشاشة — هنا مؤشرات الكميات فقط

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'مؤشرات', subtitle: 'حسب صلاحياتك'),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final columns = width >= 1400
                ? 5
                : width >= 1100
                ? 4
                : width >= 700
                ? 3
                : 2;

            return GridView.builder(
              itemCount: cards.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) => cards[index],
            );
          },
        ),
      ],
    );
  }
}
