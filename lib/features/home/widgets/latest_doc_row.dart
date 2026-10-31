import 'package:flutter/material.dart';

import '../../../services/app_colors.dart';
import '../../../widgets/design_kit.dart';
import 'home_accent.dart';

/// صف وثيقة احترافي موحّد لأقسام «آخر …» في الرئيسية (فواتير/عروض):
/// لوحة فرعية داخل البطاقة الأم (درجة أغمق منها في الوضعين —
/// panel-in-panel)، رقاقة أيقونة متدرّجة بلون القسم المميز، سطر
/// أساسي للطرف وسطر ثانوي للرقم والتاريخ، والمبلغ مع شارة الحالة
/// في الطرف المقابل. البيانات والإجراءات يمرّرها القسم كما هي —
/// هذا الصف عرضٌ فقط.
class LatestDocRow extends StatelessWidget {
  const LatestDocRow({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String amount;
  final Widget badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        // لوحة فرعية: خطوة أغمق من البطاقة الأم في الوضعين
        color: isDark ? AppColors.surface(true) : AppColors.inputFill(false),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.premiumStroke(isDark)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // رقاقة أيقونة متدرّجة — لغة بطاقة CRM نفسها
                Container(
                  width: 44,
                  height: 44,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(value: amount, size: 14),
                    const SizedBox(height: 5),
                    badge,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
