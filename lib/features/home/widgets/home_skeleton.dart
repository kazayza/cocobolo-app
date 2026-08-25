import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// شاشة تحميل متلألئة (Skeleton) تحاكي شكل الصفحة النهائية
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlight = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    Widget block(double height, {double? width, double radius = 16}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          block(120, radius: 24),
          const SizedBox(height: 24),
          block(18, width: 140, radius: 8),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: block(110)),
              const SizedBox(width: 12),
              Expanded(child: block(110)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: block(110)),
              const SizedBox(width: 12),
              Expanded(child: block(110)),
            ],
          ),
          const SizedBox(height: 24),
          block(18, width: 140, radius: 8),
          const SizedBox(height: 14),
          block(100, radius: 18),
          const SizedBox(height: 24),
          block(18, width: 140, radius: 8),
          const SizedBox(height: 14),
          block(160, radius: 18),
        ],
      ),
    );
  }
}
