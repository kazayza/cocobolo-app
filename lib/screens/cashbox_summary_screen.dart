import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../services/app_colors.dart';
import '../services/cashbox_report_service.dart';
import '../services/cashbox_service.dart';
import '../services/design_tokens.dart';
import '../widgets/design_kit.dart';

/// ملخص الخزن بمعالجة فترة (Item 26) — مرآة CashBoxSummary في بلازور:
/// لكل خزينة رصيد أول الفترة ووارد/صادر الفترة ورصيد الإغلاق والرصيد الحالي.
class CashboxSummaryScreen extends StatefulWidget {
  final String username;

  const CashboxSummaryScreen({super.key, required this.username});

  @override
  State<CashboxSummaryScreen> createState() => _CashboxSummaryScreenState();
}

class _CashboxSummaryScreenState extends State<CashboxSummaryScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _boxes = [];
  int? _selectedBoxId;
  // افتراضي بلازور: «كل الفترة» — لا قيد تاريخ حتى يختار المستخدم فترة
  bool _allPeriod = true;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _loadBoxes();
    _load();
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  String _fmt(dynamic v) => NumberFormat('#,##0.00').format(_num(v));

  Future<void> _loadBoxes() async {
    try {
      final boxes = await CashboxService.getAllCashboxes();
      if (!mounted) return;
      setState(() => _boxes = boxes);
    } catch (_) {
      // قائمة الخزن مساعدة للمرشح فقط؛ الملخص نفسه يعرض خطأه أدناه
      if (!mounted) return;
      setState(() => _boxes = []);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await CashboxService.getSummary(
        cashboxId: _selectedBoxId,
        from: _allPeriod ? null : _from,
        to: _allPeriod ? null : _to,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
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

  String get _periodLabel => _allPeriod
      ? 'كل الفترة'
      : 'من ${DateFormat('yyyy/MM/dd').format(_from)} إلى ${DateFormat('yyyy/MM/dd').format(_to)}';

  // طباعة/مشاركة الملخص من الاستجابة الحالية (Item 26)
  Future<void> _printSummary() async {
    final s = _summary;
    if (s == null || _printing) return;
    setState(() => _printing = true);
    try {
      final bytes = await CashboxReportService.generateSummaryPDF(
        summary: s,
        boxes: _periodBoxes,
        periodLabel: _periodLabel,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إنشاء تقرير الملخص: $e')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _allPeriod = false;
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _load();
  }

  void _resetToAllPeriod() {
    if (_allPeriod) return;
    setState(() => _allPeriod = true);
    _load();
  }

  List<Map<String, dynamic>> get _periodBoxes {
    final raw = _summary?['Boxes'] ?? _summary?['boxes'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملخص الخزن'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _printing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.print_rounded),
            tooltip: 'طباعة الملخص',
            onPressed:
                (_loading || _summary == null || _printing) ? null : _printSummary,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const AppLoading(message: 'جاري تحميل الملخص...')
          : _error != null
              ? AppError(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final s = _summary!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionHeader(
                  title: 'النطاق',
                  icon: Icons.tune_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: _selectedBoxId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الخزينة',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('كل الخزن'),
                    ),
                    ..._boxes.map((b) => DropdownMenuItem<int>(
                          value: (b['CashBoxID'] as num?)?.toInt(),
                          child: Text('${b['CashBoxName'] ?? ''}'),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedBoxId = v);
                    _load();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(true),
                        icon: const Icon(Icons.calendar_month_rounded,
                            size: 16),
                        label: Text(_allPeriod
                            ? 'من: الكل'
                            : 'من ${DateFormat('yyyy/MM/dd').format(_from)}'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(false),
                        icon: const Icon(Icons.calendar_month_rounded,
                            size: 16),
                        label: Text(_allPeriod
                            ? 'إلى: الكل'
                            : 'إلى ${DateFormat('yyyy/MM/dd').format(_to)}'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _allPeriod ? null : _resetToAllPeriod,
                      icon: const Icon(Icons.all_inclusive_rounded, size: 16),
                      label: const Text('كل الفترة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionHeader(
                  title: 'إجماليات الفترة',
                  icon: Icons.summarize_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                _figureRow('رصيد أول الفترة', s['PeriodOpeningBalance']),
                _figureRow('وارد الفترة', s['TotalIn'],
                    color: AppColors.success),
                _figureRow('صادر الفترة', s['TotalOut'],
                    color: AppColors.error),
                _figureRow('رصيد آخر الفترة', s['ClosingBalance'],
                    bold: true),
                const Divider(height: 20),
                _figureRow('الرصيد الحالي (كل الأوقات)', s['CurrentBalance'],
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.gold
                        : AppColors.navy,
                    bold: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(
            title: 'تفاصيل كل خزينة في الفترة',
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_periodBoxes.isEmpty)
            const AppEmpty(
              icon: Icons.account_balance_wallet_rounded,
              message: 'لا توجد خزن لعرضها',
            )
          else
            ..._periodBoxes.map(_boxCard),
        ],
      ),
    );
  }

  Widget _figureRow(String label, dynamic value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          AmountText(
            value: '${_fmt(value)} ج',
            size: bold ? 15 : 14,
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _boxCard(Map<String, dynamic> box) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${box['CashBoxName'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (box['IsActive'] == false)
                  const StatusBadge(
                    label: 'غير نشطة',
                    color: AppColors.error,
                    small: true,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _figureRow('رصيد أول الفترة', box['PeriodOpeningBalance']),
            _figureRow('الوارد (${box['InCount'] ?? 0})', box['TotalIn'],
                color: AppColors.success),
            _figureRow('الصادر (${box['OutCount'] ?? 0})', box['TotalOut'],
                color: AppColors.error),
            _figureRow('رصيد آخر الفترة', box['ClosingBalance'], bold: true),
            _figureRow('الرصيد الحالي', box['CurrentBalance'],
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.gold
                    : AppColors.navy),
          ],
        ),
      ),
    );
  }
}
