import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/app_colors.dart';
import '../services/cashbox_service.dart';
import '../services/design_tokens.dart';
import '../widgets/design_kit.dart';

/// مراجعة الخزينة (Item 27) — مرآة CashBoxReview في بلازور:
/// أرقام فترة بالتعريف الموحد + تفصيل مصادر + مساعدات مراجعة +
/// ختم مراجعة خفيف بكشف التغيّر بعد المراجعة (بلا أي قفل).
class CashboxReviewScreen extends StatefulWidget {
  final String username;

  const CashboxReviewScreen({super.key, required this.username});

  @override
  State<CashboxReviewScreen> createState() => _CashboxReviewScreenState();
}

class _CashboxReviewScreenState extends State<CashboxReviewScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _boxes = [];
  List<Map<String, dynamic>> _recent = [];
  Map<String, dynamic>? _review;
  int? _selectedBoxId;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String _filter = 'all';
  bool _stamping = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  String _fmt(dynamic v) => NumberFormat('#,##0.00').format(_num(v));

  String _date(dynamic v) {
    final d = DateTime.tryParse('${v ?? ''}');
    return d == null ? '—' : DateFormat('yyyy/MM/dd').format(d);
  }

  Future<void> _init() async {
    final List<Map<String, dynamic>> boxes;
    try {
      boxes = await CashboxService.getAllCashboxes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _boxes = boxes;
      for (final b in boxes) {
        if (b['IsDefault'] == true && b['IsActive'] != false) {
          _selectedBoxId = (b['CashBoxID'] as num?)?.toInt();
          break;
        }
      }
      _selectedBoxId ??= boxes.isNotEmpty
          ? (boxes.first['CashBoxID'] as num?)?.toInt()
          : null;
    });
    await _load();
  }

  Future<void> _load() async {
    if (_selectedBoxId == null) {
      setState(() {
        _loading = false;
        _error = 'لا توجد خزينة للمراجعة';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final review = await CashboxService.getReview(
        cashboxId: _selectedBoxId!,
        from: _from,
        to: _to,
      );
      final recent = await CashboxService.getRecentStamps();
      if (!mounted) return;
      setState(() {
        _review = review;
        _recent = recent;
        _filter = 'all';
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

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _load();
  }

  Map<String, dynamic> get _stamp {
    final s = _review?['Stamp'];
    return s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
  }

  Map<String, dynamic> get _aids {
    final a = _review?['Aids'];
    return a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{};
  }

  List<dynamic> _ids(String key) {
    final v = _aids[key];
    return v is List ? v : const [];
  }

  List<Map<String, dynamic>> get _movements {
    final raw = _review?['Movements'];
    if (raw is! List) return [];
    var list = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    Set<int> pick(List<dynamic> ids) =>
        ids.map((e) => (e as num).toInt()).toSet();
    switch (_filter) {
      case 'manual':
        final ids = pick(_ids('ManualMovementIds'));
        list = list
            .where((m) => ids.contains((m['CashboxTransactionId'] as num?)?.toInt()))
            .toList();
        break;
      case 'noref':
        final ids = pick(_ids('NoReferenceMovementIds'));
        list = list
            .where((m) => ids.contains((m['CashboxTransactionId'] as num?)?.toInt()))
            .toList();
        break;
      case 'backdated':
        final ids = pick(_ids('BackdatedMovementIds'));
        list = list
            .where((m) => ids.contains((m['CashboxTransactionId'] as num?)?.toInt()))
            .toList();
        break;
      case 'largest':
        final rawLargest = _aids['LargestMovements'];
        if (rawLargest is List) {
          list = rawLargest
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        break;
      case 'negative':
        final ids = pick(_ids('NegativeDayMovementIds'));
        list = list
            .where((m) => ids.contains((m['CashboxTransactionId'] as num?)?.toInt()))
            .toList();
        break;
    }
    return list;
  }

  Future<void> _stampReview() async {
    final stamp = _stamp;
    if (_review?['RequiresSql'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'جدول أختام مراجعة الخزينة غير مهيأ بعد — برجاء تشغيل سكربت cashbox-review.sql أولًا.'),
        ),
      );
      return;
    }
    final noteCtrl = TextEditingController(text: '${stamp['Note'] ?? ''}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ختم المراجعة'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ملاحظة المراجعة (اختياري)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ الختم'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      noteCtrl.dispose();
      return;
    }
    setState(() => _stamping = true);
    try {
      final result = await CashboxService.stampReview(
        cashboxId: _selectedBoxId!,
        from: _from,
        to: _to,
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _stamping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result['message'] ?? 'تم حفظ ختم المراجعة.'}'),
          backgroundColor: AppColors.success,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _stamping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة الخزينة'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const AppLoading(message: 'جاري تحميل المراجعة...')
          : _error != null
              ? AppError(message: _error!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final r = _review!;
    final stamp = _stamp;
    final status = '${stamp['Status'] ?? 'NotReviewed'}';
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
                  title: 'اختيار المراجعة',
                  icon: Icons.fact_check_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: _selectedBoxId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الخزينة',
                    border: OutlineInputBorder(),
                  ),
                  items: _boxes
                      .map((b) => DropdownMenuItem<int>(
                            value: (b['CashBoxID'] as num?)?.toInt(),
                            child: Text('${b['CashBoxName'] ?? ''}'),
                          ))
                      .toList(),
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
                        label: Text(
                            'من ${DateFormat('yyyy/MM/dd').format(_from)}'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(false),
                        icon: const Icon(Icons.calendar_month_rounded,
                            size: 16),
                        label: Text(
                            'إلى ${DateFormat('yyyy/MM/dd').format(_to)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _stampCard(status, stamp),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionHeader(
                  title: 'أرقام الفترة',
                  icon: Icons.summarize_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                _figureRow('رصيد أول المدة', r['OpeningBalance']),
                _figureRow('وارد الفترة', r['TotalIn'],
                    color: AppColors.success),
                _figureRow('صادر الفترة', r['TotalOut'],
                    color: AppColors.error),
                _figureRow('رصيد آخر المدة', r['ClosingBalance'], bold: true),
                if (r['IsTruncated'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'تنبيه: حركات الفترة تتجاوز حد العرض (2000) — القائمة مقطوعة والأيام السالبة معطلة.',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(
            title: 'تفصيل المصادر',
            icon: Icons.pie_chart_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          ..._sourceRows(),
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(
            title: 'حركات الفترة',
            icon: Icons.list_alt_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _aidsChips(),
          const SizedBox(height: AppSpacing.sm),
          if (_movements.isEmpty)
            const AppEmpty(
              icon: Icons.receipt_long_rounded,
              message: 'لا توجد حركات في هذا النطاق',
            )
          else
            ..._movements.map(_movementRow),
          if (_recent.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader(
              title: 'أحدث الأختام',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            ..._recent.map(_recentRow),
          ],
        ],
      ),
    );
  }

  Widget _stampCard(String status, Map<String, dynamic> stamp) {
    final (label, color) = switch (status) {
      'Reviewed' => ('تمت مراجعتها', AppColors.success),
      'ChangedAfterReview' => ('تغيّرت بعد المراجعة', AppColors.error),
      _ => ('لم تتم مراجعتها', AppColors.warning),
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: AppSectionHeader(
                  title: 'حالة المراجعة',
                  icon: Icons.verified_rounded,
                ),
              ),
              StatusBadge(label: label, color: color, small: true),
            ],
          ),
          if (_review?['RequiresSql'] == true) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'الأختام معطلة: شغّل سكربت cashbox-review.sql على قاعدة البيانات لتفعيل ختم المراجعة.',
              style: TextStyle(color: AppColors.warning),
            ),
          ],
          if (status != 'NotReviewed') ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
                'بواسطة ${stamp['ReviewedByName'] ?? stamp['ReviewedByUserName'] ?? ''} — ${_date(stamp['ReviewedAt'])}'),
            if (status == 'ChangedAfterReview') ...[
              _figureRow('فرق عدد الحركات', stamp['CountDifference']),
              _figureRow('فرق الوارد', stamp['TotalInDifference']),
              _figureRow('فرق الصادر', stamp['TotalOutDifference']),
              if (stamp['LastTxCreatedAtChanged'] == true)
                const Text('وُجدت حركة أحدث من وقت الختم.'),
            ],
            if ((stamp['Note'] ?? '').toString().isNotEmpty)
              Text('ملاحظة: ${stamp['Note']}'),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _stamping ? null : _stampReview,
              icon: const Icon(Icons.fact_check_rounded, size: 18),
              label: Text(status == 'NotReviewed'
                  ? 'ختم المراجعة'
                  : 'إعادة ختم المراجعة بالأرقام الحالية'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sourceRows() {
    final raw = _review?['SourceBreakdown'];
    if (raw is! List || raw.isEmpty) {
      return [
        const AppEmpty(
          icon: Icons.pie_chart_rounded,
          message: 'لا توجد مصادر حركة في الفترة',
        ),
      ];
    }
    return raw.whereType<Map>().map((e) {
      final row = Map<String, dynamic>.from(e);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row['Category'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${row['Count'] ?? 0} حركة — ${(row['RawReferenceTypes'] as List?)?.join('، ') ?? ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(
                      value: '+${_fmt(row['TotalIn'])}',
                      size: 12,
                      color: AppColors.success),
                  AmountText(
                      value: '-${_fmt(row['TotalOut'])}',
                      size: 12,
                      color: AppColors.error),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _aidsChips() {
    Widget chip(String key, String label, int count) => FilterChip(
          label: Text('$label ($count)'),
          selected: _filter == key,
          onSelected: (_) => setState(() => _filter = key),
        );
    final negativeDays = _aids['NegativeDays'];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        chip('all', 'الكل', (_review?['Movements'] as List?)?.length ?? 0),
        chip('manual', 'حركات يدوية', _ids('ManualMovementIds').length),
        chip('noref', 'بلا مرجع', _ids('NoReferenceMovementIds').length),
        chip('backdated', 'بتاريخ رجعي', _ids('BackdatedMovementIds').length),
        chip('largest', 'أكبر خمس حركات',
            (_aids['LargestMovements'] as List?)?.length ?? 0),
        if (_aids['NegativeDaysAvailable'] == true)
          chip('negative', 'أيام سالبة',
              negativeDays is List ? negativeDays.length : 0),
      ],
    );
  }

  Widget _movementRow(Map<String, dynamic> m) {
    final isIn = m['TransactionType'] == 'قبض';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isIn ? AppColors.success : AppColors.error,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m['Notes'] ?? m['ReferenceType'] ?? 'حركة خزينة'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${_date(m['TransactionDate'])} — ${m['ReferenceType'] ?? 'يدوية'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            AmountText(
              value: '${isIn ? '+' : '-'}${_fmt(m['Amount'])}',
              size: 13,
              color: isIn ? AppColors.success : AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentRow(Map<String, dynamic> stamp) {
    final status = '${stamp['Status'] ?? 'NotReviewed'}';
    final (label, color) = switch (status) {
      'Reviewed' => ('تمت مراجعتها', AppColors.success),
      'ChangedAfterReview' => ('تغيّرت بعد المراجعة', AppColors.error),
      _ => ('لم تتم مراجعتها', AppColors.warning),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () {
          setState(() {
            _selectedBoxId = (stamp['CashBoxId'] as num?)?.toInt();
            _from = DateTime.tryParse('${stamp['PeriodFrom']}') ?? _from;
            _to = DateTime.tryParse('${stamp['PeriodTo']}') ?? _to;
          });
          _load();
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${stamp['CashBoxName'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${_date(stamp['PeriodFrom'])} — ${_date(stamp['PeriodTo'])} • ${stamp['ReviewedByName'] ?? stamp['ReviewedByUserName'] ?? ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            StatusBadge(label: label, color: color, small: true),
          ],
        ),
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
}
