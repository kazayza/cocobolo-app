import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../constants.dart';
import '../../features/home/widgets/home_accent.dart';
import '../../services/permission_service.dart';
import '../cashbox_transactions_screen.dart';
import '../cashbox_manual_screen.dart';
import 'cashbox_manage_screen.dart';

/// مُنسّق أرقام مشترك (مشترك بين كل الكروت — أسرع)
final NumberFormat _fmtShared = NumberFormat('#,##0');


/// ─────────────────────────────────────────────────────────────
///  🏦 لوحة الخزينة — نسخة فخمة 2026
///  - رصيد إجمالي + اليوم (داخل/خارج/صافي) + الشهر
///  - كروت الخزن (الرصيد الحالي لكل خزينة)
///  - رسم آخر 30 يوم (خط بياني متدرج)
///  - توزيع الأنواع + آخر الحركات + دائنون/مدينون
///  - Theme-aware (ليلي/نهاري) + ألوان مخصصة
/// ─────────────────────────────────────────────────────────────
class CashBoxDashboardScreen extends StatefulWidget {
  final int userId;
  final String username;

  const CashBoxDashboardScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<CashBoxDashboardScreen> createState() =>
      _CashBoxDashboardScreenState();
}

class _CashBoxDashboardScreenState extends State<CashBoxDashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  final PermissionService _perms = PermissionService();

  bool get _canManage =>
      _perms.isAdmin || _perms.canAdd(FormNames.cashBoxManual);

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
        Uri.parse('$baseUrl/api/cashbox/dashboard/full'),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        setState(() {
          _data = json['data'] is Map
              ? Map<String, dynamic>.from(json['data'])
              : null;
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

  String _fmtCompact(dynamic v) {
    final n = v is num
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '') ?? 0;
    if (n.abs() >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n.abs() >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  String _timeAgo(dynamic v) {
    if (v == null) return '';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'SaleInvoice':
        return 'فاتورة بيع';
      case 'PurchaseInvoice':
        return 'فاتورة شراء';
      case 'Expense':
        return 'مصروف';
      case 'Payroll':
        return 'رواتب';
      case 'Loan':
        return 'سلفة';
      case 'TransferIn':
      case 'TransferOut':
        return 'تحويل';
      case 'ManualReceipt':
        return 'سند قبض';
      case 'ManualPayment':
        return 'سند صرف';
      case 'OpeningBalance':
        return 'رصيد افتتاحي';
      case null:
        return 'يدوي';
      default:
        return type!;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'SaleInvoice':
        return const Color(0xFF43A047);
      case 'PurchaseInvoice':
        return const Color(0xFFFF9800);
      case 'Expense':
        return const Color(0xFFE53935);
      case 'Payroll':
        return const Color(0xFF9C27B0);
      case 'ManualReceipt':
        return const Color(0xFF26A69A);
      case 'ManualPayment':
        return const Color(0xFFEF5350);
      case 'OpeningBalance':
        return HomeAccent.gold;
      default:
        return HomeAccent.indigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الخزينة'),
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
    final d = _data ?? {};
    final boxes = (d['CashBoxes'] as List?) ?? [];
    final last30 = (d['Last30Days'] as List?) ?? [];
    final breakdown = (d['TypeBreakdown'] as List?) ?? [];
    final recent = (d['RecentTransactions'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      color: HomeAccent.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── البطاقة الرئيسية (الرصيد) ──────────────────
          _HeroCard(
            totalBalance: d['TotalBalance'],
            todayIn: d['TodayIn'],
            todayOut: d['TodayOut'],
            todayNet: d['TodayNet'],
            monthIn: d['MonthIn'],
            monthOut: d['MonthOut'],
            boxesCount: d['CashBoxesCount'],
            isDark: isDark,
          ),

          const SizedBox(height: 14),

          // ── أزرار سريعة ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _QuickActionBtn(
                  icon: Icons.receipt_long_rounded,
                  label: 'كل الحركات',
                  color: HomeAccent.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CashboxTransactionsScreen(
                        userId: widget.userId,
                        username: widget.username,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (_canManage)
                Expanded(
                  child: _QuickActionBtn(
                    icon: Icons.add_card_rounded,
                    label: 'حركة جديدة',
                    color: HomeAccent.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CashboxManualScreen(
                          userId: widget.userId,
                          username: widget.username,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionBtn(
                  icon: Icons.settings_rounded,
                  label: 'إدارة الخزن',
                  color: HomeAccent.amber,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CashBoxManageScreen(
                        userId: widget.userId,
                        username: widget.username,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── الخزن ──────────────────────────────────────
          if (boxes.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.account_balance_wallet_rounded,
              title: 'الخزن (${boxes.length})',
              color: HomeAccent.gold,
            ),
            const SizedBox(height: 10),
            for (final box in boxes)
              _CashBoxCard(box: Map<String, dynamic>.from(box), theme: theme),
            const SizedBox(height: 10),
          ],

          // ── رسم آخر 30 يوم ────────────────────────────
          if (last30.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.show_chart_rounded,
              title: 'آخر 30 يوم',
              color: HomeAccent.indigo,
            ),
            const SizedBox(height: 10),
            _MovementChart(data: last30, isDark: isDark),
            const SizedBox(height: 10),
          ],

          // ── توزيع الأنواع ─────────────────────────────
          if (breakdown.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.pie_chart_rounded,
              title: 'توزيع الحركات',
              color: HomeAccent.teal,
            ),
            const SizedBox(height: 10),
            for (final item in breakdown)
              _BreakdownRow(
                item: Map<String, dynamic>.from(item),
                fmt: _fmt,
                typeLabel: _typeLabel,
                typeColor: _typeColor,
              ),
            const SizedBox(height: 10),
          ],

          // ── آخر الحركات ───────────────────────────────
          if (recent.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.history_rounded,
              title: 'آخر الحركات',
              color: HomeAccent.purple,
            ),
            const SizedBox(height: 10),
            for (final tx in recent)
              _RecentTxRow(
                tx: Map<String, dynamic>.from(tx),
                fmt: _fmt,
                timeAgo: _timeAgo,
                typeLabel: _typeLabel,
              ),
            const SizedBox(height: 10),
          ],

          // ── دائنون/مدينون ─────────────────────────────
          if ((d['TotalCreditors'] ?? 0) > 0 ||
              (d['TotalDebtors'] ?? 0) > 0) ...[
            _SectionTitle(
              icon: Icons.balance_rounded,
              title: 'الحسابات الشخصية',
              color: HomeAccent.orange,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CreditorCard(
                    label: 'دائنون (لنا)',
                    value: d['TotalCreditors'],
                    color: const Color(0xFF43A047),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CreditorCard(
                    label: 'مدينون (علينا)',
                    value: d['TotalDebtors'],
                    color: const Color(0xFFE53935),
                    isDark: isDark,
                  ),
                ),
              ],
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
  final dynamic totalBalance;
  final dynamic todayIn;
  final dynamic todayOut;
  final dynamic todayNet;
  final dynamic monthIn;
  final dynamic monthOut;
  final dynamic boxesCount;
  final bool isDark;

  const _HeroCard({
    required this.totalBalance,
    required this.todayIn,
    required this.todayOut,
    required this.todayNet,
    required this.monthIn,
    required this.monthOut,
    required this.boxesCount,
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
    final net = todayNet is num ? (todayNet as num).toDouble() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? [const Color(0xFF0A1626), HomeAccent.navyLight]
              : [const Color(0xFF0E2A47), const Color(0xFF1E4E7B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: HomeAccent.gold.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: HomeAccent.gold.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
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
                  color: HomeAccent.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: HomeAccent.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إجمالي الرصيد',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmt(totalBalance)} ج.م',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${boxesCount ?? 0} خزنة',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 14),
          // اليوم
          Row(
            children: [
              _miniStat('اليوم داخل', todayIn, const Color(0xFF81C784)),
              _miniStat('اليوم خارج', todayOut, const Color(0xFFFF8A80)),
              _miniStat(
                'صافي اليوم',
                todayNet,
                net >= 0 ? const Color(0xFF81C784) : const Color(0xFFFF8A80),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 10),
          // الشهر
          Row(
            children: [
              _miniStat('الشهر داخل', monthIn, const Color(0xFF81C784)),
              _miniStat('الشهر خارج', monthOut, const Color(0xFFFF8A80)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, dynamic value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            _fmt(value),
            style: TextStyle(
              color: color,
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

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
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

class _CashBoxCard extends StatelessWidget {
  final Map<String, dynamic> box;
  final ThemeData theme;

  const _CashBoxCard({required this.box, required this.theme});

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return _fmtShared.format(
      v is num ? v : double.tryParse(v.toString()) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = box['CurrentBalance'] ?? 0;
    final isPositive = (balance is num ? balance : 0) >= 0;
    final color = isPositive ? const Color(0xFF43A047) : const Color(0xFFE53935);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: HomeAccent.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 18,
              color: HomeAccent.gold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  box['CashBoxName'] ?? '—',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if ((box['Description'] ?? '').toString().isNotEmpty)
                  Text(
                    box['Description'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(balance),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                '${box['TransactionsCount'] ?? 0} حركة',
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovementChart extends StatelessWidget {
  final List<dynamic> data;
  final bool isDark;

  const _MovementChart({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final spots = <FlSpot>[];
    var i = 0;
    for (final item in data) {
      final net = ((item['In'] ?? 0) is num
              ? (item['In'] as num)
              : double.tryParse((item['In'] ?? 0).toString()) ?? 0) -
          ((item['Out'] ?? 0) is num
              ? (item['Out'] as num)
              : double.tryParse((item['Out'] ?? 0).toString()) ?? 0);
      spots.add(FlSpot(i.toDouble(), net.toDouble()));
      i++;
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
    // لو كل القيم متساوية (مثلاً كل الأيام صفر) → نوسّع المدى عشان الرسم يشتغل
    if ((maxY - minY).abs() < 1) {
      final pad = minY.abs() < 1 ? 1 : minY.abs() * 0.1;
      minY -= pad;
      maxY += pad;
    } else {
      final spread = (maxY - minY) * 0.1;
      minY -= spread;
      maxY += spread;
    }
    // فاصل خطوط الشبكة: 4 خطوط فقط مهما كان حجم الأرقام
    var hInterval = (maxY - minY) / 4;
    if (hInterval <= 0) {
      minY -= 1;
      maxY += 1;
      hInterval = (maxY - minY) / 4;
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
            horizontalInterval: hInterval,
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
              color: HomeAccent.accent,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    HomeAccent.accent.withValues(alpha: 0.3),
                    HomeAccent.accent.withValues(alpha: 0.02),
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

class _BreakdownRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(dynamic) fmt;
  final String Function(String?) typeLabel;
  final Color Function(String?) typeColor;

  const _BreakdownRow({
    required this.item,
    required this.fmt,
    required this.typeLabel,
    required this.typeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = item['ReferenceType']?.toString();
    final color = typeColor(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              typeLabel(type),
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '${item['Count'] ?? 0}',
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            fmt(item['Total']),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTxRow extends StatelessWidget {
  final Map<String, dynamic> tx;
  final String Function(dynamic) fmt;
  final String Function(dynamic) timeAgo;
  final String Function(String?) typeLabel;

  const _RecentTxRow({
    required this.tx,
    required this.fmt,
    required this.timeAgo,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = tx['TransactionType'] == 'قبض';
    final color = isIn ? const Color(0xFF43A047) : const Color(0xFFE53935);

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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['Notes'] ?? typeLabel(tx['ReferenceType']?.toString()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${tx['CashBoxName'] ?? ''} • ${timeAgo(tx['TransactionDate'])}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIn ? '+' : '-'} ${fmt(tx['Amount'])}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditorCard extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;
  final bool isDark;

  const _CreditorCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final v = value is num ? value : double.tryParse(value?.toString() ?? '') ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            NumberFormat('#,##0').format(v),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
