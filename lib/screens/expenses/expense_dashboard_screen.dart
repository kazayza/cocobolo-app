import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../constants.dart';
import '../../features/home/widgets/home_accent.dart';
import '../../services/permission_service.dart';
import '../expenses_screen.dart';
import '../add_expense_screen.dart';
import 'expense_groups_screen.dart';

/// مُنسّق أرقام مشترك (مشترك بين كل الكروت — أسرع)
final NumberFormat _fmtShared = NumberFormat('#,##0');

/// ─────────────────────────────────────────────────────────────
///  💰 داشبورد المصروفات — نسخة فخمة 2026
///  - كروت: إجمالي الشهر + اليوم + مقارنة بالشهر السابق
///  - رسم آخر 30 يوم (خط متدرج)
///  - توزيع المجموعات + أعلى 5 مصروفات + آخر المصروفات
///  - Theme-aware (ليلي/نهاري) + ألوان مخصصة
/// ─────────────────────────────────────────────────────────────
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
      final res = await http.get(
        Uri.parse('$baseUrl/api/expenses/dashboard'),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        setState(() {
          _data = json is Map ? Map<String, dynamic>.from(json) : null;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'فشل تحميل البيانات (${res.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'فشل الاتصال بالخادم';
        _loading = false;
      });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return _fmtShared.format(
      v is num ? v : double.tryParse(v.toString()) ?? 0,
    );
  }

  String _date(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
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
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _error != null
              ? _buildError(theme)
              : _buildBody(theme, isDark),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 60, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(_error!,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    final summary = (_data?['summary'] ?? {}) is Map
        ? Map<String, dynamic>.from(_data!['summary'])
        : {};
    final last30 = (_data?['last30Days'] as List?) ?? [];
    final breakdown = (_data?['breakdown'] as List?) ?? [];
    final recent = (_data?['recent'] as List?) ?? [];
    final top = (_data?['topExpenses'] as List?) ?? [];

    final month = summary['monthAmount'] ?? 0;
    final prevMonth = summary['prevMonthAmount'] ?? 0;
    final today = summary['todayAmount'] ?? 0;

    // نسبة التغير
    double? changePct;
    final prev = prevMonth is num ? prevMonth.toDouble() : 0;
    final cur = month is num ? month.toDouble() : 0;
    if (prev > 0) {
      changePct = ((cur - prev) / prev) * 100;
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: HomeAccent.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── البطاقة الرئيسية ──────────────────────────
          _HeroCard(
            month: month,
            today: today,
            changePct: changePct,
            count: summary['totalCount'],
            isDark: isDark,
          ),

          const SizedBox(height: 14),

          // ── أزرار سريعة ───────────────────────────────
          Row(
            children: [
              Expanded(
                child: _QuickBtn(
                  icon: Icons.list_alt_rounded,
                  label: 'كل المصروفات',
                  color: HomeAccent.indigo,
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
                    color: HomeAccent.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddExpenseScreen(
                          username: widget.username,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: _QuickBtn(
                  icon: Icons.category_rounded,
                  label: 'المجموعات',
                  color: HomeAccent.amber,
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
          ),

          // ── رسم آخر 30 يوم ────────────────────────────
          if (last30.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle(
              icon: Icons.show_chart_rounded,
              title: 'آخر 30 يوم',
              color: HomeAccent.red,
            ),
            const SizedBox(height: 10),
            _ExpenseChart(data: last30, isDark: isDark),
          ],

          // ── توزيع المجموعات ───────────────────────────
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle(
              icon: Icons.pie_chart_rounded,
              title: 'توزيع المجموعات (الشهر)',
              color: HomeAccent.teal,
            ),
            const SizedBox(height: 10),
            _BreakdownCard(items: breakdown, fmt: _fmt),
          ],

          // ── أعلى 5 مصروفات ────────────────────────────
          if (top.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle(
              icon: Icons.trending_up_rounded,
              title: 'أعلى المصروفات (الشهر)',
              color: HomeAccent.orange,
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < top.length; i++)
              _TopRow(
                rank: i + 1,
                item: Map<String, dynamic>.from(top[i]),
                fmt: _fmt,
              ),
          ],

          // ── آخر المصروفات ─────────────────────────────
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle(
              icon: Icons.history_rounded,
              title: 'آخر المصروفات',
              color: HomeAccent.purple,
            ),
            const SizedBox(height: 10),
            for (final item in recent)
              _RecentRow(
                item: Map<String, dynamic>.from(item),
                fmt: _fmt,
                date: _date,
              ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  final dynamic month;
  final dynamic today;
  final double? changePct;
  final dynamic count;
  final bool isDark;

  const _HeroCard({
    required this.month,
    required this.today,
    required this.changePct,
    required this.count,
    required this.isDark,
  });

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return _fmtShared.format(
      v is num ? v : double.tryParse(v.toString()) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUp = (changePct ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: const [
            Color(0xFF7A1F1F),
            Color(0xFFB23B3B),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB23B3B).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
                    Text(
                      '${_fmt(month)} ج.م',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              // نسبة التغير
              if (changePct != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isUp ? Colors.red : Colors.green).withValues(
                      alpha: 0.3,
                    ),
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
                            ? const Color(0xFFFFCDD2)
                            : const Color(0xFFC8E6C9),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${isUp ? '+' : ''}${changePct!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isUp
                              ? const Color(0xFFFFCDD2)
                              : const Color(0xFFC8E6C9),
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
              _mini('اليوم', today),
              _mini('عدد المصروفات', count),
              _mini('الشهر السابق', changePct != null ? month : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, dynamic value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            _fmt(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
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
  final VoidCallback onTap;

  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ExpenseChart extends StatelessWidget {
  final List<dynamic> data;
  final bool isDark;

  const _ExpenseChart({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // آخر 7 أيام بس (أسرع)
    final limited = data.length > 7 ? data.sublist(data.length - 7) : data;

    final spots = <FlSpot>[];
    for (var i = 0; i < limited.length; i++) {
      final v = (limited[i]['Total'] ?? 0) is num
          ? (limited[i]['Total'] as num).toDouble()
          : double.tryParse((limited[i]['Total'] ?? 0).toString()) ?? 0;
      spots.add(FlSpot(i.toDouble(), v));
    }

    if (spots.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'لا توجد بيانات',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    var minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    var maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    // لو كل القيم متساوية → نوسّع المدى عشان الرسم يشتغل
    if ((maxY - minY).abs() < 1) {
      final pad = minY.abs() < 1 ? 1 : minY.abs() * 0.1;
      minY -= pad;
      maxY += pad;
    } else {
      final spread = (maxY - minY) * 0.1;
      minY -= spread;
      maxY += spread;
    }

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: const Color(0xFFEF5350),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFEF5350).withValues(alpha: 0.3),
                    const Color(0xFFEF5350).withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final List<dynamic> items;
  final String Function(dynamic) fmt;

  const _BreakdownCard({required this.items, required this.fmt});

  static const List<Color> _colors = [
    Color(0xFFEF5350),
    Color(0xFFFF9800),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFF26A69A),
    Color(0xFFFFA726),
    Color(0xFF78909C),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
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
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${items[i]['Count'] ?? 0}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    fmt(items[i]['Total']),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
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

  const _TopRow({
    required this.rank,
    required this.item,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final color = rank <= 3 ? colors[rank - 1] : theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
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
            child: Text(
              (item['ExpenseName'] ?? '—').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            fmt(item['Total']),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFEF5350),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(dynamic) fmt;
  final String Function(dynamic) date;

  const _RecentRow({
    required this.item,
    required this.fmt,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFEF5350),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
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
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${item['ExpenseGroupName'] ?? ''} • ${date(item['ExpenseDate'])}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '- ${fmt(item['Amount'])}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFFEF5350),
            ),
          ),
        ],
      ),
    );
  }
}
