import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/cashbox_service.dart';
import 'cashbox_transactions_screen.dart';
import 'cashbox_manual_screen.dart';

class CashboxDashboardScreen extends StatefulWidget {
  final int? userId;
  final String? username;

  const CashboxDashboardScreen({
    Key? key,
    this.userId,
    this.username,
  }) : super(key: key);

  @override
  State<CashboxDashboardScreen> createState() => _CashboxDashboardScreenState();
}

class _CashboxDashboardScreenState extends State<CashboxDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  bool loadingPeriod = false;
  String selectedPeriod = 'month';
  int? touchedChartIndex;

  // البيانات
  Map<String, dynamic>? stats;
  List<Map<String, dynamic>> chartData = [];
  List<Map<String, dynamic>> distribution = [];
  List<Map<String, dynamic>> balances = [];
  List<Map<String, dynamic>> recentTransactions = [];
  Map<String, dynamic>? comparison;

  // للتنبيهات
  List<Map<String, dynamic>> alerts = [];

  late AnimationController _animationController;

  final List<Map<String, String>> periods = [
    {'value': 'today', 'label': 'اليوم'},
    {'value': 'week', 'label': 'أسبوع'},
    {'value': 'month', 'label': 'شهر'},
    {'value': 'year', 'label': 'سنة'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => loading = true);

    try {
      await Future.wait([
        _loadPeriodData(),
        _loadFixedData(),
      ]);
      _generateAlerts();
      _animationController.forward(from: 0);
    } catch (e) {
      print('Error loading dashboard: $e');
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadPeriodData() async {
    final results = await Future.wait([
      CashboxService.getDashboardStats(period: selectedPeriod),
      CashboxService.getChartData(days: _getDays()),
      CashboxService.getDistribution(period: selectedPeriod),
    ]);

    if (mounted) {
      setState(() {
        stats = results[0] as Map<String, dynamic>?;
        chartData = results[1] as List<Map<String, dynamic>>;
        distribution = results[2] as List<Map<String, dynamic>>;
      });
    }
  }

  Future<void> _loadFixedData() async {
    final results = await Future.wait([
      CashboxService.getCashboxBalances(),
      CashboxService.getRecentTransactions(limit: 5),
      CashboxService.getMonthlyComparison(),
    ]);

    if (mounted) {
      setState(() {
        balances = results[0] as List<Map<String, dynamic>>;
        recentTransactions = results[1] as List<Map<String, dynamic>>;
        comparison = results[2] as Map<String, dynamic>?;
      });
    }
  }

  void _generateAlerts() {
    alerts.clear();

    // تنبيه: خزنة رصيدها قليل
    for (var b in balances) {
      final balance = (b['Balance'] ?? 0).toDouble();
      if (balance < 1000 && balance >= 0) {
        alerts.add({
          'type': 'warning',
          'icon': Icons.warning_amber,
          'color': Colors.orange,
          'message': 'رصيد ${b['CashBoxName']} منخفض (${_formatCurrencyShort(balance)})',
        });
      } else if (balance < 0) {
        alerts.add({
          'type': 'danger',
          'icon': Icons.error,
          'color': Colors.red,
          'message': '${b['CashBoxName']} رصيدها سالب!',
        });
      }
    }

    // تنبيه: مقارنة بالشهر السابق
    if (comparison != null) {
      final currentOut = (comparison!['CurrentMonthOut'] ?? 0).toDouble();
      final lastOut = (comparison!['LastMonthOut'] ?? 0).toDouble();
      if (lastOut > 0 && currentOut > lastOut * 1.2) {
        alerts.add({
          'type': 'info',
          'icon': Icons.trending_up,
          'color': Colors.blue,
          'message': 'الصرف هذا الشهر أعلى من السابق بـ ${(((currentOut - lastOut) / lastOut) * 100).toStringAsFixed(0)}%',
        });
      }
    }
  }

  Future<void> _onPeriodChanged(String period) async {
    if (selectedPeriod == period) return;

    setState(() {
      selectedPeriod = period;
      loadingPeriod = true;
    });

    await _loadPeriodData();
    _generateAlerts();

    if (mounted) setState(() => loadingPeriod = false);
  }

  int _getDays() {
    switch (selectedPeriod) {
      case 'today':
        return 1;
      case 'week':
        return 7;
      case 'month':
        return 30;
      case 'year':
        return 365;
      default:
        return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: loading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _loadAllData,
              color: const Color(0xFFE8B923),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildMainBalanceCard(),
                          const SizedBox(height: 16),
                          _buildQuickActions(),
                          const SizedBox(height: 20),
                          _buildPeriodSelector(),
                          const SizedBox(height: 16),
                          if (loadingPeriod)
                            _buildPeriodLoading()
                          else ...[
                            _buildStatsRow(),
                            const SizedBox(height: 20),
                            _buildInteractiveChart(),
                            const SizedBox(height: 20),
                            _buildDistributionSection(),
                          ],
                          const SizedBox(height: 20),
                          if (alerts.isNotEmpty) ...[
                            _buildAlertsSection(),
                            const SizedBox(height: 20),
                          ],
                          _buildCashboxBalances(),
                          const SizedBox(height: 20),
                          _buildRecentTransactions(),
                          const SizedBox(height: 20),
                          _buildMonthlyComparison(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // App Bar
  // ════════════════════════════════════════════════════════════

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 60,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE8B923).withOpacity(0.2),
                  const Color(0xFFE8B923).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.analytics, color: Color(0xFFE8B923), size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'مؤشرات الخزينة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 20, color: Colors.white),
          onPressed: _loadAllData,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // Main Balance Card - Header ذكي
  // ════════════════════════════════════════════════════════════

  Widget _buildMainBalanceCard() {
    final totalBalance = (stats?['TotalBalance'] ?? 0).toDouble();
    final lastMonthBalance = (comparison?['CurrentMonthIn'] ?? 0).toDouble() -
        (comparison?['CurrentMonthOut'] ?? 0).toDouble();
    final isUp = lastMonthBalance >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF252525),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE8B923).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8B923).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // العنوان
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B923).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: Color(0xFFE8B923),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'إجمالي الرصيد',
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // الرصيد مع Animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: totalBalance),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text(
                _formatCurrency(value),
                style: GoogleFonts.cairo(
                  color: const Color(0xFFE8B923),
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // مؤشر التغيير
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isUp ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp ? Icons.trending_up : Icons.trending_down,
                  color: isUp ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isUp ? 'زيادة هذا الشهر' : 'انخفاض هذا الشهر',
                  style: GoogleFonts.cairo(
                    color: isUp ? Colors.green : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatCurrencyShort(lastMonthBalance.abs()),
                  style: GoogleFonts.cairo(
                    color: isUp ? Colors.green : Colors.red,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2);
  }

  // ════════════════════════════════════════════════════════════
  // Quick Actions - أزرار سريعة
  // ════════════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            'قبض',
            Icons.arrow_downward,
            Colors.green,
            () => _navigateToManual('قبض'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            'صرف',
            Icons.arrow_upward,
            Colors.red,
            () => _navigateToManual('صرف'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickActionButton(
            'الحركات',
            Icons.list_alt,
            Colors.blue,
            _navigateToTransactions,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2);
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToManual(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CashboxManualScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    ).then((_) => _loadAllData());
  }

  void _navigateToTransactions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CashboxTransactionsScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    ).then((_) => _loadAllData());
  }

  // ════════════════════════════════════════════════════════════
  // Period Selector
  // ════════════════════════════════════════════════════════════

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = selectedPeriod == period['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(period['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            const Color(0xFFE8B923),
                            const Color(0xFFE8B923).withOpacity(0.8),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  period['label']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: isSelected ? Colors.black : Colors.grey[400],
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildPeriodLoading() {
    return Container(
      height: 150,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: Color(0xFFE8B923),
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'جاري تحميل البيانات...',
            style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Stats Row
  // ════════════════════════════════════════════════════════════

  Widget _buildStatsRow() {
    final totalIn = (stats?['TotalIn'] ?? 0).toDouble();
    final totalOut = (stats?['TotalOut'] ?? 0).toDouble();
    final count = stats?['TransactionCount'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'القبض',
            totalIn,
            Icons.arrow_downward,
            Colors.green,
            stats?['InCount'] ?? 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            'الصرف',
            totalOut,
            Icons.arrow_upward,
            Colors.red,
            stats?['OutCount'] ?? 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCardSimple(
            'الحركات',
            count.toString(),
            Icons.swap_horiz,
            Colors.blue,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1);
  }

  Widget _buildStatCard(
    String label,
    double value,
    IconData icon,
    Color color,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.cairo(color: color, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrencyShort(value),
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardSimple(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 10),
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
            style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Interactive Chart - رسم بياني تفاعلي
  // ════════════════════════════════════════════════════════════

  Widget _buildInteractiveChart() {
    if (chartData.isEmpty) {
      return _buildEmptySection('لا توجد بيانات للرسم البياني', Icons.show_chart);
    }

    final data = chartData.length > 7 ? chartData.sublist(chartData.length - 7) : chartData;
    final maxIn = data.map((e) => (e['TotalIn'] ?? 0).toDouble()).fold(0.0, (a, b) => a > b ? a : b);
    final maxOut = data.map((e) => (e['TotalOut'] ?? 0).toDouble()).fold(0.0, (a, b) => a > b ? a : b);
    final maxY = (maxIn > maxOut ? maxIn : maxOut) * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionHeader('حركة الخزينة', Icons.show_chart),
              const Spacer(),
              _buildLegend('القبض', Colors.green),
              const SizedBox(width: 12),
              _buildLegend('الصرف', Colors.red),
            ],
          ),
          const SizedBox(height: 20),

          // Tooltip للنقطة المختارة
          if (touchedChartIndex != null && touchedChartIndex! < data.length)
            _buildChartTooltip(data[touchedChartIndex!]),

          const SizedBox(height: 10),

          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY > 0 ? maxY : 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 25,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[index]['Label'] ?? '',
                              style: GoogleFonts.cairo(
                                color: touchedChartIndex == index
                                    ? const Color(0xFFE8B923)
                                    : Colors.grey[600],
                                fontSize: 9,
                                fontWeight: touchedChartIndex == index
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (response?.lineBarSpots != null &&
                        response!.lineBarSpots!.isNotEmpty) {
                      setState(() {
                        touchedChartIndex = response.lineBarSpots!.first.x.toInt();
                      });
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    //tooltipBgColor: Colors.transparent,
                    getTooltipItems: (spots) => spots.map((spot) => null).toList(),
                  ),
                ),
                lineBarsData: [
                  _buildChartLine(data, 'TotalIn', Colors.green),
                  _buildChartLine(data, 'TotalOut', Colors.red),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildChartTooltip(Map<String, dynamic> point) {
    final totalIn = (point['TotalIn'] ?? 0).toDouble();
    final totalOut = (point['TotalOut'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8B923).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            point['Label'] ?? '',
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              const Icon(Icons.arrow_downward, color: Colors.green, size: 14),
              const SizedBox(width: 4),
              Text(
                _formatCurrencyShort(totalIn),
                style: GoogleFonts.cairo(color: Colors.green, fontSize: 11),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.arrow_upward, color: Colors.red, size: 14),
              const SizedBox(width: 4),
              Text(
                _formatCurrencyShort(totalOut),
                style: GoogleFonts.cairo(color: Colors.red, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  LineChartBarData _buildChartLine(List<Map<String, dynamic>> data, String key, Color color) {
    return LineChartBarData(
      spots: data.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), (e.value[key] ?? 0).toDouble());
      }).toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: touchedChartIndex == index ? 6 : 3,
            color: color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Distribution Section
  // ════════════════════════════════════════════════════════════

  Widget _buildDistributionSection() {
    if (distribution.isEmpty) {
      return _buildEmptySection('لا توجد مصروفات', Icons.pie_chart);
    }

    final data = distribution.take(5).toList();
    final total = data.fold<double>(0, (sum, item) => sum + (item['Total'] ?? 0).toDouble());
    final colors = [Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.pink];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('توزيع المصروفات', Icons.pie_chart),
          const SizedBox(height: 16),
          ...data.asMap().entries.map((entry) {
            final item = entry.value;
            final amount = (item['Total'] ?? 0).toDouble();
            final percent = total > 0 ? (amount / total * 100) : 0.0;
            final color = colors[entry.key % colors.length];

            return _buildDistributionItem(
              _getReferenceTypeLabel(item['ReferenceType']),
              amount,
              percent,
              color,
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildDistributionItem(String label, double amount, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                ),
              ),
              Text(
                _formatCurrencyShort(amount),
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 40,
                child: Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 10),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent / 100,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Alerts Section - تنبيهات ذكية
  // ════════════════════════════════════════════════════════════

  Widget _buildAlertsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('تنبيهات', Icons.notifications_active),
          const SizedBox(height: 12),
          ...alerts.map((alert) => _buildAlertItem(alert)),
        ],
      ),
    ).animate().fadeIn(delay: 650.ms).shake(delay: 700.ms, duration: 500.ms);
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    final color = alert['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          right: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(alert['icon'], color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alert['message'],
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Cashbox Balances - أرصدة الخزائن محسّنة
  // ════════════════════════════════════════════════════════════

  Widget _buildCashboxBalances() {
    if (balances.isEmpty) return const SizedBox.shrink();

    final totalBalance = balances.fold<double>(
      0,
      (sum, item) => sum + (item['Balance'] ?? 0).toDouble(),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('أرصدة الخزائن', Icons.account_balance_wallet),
          const SizedBox(height: 16),
          ...balances.take(5).map((item) {
            final balance = (item['Balance'] ?? 0).toDouble();
            final percent = totalBalance > 0 ? (balance / totalBalance * 100).clamp(0, 100) : 0.0;
            final isPositive = balance >= 0;
            final color = balance < 1000
                ? Colors.orange
                : balance < 0
                    ? Colors.red
                    : Colors.green;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_balance, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['CashBoxName'] ?? '',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${percent.toStringAsFixed(0)}% من الإجمالي',
                              style: GoogleFonts.cairo(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(balance),
                            style: GoogleFonts.cairo(
                              color: color,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isPositive)
                            Text(
                              'سالب!',
                              style: GoogleFonts.cairo(color: Colors.red, fontSize: 9),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress Bar
                  Stack(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percent / 100,
                        child: Container(
                          height: 4,
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
    ).animate().fadeIn(delay: 700.ms);
  }

  // ════════════════════════════════════════════════════════════
  // Recent Transactions - آخر الحركات تفاعلية
  // ════════════════════════════════════════════════════════════

  Widget _buildRecentTransactions() {
    if (recentTransactions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionHeader('آخر الحركات', Icons.history),
              const Spacer(),
              TextButton(
                onPressed: _navigateToTransactions,
                child: Text(
                  'عرض الكل',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFFE8B923),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recentTransactions.map((item) => _buildTransactionItem(item)),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms);
  }

  Widget _buildTransactionItem(Map<String, dynamic> item) {
    final isCredit = item['TransactionType'] == 'قبض';
    final amount = (item['Amount'] ?? 0).toDouble();
    final color = isCredit ? Colors.green : Colors.red;

    String dateStr = '';
    String timeStr = '';
    if (item['TransactionDate'] != null) {
      try {
        final date = DateTime.parse(item['TransactionDate']);
        dateStr = DateFormat('MM/dd').format(date);
        timeStr = DateFormat('hh:mm a').format(date);
      } catch (e) {}
    }

    return GestureDetector(
      onTap: () => _showTransactionDetails(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // الأيقونة
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // التفاصيل
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item['TransactionType'] ?? '',
                        style: GoogleFonts.cairo(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getReferenceColor(item['ReferenceType']).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getReferenceTypeLabel(item['ReferenceType']),
                          style: GoogleFonts.cairo(
                            color: _getReferenceColor(item['ReferenceType']),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item['CashBoxName'] ?? '',
                          style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '$dateStr $timeStr',
                        style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // المبلغ
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}${_formatCurrency(amount)}',
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.chevron_left, color: Colors.grey, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> item) {
    final isCredit = item['TransactionType'] == 'قبض';
    final color = isCredit ? Colors.green : Colors.red;
    final amount = (item['Amount'] ?? 0).toDouble();

    String dateStr = '';
    String timeStr = '';
    if (item['TransactionDate'] != null) {
      try {
        final date = DateTime.parse(item['TransactionDate']);
        dateStr = DateFormat('yyyy/MM/dd').format(date);
        timeStr = DateFormat('hh:mm a').format(date);
      } catch (e) {}
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['TransactionType'] ?? '',
                        style: GoogleFonts.cairo(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        item['CashBoxName'] ?? '',
                        style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isCredit ? '+' : '-'}${_formatCurrency(amount)}',
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),

            // التفاصيل
            _buildDetailRow(Icons.category, 'نوع المرجع', _getReferenceTypeLabel(item['ReferenceType'])),
            _buildDetailRow(Icons.calendar_today, 'التاريخ', dateStr),
            _buildDetailRow(Icons.access_time, 'الوقت', timeStr),

            const SizedBox(height: 24),

            // زر الإغلاق
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withOpacity(0.2),
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('إغلاق', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE8B923), size: 18),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 13)),
          const Spacer(),
          Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Monthly Comparison
  // ════════════════════════════════════════════════════════════

  Widget _buildMonthlyComparison() {
    if (comparison == null) return const SizedBox.shrink();

    final currentIn = (comparison!['CurrentMonthIn'] ?? 0).toDouble();
    final currentOut = (comparison!['CurrentMonthOut'] ?? 0).toDouble();
    final lastIn = (comparison!['LastMonthIn'] ?? 0).toDouble();
    final lastOut = (comparison!['LastMonthOut'] ?? 0).toDouble();

    final inChange = lastIn > 0 ? ((currentIn - lastIn) / lastIn * 100) : 0.0;
    final outChange = lastOut > 0 ? ((currentOut - lastOut) / lastOut * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('مقارنة بالشهر السابق', Icons.compare_arrows),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCompareCard('القبض', currentIn, inChange, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildCompareCard('الصرف', currentOut, outChange, Colors.red)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 900.ms);
  }

  Widget _buildCompareCard(String label, double value, double change, Color color) {
    final isUp = change >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 11)),
          const SizedBox(height: 8),
          Text(
            _formatCurrencyShort(value),
            style: GoogleFonts.cairo(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isUp ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: isUp ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  '${change.abs().toStringAsFixed(1)}%',
                  style: GoogleFonts.cairo(
                    color: isUp ? Colors.green : Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Helper Widgets
  // ════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8B923).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFE8B923), size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 10)),
      ],
    );
  }

  Widget _buildEmptySection(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[700], size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFE8B923), strokeWidth: 2),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل المؤشرات...',
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // Formatters
  // ════════════════════════════════════════════════════════════

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0.00', 'en').format(amount);
  }

  String _formatCurrencyShort(double amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return NumberFormat('#,##0', 'en').format(amount);
  }

  String _getReferenceTypeLabel(String? type) {
    switch (type) {
      case 'Manual': return 'يدوي';
      case 'Transfer': return 'تحويل';
      case 'Payment': return 'سداد';
      case 'Expense': return 'مصروف';
      case 'Payroll': return 'راتب';
      case 'AdvanceExpense': return 'مقدم';
      case 'Charge': return 'رسوم';
      default: return type ?? 'أخرى';
    }
  }

  Color _getReferenceColor(String? type) {
    switch (type) {
      case 'Manual': return Colors.blue;
      case 'Transfer': return Colors.purple;
      case 'Payment': return Colors.green;
      case 'Expense': return Colors.orange;
      case 'Payroll': return Colors.teal;
      case 'AdvanceExpense': return Colors.amber;
      case 'Charge': return Colors.pink;
      default: return Colors.grey;
    }
  }
}