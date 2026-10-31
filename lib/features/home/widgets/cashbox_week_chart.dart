import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/app_colors.dart';
import '../../../services/cashbox_service.dart';
import '../../../services/design_tokens.dart';
import '../../../services/permission_service.dart';
import '../../../widgets/design_kit.dart';

/// قسم «حركة الخزينة — آخر 7 أيام» — أعمدة مجمّعة (وارد/صادر) لكل يوم.
/// البوابة: نفس بوابة شريحة الخزينة في الكاروسيل المالي حرفيًا
/// (finance_carousel.dart) — من لا يملك صلاحية لوحة الخزينة لا يظهر
/// له القسم ولا يُطلَق النداء أصلًا.
/// البيانات: CashboxService.getChartData (نقطة dashboard/chart?days=7)
/// وتعيد صفًا لكل يوم: {Label, Date, TotalIn, TotalOut}.
/// ترتيب الأيام: يُعرَض تنازليًا (اليوم أولًا) فيرسمه fl_chart في أقصى
/// اليسار، فتُقرأ الأيام في الاتجاه العربي من اليمين (الأقدم) إلى
/// اليسار (اليوم) — تسلسل زمني طبيعي للقارئ العربي.
/// الخطأ/الفراغ: الخدمة تعيد قائمة فارغة عند الخطأ، فيختفي القسم بصمت
/// (اتفاق أقسام الرئيسية)؛ وأسبوع بلا أي حركة يُعرَض بحالة فراغ الكيت.
///
/// [fill]: وضع كاروسيل الإحصائيات — البطاقة تملأ الارتفاع المعطى لها
/// ومنطقة الرسم تتمدد معها بدل الارتفاع الثابت 180.
/// [embedded]: المحتوى فقط بلا غلاف AppCard — غلاف الكاروسيل
/// (معالجة بطاقة CRM الأصلية) يحتضن الصفحة، فلا تتكرّر الأغلفة.
class CashboxWeekChart extends StatefulWidget {
  const CashboxWeekChart({super.key, this.fill = false, this.embedded = false});

  final bool fill;
  final bool embedded;

  @override
  State<CashboxWeekChart> createState() => _CashboxWeekChartState();
}

class _CashboxWeekChartState extends State<CashboxWeekChart> {
  List<Map<String, dynamic>>? _days;

  /// نفس تعبير بوابة شريحة الخزينة في الكاروسيل المالي
  bool get _canView => PermissionService().canView(FormNames.cashBoxDashboard);

  static final NumberFormat _fmt = NumberFormat('#,##0');
  static final NumberFormat _compact = NumberFormat.compact();

  static const List<String> _weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  @override
  void initState() {
    super.initState();
    if (_canView) _load();
  }

  Future<void> _load() async {
    try {
      final data = await CashboxService.getChartData(days: 7);
      if (!mounted) return;
      setState(() => _days = data);
    } catch (_) {
      // قسم رئيسية اختياري — الفشل يخفيه بصمت
      if (!mounted) return;
      setState(() => _days = const []);
    }
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  String _weekday(Map<String, dynamic> row) {
    final dt = DateTime.tryParse(row['Date']?.toString() ?? '');
    if (dt == null) return row['Label']?.toString() ?? '';
    return _weekdays[dt.weekday - 1];
  }

  Widget _legendDot(Color color, String label, TextStyle? style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) return const SizedBox.shrink();

    final days = _days;
    // تحميل أو خطأ (قائمة فارغة من الخدمة) → إخفاء صامت كأقسام الرئيسية
    if (days == null || days.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // لون «صادر»: في الليلي درجة فولاذية أفتح من الكحلي الفاتح حتى
    // تُرى الأعمدة فوق سطح غلاف الكاروسيل الكحلي وتميّز عن ذهبي
    // «وارد» — مشتقة من لون الهوية نفسه دون أي لون دخيل.
    final outColor = isDark
        ? Color.lerp(AppColors.navyLight, Colors.white, 0.45)!
        : AppColors.navy;

    // تنازلي: اليوم أول القائمة فيُرسَم أقصى اليسار (نهاية القراءة العربية)
    final rows = days.reversed.toList();

    var maxVal = 0.0;
    for (final r in rows) {
      maxVal =
          math.max(maxVal, math.max(_num(r['TotalIn']), _num(r['TotalOut'])));
    }

    final legendStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    final chart = BarChart(
      BarChartData(
        maxY: maxVal * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal / 4,
          getDrawingHorizontalLine: (v) => FlLine(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _compact.format(value),
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= rows.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _weekday(rows[i]),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            // خلفية التلميح من عائلة الكحلي في الوضعين
            // (الافتراضي في fl_chart رمادي مزرقّ دخيل)
            getTooltipColor: (_) => AppColors.navyDark,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final r = rows[groupIndex];
              return BarTooltipItem(
                '${_weekday(r)} (${r['Label'] ?? ''})\n'
                'وارد: ${_fmt.format(_num(r['TotalIn']))}\n'
                'صادر: ${_fmt.format(_num(r['TotalOut']))}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  height: 1.5,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                BarChartRodData(
                  toY: _num(rows[i]['TotalIn']),
                  color: AppColors.gold,
                  width: 7,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
                BarChartRodData(
                  toY: _num(rows[i]['TotalOut']),
                  color: outColor,
                  width: 7,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 500),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'حركة الخزينة — آخر 7 أيام',
          icon: Icons.bar_chart_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _legendDot(AppColors.gold, 'وارد', legendStyle),
              const SizedBox(width: AppSpacing.md),
              _legendDot(outColor, 'صادر', legendStyle),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (maxVal <= 0)
          const AppEmpty(
            message: 'لا حركات خزينة في آخر 7 أيام',
            icon: Icons.bar_chart_rounded,
          )
        else if (widget.fill)
          Expanded(child: chart)
        else
          SizedBox(height: 180, child: chart),
      ],
    );

    // داخل غلاف الكاروسيل: المحتوى وحده — الغلاف يوفر السطح والحشوة
    if (widget.embedded) return content;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: content,
    );
  }
}
