import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/home_provider.dart';
import 'home_accent.dart';
import 'section_header.dart';

/// آخر العمليات — نشاط حي على النظام
class ActivitiesSection extends StatelessWidget {
  const ActivitiesSection({super.key});

  static final NumberFormat _fmt = NumberFormat('#,##0');

  static String _amount(dynamic v) {
    if (v == null) return '';
    if (v is num) return _fmt.format(v);
    final s = v.toString();
    return s.isEmpty ? '' : s;
  }

  static String _date(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == -1) return 'أمس';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HomeProvider>();
    final activities = provider.recentActivities;

    if (activities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'آخر العمليات',
          subtitle: 'أحدث الحركات على النظام',
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: HomeAccent.tintedSurface(context, HomeAccent.gold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: HomeAccent.border(context, HomeAccent.gold)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < activities.length && i < 6; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 60,
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: HomeAccent.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: HomeAccent.gold,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    activities[i].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    [
                      activities[i].description,
                      _date(activities[i].date),
                    ]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: activities[i].amount != null
                      ? Text(
                          _amount(activities[i].amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: HomeAccent.gold,
                          ),
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
