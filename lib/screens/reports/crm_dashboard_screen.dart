import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:percent_indicator/percent_indicator.dart'; // تأكد إنك ضفت المكتبة دي
import '../../services/dashboard_service.dart';

class CRMDashboardScreen extends StatefulWidget {
  final int userId;
  final String username;

  const CRMDashboardScreen({super.key, required this.userId, required this.username});

  @override
  State<CRMDashboardScreen> createState() => _CRMDashboardScreenState();
}

class _CRMDashboardScreenState extends State<CRMDashboardScreen> with SingleTickerProviderStateMixin {
  final _dashboardService = DashboardService();
  bool _isLoading = true;
  Map<String, dynamic> _data = {};
  
  // الفلاتر
  String _selectedPeriod = 'this_month'; 
  DateTimeRange? _selectedDateRange;
  int? _selectedEmployeeId;

  // Pie Chart Animation
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedPeriod = 'custom';
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    String? dateFrom;
    String? dateTo;
    final now = DateTime.now();

    if (_selectedPeriod == 'custom' && _selectedDateRange != null) {
      dateFrom = intl.DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
      dateTo = intl.DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);
    } else if (_selectedPeriod == 'this_month') {
      dateFrom = intl.DateFormat('yyyy-MM-01').format(now);
      dateTo = intl.DateFormat('yyyy-MM-dd').format(now);
    } else if (_selectedPeriod == 'last_month') {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      dateFrom = intl.DateFormat('yyyy-MM-01').format(lastMonth);
      dateTo = intl.DateFormat('yyyy-MM-01').format(DateTime(now.year, now.month, 0));
    } else if (_selectedPeriod == 'this_year') {
      dateFrom = intl.DateFormat('yyyy-01-01').format(now);
      dateTo = intl.DateFormat('yyyy-MM-dd').format(now);
    }

    try {
      final data = await _dashboardService.getDashboardData(
        dateFrom: dateFrom,
        dateTo: dateTo,
        employeeId: _selectedEmployeeId,
      );
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if(mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Darker background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: Text('لوحة القيادة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: const Color(0xFFFFD700))),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))) 
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFFFFD700),
              backgroundColor: const Color(0xFF1E1E1E),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. الفلاتر
                    _buildFilterBar(),
                    const SizedBox(height: 24),

                    // 2. كروت الـ KPI (Animated)
                    _buildKPIGrid(),
                    const SizedBox(height: 24),

                    // 3. تحليل المصادر (Pie Chart)
                    _buildGlassCard(
                      title: 'تحليل مصادر العملاء',
                      icon: FontAwesomeIcons.chartPie,
                      color: Colors.blueAccent,
                      child: _buildSourcesChart(),
                    ),
                    const SizedBox(height: 20),

                    // 4. قمع المبيعات (Sales Funnel)
                    _buildGlassCard(
                      title: 'قمع المبيعات (Funnel)',
                      icon: FontAwesomeIcons.filter,
                      color: Colors.orangeAccent,
                      child: _buildFunnelChart(),
                    ),
                    const SizedBox(height: 20),

                    // 5. أفضل الموظفين (Leaderboard)
                    _buildGlassCard(
                      title: 'لوحة الشرف (Top Team)',
                      icon: FontAwesomeIcons.trophy,
                      color: const Color(0xFFFFD700),
                      child: _buildLeaderboard(),
                    ),
                    const SizedBox(height: 20),
                    
                    // 6. تحليل الخسارة
                    if ((_data['lostReasons'] as List? ?? []).isNotEmpty) 
                      _buildGlassCard(
                        title: 'لماذا نخسر الفرص؟',
                        icon: FontAwesomeIcons.circleXmark,
                        color: Colors.redAccent,
                        child: _buildLostReasonsList(),
                      ),
                      
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // ==========================================
  // 🎨 Widgets الاحترافية
  // ==========================================

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('هذا الشهر', 'this_month'),
          const SizedBox(width: 8),
          _buildFilterChip('الشهر الماضي', 'last_month'),
          const SizedBox(width: 8),
          _buildFilterChip('هذه السنة', 'this_year'),
          const SizedBox(width: 8),
          ActionChip(
            label: Row(
              children: [
                const Icon(Icons.date_range, size: 16, color: Colors.black),
                const SizedBox(width: 6),
                Text(
                  _selectedPeriod == 'custom' && _selectedDateRange != null
                      ? '${intl.DateFormat('MM/dd').format(_selectedDateRange!.start)} - ${intl.DateFormat('MM/dd').format(_selectedDateRange!.end)}'
                      : 'فترة مخصصة',
                  style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: _selectedPeriod == 'custom' ? const Color(0xFFFFD700) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: _selectDateRange,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _selectedPeriod == value;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.cairo(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      )),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPeriod = value);
          _loadData();
        }
      },
      selectedColor: const Color(0xFFFFD700),
      backgroundColor: const Color(0xFF2C2C2C),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildKPIGrid() {
    final kpi = _data['kpi'] ?? {};
    
    // حساب نسب النمو
    double calcGrowth(dynamic current, dynamic prev) {
      double c = (current ?? 0).toDouble();
      double p = (prev ?? 0).toDouble();
      if (p == 0) return 100.0; // لو اللي فات صفر، النمو 100%
      return ((c - p) / p) * 100;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                'إجمالي المبيعات', 
                _formatCurrency(kpi['currentRevenue']), 
                FontAwesomeIcons.sackDollar, 
                const [Color(0xFF11998e), Color(0xFF38ef7d)],
                growth: calcGrowth(kpi['currentRevenue'], kpi['prevRevenue']),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKPICard(
                'إجمالي الفرص', 
                '${kpi['currentOpportunities'] ?? 0}', 
                FontAwesomeIcons.usersViewfinder, 
                const [Color(0xFF2193b0), Color(0xFF6dd5ed)],
                growth: calcGrowth(kpi['currentOpportunities'], kpi['prevOpportunities']),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                'نسبة التحويل', 
                '${(kpi['currentConversion'] ?? 0).toStringAsFixed(1)}%', 
                FontAwesomeIcons.percent, 
                const [Color(0xFFf12711), Color(0xFFf5af19)],
                growth: calcGrowth(kpi['currentConversion'], kpi['prevConversion']),
              ),
            ),
            // ممكن نضيف كارت رابع هنا
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, List<Color> gradient, {double? growth}) {
    bool isPositive = (growth ?? 0) >= 0;
    
    return Container(
      height: 130, // زودنا الارتفاع شوية
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: gradient.first.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.bold)),
              FaIcon(icon, color: Colors.white.withOpacity(0.8), size: 18),
            ],
          ),
          Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          
          // مؤشر النمو
          if (growth != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? Colors.white : Colors.redAccent,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${growth.abs().toStringAsFixed(1)}%',
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'مقارنة بالسابق',
                    style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildGlassCard({required String title, required IconData icon, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Text(title, style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildSourcesChart() {
    final sources = _data['sources'] as List? ?? [];
    if (sources.isEmpty) return const Text('لا توجد بيانات', style: TextStyle(color: Colors.grey));

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 4,
          centerSpaceRadius: 40,
          sections: sources.asMap().entries.map((entry) {
            final isTouched = entry.key == _touchedIndex;
            final fontSize = isTouched ? 16.0 : 12.0;
            final radius = isTouched ? 60.0 : 50.0;
            final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
            
            return PieChartSectionData(
              color: colors[entry.key % colors.length],
              value: (entry.value['value'] as int).toDouble(),
              title: '${entry.value['name']}\n${entry.value['value']}',
              radius: radius,
              titleStyle: GoogleFonts.cairo(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFunnelChart() {
    final funnel = _data['funnel'] as List? ?? [];
    if (funnel.isEmpty) return const Text('لا توجد بيانات', style: TextStyle(color: Colors.grey));

    int maxVal = 0;
    for(var f in funnel) { if((f['count'] as int) > maxVal) maxVal = f['count']; }

    return Column(
      children: funnel.map((item) {
        double widthFactor = maxVal == 0 ? 0 : (item['count'] as int) / maxVal;
        if (widthFactor < 0.15) widthFactor = 0.15;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  item['stage'], 
                  style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: widthFactor),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOutQuart,
                  builder: (context, value, child) {
                    return Stack(
                      children: [
                        Container(
                          height: 28,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                        ),
                        FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [const Color(0xFFFFD700), const Color(0xFFFFD700).withOpacity(0.6)]),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3), blurRadius: 6)],
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('${item['count']}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaderboard() {
    final leaders = _data['leaderboard'] as List? ?? [];
    if (leaders.isEmpty) return const Text('لا توجد بيانات', style: TextStyle(color: Colors.grey));

    return Column(
      children: leaders.asMap().entries.map((entry) {
        final index = entry.key;
        final emp = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: index == 0 ? const Color(0xFFFFD700).withOpacity(0.5) : Colors.transparent),
          ),
          child: Row(
            children: [
              if (index == 0) const FaIcon(FontAwesomeIcons.crown, color: Color(0xFFFFD700), size: 18)
              else Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emp['FullName'], style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${emp['wonDeals']} صفقات ناجحة', style: GoogleFonts.cairo(color: Colors.greenAccent, fontSize: 11)),
                  ],
                ),
              ),
              Text(_formatCurrency(emp['totalRevenue']), style: GoogleFonts.cairo(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLostReasonsList() {
    final reasons = _data['lostReasons'] as List? ?? [];
    return Column(
      children: reasons.map((reason) {
        final double totalLost = (reasons.fold(0, (sum, item) => sum + (item['value'] as int))).toDouble();
        final double percent = (reason['value'] as int) / totalLost;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(reason['name'], style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
                  Text('${reason['value']}', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              LinearPercentIndicator(
                lineHeight: 6.0,
                percent: percent,
                backgroundColor: Colors.white10,
                progressColor: Colors.redAccent,
                barRadius: const Radius.circular(3),
                padding: EdgeInsets.zero,
                animation: true,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final formatter = intl.NumberFormat.compactCurrency(symbol: '', decimalDigits: 1);
    return formatter.format(amount) + ' ج.م';
  }
}