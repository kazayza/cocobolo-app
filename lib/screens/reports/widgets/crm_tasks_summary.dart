import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';
import 'crm_section_header.dart';

class CrmTasksSummary extends StatelessWidget {
  final TasksData tasks;
  final bool isDark;

  const CrmTasksSummary({
    super.key,
    required this.tasks,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final summary = tasks.summary;
    if (summary.totalTasks == 0) return const SizedBox.shrink();

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
              title: 'ملخص المهام',
              icon: Icons.task_alt_rounded,
              iconColor: const Color(0xFF66BB6A),
              subtitle: '${summary.totalTasks} مهمة',
              isDark: isDark,
            ),

            // === الصف الأول: الدائرة + الحالات ===
            Row(
              children: [
                // دائرة الإنجاز
                _buildCompletionCircle(summary),

                const SizedBox(width: 20),

                // حالات المهام
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              '✅',
                              'مكتملة',
                              summary.completed,
                              const Color(0xFF66BB6A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusCard(
                              '⏳',
                              'جارية',
                              summary.inProgress,
                              const Color(0xFF42A5F5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              '📋',
                              'معلقة',
                              summary.pending,
                              const Color(0xFFFFCA28),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusCard(
                              '🔴',
                              'متأخرة',
                              summary.overdue,
                              const Color(0xFFEF5350),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // === الأولويات ===
            _buildPriorities(summary),

            const SizedBox(height: 12),

            // === حسب النوع ===
            if (tasks.byType.isNotEmpty) _buildByType(),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 450.ms);
  }

  // === دائرة الإنجاز ===
  Widget _buildCompletionCircle(TasksSummary summary) {
    return CircularPercentIndicator(
      radius: 55,
      lineWidth: 10,
      percent: (summary.completionRate / 100).clamp(0.0, 1.0),
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${summary.completionRate.toStringAsFixed(0)}%',
            style: GoogleFonts.cairo(
              color: AppColors.text(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'إنجاز',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary(isDark),
              fontSize: 11,
            ),
          ),
        ],
      ),
      progressColor: _getCompletionColor(summary.completionRate),
      backgroundColor: AppColors.divider(isDark),
      circularStrokeCap: CircularStrokeCap.round,
      animation: true,
      animationDuration: 1200,
      backgroundWidth: 6,
    );
  }

  // === كارت حالة ===
  Widget _buildStatusCard(String emoji, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 10,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === الأولويات ===
  Widget _buildPriorities(TasksSummary summary) {
    final total = summary.totalTasks;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حسب الأولوية',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary(isDark),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // بار متعدد الألوان
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (summary.highPriority > 0)
                    Expanded(
                      flex: summary.highPriority,
                      child: Container(color: const Color(0xFFEF5350)),
                    ),
                  if (summary.normalPriority > 0)
                    Expanded(
                      flex: summary.normalPriority,
                      child: Container(color: const Color(0xFFFFCA28)),
                    ),
                  if (summary.lowPriority > 0)
                    Expanded(
                      flex: summary.lowPriority,
                      child: Container(color: const Color(0xFF66BB6A)),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // الأرقام
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPriorityItem(
                '🔴',
                'عالية',
                summary.highPriority,
                total,
                const Color(0xFFEF5350),
              ),
              _buildPriorityItem(
                '🟡',
                'عادية',
                summary.normalPriority,
                total,
                const Color(0xFFFFCA28),
              ),
              _buildPriorityItem(
                '🟢',
                'منخفضة',
                summary.lowPriority,
                total,
                const Color(0xFF66BB6A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityItem(
    String emoji,
    String label,
    int count,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count ($label)',
              style: GoogleFonts.cairo(
                color: AppColors.text(isDark),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // === حسب النوع ===
  Widget _buildByType() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حسب النوع',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary(isDark),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          ...tasks.byType.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final completionRate = item.total > 0
                ? (item.completed / item.total)
                : 0.0;
            final color = _getTypeColor(index);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // اسم النوع
                  Expanded(
                    flex: 3,
                    child: Text(
                      item.name,
                      style: GoogleFonts.cairo(
                        color: AppColors.text(isDark),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // بار الإنجاز
                  Expanded(
                    flex: 4,
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: completionRate.clamp(0.0, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // الأرقام
                  Text(
                    '${item.completed}/${item.total}',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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
  Color _getCompletionColor(double rate) {
    if (rate >= 70) return const Color(0xFF66BB6A);
    if (rate >= 40) return const Color(0xFFFFCA28);
    return const Color(0xFFEF5350);
  }

  Color _getTypeColor(int index) {
    const colors = [
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFFF7043),
      Color(0xFFAB47BC),
      Color(0xFFFFCA28),
      Color(0xFF26A69A),
      Color(0xFFEC407A),
    ];
    return colors[index % colors.length];
  }
}