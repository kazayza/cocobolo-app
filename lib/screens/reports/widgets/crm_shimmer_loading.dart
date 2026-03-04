import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/app_colors.dart';

class CrmShimmerLoading extends StatelessWidget {
  final bool isDark;

  const CrmShimmerLoading({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Period Chips shimmer
          _buildChipsShimmer(),
          const SizedBox(height: 16),

          // Story Cards shimmer
          _buildCardShimmer(height: 260),
          const SizedBox(height: 20),

          // Funnel shimmer
          _buildSectionShimmer(),
          const SizedBox(height: 16),

          // Trend shimmer
          _buildSectionShimmer(height: 280),
          const SizedBox(height: 16),

          // Sources shimmer
          _buildSectionShimmer(height: 250),
          const SizedBox(height: 16),

          // Leaderboard shimmer
          _buildSectionShimmer(height: 200),
        ],
      ),
    );
  }

  // === Chips Shimmer ===
  Widget _buildChipsShimmer() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: List.generate(5, (index) {
          return Container(
            margin: const EdgeInsets.only(left: 8),
            width: 80,
            height: 36,
            decoration: BoxDecoration(
              color: _shimmerBase,
              borderRadius: BorderRadius.circular(20),
            ),
          ).animate(
            onPlay: (controller) => controller.repeat(),
          ).shimmer(
            duration: 1200.ms,
            color: _shimmerHighlight,
          );
        }),
      ),
    );
  }

  // === Card Shimmer ===
  Widget _buildCardShimmer({double height = 200}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _shimmerBase,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildShimmerBox(36, 36, radius: 10),
                const SizedBox(width: 10),
                _buildShimmerBox(120, 16),
                const Spacer(),
                _buildShimmerBox(30, 16, radius: 10),
              ],
            ),
            const SizedBox(height: 24),

            // Big number
            Center(child: _buildShimmerBox(100, 40)),
            const SizedBox(height: 8),
            Center(child: _buildShimmerBox(80, 14)),

            const Spacer(),

            // Bottom row
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: _shimmerBase,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ],
        ),
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
    ).shimmer(
      duration: 1200.ms,
      color: _shimmerHighlight,
    );
  }

  // === Section Shimmer ===
  Widget _buildSectionShimmer({double height = 200}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _shimmerBase,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _buildShimmerBox(32, 32, radius: 10),
              const SizedBox(width: 10),
              _buildShimmerBox(140, 16),
            ],
          ),
          const SizedBox(height: 16),

          // Lines
          ...List.generate(4, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  _buildShimmerBox(60, 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: _shimmerHighlight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildShimmerBox(30, 12),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
    ).shimmer(
      duration: 1200.ms,
      color: _shimmerHighlight,
    );
  }

  // === Shimmer Box ===
  Widget _buildShimmerBox(double width, double height, {double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _shimmerHighlight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // === Colors ===
  Color get _shimmerBase => isDark
      ? AppColors.darkCard.withOpacity(0.5)
      : AppColors.lightCard;

  Color get _shimmerHighlight => isDark
      ? Colors.white.withOpacity(0.08)
      : Colors.grey.withOpacity(0.15);
}