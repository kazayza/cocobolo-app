import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';
import 'crm_section_header.dart';

class CrmCategories extends StatefulWidget {
  final List<CategoryItem> categories;
  final bool isDark;

  const CrmCategories({
    super.key,
    required this.categories,
    required this.isDark,
  });

  @override
  State<CrmCategories> createState() => _CrmCategoriesState();
}

class _CrmCategoriesState extends State<CrmCategories> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) return const SizedBox.shrink();

    final totalOpportunities =
        widget.categories.fold<int>(0, (sum, c) => sum + c.total);

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
              title: 'تصنيفات الاهتمام',
              icon: Icons.category_rounded,
              iconColor: const Color(0xFFAB47BC),
              subtitle:
                  '$totalOpportunities فرصة في ${widget.categories.length} تصنيفات',
              isDark: widget.isDark,
            ),

            // === الرسم البياني + القائمة ===
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pie Chart
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                      sections: _buildPieSections(totalOpportunities),
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
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 300),
                  ),
                ),

                const SizedBox(width: 16),

                // القائمة
                Expanded(
                  child: Column(
                    children: widget.categories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildCategoryItem(item, totalOpportunities, index);
                    }).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // === تفاصيل التصنيف المختار ===
            if (_touchedIndex != -1 && _touchedIndex < widget.categories.length)
              _buildCategoryDetails(widget.categories[_touchedIndex]),

            if (_touchedIndex == -1) _buildSummary(),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 400.ms);
  }

  // === Pie Chart Sections ===
  List<PieChartSectionData> _buildPieSections(int total) {
    return widget.categories.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isTouched = index == _touchedIndex;
      final percentage = total > 0 ? (item.total / total * 100) : 0.0;
      final color = _getCategoryColor(index);

      return PieChartSectionData(
        value: item.total.toDouble(),
        color: color,
        radius: isTouched ? 38 : 32,
        title: isTouched
            ? '${percentage.toStringAsFixed(0)}%'
            : percentage >= 10
                ? '${percentage.toStringAsFixed(0)}%'
                : '',
        titleStyle: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: isTouched ? 12 : 9,
          fontWeight: FontWeight.bold,
        ),
        badgeWidget: isTouched
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 2),
                  ],
                ),
                child: Text(
                  '${item.total}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();
  }

  // === عنصر تصنيف واحد ===
  Widget _buildCategoryItem(CategoryItem item, int total, int index) {
    final color = _getCategoryColor(index);
    final percentage = total > 0 ? (item.total / total * 100) : 0.0;
    final isTouched = index == _touchedIndex;

    return GestureDetector(
      onTap: () => setState(() => _touchedIndex = isTouched ? -1 : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isTouched
              ? color.withOpacity(widget.isDark ? 0.15 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isTouched ? Border.all(color: color.withOpacity(0.3)) : null,
        ),
        child: Row(
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
              '${item.total}',
              style: GoogleFonts.cairo(
                color: AppColors.text(widget.isDark),
                fontSize: 12,
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
      ),
    );
  }

  // === تفاصيل التصنيف المختار ===
  Widget _buildCategoryDetails(CategoryItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getCategoryColor(_touchedIndex).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getCategoryColor(_touchedIndex).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailItem(
            '✅',
            'مكسبة',
            '${item.won}',
            const Color(0xFF66BB6A),
          ),
          Container(width: 1, height: 30, color: AppColors.divider(widget.isDark)),
          _buildDetailItem(
            '🔄',
            'تحويل',
            '${item.conversionRate.toStringAsFixed(0)}%',
            _getConversionColor(item.conversionRate),
          ),
          Container(width: 1, height: 30, color: AppColors.divider(widget.isDark)),
          _buildDetailItem(
            '💰',
            'إيراد',
            _formatCurrency(item.actualRevenue),
            const Color(0xFF42A5F5),
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

  // === ملخص عام ===
  Widget _buildSummary() {
    final bestConversion = widget.categories.reduce(
      (a, b) => a.conversionRate > b.conversionRate ? a : b,
    );
    final highestRevenue = widget.categories.reduce(
      (a, b) => a.actualRevenue > b.actualRevenue ? a : b,
    );

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
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                'أفضل تحويل: ',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(widget.isDark),
                  fontSize: 11,
                ),
              ),
              Expanded(
                child: Text(
                  '${bestConversion.name} (${bestConversion.conversionRate.toStringAsFixed(0)}%)',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFF66BB6A),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (highestRevenue.actualRevenue > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Text('💰', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    'أعلى إيراد: ',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(widget.isDark),
                      fontSize: 11,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${highestRevenue.name} (${_formatCurrency(highestRevenue.actualRevenue)} ج.م)',
                      style: GoogleFonts.cairo(
                        color: const Color(0xFF42A5F5),
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

  // === Helpers ===
  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    if (amount == 0) return '-';
    return amount.toStringAsFixed(0);
  }

  Color _getCategoryColor(int index) {
    const colors = [
      Color(0xFFAB47BC),
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFFF7043),
      Color(0xFFFFCA28),
      Color(0xFF26A69A),
      Color(0xFFEC407A),
      Color(0xFF5C6BC0),
      Color(0xFF8D6E63),
      Color(0xFF78909C),
    ];
    return colors[index % colors.length];
  }

  Color _getConversionColor(double rate) {
    if (rate >= 50) return const Color(0xFF66BB6A);
    if (rate >= 30) return const Color(0xFFFFCA28);
    return const Color(0xFFEF5350);
  }
}