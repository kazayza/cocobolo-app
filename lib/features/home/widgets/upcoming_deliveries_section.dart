import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../providers/auth_provider.dart';
import '../../../screens/delivery_details_screen.dart';
import '../../../screens/delivery_tracking_screen.dart';
import '../../../services/app_colors.dart';
import '../../../services/delivery_service.dart';
import '../../../services/design_tokens.dart';
import '../../../services/permission_service.dart';
import '../../../widgets/design_kit.dart';

/// قسم «التسليمات القادمة — 10 أيام» — مقابل قسم بلازور بالاسم نفسه
/// في الرئيسية (Home.razor): مواعيد (فاتورة × موعد) خلال 10 أيام
/// بالتواريخ كما تظهر لهذا المستخدم، مجمّعة بالأيام وبسقف 12 موعدًا.
/// البوابة: نفس بوابة وحدة التسليمات في التطبيق (canViewDelivery)،
/// وأي فشل أو رفض (403/404 قبل نشر الـ API) يخفي القسم بصمت كاتفاق
/// أقسام الرئيسية. الضغط على موعد يفتح تفاصيل التسليم الحالية.
/// التصميم: شريط علوي بتدرّج الهوية يحمل إحصاءات سريعة، ثم خط زمني
/// عمودي بعُقد أيام ملوّنة (ذهبي = اليوم، أحمر = متأخر) وبطاقة لكل موعد.
class UpcomingDeliveriesSection extends StatefulWidget {
  const UpcomingDeliveriesSection({super.key});

  @override
  State<UpcomingDeliveriesSection> createState() =>
      _UpcomingDeliveriesSectionState();
}

