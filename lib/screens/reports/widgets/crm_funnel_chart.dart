import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';
import 'crm_section_header.dart';

class CrmFunnelChart extends StatefulWidget {
  final List<FunnelItem> funnel;
  final bool isDark;

  const CrmFunnelChart({
    super.key,
    required this.funnel,
    required this.isDark,
  });

  @override
  State<CrmFunnelChart> createState() => _CrmFunnelChartState();
}

class _CrmFunnelChartState extends State<CrmFunnelChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.funnel.fold<int>(0, (sum, item) => sum + item.count);

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
              title: 'مراحل المبيعات',
              icon: Icons.filter_alt_rounded,
              iconColor: const Color(0xFF7C4DFF),
              subtitle: 'إجمالي: $totalCount فرصة',
              isDark: widget.isDark,
            ),

            const SizedBox(height: 8),

            // === القمع ===
            ...widget.funnel.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildFunnelBar(item, totalCount, index);
            }),

            const SizedBox(height: 12),

            // === تفاصيل العنصر المختار ===
            if (_selectedIndex != null)
              _buildSelectedDetails(widget.funnel[_selectedIndex!]),

            if (_selectedIndex != null) const SizedBox(height: 12),

            // === إجمالي القيم ===
            _buildTotalValues(),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms);
  }

  // === شريط واحد في القمع ===
  Widget _buildFunnelBar(FunnelItem item, int totalCount, int index) {
    final percentage = totalCount > 0 ? (item.count / totalCount) : 0.0;
    final barColor = _parseColor(item.stageColor) ?? _getDefaultColor(index);
    final isSelected = _selectedIndex == index;
    final funnelWidth = 1.0 - (index * 0.12).clamp(0.0, 0.6);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = _selectedIndex == index ? null : index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 4 : 0,
            vertical: isSelected ? 4 : 0,
          ),
          decoration: isSelected
              ? BoxDecoration(
                  color: barColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: barColor.withOpacity(0.3),
                  ),
                )
              : null,
          child: Row(
            children: [
              // اسم المرحلة
              SizedBox(
                width: 65,
                child: Text(
                  item.stageNameAr,
                  style: GoogleFonts.cairo(
                    color: isSelected
                        ? barColor
                        : AppColors.textSecondary(widget.isDark),
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 8),

              // البار على شكل قمع
              Expanded(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: funnelWidth,
                    child: Stack(
                      children: [
                        // الخلفية
                        Container(
                          height: isSelected ? 34 : 30,
                          decoration: BoxDecoration(
                            color: barColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),

                        // البار الملون
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          height: isSelected ? 34 : 30,
                          child: FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: percentage > 0
                                ? percentage.clamp(0.08, 1.0)
                                : 0.08,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    barColor,
                                    barColor.withOpacity(0.6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: barColor.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // النص داخل البار
                        SizedBox(
                          height: isSelected ? 34 : 30,
                          child: Center(
                            child: Text(
                              '${item.count}',
                              style: GoogleFonts.cairo(
                                color: percentage > 0.2
                                    ? Colors.white
                                    : AppColors.text(widget.isDark),
                                fontSize: isSelected ? 14 : 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // النسبة
              SizedBox(
                width: 40,
                child: Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.cairo(
                    color: barColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 100 * index), duration: 400.ms)
        .slideX(begin: -0.1, end: 0);
  }

  // === تفاصيل العنصر المختار ===
  Widget _buildSelectedDetails(FunnelItem item) {
    final barColor = _parseColor(item.stageColor) ?? const Color(0xFF42A5F5);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            barColor.withOpacity(widget.isDark ? 0.15 : 0.08),
            barColor.withOpacity(widget.isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: barColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.stageNameAr,
                style: GoogleFonts.cairo(
                  color: barColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailItem(
                '📊',
                'العدد',
                '${item.count}',
                barColor,
              ),
              _buildDetailDivider(),
              _buildDetailItem(
                '💰',
                'القيمة المتوقعة',
                _formatCurrency(item.totalValue),
                const Color(0xFF42A5F5),
              ),
              _buildDetailDivider(),
              _buildDetailItem(
                '💵',
                'القيمة الفعلية',
                _formatCurrency(item.actualValue),
                const Color(0xFF66BB6A),
              ),
            ],
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
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 14,
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

  Widget _buildDetailDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.divider(widget.isDark),
    );
  }

  // === إجمالي القيم ===
  Widget _buildTotalValues() {
    final totalExpected =
        widget.funnel.fold<double>(0, (sum, item) => sum + item.totalValue);
    final totalActual =
        widget.funnel.fold<double>(0, (sum, item) => sum + item.actualValue);
    final gap = totalExpected - totalActual;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildValueItem(
            '💰',
            'المتوقعة',
            _formatCurrency(totalExpected),
            const Color(0xFF42A5F5),
          ),
          Container(
            width: 1,
            height: 35,
            color: AppColors.divider(widget.isDark),
          ),
          _buildValueItem(
            '💵',
            'الفعلية',
            _formatCurrency(totalActual),
            const Color(0xFF66BB6A),
          ),
          Container(
            width: 1,
            height: 35,
            color: AppColors.divider(widget.isDark),
          ),
          _buildValueItem(
            '📉',
            'الفجوة',
            _formatCurrency(gap),
            gap > 0 ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
          ),
        ],
      ),
    );
  }

  Widget _buildValueItem(
      String emoji, String label, String value, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 2),
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
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M ج.م';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K ج.م';
    }
    return '${amount.toStringAsFixed(0)} ج.م';
  }

  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    try {
      String hex = colorStr.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return null;
    }
  }

  Color _getDefaultColor(int index) {
    const colors = [
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFFFCA28),
      Color(0xFFEF5350),
      Color(0xFF7E57C2),
      Color(0xFF26A69A),
      Color(0xFFFF7043),
    ];
    return colors[index % colors.length];
  }
}