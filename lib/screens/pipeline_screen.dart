import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../features/home/widgets/home_accent.dart';
import '../services/pipeline_service.dart';
import '../services/permission_service.dart';
import 'opportunity_detail_screen.dart';

/// مُنسّق أرقام مشترك
final NumberFormat _fmtShared = NumberFormat('#,##0');

/// ─────────────────────────────────────────────────────────────
/// 📋 مراحل البيع — عرض كانبان فخم
///  - كروت KPI علوية (إجمالي + قيمة + مكسب + خسارة + متأخرة)
///  - فلاتر (بحث + موظف + مصدر + حملة + متأخر/متابعة)
///  - أعمدة لكل مرحلة بطول الشاشة كامل
///  - كروت الفرص (عرض فقط — بدون نقل مراحل)
///  - الضغط على كارت → تفاصيل الفرصة
/// ─────────────────────────────────────────────────────────────
class PipelineScreen extends StatefulWidget {
  final int userId;
  final String username;

  const PipelineScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> {
  List<Map<String, dynamic>> _columns = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String? _error;

  // ── الفلاتر ──
  final TextEditingController _searchCtrl = TextEditingController();
  int? _employeeId;
  int? _sourceId;
  int? _adTypeId;
  bool _overdueOnly = false;
  bool _hasFollowUpOnly = false;
  bool _filtersOpen = false;

  // فلتر الفترة (التاريخ)
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _periodFilter = 'الكل'; // الكل | اليوم | آخر أسبوع | آخر شهر | مخصص

  List<dynamic> _employees = [];
  List<dynamic> _sources = [];
  List<dynamic> _adTypes = [];

  // ── حالة العرض ──
  bool _groupByEmployee = false;
  String _mergedFilter = 'all'; // all | lost | noint
  final Map<int, String> _columnSort = {};
  final Map<String, bool> _collapsedEmps = {}; // "stageId_empName" → collapsed

  static const List<String> _sortCycle = [
    'newest',
    'oldest',
    'value_high',
    'overdue_first',
  ];

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        PipelineService.getEmployees(),
        PipelineService.getSources(),
        PipelineService.getAdTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = results[0];
        _sources = results[1];
        _adTypes = results[2];
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        PipelineService.getKanbanBoard(
          employeeId: _employeeId,
          sourceId: _sourceId,
          adTypeId: _adTypeId,
          search: _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim(),
          isOverdue: _overdueOnly,
          hasFollowUp: _hasFollowUpOnly,
          dateFrom: _dateFrom != null
              ? _dateFrom!.toIso8601String()
              : null,
          dateTo: _dateTo != null ? _dateTo!.toIso8601String() : null,
        ),
        PipelineService.getPipelineSummary(
          employeeId: _employeeId,
          sourceId: _sourceId,
          adTypeId: _adTypeId,
          dateFrom: _dateFrom != null
              ? _dateFrom!.toIso8601String()
              : null,
          dateTo: _dateTo != null ? _dateTo!.toIso8601String() : null,
        ),
      ]);

      if (!mounted) return;
      final board = results[0];
      final summary = results[1];

      final cols = ((board?['columns']) as List? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _columns = cols;
        _summary = summary ?? {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onFilterChanged() {
    _load();
  }

  // اختيار فلتر الفترة
  void _applyPeriod(String period) {
    final now = DateTime.now();
    setState(() {
      _periodFilter = period;
      switch (period) {
        case 'اليوم':
          _dateFrom = DateTime(now.year, now.month, now.day);
          _dateTo = now;
          break;
        case 'آخر أسبوع':
          _dateFrom = now.subtract(const Duration(days: 7));
          _dateTo = now;
          break;
        case 'آخر شهر':
          _dateFrom = now.subtract(const Duration(days: 30));
          _dateTo = now;
          break;
        case 'مخصص':
          break; // هنفتح منتقي التاريخ
        default:
          _dateFrom = null;
          _dateTo = null;
      }
    });
    if (period == 'مخصص') {
      _pickCustomRange();
    } else {
      _load();
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final from = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? now.subtract(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'من تاريخ',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
    );
    if (from == null) {
      setState(() => _periodFilter = 'الكل');
      return;
    }
    final to = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? now,
      firstDate: from,
      lastDate: now,
      helpText: 'إلى تاريخ',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
    );
    if (to == null) {
      setState(() => _periodFilter = 'الكل');
      return;
    }
    setState(() {
      _dateFrom = from;
      _dateTo = to;
    });
    _load();
  }

  // ═══════════ الفرز ═══════════

  String _getSort(int stageId) => _columnSort[stageId] ?? 'newest';

  void _cycleSort(int stageId) {
    final current = _getSort(stageId);
    final idx = _sortCycle.indexOf(current);
    setState(() {
      _columnSort[stageId] = _sortCycle[(idx + 1) % _sortCycle.length];
    });
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'oldest':
        return 'الأقدم';
      case 'value_high':
        return 'الأعلى قيمة';
      case 'overdue_first':
        return 'المتأخرة أولاً';
      default:
        return 'الأحدث';
    }
  }

  IconData _sortIcon(String sort) {
    switch (sort) {
      case 'oldest':
        return Icons.arrow_upward_rounded;
      case 'value_high':
        return Icons.attach_money_rounded;
      case 'overdue_first':
        return Icons.notification_important_rounded;
      default:
        return Icons.arrow_downward_rounded;
    }
  }

  List<Map<String, dynamic>> _sortedCards(List<dynamic> cards, int stageId) {
    final list = cards.cast<Map<String, dynamic>>().toList();
    final sort = _getSort(stageId);
    switch (sort) {
      case 'oldest':
        list.sort((a, b) =>
            (a['OpportunityId'] as num).compareTo(b['OpportunityId'] as num));
        break;
      case 'value_high':
        list.sort((a, b) => ((b['ExpectedValue'] ?? 0) as num)
            .compareTo((a['ExpectedValue'] ?? 0) as num));
        break;
      case 'overdue_first':
        list.sort((a, b) {
          final ao = (a['IsOverdue'] == true) ? 0 : 1;
          final bo = (b['IsOverdue'] == true) ? 0 : 1;
          if (ao != bo) return ao.compareTo(bo);
          final ad = a['NextFollowUpDate'] != null
              ? DateTime.tryParse(a['NextFollowUpDate'].toString())
              : null;
          final bd = b['NextFollowUpDate'] != null
              ? DateTime.tryParse(b['NextFollowUpDate'].toString())
              : null;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        });
        break;
      default:
        list.sort((a, b) =>
            (b['OpportunityId'] as num).compareTo(a['OpportunityId'] as num));
    }
    return list;
  }

  // ═══════════ التنسيق ═══════════

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return _fmtShared.format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  String _fmtMoney(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    if (n.abs() >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n.abs() >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  Color _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF94A3B8);
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v != null ? Color(v) : const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مراحل البيع'),
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
              : Column(
                  children: [
                    // كروت KPI
                    _buildKpiBar(theme),

                    // الفلاتر
                    _buildFilters(theme),

                    // الكانبان (باقي الشاشة كاملة)
                    Expanded(child: _buildBoard(theme, isDark)),
                  ],
                ),
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
          Text(_error!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
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

  // ═══════════ كروت KPI ═══════════

  Widget _buildKpiBar(ThemeData theme) {
    final totals = _summary['totals'] is Map
        ? Map<String, dynamic>.from(_summary['totals'] as Map)
        : <String, dynamic>{};

    final totalCount = (totals['TotalOpportunities'] ?? 0) as num;
    final totalValue = (totals['TotalExpectedValue'] ?? 0) as num;
    final wonCount = (totals['WonCount'] ?? 0) as num;
    final lostCount = (totals['LostCount'] ?? 0) as num;

    // مجموع المتأخرات من المراحل
    final stages = (_summary['stages'] as List? ?? []);
    int overdue = 0;
    int todayFollow = 0;
    for (final s in stages) {
      if (s is Map) {
        overdue += (s['OverdueCount'] ?? 0) as int;
        todayFollow += (s['TodayCount'] ?? 0) as int;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _kpiCard('الفرص', '${_fmt(totalCount)}', Icons.lightbulb_rounded,
                const Color(0xFF2563EB), theme),
            _kpiCard('القيمة', '${_fmtMoney(totalValue)}',
                Icons.attach_money_rounded, const Color(0xFFF59E0B), theme),
            _kpiCard('مكسب', '${_fmt(wonCount)}', Icons.emoji_events_rounded,
                const Color(0xFF43A047), theme),
            _kpiCard('خسارة', '${_fmt(lostCount)}', Icons.trending_down_rounded,
                const Color(0xFFEF4444), theme),
            _kpiCard('متأخرة', '${_fmt(overdue)}',
                Icons.notification_important_rounded, const Color(0xFFEF4444),
                theme),
            _kpiCard('متابعة اليوم', '${_fmt(todayFollow)}',
                Icons.event_available_rounded, const Color(0xFF8B5CF6), theme),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color,
      ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════ الفلاتر ═══════════

  Widget _buildFilters(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          // رأس الفلاتر
          InkWell(
            onTap: () => setState(() => _filtersOpen = !_filtersOpen),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded, size: 17, color: HomeAccent.accent),
                  const SizedBox(width: 6),
                  const Text(
                    'بحث وتصفية',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: HomeAccent.gold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'فلتر نشط',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_hasActiveFilters)
                    InkWell(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() {
                          _employeeId = null;
                          _sourceId = null;
                          _adTypeId = null;
                          _overdueOnly = false;
                          _hasFollowUpOnly = false;
                          _periodFilter = 'الكل';
                          _dateFrom = null;
                          _dateTo = null;
                        });
                        _load();
                      },
                      child: Icon(Icons.close_rounded, size: 16, color: theme.colorScheme.error),
                    ),
                  AnimatedRotation(
                    turns: _filtersOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // المحتوى
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState:
                _filtersOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // البحث
                  TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _onFilterChanged(),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'بحث باسم العميل أو الهاتف أو المنتج...',
                      hintStyle: const TextStyle(fontSize: 11.5),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: isDark
                          ? theme.colorScheme.surfaceContainerHighest
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onFilterChanged();
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // موظف + مصدر
                  Row(
                    children: [
                      Expanded(
                        child: _filterDropdown<int?>(
                          value: _employeeId,
                          hint: 'كل الموظفين',
                          icon: Icons.person_rounded,
                          items: [
                            DropdownMenuItem<int?>(
                                value: null,
                                child: const Text('كل الموظفين',
                                    style: TextStyle(fontSize: 11.5))),
                            ..._employees.map((e) => DropdownMenuItem<int?>(
                                  value: (e['EmployeeId'] ?? e['EmployeeID'] ?? 0) as int?,
                                  child: Text(
                                    e['FullName']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 11.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() => _employeeId = v);
                            _onFilterChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _filterDropdown<int?>(
                          value: _sourceId,
                          hint: 'كل المصادر',
                          icon: Icons.contact_phone_rounded,
                          items: [
                            DropdownMenuItem<int?>(
                                value: null,
                                child: const Text('كل المصادر',
                                    style: TextStyle(fontSize: 11.5))),
                            ..._sources.map((s) => DropdownMenuItem<int?>(
                                  value: (s['SourceID'] as num?)?.toInt(),
                                  child: Text(
                                    (s['SourceNameAr'] ?? s['SourceName'] ?? '')
                                        .toString(),
                                    style: const TextStyle(fontSize: 11.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() => _sourceId = v);
                            _onFilterChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // حملة + مفاتيح
                  Row(
                    children: [
                      Expanded(
                        child: _filterDropdown<int?>(
                          value: _adTypeId,
                          hint: 'كل الحملات',
                          icon: Icons.campaign_rounded,
                          items: [
                            DropdownMenuItem<int?>(
                                value: null,
                                child: const Text('كل الحملات',
                                    style: TextStyle(fontSize: 11.5))),
                            ..._adTypes.map((a) => DropdownMenuItem<int?>(
                                  value: (a['AdTypeID'] as num?)?.toInt(),
                                  child: Text(
                                    (a['AdTypeNameAr'] ?? a['AdTypeName'] ?? '')
                                        .toString(),
                                    style: const TextStyle(fontSize: 11.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() => _adTypeId = v);
                            _onFilterChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // متأخر فقط
                      GestureDetector(
                        onTap: () {
                          setState(() => _overdueOnly = !_overdueOnly);
                          _onFilterChanged();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: _overdueOnly
                                ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _overdueOnly
                                  ? const Color(0xFFEF4444)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notification_important_rounded,
                                size: 13,
                                color: _overdueOnly
                                    ? const Color(0xFFEF4444)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'متأخر',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _overdueOnly
                                      ? const Color(0xFFEF4444)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ليه متابعة
                      GestureDetector(
                        onTap: () {
                          setState(() => _hasFollowUpOnly = !_hasFollowUpOnly);
                          _onFilterChanged();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: _hasFollowUpOnly
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _hasFollowUpOnly
                                  ? const Color(0xFF8B5CF6)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_available_rounded,
                                size: 13,
                                color: _hasFollowUpOnly
                                    ? const Color(0xFF8B5CF6)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'متابعة',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _hasFollowUpOnly
                                      ? const Color(0xFF8B5CF6)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── فلتر الفترة ──
                  Row(
                    children: [
                      for (final period in ['الكل', 'اليوم', 'آخر أسبوع', 'آخر شهر', 'مخصص'])
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () => _applyPeriod(period),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: _periodFilter == period
                                    ? HomeAccent.accent.withValues(alpha: 0.15)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _periodFilter == period
                                      ? HomeAccent.accent
                                      : theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                period == 'مخصص' && _periodFilter == 'مخصص' &&
                                        _dateFrom != null && _dateTo != null
                                    ? '${_dateFrom!.day}/${_dateFrom!.month} - ${_dateTo!.day}/${_dateTo!.month}'
                                    : period,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _periodFilter == period
                                      ? HomeAccent.accent
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFilters =>
      _employeeId != null ||
      _sourceId != null ||
      _adTypeId != null ||
      _overdueOnly ||
      _hasFollowUpOnly ||
      _periodFilter != 'الكل' ||
      _searchCtrl.text.trim().isNotEmpty;

  Widget _filterDropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          items: items,
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: theme.colorScheme.surfaceContainerHigh,
          icon: Icon(Icons.arrow_drop_down_rounded,
              color: theme.colorScheme.onSurfaceVariant, size: 20),
        ),
      ),
    );
  }

  // ═══════════ اللوحة (كانبان) ═══════════

  Widget _buildBoard(ThemeData theme, bool isDark) {
    // دمج خسارة(4) + غير مهتم(5) في عمود واحد
    final mergedColumns = <Map<String, dynamic>>[];
    for (final col in _columns) {
      final stageId = (col['StageId'] as num).toInt();
      if (stageId == 5) continue; // غير مهتم بتتدمج مع خسارة

      if (stageId == 4) {
        final lostCards = _sortedCards(col['Cards'] as List? ?? [], 4);
        final niCol = _columns.firstWhere(
          (c) => (c['StageId'] as num).toInt() == 5,
          orElse: () => <String, dynamic>{},
        );
        final niCards = niCol.isNotEmpty
            ? _sortedCards(niCol['Cards'] as List? ?? [], 5)
            : <Map<String, dynamic>>[];

        List<Map<String, dynamic>> display;
        if (_mergedFilter == 'lost') {
          display = lostCards;
        } else if (_mergedFilter == 'noint') {
          display = niCards;
        } else {
          display = [...lostCards, ...niCards];
        }

        final allCards = [...lostCards, ...niCards];
        mergedColumns.add({
          'StageId': -1,
          'StageName': col['StageName'],
          'StageNameAr': 'مغلق / خاسر',
          'StageColor': '#94a3b8',
          'Count': allCards.length,
          'Value':
              allCards.fold<num>(0, (s, c) => s + ((c['ExpectedValue'] ?? 0) as num)),
          'Cards': display,
        });
      } else {
        final cards = _sortedCards(col['Cards'] as List? ?? [], stageId);
        mergedColumns.add({...col, 'Cards': cards});
      }
    }

    return Column(
      children: [
        // شريط الملخص + الأدوات
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final col in mergedColumns)
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: _pill(
                            label: col['StageNameAr']?.toString() ?? '',
                            count: (col['Count'] as num?)?.toInt() ?? 0,
                            color: _hexColor(col['StageColor']?.toString()),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // تجميع بالموظف
              GestureDetector(
                onTap: () => setState(() => _groupByEmployee = !_groupByEmployee),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _groupByEmployee
                        ? HomeAccent.accent.withValues(alpha: 0.15)
                        : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _groupByEmployee
                          ? HomeAccent.accent
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_work_rounded,
                          size: 13,
                          color: _groupByEmployee
                              ? HomeAccent.accent
                              : theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(
                        'تجميع',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _groupByEmployee
                              ? HomeAccent.accent
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // الأعمدة — بطول الشاشة كامل
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: mergedColumns.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final col = mergedColumns[i];
              final stageId = (col['StageId'] as num).toInt();
              return _buildLane(theme, isDark, col, stageId == -1);
            },
          ),
        ),
      ],
    );
  }

  Widget _pill({required String label, required int count, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════ العمود ═══════════

  Widget _buildLane(ThemeData theme, bool isDark, Map<String, dynamic> col, bool isMerged) {
    final stageId = (col['StageId'] as num).toInt();
    final color = _hexColor(col['StageColor']?.toString());
    final cards = (col['Cards'] as List? ?? []).cast<Map<String, dynamic>>();
    final count = (col['Count'] as num?)?.toInt() ?? cards.length;
    final value = (col['Value'] ?? 0) as num;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس العمود
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              color: color.withValues(alpha: 0.08),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (col['StageNameAr']?.toString() ?? '?').isNotEmpty
                            ? (col['StageNameAr']!.toString())[0]
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            col['StageNameAr']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '$count فرصة · ${_fmtMoney(value)} ج.م',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _cycleSort(stageId),
                      child: Tooltip(
                        message: _sortLabel(_getSort(stageId)),
                        child: Icon(
                          _sortIcon(_getSort(stageId)),
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isMerged) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _mergedTab('الكل', _mergedFilter == 'all', () {
                        setState(() => _mergedFilter = 'all');
                      }),
                      const SizedBox(width: 4),
                      _mergedTab('خسارة', _mergedFilter == 'lost', () {
                        setState(() => _mergedFilter = 'lost');
                      }),
                      const SizedBox(width: 4),
                      _mergedTab('غير مهتم', _mergedFilter == 'noint', () {
                        setState(() => _mergedFilter = 'noint');
                      }),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 6),

          // الكروت
          Expanded(
            child: _groupByEmployee
                ? _buildGroupedCards(theme, cards, stageId, color)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: cards.length,
                    itemBuilder: (context, i) =>
                        _buildCard(theme, cards[i], color),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _mergedTab(String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? HomeAccent.accent.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? HomeAccent.accent
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color:
                selected ? HomeAccent.accent : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ═══════════ تجميع بالموظف ═══════════

  Widget _buildGroupedCards(ThemeData theme, List<Map<String, dynamic>> cards,
      int stageId, Color color) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final c in cards) {
      final emp = c['EmployeeName']?.toString() ?? '—';
      groups.putIfAbsent(emp, () => []).add(c);
    }

    final empNames = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: empNames.length,
      itemBuilder: (context, i) {
        final emp = empNames[i];
        final empCards = groups[emp]!;
        final key = '${stageId}_$emp';
        final isCollapsed = _collapsedEmps[key] == true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس مجموعة الموظف
            InkWell(
              onTap: () => setState(() {
                _collapsedEmps[key] = !isCollapsed;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        emp.isNotEmpty ? emp[0] : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        emp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${empCards.length}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (!isCollapsed)
              ...empCards.map((c) => _buildCard(theme, c, color)),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  // ═══════════ الكارت (عرض فقط — بدون سحب) ═══════════

  Widget _buildCard(ThemeData theme, Map<String, dynamic> card, Color laneColor) {
    final stageId = (card['StageId'] as num).toInt();
    final isLost = stageId == 4;
    final isNI = stageId == 5;
    final isOverdue = card['IsOverdue'] == true;
    final cardColor = isOverdue ? const Color(0xFFEF4444) : laneColor;
    final days = (card['LifecycleDays'] as num?)?.toInt() ?? 0;
    final followUp = card['NextFollowUpDate'] != null
        ? DateTime.tryParse(card['NextFollowUpDate'].toString())
        : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OpportunityDetailScreen(
              opportunityId: (card['OpportunityId'] as num).toInt(),
              userId: widget.userId,
              username: widget.username,
            ),
          ),
        ).then((_) => _load());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شريط علوي ملون
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الاسم + الشارات
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          card['ClientName']?.toString() ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isOverdue) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'متأخر',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (isLost) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B7280)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'خسارة',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ] else if (isNI) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'غير مهتم',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // الشرائح
                  if ((card['SourceName'] ?? '').toString().isNotEmpty ||
                      (card['InterestedProduct'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if ((card['SourceName'] ?? '').toString().isNotEmpty)
                          _chip(
                            (card['SourceName'] ?? '').toString(),
                            const Color(0xFF0EA5E9),
                          ),
                        if ((card['InterestedProduct'] ?? '').toString().isNotEmpty)
                          _chip(
                            (card['InterestedProduct'] ?? '').toString(),
                            const Color(0xFF8B5CF6),
                          ),
                      ],
                    ),
                  ],

                  // نقاط تقدم المراحل
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final col in _columns)
                        if ((col['StageId'] as num).toInt() != 4 &&
                            (col['StageId'] as num).toInt() != 5) ...[
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (col['StageId'] as num).toInt() == stageId
                                  ? _hexColor(col['StageColor']?.toString())
                                  : ((col['StageId'] as num).toInt() < stageId
                                      ? _hexColor(col['StageColor']?.toString())
                                          .withValues(alpha: 0.5)
                                      : theme.colorScheme.outlineVariant),
                            ),
                          ),
                        ],
                    ],
                  ),

                  // القيمة + المتابعة
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_fmtMoney(card['ExpectedValue'] ?? 0)} ج.م',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: cardColor,
                          ),
                        ),
                      ),
                      if (isOverdue && followUp != null)
                        Text(
                          DateFormat('dd/MM').format(followUp),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                    ],
                  ),

                  // القدم
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          days >= 0 ? '$days يوم' : '—',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: days > 7
                                ? const Color(0xFFEF4444)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '${card['InteractionsCount'] ?? 0}/${card['TasksCount'] ?? 0}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
