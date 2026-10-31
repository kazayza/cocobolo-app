import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../services/expense_service.dart';
import '../../services/theme_service.dart';
import '../../core/network/api_client.dart';
import '../../widgets/design_kit.dart';

/// تقارير المصروفات — وضعا بلازور فقط: تفصيلي / إجمالي شهري، من نهايات
/// الخادم (print-data وmonthly-summary) لا من حساب عميل على قائمة
/// مقتطعة. التصدير فعلي: CSV من نهاية التصدير يُحفظ مؤقتًا ويُشارك
/// بنمط التطبيق المعتاد. الهوية واعية بالوضع في الوضعين.
class ExpenseReportsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String initialPeriod;

  const ExpenseReportsScreen({
    Key? key,
    required this.userId,
    required this.username,
    this.initialPeriod = 'هذا الشهر',
  }) : super(key: key);

  @override
  State<ExpenseReportsScreen> createState() => _ExpenseReportsScreenState();
}

class _ExpenseReportsScreenState extends State<ExpenseReportsScreen> {
  // وضعا بلازور: detail / summary
  String _mode = 'detail';
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _monthly;
  double _totalAmount = 0;
  int _totalCount = 0;
  bool isLoading = true;
  bool _exporting = false;
  String? _error;

  String _selectedPeriod = 'هذا الشهر';
  final List<String> periods = [
    'اليوم',
    'أمس',
    'الأسبوع',
    'هذا الشهر',
    'الشهر الماضي',
    'مخصص'
  ];
  DateTimeRange? _selectedDateRange;

  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod;
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
        start: DateTime(now.year, now.month, 1), end: now);
    _loadReportData();
  }

  DateTimeRange _getDateRangeForPeriod(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'اليوم':
        final start = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: start, end: now);
      case 'أمس':
        final yesterday = now.subtract(const Duration(days: 1));
        final start =
            DateTime(yesterday.year, yesterday.month, yesterday.day);
        return DateTimeRange(start: start, end: yesterday);
      case 'الأسبوع':
        final weekAgo = now.subtract(const Duration(days: 7));
        return DateTimeRange(start: weekAgo, end: now);
      case 'هذا الشهر':
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: now);
      case 'الشهر الماضي':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0);
        return DateTimeRange(start: lastMonth, end: end);
      case 'مخصص':
        return _selectedDateRange ??
            DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      default:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: now);
    }
  }

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadReportData() async {
    setState(() {
      isLoading = true;
      _error = null;
    });
    try {
      final range = _getDateRangeForPeriod(_selectedPeriod);
      if (_mode == 'summary') {
        final summary = await ExpenseService.getMonthlySummary(
          startDate: _fmtDate(range.start),
          endDate: _fmtDate(range.end),
        );
        if (mounted) {
          setState(() {
            _monthly = summary;
            _items = [];
            _totalAmount =
                (summary['GrandTotal'] as num?)?.toDouble() ?? 0;
            _totalCount = (summary['TotalCount'] as num?)?.toInt() ?? 0;
          });
        }
      } else {
        final data = await ExpenseService.getPrintData(
          mode: 'detail',
          startDate: _fmtDate(range.start),
          endDate: _fmtDate(range.end),
        );
        final items = (data['items'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (mounted) {
          setState(() {
            _items = items;
            _monthly = null;
            _totalAmount = (data['totalAmount'] as num?)?.toDouble() ??
                items.fold(
                    0.0, (s, e) => s + ((e['Amount'] as num?)?.toDouble() ?? 0));
            _totalCount =
                (data['totalCount'] as num?)?.toInt() ?? items.length;
          });
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'فشل تحميل بيانات التقرير');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  double get _average {
    if (_mode == 'summary') {
      return (_monthly?['MonthlyAverage'] as num?)?.toDouble() ?? 0;
    }
    return _totalCount > 0 ? _totalAmount / _totalCount : 0;
  }

  double get _max {
    if (_mode == 'summary') {
      final months = (_monthly?['Months'] as List?) ?? const [];
      var m = 0.0;
      for (final x in months) {
        final t = ((x as Map)['Total'] as num?)?.toDouble() ?? 0;
        if (t > m) m = t;
      }
      return m;
    }
    var m = 0.0;
    for (final e in _items) {
      final a = (e['Amount'] as num?)?.toDouble() ?? 0;
      if (a > m) m = a;
    }
    return m;
  }

  Future<void> _exportReport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final range = _getDateRangeForPeriod(_selectedPeriod);
      final csv = await ExpenseService.exportCsv(
        mode: _mode == 'summary' ? 'monthly' : 'detailed',
        startDate: _fmtDate(range.start),
        endDate: _fmtDate(range.end),
      );
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/expenses-${_mode == 'summary' ? 'monthly' : 'detailed'}.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'تقرير المصروفات');
    } on ApiException catch (e) {
      _showSnackbar(e.message, isError: true);
    } catch (_) {
      _showSnackbar('حدث خطأ في التصدير', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'تقارير المصروفات',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download, color: Colors.white),
            onPressed: _exporting ? null : _exportReport,
            tooltip: 'تصدير التقرير (CSV)',
          ),
        ],
      ),
      body: isLoading
          ? const AppLoading(message: 'جاري تحميل بيانات التقرير...')
          : _error != null
              ? AppError(message: _error!, onRetry: _loadReportData)
              : _buildReportContent(isDark),
    );
  }

  Widget _buildReportContent(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportFilters(isDark),
            const SizedBox(height: 20),
            _buildKpis(isDark),
            const SizedBox(height: 20),
            if (_mode == 'summary') _buildMonthlyList(isDark),
            if (_mode == 'detail') _buildDetailedList(isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildReportFilters(bool isDark) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إعدادات التقرير',
                style: TextStyle(
                  color: AppColors.text(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.filter_alt, color: AppColors.gold, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'وضع التقرير',
            style: TextStyle(
                color: AppColors.textSecondary(isDark), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _modeChip('تفصيلي', 'detail', isDark),
              _modeChip('إجمالي شهري', 'summary', isDark),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'الفترة الزمنية',
            style: TextStyle(
                color: AppColors.textSecondary(isDark), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: periods.map((period) {
              final isSelected = _selectedPeriod == period;
              return FilterChip(
                label: Text(
                  period,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.navy
                        : AppColors.text(isDark),
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.gold,
                backgroundColor: AppColors.inputFill(isDark),
                onSelected: (_) async {
                  if (period == 'مخصص') {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: _selectedDateRange,
                    );
                    if (picked != null) {
                      setState(() => _selectedDateRange = picked);
                    }
                  }
                  setState(() => _selectedPeriod = period);
                  _loadReportData();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: AppColors.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getPeriodDisplayText(),
                  style: TextStyle(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String label, String mode, bool isDark) {
    final isSelected = _mode == mode;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.navy : AppColors.text(isDark),
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.gold,
      backgroundColor: AppColors.inputFill(isDark),
      onSelected: (_) {
        if (_mode == mode) return;
        setState(() => _mode = mode);
        _loadReportData();
      },
    );
  }

  String _getPeriodDisplayText() {
    final range = _getDateRangeForPeriod(_selectedPeriod);
    final fmt = DateFormat('dd/MM/yyyy');
    return '${fmt.format(range.start)} - ${fmt.format(range.end)} ($_selectedPeriod)';
  }

  Widget _buildKpis(bool isDark) {
    final money = NumberFormat('#,##0');
    return Row(
      children: [
        Expanded(
          child: AppStatCard(
            label: 'إجمالي المصروفات',
            value: '${money.format(_totalAmount)} ج.م',
            color: isDark ? AppColors.errorLight : AppColors.error,
            icon: Icons.account_balance_wallet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppStatCard(
            label: 'عدد العمليات',
            value: '$_totalCount',
            color: isDark ? AppColors.infoLight : AppColors.info,
            icon: Icons.list,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppStatCard(
            label: _mode == 'summary' ? 'متوسط الشهر' : 'متوسط المصروف',
            value: '${money.format(_average)} ج.م',
            color: isDark ? AppColors.gold : AppColors.goldDark,
            icon: Icons.calculate_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppStatCard(
            label: _mode == 'summary' ? 'أعلى شهر' : 'أعلى مصروف',
            value: '${money.format(_max)} ج.م',
            color: isDark ? AppColors.warningLight : AppColors.warning,
            icon: Icons.trending_up,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedList(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
            title: 'التقرير التفصيلي (${_items.length})',
            icon: Icons.receipt_long_rounded),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          const AppEmpty(message: 'لا توجد معاملات في هذه الفترة')
        else
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                for (final e in _items) _detailRow(e, isDark),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detailRow(Map<String, dynamic> e, bool isDark) {
    final date = DateTime.tryParse(e['ExpenseDate']?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e['ExpenseName']?.toString() ?? '',
                  style: TextStyle(
                    color: AppColors.text(isDark),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(e['FullGroupPath'] ?? e['ExpenseGroupName'] ?? '').toString()}'
                  '${e['BranchName'] != null ? ' — ${e['BranchName']}' : ''}'
                  '${date != null ? ' — ${DateFormat('dd/MM/yyyy').format(date)}' : ''}',
                  style: TextStyle(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 11,
                  ),
                ),
                if (e['Torecipient'] != null &&
                    e['Torecipient'].toString().isNotEmpty)
                  Text(
                    'المستلم: ${e['Torecipient']}',
                    style: TextStyle(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          AmountText(
            value:
                '${NumberFormat('#,##0.00').format((e['Amount'] as num?)?.toDouble() ?? 0)} ج.م',
            color: isDark ? AppColors.errorLight : AppColors.error,
            size: 13,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyList(bool isDark) {
    final months = (_monthly?['Months'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
            title: 'الإجمالي الشهري', icon: Icons.calendar_month_rounded),
        const SizedBox(height: 12),
        if (months.isEmpty)
          const AppEmpty(message: 'لا توجد بيانات في هذه الفترة')
        else
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                for (final m in months)
                  _monthRow(Map<String, dynamic>.from(m as Map), isDark),
              ],
            ),
          ),
      ],
    );
  }

  Widget _monthRow(Map<String, dynamic> m, bool isDark) {
    final change = (m['ChangePercent'] as num?)?.toDouble() ?? 0;
    final hasPrev = m['HasPrevious'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m['MonthLabel']?.toString() ?? '',
                  style: TextStyle(
                    color: AppColors.text(isDark),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${m['Count'] ?? 0} عملية',
                  style: TextStyle(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (hasPrev)
            StatusBadge(
              label:
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
              color: change > 0
                  ? (isDark ? AppColors.errorLight : AppColors.error)
                  : (isDark ? AppColors.successLight : AppColors.success),
              small: true,
            ),
          const SizedBox(width: 10),
          AmountText(
            value:
                '${NumberFormat('#,##0.00').format((m['Total'] as num?)?.toDouble() ?? 0)} ج.م',
            color: AppColors.text(isDark),
            size: 13,
          ),
        ],
      ),
    );
  }
}