class _UpcomingDeliveriesSectionState
    extends State<UpcomingDeliveriesSection> {
  List<Map<String, dynamic>> _appointments = const [];
  int _total = 0;

  bool get _canView => PermissionService().canViewDelivery;

  static const List<String> _weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  static const List<String> _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    if (_canView) _load();
  }

  Future<void> _load() async {
    try {
      final data = await DeliveryService().getHomeUpcoming();
      final list = ((data['appointments'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _appointments = list;
        _total = (data['total'] as num?)?.toInt() ?? list.length;
      });
    } catch (_) {
      // قسم رئيسية اختياري — الفشل أو الرفض يخفيه بصمت
    }
  }

  DateTime? _displayDate(Map<String, dynamic> appt) =>
      DateTime.tryParse((appt['DisplayDate'] ?? '').toString());

  String _dateLabel(DateTime dt) => DateFormat('yyyy/MM/dd').format(dt);

  int _dayDiff(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(day.year, day.month, day.day).difference(today).inDays;
  }

  /// تسمية اليوم النسبية — مرآة RelativeDayLabel في بلازور
  String _relativeLabel(DateTime day) {
    final diff = _dayDiff(day);
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'غدًا';
    return _weekdays[day.weekday - 1];
  }

  /// كمية بصيغة بلازور (0.###): بلا أصفار زائدة
  String _qty(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _openTracking(BuildContext context) {
    final auth = AuthProvider();
    if (auth.userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeliveryTrackingScreen(
          userId: auth.userId!,
          username: auth.username ?? '',
        ),
      ),
    );
  }

  Color _dayColor(DateTime day) {
    final diff = _dayDiff(day);
    if (diff < 0) return AppColors.error;
    if (diff == 0) return AppColors.gold;
    return AppColors.navy;
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView || _appointments.isEmpty) return const SizedBox.shrink();

    // تجميع المواعيد بالأيام كما في بلازور (الترتيب من الخادم)
    final groups = <DateTime, List<Map<String, dynamic>>>{};
    for (final appt in _appointments) {
      final dt = _displayDate(appt);
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      groups.putIfAbsent(day, () => []).add(appt);
    }
    if (groups.isEmpty) return const SizedBox.shrink();

    final groupList = groups.entries.toList();
    var todayCount = 0;
    var remainingSum = 0.0;
    for (final appt in _appointments) {
      final dt = _displayDate(appt);
      if (dt != null && _dayDiff(dt) == 0) todayCount++;
      remainingSum += (appt['RemainingQty'] as num?)?.toDouble() ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        _hero(context, todayCount, remainingSum),
        const SizedBox(height: AppSpacing.lg),
        for (var gi = 0; gi < groupList.length; gi++)
          _timelineGroup(
            context,
            groupList[gi].key,
            groupList[gi].value,
            isLast: gi == groupList.length - 1,
          ),
        if (_total > _appointments.length)
          Center(
            child: TextButton.icon(
              onPressed: () => _openTracking(context),
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(
                'و${_total - _appointments.length} موعد آخر — عرض الكل في متابعة التسليمات',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  /// الشريط العلوي: تدرّج الهوية + إحصاءات سريعة (الإجمالي، اليوم، المتبقي)
  Widget _hero(BuildContext context, int todayCount, double remainingSum) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -18,
            bottom: -22,
            child: Icon(
              Icons.local_shipping_rounded,
              size: 118,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: AppColors.gold,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'التسليمات القادمة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'مواعيد التسليم خلال 10 أيام — بالتواريخ كما تظهر لك',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => _openTracking(context),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.gold),
                        ),
                        child: const Text(
                          'عرض الكل',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _heroStat('$_total', 'موعد خلال 10 أيام'),
                    _heroDivider(),
                    _heroStat(
                      '$todayCount',
                      'موعد اليوم',
                      valueColor: AppColors.gold,
                    ),
                    _heroDivider(),
                    _heroStat(_qty(remainingSum), 'إجمالي المتبقي'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label, {Color? valueColor}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.14),
    );
  }

  /// مجموعة يوم على الخط الزمني: عقدة ملوّنة برقم اليوم + خط متدرج واصل
  Widget _timelineGroup(
    BuildContext context,
    DateTime day,
    List<Map<String, dynamic>> items, {
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final diff = _dayDiff(day);
    final color = _dayColor(day);
    final remainingSum = items.fold<double>(
      0,
      (sum, a) => sum + ((a['RemainingQty'] as num?)?.toDouble() ?? 0),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // سكة الخط الزمني
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.55),
                            AppColors.gold.withValues(alpha: 0.35),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      diff < 0
                          ? 'متأخر — ${_weekdays[day.weekday - 1]}'
                          : _relativeLabel(day),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: diff < 0
                            ? AppColors.error
                            : diff == 0
                                ? AppColors.goldDark
                                : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${_months[day.month - 1]} • ${_dateLabel(day)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length} موعد • متبقي ${_qty(remainingSum)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final appt in items) ...[
                  _appointmentCard(context, appt, day),
                  const SizedBox(height: AppSpacing.sm),
                ],
                SizedBox(height: isLast ? AppSpacing.xs : AppSpacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentCard(
    BuildContext context,
    Map<String, dynamic> appt,
    DateTime day,
  ) {
    final auth = AuthProvider();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final id = (appt['TransactionID'] as num?)?.toInt() ?? 0;
    final reference = (appt['ReferenceNumber'] ?? '').toString();
    final appointmentCount = (appt['AppointmentCount'] as num?)?.toInt();
    final appointmentIndex = (appt['AppointmentIndex'] as num?)?.toInt();
    final diff = _dayDiff(day);
    final remainingColor = isDark ? AppColors.gold : AppColors.navy;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.xl,
      onTap: id == 0
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeliveryDetailsScreen(
                    transactionId: id,
                    username: auth.username ?? '',
                  ),
                ),
              );
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: isDark ? 0.35 : 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: isDark ? AppColors.gold : AppColors.navy,
                  size: 19,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  (appt['ClientName'] ?? '—').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (diff == 0)
                const StatusBadge(
                  label: 'اليوم',
                  color: AppColors.gold,
                  filled: true,
                  small: true,
                )
              else if (diff < 0)
                const StatusBadge(
                  label: 'متأخر',
                  color: AppColors.error,
                  filled: true,
                  small: true,
                )
              else if (diff == 1)
                const StatusBadge(
                  label: 'غدًا',
                  color: AppColors.info,
                  small: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                'فاتورة ${reference.isNotEmpty ? reference : '#$id'} • بنود مستحقة ${appt['DueLineCount'] ?? 0}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'متبقي ${_qty(appt['RemainingQty'])}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: remainingColor,
                ),
              ),
            ],
          ),
          // شيب «موعد X من N» — يظهر من موعدين فأكثر كما في بلازور
          if (appointmentCount != null &&
              appointmentCount >= 2 &&
              appointmentIndex != null) ...[
            const SizedBox(height: AppSpacing.sm),
            StatusBadge(
              label: 'موعد $appointmentIndex من $appointmentCount',
              color: AppColors.gold,
              icon: Icons.event_repeat_rounded,
              small: true,
            ),
          ],
        ],
      ),
    );
  }
}
