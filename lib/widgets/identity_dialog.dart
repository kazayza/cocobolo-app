import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';

/// هيكل الحوارات الموحّد بهوية التطبيق: شريط ترويسة كحلي متدرج بأيقونة
/// ذهبية، ومحتوى مبطّن بسخاء، وشريط إجراءات سفلي لاصق (حفظ = حبة
/// ممتلئة، تراجع = مفرّغة)، ونصف قطر 18.
/// كل حوار يملك وحدات تحكّمه داخل حالته هو (StatefulWidget) وتُحرَّر
/// في dispose الخاصة بها — لا وحدات تحكّم تُنشأ خارج شجرة الحوار.

class IdentityDialogAction {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// ممتلئ (الإجراء الأساسي) أم مفرّغ (الثانوي)
  final bool filled;

  /// زر خطر (إلغاء/حذف): ممتلئ بلون الخطأ
  final bool danger;

  const IdentityDialogAction({
    required this.label,
    this.icon,
    this.onPressed,
    this.filled = false,
    this.danger = false,
  });
}

class IdentityDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final String? errorText;
  final List<IdentityDialogAction> actions;

  const IdentityDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    required this.actions,
    this.subtitle,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: AppColors.surface(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // شريط الترويسة الكحلي
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppGradients.identityHeader,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, color: AppColors.gold, size: 21),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.goldLight,
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // المحتوى
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    child,
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppColors.errorLight
                                  : AppColors.error)
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 17,
                              color: isDark
                                  ? AppColors.errorLight
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                errorText!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? AppColors.errorLight
                                      : AppColors.error,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // شريط الإجراءات اللاصق
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _buildAction(context, actions[i], isDark)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    IdentityDialogAction action,
    bool isDark,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
    const padding = EdgeInsets.symmetric(vertical: 13);
    Widget label(Color color, FontWeight weight) => Text(
          action.label,
          style: textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: weight,
            fontSize: 13.5,
          ),
        );
    if (action.filled || action.danger) {
      final Color bg;
      final Color fg;
      if (action.danger) {
        bg = AppColors.error;
        fg = Colors.white;
      } else if (isDark) {
        bg = AppColors.gold;
        fg = AppColors.navy;
      } else {
        bg = AppColors.navy;
        fg = Colors.white;
      }
      final style = FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        shape: shape,
        padding: padding,
      );
      return action.icon != null
          ? FilledButton.icon(
              onPressed: action.onPressed,
              style: style,
              icon: Icon(action.icon, size: 18),
              label: label(fg, FontWeight.w800),
            )
          : FilledButton(
              onPressed: action.onPressed,
              style: style,
              child: label(fg, FontWeight.w800),
            );
    }
    final style = OutlinedButton.styleFrom(
      foregroundColor: AppColors.text(isDark),
      side: BorderSide(
        color: AppColors.textSecondary(isDark).withValues(alpha: 0.45),
      ),
      shape: shape,
      padding: padding,
    );
    return action.icon != null
        ? OutlinedButton.icon(
            onPressed: action.onPressed,
            style: style,
            icon: Icon(action.icon, size: 18),
            label: label(AppColors.text(isDark), FontWeight.w700),
          )
        : OutlinedButton(
            onPressed: action.onPressed,
            style: style,
            child: label(AppColors.text(isDark), FontWeight.w700),
          );
  }
}

/// حوار تأكيد موحّد بالهيكل نفسه — يرجع true عند التأكيد.
/// بلا وحدات تحكّم ولا حالة داخلية: آمن بطبيعته ضد أي مسار إغلاق.
Future<bool> showIdentityConfirmDialog({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'تراجع',
  bool danger = false,
  String? subtitle,
}) async {
  final isDark = ThemeService().isDarkMode;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => IdentityDialog(
      icon: icon,
      title: title,
      subtitle: subtitle,
      actions: [
        IdentityDialogAction(
          label: cancelLabel,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        IdentityDialogAction(
          label: confirmLabel,
          filled: !danger,
          danger: danger,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
      child: Text(
        message,
        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              color: AppColors.text(isDark),
              fontSize: 13.5,
              height: 1.6,
            ),
      ),
    ),
  );
  return result ?? false;
}
