import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../services/app_colors.dart';
import '../services/delivery_service.dart';

/// Item 1/3 (Pkg1) — record-delivery-event dialog, mirror of Blazor
/// RecordDeliveryDialog.razor + courier-rules summary point 1/2:
/// per line the courier enters a batch quantity and a disposition split
/// (accepted / manufacturing defect / handling damage / customer
/// modification) whose parts must sum to the batch quantity; the agreed
/// modification price appears only on modification lines and only for
/// users who may see amounts; a live coverage banner (batch coverage
/// gate) is fetched from POST /events/coverage on every change, with the
/// request-permission button inside the dialog. Figures inside the
/// banner come from the server, which nulls them for users without
/// amount permission — the dialog never computes money itself.
class RecordDeliveryLineInput {
  final int detailId;
  final String productName;
  final double remainingQty;
  final int? maintenanceId;
  bool selected;
  final TextEditingController batchCtrl;
  final TextEditingController acceptedCtrl;
  final TextEditingController mfgCtrl;
  final TextEditingController handlingCtrl;
  final TextEditingController modCtrl;
  final TextEditingController noteCtrl;
  final TextEditingController priceCtrl;

  RecordDeliveryLineInput({
    required this.detailId,
    required this.productName,
    required this.remainingQty,
    this.maintenanceId,
    this.selected = false,
  })  : batchCtrl =
            TextEditingController(text: _fmt(remainingQty)),
        acceptedCtrl =
            TextEditingController(text: _fmt(remainingQty)),
        mfgCtrl = TextEditingController(text: '0'),
        handlingCtrl = TextEditingController(text: '0'),
        modCtrl = TextEditingController(text: '0'),
        noteCtrl = TextEditingController(),
        priceCtrl = TextEditingController();

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double get batch => double.tryParse(batchCtrl.text) ?? 0;
  double get accepted => double.tryParse(acceptedCtrl.text) ?? 0;
  double get mfg => double.tryParse(mfgCtrl.text) ?? 0;
  double get handling => double.tryParse(handlingCtrl.text) ?? 0;
  double get mod => double.tryParse(modCtrl.text) ?? 0;
  double get returned => mfg + handling + mod;
  bool get splitOk => (accepted + returned - batch).abs() <= 0.0005;

  void applyQuick(String kind) {
    final b = batch;
    acceptedCtrl.text = kind == 'accepted' ? _fmt(b) : '0';
    mfgCtrl.text = kind == 'mfg' ? _fmt(b) : '0';
    handlingCtrl.text = kind == 'handling' ? _fmt(b) : '0';
    modCtrl.text = kind == 'mod' ? _fmt(b) : '0';
  }

  String get autoNote {
    if (noteCtrl.text.trim().isNotEmpty) return noteCtrl.text.trim();
    // Blazor: the returned slice description defaults to the disposition
    // name itself when the courier writes no note.
    final parts = <String>[
      if (mfg > 0) 'عيب تصنيع',
      if (handling > 0) 'تلف مناولة',
      if (mod > 0) 'العميل طلب تعديل إضافي',
    ];
    return parts.join('، ');
  }

  Map<String, dynamic> toItem({required bool canSeeAmounts}) {
    return {
      'transactionDetailId': detailId,
      'quantity': batch,
      'acceptedQty': accepted,
      'returnedManufacturingQty': mfg,
      'returnedHandlingQty': handling,
      'returnedModificationQty': mod,
      'dispositionNotes': returned > 0 ? autoNote : (noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()),
      'agreedModificationPrice': (mod > 0 && canSeeAmounts)
          ? double.tryParse(priceCtrl.text)
          : null,
      'maintenanceId': maintenanceId,
    };
  }

  void dispose() {
    batchCtrl.dispose();
    acceptedCtrl.dispose();
    mfgCtrl.dispose();
    handlingCtrl.dispose();
    modCtrl.dispose();
    noteCtrl.dispose();
    priceCtrl.dispose();
  }
}

