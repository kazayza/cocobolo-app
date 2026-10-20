import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/app_colors.dart';
import '../services/app_text_styles.dart';
import '../services/theme_service.dart';

/// حالة تحميل موحدة مع سكلتون متلألئ.
class AppLoading extends StatelessWidget {
  final String? message;
  final bool showSkeleton;

  const AppLoading({super.key, this.message, this.showSkeleton = false});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    if (showSkeleton) {
      return ListView.builder(
        itemCount: 6,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.inputFill(isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.inputFill(isDark),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ).animate().shimmer(),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.inputFill(isDark),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ).animate().shimmer(delay: 200.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: AppTextStyles.bodyMedium(isDark),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// حالة خطأ موحدة مع زر إعادة المحاولة.
class AppError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? retryLabel;

  const AppError({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'حدث خطأ',
              style: AppTextStyles.headlineSmall(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: AppTextStyles.bodyMedium(isDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(retryLabel ?? 'إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حالة فارغة موحدة مع زر تحديث اختياري.
class AppEmpty extends StatelessWidget {
  final String message;
  final String? hint;
  final IconData? icon;
  final VoidCallback? onRefresh;
  final String? refreshLabel;

  const AppEmpty({
    super.key,
    required this.message,
    this.hint,
    this.icon,
    this.onRefresh,
    this.refreshLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.inbox_rounded,
                size: 40,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: AppTextStyles.headlineSmall(isDark),
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                style: AppTextStyles.bodySmall(isDark),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
                label: Text(refreshLabel ?? 'تحديث'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.gold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
