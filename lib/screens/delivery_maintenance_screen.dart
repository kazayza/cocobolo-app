import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/delivery_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_states.dart';
import '../widgets/design_kit.dart';

/// Item 5 (Pkg2) — delivery maintenance queue, mirror of Blazor
/// Components/Pages/DeliveryMaintenance.razor + DeliveryMaintenanceService:
/// queue list with status/reason filters, transitions (start / ready /
/// unrepairable), closures (replacement / final-return credit), cancel
/// with mandatory reason, and reclassify (D12) with mandatory reason.
/// Repair cost and charge amounts are rendered only when the server
/// returns them (server nulls them for roles without permission).
class DeliveryMaintenanceScreen extends StatefulWidget {
  final int userId;
  final String username;

  const DeliveryMaintenanceScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<DeliveryMaintenanceScreen> createState() =>
      _DeliveryMaintenanceScreenState();
}

class _DeliveryMaintenanceScreenState extends State<DeliveryMaintenanceScreen> {
  final DeliveryService _service = DeliveryService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _status;
  String? _reasonClass;
  bool _includeTerminal = false;

  bool get _isDark => ThemeService().isDarkMode;
  bool _can(String name) => _capabilities[name] == true;

  static const Map<String, String> statusLabels = {
    'Pending': 'بانتظار الصيانة',
    'InProgress': 'قيد الصيانة',
    'ReadyForRedelivery': 'جاهز لإعادة التسليم',
    'Redelivered': 'أعيد تسليمه',
    'Unrepairable': 'تعذّر إصلاحه',
    'ClosedByReplacement': 'أُغلق باستبدال',
    'ClosedByCredit': 'أُغلق بردّ نهائي/رصيد',
    'Cancelled': 'أُلغي الطلب',
  };

  static const Map<String, String> reasonLabels = {
    'ManufacturingDefect': 'عيب تصنيع',
    'HandlingDamage': 'تلف مناولة',
    'CustomerModification': 'تعديل بطلب العميل',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getMaintenanceQueue(
        status: _status,
        reasonClass: _reasonClass,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        includeTerminal: _includeTerminal,
      );
      if (!mounted) return;
      setState(() {
        _rows = ((data['rows'] as List?) ?? const [])
            .map<Map<String, dynamic>>(_map)
            .toList();
        _capabilities = _map(data['capabilities']);
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

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _busy = true);
    try {
      final result = await action();
      if (!mounted) return;
      _message('${result['message'] ?? 'تمت العملية بنجاح'}');
      await _load();
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: GoogleFonts.cairo()),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<String?> _reasonDialog(String title, String label) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: GoogleFonts.cairo(),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.cairo(),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, ctrl.text.trim());
            },
            child: Text('تأكيد', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return value;
  }

