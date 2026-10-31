import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../services/expense_service.dart';
import '../../services/permission_service.dart';
import '../../services/theme_service.dart';
import '../../core/network/api_client.dart';
import '../../widgets/design_kit.dart';
import '../expenses_screen.dart';
import '../add_expense_screen.dart';
import 'expense_groups_screen.dart';
import '../../widgets/app_drawer.dart';

final NumberFormat _fmtShared = NumberFormat('#,##0');

/// داشبورد المصروفات — يستهلك تعريفات GetDashboardDataAsync العشرة من
/// الخادم كما هي (نمو شهري، متوسط يومي، مقدمات نشطة، توزيع السنة،
/// أعلى 5 فردية، اتجاه 12 شهرًا، اتجاه يومي، تباين، باريتو) على
/// المصروفات المعترف بها فقط. كل النصوص واعية بالوضع عبر AppColors.
class ExpenseDashboardScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ExpenseDashboardScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ExpenseDashboardScreen> createState() =>
      _ExpenseDashboardScreenState();
}

class _ExpenseDashboardScreenState extends State<ExpenseDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  final PermissionService _perms = PermissionService();

  bool get _canAdd => _perms.canAdd(FormNames.expensesAdd) || _perms.isAdmin;
  bool get _canViewGroups =>
      _perms.canView(FormNames.expensesGroup) || _perms.isAdmin;
  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ExpenseService.getDashboard();
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'فشل الاتصال بالخادم';
          _loading = false;
        });
      }
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return _fmtShared.format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  String _date(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      drawer: buildAppDrawer(currentRoute: 'frm_ExpensesList'),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('المصروفات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? AppError(message: _error!, onRetry: _load)
              : _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    final d = _data ?? {};
    final distribution = (d['GroupDistribution'] as List?) ?? [];
    final top = (d['TopExpenses'] as List?) ?? [];
    final trends = (d['MonthlyTrends'] as List?) ?? [];
    final daily = (d['DailyTrend'] as List?) ?? [];
    final variance = (d['VarianceAnalysis'] as List?) ?? [];
    final pareto = (d['ParetoAnalysis'] as List?) ?? [];
    final growth = _num(d['MonthOverMonthGrowth']);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _HeroCard(
            month: d['CurrentMonthAmount'],
            prevMonth: d['PreviousMonthAmount'],
            dailyAverage: d['DailyAverage'],
            growth: growth,
            fmt: _fmt,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuickBtn(
                  icon: Icons.list_alt_rounded,
                  label: 'كل المصروفات',
                  color: isDark ? AppColors.infoLight : AppColors.info,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpensesScreen(
                        userId: widget.userId,
                        username: widget.username,
                      ),
                    ),
                  ),
                ),
              ),
              if (_canAdd) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickBtn(
                    icon: Icons.add_card_rounded,
                    label: 'إضافة مصروف',
                    color: isDark ? AppColors.successLight : AppColors.success,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddExpenseScreen(username: widget.username),
                      ),
                    ),
                  ),
                ),
              ],
              if (_canViewGroups) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickBtn(
                    icon: Icons.category_rounded,
                    label: 'المجموعات',
                    color: AppColors.gold,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExpenseGroupsScreen(
                          userId: widget.userId,
                          username: widget.username,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // المقدمات النشطة: عدد الرؤوس + مجموع أقساطها المتبقية التعريف
          AppStatCard(
            label:
                'مقدمات نشطة — ${_fmt(d['ActiveAdvanceExpensesAmount'])} ج.م',
            value: '${d['ActiveAdvanceExpensesCount'] ?? 0}',
            color: AppColors.gold,
            icon: Icons.schedule_rounded,
          ),
          if (daily.isNotEmpty) ...[
            const SizedBox(height: 20),
            const AppSectionHeader(
              title: 'الاتجاه اليومي — الشهر الحالي',
              icon: Icons.show_chart_rounded,
              accent: AppColors.gold,
            ),
            const SizedBox(height: 10),
            _DailyChart(data: daily, isDark: isDark),
          ],
          if (trends.isNotEmpty) ...[
            const SizedBox(height: 20),
            const AppSectionHeader(
              title: 'اتجاه 12 شهرًا',
              icon: Icons.bar_chart_rounded,
              accent: AppColors.gold,
            ),
            const SizedBox(height: 10),
            _MonthlyChart(data: trends, isDark: isDark, fmt: _fmt),
          ],
          if (distribution.isNotEmpty) ...[
            const SizedBox(height: 20),
            const AppSectionHeader(
              title: 'توزيع مجموعات السنة (أعلى 10)',
              icon: Icons.pie_chart_rounded,
              accent: AppColors.gold,
            ),
            const SizedBox(height: 10),
            _BreakdownCard(items: distribution, fmt: _fmt, isDark: isDark),
          ],
          if (top.isNotEmpty) ...[
            const SizedBox(height: 20),
            const AppSectionHeader(
              title: 'أعلى 5 مصروفات فردية (الشهر)',
              icon: Icons.trending_up_rounded,
              accent: AppColors.gold,
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < top.length; i++)
              _TopRow(
                rank: i + 1,
                item: Map<String, dynamic>.from(top[i] as Map),
                fmt: _fmt,
                date: _date,
                isDark: isDark,
              ),
          ],
          if (variance.isNotEmpty) ...[
            const SizedBox(height: 20),
            const AppSectionHeader(
              title: 'التباين — الشهر مقابل متوسط 3 أشهر سابقة',
              icon: Icons.compare_arrows_rounded,
              accent: AppColors.gold,
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              radius: AppRadius.md,
              child: Column(
                children: [
                  for (final v in variance)
                    _VarianceRow(
                      item: Map<String, dynamic>.from(v as Map),
                      fmt: _fmt,
                      isDark: isDark,
                    ),
                ],
              ),
            ),
          ],
          if (pareto.isNotEmpty) ...[
            const SizedBox(height: 20),
            const AppSectionHeader(
              title: 'تحليل باريتو — منذ بداية السنة',
              icon: Icons.stacked_bar_chart_rounded,
              accent: AppColors.gold,
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              radius: AppRadius.md,
              child: Column(
                children: [
                  for (final p in pareto)
                    _ParetoRow(
                      item: Map<String, dynamic>.from(p as Map),
                      fmt: _fmt,
                      isDark: isDark,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── البطاقة المرجعية: كحلية الهوية في الوضعين ──────────────────
class _HeroCard extends StatelessWidget {
  final dynamic month;
  final dynamic prevMonth;
  final dynamic dailyAverage;
  final double growth;
  final String Function(dynamic) fmt;

  const _HeroCard({
    required this.month,
    required this.prevMonth,
    required this.dailyAverage,
    required this.growth,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = growth >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: AppGradients.identityHeader,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مصروفات الشهر الحالي',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    AmountText(
                      value: '${fmt(month)} ج.م',
                      color: Colors.white,
                      size: 26,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isUp ? AppColors.error : AppColors.success)
                      .withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 14,
                      color: isUp
                          ? AppColors.errorLight
                          : AppColors.successLight,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${isUp ? '+' : ''}${growth.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isUp
                            ? AppColors.errorLight
                            : AppColors.successLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Row(
            children: [
              _mini('الشهر السابق', fmt(prevMonth)),
              _mini('المتوسط اليومي', fmt(dailyAverage)),
              _mini('النمو الشهري', '${growth.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          AmountText(value: value, color: Colors.white, size: 15),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  final List<dynamic> data;
  final bool isDark;

  const _DailyChart({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (final d in data) {
      final m = Map<String, dynamic>.from(d as Map);
      spots.add(FlSpot(
        ((m['Day'] as num?)?.toDouble() ?? 0),
        (m['Amount'] as num?)?.toDouble() ?? 0,
      ));
    }
    var maxY = spots.isEmpty
        ? 1.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= 0) maxY = 1;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 10),
      radius: AppRadius.lg,
      child: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY * 1.15,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(
                color: AppColors.text(isDark).withValues(alpha: 0.05),
                strokeWidth: 1,
              ),
            ),
            titlesData: const FlTitlesData(
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: isDark ? AppColors.errorLight : AppColors.error,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (isDark ? AppColors.errorLight : AppColors.error)
                          .withValues(alpha: 0.3),
                      (isDark ? AppColors.errorLight : AppColors.error)
                          .withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 500),
        ),
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final List<dynamic> data;
  final bool isDark;
  final String Function(dynamic) fmt;

  const _MonthlyChart({
    required this.data,
    required this.isDark,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final values = data.map((d) {
      final m = Map<String, dynamic>.from(d as Map);
      return (m['TotalAmount'] as num?)?.toDouble() ?? 0;
    }).toList();
    var maxY = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b);
    if (maxY <= 0) maxY = 1;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 10),
      radius: AppRadius.lg,
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.15,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= data.length) {
                      return const SizedBox.shrink();
                    }
                    final m = Map<String, dynamic>.from(data[i] as Map);
                    final dt =
                        DateTime.tryParse(m['MonthDate']?.toString() ?? '');
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dt != null ? '${dt.month}' : '',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: 12,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                    color: i == values.length - 1
                        ? AppColors.gold
                        : (isDark
                            ? AppColors.neutralLight
                            : AppColors.navyLight.withValues(alpha: 0.55)),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final List<dynamic> items;
  final String Function(dynamic) fmt;
  final bool isDark;

  const _BreakdownCard({
    required this.items,
    required this.fmt,
    required this.isDark,
  });

  static const List<Color> _colors = [
    AppColors.errorLight,
    AppColors.warning,
    AppColors.infoLight,
    AppColors.successLight,
    AppStatus.editPending,
    AppColors.success,
    AppColors.warningLight,
    AppColors.neutralLight,
    AppColors.gold,
    AppColors.info,
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.md,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colors[i % _colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (items[i]['GroupName'] ?? '—').toString(),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.text(isDark),
                      ),
                    ),
                  ),
                  Text(
                    '${items[i]['Percentage'] ?? 0}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AmountText(value: fmt(items[i]['Total']), size: 12.5),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> item;
  final String Function(dynamic) fmt;
  final String Function(dynamic) date;
  final bool isDark;

  const _TopRow({
    required this.rank,
    required this.item,
    required this.fmt,
    required this.date,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.gold,
      AppColors.neutralLight,
      AppColors.warning,
    ];
    final color =
        rank <= 3 ? colors[rank - 1] : AppColors.textSecondary(isDark);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['ExpenseName'] ?? '—').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(isDark),
                  ),
                ),
                Text(
                  '${item['ExpenseGroupName'] ?? ''} • ${date(item['ExpenseDate'])}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          AmountText(
            value: fmt(item['Amount']),
            size: 13,
            color: isDark ? AppColors.errorLight : AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _VarianceRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(dynamic) fmt;
  final bool isDark;

  const _VarianceRow({
    required this.item,
    required this.fmt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final variance =
        (item['VariancePercentage'] as num?)?.toDouble() ?? 0;
    final isOver = variance > 10;
    final badgeColor = isOver
        ? (isDark ? AppColors.errorLight : AppColors.error)
        : (isDark ? AppColors.successLight : AppColors.success);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['GroupName'] ?? '—').toString(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(isDark),
                  ),
                ),
                Text(
                  'الحالي ${fmt(item['CurrentMonth'])} — متوسط سابق ${fmt(item['PreviousMonthsAverage'])}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            label: '${variance >= 0 ? '+' : ''}${variance.toStringAsFixed(1)}%',
            color: badgeColor,
            small: true,
          ),
        ],
      ),
    );
  }
}

class _ParetoRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(dynamic) fmt;
  final bool isDark;

  const _ParetoRow({
    required this.item,
    required this.fmt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = ((item['Percentage'] as num?)?.toDouble() ?? 0) / 100;
    final cumulative = (item['CumulativePercentage'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (item['ItemName'] ?? '—').toString(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(isDark),
                  ),
                ),
              ),
              AmountText(value: fmt(item['Amount']), size: 12.5),
              const SizedBox(width: 8),
              Text(
                'تراكمي ${cumulative.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0, 1),
              minHeight: 6,
              backgroundColor: AppColors.divider(isDark),
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}