String _newEventGuid() {
  final r = Random();
  String hex(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
}

/// Shows the record-delivery dialog. Returns true when an event was saved.
Future<bool> showRecordDeliveryDialog(
  BuildContext context, {
  required int transactionId,
  required List<Map<String, dynamic>> products,
  required List<Map<String, dynamic>> employees,
  required bool canSeeAmounts,
  required bool canEditFull,
  required bool canOverrideRemaining,
  required bool permissionGranted,
  int? initialEmployeeId,
}) async {
  final service = DeliveryService();
  final lines = <RecordDeliveryLineInput>[];
  for (final p in products) {
    final remaining = (p['RemainingQty'] is num)
        ? (p['RemainingQty'] as num).toDouble()
        : double.tryParse('${p['RemainingQty'] ?? ''}') ??
            ((p['Quantity'] is num) ? (p['Quantity'] as num).toDouble() : 0);
    if (remaining <= 0.0005) continue;
    final detailId = (p['DetailID'] is num)
        ? (p['DetailID'] as num).toInt()
        : int.tryParse('${p['DetailID'] ?? ''}') ?? 0;
    if (detailId <= 0) continue;
    lines.add(RecordDeliveryLineInput(
      detailId: detailId,
      productName: '${p['ProductName'] ?? '—'}',
      remainingQty: remaining,
    ));
  }

  int? employeeId = initialEmployeeId;
  final notesCtrl = TextEditingController();
  Map<String, dynamic>? coverage;
  bool coverageLoading = false;
  bool requesting = false;
  bool permissionPending = false;
  Timer? debounce;
  final eventGuid = _newEventGuid();

  List<Map<String, dynamic>> currentItems(bool forSave) => lines
      .where((l) => l.selected && l.batch > 0)
      .map((l) => l.toItem(canSeeAmounts: canSeeAmounts))
      .toList();

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setState) {
        Future<void> refreshCoverage() async {
          final items = currentItems(false);
          if (items.isEmpty) {
            setState(() => coverage = null);
            return;
          }
          setState(() => coverageLoading = true);
          try {
            final data = await service.getCoverage(
                id: transactionId, items: items);
            if (dialogContext.mounted) {
              setState(() {
                coverage = data;
                coverageLoading = false;
              });
            }
          } catch (_) {
            if (dialogContext.mounted) {
              setState(() => coverageLoading = false);
            }
          }
        }

        void scheduleCoverage() {
          debounce?.cancel();
          debounce = Timer(
              const Duration(milliseconds: 450), refreshCoverage);
        }

        final selectedLines =
            lines.where((l) => l.selected).toList();
        final splitInvalid =
            selectedLines.any((l) => !l.splitOk || l.batch <= 0);
        final requiresPermission = coverage != null &&
            coverage!['RequiresPermission'] == true;
        final blocked = requiresPermission &&
            !canOverrideRemaining &&
            !permissionGranted &&
            !permissionPending;
        final canSave =
            selectedLines.isNotEmpty && !splitInvalid && !blocked;

        Widget coverageBanner() {
          if (coverageLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: LinearProgressIndicator(minHeight: 3),
            );
          }
          if (coverage == null) return const SizedBox.shrink();
          final covered = coverage!['Covered'] == true;
          final color = covered
              ? AppColors.success
              : (canOverrideRemaining || permissionGranted)
                  ? AppColors.warning
                  : AppColors.error;
          final message = '${coverage!['Message'] ?? ''}';
          return Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                        covered
                            ? Icons.verified_rounded
                            : Icons.warning_amber_rounded,
                        size: 17,
                        color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        covered
                            ? 'تغطية الدفعة مكتملة'
                            : 'تغطية الدفعة غير مكتملة',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: color),
                      ),
                    ),
                  ]),
                  if (message.isNotEmpty)
                    Text(message,
                        style: GoogleFonts.cairo(
                            fontSize: 10.5, height: 1.5)),
                  if (canSeeAmounts &&
                      coverage!['ThisBatchValue'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'المدفوع: ${NumberFormat('#,##0.00').format((coverage!['PaidAmount'] as num?)?.toDouble() ?? 0)} ج.م — '
                      'مسلّم سابقًا: ${NumberFormat('#,##0.00').format((coverage!['PreviousDeliveredValue'] as num?)?.toDouble() ?? 0)} ج.م — '
                      'هذه الدفعة: ${NumberFormat('#,##0.00').format((coverage!['ThisBatchValue'] as num?)?.toDouble() ?? 0)} ج.م',
                      style: GoogleFonts.cairo(fontSize: 10),
                    ),
                  ],
                  if (requiresPermission &&
                      !canOverrideRemaining &&
                      !permissionGranted) ...[
                    const SizedBox(height: 8),
                    if (permissionPending)
                      Text('طلب الإذن معلّق لدى الإدارة',
                          style: GoogleFonts.cairo(
                              fontSize: 11, color: AppColors.warning))
                    else
                      OutlinedButton.icon(
                        onPressed: requesting
                            ? null
                            : () async {
                                setState(() => requesting = true);
                                try {
                                  await service
                                      .requestPermission(transactionId);
                                  setState(() {
                                    permissionPending = true;
                                    requesting = false;
                                  });
                                } catch (e) {
                                  setState(() => requesting = false);
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext)
                                        .showSnackBar(SnackBar(
                                            content: Text('$e',
                                                style:
                                                    GoogleFonts.cairo())));
                                  }
                                }
                              },
                        icon: const Icon(Icons.approval_rounded, size: 16),
                        label: Text('إرسال طلب إذن تسليم',
                            style: GoogleFonts.cairo(fontSize: 11)),
                      ),
                  ],
                ]),
          );
        }

        Widget qtyField(TextEditingController ctrl, String label) =>
            SizedBox(
              width: 74,
              child: TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.cairo(fontSize: 12),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: GoogleFonts.cairo(fontSize: 9),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) {
                  setState(() {});
                  scheduleCoverage();
                },
              ),
            );

        return AlertDialog(
          title: Text('تسجيل تسليمة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lines.isEmpty)
                      Text('لا توجد كميات متاحة للتسليم الآن',
                          style: GoogleFonts.cairo())
                    else
                      for (final line in lines) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Checkbox(
                                    value: line.selected,
                                    onChanged: (v) {
                                      setState(() =>
                                          line.selected = v ?? false);
                                      scheduleCoverage();
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${line.productName} — متبقٍّ ${RecordDeliveryLineInput._fmt(line.remainingQty)}',
                                      style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12),
                                    ),
                                  ),
                                ]),
                                if (line.selected) ...[
                                  Wrap(spacing: 6, runSpacing: 6, children: [
                                    qtyField(line.batchCtrl, 'كمية الدفعة'),
                                    qtyField(line.acceptedCtrl, 'سليم'),
                                    qtyField(line.mfgCtrl, 'عيب تصنيع'),
                                    qtyField(
                                        line.handlingCtrl, 'تلف مناولة'),
                                    qtyField(line.modCtrl, 'تعديل عميل'),
                                  ]),
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 6, children: [
                                    for (final entry in const [
                                      ('accepted', 'سليم — بدون ملاحظات'),
                                      ('mfg', 'عيب تصنيع'),
                                      ('handling', 'تلف مناولة'),
                                      ('mod', 'تعديل إضافي'),
                                    ])
                                      ActionChip(
                                        label: Text(entry.$2,
                                            style: GoogleFonts.cairo(
                                                fontSize: 10)),
                                        onPressed: () {
                                          setState(() =>
                                              line.applyQuick(entry.$1));
                                          scheduleCoverage();
                                        },
                                      ),
                                  ]),
                                  if (!line.splitOk)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'مجموع التصنيفات يجب أن يساوي كمية الدفعة',
                                        style: GoogleFonts.cairo(
                                            fontSize: 10,
                                            color: AppColors.error),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: line.noteCtrl,
                                    style: GoogleFonts.cairo(fontSize: 12),
                                    decoration: InputDecoration(
                                      labelText: 'ملاحظة البند (اختيارية)',
                                      labelStyle:
                                          GoogleFonts.cairo(fontSize: 10),
                                      isDense: true,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                  if (line.mod > 0 && canSeeAmounts) ...[
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: line.priceCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style: GoogleFonts.cairo(fontSize: 12),
                                      decoration: InputDecoration(
                                        labelText:
                                            'السعر المتفق عليه للتعديل (ج.م)',
                                        labelStyle:
                                            GoogleFonts.cairo(fontSize: 10),
                                        isDense: true,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ],
                              ]),
                        ),
                      ],
                    coverageBanner(),
                    const SizedBox(height: 10),
                    if (canEditFull && employees.isNotEmpty) ...[
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
                              child: Text('المستخدم الحالي',
                                  style: GoogleFonts.cairo())),
                          ...employees.map((e) => DropdownMenuItem<int?>(
                                value: (e['EmployeeID'] is num)
                                    ? (e['EmployeeID'] as num).toInt()
                                    : int.tryParse('${e['EmployeeID'] ?? ''}'),
                                child: Text('${e['FullName'] ?? ''}',
                                    style: GoogleFonts.cairo()),
                              )),
                        ],
                        onChanged: (v) => setState(() => employeeId = v),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      style: GoogleFonts.cairo(),
                      decoration: InputDecoration(
                        labelText: 'ملاحظات التسليم',
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
            FilledButton.icon(
              onPressed: canSave
                  ? () async {
                      try {
                        final res = await service.recordEvent(
                          id: transactionId,
                          items: currentItems(true),
                          deliveryEmployeeId: employeeId,
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                          eventGuid: eventGuid,
                        );
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                                content: Text(
                                    '${res['message'] ?? 'تم تسجيل التسليمة'}',
                                    style: GoogleFonts.cairo())),
                          );
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                                content:
                                    Text('$e', style: GoogleFonts.cairo()),
                                backgroundColor: AppColors.error),
                          );
                        }
                      }
                    }
                  : null,
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text('حفظ التسليمة', style: GoogleFonts.cairo()),
            ),
          ],
        );
      },
    ),
  );
  debounce?.cancel();
  for (final l in lines) {
    l.dispose();
  }
  notesCtrl.dispose();
  return result == true;
}