  Future<void> _ready(Map<String, dynamic> row) async {
    final costCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('جاهز لإعادة التسليم',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: costCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
              labelText: 'تكلفة الإصلاح (اختيارية)',
              labelStyle: GoogleFonts.cairo(),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notesCtrl,
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
              labelText: 'ملاحظات تكلفة الإصلاح',
              labelStyle: GoogleFonts.cairo(),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('تأكيد الجاهزية', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final cost = double.tryParse(costCtrl.text);
    await _run(() => _service.maintenanceAction(
          _int(row['MaintenanceId']),
          'ready',
          body: {
            'repairCost': cost,
            'repairCostNotes':
                notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          },
        ));
    costCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _reclassify(Map<String, dynamic> row) async {
    String newClass = 'ManufacturingDefect';
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('إعادة تصنيف الرجوع',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: newClass,
              decoration: InputDecoration(
                labelText: 'التصنيف الجديد',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              items: reasonLabels.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: GoogleFonts.cairo())))
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => newClass = v);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                labelText: 'سبب إعادة التصنيف (إلزامي)',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: Text('إعادة التصنيف', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _run(() => _service.maintenanceAction(
          _int(row['MaintenanceId']),
          'reclassify',
          body: {'newClass': newClass, 'reason': reasonCtrl.text.trim()},
        ));
    reasonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('صيانة التسليمات',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(children: [
        if (_loading)
          const AppLoading(message: 'جاري تحميل قائمة الصيانة')
        else if (_error != null)
          AppError(message: _error!, onRetry: _load)
        else
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _filters(),
                const SizedBox(height: 10),
                if (_rows.isEmpty)
                  AppEmpty(
                    message: 'لا توجد سجلات صيانة مطابقة',
                    hint: 'غيّر الفلاتر أو حدّث البيانات',
                    icon: Icons.build_circle_outlined,
                    onRefresh: _load,
                  )
                else
                  for (final row in _rows) _card(row),
              ],
            ),
          ),
        if (_busy)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.28),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ]),
    );
  }

  Widget _filters() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.xl,
      child: Column(children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => _load(),
          style: GoogleFonts.cairo(),
          decoration: InputDecoration(
            hintText: 'العميل، المنتج، أو رقم الفاتورة',
            hintStyle: GoogleFonts.cairo(fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.inputFill(_isDark),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _status,
              decoration: InputDecoration(
                labelText: 'الحالة',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('داخل الحلقة')),
                ...statusLabels.entries.map((e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value, style: GoogleFonts.cairo()))),
              ],
              onChanged: (v) {
                setState(() => _status = v);
                _load();
              },
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _reasonClass,
              decoration: InputDecoration(
                labelText: 'التصنيف',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('الكل')),
                ...reasonLabels.entries.map((e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value, style: GoogleFonts.cairo()))),
              ],
              onChanged: (v) {
                setState(() => _reasonClass = v);
                _load();
              },
            ),
          ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('إظهار المنتهية',
              style: GoogleFonts.cairo(fontSize: 12)),
          value: _includeTerminal,
          onChanged: (v) {
            setState(() => _includeTerminal = v);
            _load();
          },
        ),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final status = '${row['Status'] ?? ''}';
    final terminal = row['IsTerminal'] == true;
    final color = switch (status) {
      'Pending' => AppColors.warning,
      'InProgress' => AppColors.info,
      'ReadyForRedelivery' => AppColors.success,
      'Unrepairable' => AppColors.error,
      _ => AppColors.goldDark,
    };
    final mid = _int(row['MaintenanceId']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        radius: AppRadius.xl,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${row['ProductName'] ?? '—'}',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            StatusBadge(
                label: statusLabels[status] ?? status,
                color: color,
                small: true),
          ]),
          const SizedBox(height: 6),
          Text(
            '${row['TransactionRef'] ?? '#${row['TransactionId']}'} — ${row['PartyName'] ?? ''}',
            style: GoogleFonts.cairo(
                color: AppColors.textSecondary(_isDark), fontSize: 11),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _chip(Icons.numbers_rounded,
                'الكمية: ${_num(row['Quantity'])}'),
            _chip(Icons.category_rounded,
                reasonLabels['${row['ReasonClass']}'] ??
                    '${row['ReasonClass'] ?? ''}'),
            _chip(Icons.schedule_rounded,
                'العمر: ${_int(row['AgeDays'])} يوم'),
            if (row['RepairCost'] != null)
              _chip(Icons.payments_outlined,
                  'تكلفة الإصلاح: ${_num(row['RepairCost'])}'),
            if (row['ChargeAmount'] != null)
              _chip(Icons.receipt_long_rounded,
                  'رسم التعديل: ${_num(row['ChargeAmount'])}'),
          ]),
          if ((row['IssueDescription'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${row['IssueDescription']}',
                style: GoogleFonts.cairo(fontSize: 11.5)),
          ],
          if (!terminal) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (status == 'Pending' && _can('canTransitionMaintenance'))
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() =>
                          _service.maintenanceAction(mid, 'start')),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label:
                      Text('بدء الصيانة', style: GoogleFonts.cairo(fontSize: 10)),
                ),
              if ((status == 'Pending' || status == 'InProgress') &&
                  _can('canTransitionMaintenance'))
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _ready(row),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text('جاهز لإعادة التسليم',
                      style: GoogleFonts.cairo(fontSize: 10)),
                ),
              if (_can('canTransitionMaintenance'))
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() =>
                          _service.maintenanceAction(mid, 'unrepairable')),
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label:
                      Text('تعذّر إصلاحه', style: GoogleFonts.cairo(fontSize: 10)),
                ),
              if (status == 'Unrepairable' &&
                  (_can('canTransitionMaintenance') ||
                      _can('canOverrideRemaining')))
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => _service.maintenanceAction(
                          mid, 'close-replacement')),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label:
                      Text('إغلاق باستبدال', style: GoogleFonts.cairo(fontSize: 10)),
                ),
              if (status == 'Unrepairable' &&
                  _can('canCloseMaintenanceByCredit'))
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() =>
                          _service.maintenanceAction(mid, 'close-credit')),
                  icon: const Icon(Icons.account_balance_wallet_rounded,
                      size: 16),
                  label: Text('إغلاق بردّ نهائي',
                      style: GoogleFonts.cairo(fontSize: 10)),
                ),
              if (_can('canReclassifyMaintenance'))
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _reclassify(row),
                  icon: const Icon(Icons.label_rounded, size: 16),
                  label: Text('إعادة تصنيف',
                      style: GoogleFonts.cairo(fontSize: 10)),
                ),
              if (_can('canCloseMaintenanceByCredit'))
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final reason = await _reasonDialog(
                              'إلغاء طلب الصيانة', 'سبب الإلغاء (إلزامي)');
                          if (reason == null) return;
                          await _run(() => _service.maintenanceAction(
                              mid, 'cancel',
                              body: {'reason': reason}));
                        },
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label:
                      Text('إلغاء الطلب', style: GoogleFonts.cairo(fontSize: 10)),
                ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.textSecondary(_isDark)),
          const SizedBox(width: 5),
          Text(text,
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark), fontSize: 9.5)),
        ]),
      );
}
