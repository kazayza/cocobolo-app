import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../services/exemption_service.dart';
import '../../services/loan_service.dart';
import '../../services/payroll_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/design_kit.dart';
import '../attendance_screen.dart';
import '../employees_screen.dart';
import '../exemptions_screen.dart';
import '../penalties_screen.dart';
import '../shifts_management_screen.dart';
import 'loans_screen.dart';
import 'my_payslips_screen.dart';
import 'off_payroll_screen.dart';
import 'payroll_list_screen.dart';

/// لوحة الموارد البشرية — كل أرقامها حقيقية من نهايات قائمة:
/// الموظفون (/api/employees)، حضور اليوم (/api/attendance/by-date)،
/// إحصاءات الرواتب (/api/payroll/stats)، إحصاءات السلف
/// (/api/loans/stats)، والاستثناءات المعلّقة (exemptions-list).
/// كل قسم يُحمَّل مستقلًا: فشل قسم (بوابة دور عند الخادم مثلًا) يعرض
/// «—» في بلاطاته ولا يُسقط اللوحة كلها.
///
/// التكوين البصري (على أنماط لوحات الموارد الحديثة): شريط مؤشرات
/// رئيسية في الأعلى، ثم مخطط تكوين دائري لحضور اليوم بمركز يحمل
/// الإجمالي ووسيلة إيضاح بالنسب، ثم قائمة طلبات معلّقة قابلة
/// للتنفيذ، وتفصيلات الإدارات والرواتب والسلف في لوحات مجمّعة.
///
/// ملاحظة اشتقاق الحضور: «الغائبون» هم صفوف اليوم ذات الحالة «غائب»
/// في سجل الحضور؛ الموظف بلا أي صف اليوم (لا حضور ولا غياب مسجل)
/// لا يظهر في النهاية أصلًا، فلا يُحتسب هنا — كما في بلازور الذي
/// يبني لوحته على بيانات الحضور المسجلة.
class HrDashboardScreen extends StatefulWidget {
  final int userId;
  final String username;

  const HrDashboardScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final ApiClient _api = ApiClient.instance;
  final PayrollService _payroll = PayrollService();
  final LoanService _loans = LoanService();
  final ExemptionService _exemptions = ExemptionService();
  final NumberFormat _num = NumberFormat('#,##0');

  bool _loading = true;

  // الموظفون
  int? _empTotal;
  int? _empActive;
  // حضور اليوم
  List<dynamic>? _todayRows;
  // الرواتب
  Map<String, dynamic>? _payrollStats;
  // السلف
  Map<String, dynamic>? _loanStats;
  // الاستثناءات المعلّقة (القائمة نفسها — العدّ مشتق من طولها)
  List<dynamic>? _pendingExemptionRows;
  int? _pendingExemptions;

