import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/home_provider.dart';
import 'home_accent.dart';

/// بطاقة CRM — ملخص الليدز والمتابعات + رسم Donut حقيقي
/// محسّنة: Donut أكبر مع الإجمالي في المنتصف + أشرطة تقدم لكل فئة
class CrmSummaryCard extends StatelessWidget {
  final VoidCallback? onTap;

  const CrmSummaryCard({super.key, this.onTap});

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HomeProvider>();
    final summary = provider.summary;

    final leads = _toInt(summary['leads']);
    final total = _toInt(summary['followUpsTotal']);
    final overdue = _toInt(summary['followUpsOverdue']);
    final today = _toInt(summary['followUpsToday']);
    final tomorrow = _toInt(summary['followUpsTomorrow']);

    final counted = overdue + today + tomorrow;
    final rest = total > counted ? total - counted : 0;
    final hasDonut = total > 0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: HomeAccent.tintedSurface(context, HomeAccent.indigo),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: HomeAccent.border(context, HomeAccent.indigo)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: HomeAccent.gradient(HomeAccent.indigo),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.hub_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إدارة علاقات العملاء',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'متابعة الليدز والمتابعات والفرص',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── المؤشرات الثلاثة ───────────────────────
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      title: 'Leads',
                      value: leads,
                      color: HomeAccent.indigo,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      title: 'المتابعات',
                      value: total,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      title: 'متأخرة',
                      value: overdue,
                      isAlert: overdue > 0,
                    ),
                  ),
                ],
              ),

              if (hasDonut) ...[
                const SizedBox(height: 18),
                Divider(
                  height: 1,
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),

                // ── الجزء البياني: Donut + أشرطة تقدم ────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Donut مع الإجمالي في المنتصف
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _DonutChart(
                            overdue: overdue,
                            today: today,
                            tomorrow: tomorrow,
                            rest: rest,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$total',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'متابعة',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 18),

                    // أشرطة التقدم لكل فئة
                    Expanded(
                      child: Column(
                        children: [
                          _ProgressBar(
                            label: 'متأخرة',
                            value: overdue,
                            total: total,
                            color: const Color(0xFFE53935),
                          ),
                          const SizedBox(height: 10),
                          _ProgressBar(
                            label: 'اليوم',
                            value: today,
                            total: total,
                            color: HomeAccent.gold,
                          ),
                          const SizedBox(height: 10),
                          _ProgressBar(
                            label: 'غداً',
                            value: tomorrow,
                            total: total,
                            color: const Color(0xFFFFA726),
                          ),
                          if (rest > 0) ...[
                            const SizedBox(height: 10),
                            _ProgressBar(
                              label: 'قادمة',
                              value: rest,
                              total: total,
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// المؤشرات
// ═══════════════════════════════════════════════════════════

class _Metric extends StatelessWidget {
  final String title;
  final int value;
  final bool isAlert;
  final Color? color;

  const _Metric({
    required this.title,
    required this.value,
    this.isAlert = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = isAlert
        ? const Color(0xFFE53935)
        : color ?? theme.colorScheme.primary;

    return Column(
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: c,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// شريط تقدم أفقي لكل فئة
// ═══════════════════════════════════════════════════════════

class _ProgressBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.08,
              ),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Donut Chart
// ═══════════════════════════════════════════════════════════

class _DonutChart extends StatelessWidget {
  final int overdue;
  final int today;
  final int tomorrow;
  final int rest;

  const _DonutChart({
    required this.overdue,
    required this.today,
    required this.tomorrow,
    required this.rest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sections = <PieChartSectionData>[
      if (overdue > 0)
        PieChartSectionData(
          value: overdue.toDouble(),
          color: const Color(0xFFE53935),
          radius: 16,
          showTitle: false,
        ),
      if (today > 0)
        PieChartSectionData(
          value: today.toDouble(),
          color: HomeAccent.gold,
          radius: 16,
          showTitle: false,
        ),
      if (tomorrow > 0)
        PieChartSectionData(
          value: tomorrow.toDouble(),
          color: const Color(0xFFFFA726),
          radius: 16,
          showTitle: false,
        ),
      if (rest > 0)
        PieChartSectionData(
          value: rest.toDouble(),
          color: theme.colorScheme.outlineVariant,
          radius: 16,
          showTitle: false,
        ),
    ];

    return PieChart(
      PieChartData(sectionsSpace: 3, centerSpaceRadius: 42, sections: sections),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }
}
