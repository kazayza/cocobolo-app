import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';
import 'crm_section_header.dart';

class CrmLostReasons extends StatefulWidget {
  final List<LostReasonItem> lostReasons;
  final bool isDark;

  const CrmLostReasons({
    super.key,
    required this.lostReasons,
    required this.isDark,
  });

  @override
  State<CrmLostReasons> createState() => _CrmLostReasonsState();
}

class _CrmLostReasonsState extends State<CrmLostReasons> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.lostReasons.isEmpty) return const SizedBox.shrink();

    final totalLost = widget.lostReasons.fold<int>(0, (sum, r) => sum + r.count);
    final totalValue = widget.lostReasons.fold<double>(0, (sum, r) => sum + r.lostValue);

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
              title: 'أسباب الخسارة',
              icon: Icons.cancel_rounded,
              iconColor: const Color(0xFFEF5350),
              subtitle: '$totalLost فرصة خاسرة',
              isDark: widget.isDark,
            ),

            // === Pie Chart + القائمة ===
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pie Chart
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: _buildPieSections(totalLost),
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 300),
                  ),
                ),

                const SizedBox(width: 16),

                // القائمة
                Expanded(
                  child: Column(
                    children: widget.lostReasons.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildReasonItem(item, totalLost, index);
                    }).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // === القيمة المفقودة ===
            _buildLostValueSummary(totalLost, totalValue),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 600.ms);
  }

  // === Pie Sections ===
  List<PieChartSectionData> _buildPieSections(int total) {
    return widget.lostReasons.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isTouched = index == _touchedIndex;
      final color = _getReasonColor(index);
      final percentage = total > 0 ? (item.count / total * 100) : 0.0;

      return PieChartSectionData(
        value: item.count.toDouble(),
        color: color,
        radius: isTouched ? 38 : 32,
        title: isTouched
            ? '${percentage.toStringAsFixed(0)}%'
            : percentage >= 15
                ? '${percentage.toStringAsFixed(0)}%'
                : '',
        titleStyle: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: isTouched ? 12 : 10,
          fontWeight: FontWeight.bold,
        ),
        titlePositionPercentageOffset: 0.55,
        badgePositionPercentageOffset: 1.2,
        badgeWidget: isTouched
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.count}',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      );
    }).toList();
  }

  // === عنصر سبب واحد ===
  Widget _buildReasonItem(LostReasonItem item, int total, int index) {
    final color = _getReasonColor(index);
    final percentage = total > 0 ? (item.count / total * 100) : 0.0;
    final isTouched = index == _touchedIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _touchedIndex = _touchedIndex == index ? -1 : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isTouched
              ? color.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isTouched
              ? Border.all(color: color.withOpacity(0.3))
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // مؤشر اللون
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                const SizedBox(width: 8),

                // الاسم
                Expanded(
                  child: Text(
                    item.name,
                    style: GoogleFonts.cairo(
                      color: AppColors.text(widget.isDark),
                      fontSize: 11,
                      fontWeight: isTouched ? FontWeight.bold : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // العدد والنسبة
                Text(
                  '${item.count}',
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${percentage.toStringAsFixed(0)}%)',
                  style: GoogleFonts.cairo(
                    color: AppColors.textHint(widget.isDark),
                    fontSize: 10,
                  ),
                ),
              ],
            ),

            // التفاصيل عند الضغط
            if (isTouched && item.lostValue > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 18),
                child: Row(
                  children: [
                    Text(
                      '💰 القيمة المفقودة: ',
                      style: GoogleFonts.cairo(
                        color: AppColors.textSecondary(widget.isDark),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${_formatCurrency(item.lostValue)} ج.م',
                      style: GoogleFonts.cairo(
                        color: const Color(0xFFEF5350),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // === ملخص القيمة المفقودة ===
  Widget _buildLostValueSummary(int totalLost, double totalValue) {
    final avgLostValue = totalLost > 0 ? totalValue / totalLost : 0.0;
    final topReason = widget.lostReasons.isNotEmpty
        ? widget.lostReasons.reduce((a, b) => a.count > b.count ? a : b)
        : null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // إجمالي القيمة المفقودة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                '💸',
                'القيمة المفقودة',
                '${_formatCurrency(totalValue)} ج.م',
                const Color(0xFFEF5350),
              ),
              Container(
                width: 1,
                height: 30,
                color: AppColors.divider(widget.isDark),
              ),
              _buildSummaryItem(
                '📊',
                'متوسط/فرصة',
                '${_formatCurrency(avgLostValue)} ج.م',
                const Color(0xFFFF7043),
              ),
            ],
          ),

          // أكبر سبب
          if (topReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'السبب الأكبر: ',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(widget.isDark),
                      fontSize: 11,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${topReason.name} (${topReason.count} فرصة - ${_formatCurrency(topReason.lostValue)} ج.م)',
                      style: GoogleFonts.cairo(
                        color: const Color(0xFFEF5350),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String emoji, String label, String value, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: AppColors.textSecondary(widget.isDark),
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  // === Helpers ===
  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    if (amount == 0) return '0';
    return amount.toStringAsFixed(0);
  }

  Color _getReasonColor(int index) {
    const colors = [
      Color(0xFFEF5350),
      Color(0xFFFF7043),
      Color(0xFFFFCA28),
      Color(0xFF42A5F5),
      Color(0xFFAB47BC),
      Color(0xFF26A69A),
      Color(0xFF8D6E63),
      Color(0xFF78909C),
    ];
    return colors[index % colors.length];
  }
}