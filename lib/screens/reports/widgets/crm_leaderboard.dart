import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';
import 'crm_section_header.dart';

class CrmLeaderboard extends StatelessWidget {
  final List<LeaderboardItem> leaderboard;
  final bool isDark;

  const CrmLeaderboard({
    super.key,
    required this.leaderboard,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (leaderboard.isEmpty) return const SizedBox.shrink();

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
              title: 'لوحة الشرف',
              icon: Icons.emoji_events_rounded,
              iconColor: AppColors.gold,
              subtitle: 'أداء فريق المبيعات (${leaderboard.length} موظف)',
              isDark: isDark,
            ),

            // === Top 3 ===
            if (leaderboard.length >= 3) _buildTopThree(),
            if (leaderboard.length >= 3) const SizedBox(height: 16),

            // === باقي القائمة ===
            if (leaderboard.length < 3)
              ...leaderboard.asMap().entries.map((entry) {
                return _buildEmployeeRow(entry.value, entry.key);
              }),
            if (leaderboard.length >= 3)
              ...leaderboard.sublist(3).asMap().entries.map((entry) {
                return _buildEmployeeRow(entry.value, entry.key + 3);
              }),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 550.ms);
  }

  // ══════════════════════════════════════
  // Top 3 - تصميم محسّن
  // ══════════════════════════════════════
  Widget _buildTopThree() {
    return SizedBox(
      height: 185,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // المركز الثاني
          Expanded(
            child: _buildTopCard(
              leaderboard[1],
              '🥈',
              2,
              const Color(0xFFC0C0C0),
              150,
            ),
          ),
          const SizedBox(width: 8),

          // المركز الأول
          Expanded(
            child: _buildTopCard(
              leaderboard[0],
              '🥇',
              1,
              AppColors.gold,
              185,
            ),
          ),
          const SizedBox(width: 8),

          // المركز الثالث
          Expanded(
            child: _buildTopCard(
              leaderboard[2],
              '🥉',
              3,
              const Color(0xFFCD7F32),
              135,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCard(
    LeaderboardItem item,
    String medal,
    int rank,
    Color color,
    double height,
  ) {
    final conversionPercent = (item.conversionRate / 100).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // حساب أحجام نسبية بناءً على عرض الكارت
        final avatarSize = constraints.maxWidth * (rank == 1 ? 0.45 : 0.35);
        final fontSizeName = constraints.maxWidth * 0.11;
        final fontSizeRevenue = constraints.maxWidth * 0.1;
        final fontSizeDetails = constraints.maxWidth * 0.08;

        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(isDark ? 0.25 : 0.15),
                color.withOpacity(isDark ? 0.08 : 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(rank == 1 ? 0.5 : 0.3),
              width: rank == 1 ? 2 : 1,
            ),
            boxShadow: rank == 1
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // الميدالية
              Text(medal, style: TextStyle(fontSize: rank == 1 ? 24 : 20)),
              
              const SizedBox(height: 4),

              // الأفاتار مع progress
              CircularPercentIndicator(
                radius: avatarSize / 2,
                lineWidth: 3,
                percent: conversionPercent,
                center: Container(
                  width: avatarSize - 6,
                  height: avatarSize - 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: FittedBox(
                      child: Text(
                        _getInitials(item.fullName),
                        style: GoogleFonts.cairo(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                progressColor: color,
                backgroundColor: AppColors.divider(isDark),
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animationDuration: 1200,
              ),

              const SizedBox(height: 6),

              // الاسم (FittedBox يمنع الـ overflow)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _getFirstName(item.fullName),
                    style: GoogleFonts.cairo(
                      color: AppColors.text(isDark),
                      fontSize: fontSizeName,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // الإيراد
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_formatCurrency(item.actualRevenue)} ج.م',
                    style: GoogleFonts.cairo(
                      color: color,
                      fontSize: fontSizeRevenue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // الصفقات والتحويل
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${item.wonDeals} صفقة • ${item.conversionRate.toStringAsFixed(0)}%',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(isDark),
                      fontSize: fontSizeDetails,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate()
            .fadeIn(delay: Duration(milliseconds: rank == 1 ? 0 : 150 * rank), duration: 500.ms)
            .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1));
      },
    );
  }

  // ══════════════════════════════════════
  // صف موظف (المركز 4+)
  // ══════════════════════════════════════
  Widget _buildEmployeeRow(LeaderboardItem item, int index) {
    final conversionPercent = (item.conversionRate / 100).clamp(0.0, 1.0);
    final avatarColor = _getAvatarColor(index);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // الترتيب
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.textHint(isDark).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // الأفاتار مع progress
              CircularPercentIndicator(
                radius: 20,
                lineWidth: 2.5,
                percent: conversionPercent,
                center: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        avatarColor.withOpacity(0.25),
                        avatarColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(item.fullName),
                      style: GoogleFonts.cairo(
                        color: avatarColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                progressColor: _getConversionColor(item.conversionRate),
                backgroundColor: AppColors.divider(isDark),
                circularStrokeCap: CircularStrokeCap.round,
              ),

              const SizedBox(width: 10),

              // الاسم والتفاصيل
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fullName,
                      style: GoogleFonts.cairo(
                        color: AppColors.text(isDark),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // معلومات مفصلة
                    Row(
                      children: [
                        _buildMiniInfo(Icons.check_circle, '${item.wonDeals}',
                            const Color(0xFF66BB6A)),
                        const SizedBox(width: 10),
                        _buildMiniInfo(Icons.cancel, '${item.lostDeals}',
                            const Color(0xFFEF5350)),
                        const SizedBox(width: 10),
                        _buildMiniInfo(Icons.timer, '${item.avgCloseTime}د',
                            const Color(0xFF42A5F5)),
                        const SizedBox(width: 10),
                        _buildMiniInfo(Icons.trending_up,
                            '${item.dailyActivityRate}/ي',
                            const Color(0xFFFFCA28)),
                      ],
                    ),

                    // Progress bar
                    const SizedBox(height: 4),
                    Stack(
                      children: [
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.divider(isDark),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: conversionPercent,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getConversionColor(item.conversionRate),
                                  _getConversionColor(item.conversionRate)
                                      .withOpacity(0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // الإيراد ونسبة التحويل
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(item.actualRevenue),
                    style: GoogleFonts.cairo(
                      color: const Color(0xFF66BB6A),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getConversionColor(item.conversionRate)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getConversionColor(item.conversionRate)
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${item.conversionRate.toStringAsFixed(0)}%',
                      style: GoogleFonts.cairo(
                        color: _getConversionColor(item.conversionRate),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // المهام المتأخرة
                  if (item.overdueTasks > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 10,
                            color: Color(0xFFEF5350),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${item.overdueTasks} متأخرة',
                            style: GoogleFonts.cairo(
                              color: const Color(0xFFEF5350),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
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

        if (index < leaderboard.length - 1)
          Divider(color: AppColors.divider(isDark), height: 1),
      ],
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 80 * index), duration: 400.ms)
        .slideX(begin: 0.05, end: 0);
  }

  // === معلومة صغيرة مع أيقونة ===
  Widget _buildMiniInfo(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: AppColors.textSecondary(isDark),
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  // === Helpers ===
  String _getFirstName(String fullName) {
    final parts = fullName.split(' ');
    return parts.isNotEmpty ? parts[0] : fullName;
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '؟';
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    if (amount == 0) return '0';
    return amount.toStringAsFixed(0);
  }

  Color _getAvatarColor(int index) {
    const colors = [
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFFF7043),
      Color(0xFFAB47BC),
      Color(0xFFFFCA28),
      Color(0xFF26A69A),
      Color(0xFFEC407A),
      Color(0xFF5C6BC0),
    ];
    return colors[index % colors.length];
  }

  Color _getConversionColor(double rate) {
    if (rate >= 50) return const Color(0xFF66BB6A);
    if (rate >= 30) return const Color(0xFFFFCA28);
    return const Color(0xFFEF5350);
  }
}