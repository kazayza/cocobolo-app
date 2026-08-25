import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../../services/permission_service.dart';
import '../models/home_dashboard_config.dart';
import '../providers/home_provider.dart';
import 'home_accent.dart';
import 'section_header.dart';

/// ─────────────────────────────────────────────────────────────
///  كاروسيل مالي متحرك — كروت بعرض الشاشة قابلة للسحب
///  💰 رصيد الخزينة • 📈 المبيعات • 💸 مصروفات الشهر
///  - تمرير تلقائي (Auto-play) + سحب يدوي + نقاط تنقل
///  - كل كارت يظهر حسب صلاحيات المستخدم
///  - على الشاشات الواسعة: الكروت جنب بعض بدل التمرير
/// ─────────────────────────────────────────────────────────────
class FinanceCarousel extends StatefulWidget {
  const FinanceCarousel({super.key});

  @override
  State<FinanceCarousel> createState() => _FinanceCarouselState();
}

class _FinanceCarouselState extends State<FinanceCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.92);
  Timer? _autoPlay;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlay?.cancel();
    _autoPlay = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_currentPage + 1) % _cardCount();
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _stopAutoPlay() {
    _autoPlay?.cancel();
    _autoPlay = null;
  }

  int _cardCount() {
    final perms = PermissionService();
    var count = 0;
    if (perms.canView(FormNames.cashBoxDashboard)) count++;
    if (perms.canSeeAllSales) count++;
    if (perms.canView(FormNames.expensesList)) count++;
    return count;
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perms = PermissionService();
    final cards = <Widget>[];

    if (perms.canView(FormNames.cashBoxDashboard)) {
      cards.add(_FinanceCard.cashbox(context));
    }
    if (perms.canSeeAllSales) {
      cards.add(_FinanceCard.sales(context));
    }
    if (perms.canView(FormNames.expensesList)) {
      cards.add(_FinanceCard.expenses(context));
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'ملخص الأعمال',
          subtitle: 'اسحب يميناً أو يساراً لاستعراض المؤشرات',
        ),
        const SizedBox(height: 14),
        // ── شاشات واسعة: الكروت جنب بعض ─────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            }

            // ── موبايل/تابلت: كاروسيل متحرك ─────────────
            return Column(
              children: [
                // Listener لوقف التمرير التلقائي أثناء السحب اليدوي
                Listener(
                  onPointerDown: (_) => _stopAutoPlay(),
                  onPointerUp: (_) {
                    Future.delayed(const Duration(seconds: 4), () {
                      if (mounted) _startAutoPlay();
                    });
                  },
                  onPointerCancel: (_) {
                    Future.delayed(const Duration(seconds: 4), () {
                      if (mounted) _startAutoPlay();
                    });
                  },
                  child: SizedBox(
                    height: 180,
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: cards.length,
                      onPageChanged: (i) {
                        setState(() => _currentPage = i);
                        _startAutoPlay();
                      },
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: cards[i],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // نقاط التنقل
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < cards.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _currentPage ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? HomeAccent.gold
                              : Theme.of(context).colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// الكروت
// ═══════════════════════════════════════════════════════════

class _FinanceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final Color accent;
  final String? footer;
  final String? changePercent;

  const _FinanceCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.accent,
    this.footer,
    this.changePercent,
  });

  static final NumberFormat _fmt = NumberFormat('#,##0');

  static String _num(dynamic v) {
    if (v == null) return '--';
    if (v is num) return _fmt.format(v);
    final s = v.toString();
    return s.isEmpty ? '--' : s;
  }

  /// نسبة التغير بين الشهر الحالي والسابق
  static String? _percentChange(dynamic current, dynamic previous) {
    final cur = current is num
        ? current.toDouble()
        : double.tryParse(current?.toString() ?? '') ?? 0;
    final prev = previous is num
        ? previous.toDouble()
        : double.tryParse(previous?.toString() ?? '') ?? 0;

    if (prev <= 0) {
      return cur > 0 ? null : null; // مفيش مقارنة واضحة
    }
    final pct = ((cur - prev) / prev) * 100;
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
  }

  // ── 💰 رصيد الخزينة ───────────────────────────────────
  static _FinanceCard cashbox(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final balance = provider.summary['cashboxBalance'];
    final count = provider.summary['cashboxCount'];

    return _FinanceCard(
      title: 'رصيد الخزينة',
      subtitle: count != null ? 'مجموع $count خزائن' : 'إجمالي الأرصدة',
      value: _num(balance),
      icon: Icons.savings_rounded,
      gradient: const [Color(0xFF0E4D45), Color(0xFF1B6E63)],
      accent: const Color(0xFF26A69A),
      footer: 'محدث مع آخر تحديث للبيانات',
    );
  }

  // ── 📈 مبيعات الشهر ───────────────────────────────────
  static _FinanceCard sales(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final month = provider.summary['salesMonth'];
    final today = provider.summary['salesToday'];
    final prev = provider.summary['salesPrevMonth'];

    return _FinanceCard(
      title: 'مبيعات الشهر',
      subtitle: today != null && (today as num) > 0
          ? 'منها ${_num(today)} اليوم'
          : 'إجمالي مبيعات الشهر الحالي',
      value: _num(month),
      icon: Icons.trending_up_rounded,
      gradient: const [HomeAccent.navyDark, HomeAccent.navyLight],
      accent: HomeAccent.gold,
      changePercent: _percentChange(month, prev),
      footer: 'مقارنة بالشهر السابق',
    );
  }

  // ── 💸 مصروفات الشهر ──────────────────────────────────
  static _FinanceCard expenses(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final month = provider.summary['monthExpenses'];
    final today = provider.summary['todayExpenses'];

    return _FinanceCard(
      title: 'مصروفات الشهر',
      subtitle: today != null && (today as num) > 0
          ? 'منها ${_num(today)} اليوم'
          : 'إجمالي الشهر الحالي',
      value: _num(month),
      icon: Icons.account_balance_wallet_rounded,
      gradient: const [Color(0xFF7A1F1F), Color(0xFFB23B3B)],
      accent: const Color(0xFFEF5350),
      footer: 'الشهر الحالي',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // توهج زخرفي
          Positioned(
            top: -30,
            right: -25,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.18),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (changePercent != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (changePercent!.startsWith('+'))
                        ? const Color(0xFF43A047).withValues(alpha: 0.25)
                        : const Color(0xFFE53935).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        changePercent!.startsWith('+')
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14,
                        color: changePercent!.startsWith('+')
                            ? const Color(0xFF81C784)
                            : const Color(0xFFEF9A9A),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        changePercent!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: changePercent!.startsWith('+')
                              ? const Color(0xFF81C784)
                              : const Color(0xFFEF9A9A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // القيمة الكبيرة
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        'ج.م',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (footer != null)
                Text(
                  footer!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
