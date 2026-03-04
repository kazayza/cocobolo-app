import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';
import 'crm_section_header.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CrmSourcesChart extends StatefulWidget {
  final List<SourceItem> sources;
  final bool isDark;

  const CrmSourcesChart({
    super.key,
    required this.sources,
    required this.isDark,
  });

  @override
  State<CrmSourcesChart> createState() => _CrmSourcesChartState();
}

class _CrmSourcesChartState extends State<CrmSourcesChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.sources.isEmpty) return const SizedBox.shrink();

    final totalOpportunities =
        widget.sources.fold<int>(0, (sum, s) => sum + s.total);
    final bestConversion = widget.sources
        .reduce((a, b) => a.conversionRate > b.conversionRate ? a : b);
    final fastestClose =
        widget.sources.where((s) => s.avgCloseTime > 0).toList()
          ..sort((a, b) => a.avgCloseTime.compareTo(b.avgCloseTime));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(widget.isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            CrmSectionHeader(
              title: 'تحليل المصادر',
              icon: Icons.source_rounded,
              iconColor: const Color(0xFF26A69A),
              subtitle:
                  '$totalOpportunities فرصة من ${widget.sources.length} مصادر',
              isDark: widget.isDark,
            ),

            // === القائمة ===
            ...widget.sources.asMap().entries.map((entry) {
              return _buildSourceItem(
                  entry.value, totalOpportunities, entry.key);
            }),

            const SizedBox(height: 12),

            // === تفاصيل المصدر المختار ===
            if (_selectedIndex != null)
              _buildSelectedDetails(widget.sources[_selectedIndex!]),

            if (_selectedIndex != null) const SizedBox(height: 12),

            // === Insights ===
            _buildInsights(bestConversion, fastestClose),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms);
  }

  // === عنصر مصدر واحد ===
  Widget _buildSourceItem(SourceItem source, int total, int index) {
    final percentage = total > 0 ? (source.total / total) : 0.0;
    final barColor = _getSourceColor(index);
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = _selectedIndex == index ? null : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(isSelected ? 10 : 6),
        decoration: BoxDecoration(
          color: isSelected
              ? barColor.withOpacity(widget.isDark ? 0.1 : 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: barColor.withOpacity(0.3))
              : null,
        ),
        child: Column(
          children: [
            // الصف الأول: الأيقونة + الاسم + الأرقام
            Row(
              children: [
                // أيقونة المصدر
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        barColor.withOpacity(0.2),
                        barColor.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: barColor.withOpacity(0.2),
                    ),
                  ),
                 child: Center(
                    child: _getSourceIcon(source.name, barColor), // استخدام مباشر للـ Widget
                  ),
                ),

                const SizedBox(width: 10),

                // الاسم
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: GoogleFonts.cairo(
                          color: isSelected
                              ? barColor
                              : AppColors.text(widget.isDark),
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      // Mini stats
                      Row(
                        children: [
                          _buildMiniStat(
                              '✅', '${source.won}', const Color(0xFF66BB6A)),
                          const SizedBox(width: 8),
                          _buildMiniStat(
                              '❌', '${source.lost}', const Color(0xFFEF5350)),
                          if (source.avgCloseTime > 0) ...[
                            const SizedBox(width: 8),
                            _buildMiniStat('⏱️', '${source.avgCloseTime}د',
                                const Color(0xFF42A5F5)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // العدد + نسبة التحويل
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${source.total}',
                      style: GoogleFonts.cairo(
                        color: AppColors.text(widget.isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _getConversionColor(source.conversionRate)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getConversionColor(source.conversionRate)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${source.conversionRate.toStringAsFixed(0)}%',
                        style: GoogleFonts.cairo(
                          color:
                              _getConversionColor(source.conversionRate),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // بار النسبة
            Stack(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: barColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage.clamp(0.02, 1.0),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [barColor, barColor.withOpacity(0.5)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // خط فاصل
            if (!isSelected && index < widget.sources.length - 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Divider(
                  color: AppColors.divider(widget.isDark),
                  height: 1,
                ),
              ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 80 * index), duration: 400.ms)
        .slideX(begin: 0.05, end: 0);
  }

  // === Mini Stat ===
  Widget _buildMiniStat(String emoji, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 2),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // === تفاصيل المصدر المختار ===
  Widget _buildSelectedDetails(SourceItem source) {
    final barColor = _getSourceColor(
        widget.sources.indexWhere((s) => s.sourceId == source.sourceId));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            barColor.withOpacity(widget.isDark ? 0.12 : 0.06),
            barColor.withOpacity(widget.isDark ? 0.04 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailItem(
            '💰',
            'الإيراد المتوقع',
            _formatCurrency(source.expectedRevenue),
            const Color(0xFF42A5F5),
          ),
          _buildDetailDivider(),
          _buildDetailItem(
            '💵',
            'الإيراد الفعلي',
            _formatCurrency(source.actualRevenue),
            const Color(0xFF66BB6A),
          ),
          _buildDetailDivider(),
          _buildDetailItem(
            '⏱️',
            'وقت الإغلاق',
            '${source.avgCloseTime} يوم',
            const Color(0xFFAB47BC),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
        );
  }

  Widget _buildDetailItem(
      String emoji, String label, String value, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: AppColors.textSecondary(widget.isDark),
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailDivider() {
    return Container(
      width: 1,
      height: 35,
      color: AppColors.divider(widget.isDark),
    );
  }

  // === Insights ===
  Widget _buildInsights(
      SourceItem bestConversion, List<SourceItem> fastestClose) {
    final totalRevenue =
        widget.sources.fold<double>(0, (sum, s) => sum + s.actualRevenue);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // أفضل تحويل
          _buildInsightRow(
            '🏆',
            'أفضل تحويل',
            '${bestConversion.name} (${bestConversion.conversionRate.toStringAsFixed(0)}%)',
            const Color(0xFF66BB6A),
          ),

          // أسرع إغلاق
          if (fastestClose.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildInsightRow(
                '⚡',
                'أسرع إغلاق',
                '${fastestClose.first.name} (${fastestClose.first.avgCloseTime} يوم)',
                const Color(0xFF42A5F5),
              ),
            ),

          // إجمالي الإيراد
          if (totalRevenue > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildInsightRow(
                '💰',
                'إجمالي الإيراد',
                '${_formatCurrency(totalRevenue)} ج.م',
                AppColors.gold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(
      String emoji, String label, String value, Color color) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.cairo(
            color: AppColors.textSecondary(widget.isDark),
            fontSize: 11,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // === Helpers ===
  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }

  Color _getSourceColor(int index) {
    const colors = [
      Color(0xFF26A69A),
      Color(0xFF42A5F5),
      Color(0xFFAB47BC),
      Color(0xFFFF7043),
      Color(0xFF66BB6A),
      Color(0xFFFFCA28),
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

  // === دالة تحديد الأيقونة واللون ===
  Widget _getSourceIcon(String name, Color defaultColor) {
    final lower = name.toLowerCase();
    IconData icon;
    Color color;

    if (lower.contains('فيس') || lower.contains('face')) {
      icon = FontAwesomeIcons.facebook;
      color = const Color(0xFF1877F2); // Facebook Blue
    } else if (lower.contains('واتس') || lower.contains('whats')) {
      icon = FontAwesomeIcons.whatsapp;
      color = const Color(0xFF25D366); // WhatsApp Green
    } else if (lower.contains('انستا') || lower.contains('انستج')) {
      icon = FontAwesomeIcons.instagram;
      color = const Color(0xFFE1306C); // Instagram Gradient (simplified)
    } else if (lower.contains('تيك') || lower.contains('tik')) {
      icon = FontAwesomeIcons.tiktok;
      color = Colors.black; // TikTok Black
    } else if (lower.contains('جوجل') || lower.contains('google')) {
      icon = FontAwesomeIcons.google;
      color = const Color(0xFFDB4437); // Google Red
    } else if (lower.contains('يوتيوب') || lower.contains('youtube')) {
      icon = FontAwesomeIcons.youtube;
      color = const Color(0xFFFF0000); // YouTube Red
    } else if (lower.contains('تويتر') || lower.contains('twitter') || lower.contains('x')) {
      icon = FontAwesomeIcons.xTwitter;
      color = Colors.black; // X Black
    } else if (lower.contains('لينكد') || lower.contains('linked')) {
      icon = FontAwesomeIcons.linkedin;
      color = const Color(0xFF0077B5); // LinkedIn Blue
    } else if (lower.contains('تليفون') || lower.contains('phone')) {
      icon = FontAwesomeIcons.phone;
      color = const Color(0xFF4CAF50);
    } else if (lower.contains('موقع') || lower.contains('web')) {
      icon = FontAwesomeIcons.globe;
      color = const Color(0xFF2196F3);
    } else if (lower.contains('زيارة') || lower.contains('visit')) {
      icon = FontAwesomeIcons.store;
      color = const Color(0xFF9C27B0);
    } else if (lower.contains('إحالة') || lower.contains('refer')) {
      icon = FontAwesomeIcons.handshake;
      color = const Color(0xFFFF9800);
    } else {
      icon = FontAwesomeIcons.bullhorn; // Default
      color = defaultColor;
    }

    // لو الثيم داكن واللون أسود (زي تيك توك و X)، خليه أبيض عشان يبان
    if (widget.isDark && color == Colors.black) {
      color = Colors.white;
    }

    return FaIcon(icon, color: color, size: 18);
  }
}