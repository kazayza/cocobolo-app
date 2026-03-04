import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';
import 'crm_section_header.dart';

class CrmInteractions extends StatelessWidget {
  final InteractionsData interactions;
  final bool isDark;

  const CrmInteractions({
    super.key,
    required this.interactions,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final summary = interactions.summary;
    if (summary.totalInteractions == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            CrmSectionHeader(
              title: 'تحليل التفاعلات',
              icon: Icons.forum_rounded,
              iconColor: const Color(0xFF42A5F5),
              subtitle: '${summary.totalInteractions} تفاعل',
              isDark: isDark,
            ),

            // === الإحصائيات الرئيسية ===
            _buildMainStats(summary),

            const SizedBox(height: 16),

            // === حسب الحالة وحسب المصدر ===
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // حسب الحالة
                Expanded(
                  child: _buildByStatusSection(),
                ),

                const SizedBox(width: 12),

                // حسب المصدر
                Expanded(
                  child: _buildBySourceSection(),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 500.ms);
  }

  // === الإحصائيات الرئيسية ===
  Widget _buildMainStats(InteractionsSummary summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            '💬',
            'إجمالي',
            '${summary.totalInteractions}',
            const Color(0xFF42A5F5),
          ),
          _buildStatDivider(),
          _buildStatItem(
            '🎯',
            'فرص فريدة',
            '${summary.uniqueOpportunities}',
            const Color(0xFF66BB6A),
          ),
          _buildStatDivider(),
          _buildStatItem(
            '📊',
            'متوسط/فرصة',
            summary.avgPerOpportunity.toStringAsFixed(1),
            const Color(0xFFFFCA28),
          ),
          _buildStatDivider(),
          _buildStatItem(
            '🔄',
            'تحولات',
            '${summary.stageChanges}',
            const Color(0xFFAB47BC),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String label, String value, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: AppColors.textSecondary(isDark),
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.divider(isDark),
    );
  }

  // === حسب الحالة ===
  Widget _buildByStatusSection() {
    final byStatus = interactions.byStatus;
    if (byStatus.isEmpty) return const SizedBox.shrink();

    final total = byStatus.fold<int>(0, (sum, item) => sum + item.count);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : AppColors.lightBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(isDark).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                'حسب الحالة',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...byStatus.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percentage = total > 0 ? (item.count / total) : 0.0;
            final color = _getStatusColor(index);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.name,
                          style: GoogleFonts.cairo(
                            color: AppColors.text(isDark),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${item.count}',
                        style: GoogleFonts.cairo(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // بار
                  Stack(
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage.clamp(0.02, 1.0),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // === حسب المصدر ===
  Widget _buildBySourceSection() {
    final bySource = interactions.bySource;
    if (bySource.isEmpty) return const SizedBox.shrink();

    final total = bySource.fold<int>(0, (sum, item) => sum + item.count);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : AppColors.lightBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(isDark).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📱', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                'حسب المصدر',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...bySource.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percentage = total > 0 ? (item.count / total) : 0.0;
            final color = _getSourceColor(index);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        _getSourceEmoji(item.icon, item.name),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.name,
                          style: GoogleFonts.cairo(
                            color: AppColors.text(isDark),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${item.count}',
                        style: GoogleFonts.cairo(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // بار
                  Stack(
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage.clamp(0.02, 1.0),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // === Helpers ===
  Color _getStatusColor(int index) {
    const colors = [
      Color(0xFF66BB6A),
      Color(0xFF42A5F5),
      Color(0xFFFFCA28),
      Color(0xFFEF5350),
      Color(0xFFAB47BC),
      Color(0xFF26A69A),
      Color(0xFFFF7043),
    ];
    return colors[index % colors.length];
  }

  Color _getSourceColor(int index) {
    const colors = [
      Color(0xFF26A69A),
      Color(0xFF42A5F5),
      Color(0xFFAB47BC),
      Color(0xFFFF7043),
      Color(0xFF66BB6A),
      Color(0xFFFFCA28),
    ];
    return colors[index % colors.length];
  }

  String _getSourceEmoji(String? icon, String name) {
    if (icon != null && icon.isNotEmpty) return icon;

    final lower = name.toLowerCase();
    if (lower.contains('فيس') || lower.contains('face')) return '📘';
    if (lower.contains('واتس') || lower.contains('whats')) return '💬';
    if (lower.contains('انستا') || lower.contains('insta')) return '📸';
    if (lower.contains('جوجل') || lower.contains('google')) return '🔍';
    if (lower.contains('زيارة') || lower.contains('visit')) return '🏢';
    if (lower.contains('تليفون') || lower.contains('phone')) return '📞';
    if (lower.contains('موقع') || lower.contains('web')) return '🌐';
    return '📱';
  }
}