  bool get _isDark => ThemeService().isDarkMode;
  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());
  String get _monthStr => DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<T?> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _guard(() async {
        final res = await _api.get('/api/employees', forceRefresh: true);
        final data = _api.decode(res);
        return data is List ? data : const [];
      }),
      _guard(() async {
        final res = await _api.get(
          '/api/attendance/by-date',
          query: {'date': _todayStr},
          forceRefresh: true,
        );
        final data = _api.decode(res);
        return data is List ? data : const [];
      }),
      _guard(() => _payroll.getStats(_monthStr)),
      _guard(() => _loans.getStats()),
      _guard(() => _exemptions.getList(status: 'Pending')),
    ]);
    if (!mounted) return;
    final employees = results[0] as List<dynamic>?;
    final pendingRows = results[4] as List<dynamic>?;
    setState(() {
      if (employees != null) {
        _empTotal = employees.length;
        _empActive = employees
            .where((e) => (e as Map)['Status']?.toString() == 'نشط')
            .length;
      }
      _todayRows = results[1] as List<dynamic>?;
      _payrollStats = results[2] as Map<String, dynamic>?;
      _loanStats = results[3] as Map<String, dynamic>?;
      _pendingExemptionRows = pendingRows;
      _pendingExemptions = pendingRows?.length;
      _loading = false;
    });
  }

  // اشتقاقات حضور اليوم
  List<dynamic> get _lateRows => (_todayRows ?? [])
      .where((r) => ((r as Map)['LateMinutes'] as num? ?? 0) > 0)
      .toList();
  List<dynamic> get _absentRows => (_todayRows ?? [])
      .where((r) => (r as Map)['Status']?.toString() == 'غائب')
      .toList();
  int get _presentCount => (_todayRows ?? [])
      .where((r) => (r as Map)['Status']?.toString() != 'غائب')
      .length;
  int get _lateMinutesTotal => _lateRows.fold(
        0,
        (sum, r) => sum + (((r as Map)['LateMinutes'] as num?)?.toInt() ?? 0),
      );

  /// متأخرون حاضرون فعليًا (لتقسيم الدائرة: حاضر بوقته/متأخر/غائب)
  int get _latePresentCount => (_todayRows ?? []).where((r) {
        final late = ((r['LateMinutes'] as num?) ?? 0) > 0;
        return late && r['Status']?.toString() != 'غائب';
      }).length;

  String _money(dynamic v) {
    final n = v is num ? v : num.tryParse('${v ?? ''}');
    return n == null ? '—' : _num.format(n);
  }

  double _dbl(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  String _count(int? v) => v == null ? '—' : _num.format(v);

  void _go(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frm_HR_Dashboard'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        title: const Text('لوحة الموارد البشرية'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildHero(),
              ),
            ),
            SliverToBoxAdapter(child: _buildTabs()),
            SliverFillRemaining(
              hasScrollBody: true,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildOverviewTab(),
                  _buildAttendanceTab(),
                  _buildFinanceTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لوحة الموارد البشرية',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('EEEE، d MMMM yyyy', 'ar')
                          .format(DateTime.now()),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.goldLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroStat('موظفون نشطون', _count(_empActive)),
              _heroDivider(),
              _heroStat(
                'حاضرون اليوم',
                _todayRows == null ? '—' : _num.format(_presentCount),
              ),
              _heroDivider(),
              _heroStat(
                'متأخرون اليوم',
                _todayRows == null ? '—' : _num.format(_lateRows.length),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.goldLight, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() => Container(
        width: 1,
        height: 34,
        color: Colors.white.withValues(alpha: 0.18),
      );

  /// شريط تبويبات مقسّم (Segmented) — حبة كحلية في النهاري وذهبية
  /// في الليلي داخل مسار بلون السطح، بدل خط التبويبات الافتراضي
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.premiumStroke(_isDark)),
        ),
        child: TabBar(
          controller: _tabs,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: _isDark ? AppColors.gold : AppColors.navy,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          labelColor: _isDark ? AppColors.navy : Colors.white,
          unselectedLabelColor: AppColors.textSecondary(_isDark),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'نظرة عامة'),
            Tab(text: 'حضور اليوم'),
            Tab(text: 'الرواتب والسلف'),
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String label,
    required String value,
    String? sub,
    required Color tint,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: _isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 17, color: tint),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.text(_isDark),
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary(_isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (sub != null)
            Text(
              sub,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textHint(_isDark),
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tileGrid(List<Widget> tiles) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.26,
      children: tiles,
    );
  }

  Color get _onTimeColor =>
      _isDark ? AppColors.successLight : AppColors.success;
  Color get _lateColor => _isDark ? AppColors.warningLight : AppColors.warning;
  Color get _absentColor => _isDark ? AppColors.errorLight : AppColors.error;

  /// بطاقة تكوين حضور اليوم: دائرة (بوقته/متأخر/غائب) بمركز يحمل
  /// إجمالي السجلات + وسيلة إيضاح بالعدد والنسبة لكل فئة
  Widget _attendanceDonutCard({bool withDetailsAction = false}) {
    final rows = _todayRows!;
    final total = rows.length;
    final absent = _absentRows.length;
    final late = _latePresentCount;
    final onTime = total - absent - late;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'حضور اليوم',
            icon: Icons.pie_chart_rounded,
            trailing: withDetailsAction
                ? TextButton(
                    onPressed: () => _tabs.animateTo(1),
                    child: const Text('التفاصيل'),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          if (total == 0)
            const AppEmpty(
              message: 'لا سجلات حضور اليوم',
              icon: Icons.fingerprint_rounded,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 42,
                          sections: [
                            if (onTime > 0)
                              PieChartSectionData(
                                value: onTime.toDouble(),
                                color: _onTimeColor,
                                radius: 16,
                                showTitle: false,
                              ),
                            if (late > 0)
                              PieChartSectionData(
                                value: late.toDouble(),
                                color: _lateColor,
                                radius: 16,
                                showTitle: false,
                              ),
                            if (absent > 0)
                              PieChartSectionData(
                                value: absent.toDouble(),
                                color: _absentColor,
                                radius: 16,
                                showTitle: false,
                              ),
                          ],
                        ),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _num.format(total),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text(_isDark),
                            ),
                          ),
                          Text(
                            'سجل اليوم',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary(_isDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      _donutLegend('حاضر بوقته', onTime, total, _onTimeColor),
                      const SizedBox(height: 10),
                      _donutLegend('متأخر', late, total, _lateColor),
                      const SizedBox(height: 10),
                      _donutLegend('غائب', absent, total, _absentColor),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppColors.textSecondary(_isDark),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'مجموع التأخير: $_lateMinutesTotal دقيقة',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary(_isDark),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _donutLegend(String label, int value, int total, Color color) {
    final pct = total == 0 ? 0 : (value / total * 100).round();
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(_isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$value · $pct%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.text(_isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    if (_loading) return const AppLoading();
    // اتجاه النص دون تسمية TextDirection (intl يصدّر اسمًا مماثلًا)
    final isRtl = Directionality.of(context).name == 'rtl';
    final alerts = <(IconData, String, Color, VoidCallback)>[];
    if (_todayRows != null) {
      if (_absentRows.isNotEmpty) {
        alerts.add((
          Icons.person_off_rounded,
          'غائبون اليوم: ${_absentRows.length} موظفًا',
          _isDark ? AppColors.errorLight : AppColors.error,
          () => _tabs.animateTo(1),
        ));
      }
      if (_lateRows.isNotEmpty) {
        alerts.add((
          Icons.schedule_rounded,
          'متأخرون اليوم: ${_lateRows.length} — مجموع التأخير $_lateMinutesTotal دقيقة',
          _isDark ? AppColors.warningLight : AppColors.warning,
          () => _tabs.animateTo(1),
        ));
      }
    }
    final reviewCount = _payrollStats?['ReviewCount'];
    if (reviewCount is num && reviewCount > 0) {
      alerts.add((
        Icons.rate_review_rounded,
        'رواتب بانتظار المراجعة هذا الشهر: ${reviewCount.toInt()}',
        _isDark ? AppColors.warningLight : AppColors.warning,
        () => _go(PayrollListScreen(
            userId: widget.userId, username: widget.username)),
      ));
    }
    final pendingInst = _loanStats?['PendingInstallmentsCount'];
    if (pendingInst is num && pendingInst > 0) {
      alerts.add((
        Icons.account_balance_wallet_rounded,
        'أقساط سلف معلّقة: ${pendingInst.toInt()}',
        _isDark ? AppColors.infoLight : AppColors.info,
        () =>
            _go(LoansScreen(userId: widget.userId, username: widget.username)),
      ));
    }
    if ((_pendingExemptions ?? 0) > 0) {
      alerts.add((
        Icons.event_busy_rounded,
        'استثناءات بانتظار الاعتماد: $_pendingExemptions',
        _isDark ? AppColors.infoLight : AppColors.info,
        () => _go(
            ExemptionsScreen(userId: widget.userId, username: widget.username)),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── شريط المؤشرات الرئيسية ──────────────────────
        _tileGrid([
          _statTile(
            icon: Icons.people_rounded,
            label: 'إجمالي الموظفين',
            value: _count(_empTotal),
            sub: 'نشط: ${_count(_empActive)}',
            tint: _isDark ? AppColors.gold : AppColors.navy,
          ),
          _statTile(
            icon: Icons.how_to_reg_rounded,
            label: 'حاضرون اليوم',
            value: _todayRows == null ? '—' : _num.format(_presentCount),
            sub: 'غائب: ${_todayRows == null ? '—' : _absentRows.length}',
            tint: _onTimeColor,
          ),
          _statTile(
            icon: Icons.payments_rounded,
            label: 'صافي رواتب الشهر',
            value: _money(_payrollStats?['TotalNetThisMonth']),
            sub: 'مسجل: ${_money(_payrollStats?['TotalCount'])} راتبًا',
            tint: _isDark ? AppColors.infoLight : AppColors.info,
          ),
          _statTile(
            icon: Icons.account_balance_wallet_rounded,
            label: 'سلف نشطة',
            value: _money(_loanStats?['ActiveLoansCount']),
            sub: 'المتبقي: ${_money(_loanStats?['TotalRemainingAmount'])} ج',
            tint: _isDark ? AppColors.warningLight : AppColors.warning,
          ),
        ]),
        const SizedBox(height: 16),
        // ── تكوين حضور اليوم ────────────────────────────
        if (_todayRows != null) _attendanceDonutCard(withDetailsAction: true),
        if (_todayRows != null) const SizedBox(height: 16),
        // ── قائمة الاستثناءات المعلّقة القابلة للتنفيذ ──
        if ((_pendingExemptionRows ?? const []).isNotEmpty) ...[
          _pendingQueue(),
          const SizedBox(height: 16),
        ],
        // ── تنبيهات تحتاج متابعة ────────────────────────
        _sectionHeader('تنبيهات تحتاج متابعة'),
        if (alerts.isEmpty)
          const AppEmpty(message: 'لا تنبيهات حاليًا')
        else
          ...alerts.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: a.$4,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: a.$3.withValues(alpha: _isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(a.$1, size: 17, color: a.$3),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.$2,
                        style: TextStyle(color: AppColors.text(_isDark)),
                      ),
                    ),
                    Icon(
                      isRtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textHint(_isDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        // ── إجراءات سريعة ───────────────────────────────
        _sectionHeader('إجراءات سريعة'),
        _tileGrid([
          _actionTile(
              Icons.people_rounded,
              'الموظفون',
              () => EmployeesScreen(
                  userId: widget.userId, username: widget.username)),
          _actionTile(
              Icons.fingerprint_rounded,
              'الحضور والانصراف',
              () => AttendanceScreen(
                  userId: widget.userId, username: widget.username)),
          _actionTile(
              Icons.access_time_rounded,
              'إدارة الشيفتات',
              () => ShiftsManagementScreen(
                  userId: widget.userId, username: widget.username)),
          _actionTile(
              Icons.event_busy_rounded,
              'الاستثناءات',
              () => ExemptionsScreen(
                  userId: widget.userId, username: widget.username)),
          _actionTile(
              Icons.gavel_rounded,
              'الجزاءات',
              () => PenaltiesScreen(
                  userId: widget.userId, username: widget.username)),
          _actionTile(
              Icons.payments_rounded,
              'سجل المرتبات',
              () => PayrollListScreen(
                  userId: widget.userId, username: widget.username)),
          _actionTile(
              Icons.account_balance_wallet_rounded,
              'السلف',
              () => LoansScreen(
                  userId: widget.userId, username: widget.username)),
          _actionTile(
              Icons.receipt_long_rounded,
              'قسيمتي',
              () => MyPayslipsScreen(
                  userId: widget.userId, username: widget.username)),
          _actionTile(
              Icons.money_rounded,
              'خارج الراتب',
              () => OffPayrollScreen(
                  userId: widget.userId, username: widget.username)),
        ]),
      ],
    );
  }

  /// قائمة طلبات الاستثناء المعلّقة — صفوف قابلة للضغط تفتح شاشة
  /// الاستثناءات حيث تُتّخذ قرارات الاعتماد والرفض
  Widget _pendingQueue() {
    final rows = _pendingExemptionRows!;
    final shown = rows.take(4).toList();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'طلبات بانتظار الاعتماد',
            icon: Icons.pending_actions_rounded,
            trailing: TextButton(
              onPressed: () => _go(ExemptionsScreen(
                  userId: widget.userId, username: widget.username)),
              child: const Text('عرض الكل'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            InkWell(
              onTap: () => _go(ExemptionsScreen(
                  userId: widget.userId, username: widget.username)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.navy.withValues(alpha: _isDark ? 0.5 : 0.1),
                      child: Text(
                        _rowName(shown[i]).characters.first,
                        style: TextStyle(
                          color: _isDark ? AppColors.goldLight : AppColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _rowName(shown[i]),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.text(_isDark),
                            ),
                          ),
                          Text(
                            _rowReason(shown[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary(_isDark),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: _rowWhen(shown[i]),
                      color: _isDark ? AppColors.infoLight : AppColors.info,
                      small: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (rows.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'و${rows.length - shown.length} طلبات أخرى بانتظار الاعتماد',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(_isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _rowName(dynamic r) {
    final name = (r as Map)['EmployeeName']?.toString() ?? '';
    return name.isEmpty ? '—' : name;
  }

  String _rowReason(dynamic r) {
    final m = r as Map;
    final reason = m['ReasonCode']?.toString() ?? '';
    final desc = m['Description']?.toString() ?? '';
    final dept = m['Department']?.toString() ?? '';
    final parts = [
      if (reason.isNotEmpty) reason,
      if (desc.isNotEmpty) desc,
      if (dept.isNotEmpty) dept,
    ];
    return parts.join(' · ');
  }

  String _rowWhen(dynamic r) {
    final m = r as Map;
    final fullDay = m['IsFullDay'] == true;
    final hours = m['Hours'];
    final date = m['ExemptionDate']?.toString() ?? '';
    final shortDate = date.length >= 10 ? date.substring(5, 10) : date;
    if (fullDay) {
      return shortDate.isEmpty ? 'يوم كامل' : '$shortDate · يوم كامل';
    }
    if (hours is num) {
      return shortDate.isEmpty ? '$hours ساعة' : '$shortDate · $hours ساعة';
    }
    return shortDate;
  }

  Widget _actionTile(IconData icon, String label, Widget Function() target) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => target()),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (_isDark ? AppColors.gold : AppColors.navy)
                  .withValues(alpha: _isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              size: 21,
              color: _isDark ? AppColors.gold : AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.text(_isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    if (_loading) return const AppLoading();
    if (_todayRows == null) {
      return const AppEmpty(
        message: 'بيانات حضور اليوم غير متاحة لهذا الحساب',
        icon: Icons.lock_rounded,
      );
    }
    // معدلات الحضور لكل إدارة من صفوف اليوم
    final deptTotal = <String, int>{};
    final deptPresent = <String, int>{};
    for (final r in _todayRows!) {
      final m = r as Map;
      final dept = m['Department']?.toString() ?? '—';
      deptTotal[dept] = (deptTotal[dept] ?? 0) + 1;
      if (m['Status']?.toString() != 'غائب') {
        deptPresent[dept] = (deptPresent[dept] ?? 0) + 1;
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _attendanceDonutCard(),
        const SizedBox(height: 16),
        _tileGrid([
          _statTile(
            icon: Icons.how_to_reg_rounded,
            label: 'حاضرون',
            value: _num.format(_presentCount),
            tint: _onTimeColor,
          ),
          _statTile(
            icon: Icons.person_off_rounded,
            label: 'غائبون',
            value: _num.format(_absentRows.length),
            tint: _absentColor,
          ),
          _statTile(
            icon: Icons.schedule_rounded,
            label: 'متأخرون',
            value: _num.format(_lateRows.length),
            sub: 'مجموع التأخير: $_lateMinutesTotal دقيقة',
            tint: _lateColor,
          ),
          _statTile(
            icon: Icons.fingerprint_rounded,
            label: 'سجلات اليوم',
            value: _num.format(_todayRows!.length),
            tint: _isDark ? AppColors.gold : AppColors.navy,
          ),
        ]),
        const SizedBox(height: 16),
        _sectionHeader('المتأخرون اليوم'),
        if (_lateRows.isEmpty)
          const AppEmpty(message: 'لا متأخرين اليوم')
        else
          ..._lateRows.map((r) {
            final m = r as Map;
            return _personRow(
              name: m['EmployeeName']?.toString() ?? '—',
              sub: m['Department']?.toString() ?? '',
              trailing:
                  'تأخير ${((m['LateMinutes'] as num?)?.toInt() ?? 0)} دقيقة',
            );
          }),
        const SizedBox(height: 12),
        _sectionHeader('الغائبون اليوم'),
        if (_absentRows.isEmpty)
          const AppEmpty(message: 'لا غائبين اليوم')
        else
          ..._absentRows.map((r) {
            final m = r as Map;
            return _personRow(
              name: m['EmployeeName']?.toString() ?? '—',
              sub: m['Department']?.toString() ?? '',
              trailing: 'غائب',
            );
          }),
        const SizedBox(height: 12),
        _sectionHeader('الحضور حسب الإدارة'),
        ...deptTotal.entries.map((e) {
          final total = e.value;
          final present = deptPresent[e.key] ?? 0;
          final rate = total == 0 ? 0.0 : present / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(_isDark),
                          ),
                        ),
                      ),
                      Text(
                        '${(rate * 100).toStringAsFixed(0)}% — $present/$total',
                        style: TextStyle(
                          color: AppColors.textSecondary(_isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: rate,
                      minHeight: 8,
                      backgroundColor:
                          AppColors.neutral.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation(
                        _isDark ? AppColors.gold : AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.text(_isDark),
            ),
      ),
    );
  }

  Widget _personRow({
    required String name,
    required String sub,
    required String trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  AppColors.navy.withValues(alpha: _isDark ? 0.5 : 0.1),
              child: Text(
                name.isNotEmpty ? name.characters.first : '؟',
                style: TextStyle(
                  color: _isDark ? AppColors.goldLight : AppColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(_isDark),
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: TextStyle(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              trailing,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(_isDark),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// شريط نسبة بمسمّى وقيمة مئوية (داخل لوحات الرواتب والسلف)
  Widget _ratioBar({
    required String label,
    required double ratio,
    required Color color,
  }) {
    final pct = (ratio.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(_isDark),
                ),
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.text(_isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.neutral.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  /// رقم داخل لوحة مجمّعة (قيمة + مسمّى) دون بطاقة مستقلة
  Widget _figure(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.text(_isDark),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary(_isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _figureGrid(List<Widget> figures) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: figures,
    );
  }

  Widget _buildFinanceTab() {
    if (_loading) return const AppLoading();
    final payroll = _payrollStats;
    final loans = _loanStats;
    final paidRatio = payroll == null
        ? 0.0
        : (_dbl(payroll['TotalCount']) > 0
            ? _dbl(payroll['PaidCount']) / _dbl(payroll['TotalCount'])
            : 0.0);
    final loanTotal = loans == null ? 0.0 : _dbl(loans['TotalLoanAmount']);
    final collectedRatio = loans == null || loanTotal <= 0
        ? 0.0
        : (loanTotal - _dbl(loans['TotalRemainingAmount'])) / loanTotal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── لوحة رواتب الشهر ────────────────────────────
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                title:
                    'رواتب ${DateFormat('MMMM yyyy', 'ar').format(DateTime.now())}',
                icon: Icons.payments_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              if (payroll == null)
                const AppEmpty(
                  message: 'إحصاءات الرواتب غير متاحة لهذا الحساب',
                  icon: Icons.lock_rounded,
                )
              else ...[
                Text(
                  _money(payroll['TotalNetThisMonth']),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text(_isDark),
                  ),
                ),
                Text(
                  'صافي رواتب الشهر · ${_money(payroll['TotalCount'])} راتبًا مسجلًا',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(_isDark),
                  ),
                ),
                const SizedBox(height: 14),
                _ratioBar(
                  label: 'نسبة المدفوعة',
                  ratio: paidRatio,
                  color: _onTimeColor,
                ),
                const SizedBox(height: 14),
                _figureGrid([
                  _figure(_money(payroll['PaidCount']), 'مدفوعة'),
                  _figure(_money(payroll['ReviewCount']), 'بانتظار المراجعة'),
                  _figure(_money(payroll['ApprovedCount']), 'معتمدة'),
                  _figure(_money(payroll['PendingCount']), 'قيد الانتظار'),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── لوحة السلف ──────────────────────────────────
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                title: 'السلف',
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              if (loans == null)
                const AppEmpty(
                  message: 'إحصاءات السلف غير متاحة لهذا الحساب',
                  icon: Icons.lock_rounded,
                )
              else ...[
                Text(
                  _money(loans['TotalRemainingAmount']),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text(_isDark),
                  ),
                ),
                Text(
                  'المتبقي للتحصيل · من إجمالي ${_money(loans['TotalLoanAmount'])} ج',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(_isDark),
                  ),
                ),
                const SizedBox(height: 14),
                _ratioBar(
                  label: 'نسبة المحصّل',
                  ratio: collectedRatio,
                  color: _isDark ? AppColors.gold : AppColors.navy,
                ),
                const SizedBox(height: 14),
                _figureGrid([
                  _figure(_money(loans['ActiveLoansCount']), 'سلف نشطة'),
                  _figure(_money(loans['PendingInstallmentsCount']),
                      'أقساط معلّقة'),
                  _figure(
                      _money(loans['ThisMonthDeductions']), 'خصومات هذا الشهر'),
                  _figure(
                      _money(loans['CompletedThisMonth']), 'اكتملت هذا الشهر'),
                ]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
