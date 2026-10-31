import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/icon_utils.dart';
import 'app_states.dart' show AppLoading, AppEmpty;

/// حالات الشاشة الموحدة تأتي من app_states.dart — تُعاد تصديرها هنا
/// حتى تستورد الشاشات ملفًا واحدًا (النظام + الحالات).
export 'app_states.dart' show AppLoading, AppEmpty, AppError;

/// أسماء النظام للحالات (نفس مكوّنات app_states دون أي تكرار)
typedef AppLoadingState = AppLoading;
typedef AppEmptyState = AppEmpty;

/// ═══════════════════════════════════════════════════════════
///  مكوّنات نظام التصميم — COCOBOLO Design Kit
///  بطاقات وترويسات وشارات وأزرار واحدة لكل التطبيق،
///  مبنية بالكامل على [AppColors] و [AppSpacing] و [AppRadius].
/// ═══════════════════════════════════════════════════════════

/// البطاقة الموحدة: سطح + إطار خفيف + ظل ناعم + نصف قطر XL
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.xl,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // سطح البطاقة: في الوضع الليلي نأخذ لون البطاقة من الهوية مباشرة
    // (AppColors.card = كحلي فاتح) — لا من surfaceContainerLow، لأن
    // ثيم التطبيق مبني بـ ColorScheme.fromSeed بلون ذهبي، فتولّد
    // حاويات الأسطح الليليّة من لوحة الذهبي اللونية فتخرج بُنّية
    // (#201B13) مناقضة لبقية الأسطح الكحلية. النهاري يبقى كما هو.
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ??
            (isDark
                ? AppColors.card(true)
                : theme.colorScheme.surfaceContainerLow),
        borderRadius: AppRadius.all(radius),
        border: Border.all(
          color: isDark
              ? AppColors.premiumStroke(true)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.all(radius),
      child: card,
    );
  }
}

/// ترويسة قسم موحدة: شريط ملوّن + أيقونة اختيارية + عنوان + وصف + طرف
/// (نفس لغة ترويسة الرئيسية وتفاصيل الفاتورة — بصمة العلامة)
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accent;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accent = AppColors.gold,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        if (icon != null) ...[
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// بطاقة إحصائية صغيرة موحدة (قيمة ملوّنة + تسمية) — نمط قوائم الفواتير
class AppStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String? tooltip;
  final bool selected;
  final VoidCallback? onTap;

  const AppStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.tooltip,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.18)
            : (theme.brightness == Brightness.dark
                ? AppColors.card(true)
                : theme.colorScheme.surfaceContainerLow),
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(
          color: selected
              ? color
              : (theme.brightness == Brightness.dark
                  ? AppColors.premiumStroke(true)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 3),
          // القيمة تُصغَّر عند ضيق البطاقة بدل أن تُقتطع بنقاط (…)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AmountText(value: value, color: color, size: 14),
          ),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final tappable = GestureDetector(onTap: onTap, child: content);
    if (tooltip == null) return tappable;
    return Tooltip(message: tooltip!, child: tappable);
  }
}

/// شارة حالة موحدة — نسخة ناعمة (خلفية ملوّنة خفيفة) أو ممتلئة (لون صلب)
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;
  final bool small;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: AppRadius.all(AppRadius.pill),
        border:
            filled ? null : Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 11 : 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: small ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// شارة حالة فاتورة — التعريف واللون والنص من [AppStatus.invoiceInfo]
class InvoiceStatusBadge extends StatelessWidget {
  final String? status;
  final bool filled;
  final bool small;

  const InvoiceStatusBadge({
    super.key,
    required this.status,
    this.filled = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = AppStatus.invoiceInfo(status);
    return StatusBadge(
      label: label,
      color: color,
      icon: icon,
      filled: filled,
      small: small,
    );
  }
}

/// نص مبلغ موحد — وزن عريض واحد لكل أرقام الفلوس في التطبيق
class AmountText extends StatelessWidget {
  final String value;
  final double size;
  final Color? color;
  final FontWeight weight;

  const AmountText({
    super.key,
    required this.value,
    this.size = 14,
    this.color,
    this.weight = FontWeight.w900,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// زر أساسي — كحلي ممتلئ
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.md)),
    );

    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// زر ذهبي — للإجراء الأبرز في الشاشة (نص كحلي فوق ذهبي الهوية)
class GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const GoldButton({super.key, required this.label, this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.navy,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.md)),
    );

    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// رقاقة أيقونة إجراء موحدة — أيقونة بلون الإجراء فوق ظل ناعم من
/// اللون نفسه (المعالجة الوحيدة لأيقونات إجراءات التواصل في الكروت:
/// اتصال/واتساب/نسخ...). الحجم القياسي للشعار 16 والحشوة 6.
class AppIconChip extends StatelessWidget {
  final dynamic icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  const AppIconChip({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 16,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chip = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: AppRadius.all(AppRadius.xs),
        ),
        child: compatIcon(icon, size: size, color: color),
      ),
    );

    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}

/// رقاقة واتساب الرسمية — شعار واتساب (FontAwesome) بأخضر العلامة
/// [AppColors.whatsapp] فوق ظل ناعم منه. هذه هي المعالجة الوحيدة
/// المعتمدة لأي إجراء يفتح واتساب في كروت العملاء/الفرص/الليدز.
class WhatsAppChip extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const WhatsAppChip({super.key, required this.onTap, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return AppIconChip(
      icon: FontAwesomeIcons.whatsapp,
      color: AppColors.whatsapp,
      size: size,
      tooltip: 'واتساب',
      onTap: onTap,
    );
  }
}

/// زر إجراء ناعم ملوّن بعرض كامل — نمط أزرار تفاصيل الفاتورة
/// (خلفية ملوّنة خفيفة + إطار + نص وأيقونة بلون الإجراء)
class AppButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const AppButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: AppRadius.all(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.all(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.all(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
