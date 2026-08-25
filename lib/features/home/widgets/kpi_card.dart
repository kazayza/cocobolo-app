import 'package:flutter/material.dart';

import 'home_accent.dart';
import 'sparkline.dart';

/// بطاقة مؤشر (KPI) مطوّرة:
/// - لون مميز لكل مؤشر + تدرج للأيقونة
/// - Chip اختياري (تنبيه/عداد) أو نسبة تغيّر
/// - متوافقة مع الاستخدام القديم (كل المعاملات الاختيارية)
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final double? percentage;
  final VoidCallback? onTap;
  final Color? accent;
  final String? chipText;
  final Color? chipColor;
  final List<double>? trend;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.percentage,
    this.onTap,
    this.accent,
    this.chipText,
    this.chipColor,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = this.accent ?? theme.colorScheme.primary;
    final surface = HomeAccent.tintedSurface(context, accent);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: HomeAccent.border(context, accent)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: HomeAccent.gradient(accent),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const Spacer(),
                  if (percentage != null)
                    _PercentageBadge(percentage: percentage!),
                  if (chipText != null && percentage == null)
                    _Chip(text: chipText!, color: chipColor ?? accent),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
              // ── مؤشر بياني صغير (آخر 7 أيام) ────────────
              if (trend != null && trend!.length >= 2) ...[
                const SizedBox(height: 6),
                Sparkline(
                  data: trend!,
                  color: accent,
                  height: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PercentageBadge extends StatelessWidget {
  final double percentage;

  const _PercentageBadge({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final isPositive = percentage >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isPositive
            ? Colors.green.withValues(alpha: .12)
            : Colors.red.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${isPositive ? '+' : ''}${percentage.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;

  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
