import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_colors.dart';
import '../services/customer_care_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_states.dart';

class CustomerCareHistoryScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? initialFeedbackId;

  const CustomerCareHistoryScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialFeedbackId,
  });

  @override
  State<CustomerCareHistoryScreen> createState() =>
      _CustomerCareHistoryScreenState();
}

class _CustomerCareHistoryScreenState extends State<CustomerCareHistoryScreen> {
  final CustomerCareService _service = CustomerCareService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _outcomeStats = <Map<String, dynamic>>[];
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _exporting = false;
  String? _error;
  String? _kind;
  String? _status;
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _hasMore = false;
  Timer? _debounce;

  bool get _isDark => ThemeService().isDarkMode;
  bool _can(String key) => _capabilities[key] == true;

  static const Map<String, String> _kindNames = <String, String>{
    'Visit': 'زيارة معرض',
    'Delivery': 'بعد التسليم',
    'SalesInvoice': 'قبل التسليم',
    'ComplaintFollowUp': 'متابعة شكوى',
  };
  static const Map<String, String> _outcomeNames = <String, String>{
    'Positive': 'إيجابي',
    'Neutral': 'محايد',
    'Negative': 'سلبي',
    'NoAnswer': 'لم يرد',
    'NotInterested': 'غير مهتم',
    'CallbackLater': 'تواصل لاحقًا',
  };
  static const Map<String, String> _statusNames = <String, String>{
    'Done': 'تم',
    'Open': 'مفتوح',
    'Skipped': 'مُسقط',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  Future<void> _load({bool append = false}) async {
    if (append) {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }
    try {
      final data = await _service.getHistory(
        dateFrom: _from,
        dateTo: _to,
        kind: _kind,
        status: _status,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        feedbackId: widget.initialFeedbackId,
        page: append ? _page + 1 : 1,
      );
      final incoming = ((data['rows'] as List?) ?? const [])
          .map<Map<String, dynamic>>(_map)
          .toList();
      final pagination = _map(data['pagination']);
      if (!mounted) return;
      setState(() {
        if (append) {
          _rows.addAll(incoming);
          _page++;
        } else {
          _rows = incoming;
          _page = _int(pagination['page']).clamp(1, 999999).toInt();
        }
        _outcomeStats = ((data['outcomeStats'] as List?) ?? const [])
            .map<Map<String, dynamic>>(_map)
            .toList();
        _capabilities = _map(data['capabilities']);
        _hasMore = pagination['hasMore'] == true;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error.toString();
      });
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  Future<void> _pickDate(bool from) async {
    final value = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value == null) return;
    setState(() {
      if (from) {
        _from = value;
      } else {
        _to = value;
      }
    });
    await _load();
  }

  Future<void> _hide(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إخفاء السجل',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: Text('هل تريد إخفاء هذا السجل من تقارير خدمة العملاء؟',
            style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('إخفاء', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await _service.hide(_int(row['FeedbackId']));
      if (!mounted) return;
      _message('${result['message'] ?? 'تم إخفاء السجل'}');
      await _load();
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    }
  }

  Future<void> _export() async {
    if (_exporting || !_can('canExport')) return;
    setState(() => _exporting = true);
    try {
      final rows = await _service.getExportRows(
        dateFrom: _from,
        dateTo: _to,
        kind: _kind,
        status: _status,
        search: _searchController.text.trim(),
      );
      final workbook = excel.Excel.createExcel();
      final sheet = workbook['خدمة العملاء'];
      if (workbook.sheets.containsKey('Sheet1')) workbook.delete('Sheet1');
      sheet.appendRow(<excel.CellValue>[
        excel.TextCellValue('رقم'),
        excel.TextCellValue('المصدر'),
        excel.TextCellValue('العميل'),
        excel.TextCellValue('الهاتف'),
        excel.TextCellValue('الحالة'),
        excel.TextCellValue('النتيجة'),
        excel.TextCellValue('الرضا'),
        excel.TextCellValue('القناة'),
        excel.TextCellValue('ملاحظات العميل'),
        excel.TextCellValue('انطباع الموظف'),
        excel.TextCellValue('تاريخ الحدث'),
        excel.TextCellValue('موعد المتابعة'),
        excel.TextCellValue('المحرر'),
        excel.TextCellValue('تاريخ التسجيل'),
      ]);
      for (final row in rows) {
        sheet.appendRow(<excel.CellValue>[
          excel.IntCellValue(_int(row['FeedbackId'])),
          excel.TextCellValue(_kindName('${row['Kind'] ?? ''}')),
          excel.TextCellValue('${row['ClientName'] ?? ''}'),
          excel.TextCellValue('${row['Phone'] ?? ''}'),
          excel.TextCellValue(_statusName('${row['Status'] ?? ''}')),
          excel.TextCellValue(_outcomeName('${row['Outcome'] ?? ''}')),
          excel.TextCellValue(
              row['Satisfaction'] == null ? '' : '${row['Satisfaction']}/5'),
          excel.TextCellValue('${row['Channel'] ?? ''}'),
          excel.TextCellValue('${row['Notes'] ?? ''}'),
          excel.TextCellValue('${row['EmployeeNotes'] ?? ''}'),
          excel.TextCellValue(_date(row['SourceDate'])),
          excel.TextCellValue(_date(row['NextCallDate'])),
          excel.TextCellValue('${row['CreatedBy'] ?? ''}'),
          excel.TextCellValue(_dateTime(row['CreatedAt'])),
        ]);
      }
      final bytes = workbook.save();
      if (bytes == null) throw StateError('تعذر إنشاء ملف Excel');
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/CustomerCare_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: <XFile>[
          XFile(file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
        ],
        text: 'تقرير خدمة العملاء',
      ));
    } catch (error) {
      if (mounted) _message('تعذر التصدير: $error', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: GoogleFonts.cairo()),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  int _outcomeCount(String outcome) {
    final row = _outcomeStats.where((item) => item['Outcome'] == outcome);
    return row.isEmpty ? 0 : _int(row.first['Count']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Text('سجل خدمة العملاء',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        actions: [
          if (_can('canExport'))
            IconButton(
              onPressed: _exporting ? null : _export,
              icon: const Icon(Icons.file_download_rounded),
              tooltip: 'تصدير Excel',
            ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Stack(children: [
        if (_loading)
          const AppLoading(message: 'جاري تحميل سجل خدمة العملاء')
        else if (_error != null)
          AppError(message: _error!, onRetry: _load)
        else
          RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _summary()),
              SliverToBoxAdapter(child: _filters()),
              if (_rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmpty(
                    message: 'لا توجد سجلات مطابقة',
                    hint: 'غيّر الفلاتر أو الفترة الزمنية',
                    icon: Icons.history_rounded,
                    onRefresh: _load,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  sliver: SliverList.builder(
                    itemCount: _rows.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (index == _rows.length) {
                        return Center(
                          child: OutlinedButton.icon(
                            onPressed:
                                _loadingMore ? null : () => _load(append: true),
                            icon: _loadingMore
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.expand_more_rounded),
                            label: Text('تحميل المزيد',
                                style: GoogleFonts.cairo()),
                          ),
                        );
                      }
                      return _historyCard(_rows[index]);
                    },
                  ),
                ),
            ]),
          ),
        if (_exporting)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ]),
    );
  }

  Widget _summary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navy, AppColors.navyLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.analytics_rounded, color: AppColors.gold, size: 26),
          const SizedBox(width: 9),
          Text('نتائج التواصل',
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _stat('إيجابي', _outcomeCount('Positive'), AppColors.success,
                Icons.sentiment_very_satisfied_rounded),
            _stat('محايد', _outcomeCount('Neutral'), AppColors.info,
                Icons.sentiment_neutral_rounded),
            _stat('سلبي', _outcomeCount('Negative'), AppColors.error,
                Icons.sentiment_dissatisfied_rounded),
            _stat('لم يرد', _outcomeCount('NoAnswer'), AppColors.warning,
                Icons.phone_missed_rounded),
            _stat('غير مهتم', _outcomeCount('NotInterested'), AppColors.neutral,
                Icons.block_rounded),
            _stat('اتصال لاحق', _outcomeCount('CallbackLater'), Colors.purple,
                Icons.event_repeat_rounded),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String label, int count, Color color, IconData icon) =>
      Container(
        width: 103,
        margin: const EdgeInsetsDirectional.only(end: 7),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          Text('$count',
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
          Text(label,
              style: GoogleFonts.cairo(color: Colors.white60, fontSize: 8.5)),
        ]),
      );

  Widget _filters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(children: [
        TextField(
          controller: _searchController,
          onChanged: _searchChanged,
          style: GoogleFonts.cairo(),
          decoration: InputDecoration(
            hintText: 'العميل، الهاتف، أو الملاحظات',
            hintStyle: GoogleFonts.cairo(fontSize: 11),
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.inputFill(_isDark),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _kind,
              decoration: InputDecoration(
                labelText: 'المصدر',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(
                    value: null,
                    child: Text('كل المصادر', style: GoogleFonts.cairo())),
                ..._kindNames.entries.map((entry) => DropdownMenuItem<String?>(
                      value: entry.key,
                      child: Text(entry.value, style: GoogleFonts.cairo()),
                    )),
              ],
              onChanged: (value) {
                setState(() => _kind = value);
                _load();
              },
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _status,
              decoration: InputDecoration(
                labelText: 'الحالة',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(
                    value: null,
                    child: Text('كل الحالات', style: GoogleFonts.cairo())),
                ..._statusNames.entries
                    .map((entry) => DropdownMenuItem<String?>(
                          value: entry.key,
                          child: Text(entry.value, style: GoogleFonts.cairo()),
                        )),
              ],
              onChanged: (value) {
                setState(() => _status = value);
                _load();
              },
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _dateButton('من', _from, () => _pickDate(true))),
          const SizedBox(width: 7),
          Expanded(child: _dateButton('إلى', _to, () => _pickDate(false))),
          if (_from != null || _to != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _from = null;
                  _to = null;
                });
                _load();
              },
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
        ]),
      ]),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_month_rounded, size: 16),
        label: Text(
            date == null ? label : DateFormat('yyyy/MM/dd').format(date),
            style: GoogleFonts.cairo(fontSize: 10)),
      );

  Widget _historyCard(Map<String, dynamic> row) {
    final outcome = '${row['Outcome'] ?? ''}';
    final status = '${row['Status'] ?? ''}';
    final color = _outcomeColor(outcome);
    final highlighted = widget.initialFeedbackId != null &&
        _int(row['FeedbackId']) == widget.initialFeedbackId;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.gold.withValues(alpha: _isDark ? 0.10 : 0.07)
            : AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: highlighted ? AppColors.gold : color.withValues(alpha: 0.25),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_outcomeIcon(outcome), color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['ClientName'] ?? 'عميل'}',
                  style: GoogleFonts.cairo(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5)),
              Text(_kindName('${row['Kind'] ?? ''}'),
                  style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(_isDark), fontSize: 10)),
            ]),
          ),
          _badge('${_statusName(status)} — ${_outcomeName(outcome)}', color),
        ]),
        const SizedBox(height: 8),
        if ((row['Notes'] ?? '').toString().isNotEmpty)
          Text('${row['Notes']}',
              style: GoogleFonts.cairo(
                  color: AppColors.text(_isDark), fontSize: 11.5)),
        if ((row['EmployeeNotes'] ?? '').toString().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.badge_outlined, color: Colors.purple, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${row['EmployeeNotes']}',
                    style: GoogleFonts.cairo(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 10.5)),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 6, children: [
          _chip(Icons.forum_outlined, '${row['Channel'] ?? '—'}'),
          if (row['Satisfaction'] != null)
            _chip(Icons.star_rounded, '${row['Satisfaction']}/5',
                color: AppColors.warning),
          _chip(Icons.calendar_month_rounded, _dateTime(row['CreatedAt'])),
          _chip(Icons.person_outline_rounded, '${row['CreatedBy'] ?? '—'}'),
          if (row['NextCallDate'] != null)
            _chip(Icons.event_repeat_rounded,
                'موعد: ${_date(row['NextCallDate'])}',
                color: Colors.purple),
        ]),
        if (_can('canHide'))
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              onPressed: () => _hide(row),
              icon: const Icon(Icons.visibility_off_outlined,
                  color: AppColors.error),
              tooltip: 'إخفاء السجل',
            ),
          ),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
        constraints: const BoxConstraints(maxWidth: 155),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
                color: color, fontSize: 8.5, fontWeight: FontWeight.w800)),
      );

  Widget _chip(IconData icon, String text, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: (color ?? AppColors.navy).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 13, color: color ?? AppColors.textSecondary(_isDark)),
          const SizedBox(width: 4),
          Text(text,
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark), fontSize: 9)),
        ]),
      );

  String _kindName(String value) => _kindNames[value] ?? value;
  String _outcomeName(String value) => _outcomeNames[value] ?? value;
  String _statusName(String value) => _statusNames[value] ?? value;

  IconData _outcomeIcon(String outcome) => switch (outcome) {
        'Positive' => Icons.sentiment_very_satisfied_rounded,
        'Neutral' => Icons.sentiment_neutral_rounded,
        'Negative' => Icons.sentiment_dissatisfied_rounded,
        'NoAnswer' => Icons.phone_missed_rounded,
        'NotInterested' => Icons.block_rounded,
        'CallbackLater' => Icons.event_repeat_rounded,
        _ => Icons.help_outline_rounded,
      };

  Color _outcomeColor(String outcome) => switch (outcome) {
        'Positive' => AppColors.success,
        'Neutral' => AppColors.info,
        'Negative' => AppColors.error,
        'NoAnswer' => AppColors.warning,
        'NotInterested' => AppColors.neutral,
        'CallbackLater' => Colors.purple,
        _ => AppColors.navy,
      };

  String _date(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? '—' : DateFormat('yyyy/MM/dd').format(date);
  }

  String _dateTime(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? '—' : DateFormat('yyyy/MM/dd HH:mm').format(date);
  }
}
