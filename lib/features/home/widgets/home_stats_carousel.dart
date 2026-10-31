import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/permission_service.dart';
import '../providers/home_provider.dart';
import 'cashbox_week_chart.dart';
import 'crm_summary_card.dart';
import 'home_accent.dart';

/// كاروسيل الإحصائيات — موضع واحد في الرئيسية يضم صفحتين قابلتين
/// للسحب يمينًا ويسارًا:
///  • إحصائيات إدارة علاقات العملاء (بوابتها: بطاقات CRM في إعدادات
///    الرئيسية — يمرّرها الأب كما كانت تُعرَض البطاقة منفردة).
///  • حركة الخزينة — آخر 7 أيام (بوابتها: صلاحية لوحة الخزينة
///    frm_CashBoxDashboard — نفس بوابة الشارت منذ إنشائه).
/// القواعد: صفحة واحدة متاحة → تُعرَض وحدها بلا نقاط ولا سحب؛
/// لا شيء متاح → الموضع كله غائب؛ صفحتان → PageView بعرض كامل
/// (لا تظهر الصفحة المجاورة إطلاقًا قبل السحب) ونقاط التنقّل أسفله
/// على نمط الكاروسيل المالي أعلى الرئيسية تمامًا.
/// الغلاف: معالجة بطاقة CRM الأصلية نفسها قبل دمج الكاروسيل —
/// سطح ملوّن خفيف من لون البطاقة المميز (نيلي) فوق سطح الثيم
/// وإطار من اللون نفسه ونصف قطر 20 — والصفحتان تعيشان داخله
/// بلا أغلفة خاصة بهما.
class HomeStatsCarousel extends StatefulWidget {
  const HomeStatsCarousel({super.key, required this.showCrm});

  /// بوابة صفحة CRM كما يحسبها الأب من إعدادات الرئيسية
  final bool showCrm;

  @override
  State<HomeStatsCarousel> createState() => _HomeStatsCarouselState();
}

class _HomeStatsCarouselState extends State<HomeStatsCarousel> {
  // عرض كامل: صفحة واحدة تملأ الموضع ولا يطلّ أي جزء من جارتها
  final PageController _controller = PageController(viewportFraction: 1.0);
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final hasChart = PermissionService().canView(FormNames.cashBoxDashboard);
    final hasCrm = widget.showCrm;

    if (!hasCrm && !hasChart) return const SizedBox.shrink();

    // صفحة واحدة: داخل الغلاف نفسه، بارتفاعها الطبيعي وبلا نقاط
    if (hasCrm && !hasChart) {
      return const Column(
        children: [
          SizedBox(height: 24),
          _StatsShell(child: CrmSummaryCard(embedded: true)),
        ],
      );
    }
    if (hasChart && !hasCrm) {
      return const Column(
        children: [
          SizedBox(height: 24),
          _StatsShell(child: CashboxWeekChart(embedded: true)),
        ],
      );
    }

    // الصفحتان: ارتفاع موحّد لمحتوى الصفحات — بطاقة CRM أطول حين
    // يحمل رسمها الدائري بيانات متابعات، والشارت يتمدد بملء الارتفاع
    // نفسه. (330/264 هما ارتفاعا الغلاف الكليّان كما كانا، وحشوة
    // الغلاف 18+18 محجوزة منهما حتى لا يتغيّر أثر الموضع في الصفحة.)
    final summary = context.watch<HomeProvider>().summary;
    final height = (_toInt(summary['followUpsTotal']) > 0 ? 330.0 : 264.0) -
        _StatsShell.padding.vertical;

    return Column(
      children: [
        const SizedBox(height: 24),
        _StatsShell(
          child: SizedBox(
            height: height,
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: const [
                CrmSummaryCard(embedded: true),
                CashboxWeekChart(embedded: true, fill: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // نقاط التنقل — نمط الكاروسيل المالي نفسه
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 2; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _currentPage ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _currentPage
                      ? HomeAccent.gold
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// غلاف الكاروسيل — معالجة بطاقة «إدارة علاقات العملاء» الأصلية
/// حرفيًا كما كانت قبل الدمج: سطح ملوّن من [HomeAccent.tintedSurface]
/// (مزج لوني خفيف من النيلي فوق سطح الثيم — كحلي في الليلي، لا علاقة
/// له بحاويات fromSeed البُنّية)، وإطار [HomeAccent.border] من اللون
/// نفسه، ونصف قطر 20، وحشوة 18.
class _StatsShell extends StatelessWidget {
  const _StatsShell({required this.child});

  final Widget child;

  static const EdgeInsets padding = EdgeInsets.all(18);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: HomeAccent.tintedSurface(context, HomeAccent.indigo),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: HomeAccent.border(context, HomeAccent.indigo)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
