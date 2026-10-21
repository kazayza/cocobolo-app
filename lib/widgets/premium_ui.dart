import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/app_colors.dart';
import '../services/app_text_styles.dart';
import '../services/theme_service.dart';

class PremiumHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final double expandedHeight;

  const PremiumHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.expandedHeight = 132,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.navyDark,
            AppColors.navy,
            AppColors.navyLight,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            left: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: AppColors.gold,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subtitle,
                              style: GoogleFonts.cairo(
                                color: AppColors.goldLight,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              title,
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const PremiumStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 156,
        height: 100,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppColors.premiumSurface(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : AppColors.premiumStroke(isDark),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (selected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTextStyles.headlineSmall(isDark).copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.bodySmall(isDark).copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumStatStrip extends StatelessWidget {
  final List<PremiumStatCard> cards;

  const PremiumStatStrip({
    super.key,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: cards.map((card) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: card,
        )).toList(),
      ),
    );
  }
}

class PremiumFilterField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final bool includeAll;

  const PremiumFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
    this.includeAll = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final effectiveItems = <DropdownMenuItem<T>>[
      if (includeAll)
        DropdownMenuItem<T>(value: null, child: const Text('الكل')),
      ...items,
    ];
    final exists = value == null ||
        effectiveItems.any((item) => item.value == value);

    return DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: exists ? value : null,
      isExpanded: true,
      items: effectiveItems,
      onChanged: onChanged,
      dropdownColor: AppColors.premiumSurface(isDark),
      style: AppTextStyles.bodyMedium(isDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.bodySmall(isDark),
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.goldDark, size: 19)
            : null,
        filled: true,
        fillColor: AppColors.inputFill(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: AppColors.divider(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: AppColors.divider(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

class PremiumFilterGrid extends StatelessWidget {
  final List<Widget> fields;
  final Widget? bottomAction;

  const PremiumFilterGrid({
    super.key,
    required this.fields,
    this.bottomAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.premiumSurface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.premiumStroke(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 700 ? 3 : 2;
              final spacing = 10.0;
              final fieldWidth = (constraints.maxWidth - (cols - 1) * spacing) / cols;
              
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: fields.map((field) => SizedBox(
                  width: fieldWidth,
                  child: field,
                )).toList(),
              );
            },
          ),
          if (bottomAction != null) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: bottomAction!),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.04, end: 0);
  }
}

class PremiumBadge extends StatelessWidget {
  final String label;
  final BadgeType type;
  final IconData? icon;

  const PremiumBadge({
    super.key,
    required this.label,
    required this.type,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (type) {
      case BadgeType.success:
        backgroundColor = AppColors.success.withValues(alpha: isDark ? 0.18 : 0.12);
        textColor = isDark ? AppColors.successLight : AppColors.success;
        borderColor = AppColors.success.withValues(alpha: 0.3);
        break;
      case BadgeType.error:
        backgroundColor = AppColors.error.withValues(alpha: isDark ? 0.18 : 0.12);
        textColor = isDark ? AppColors.errorLight : AppColors.error;
        borderColor = AppColors.error.withValues(alpha: 0.3);
        break;
      case BadgeType.warning:
        backgroundColor = AppColors.warning.withValues(alpha: isDark ? 0.18 : 0.12);
        textColor = isDark ? AppColors.warningLight : AppColors.warning;
        borderColor = AppColors.warning.withValues(alpha: 0.3);
        break;
      case BadgeType.info:
        backgroundColor = AppColors.info.withValues(alpha: isDark ? 0.18 : 0.12);
        textColor = isDark ? AppColors.infoLight : AppColors.info;
        borderColor = AppColors.info.withValues(alpha: 0.3);
        break;
      case BadgeType.neutral:
        backgroundColor = AppColors.neutral.withValues(alpha: isDark ? 0.18 : 0.12);
        textColor = isDark ? AppColors.neutralLight : AppColors.neutral;
        borderColor = AppColors.neutral.withValues(alpha: 0.3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.cairo(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum BadgeType {
  success,
  error,
  warning,
  info,
  neutral,
}

class PremiumActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final ButtonStyleType style;
  final Color? color;

  const PremiumActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.style = ButtonStyleType.solid,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _getBackgroundColor(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getBorderColor(isDark)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _getIconColor(isDark)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: _getTextColor(isDark),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isDark) {
    switch (style) {
      case ButtonStyleType.solid:
        return color ?? AppColors.navy;
      case ButtonStyleType.soft:
        return (color ?? AppColors.navy).withValues(alpha: 0.12);
      case ButtonStyleType.ghost:
        return Colors.transparent;
    }
  }

  Color _getBorderColor(bool isDark) {
    switch (style) {
      case ButtonStyleType.solid:
        return Colors.transparent;
      case ButtonStyleType.soft:
        return (color ?? AppColors.navy).withValues(alpha: 0.3);
      case ButtonStyleType.ghost:
        return (color ?? AppColors.navy).withValues(alpha: 0.3);
    }
  }

  Color _getIconColor(bool isDark) {
    switch (style) {
      case ButtonStyleType.solid:
        return Colors.white;
      case ButtonStyleType.soft:
      case ButtonStyleType.ghost:
        return color ?? (isDark ? AppColors.goldDark : AppColors.navy);
    }
  }

  Color _getTextColor(bool isDark) {
    switch (style) {
      case ButtonStyleType.solid:
        return Colors.white;
      case ButtonStyleType.soft:
      case ButtonStyleType.ghost:
        return color ?? (isDark ? AppColors.goldDark : AppColors.navy);
    }
  }
}

enum ButtonStyleType {
  solid,
  soft,
  ghost,
}

class Responsive {
  final double maxWidth;
  
  Responsive._(this.maxWidth);
  
  static Responsive of(BuildContext context) {
    return Responsive._(MediaQuery.of(context).size.width);
  }
  
  bool get isMobile => maxWidth < 600;
  bool get isTablet => maxWidth >= 600 && maxWidth < 1024;
  bool get isDesktop => maxWidth >= 1024;
  
  int get filterColumns => maxWidth >= 700 ? 3 : 2;
  int get statColumns => maxWidth >= 1000 ? 4 : (maxWidth >= 700 ? 3 : 2);
  
  double get horizontalPadding => maxWidth >= 1024 ? 24 : 16;
}