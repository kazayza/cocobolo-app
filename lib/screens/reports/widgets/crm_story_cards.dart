import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';

class CrmStoryCards extends StatefulWidget {
  final KPIData kpi;
  final DashboardPeriod period;
  final bool isDark;

  const CrmStoryCards({
    super.key,
    required this.kpi,
    required this.period,
    required this.isDark,
  });

  @override
  State<CrmStoryCards> createState() => _CrmStoryCardsState();
}

class _CrmStoryCardsState extends State<CrmStoryCards> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // === الكروت ===
        SizedBox(
          height: 260,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            physics: const BouncingScrollPhysics(),
            children: [
              _buildPerformanceCard(),
              _buildFinancialCard(),
              _buildMarketingCard(),
              _buildEfficiencyCard(),
              _buildAlertsCard(),
              _buildSummaryCard(),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // === النقاط + رقم الكارت ===
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // النقاط
            Row(
              children: List.generate(6, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.gold
                        : AppColors.textHint(widget.isDark).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: _currentPage == index
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(width: 12),
            // رقم الكارت
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textHint(widget.isDark).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_currentPage + 1}/6',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(widget.isDark),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  // ══════════════════════════════════════
  // الكارت 1: ملخص الأداء العام
  // ══════════════════════════════════════
  Widget _buildPerformanceCard() {
    final kpi = widget.kpi;

    return _buildGlassCard(
      gradientColors: [
        const Color(0xFF1A237E),
        const Color(0xFF283593),
        const Color(0xFF1A237E),
      ],
      gradientColorsLight: [
        const Color(0xFF5C6BC0),
        const Color(0xFF3F51B5),
        const Color(0xFF5C6BC0),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('📊', 'ملخص الأداء', '1/6'),
          const SizedBox(height: 16),

          // الرقم الكبير
          Center(
            child: Column(
              children: [
                Text(
                  '${kpi.currentOpportunities}',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'فرصة جديدة',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                _buildGrowthBadge(kpi.opportunitiesGrowth),
              ],
            ),
          ),

          const Spacer(),

          // التفاصيل
          _buildGlassInfoRow([
            _GlassInfo('✅ مكسبة', '${kpi.currentWon}', _buildGrowthText(kpi.wonGrowth)),
            _GlassInfo('❌ خاسرة', '${kpi.currentLost}', null),
            _GlassInfo('🔄 تحويل', '${kpi.currentConversion}%', _buildGrowthText(kpi.conversionGrowth)),
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // الكارت 2: الملخص المالي
  // ══════════════════════════════════════
  Widget _buildFinancialCard() {
    final kpi = widget.kpi;

    return _buildGlassCard(
      gradientColors: [
        const Color(0xFF1B5E20),
        const Color(0xFF2E7D32),
        const Color(0xFF1B5E20),
      ],
      gradientColorsLight: [
        const Color(0xFF43A047),
        const Color(0xFF2E7D32),
        const Color(0xFF43A047),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('💰', 'الملخص المالي', '2/6'),
          const SizedBox(height: 16),

          // الرقم الكبير
          Center(
            child: Column(
              children: [
                Text(
                  _formatCurrency(kpi.currentActualRevenue),
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ج.م الإيراد الفعلي',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                _buildGrowthBadge(kpi.actualRevenueGrowth),
              ],
            ),
          ),

          const Spacer(),

          // التفاصيل
          _buildGlassInfoRow([
            _GlassInfo('💵 المتوقع', _formatCurrency(kpi.currentExpectedRevenue), null),
            _GlassInfo('💳 المحصل', _formatCurrency(kpi.currentCollected), null),
            _GlassInfo('📊 تحصيل', '${kpi.collectionRate.toStringAsFixed(0)}%', null),
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // الكارت 3: التسويق والعائد
  // ══════════════════════════════════════
  Widget _buildMarketingCard() {
    final kpi = widget.kpi;

    return _buildGlassCard(
      gradientColors: [
        const Color(0xFFE65100),
        const Color(0xFFF57C00),
        const Color(0xFFE65100),
      ],
      gradientColorsLight: [
        const Color(0xFFFF9800),
        const Color(0xFFF57C00),
        const Color(0xFFFF9800),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('📢', 'التسويق والعائد', '3/6'),
          const SizedBox(height: 16),

          // الرقم الكبير
          Center(
            child: Column(
              children: [
                Text(
                  '${kpi.roi.toStringAsFixed(0)}%',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'العائد على الاستثمار',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                _buildGrowthBadge(kpi.roiGrowth),
              ],
            ),
          ),

          const Spacer(),

          // التفاصيل
          _buildGlassInfoRow([
            _GlassInfo('📢 تكلفة', _formatCurrency(kpi.currentMarketingCost), null),
            _GlassInfo('👤 اكتساب', _formatCurrency(kpi.cac), null),
            _GlassInfo(
              '💰 عائد/1ج',
              kpi.currentMarketingCost > 0
                  ? '${(kpi.currentActualRevenue / kpi.currentMarketingCost).toStringAsFixed(1)}'
                  : '0',
              null,
            ),
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // الكارت 4: الكفاءة والسرعة
  // ══════════════════════════════════════
  Widget _buildEfficiencyCard() {
    final kpi = widget.kpi;

    return _buildGlassCard(
      gradientColors: [
        const Color(0xFF4A148C),
        const Color(0xFF7B1FA2),
        const Color(0xFF4A148C),
      ],
      gradientColorsLight: [
        const Color(0xFF9C27B0),
        const Color(0xFF7B1FA2),
        const Color(0xFF9C27B0),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('⏱️', 'الكفاءة والسرعة', '4/6'),
          const SizedBox(height: 16),

          // الرقم الكبير
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${kpi.currentAvgCloseTime}',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        ' يوم',
                        style: GoogleFonts.cairo(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'متوسط وقت الإغلاق',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                _buildGrowthBadge(kpi.avgCloseTimeGrowth, invertColors: true),
              ],
            ),
          ),

          const Spacer(),

          // التفاصيل
          _buildGlassInfoRow([
            _GlassInfo('📅 السابق', '${kpi.prevAvgCloseTime} يوم', null),
            _GlassInfo('📊 فرق', '${(kpi.currentAvgCloseTime - kpi.prevAvgCloseTime).abs()} يوم', null),
            _GlassInfo(
              '🔄 تحسن',
              kpi.prevAvgCloseTime > 0
                  ? '${((kpi.prevAvgCloseTime - kpi.currentAvgCloseTime) / kpi.prevAvgCloseTime * 100).toStringAsFixed(0)}%'
                  : '0%',
              null,
            ),
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // الكارت 5: التنبيهات
  // ══════════════════════════════════════
  Widget _buildAlertsCard() {
    final kpi = widget.kpi;
    final hasAlerts = kpi.totalAlerts > 0;

    return _buildGlassCard(
      gradientColors: hasAlerts
          ? [const Color(0xFFB71C1C), const Color(0xFFD32F2F), const Color(0xFFB71C1C)]
          : [const Color(0xFF1B5E20), const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
      gradientColorsLight: hasAlerts
          ? [const Color(0xFFE53935), const Color(0xFFD32F2F), const Color(0xFFE53935)]
          : [const Color(0xFF43A047), const Color(0xFF2E7D32), const Color(0xFF43A047)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            hasAlerts ? '🚨' : '✅',
            hasAlerts ? 'تنبيهات تحتاج اهتمام' : 'أداء ممتاز!',
            '5/6',
          ),
          const SizedBox(height: 12),

          if (hasAlerts) ...[
            // الرقم الكبير
            Center(
              child: Column(
                children: [
                  Text(
                    '${kpi.totalAlerts}',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'إجمالي التنبيهات',
                    style: GoogleFonts.cairo(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // التنبيهات كـ Grid
            _buildAlertsGrid(kpi),
          ] else ...[
            // رسالة إيجابية
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text(
                      'لا توجد تنبيهات!',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'كل شيء يسير بشكل ممتاز',
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // === Grid التنبيهات ===
    // === Grid التنبيهات (تصميم الشبكة المنتظم) ===
  Widget _buildAlertsGrid(KPIData kpi) {
    final alerts = <_AlertItem>[];

    if (kpi.overdueTasks > 0) alerts.add(_AlertItem('🔴', '${kpi.overdueTasks}', 'مهام متأخرة'));
    if (kpi.stagnantOpportunities > 0) alerts.add(_AlertItem('🟠', '${kpi.stagnantOpportunities}', 'فرص راكدة'));
    if (kpi.overdueFollowUps > 0) alerts.add(_AlertItem('🟡', '${kpi.overdueFollowUps}', 'متابعات متأخرة'));
    if (kpi.openComplaints > 0) alerts.add(_AlertItem('🔵', '${kpi.openComplaints}', 'شكاوى مفتوحة'));
    if (kpi.todayTasks > 0) alerts.add(_AlertItem('🟢', '${kpi.todayTasks}', 'مهام اليوم'));

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: List.generate((alerts.length / 2).ceil(), (rowIndex) {
          final firstIndex = rowIndex * 2;
          final secondIndex = firstIndex + 1;
          final hasSecond = secondIndex < alerts.length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // العنصر الأول (يمين)
                Expanded(
                  child: _buildSingleAlertItem(alerts[firstIndex]),
                ),
                
                const SizedBox(width: 8),
                
                // العنصر الثاني (يسار) - أو مكان فاضي لو مفيش
                Expanded(
                  child: hasSecond
                      ? _buildSingleAlertItem(alerts[secondIndex])
                      : const SizedBox(),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // عنصر واحد في الشبكة
  Widget _buildSingleAlertItem(_AlertItem alert) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // توسيط المحتوى داخل البوكس
        children: [
          Text(alert.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            alert.count,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 6),
          Flexible( // عشان النص ميكسرش الشكل
            child: Text(
              alert.label,
              style: GoogleFonts.cairo(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // الكارت 6: الملخص النصي التحليلي
  // ══════════════════════════════════════
  Widget _buildSummaryCard() {
    final kpi = widget.kpi;

    return _buildGlassCard(
      gradientColors: [
        const Color(0xFF004D40),
        const Color(0xFF00695C),
        const Color(0xFF004D40),
      ],
      gradientColorsLight: [
        const Color(0xFF00897B),
        const Color(0xFF00695C),
        const Color(0xFF00897B),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('📝', 'ملخص تحليلي', '6/6'),
          const SizedBox(height: 10),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                _generateSummaryText(kpi),
                style: GoogleFonts.cairo(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  height: 2.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // Glass Card Container
  // ══════════════════════════════════════
   // ══════════════════════════════════════
  // Glass Card Container (مصحح)
  // ══════════════════════════════════════
  Widget _buildGlassCard({
    required List<Color> gradientColors,
    required List<Color> gradientColorsLight,
    required Widget child,
  }) {
    final colors = widget.isDark ? gradientColors : gradientColorsLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            // شيلنا الـ padding من هنا وهنحطه جوا
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(widget.isDark ? 0.15 : 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(18), // الـ padding هنا
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 36, // طرح الـ padding
                    ),
                    child: IntrinsicHeight(
                      child: child,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // === Header الكارت ===
  Widget _buildCardHeader(String emoji, String title, String counter) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            counter,
            style: GoogleFonts.cairo(
              color: Colors.white60,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  // === Glass Info Row ===
  Widget _buildGlassInfoRow(List<_GlassInfo> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Expanded(
            child: Row(
              children: [
                if (index > 0)
                  Container(
                    width: 1,
                    height: 30,
                    margin: const EdgeInsets.only(left: 4, right: 4),
                    color: Colors.white.withOpacity(0.15),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        item.value,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item.label,
                        style: GoogleFonts.cairo(
                          color: Colors.white60,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.growth != null) item.growth!,
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // === Growth Badge ===
  Widget _buildGrowthBadge(double growth, {bool invertColors = false}) {
    if (growth == 0) return const SizedBox(height: 4);

    final isPositive = growth > 0;
    final isGood = invertColors ? !isPositive : isPositive;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isGood
            ? Colors.greenAccent.withOpacity(0.2)
            : Colors.redAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            color: isGood ? Colors.greenAccent : Colors.redAccent,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            '${growth.abs().toStringAsFixed(0)}% عن السابق',
            style: GoogleFonts.cairo(
              color: isGood ? Colors.greenAccent : Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // === Growth Text (صغير) ===
  Widget? _buildGrowthText(double growth) {
    if (growth == 0) return null;

    final isPositive = growth > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
          color: isPositive ? Colors.greenAccent : Colors.redAccent,
          size: 10,
        ),
        Text(
          '${growth.abs().toStringAsFixed(0)}%',
          style: GoogleFonts.cairo(
            color: isPositive ? Colors.greenAccent : Colors.redAccent,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // === تنسيق العملة ===
  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  // === توليد الملخص النصي ===
  String _generateSummaryText(KPIData kpi) {
    final buffer = StringBuffer();

    buffer.write(
        '📊 تم تحقيق ${kpi.currentWon} صفقة من أصل ${kpi.currentOpportunities} فرصة');
    buffer.write(' بنسبة تحويل ${kpi.currentConversion}%');

    if (kpi.conversionGrowth > 0) {
      buffer.write(' (↑${kpi.conversionGrowth.toStringAsFixed(0)}%)');
    } else if (kpi.conversionGrowth < 0) {
      buffer.write(' (↓${kpi.conversionGrowth.abs().toStringAsFixed(0)}%)');
    }
    buffer.writeln('.');

    buffer.writeln();
    buffer.write(
        '💰 إجمالي الإيراد ${_formatCurrency(kpi.currentActualRevenue)} ج.م');
    buffer.writeln(' بمتوسط إغلاق ${kpi.currentAvgCloseTime} أيام.');

    if (kpi.currentCollected > 0) {
      buffer.writeln();
      buffer.write(
          '💳 تم تحصيل ${_formatCurrency(kpi.currentCollected)} ج.م');
      buffer.writeln(' (${kpi.collectionRate.toStringAsFixed(0)}% تحصيل).');
    }

    if (kpi.currentMarketingCost > 0) {
      buffer.writeln();
      buffer.write(
          '📢 تكلفة التسويق ${_formatCurrency(kpi.currentMarketingCost)} ج.م');
      buffer.writeln(' بعائد ${kpi.roi.toStringAsFixed(0)}%.');
    }

    if (kpi.totalAlerts > 0) {
      buffer.writeln();
      final alerts = <String>[];
      if (kpi.overdueFollowUps > 0) alerts.add('${kpi.overdueFollowUps} متابعات متأخرة');
      if (kpi.stagnantOpportunities > 0) alerts.add('${kpi.stagnantOpportunities} فرص راكدة');
      if (kpi.overdueTasks > 0) alerts.add('${kpi.overdueTasks} مهام متأخرة');
      if (kpi.openComplaints > 0) alerts.add('${kpi.openComplaints} شكاوى مفتوحة');
      buffer.write('⚠️ يوجد ${alerts.join(' و ')} تحتاج اهتمام.');
    }

    return buffer.toString();
  }
}

// === Models داخلية ===
class _GlassInfo {
  final String label;
  final String value;
  final Widget? growth;

  _GlassInfo(this.label, this.value, this.growth);
}

class _AlertItem {
  final String emoji;
  final String count;
  final String label;

  _AlertItem(this.emoji, this.count, this.label);
}