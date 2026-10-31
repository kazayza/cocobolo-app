import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/network/api_client.dart';
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../services/permission_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/design_kit.dart';

/// خدمة تحليلات المبيعات — تقابل SalesAnalyticsService في بلازور.
/// الخادم يفرض بوابة reports.canViewSalesAnalytics على المسارين.
class SalesAnalyticsService {
  final ApiClient _api = ApiClient.instance;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> getFilters() async {
    final response = await _api.get('/api/reports/sales-analytics/filters');
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> getAnalytics(
    DateTime from,
    DateTime to, {
    int? branchId,
    int? employeeId,
    String? invoiceStatus,
  }) async {
    final response = await _api.get(
      '/api/reports/sales-analytics',
      forceRefresh: true,
      query: {
        'dateFrom': _date(from),
        'dateTo': _date(to),
        if (branchId != null) 'branchId': branchId,
        if (employeeId != null) 'employeeId': employeeId,
        if (invoiceStatus != null) 'invoiceStatus': invoiceStatus,
      },
    );
    return _map(_map(_api.decode(response))['data']);
  }
}

/// شاشة تحليلات المبيعات — تقابل SalesAnalytics.razor في بلازور:
/// مؤشرات الفترة مقابل السابقة، تحويل الفريق، أداء الموظفين، الاتجاه،
/// الفروع وطرق الدفع، التحصيل، أهم العملاء، أسباب الخسارة، قراءات ذكية.
/// القفل المحلي للرؤية فقط؛ الخادم هو جهة الفرض (canViewSalesAnalytics).
class SalesAnalyticsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const SalesAnalyticsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  final SalesAnalyticsService _service = SalesAnalyticsService();
  late DateTime _from;
  late DateTime _to;
  int? _branchId;
  int? _employeeId;
  String? _invoiceStatus;
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _employeesFilter = <Map<String, dynamic>>[];
  List<String> _statuses = <String>[];
  Map<String, dynamic> _data = <String, dynamic>{};
  bool _loading = true;
  String? _error;

  bool get _isDark => ThemeService().isDarkMode;

