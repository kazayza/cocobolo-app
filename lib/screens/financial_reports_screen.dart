import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../services/app_colors.dart';
import '../services/financial_reports_service.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import '../widgets/app_drawer.dart';

/// شاشة التقارير المالية — تقابل في بلازور اللوحة المالية وقائمة الدخل
/// والميزانية العمومية وقائمة التدفقات النقدية. القفل المحلي بحرفيات
/// بلازور الحقيقية (D19): مدير النظام أو حامل عرض قائمة الدخل
/// (frmIncomeStatement) أو التدفقات (frm_CashFlowNew) أو لوحة الخزينة
/// (frmCashBoxDashboard)؛ والخادم يفرض بوابة مستقلة لكل قائمة.
class FinancialReportsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const FinancialReportsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen>
    with SingleTickerProviderStateMixin {
  final FinancialReportsService _service = FinancialReportsService();
  late final TabController _tabs;
  late DateTime _from;
  late DateTime _to;
  int? _branchId;
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];
  final Map<int, Map<String, dynamic>> _data = <int, Map<String, dynamic>>{};
  final Set<int> _loaded = <int>{};
  bool _loading = true;
  String? _error;

  bool get _isDark => ThemeService().isDarkMode;

  bool get _allowed {
    final perms = PermissionService();
    return perms.isAdmin ||
        perms.canView('frmIncomeStatement') ||
        perms.canView('frm_CashFlowNew') ||
        perms.canView('frmCashBoxDashboard');
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _loadTab(_tabs.index);
    });
    if (_allowed) {
      _loadBranches();
      _loadTab(0);
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  String _money(dynamic value) =>
      NumberFormat('#,##0', 'ar_EG').format(_num(value));

  String _pct(dynamic value) => '${_num(value).toStringAsFixed(1)}%';

  Future<void> _loadBranches() async {
    final branches = await _service.getBranches();
    if (!mounted) return;
    setState(() => _branches = branches);
  }

  Future<void> _loadTab(int index) async {
    if (_loaded.contains(index) && _data.containsKey(index)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> result;
      switch (index) {
        case 1:
          result = await _service.getIncomeStatement(_from, _to, _branchId);
          break;
        case 2:
          result = await _service.getBalanceSheet(_from, _to, _branchId);
          break;
        case 3:
          result = await _service.getCashFlow(_from, _to, _branchId);
          break;
        default:
          result = await _service.getDashboard(_from, _to, _branchId);
      }
      if (!mounted) return;
      setState(() {
        _data[index] = result;
        _loaded.add(index);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _reloadAll() async {
    _loaded.clear();
    _data.clear();
    await _loadTab(_tabs.index);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    await _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frmFinancialReports'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: const AppDrawerMenuButton(),
        title: Text('التقارير المالية',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_allowed)
            IconButton(
              onPressed: _reloadAll,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
            ),
        ],
        bottom: _allowed
            ? TabBar(
                controller: _tabs,
                isScrollable: true,
                labelStyle: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800),
                unselectedLabelStyle: TextStyle(fontSize: 12),
                tabs: const [
                  Tab(text: 'اللوحة المالية'),
                  Tab(text: 'قائمة الدخل'),
                  Tab(text: 'الميزانية'),
                  Tab(text: 'التدفقات'),
                ],
              )
            : null,
      ),
      body: !_allowed
          ? const AppEmpty(
              message:
                  'التقارير المالية متاحة للإدارة أو لمن لديه صلاحية عرض قائمة الدخل أو الميزانية أو التدفقات النقدية',
              icon: Icons.lock_rounded,
            )
          : Column(children: [
              _filters(),
              Expanded(
                child: _loading
                    ? const AppLoading(message: 'جاري تحميل التقرير المالي')
                    : _error != null
                        ? AppError(message: _error!, onRetry: _reloadAll)
                        : TabBarView(
                            controller: _tabs,
                            children: [
                              _dashboardTab(),
                              _incomeTab(),
                              _balanceTab(),
                              _cashFlowTab(),
                            ],
                          ),
              ),
            ]),
    );
  }

  Widget _filters() {
    final fmt = DateFormat('yyyy/MM/dd');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: Text('${fmt.format(_from)} — ${fmt.format(_to)}',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 7),
              child: ChoiceChip(
                selected: _branchId == null,
                label: Text('كل الفروع',
                    style: TextStyle(fontSize: 11)),
                onSelected: (_) async {
                  setState(() => _branchId = null);
                  await _reloadAll();
                },
              ),
            ),
            ..._branches.map((branch) {
              final id = (branch['BranchId'] as num?)?.toInt();
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 7),
                child: ChoiceChip(
                  selected: _branchId == id,
                  label: Text('${branch['BranchNameAr'] ?? ''}',
                      style: TextStyle(fontSize: 11)),
                  onSelected: (_) async {
                    setState(() => _branchId = id);
                    await _reloadAll();
                  },
                ),
              );
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String label, dynamic value, IconData icon, Color color,
      {bool percent = false}) {
    return AppStatCard(
      label: label,
      value: percent ? _pct(value) : _money(value),
      color: color,
      icon: icon,
    );
  }

  Widget _statGrid(List<Widget> cards) {
    return LayoutBuilder(builder: (_, constraints) {
      final width = constraints.maxWidth >= 900
          ? (constraints.maxWidth - 20) / 3
          : (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards
            .map((card) => SizedBox(width: width, child: card))
            .toList(),
      );
    });
  }

  Widget _kv(String label, dynamic value,
      {bool money = true, bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: color ?? AppColors.text(_isDark))),
        ),
        Text(money ? _money(value) : '${value ?? ''}',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color ?? AppColors.text(_isDark))),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppSectionHeader(title: title),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children),
        ),
      ]),
    );
  }

  Widget _scroll(Widget child) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [child],
      );

  // ══════════════ التبويب 1: اللوحة المالية ══════════════
  Widget _dashboardTab() {
    final data = _data[0];
    if (data == null) return const AppLoading(message: 'جاري تحميل اللوحة');
    final health = _map(data['HealthScore']);
    final ratios = _map(data['Ratios']);
    final receivables = _map(data['Receivables']);
    final score = _num(health['Score']);
    final scoreColor = score >= 75
        ? AppColors.success
        : score >= 55
            ? AppColors.info
            : score >= 40
                ? AppColors.warning
                : AppColors.error;
    return _scroll(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: _statGrid([
          _stat('المبيعات', data['Sales'], Icons.paid_rounded, AppColors.success),
          _stat('المصروفات', data['Expenses'], Icons.receipt_long_rounded, AppColors.error),
          _stat('صافي الربح', data['NetProfit'], Icons.trending_up_rounded, scoreColor),
          _stat('رصيد الخزائن الحالي', data['CashBalance'], Icons.savings_rounded, Theme.of(context).brightness == Brightness.dark ? AppColors.gold : AppColors.goldDark),
          _stat('هامش الربح', data['ProfitMargin'], Icons.percent_rounded, AppColors.info, percent: true),
          _stat('نمو المبيعات شهريًا', data['GrowthRate'], Icons.show_chart_rounded, AppColors.success, percent: true),
        ]),
      ),
      _section('الصحة المالية — ${health['Level'] ?? ''}', [
        Row(children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 84,
                height: 84,
                child: CircularProgressIndicator(
                  value: (score / 100).clamp(0, 1),
                  strokeWidth: 9,
                  color: scoreColor,
                  backgroundColor: AppColors.divider(_isDark),
                ),
              ),
              Text('${score.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text(_isDark))),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _list(health['Factors'])
                    .map((factor) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Icon(
                                factor['Status'] == 'danger'
                                    ? Icons.error_rounded
                                    : factor['Status'] == 'warning'
                                        ? Icons.warning_rounded
                                        : Icons.check_circle_rounded,
                                size: 16,
                                color: factor['Status'] == 'good'
                                    ? AppColors.success
                                    : factor['Status'] == 'warning'
                                        ? AppColors.warning
                                        : AppColors.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                  '${factor['Name'] ?? ''}: ${factor['Description'] ?? ''}',
                                  style: TextStyle(fontSize: 11.5)),
                            ),
                          ]),
                        ))
                    .toList()),
          ),
        ]),
      ]),
      _section('النسب المالية', [
        _kv('هامش الربح الإجمالي', _pct(ratios['GrossMargin']), money: false),
        _kv('هامش الربح الصافي', _pct(ratios['NetMargin']), money: false),
        _kv('نسبة المصروفات إلى المبيعات', _pct(ratios['ExpenseRatio']), money: false),
        _kv('نسبة التحصيل', _pct(ratios['CollectionRate']), money: false),
        _kv('أيام التحصيل (DSO)', ratios['DSO'], money: false),
        _kv('أيام سداد الموردين (DPO)', ratios['DPO'], money: false),
        _kv('دوران المخزون', ratios['InventoryTurnover'], money: false),
        _kv('نسبة السيولة السريعة', ratios['QuickRatio'], money: false),
      ]),
      _section('المديونيات', [
        _kv('مستحقات العملاء', receivables['CustomersReceivable']),
        _kv('منها متعثرة', receivables['OverDueCustomers']),
        _kv('مستحقات الموردين', receivables['SuppliersPayable']),
        _kv('عدد فواتير الشراء غير المسددة', receivables['UnpaidInvoicesCount'], money: false),
      ]),
      _section('الاتجاه الموحد — آخر 12 شهرًا',
          _list(data['Last12Months'])
              .map((row) => _kv(
                    '${row['MonthName'] ?? ''}',
                    'ربح ${_money(row['NetProfit'])}',
                    money: false,
                  ))
              .toList()),
      _section('أفضل المنتجات',
          _list(data['TopProducts'])
              .map((row) => _kv('${row['ProductName'] ?? ''}', row['Revenue']))
              .toList()),
      _section('أفضل العملاء',
          _list(data['TopCustomers'])
              .map((row) => _kv('${row['CustomerName'] ?? ''}', row['Total']))
              .toList()),
      _section('أكبر بنود المصروفات',
          _list(data['TopExpenseCategories'])
              .map((row) => _kv('${row['Category'] ?? ''}', row['Amount']))
              .toList()),
      if (_list(data['Alerts']).isNotEmpty)
        _section('تنبيهات مالية',
            _list(data['Alerts'])
                .map((alert) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Icon(
                            alert['Severity'] == 'danger'
                                ? Icons.error_rounded
                                : Icons.warning_rounded,
                            size: 17,
                            color: alert['Severity'] == 'danger'
                                ? AppColors.error
                                : AppColors.warning),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text('${alert['Message'] ?? ''}',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ]),
                    ))
                .toList()),
      if (_list(data['StrategicRecommendations']).isNotEmpty)
        _section('توصيات استراتيجية',
            _list(data['StrategicRecommendations'])
                .map((rec) => _kv('${rec['Title'] ?? ''}', '${rec['Action'] ?? ''}', money: false))
                .toList()),
    ]));
  }

  // ══════════════ التبويب 2: قائمة الدخل ══════════════
  Widget _incomeTab() {
    final data = _data[1];
    if (data == null) return const AppLoading(message: 'جاري تحميل قائمة الدخل');
    return _scroll(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: _statGrid([
          _stat('إجمالي الإيرادات', data['TotalRevenue'], Icons.paid_rounded, AppColors.success),
          _stat('تكلفة البضاعة المباعة', data['TotalCOGS'], Icons.inventory_2_rounded, AppColors.warning),
          _stat('إجمالي الربح', data['GrossProfit'], Icons.trending_up_rounded, AppColors.info),
          _stat('المصروفات التشغيلية', data['TotalOperatingExpenses'], Icons.receipt_long_rounded, AppColors.error),
          _stat('صافي الربح', data['NetProfit'], Icons.workspace_premium_rounded, AppColors.goldDark),
          _stat('هامش صافي الربح', data['NetProfitMargin'], Icons.percent_rounded, AppColors.success, percent: true),
        ]),
      ),
      _section('تفاصيل قائمة الدخل', [
        _kv('مبيعات الفترة', data['TotalSalesRevenue']),
        _kv('إيرادات أخرى', data['TotalOtherRevenue']),
        _kv('تكلفة مبيعات المعارض', data['ShowroomCOGS']),
        _kv('تكلفة المبيعات المنعكسة (مرايا)', data['MirrorCOGS']),
        _kv('هامش الربح الإجمالي', '${_pct(data['GrossProfitMargin'])}', money: false),
        _kv('الأجور والرواتب', _map(data['PayrollSummary'])['TotalPayroll']),
        _kv('إجمالي المصروفات التشغيلية', data['TotalOperatingExpenses'], bold: true),
        _kv('صافي ربح الفترة', data['NetProfit'], bold: true),
      ]),
      _section('المصروفات حسب المجموعة',
          _list(data['ExpensesByGroup'])
              .map((row) => _kv('${row['GroupName'] ?? ''}', row['Amount']))
              .toList()),
      if (_list(data['OtherRevenueByType']).isNotEmpty)
        _section('الإيرادات الأخرى حسب النوع',
            _list(data['OtherRevenueByType'])
                .map((row) => _kv('${row['ChargeTypeName'] ?? row['ChargeType'] ?? ''}', row['Amount']))
                .toList()),
      _section('نقطة التعادل وأهداف الربح', [
        _kv('مبيعات التعادل المطلوبة', _map(data['BreakEven'])['BreakEvenSales']),
        _kv('نسبة التكاليف الثابتة', _map(data['BreakEven'])['FixedCostRatio'], money: false),
        _kv('هدف الربح التالي', _map(data['ProfitTarget'])['NextTargetLabel'], money: false),
        _kv('المبيعات المطلوبة للهدف', _map(data['ProfitTarget'])['RequiredSales']),
        _kv('الفجوة عن الهدف', _map(data['ProfitTarget'])['GapAmount']),
      ]),
      _section('مقارنات', [
        _kv('صافي الفترة السابقة', _map(data['PreviousPeriod'])['NetProfit']),
        _kv('نمو صافي الربح عن الفترة السابقة', '${_pct(data['NetProfitGrowthVsPrevious'])}', money: false),
        _kv('صافي نفس الفترة من العام الماضي', _map(data['SamePeriodLastYear'])['NetProfit']),
        _kv('نمو صافي الربح عن العام الماضي', '${_pct(data['NetProfitGrowthVsLastYear'])}', money: false),
      ]),
      _section('الاتجاه الشهري',
          _list(data['MonthlyTrend'])
              .map((row) => _kv('${row['MonthLabel'] ?? ''}', 'صافي ${_money(row['NetProfit'])}', money: false))
              .toList()),
      if (_list(data['Recommendations']).isNotEmpty)
        _section('توصيات',
            _list(data['Recommendations'])
                .map((rec) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                          '${rec['Icon'] ?? ''} ${rec['Title'] ?? ''} — ${rec['Message'] ?? ''}',
                          style: TextStyle(fontSize: 12)),
                    ))
                .toList()),
    ]));
  }

  // ══════════════ التبويب 3: الميزانية ══════════════
  Widget _balanceTab() {
    final data = _data[2];
    if (data == null) return const AppLoading(message: 'جاري تحميل الميزانية');
    final assets = _map(data['Assets']);
    final liabilities = _map(data['Liabilities']);
    final equity = _map(data['Equity']);
    final balanced = data['IsBalanced'] == true;
    return _scroll(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: (balanced ? AppColors.success : AppColors.error)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: (balanced ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Icon(balanced ? Icons.verified_rounded : Icons.error_rounded,
                color: balanced ? AppColors.success : AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  balanced
                      ? 'الميزانية متوازنة — الأصول = الالتزامات + حقوق الملكية'
                      : 'الميزانية غير متوازنة — الفرق ${_money(data['Difference'])}',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
      _section('الأصول', [
        _kv('النقدية بالخزائن', assets['CashInBoxes']),
        _kv('مستحقات العملاء', assets['AccountsReceivable']),
        _kv('قيمة المخزون', assets['InventoryValue']),
        _kv('المصروفات المدفوعة مقدمًا', assets['PrepaidExpenses']),
        _kv('إجمالي الأصول', assets['TotalAssets'], bold: true),
      ]),
      _section('الالتزامات', [
        _kv('مستحقات الموردين', liabilities['AccountsPayable']),
        _kv('دفعات العملاء المقدمة', liabilities['CustomerAdvances']),
        _kv('أجور مستحقة', liabilities['PayrollPayable']),
        _kv('أقساط قروض مستحقة', liabilities['LoansPayable']),
        _kv('إجمالي الالتزامات', liabilities['TotalLiabilities'], bold: true),
      ]),
      _section('حقوق الملكية', [
        _kv('رأس المال الافتتاحي', equity['OpeningCapital']),
        _kv('الأرباح المحتجزة', equity['RetainedEarnings']),
        _kv('صافي ربح الفترة الحالية', equity['CurrentPeriodProfit']),
        _kv('إجمالي حقوق الملكية', equity['TotalEquity'], bold: true),
      ]),
      _section('إجماليات التحقق', [
        _kv('إجمالي الأصول', data['TotalAssets']),
        _kv('إجمالي الالتزامات وحقوق الملكية', data['TotalLiabilitiesAndEquity']),
        _kv('الفرق', data['Difference']),
      ]),
    ]));
  }

  // ══════════════ التبويب 4: التدفقات النقدية ══════════════
  Widget _cashFlowTab() {
    final data = _data[3];
    if (data == null) return const AppLoading(message: 'جاري تحميل التدفقات');
    final liquidity = _map(data['Liquidity']);
    final forecast = _map(data['Forecast']);
    return _scroll(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: _statGrid([
          _stat('الرصيد الافتتاحي', data['OpeningBalance'], Icons.savings_rounded, AppColors.info),
          _stat('إجمالي المقبوضات', data['TotalInflows'], Icons.arrow_downward_rounded, AppColors.success),
          _stat('إجمالي المدفوعات', data['TotalOutflows'], Icons.arrow_upward_rounded, AppColors.error),
          _stat('صافي التدفق', data['NetCashFlow'], Icons.currency_exchange_rounded, AppColors.goldDark),
          _stat('الرصيد الختامي', data['ClosingBalance'], Icons.account_balance_wallet_rounded, AppColors.success),
          _stat('أشهر السيولة المتاحة', liquidity['MonthsOfLiquidity'], Icons.water_drop_rounded, AppColors.info),
        ]),
      ),
      _section('المقبوضات حسب الفئة',
          _list(data['Inflows'])
              .map((row) => _kv('${row['CategoryName'] ?? ''}', row['Amount']))
              .toList()),
      _section('المدفوعات حسب الفئة',
          _list(data['Outflows'])
              .map((row) => _kv('${row['CategoryName'] ?? ''}', row['Amount']))
              .toList()),
      _section('الأرصدة حسب الخزينة',
          _list(data['ByCashBox'])
              .map((row) => _kv('${row['CashBoxName'] ?? ''}', row['ClosingBalance']))
              .toList()),
      _section('الاتجاه الشهري',
          _list(data['MonthlyTrend'])
              .map((row) => _kv('${row['MonthLabel'] ?? ''}', 'صافي ${_money(row['NetFlow'])}', money: false))
              .toList()),
      _section('السيولة والتوقع', [
        _kv('متوسط المصروف الشهري (آخر 3 أشهر)', liquidity['AvgMonthlyOutflow']),
        _kv('أشهر السيولة', liquidity['MonthsOfLiquidity'], money: false),
        _kv('التدفق المتوقع للشهر القادم', forecast['ExpectedNetNextMonth']),
        _kv('الرصيد المتوقع نهاية الشهر القادم', forecast['ProjectedClosingNextMonth']),
        _kv('التدفق المتوقع لربع السنة القادم', forecast['ExpectedNetNextQuarter']),
      ]),
      if (_list(data['Alerts']).isNotEmpty)
        _section('تنبيهات التدفقات',
            _list(data['Alerts'])
                .map((alert) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('${alert['Message'] ?? ''}',
                          style: TextStyle(fontSize: 12)),
                    ))
                .toList()),
    ]));
  }
}
