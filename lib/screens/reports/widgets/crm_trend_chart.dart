import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';
import 'crm_section_header.dart';

class CrmTrendChart extends StatefulWidget {
  final TrendData trend;
  final bool isDark;

  const CrmTrendChart({
    super.key,
    required this.trend,
    required this.isDark,
  });

  @override
  State<CrmTrendChart> createState() => _CrmTrendChartState();
}

class _CrmTrendChartState extends State<CrmTrendChart> {
  bool _showOpportunities = true;
  bool _showWon = true;
  bool _showLost = false;
  bool _showRevenue = false;
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final data = widget.trend.data;
    if (data.isEmpty) return const SizedBox.shrink();

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
              title: 'اتجاه المبيعات',
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFF42A5F5),
              subtitle: widget.trend.type == 'monthly' ? 'عرض شهري' : 'عرض يومي',
              isDark: widget.isDark,
            ),

            _buildToggleButtons(),
            const SizedBox(height: 16),

            // === الرسم البياني ===
            SizedBox(
              height: 220,
              child: LineChart(
                _buildChartData(data),
                duration: const Duration(milliseconds: 500),
              ),
            ),

            const SizedBox(height: 8),

            // === Tooltip للنقطة المختارة ===
            if (_touchedIndex != null && _touchedIndex! < data.length)
              _buildTouchInfo(data[_touchedIndex!]),

            const SizedBox(height: 8),

            // === ملخص سريع ===
            _buildQuickSummary(data),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms);
  }

  // === أزرار التبديل ===
  Widget _buildToggleButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildToggleChip('الفرص', _showOpportunities, const Color(0xFF42A5F5),
              (v) => setState(() => _showOpportunities = v)),
          _buildToggleChip('المكسبة', _showWon, const Color(0xFF66BB6A),
              (v) => setState(() => _showWon = v)),
          _buildToggleChip('الخاسرة', _showLost, const Color(0xFFEF5350),
              (v) => setState(() => _showLost = v)),
          _buildToggleChip('الإيراد', _showRevenue, const Color(0xFFFFCA28),
              (v) => setState(() => _showRevenue = v)),
        ],
      ),
    );
  }

  Widget _buildToggleChip(
    String label,
    bool isActive,
    Color color,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () => onChanged(!isActive),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? color : AppColors.divider(widget.isDark),
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? color : AppColors.textHint(widget.isDark),
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: isActive ? color : AppColors.textSecondary(widget.isDark),
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === Touch Info Card ===
  Widget _buildTouchInfo(TrendItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.08)
            : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.divider(widget.isDark),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            '📅 ${item.label}',
            style: GoogleFonts.cairo(
              color: AppColors.text(widget.isDark),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_showOpportunities)
            _buildTouchItem('فرص', '${item.totalOpportunities}', const Color(0xFF42A5F5)),
          if (_showWon)
            _buildTouchItem('مكسبة', '${item.wonDeals}', const Color(0xFF66BB6A)),
          if (_showLost)
            _buildTouchItem('خاسرة', '${item.lostDeals}', const Color(0xFFEF5350)),
          if (_showRevenue)
            _buildTouchItem('إيراد', _formatCurrency(item.revenue), const Color(0xFFFFCA28)),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildTouchItem(String label, String value, Color color) {
    return Column(
      children: [
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
            color: AppColors.textHint(widget.isDark),
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  // === بناء بيانات الرسم ===
  LineChartData _buildChartData(List<TrendItem> data) {
    final maxY = _calculateMaxY(data);

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 4 : 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: AppColors.divider(widget.isDark).withOpacity(0.3),
            strokeWidth: 0.5,
            dashArray: [5, 5],
          );
        },
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            getTitlesWidget: (value, meta) {
              if (value == meta.max || value == meta.min) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  _formatAxisValue(value),
                  style: GoogleFonts.cairo(
                    color: AppColors.textHint(widget.isDark),
                    fontSize: 9,
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: _calculateLabelInterval(data.length),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  data[index].label,
                  style: GoogleFonts.cairo(
                    color: AppColors.textHint(widget.isDark),
                    fontSize: 8,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (data.length - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchCallback: (event, response) {
          if (event is FlTapUpEvent || event is FlLongPressEnd) {
            setState(() => _touchedIndex = null);
          } else if (response != null &&
              response.lineBarSpots != null &&
              response.lineBarSpots!.isNotEmpty) {
            setState(() {
              _touchedIndex = response.lineBarSpots!.first.x.toInt();
            });
          }
        },
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.transparent,
          tooltipPadding: EdgeInsets.zero,
          getTooltipItems: (spots) {
            return spots.map((_) => null).toList();
          },
        ),
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes.map((index) {
            return TouchedSpotIndicatorData(
              FlLine(
                color: AppColors.gold.withOpacity(0.5),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
              FlDotData(
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: barData.color ?? Colors.white,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
            );
          }).toList();
        },
      ),
      lineBarsData: _buildLines(data),
    );
  }

  // === بناء الخطوط ===
  List<LineChartBarData> _buildLines(List<TrendItem> data) {
    final List<LineChartBarData> lines = [];

    if (_showOpportunities) {
      lines.add(_createLine(
        data.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.totalOpportunities.toDouble()))
            .toList(),
        const Color(0xFF42A5F5),
      ));
    }

    if (_showWon) {
      lines.add(_createLine(
        data.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.wonDeals.toDouble()))
            .toList(),
        const Color(0xFF66BB6A),
      ));
    }

    if (_showLost) {
      lines.add(_createLine(
        data.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.lostDeals.toDouble()))
            .toList(),
        const Color(0xFFEF5350),
      ));
    }

    if (_showRevenue) {
      final maxRevenue = data.fold<double>(
          0, (max, item) => item.revenue > max ? item.revenue : max);
      final divisor = maxRevenue > 0 ? maxRevenue / _getMaxCount(data) : 1;

      lines.add(_createLine(
        data.asMap().entries
            .map((e) => FlSpot(
                e.key.toDouble(), divisor > 0 ? e.value.revenue / divisor : 0))
            .toList(),
        const Color(0xFFFFCA28),
        isDashed: true,
      ));
    }

    return lines;
  }

  LineChartBarData _createLine(
    List<FlSpot> spots,
    Color color, {
    bool isDashed = false,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dashArray: isDashed ? [5, 5] : null,
      dotData: FlDotData(
        show: spots.length <= 15,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
            color: color,
            strokeWidth: 1.5,
            strokeColor: widget.isDark ? AppColors.darkCard : Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  // === ملخص سريع ===
  Widget _buildQuickSummary(List<TrendItem> data) {
    final totalOpp = data.fold<int>(0, (sum, item) => sum + item.totalOpportunities);
    final totalWon = data.fold<int>(0, (sum, item) => sum + item.wonDeals);
    final totalLost = data.fold<int>(0, (sum, item) => sum + item.lostDeals);
    final totalRevenue = data.fold<double>(0, (sum, item) => sum + item.revenue);
    final avgPerDay = data.isNotEmpty ? (totalOpp / data.length).toStringAsFixed(1) : '0';

    // أفضل يوم
    TrendItem? bestDay;
    for (final item in data) {
      if (bestDay == null || item.wonDeals > bestDay.wonDeals) {
        bestDay = item;
      }
    }

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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('📊', 'إجمالي', '$totalOpp', const Color(0xFF42A5F5)),
              _buildSummaryDivider(),
              _buildSummaryItem('✅', 'مكسبة', '$totalWon', const Color(0xFF66BB6A)),
              _buildSummaryDivider(),
              _buildSummaryItem('❌', 'خاسرة', '$totalLost', const Color(0xFFEF5350)),
              _buildSummaryDivider(),
              _buildSummaryItem('📈', 'متوسط/يوم', avgPerDay, AppColors.gold),
            ],
          ),

          // أفضل يوم
          if (bestDay != null && bestDay.wonDeals > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    'أفضل يوم: ${bestDay.label} (${bestDay.wonDeals} صفقة)',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(widget.isDark),
                      fontSize: 10,
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
        Text(emoji, style: const TextStyle(fontSize: 12)),
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
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppColors.divider(widget.isDark),
    );
  }

  // === Helpers ===
  double _calculateMaxY(List<TrendItem> data) {
    double maxVal = 0;
    for (final item in data) {
      if (_showOpportunities && item.totalOpportunities > maxVal) {
        maxVal = item.totalOpportunities.toDouble();
      }
      if (_showWon && item.wonDeals > maxVal) {
        maxVal = item.wonDeals.toDouble();
      }
      if (_showLost && item.lostDeals > maxVal) {
        maxVal = item.lostDeals.toDouble();
      }
    }
    return maxVal > 0 ? maxVal * 1.2 : 10;
  }

  double _getMaxCount(List<TrendItem> data) {
    double maxVal = 0;
    for (final item in data) {
      if (item.totalOpportunities > maxVal) maxVal = item.totalOpportunities.toDouble();
      if (item.wonDeals > maxVal) maxVal = item.wonDeals.toDouble();
    }
    return maxVal > 0 ? maxVal : 1;
  }

  double _calculateLabelInterval(int dataLength) {
    if (dataLength <= 7) return 1;
    if (dataLength <= 15) return 2;
    if (dataLength <= 30) return 5;
    return (dataLength / 6).roundToDouble();
  }

  String _formatAxisValue(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }
}