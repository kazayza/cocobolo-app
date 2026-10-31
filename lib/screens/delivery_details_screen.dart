import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../widgets/design_kit.dart';
import '../services/delivery_service.dart';
import '../services/permission_service.dart';
import 'general_tasks_screen.dart';
import '../widgets/record_delivery_dialog.dart';
import '../services/theme_service.dart';
import '../widgets/app_states.dart';
import 'invoice/invoice_details_screen.dart';

class DeliveryDetailsScreen extends StatefulWidget {
  final int transactionId;
  final String username;

  const DeliveryDetailsScreen({
    super.key,
    required this.transactionId,
    required this.username,
  });

  @override
  State<DeliveryDetailsScreen> createState() => _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends State<DeliveryDetailsScreen> {
  final DeliveryService _service = DeliveryService();
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _scheduleRequests = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _employees = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _isDark => ThemeService().isDarkMode;
  Map<String, dynamic> get _capabilities => _map(_data?['capabilities']);
  bool _can(String key) => _capabilities[key] == true;

  @override
  void initState() {
    super.initState();
    _load();
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
      final data = await _service.getDelivery(widget.transactionId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      try {
        final sched =
            await _service.getScheduleRequests(widget.transactionId);
        if (mounted) {
          setState(() {
            _scheduleRequests = ((sched['rows'] as List?) ?? const [])
                .map<Map<String, dynamic>>(_map)
                .toList();
          });
        }
      } catch (_) {}
      if (_can('canEditFull')) {
        try {
          _employees = await _service.getEmployees();
          if (mounted) setState(() {});
        } catch (_) {}
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _requestPermission() async {
    await _run(() => _service.requestPermission(widget.transactionId));
  }

  Future<void> _grantPermission() async {
    await _run(() => _service.grantPermission(widget.transactionId));
  }

  Future<void> _confirm() async {
    await _showConfirmDialog();
  }

  // Item 1/3 (Pkg1): recording now goes through the per-line record-event
  // dialog (dispositions + live coverage) as the primary path.
  Future<void> _showConfirmDialog() async {
    final data = _data!;
    final products = ((data['Products'] as List?) ?? const [])
        .map<Map<String, dynamic>>(_map)
        .toList();
    final saved = await showRecordDeliveryDialog(
      context,
      transactionId: widget.transactionId,
      products: products,
      employees: _employees,
      canSeeAmounts: _can('canSeeAmounts'),
      canEditFull: _can('canEditFull'),
      canOverrideRemaining: _can('canOverrideRemaining'),
      permissionGranted:
          data['LastPermissionAction'] == 'DeliveryPermissionGranted',
      initialEmployeeId: data['DeliveryEmployeeId'] is num
          ? (data['DeliveryEmployeeId'] as num).toInt()
          : null,
    );
    if (saved && mounted) await _load();
  }

  // Item 2 (Pkg1): void a delivery event — Admin/AccountManager only
  // (capability canVoidDelivery), mandatory reason.
  Future<void> _voidEvent(Map<String, dynamic> event) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إلغاء حدث تسليم',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: GoogleFonts.cairo(),
          decoration: InputDecoration(
            labelText: 'سبب الإلغاء (إلزامي)',
            labelStyle: GoogleFonts.cairo(),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('تراجع', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: Text('إلغاء الحدث', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final reason = ctrl.text.trim();
    ctrl.dispose();
    await _run(() => _service.voidEvent(
          id: widget.transactionId,
          deliveryId: _int(event['DeliveryId']),
          reason: reason,
        ));
  }

  // Item 6 (Pkg2): create a schedule-change request.
  Future<void> _createScheduleRequest() async {
    final data = _data!;
    final products = ((data['Products'] as List?) ?? const [])
        .map<Map<String, dynamic>>(_map)
        .where((pr) => _num(pr['RemainingQty']) > 0.0005)
        .toList();
    final reasonCtrl = TextEditingController();
    DateTime? proposedDue;
    final lineDates = <int, DateTime?>{};
    final lineCustom = <int, bool>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('طلب تعديل موعد / تقسيم',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('التاريخ الكلي المقترح (اختياري)',
                      style: GoogleFonts.cairo(fontSize: 12)),
                  subtitle: Text(
                      proposedDue == null
                          ? 'لا تغيير'
                          : DateFormat('yyyy/MM/dd').format(proposedDue!),
                      style: GoogleFonts.cairo(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_month_rounded),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: proposedDue ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate:
                            DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setDialogState(() => proposedDue = picked);
                      }
                    },
                  ),
                ),
                for (final pr in products) ...[
                  const Divider(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text(
                        '${pr['ProductName'] ?? ''} — موعده: ${_date(pr['ScheduledDate'])}${pr['ScheduledDateIsCustom'] == true ? ' (خاص)' : ''}',
                        style: GoogleFonts.cairo(fontSize: 11.5),
                      ),
                    ),
                    if (lineCustom[_int(pr['DetailID'])] == true)
                      TextButton(
                        onPressed: () => setDialogState(() {
                          lineCustom[_int(pr['DetailID'])] = false;
                          lineDates[_int(pr['DetailID'])] = null;
                        }),
                        child: Text('اتباع تاريخ الفاتورة',
                            style: GoogleFonts.cairo(fontSize: 10)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_month_rounded,
                          size: 19),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate:
                              lineDates[_int(pr['DetailID'])] ??
                                  DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            lineDates[_int(pr['DetailID'])] = picked;
                            lineCustom[_int(pr['DetailID'])] = true;
                          });
                        }
                      },
                    ),
                  ]),
                  if (lineCustom[_int(pr['DetailID'])] == true)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'المقترح: ${DateFormat('yyyy/MM/dd').format(lineDates[_int(pr['DetailID'])]!)}',
                        style: GoogleFonts.cairo(
                            fontSize: 10.5, color: AppColors.warning),
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: GoogleFonts.cairo(),
                  decoration: InputDecoration(
                    labelText: 'سبب طلب التعديل (إلزامي)',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ]),
            ),
          ),
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
              child: Text('إرسال الطلب', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final lines = <Map<String, dynamic>>[
      for (final entry in lineCustom.entries)
        if (entry.value || lineDates[entry.key] != null)
          {
            'transactionDetailId': entry.key,
            'proposedDate': lineDates[entry.key]?.toIso8601String(),
            'proposedIsCustom': entry.value,
          },
    ];
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    await _run(() => _service.createScheduleRequest(
          id: widget.transactionId,
          reason: reason,
          proposedDueDate: proposedDue,
          lines: lines,
        ));
  }

  // Item 6 (Pkg2): decide a schedule-change request with editable finals.
  Future<void> _decideScheduleRequest(Map<String, dynamic> request) async {
    Map<String, dynamic> approval;
    try {
      approval = await _service.getScheduleApproval(_int(request['Id']));
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
      return;
    }
    if (!mounted) return;
    final reqMap = _map(approval['Request']);
    final currentLines = ((approval['CurrentLines'] as List?) ?? const [])
        .map<Map<String, dynamic>>(_map)
        .toList();
    final proposedByDetail = <int, Map<String, dynamic>>{};
    for (final l in ((reqMap['Lines'] as List?) ?? const [])
        .map<Map<String, dynamic>>(_map)) {
      proposedByDetail[_int(l['TransactionDetailId'])] = l;
    }
    final finalDates = <int, DateTime?>{};
    final finalCustom = <int, bool>{};
    for (final entry in proposedByDetail.entries) {
      finalCustom[entry.key] = entry.value['ProposedIsCustom'] == true;
      finalDates[entry.key] = entry.value['ProposedDate'] == null
          ? null
          : DateTime.tryParse('${entry.value['ProposedDate']}');
    }
    DateTime? finalDue = reqMap['ProposedDueDate'] == null
        ? null
        : DateTime.tryParse('${reqMap['ProposedDueDate']}');
    final noteCtrl = TextEditingController();
    final decision = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('اعتماد طلب تعديل المواعيد',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('السبب: ${reqMap['Reason'] ?? ''}',
                    style: GoogleFonts.cairo(fontSize: 12)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'التاريخ الكلي الحالي (الحقيقي): ${_date(approval['CurrentDueDate'])}',
                      style: GoogleFonts.cairo(fontSize: 11.5)),
                  subtitle: Text(
                      'النهائي: ${finalDue == null ? 'لا تغيير' : DateFormat('yyyy/MM/dd').format(finalDue!)}',
                      style: GoogleFonts.cairo(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_month_rounded),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: finalDue ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate:
                            DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setDialogState(() => finalDue = picked);
                      }
                    },
                  ),
                ),
                for (final line in currentLines) ...[
                  const Divider(height: 8),
                  Text(
                    '${line['ProductName'] ?? ''} — الحالي الحقيقي: ${_date(line['CurrentDate'])}${line['CurrentIsCustom'] == true ? ' (خاص)' : ''} — متبقٍّ ${_num(line['RemainingQty'])}',
                    style: GoogleFonts.cairo(fontSize: 11.5),
                  ),
                  if (proposedByDetail
                      .containsKey(_int(line['TransactionDetailId'])))
                    Row(children: [
                      Expanded(
                        child: Text(
                          finalCustom[_int(line['TransactionDetailId'])] ==
                                  true
                              ? 'النهائي: ${finalDates[_int(line['TransactionDetailId'])] == null ? '—' : DateFormat('yyyy/MM/dd').format(finalDates[_int(line['TransactionDetailId'])]!)}'
                              : 'النهائي: اتباع تاريخ الفاتورة',
                          style: GoogleFonts.cairo(fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          finalCustom[_int(line['TransactionDetailId'])] =
                              false;
                          finalDates[_int(line['TransactionDetailId'])] =
                              null;
                        }),
                        child: Text('اتباع الفاتورة',
                            style: GoogleFonts.cairo(fontSize: 10)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month_rounded,
                            size: 19),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate:
                                finalDates[_int(line['TransactionDetailId'])] ??
                                    DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 730)),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              finalDates[_int(line['TransactionDetailId'])] =
                                  picked;
                              finalCustom[_int(line['TransactionDetailId'])] =
                                  true;
                            });
                          }
                        },
                      ),
                    ]),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  style: GoogleFonts.cairo(),
                  decoration: InputDecoration(
                    labelText: 'ملاحظة القرار (إلزامية عند الرفض)',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: Text('إغلاق', style: GoogleFonts.cairo()),
            ),
            OutlinedButton(
              onPressed: () {
                if (noteCtrl.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, false);
              },
              child: Text('رفض الطلب',
                  style: GoogleFonts.cairo(color: AppColors.error)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('اعتماد وتطبيق', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (decision == null) return;
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    final finalLines = <Map<String, dynamic>>[
      for (final entry in proposedByDetail.entries)
        {
          'transactionDetailId': entry.key,
          'finalDate': finalDates[entry.key]?.toIso8601String(),
          'finalIsCustom': finalCustom[entry.key] ?? false,
        },
    ];
    await _run(() => _service.decideScheduleRequest(
          requestId: _int(request['Id']),
          approve: decision,
          finalDueDate: finalDue,
          finalLines: finalLines,
          note: note.isEmpty ? null : note,
        ));
  }

  Future<void> _edit() async {
    String status = '${_data?['DeliveryStatus'] ?? 'pending'}';
    if (status != 'returned' && status != 'delivered') status = 'pending';
    int? employeeId = _data?['DeliveryEmployeeId'] is num
        ? (_data!['DeliveryEmployeeId'] as num).toInt()
        : null;
    final notes =
        TextEditingController(text: '${_data?['DeliveredNotes'] ?? ''}');
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(_isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              18, 18, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('تعديل بيانات التسليم',
                style: GoogleFonts.cairo(
                    fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: InputDecoration(
                labelText: 'الحالة',
                labelStyle: GoogleFonts.cairo(),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('قيد التسليم')),
                DropdownMenuItem(value: 'returned', child: Text('مرتجع')),
                DropdownMenuItem(value: 'delivered', child: Text('تم التسليم')),
              ],
              onChanged: (value) {
                if (value != null) setSheetState(() => status = value);
              },
            ),
            const SizedBox(height: 12),
            if (_employees.isNotEmpty)
              DropdownButtonFormField<int?>(
                initialValue: employeeId,
                decoration: InputDecoration(
                  labelText: 'مندوب التسليم',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                items: [
                  DropdownMenuItem<int?>(
                      value: null,
                      child: Text('بدون تحديد', style: GoogleFonts.cairo())),
                  ..._employees.map((employee) => DropdownMenuItem<int?>(
                        value: _int(employee['EmployeeID']),
                        child: Text('${employee['FullName'] ?? ''}',
                            style: GoogleFonts.cairo()),
                      )),
                ],
                onChanged: (value) => setSheetState(() => employeeId = value),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              maxLines: 3,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                labelText: 'ملاحظات',
                labelStyle: GoogleFonts.cairo(),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.save_rounded),
                label: Text('حفظ التعديلات', style: GoogleFonts.cairo()),
              ),
            ),
          ]),
        ),
      ),
    );
    if (save != true) return;
    await _run(() => _service.updateDelivery(
          id: widget.transactionId,
          status: status,
          deliveryEmployeeId: employeeId,
          notes: notes.text.trim(),
        ));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('تفاصيل التسليم #${widget.transactionId}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        actions: [
          if (_data != null && _can('canEditFull'))
            IconButton(
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'تعديل',
            ),
          IconButton(
            tooltip: 'تكليف جديد',
            icon: const Icon(Icons.add_task_rounded),
            color: AppColors.gold,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GeneralTasksScreen(
                    userId: PermissionService().userId ?? 0,
                    username: widget.username,
                    presetLinkedType: 'Delivery',
                    presetLinkedId: widget.transactionId,
                    autoOpenCreate: true,
                  ),
                ),
              );
            },
          ),
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(children: [
        if (_loading)
          const AppLoading(message: 'جاري تحميل تفاصيل التسليم')
        else if (_error != null)
          AppError(message: _error!, onRetry: _load)
        else
          _body(),
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

  Widget _body() {
    final data = _data!;
    final status = '${data['DeliveryStatus'] ?? 'upcoming'}';
    final delivered = status == 'delivered';
    final pending = data['HasPendingPermissionRequest'] == true;
    final remaining = _num(data['RemainingAmount']);
    final products = (data['Products'] as List? ?? const [])
        .map<Map<String, dynamic>>(_map)
        .toList();
    final color = _statusColor(status);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppGradients.identityHeader,
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: AppRadius.all(AppRadius.xxl),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.32)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: AppRadius.all(AppRadius.md),
                  ),
                  child: Icon(
                      delivered
                          ? Icons.check_circle_rounded
                          : Icons.local_shipping_rounded,
                      color: color,
                      size: 27),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${data['ClientName'] ?? '—'}',
                            style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900)),
                        Text(
                            '${data['ReferenceNumber'] ?? '#${data['TransactionID']}'}',
                            style: GoogleFonts.cairo(
                                color: Colors.white60, fontSize: 10.5)),
                      ]),
                ),
                StatusBadge(label: _statusLabel(status), color: color, filled: true),
              ]),
              if (_can('canSeeAmounts')) ...[
                const SizedBox(height: 14),
                Row(children: [
                  _amount('الإجمالي', data['GrandTotal']),
                  _amount('المدفوع', data['PaidAmount']),
                  _amount('المتبقي', data['RemainingAmount']),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          _section(
            title: 'بيانات الفاتورة والتسليم',
            icon: Icons.receipt_long_rounded,
            children: [
              _line('تاريخ الفاتورة', _date(data['TransactionDate'])),
              _line('موعد التسليم', _date(data['DueDate'])),
              if (data['DeliveredAt'] != null)
                _line('تاريخ التسليم', _date(data['DeliveredAt'])),
              _line('موظف المبيعات', data['SalesEmployeeName']),
              _line('مندوب التسليم', data['DeliveryEmployeeName']),
              if ((data['DeliveredNotes'] ?? '').toString().isNotEmpty)
                _line('ملاحظات التسليم', data['DeliveredNotes']),
            ],
          ),
          const SizedBox(height: 10),
          _section(
            title: 'بيانات العميل',
            icon: Icons.person_rounded,
            children: [
              _line('الاسم', data['ClientName']),
              _line('الهاتف', data['Phone']),
              if ((data['Phone2'] ?? '').toString().isNotEmpty)
                _line('هاتف إضافي', data['Phone2']),
              _line('العنوان', data['Address']),
            ],
          ),
          const SizedBox(height: 10),
          _section(
            title: 'الأصناف (${products.length})',
            icon: Icons.inventory_2_rounded,
            children: [
              if (products.isEmpty)
                Text('لا توجد أصناف', style: GoogleFonts.cairo())
              else
                for (final product in products)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.inventory_2_outlined,
                        color: AppColors.goldDark),
                    title: Text('${product['ProductName'] ?? '—'}',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      'الكمية: ${product['Quantity'] ?? 0}'
                      '${(product['AlternativeName'] ?? '').toString().isEmpty ? '' : ' — ${product['AlternativeName']}'}'
                      '\nمقبول: ${_num(product['DeliveredQty'])} — داخل الصيانة: ${_num(product['InLoopQty'])} — مُسوّى: ${_num(product['SettledQty'])} — متبقٍّ: ${_num(product['RemainingQty'])}'
                      '\nموعد التسليم: ${_date(product['ScheduledDate'])}${product['ScheduledDateIsCustom'] == true ? ' (موعد خاص)' : ''}${product['IsScheduleOverdue'] == true ? ' — متأخر' : ''}'
                      '${product['LastDeliveryDate'] == null ? '' : '\nآخر تسليمة: ${_date(product['LastDeliveryDate'])}'}',
                      style: GoogleFonts.cairo(fontSize: 10.5),
                    ),
                    trailing: _can('canSeeAmounts')
                        ? AmountText(value: _money(product['TotalAmount']))
                        : null,
                  ),
            ],
          ),
          const SizedBox(height: 10),
          // Item 8 (Pkg1): delivery progress summary from the API Progress block
          _section(
            title: 'تقدم التسليم',
            icon: Icons.local_shipping_rounded,
            children: [
              _line('إجمالي المفوتر', '${_num(_map(data['Progress'])['TotalInvoicedQty'])}'),
              _line('المقبول', '${_num(_map(data['Progress'])['TotalDeliveredQty'])}'),
              _line('داخل الصيانة', '${_num(_map(data['Progress'])['TotalInLoopQty'])}'),
              _line('المُسوّى', '${_num(_map(data['Progress'])['TotalSettledQty'])}'),
              _line('المتبقي', '${_num(_map(data['Progress'])['TotalRemainingQty'])}'),
              _line('عدد الأحداث', '${_int(_map(data['Progress'])['EventCount'])}'),
            ],
          ),
          const SizedBox(height: 10),
          // Item 8 + Item 2: events history (actual dates are facts — never masked)
          _section(
            title: 'سجل أحداث التسليم',
            icon: Icons.history_rounded,
            children: [
              if (((data['Events'] as List?) ?? const []).isEmpty)
                Text('لا توجد أحداث تسليم مسجلة', style: GoogleFonts.cairo())
              else
                for (final event in ((data['Events'] as List?) ?? const [])
                    .map<Map<String, dynamic>>(_map))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                        event['IsVoided'] == true
                            ? Icons.block_rounded
                            : Icons.check_circle_rounded,
                        color: event['IsVoided'] == true
                            ? AppColors.error
                            : AppColors.success),
                    title: Text(
                      '${_date(event['DeliveryDate'])} — ${event['DeliveryEmployeeName'] ?? ''}${event['IsVoided'] == true ? ' (ملغي)' : ''}',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    subtitle: Text(
                      ((event['Items'] as List?) ?? const [])
                          .map<Map<String, dynamic>>(_map)
                          .map((it) =>
                              '${it['ProductName'] ?? ''}: مقبول ${_num(it['AcceptedQty'])} / راجع ${_num(it['ReturnedManufacturingQty']) + _num(it['ReturnedHandlingQty']) + _num(it['ReturnedModificationQty'])}')
                          .join('، '),
                      style: GoogleFonts.cairo(fontSize: 10.5),
                    ),
                    trailing: (event['IsVoided'] != true &&
                            _can('canVoidDelivery'))
                        ? IconButton(
                            icon: const Icon(Icons.undo_rounded,
                                color: AppColors.error),
                            tooltip: 'إلغاء الحدث',
                            onPressed:
                                _busy ? null : () => _voidEvent(event),
                          )
                        : null,
                  ),
            ],
          ),
          const SizedBox(height: 10),
          _section(
            title: 'سجلات الصيانة',
            icon: Icons.build_circle_rounded,
            children: [
              if (((data['Maintenance'] as List?) ?? const []).isEmpty)
                Text('لا توجد سجلات صيانة', style: GoogleFonts.cairo())
              else
                for (final m in ((data['Maintenance'] as List?) ?? const [])
                    .map<Map<String, dynamic>>(_map))
                  _line(
                    '${m['ReasonClass'] ?? ''} — ${m['Status'] ?? ''}',
                    'كمية ${_num(m['Quantity'])}${(m['IssueDescription'] ?? '').toString().isEmpty ? '' : ' — ${m['IssueDescription']}'}',
                  ),
            ],
          ),
          const SizedBox(height: 10),
          _section(
            title: 'رسوم التعديل',
            icon: Icons.receipt_long_rounded,
            children: [
              if (((data['Charges'] as List?) ?? const []).isEmpty)
                Text('لا توجد رسوم تعديل', style: GoogleFonts.cairo())
              else
                for (final ch in ((data['Charges'] as List?) ?? const [])
                    .map<Map<String, dynamic>>(_map))
                  _line(
                    '${ch['ChargeDescription'] ?? 'رسم تعديل'} — ${ch['Status'] ?? ''}',
                    _can('canSeeAmounts') && ch['ChargeAmount'] != null
                        ? _money(ch['ChargeAmount'])
                        : 'الحالة فقط',
                  ),
            ],
          ),
          const SizedBox(height: 10),
          // Item 6 (Pkg2): schedule-change requests section
          _section(
            title: 'طلبات تعديل المواعيد',
            icon: Icons.schedule_rounded,
            children: [
              if (_scheduleRequests.any((r) => r['Status'] == 'Pending'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: StatusBadge(
                      label: 'طلب تعديل موعد قيد الانتظار',
                      color: AppColors.warning,
                      small: true),
                ),
              if (_scheduleRequests.isEmpty)
                Text('لا توجد طلبات تعديل مواعيد',
                    style: GoogleFonts.cairo())
              else
                for (final r in _scheduleRequests)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      '${r['Status'] ?? ''} — ${r['RequesterName'] ?? r['RequesterUserName'] ?? ''}',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    subtitle: Text(
                      '${r['Reason'] ?? ''}${r['DecisionNote'] == null ? '' : '\nقرار: ${r['DecisionNote']}'}',
                      style: GoogleFonts.cairo(fontSize: 10.5),
                    ),
                    trailing: Wrap(spacing: 2, children: [
                      if (r['Status'] == 'Pending' &&
                          _can('canDecideScheduleChange'))
                        IconButton(
                          icon: const Icon(Icons.gavel_rounded,
                              color: AppColors.navy),
                          tooltip: 'اعتماد / رفض',
                          onPressed: _busy
                              ? null
                              : () => _decideScheduleRequest(r),
                        ),
                      if (r['Status'] == 'Pending' &&
                          '${r['RequesterUserName'] ?? ''}' ==
                              widget.username)
                        IconButton(
                          icon: const Icon(Icons.undo_rounded,
                              color: AppColors.error),
                          tooltip: 'سحب الطلب',
                          onPressed: _busy
                              ? null
                              : () => _run(() =>
                                  _service.withdrawScheduleRequest(
                                      _int(r['Id']))),
                        ),
                    ]),
                  ),
              if (_can('canRequestScheduleChange') &&
                  !_scheduleRequests
                      .any((r) => r['Status'] == 'Pending')) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _createScheduleRequest,
                    icon: const Icon(Icons.schedule_rounded, size: 17),
                    label: Text('طلب تعديل موعد / تقسيم',
                        style: GoogleFonts.cairo()),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            if ((data['Phone'] ?? '').toString().isNotEmpty) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _call('${data['Phone']}'),
                  icon: const Icon(Icons.call_rounded),
                  label: Text('اتصال', style: GoogleFonts.cairo()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _whatsapp('${data['Phone']}'),
                  icon: const FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: AppColors.whatsapp,
                  ),
                  label: Text('واتساب', style: GoogleFonts.cairo()),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceDetailsScreen(
                      transactionId: widget.transactionId,
                      username: widget.username,
                    ),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_rounded),
                label: Text('الفاتورة', style: GoogleFonts.cairo()),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (!delivered && pending && _can('canOverrideRemaining'))
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _grantPermission,
                icon: const Icon(Icons.approval_rounded),
                label: Text('منح إذن التسليم', style: GoogleFonts.cairo()),
              ),
            ),
          if (!delivered && _can('canConfirmDelivery')) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _confirm,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(
                  remaining > 0 &&
                          !_can('canOverrideRemaining') &&
                          data['LastPermissionAction'] !=
                              'DeliveryPermissionGranted'
                      ? 'طلب إذن التسليم'
                      : 'تأكيد التسليم',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.xl,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppSectionHeader(title: title, icon: icon, accent: AppColors.goldDark),
        const Divider(height: 20),
        ...children,
      ]),
    );
  }

  Widget _line(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 115,
            child: Text(label,
                style: GoogleFonts.cairo(
                    color: AppColors.textSecondary(_isDark), fontSize: 11)),
          ),
          Expanded(
            child: Text('${value ?? '—'}',
                style: GoogleFonts.cairo(
                    color: AppColors.text(_isDark),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _amount(String label, dynamic value) => Expanded(
        child: Column(children: [
          AmountText(value: _money(value), color: Colors.white, size: 12),
          Text(label,
              style: GoogleFonts.cairo(color: Colors.white54, fontSize: 9)),
        ]),
      );

  Future<void> _call(String phone) async => launchUrl(Uri.parse('tel:$phone'));

  Future<void> _whatsapp(String phone) async {
    var value = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.startsWith('0')) value = '2$value';
    await launchUrl(Uri.parse('https://wa.me/$value'),
        mode: LaunchMode.externalApplication);
  }

  Color _statusColor(String status) => switch (status) {
        'delivered' => AppColors.success,
        'overdue' => AppColors.error,
        'today' => AppColors.warning,
        'soon' => AppColors.info,
        'returned' => AppStatus.editPending,
        _ => AppColors.goldDark,
      };

  String _statusLabel(String status) => switch (status) {
        'delivered' => 'تم التسليم',
        'overdue' => 'متأخر',
        'today' => 'اليوم',
        'soon' => 'خلال 3 أيام',
        'returned' => 'مرتجع',
        _ => 'قادم',
      };

  String _money(dynamic value) =>
      '${NumberFormat('#,##0.00').format(_num(value))} ج.م';

  String _date(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? 'غير محدد' : DateFormat('yyyy/MM/dd').format(date);
  }
}