  bool get _allowed {
    final perms = PermissionService();
    return perms.isAdmin ||
        perms.isGeneralManager ||
        perms.isAccountManager ||
        perms.isSalesManager ||
        perms.canView('frm_SalesAnalytics');
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 29));
    if (_allowed) {
      _loadFilters();
      _load();
    } else {
      _loading = false;
    }
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

  List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];
    return value.map((item) => '$item').toList();
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  String _money(dynamic value) =>
      NumberFormat('#,##0', 'ar_EG').format(_num(value));

  String _pct(dynamic value) => '${_num(value).toStringAsFixed(1)}%';

  String _growth(dynamic value) {
    if (value == null) return '—';
    final v = _num(value);
    return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%';
  }

  Future<void> _loadFilters() async {
    try {
      final filters = await _service.getFilters();
      if (!mounted) return;
      setState(() {
        _branches = _list(filters['Branches']);
        _employeesFilter = _list(filters['SalesEmployees']);
        _statuses = _stringList(filters['InvoiceStatuses']);
      });
    } catch (_) {
      // خيارات الفلاتر غير جوهرية — نكمل بدونها كما في بلازور
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getAnalytics(
        _from,
        _to,
        branchId: _branchId,
        employeeId: _employeeId,
        invoiceStatus: _invoiceStatus,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
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
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'تحليلات المبيعات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_allowed)
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
            ),
        ],
      ),
      body: !_allowed
          ? const AppEmpty(
              message:
                  'تحليلات المبيعات متاحة للإدارة أو مدير الحسابات أو مدير المبيعات أو حامل صلاحية تحليلات المبيعات',
              icon: Icons.lock_rounded,
            )
          : Column(children: [
              _filters(),
              Expanded(
                child: _loading
                    ? const AppLoading(message: 'جاري تحميل تحليلات المبيعات')
                    : _error != null
                        ? AppError(message: _error!, onRetry: _load)
                        : _content(),
              ),
            ]),
    );
  }

  Widget _filters() {
    final fmt = DateFormat('yyyy/MM/dd');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range_rounded, size: 18),
          label: Text('${fmt.format(_from)} — ${fmt.format(_to)}'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              selected: _branchId == null,
              label: const Text('كل الفروع'),
              onSelected: (_) async {
                setState(() => _branchId = null);
                await _load();
              },
            ),
            ..._branches.map((branch) {
              final id = (branch['Id'] as num?)?.toInt();
              return ChoiceChip(
                selected: _branchId == id,
                label: Text('${branch['Name'] ?? ''}'),
                onSelected: (_) async {
                  setState(() => _branchId = id);
                  await _load();
                },
              );
            }),
          ],
        ),
        if (_employeesFilter.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ChoiceChip(
                selected: _employeeId == null,
                label: const Text('كل فريق المبيعات'),
                onSelected: (_) async {
                  setState(() => _employeeId = null);
                  await _load();
                },
              ),
              ..._employeesFilter.map((emp) {
                final id = (emp['Id'] as num?)?.toInt();
                return Padding(
                  padding:
                      const EdgeInsetsDirectional.only(start: AppSpacing.sm),
                  child: ChoiceChip(
                    selected: _employeeId == id,
                    label: Text('${emp['Name'] ?? ''}'),
                    onSelected: (_) async {
                      setState(() => _employeeId = id);
                      await _load();
                    },
                  ),
                );
              }),
            ]),
          ),
        ],
        if (_statuses.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                selected: _invoiceStatus == null,
                label: const Text('كل الحالات'),
                onSelected: (_) async {
                  setState(() => _invoiceStatus = null);
                  await _load();
                },
              ),
              ..._statuses.map((status) {
                return ChoiceChip(
                  selected: _invoiceStatus == status,
                  label: Text(_statusLabel(status)),
                  onSelected: (_) async {
                    setState(() => _invoiceStatus = status);
                    await _load();
                  },
                );
              }),
            ],
          ),
        ],
      ]),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Open':
        return 'غير مسددة';
      case 'PartiallyPaid':
        return 'مدفوعة جزئياً';
      case 'Paid':
        return 'مدفوعة';
      default:
        return status;
    }
  }

  Widget _content() {
    final d = _data;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      children: [
        _hero(d),
        const SizedBox(height: AppSpacing.lg),
        _statGrid([
          _stat('عدد الفواتير', d['InvoiceCount'], Icons.receipt_long_rounded,
              AppColors.info, _growth(d['CountGrowthPct'])),
          _stat(
              'متوسط الفاتورة',
              d['AvgInvoice'],
              Icons.calculate_rounded,
              Theme.of(context).brightness == Brightness.dark
                  ? AppColors.neutralLight
                  : AppColors.neutral,
              _growth(d['AvgGrowthPct']),
              money: true),
          _stat('العملاء', d['Customers'], Icons.people_rounded,
              AppColors.success, _growth(d['CustomersGrowthPct'])),
          _stat('نسبة التحصيل', d['CollectionRate'], Icons.payments_rounded,
              AppColors.gold, null, percent: true),
        ]),
        const SizedBox(height: AppSpacing.lg),
        _section(
          'تحويل فريق المبيعات',
          Icons.filter_alt_rounded,
          [
            _kv('فرص الفريق', '${_num(d['TeamOpportunities']).toInt()}'),
            _kv('صفقات مغلقة', '${_num(d['TeamWonDeals']).toInt()}'),
            _kv('معدل التحويل', _pct(d['TeamConversionRate'])),
            _kv('قيد التقدم', '${_num(d['TeamInProgress']).toInt()}'),
            _kv('فرص خاسرة', '${_num(d['TeamLostOpportunities']).toInt()}'),
            _kv('المحصّل', '${_money(d['CollectedAmount'])} جـ'),
            _kv('المتبقي', '${_money(d['OutstandingAmount'])} جـ'),
            _kv('عملاء جدد', '${_num(d['NewCustomers']).toInt()}'),
            _kv('عملاء عائدون', '${_num(d['ReturningCustomers']).toInt()}'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _barsSection('المبيعات حسب الفرع', Icons.store_rounded,
            _list(d['Branches'])),
        const SizedBox(height: AppSpacing.lg),
        _barsSection(
            'طرق الدفع', Icons.credit_card_rounded, _list(d['PaymentMethods'])),
        const SizedBox(height: AppSpacing.lg),
        _trendSection(d),
        const SizedBox(height: AppSpacing.lg),
        _employeesSection(d),
        const SizedBox(height: AppSpacing.lg),
        _customersSection(d),
        if (_list(d['LostReasons']).isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _barsSection(
              'أسباب الخسارة', Icons.trending_down_rounded, _list(d['LostReasons']),
              isCount: true),
        ],
        if (_stringList(d['Insights']).isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _insightsSection(d),
        ],
      ],
    );
  }

  // بطاقة الهوية: إجمالي مبيعات الفترة مقابل السابقة — كحلية في الوضعين.
  Widget _hero(Map<String, dynamic> d) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.analytics_rounded, color: AppColors.gold, size: 20),
          SizedBox(width: AppSpacing.sm),
          Text(
            'إجمالي مبيعات الفترة',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${_money(d['TotalAmount'])} جـ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'الفترة السابقة: ${_money(d['PrevTotalAmount'])} جـ • التغير: ${_growth(d['TotalGrowthPct'])}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        if (d['HiddenAccountManagerSales'] == true) ...[
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'تُستبعد فواتير مديري الحسابات من هذه الأرقام وفق صلاحياتك',
            style: TextStyle(color: AppColors.goldLight, fontSize: 11),
          ),
        ],
      ]),
    );
  }

  Widget _stat(String label, dynamic value, IconData icon, Color color,
      String? sub,
      {bool money = false, bool percent = false}) {
    return AppStatCard(
      label: sub == null ? label : '$label • $sub',
      value: percent
          ? _pct(value)
          : money
              ? _money(value)
              : '${_num(value).toInt()}',
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
        children:
            cards.map((card) => SizedBox(width: width, child: card)).toList(),
      );
    });
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppSectionHeader(title: title, icon: icon),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ]),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(_isDark),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.text(_isDark),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }

  Widget _barsSection(String title, IconData icon,
      List<Map<String, dynamic>> rows,
      {bool isCount = false}) {
    final maxValue = rows.fold<double>(
        0, (max, r) => _num(r['Value']) > max ? _num(r['Value']) : max);
    return _section(title, icon, [
      if (rows.isEmpty)
        Text(
          'لا توجد بيانات في هذه الفترة',
          style: TextStyle(color: AppColors.textSecondary(_isDark)),
        ),
      ...rows.map((row) {
        final value = _num(row['Value']);
        final ratio = maxValue <= 0 ? 0.0 : value / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  '${row['Label'] ?? ''}',
                  style: TextStyle(
                    color: AppColors.text(_isDark),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                isCount ? '${value.toInt()}' : '${_money(value)} جـ',
                style: TextStyle(
                  color: AppColors.text(_isDark),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.inputFill(_isDark),
                color: ThemeService().accentColor,
              ),
            ),
          ]),
        );
      }),
    ]);
  }

  Widget _trendSection(Map<String, dynamic> d) {
    final labels = _stringList(d['TrendLabels']);
    final current = (d['TrendCurrent'] is List)
        ? (d['TrendCurrent'] as List).map(_num).toList()
        : <double>[];
    final prev = (d['TrendPrev'] is List)
        ? (d['TrendPrev'] as List).map(_num).toList()
        : <double>[];
    final maxValue = [...current, ...prev]
        .fold<double>(0, (max, v) => v > max ? v : max);
    return _section('اتجاه المبيعات مقابل الفترة السابقة',
        Icons.show_chart_rounded, [
      if (labels.isEmpty)
        Text(
          'لا توجد بيانات في هذه الفترة',
          style: TextStyle(color: AppColors.textSecondary(_isDark)),
        )
      else
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            height: maxValue <= 0
                                ? 2
                                : 4 + (current[i] / maxValue) * 110,
                            decoration: BoxDecoration(
                              color: ThemeService().accentColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 1),
                        Expanded(
                          child: Container(
                            height: maxValue <= 0
                                ? 2
                                : 4 + ((i < prev.length ? prev[i] : 0) / maxValue) * 110,
                            decoration: BoxDecoration(
                              color: AppColors.neutralLight,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      Row(children: [
        Container(
            width: 10,
            height: 10,
            color: ThemeService().accentColor),
        const SizedBox(width: AppSpacing.xs),
        Text('الفترة الحالية',
            style: TextStyle(
                color: AppColors.textSecondary(_isDark), fontSize: 11)),
        const SizedBox(width: AppSpacing.md),
        const SizedBox(
            width: 10, height: 10, child: ColoredBox(color: AppColors.neutralLight)),
        const SizedBox(width: AppSpacing.xs),
        Text('الفترة السابقة',
            style: TextStyle(
                color: AppColors.textSecondary(_isDark), fontSize: 11)),
      ]),
    ]);
  }

  Widget _employeesSection(Map<String, dynamic> d) {
    final employees = _list(d['Employees']);
    return _section('أداء الموظفين', Icons.badge_rounded, [
      if (employees.isEmpty)
        Text(
          'لا توجد بيانات في هذه الفترة',
          style: TextStyle(color: AppColors.textSecondary(_isDark)),
        ),
      ...employees.map((emp) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  '${emp['Name'] ?? ''}',
                  style: TextStyle(
                    color: AppColors.text(_isDark),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_money(emp['SalesAmount'])} جـ',
                style: TextStyle(
                  color: AppColors.text(_isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'فرص: ${_num(emp['Opportunities']).toInt()} • مغلقة: ${_num(emp['WonDeals']).toInt()} • تحويل: ${_pct(emp['ConversionRate'])} • فواتير: ${_num(emp['InvoiceCount']).toInt()} • متوسط الدورة: ${_num(emp['AvgCycleDays']).toStringAsFixed(1)} يوم',
              style: TextStyle(
                color: AppColors.textSecondary(_isDark),
                fontSize: 12,
              ),
            ),
            Divider(color: AppColors.divider(_isDark)),
          ]),
        );
      }),
    ]);
  }

  Widget _customersSection(Map<String, dynamic> d) {
    final customers = _list(d['TopCustomers']);
    return _section('أهم العملاء', Icons.emoji_events_rounded, [
      if (customers.isEmpty)
        Text(
          'لا توجد بيانات في هذه الفترة',
          style: TextStyle(color: AppColors.textSecondary(_isDark)),
        ),
      ...customers.map((customer) {
        return _kv(
          '${customer['Name'] ?? ''} (${_num(customer['InvoiceCount']).toInt()} فاتورة • ${_pct(customer['Pct'])})',
          '${_money(customer['Amount'])} جـ',
        );
      }),
    ]);
  }

  Widget _insightsSection(Map<String, dynamic> d) {
    final insights = _stringList(d['Insights']);
    return _section('قراءات ذكية', Icons.lightbulb_rounded, [
      ...insights.map((text) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.insights_rounded,
                size: 16, color: AppColors.gold),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AppColors.text(_isDark),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ]),
        );
      }),
    ]);
  }
}
