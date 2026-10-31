import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../constants.dart';
import '../../features/home/widgets/home_accent.dart';
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../widgets/design_kit.dart';
import '../../services/permission_service.dart';
import '../general_tasks_screen.dart';
import '../../services/invoice_service.dart';
import '../../services/payment_service.dart';
import '../payments_screen.dart';
import '../../services/cashbox_service.dart';
import '../../core/network/api_client.dart';
import 'add_invoice_screen.dart';
import 'invoice_edit_history_sheet.dart';

/// تفاصيل فاتورة مبيعات - نسخة محسنة UI + PDF آمن
class InvoiceDetailsScreen extends StatefulWidget {
  final int transactionId;
  final String username;
  final String invoiceType; // 'Sale' أو 'Purchase'

  const InvoiceDetailsScreen({
    super.key,
    required this.transactionId,
    required this.username,
    this.invoiceType = 'Sale',
  });

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _pdfGenerating = false;

  final PermissionService _perms = PermissionService();

  // قدرة الإلغاء: ادعاء الإلغاء المخصص في بلازور الحالي
  // (frm_PartiesInvoices:Cancel) أو Admin — ادعاء الحذف لم يعد يكفي،
  // وقدرة الخادم من نموذج التعديل تحمل الحكم نفسه.
  bool _canCancelFromServer = false;
  bool get _canCancelInvoice =>
      _canCancelFromServer ||
      _perms.isAdmin ||
      (_perms.getPermission('frm_PartiesInvoices:Cancel')?.canView == true);

  // بوابات إجراءات دفعات هذه الفاتورة — مرآة payments.canEdit/canDelete
  bool _canEditPaymentRow(bool purchase) =>
      _perms.isAdmin ||
      _perms.canEdit(FormNames.payments) ||
      _perms.isAccountManager ||
      _perms.isAccount ||
      (!purchase && _perms.isSales);
  bool get _canDeletePaymentRow =>
      _perms.isAdmin || _perms.canDelete(FormNames.payments);
  bool get _canViewPaymentsList =>
      _perms.isAdmin || _perms.canView(FormNames.payments);

  bool get _isAdminOrAccountMgr => _perms.canFullEditInvoices;
  bool get _canApprove => _perms.canApproveInvoiceEdit;
  // طلب التعديل في المرجع الحالي لفاتورة البيع فقط؛ الشراء له مسار تشغيل مستقل.
  bool get _canRequestEdit => !isPurchase && _perms.canViewSalesInvoices;
  bool get _canViewHistory => _perms.canViewInvoiceHistory;
  bool get _canViewProfit => _perms.canViewInvoiceProfit;

  bool get isPurchase =>
      (_data?['header']?['TransactionType']?.toString() ?? widget.invoiceType) ==
      'Purchase';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await InvoiceService.instance.getFull(widget.transactionId);
      // قدرات الخادم (منها canCancel) — فشلها لا يمنع عرض التفاصيل
      var canCancel = false;
      try {
        final model =
            await InvoiceService.instance.getEditModel(widget.transactionId);
        final caps = model['capabilities'];
        if (caps is Map) canCancel = caps['canCancel'] == true;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _data = data;
        _canCancelFromServer = canCancel;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'فشل الاتصال بالخادم';
        _loading = false;
      });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return NumberFormat(
      '#,##0.00',
    ).format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  String _fmt0(dynamic v) {
    if (v == null) return '0';
    return NumberFormat(
      '#,##0',
    ).format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  String _date(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  String _cust(dynamic v) => (v ?? '').toString().trim();
  num _numOf(dynamic v) =>
      v is num ? v : double.tryParse(v?.toString() ?? '') ?? 0;

  // ──────────── طلبات التعديل ────────────────
  Future<void> _requestEdit() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب تعديل الفاتورة'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'سبب التعديل *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = reasonCtrl.text.trim();
              if (value.isNotEmpty) Navigator.pop(ctx, value);
            },
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || !mounted) return;
    try {
      await InvoiceService.instance.requestEdit(widget.transactionId, reason);
      _showMsg('تم إرسال طلب التعديل وتوجيه الإشعار للمسؤول', true);
      await _load();
    } on ApiException catch (e) {
      _showMsg(e.message, false);
    }
  }

  Future<void> _approveEdit() async {
    final ok = await _confirm(
      'الموافقة على التعديل',
      'هل توافق على طلب تعديل هذه الفاتورة؟',
      'موافقة',
      AppColors.success,
    );
    if (ok != true || !mounted) return;
    try {
      await InvoiceService.instance.approveEdit(widget.transactionId);
      _showMsg('تمت الموافقة وإرسال إشعار لصاحب الطلب', true);
      await _load();
    } on ApiException catch (e) {
      _showMsg(e.message, false);
    }
  }

  Future<void> _rejectEdit() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض طلب التعديل'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(ctx, value);
            },
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    try {
      await InvoiceService.instance.rejectEdit(widget.transactionId, reason);
      _showMsg('تم الرفض وإرسال إشعار لصاحب الطلب', true);
      await _load();
    } on ApiException catch (e) {
      _showMsg(e.message, false);
    }
  }

  Future<bool?> _confirm(
      String title, String message, String actionLabel, Color color) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _applyDiscount() async {
    final header = _data?['header'] ?? {};
    final discPctCtrl = TextEditingController(
        text: header['DiscountPercentage']?.toString() ?? '');
    final discAmtCtrl = TextEditingController(
        text: header['DiscountAmount']?.toString() ?? '');

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة خصم على الفاتورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: discPctCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الخصم بالنسبة (%)',
                prefixText: '% ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: discAmtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الخصم بالقيمة — تُقرب لأقرب 100',
                prefixText: 'ج.م ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HomeAccent.accent,
              foregroundColor: AppColors.navy,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تطبيق الخصم'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;

    double? discAmt;
    if (discAmtCtrl.text.trim().isNotEmpty) {
      discAmt = (double.tryParse(discAmtCtrl.text.trim()) ?? 0);
      discAmt = (discAmt / 100).round() * 100;
    }
    double? discPct;
    if (discPctCtrl.text.trim().isNotEmpty) {
      discPct = double.tryParse(discPctCtrl.text.trim());
    }
    if (discAmt == null && discPct == null) {
      _showMsg('أدخل قيمة أو نسبة الخصم', false);
      return;
    }
    try {
      await InvoiceService.instance.applyEdit(widget.transactionId, {
        'discountPercentage': discPct,
        'discountAmount': discAmt,
      });
      _showMsg('تم تطبيق الخصم', true);
      await _load();
    } on ApiException catch (e) {
      _showMsg(e.message, false);
    }
  }

  Future<void> _applyEdit() async {
    final header = _data?['header'] ?? {};
    final dueCtrl = TextEditingController(
      text: header['DueDate'] != null ? _date(header['DueDate']) : '',
    );
    final discPctCtrl = TextEditingController(
        text: header['DiscountPercentage']?.toString() ?? '');
    final discAmtCtrl = TextEditingController(
        text: header['DiscountAmount']?.toString() ?? '');
    DateTime? pickedDueDate;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الفاتورة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dueCtrl,
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    pickedDueDate = picked;
                    dueCtrl.text = DateFormat('yyyy/MM/dd').format(picked);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'تاريخ التسليم',
                  suffixIcon: Icon(Icons.calendar_today_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discPctCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الخصم (%)',
                  prefixText: '% ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discAmtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الخصم (قيمة) — تُقرب لأقرب 100',
                  prefixText: 'ج.م ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HomeAccent.accent,
              foregroundColor: AppColors.navy,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;

    double? discAmt;
    if (discAmtCtrl.text.trim().isNotEmpty) {
      discAmt = (double.tryParse(discAmtCtrl.text.trim()) ?? 0);
      discAmt = (discAmt / 100).round() * 100;
    }
    double? discPct;
    if (discPctCtrl.text.trim().isNotEmpty) {
      discPct = double.tryParse(discPctCtrl.text.trim());
    }

    try {
      await InvoiceService.instance.applyEdit(widget.transactionId, {
        'dueDate': pickedDueDate?.toIso8601String(),
        'discountPercentage': discPct,
        'discountAmount': discAmt,
      });
      _showMsg('تم التعديل', true);
      await _load();
    } on ApiException catch (e) {
      _showMsg(e.message, false);
    }
  }

  Future<void> _editDetailPrice(Map<String, dynamic> detail) async {
    final priceCtrl = TextEditingController(
        text: (detail['UnitPrice'] ?? 0).toString());
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل سعر الصنف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail['ProductName'] ?? '',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              'الكمية: ${detail['Quantity']} — الحالي: ${_fmt(detail['UnitPrice'])}',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر الجديد',
                prefixText: 'ج.م ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HomeAccent.accent,
              foregroundColor: AppColors.navy,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    final newPrice = double.tryParse(priceCtrl.text.trim());
    if (newPrice == null) {
      _showMsg('سعر غير صالح', false);
      return;
    }
    try {
      await InvoiceService.instance.updateDetailPrice(
        widget.transactionId,
        detail['DetailID'],
        newPrice,
        reason: 'تعديل سعر صنف من تفاصيل الفاتورة',
      );
      _showMsg('تم تعديل السعر وإعادة حساب الإجماليات', true);
      await _load();
    } on ApiException catch (e) {
      _showMsg(e.message, false);
    }
  }

  Future<void> _openInvoiceEdit() async {
    final userId = _perms.userId ?? 0;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddInvoiceScreen(
          userId: userId,
          username: widget.username,
          invoiceId: widget.transactionId,
          initialType: isPurchase ? 'Purchase' : 'Sale',
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _openEditHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvoiceEditHistorySheet(
        transactionId: widget.transactionId,
        onRestored: _load,
      ),
    );
  }

  // ═════════════════ PDF - نسخة آمنة ومستقرة ═════════════════
  Future<pw.Font> _safeLoadFont(String path, {bool bold = false}) async {
    try {
      final data = await rootBundle.load(path);
      return pw.Font.ttf(data);
    } catch (_) {
      return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
    }
  }

  Future<pw.MemoryImage?> _safeLoadBg() async {
    try {
      final bgBytes =
          await rootBundle.load('assets/images/design-background.png');
      return pw.MemoryImage(Uint8List.view(
          bgBytes.buffer, bgBytes.offsetInBytes, bgBytes.lengthInBytes));
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _generatePdf() async {
    final header = _data?['header'] ?? {};
    final details = (_data?['details'] as List?) ?? [];
    final charges = (_data?['charges'] as List?) ?? [];

    final regularFont = await _safeLoadFont('assets/fonts/Cairo-Regular.ttf');
    final boldFont =
        await _safeLoadFont('assets/fonts/Cairo-Bold.ttf', bold: true);
    final bgImage = await _safeLoadBg();

    final productImages = <int, pw.MemoryImage>{};
    for (final d in details) {
      final pid = d['ProductID'];
      if (pid == null) continue;
      try {
        final res = await http
            .get(Uri.parse('$baseUrl/api/product-images/$pid'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          productImages[pid] = pw.MemoryImage(res.bodyBytes);
        }
      } catch (_) {}
    }

    final pages = <List<dynamic>>[];
    if (details.isNotEmpty) {
      pages.add(details.take(5).toList());
      var remaining = details.skip(5).toList();
      while (remaining.isNotEmpty) {
        pages.add(remaining.take(7).toList());
        remaining = remaining.skip(7).toList();
      }
    }

    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);
    final pdf = pw.Document();
    final typeLabel = isPurchase ? 'فاتورة مشتريات' : 'فاتورة مبيعات';

    for (var p = 0; p < pages.length; p++) {
      final isFirst = p == 0;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          theme: theme,
          build: (_) => _pdfPageScaffold(
            bgImage,
            meta: isFirst
                ? _pdfMetaBox(header,
                    typeText: typeLabel, typeColor: _pdfNavy)
                : const [],
            content: [
              if (isFirst) ...[
                _pdfPartyGrid(header),
                pw.SizedBox(height: 18),
              ],
              _pdfItemsTable(
                pages[p],
                productImages,
                startIndex: isFirst ? 1 : 6 + (p - 1) * 7,
              ),
            ],
          ),
        ),
      );
    }

    if (pages.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          theme: theme,
          build: (_) => _pdfPageScaffold(
            bgImage,
            meta: _pdfMetaBox(header,
                typeText: typeLabel, typeColor: _pdfNavy),
            content: [
              _pdfPartyGrid(header),
              pw.SizedBox(height: 18),
              pw.Text('لا توجد أصناف',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        theme: theme,
        build: (_) => _pdfSummaryContent(header, charges, bgImage),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        theme: theme,
        build: (_) => _pdfTermsContent(header, bgImage),
      ),
    );

    return pdf.save();
  }

  static final PdfColor _pdfNavy = PdfColor.fromInt(0xFF1A2842);
  static final PdfColor _pdfGold = PdfColor.fromInt(0xFFD4AF37);
  static final PdfColor _pdfGoldSoft = PdfColor.fromInt(0xFFF3E9C9);
  static final PdfColor _pdfAmber = PdfColor.fromInt(0xFFB8860B);
  static final PdfColor _pdfCream = PdfColor.fromInt(0xFFFAF6E8);
  static final PdfColor _pdfDd = PdfColor.fromInt(0xFFDDDDDD);
  static final PdfColor _pdfEe = PdfColor.fromInt(0xFFEEEEEE);
  static final PdfColor _pdfRed = PdfColor.fromInt(0xFFC62828);
  static final PdfColor _pdfHighlightRed = PdfColor.fromInt(0xFFDC1E0C);
  static final PdfColor _pdfGreen = PdfColor.fromInt(0xFF2E7D32);
  static final PdfColor _pdfRemainingBg = PdfColor.fromInt(0xFFFFF5F5);

  pw.Widget _pdfPageScaffold(
    pw.MemoryImage? bg, {
    List<pw.Widget> meta = const [],
    required List<pw.Widget> content,
    bool centerContent = false,
  }) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Stack(
        children: [
          if (bg != null)
            pw.Positioned.fill(child: pw.Image(bg, fit: pw.BoxFit.cover))
          else
            pw.Positioned.fill(
                child: pw.Container(color: PdfColors.white)),
          ...meta,
          pw.Positioned(
            left: 34,
            right: 34,
            top: 119,
            bottom: 108,
            child: pw.Column(
              mainAxisAlignment: centerContent
                  ? pw.MainAxisAlignment.center
                  : pw.MainAxisAlignment.start,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: content,
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _pdfMetaBox(Map<String, dynamic> header,
      {required String typeText, required PdfColor typeColor}) {
    return [
      pw.Positioned(
        top: 39.7,
        left: 39.7,
        right: 408.2,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(typeText,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    color: typeColor)),
            pw.SizedBox(height: 3),
            pw.Text(
                header['ReferenceNumber']?.toString() ??
                    '#${header['TransactionID'] ?? ''}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800)),
            pw.SizedBox(height: 2),
            pw.Text(_date(header['TransactionDate']),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600)),
          ],
        ),
      ),
    ];
  }

  pw.Widget _pdfPartyBox(String title, List<pw.Widget> lines) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _pdfCream,
        border: pw.Border.all(color: _pdfGoldSoft, width: 1),
        borderRadius: pw.BorderRadius.circular(7.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.only(bottom: 4),
            decoration: pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: _pdfGoldSoft, width: 1))),
            child: pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfNavy)),
          ),
          pw.SizedBox(height: 6),
          ...lines,
        ],
      ),
    );
  }

  pw.Widget _pdfPartyLine(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2.5),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                  text: '$label ',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
              pw.TextSpan(text: value, style: pw.TextStyle(fontSize: 9.5)),
            ],
          ),
        ),
      );

  pw.Widget _pdfPartyGrid(Map<String, dynamic> header) {
    final typeLabel = isPurchase ? 'فاتورة مشتريات' : 'فاتورة مبيعات';
    final phone = _cust(header['Phone'] ?? header['CustomerPhone']);
    final email = _cust(header['Email'] ?? header['CustomerEmail']);
    final address = _cust(header['Address'] ?? header['CustomerAddress']);
    final empName = _cust(header['EmployeeName']);

    final clientBox = _pdfPartyBox(
      isPurchase ? 'المورد / العميل' : 'العميل',
      isPurchase
          ? [
              _pdfPartyLine('المورد:', 'المصنع'),
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 6),
                padding: const pw.EdgeInsets.only(top: 6),
                decoration: const pw.BoxDecoration(
                    border: pw.Border(
                        top: pw.BorderSide(
                            color: PdfColor.fromInt(0xFFCCCCCC),
                            width: 0.75))),
                child:
                    _pdfPartyLine('العميل:', empName.isEmpty ? '-' : empName),
              ),
            ]
          : [
              _pdfPartyLine('الاسم:', header['PartyName']?.toString() ?? '-'),
              if (phone.isNotEmpty) _pdfPartyLine('الهاتف:', phone),
              if (email.isNotEmpty) _pdfPartyLine('البريد:', email),
              if (address.isNotEmpty) _pdfPartyLine('العنوان:', address),
            ],
    );

    final detailsBox = _pdfPartyBox(
      'تفاصيل الفاتورة',
      [
        pw.Row(children: [
          pw.Text(header['ReferenceNumber']?.toString() ?? '',
              style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _pdfAmber)),
          pw.SizedBox(width: 4),
          pw.Text('-', style: pw.TextStyle(fontSize: 9.5)),
          pw.SizedBox(width: 4),
          pw.Text(typeLabel,
              style: pw.TextStyle(
                  fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
        ]),
        _pdfPartyLine('تاريخ التعاقد:', _date(header['TransactionDate'])),
        if (header['DueDate'] != null)
          _pdfPartyLine('تاريخ الاستلام:', _date(header['DueDate'])),
        if (empName.isNotEmpty)
          _pdfPartyLine('المهندس المسئول:', empName),
        pw.Row(children: [
          _pdfStatusBadge(header['InvoiceStatus']?.toString()),
          pw.SizedBox(width: 5),
          pw.Text('الحالة:',
              style: pw.TextStyle(
                  fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
        ]),
      ],
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: detailsBox),
        pw.SizedBox(width: 12),
        pw.Expanded(child: clientBox),
      ],
    );
  }

  pw.Widget _pdfStatusBadge(String? status) {
    final s = status?.toString().toLowerCase() ?? 'open';
    PdfColor bg, fg;
    switch (s) {
      case 'paid':
        bg = PdfColor.fromInt(0xFFD4EDDA);
        fg = PdfColor.fromInt(0xFF155724);
        break;
      case 'partiallypaid':
        bg = PdfColor.fromInt(0xFFFFF3CD);
        fg = PdfColor.fromInt(0xFF856404);
        break;
      case 'cancelled':
        bg = PdfColor.fromInt(0xFFF8D7DA);
        fg = PdfColor.fromInt(0xFF721C24);
        break;
      default:
        bg = PdfColor.fromInt(0xFFD1ECF1);
        fg = PdfColor.fromInt(0xFF0C5460);
    }
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration:
          pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Text(_statusText(status),
          style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: fg)),
    );
  }

  pw.Widget _pdfItemsTable(
      List<dynamic> items, Map<int, pw.MemoryImage> images,
      {required int startIndex}) {
    return pw.Table(
      border: pw.TableBorder.all(color: _pdfDd, width: 0.75),
      columnWidths: {
        0: const pw.FixedColumnWidth(75),
        1: const pw.FixedColumnWidth(67.5),
        2: const pw.FixedColumnWidth(52.5),
        3: const pw.FlexColumnWidth(),
        4: const pw.FixedColumnWidth(86.25),
        5: const pw.FixedColumnWidth(30),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _pdfNavy),
          children: [
            _pdfTh('الإجمالي'),
            _pdfTh('السعر'),
            _pdfTh('الكمية'),
            _pdfTh('الوصف'),
            _pdfTh('صورة القطعة'),
            _pdfTh('#'),
          ],
        ),
        for (var i = 0; i < items.length; i++)
          pw.TableRow(
            decoration: i.isOdd
                ? const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFAFAFA))
                : null,
            children: [
              pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(_fmt(items[i]['TotalAmount']),
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(_fmt(items[i]['UnitPrice']),
                      style: pw.TextStyle(fontSize: 10))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.center,
                  child: pw.Text(_fmt0(items[i]['Quantity']),
                      style: pw.TextStyle(fontSize: 10))),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text((items[i]['ProductName'] ?? '').toString(),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold)),
                      if ((items[i]['ProductDescription'] ?? '')
                          .toString()
                          .isNotEmpty)
                        pw.Text(
                            (items[i]['ProductDescription'] ?? '').toString(),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 7.5, color: PdfColors.grey700)),
                    ]),
              ),
              pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  alignment: pw.Alignment.center,
                  child: _pdfProductImageCell(images[items[i]['ProductID']])),
              pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.center,
                  child: pw.Text('${startIndex + i}',
                      style: pw.TextStyle(fontSize: 10))),
            ],
          ),
      ],
    );
  }

  pw.Widget _pdfTh(String text) => pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)));

  pw.Widget _pdfProductImageCell(pw.MemoryImage? image) {
    return pw.Container(
      width: 75,
      height: 75,
      decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF5F5F5),
          border: pw.Border.all(color: _pdfDd, width: 0.75),
          borderRadius: pw.BorderRadius.circular(4.5)),
      child: image != null
          ? pw.ClipRRect(
              horizontalRadius: 4.5,
              verticalRadius: 4.5,
              child:
                  pw.Image(image, width: 75, height: 75, fit: pw.BoxFit.cover))
          : pw.Center(
              child: pw.Text('بدون صورة',
                  style: pw.TextStyle(
                      fontSize: 7.5, color: PdfColors.grey500))),
    );
  }

  pw.Widget _pdfChargesTable(List<dynamic> charges) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                  color: _pdfGold,
                  border: pw.Border.all(color: _pdfDd, width: 0.75)),
              child: pw.Text('رسوم إضافية',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white))),
          pw.Table(
            border: pw.TableBorder.all(color: _pdfDd, width: 0.75),
            columnWidths: {
              0: const pw.FlexColumnWidth(),
              1: const pw.FixedColumnWidth(97.5),
            },
            children: [
              pw.TableRow(
                  decoration: pw.BoxDecoration(color: _pdfNavy),
                  children: [_pdfTh('المبلغ'), _pdfTh('الوصف')]),
              for (final ch in charges)
                pw.TableRow(children: [
                  pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(_fmt(ch['ChargeAmount']),
                          style: pw.TextStyle(fontSize: 10))),
                  pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text((ch['ChargeDescription'] ?? '').toString(),
                          style: pw.TextStyle(fontSize: 10))),
                ]),
            ],
          ),
        ]);
  }

  pw.Widget _pdfSummaryContent(
      Map<String, dynamic> header, List<dynamic> charges, pw.MemoryImage? bg) {
    final discount = (header['DiscountAmount'] ?? 0) > 0;
    final extraCharges = (header['TotalChargesAmount'] ?? 0) > 0;
    final notes = _cust(header['Notes']);
    return _pdfPageScaffold(bg, centerContent: true, content: [
      pw.Column(children: [
        pw.Text('الملخص المالي',
            style: pw.TextStyle(
                fontSize: 21,
                fontWeight: pw.FontWeight.bold,
                color: _pdfNavy)),
        pw.SizedBox(height: 6),
        pw.Text(
            header['ReferenceNumber']?.toString() ??
                '#${header['TransactionID'] ?? ''}',
            style: pw.TextStyle(
                fontSize: 13, color: _pdfAmber, fontWeight: pw.FontWeight.bold)),
      ]),
      pw.SizedBox(height: 12),
      pw.Container(height: 1.2, color: _pdfGold),
      pw.SizedBox(height: 1.5),
      pw.Container(height: 1.2, color: _pdfGold),
      pw.SizedBox(height: 22),
      if (charges.isNotEmpty) ...[
        _pdfChargesTable(charges),
        pw.SizedBox(height: 16),
      ],
      _pdfWidth80(pw.Column(children: [
        _pdfSumRow('إجمالي الأصناف:', '${_fmt(header['TotalAmount'])} ج'),
        if (discount)
          _pdfSumRow('الخصم:', '-${_fmt(header['DiscountAmount'])} ج',
              valueColor: _pdfRed),
        _pdfSumRow('الصافي:', '${_fmt(header['NetTotalAmount'])} ج'),
        if (extraCharges)
          _pdfSumRow('رسوم إضافية:',
              '+${_fmt(header['TotalChargesAmount'])} ج'),
        _pdfSumRow('الإجمالي النهائي:', '${_fmt(header['GrandTotal'])} ج',
            bold: true, fontSize: 12.5, totalStyle: true),
        _pdfSumRow('المدفوع:', '${_fmt(header['PaidAmount'])} ج',
            valueColor: _pdfGreen),
        _pdfSumRow('المتبقي:', '${_fmt(_remaining(header))} ج',
            bold: true, valueColor: _pdfRed, remainingStyle: true),
      ])),
      if (notes.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFFAFAFA),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _pdfDd, width: 0.6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(width: 3.5, color: _pdfGold),
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(9.6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ملاحظات:',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(notes,
                          style: pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      pw.SizedBox(height: 24),
      _pdfWidth80(pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            _pdfSignatureBox('توقيع العميل', header['PartyName']?.toString()),
            _pdfSignatureBox(
                'توقيع الموظف', header['EmployeeName']?.toString()),
          ])),
    ]);
  }

  pw.Widget _pdfSumRow(String label, String value,
      {bool bold = false,
      PdfColor? valueColor,
      double fontSize = 11,
      bool totalStyle = false,
      bool remainingStyle = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: pw.BoxDecoration(
          color: totalStyle
              ? _pdfCream
              : remainingStyle
                  ? _pdfRemainingBg
                  : null,
          border: totalStyle
              ? pw.Border(
                  top: pw.BorderSide(color: _pdfGold, width: 1.5),
                  bottom: pw.BorderSide(color: _pdfGold, width: 1.5))
              : pw.Border(
                  bottom: pw.BorderSide(color: _pdfEe, width: 0.75))),
      child: pw.Row(children: [
        pw.Expanded(
            child: pw.Text(value,
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight: pw.FontWeight.bold,
                    color: valueColor ?? PdfColors.black))),
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]),
    );
  }

  pw.Widget _pdfTermsContent(Map<String, dynamic> header, pw.MemoryImage? bg) {
    return _pdfPageScaffold(
      bg,
      meta: _pdfMetaBox(header, typeText: 'شروط وأحكام', typeColor: _pdfRed),
      content: [
        pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: pw.BoxDecoration(
                border: pw.Border(
                    bottom: pw.BorderSide(color: _pdfGold, width: 1.5))),
            child: pw.Text('شروط وأحكام التعاقد',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfNavy))),
        pw.SizedBox(height: 12),
        for (final t in _pdfTermsList)
          pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                        child: pw.RichText(
                            text: pw.TextSpan(
                                style: pw.TextStyle(fontSize: 10),
                                children: _pdfHighlightSpans(t)),
                            textAlign: pw.TextAlign.justify)),
                    pw.Text('• ',
                        style: pw.TextStyle(
                            fontSize: 10.5,
                            fontWeight: pw.FontWeight.bold,
                            color: _pdfNavy)),
                  ])),
        pw.SizedBox(height: 14),
        pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: _pdfCream,
                border: pw.Border.all(color: _pdfDd, width: 0.75),
                borderRadius: pw.BorderRadius.circular(7.5)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('شروط الدفعات',
                      style: pw.TextStyle(
                          fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  for (final p in const [
                    '70% مقدم تعاقد',
                    '20% بعد صورة النجار',
                    '10% قبل التسليم',
                  ])
                    pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 3),
                        child: pw.RichText(
                            text: pw.TextSpan(
                                style: pw.TextStyle(fontSize: 10),
                                children: _pdfHighlightSpans(p)))),
                ])),
        pw.Spacer(),
        _pdfWidth80(pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _pdfSignatureBox('توقيع الشركة'),
              _pdfSignatureBox('توقيع العميل'),
            ])),
      ],
    );
  }

  pw.Widget _pdfWidth80(pw.Widget child) => pw.Row(children: [
        pw.Spacer(flex: 1),
        pw.Expanded(flex: 4, child: child),
        pw.Spacer(flex: 1),
      ]);

  pw.Widget _pdfSignatureBox(String label, [String? name]) {
    return pw.Column(children: [
      pw.Padding(
          padding: const pw.EdgeInsets.only(top: 30),
          child: pw.Container(width: 150, height: 1, color: PdfColors.grey800)),
      pw.SizedBox(height: 6),
      pw.Text(label,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      if (name != null && name.isNotEmpty)
        pw.Text(name,
            style: pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600)),
    ]);
  }

  static const List<String> _pdfHighlightTokens = [
    '5 سنوات',
    'يومان',
    '3 أيام',
    '50%',
    '4 أيام',
    '70%',
    '20%',
    '10%',
    '(01090707897)',
    '15 يوما',
    '7 أيام',
    'مرتين',
    '48 ساعة',
  ];

  List<pw.TextSpan> _pdfHighlightSpans(String text) {
    final spans = <pw.TextSpan>[];
    var rest = text;
    while (rest.isNotEmpty) {
      String? bestTok;
      var bestIdx = -1;
      for (final tok in _pdfHighlightTokens) {
        final i = rest.indexOf(tok);
        if (i != -1 && (bestIdx == -1 || i < bestIdx)) {
          bestIdx = i;
          bestTok = tok;
        }
      }
      if (bestTok == null) {
        spans.add(pw.TextSpan(text: rest));
        break;
      }
      if (bestIdx > 0) {
        spans.add(pw.TextSpan(text: rest.substring(0, bestIdx)));
      }
      spans.add(pw.TextSpan(
          text: bestTok,
          style: pw.TextStyle(
              color: _pdfHighlightRed, fontWeight: pw.FontWeight.bold)));
      rest = rest.substring(bestIdx + bestTok.length);
    }
    return spans;
  }

  static const List<String> _pdfTermsList = [
    'فترة الضمان تصل إلى 5 سنوات من تاريخ الاستلام ضد عيوب الصناعة و صيانة مدى الحياة.',
    'الأسعار غير شاملة تكاليف أي معدات و أدوات مناولة خاصة مثل (أوناش أو كلارك أو هاند ليفت ...الخ).',
    'يسقط الضمان بمجرد نقل المنتج من مكان إلى آخر أو إعادة الفك أو التركيب بمعرفة العميل.',
    'يحق للعميل إلغاء أو تعديل التعاقد فقط في خلال يومان من تاريخ التعاقد بدون أي خصومات.',
    'في حالة رغبة العميل في إلغاء التعاقد و ذلك بعد مرور 3 أيام يتم خصم 50% من قيمة البند أو إضافتها في حال التعديل.',
    'في حالة رغبة العميل في إلغاء التعاقد أو التعديل في بند محدد و ذلك بعد مرور 4 أيام أو أكثر يتم خصم كامل قيمة البند أو إضافته في حال التعديل.',
    'في حالة وجود عيب صناعة بالمنتج تقوم الشركة بإصلاح أو استبدال الجزء محل العيب فقط وليس كامل المنتج.',
    'يوقع العميل أو من ينوب عنه إذن استلام للمنتج بمجرد استلامه ومعاينته المعاينة التامة.',
    'لا يتم الاستلام إلا بعد سداد كامل القيمة و في حالة تأخير العميل في الاستلام يجب سداد المبلغ كاملا بمجرد الانتهاء من التشطيب.',
    'يتم احتساب مدة التعاقد من وقت سداد 70% من إجمالى قيمة التعاقد ولا يحق للعميل فسخ التعاقد واسترداد الدفعة المقدمة بعد البدء فى التنفيذ.',
    'تحديد موعد استلام أو خدمات ما بعد البيع يتم الاتصال على (01090707897) وذلك قبل 15 يوما على الأقل.',
    'يجوز للعميل تغيير موعد الاستلام المتفق عليه مسبقا وذلك قبل تاريخ الاستلام بـ 7 أيام على الأقل.',
    'تخلى الشركة مسئوليتها عن خدمة النقل والتركيب عند تغيير العميل لموعد الاستلام أكثر من مرتين أو قبل الاستلام بأقل من 48 ساعة.',
    'ملاءمة المنتج لموقع العميل من حيث المقاسات والذوق العام هو مسئولية العميل وحده فقط دون غيره حيث أن المنتجات تم تصنيعها خصيصا بناء على طلبه وبالمواصفات المحددة من قبله.',
    'بمجرد استلام العميل للمنتج لا يجوز استبدالها أو استرجاعها وإنما يسرى عليها شروط وأحكام الضمان وخدمة ما بعد البيع.',
  ];

  String _statusText(dynamic status) {
    switch (status?.toString()) {
      case 'Paid':
        return 'مدفوعة';
      case 'PartiallyPaid':
        return 'مدفوعة جزئياً';
      case 'Cancelled':
        return 'ملغاة';
      default:
        return 'مفتوحة';
    }
  }

  Future<void> _exportPdf() async {
    if (_pdfGenerating) return;
    setState(() => _pdfGenerating = true);
    try {
      _showMsg('جاري إنشاء PDF...', true);
      final bytes = await _generatePdf();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'invoice_${widget.transactionId}.pdf',
      );
    } catch (e, st) {
      debugPrint('PDF ERROR: $e\n$st');
      _showMsg('خطأ في إنشاء PDF: ${e.toString().split('\n').first}', false);
    } finally {
      if (mounted) setState(() => _pdfGenerating = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfGenerating) return;
    setState(() => _pdfGenerating = true);
    try {
      final bytes = await _generatePdf();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice_${widget.transactionId}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          subject: 'فاتورة #${widget.transactionId}');
    } catch (e, st) {
      debugPrint('SHARE PDF ERROR: $e\n$st');
      _showMsg('خطأ في المشاركة: $e', false);
    } finally {
      if (mounted) setState(() => _pdfGenerating = false);
    }
  }

  void _showMsg(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? AppColors.success
            : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ═════════════════ UI - تصميم احترافي جديد ═════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('فاتورة #${widget.transactionId}'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'تكليف جديد',
            icon: const Icon(Icons.add_task_rounded),
            color: AppColors.gold,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GeneralTasksScreen(
                    userId: _perms.userId ?? 0,
                    username: widget.username,
                    presetLinkedType: 'Invoice',
                    presetLinkedId: widget.transactionId,
                    autoOpenCreate: true,
                  ),
                ),
              );
            },
          ),
          if (_pdfGenerating)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
              tooltip: 'تصدير PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _exportPdf,
            ),
            IconButton(
              tooltip: 'مشاركة',
              icon: const Icon(Icons.share_rounded),
              onPressed: _sharePdf,
            ),
          ]
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return AppError(message: _error!, onRetry: _load);
  }

  (Color, String, IconData) _statusInfo(String? status) {
    switch (status) {
      case 'Paid':
        return (AppColors.success, 'مدفوعة', Icons.check_circle_rounded);
      case 'PartiallyPaid':
        return (
          AppColors.warning,
          'مدفوعة جزئياً',
          Icons.payment_rounded,
        );
      case 'Cancelled':
        return (AppColors.error, 'ملغاة', Icons.cancel_rounded);
      default:
        return (AppColors.info, 'مفتوحة', Icons.lock_open_rounded);
    }
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final header = _data?['header'] ?? {};
    final details = (_data?['details'] as List?) ?? [];
    final payments = (_data?['payments'] as List?) ?? [];
    final profit = _data?['profit'] is Map
        ? Map<String, dynamic>.from(_data!['profit'] as Map)
        : <String, dynamic>{};
    final editStatus = header['EditStatus'] ?? 0;

    final (statusColor, statusText, statusIcon) =
        _statusInfo(header['InvoiceStatus']?.toString());
    final partyName = isPurchase
        ? (header['SupplierName'] ??
            header['EmployeeName'] ??
            header['PartyName'] ??
            '—')
        : (header['PartyName'] ?? '—');
    final phone = _cust(header['Phone'] ?? header['CustomerPhone']);
    final empName = _cust(header['EmployeeName']);
    final refNo = header['ReferenceNumber']?.toString() ??
        '#${header['TransactionID'] ?? ''}';
    final grand = _numOf(header['GrandTotal']);
    final paid = _numOf(header['PaidAmount']);
    final remaining = grand - paid;
    final paidRatio = grand > 0 ? (paid / grand).clamp(0.0, 1.0) : 0.0;
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ══════════ هيدر احترافي - مضاد للـ overflow ══════════
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [HomeAccent.navyDark, HomeAccent.navyLight]
                    : [HomeAccent.navy, AppColors.navyLight],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: HomeAccent.navy.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // سطر النوع + المرجع - مع Flexible ضد overflow
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: HomeAccent.gold.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                isPurchase
                                    ? Icons.shopping_cart_rounded
                                    : Icons.sell_rounded,
                                size: 13,
                                color: HomeAccent.gold),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                isPurchase
                                    ? 'فاتورة مشتريات'
                                    : 'فاتورة مبيعات',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: HomeAccent.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          refNo,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // العميل + حالة
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partyName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.phone_rounded,
                                    size: 12, color: Colors.white70),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    phone,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (empName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.badge_outlined,
                                    size: 12, color: Colors.white70),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    empName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusBadge(
                      label: statusText,
                      color: statusColor,
                      icon: statusIcon,
                      filled: true,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // شريط التقدم
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'نسبة التحصيل ${(paidRatio * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10.5),
                        ),
                        const Spacer(),
                        Text(
                          '${_fmt(paid)} / ${_fmt(grand)}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: paidRatio,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        valueColor: AlwaysStoppedAnimation(statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3 إحصائيات - بدون overflow باستخدام FittedBox
                Row(
                  children: [
                    Expanded(
                        child: _StatTile(
                            label: 'الإجمالي',
                            value: _fmt(grand),
                            icon: Icons.receipt_long_rounded,
                            color: Colors.white)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatTile(
                            label: 'المدفوع',
                            value: _fmt(paid),
                            icon: Icons.check_circle_outline_rounded,
                            color: const Color(0xFF81C784))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatTile(
                            label: 'المتبقي',
                            value: _fmt(remaining),
                            icon: Icons.pending_rounded,
                            color: remaining > 0
                                ? const Color(0xFFFFAB91)
                                : const Color(0xFFA5D6A7))),
                  ],
                ),

                if ((header['DiscountPercentage'] ?? 0) > 0 ||
                    (header['DiscountAmount'] ?? 0) > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: HomeAccent.gold.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color:
                                    HomeAccent.gold.withValues(alpha: 0.22),
                                shape: BoxShape.circle),
                            child: Icon(Icons.percent_rounded,
                                size: 12, color: HomeAccent.gold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'خصم: ${header['DiscountPercentage'] ?? 0}% (${_fmt(header['DiscountAmount'])} ج.م)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (editStatus == 1) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppStatus.editPending.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFCE93D8).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded,
                            size: 15, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'طلب تعديل قيد المراجعة من الإدارة',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // معلومات الفاتورة
          _SectionCard(
            title: 'معلومات الفاتورة',
            icon: Icons.receipt_long_rounded,
            color: HomeAccent.indigo,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 74,
              ),
              itemBuilder: (c, idx) {
                final tiles = [
                  _InfoTileData(
                      icon: Icons.event_rounded,
                      label: 'تاريخ التعاقد',
                      value: _date(header['TransactionDate'])),
                  _InfoTileData(
                      icon: Icons.local_shipping_rounded,
                      label: 'تاريخ التسليم',
                      value: _date(header['DueDate'])),
                  _InfoTileData(
                      icon: Icons.warehouse_rounded,
                      label: 'المخزن',
                      value: header['WarehouseName'] ?? '—'),
                  _InfoTileData(
                      icon: Icons.payments_rounded,
                      label: 'طريقة الدفع',
                      value: header['PaymentMethod'] ?? '—'),
                ];
                return _InfoTile(data: tiles[idx]);
              },
            ),
          ),

          if (_canViewProfit && !isPurchase && profit.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionCard(
              title: 'تحليل الربح',
              icon: Icons.trending_up_rounded,
              color: AppStatus.profit,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _ProfitTile(
                        label: 'التكلفة',
                        value: _fmt(profit['totalCost']),
                        color: AppColors.neutral,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ProfitTile(
                        label: 'مجمل الربح',
                        value: _fmt(profit['grossProfit']),
                        color: AppStatus.profit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ProfitTile(
                        label: 'الهامش',
                        value:
                            '${_fmt(profit['profitMarginPercentage'])}%',
                        color: HomeAccent.gold,
                        hasCurrency: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // الأصناف
          _SectionCard(
            title: 'الأصناف (${details.length})',
            icon: Icons.inventory_2_rounded,
            color: HomeAccent.accent,
            child: details.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 36, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('لا توجد أصناف',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    )),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < details.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 1,
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3)),
                        _ProductRow(
                          detail: Map<String, dynamic>.from(details[i]),
                          // تعديل السعر أصبح داخل Full Edit حتى يمر بسبب/Audit وتصحيح مخزون.
                          canEditPrice: false,
                          onEditPrice: () => _editDetailPrice(
                              Map<String, dynamic>.from(details[i])),
                        ),
                      ],
                    ],
                  ),
          ),

          // المدفوعات
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionCard(
              title: 'المدفوعات (${payments.length})',
              icon: Icons.payments_rounded,
              color: HomeAccent.teal,
              child: Column(
                children: [
                  for (int idx = 0; idx < payments.length; idx++) ...[
                    _PaymentRow(
                      payment: payments[idx],
                      canEdit: _canEditPaymentRow(isPurchase),
                      canDelete: _canDeletePaymentRow,
                      onReceipt: () => _showPaymentReceipt(
                          Map<String, dynamic>.from(payments[idx] as Map)),
                      onEdit: () => _editPaymentFromDetails(
                          Map<String, dynamic>.from(payments[idx] as Map)),
                      onDelete: () => _deletePaymentFromDetails(
                          Map<String, dynamic>.from(payments[idx] as Map)),
                    ),
                    if (idx != payments.length - 1)
                      Divider(
                          height: 1,
                          indent: 52,
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.25)),
                  ],
                  if (_canViewPaymentsList)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor:
                              theme.brightness == Brightness.dark
                                  ? AppColors.gold
                                  : AppColors.navy,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('سجل المدفوعات الكامل'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PaymentsScreen(
                              username: widget.username,
                              initialType: isPurchase ? 'Purchase' : 'Sale',
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          if (editStatus == 1 || editStatus == 2 || editStatus == 3 || editStatus == 4) ...[
            _EditRequestCard(
              editStatus: editStatus,
              editBy: header['EditBy']?.toString(),
              editDate: header['EditRequestDate'],
              editReason: header['EditReason']?.toString(),
            ),
            const SizedBox(height: 16),
          ],

          // أزرار
          if (_canRequestEdit &&
              editStatus != 1 &&
              editStatus != 2 &&
              header['InvoiceStatus'] != 'Cancelled')
            AppButton(
              icon: Icons.edit_note_rounded,
              label: 'طلب تعديل الفاتورة',
              color: HomeAccent.indigo,
              onTap: _requestEdit,
            ),
          if (editStatus == 1 && _canApprove) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: AppButton(
                        icon: Icons.check_rounded,
                        label: 'موافقة',
                        color: AppColors.success,
                        onTap: _approveEdit)),
                const SizedBox(width: 12),
                Expanded(
                    child: AppButton(
                        icon: Icons.close_rounded,
                        label: 'رفض',
                        color: AppColors.error,
                        onTap: _rejectEdit)),
              ],
            ),
          ],
          if (header['InvoiceStatus'] != 'Cancelled' &&
              header['InvoiceStatus'] != 'Paid' &&
              (isPurchase
                  ? (_isAdminOrAccountMgr ||
                      _perms.canEdit('frm_SalesInvoiveNew') ||
                      _perms.canView('frm_SupplierInvoices'))
                  : (_canApprove && editStatus != 1))) ...[
            const SizedBox(height: 12),
            AppButton(
              icon: Icons.edit_rounded,
              label: _isAdminOrAccountMgr
                  ? 'تعديل الفاتورة بالكامل'
                  : 'تعديل بيانات الفاتورة',
              color: HomeAccent.gold,
              onTap: _openInvoiceEdit,
            ),
          ],
          if (!isPurchase &&
              header['InvoiceStatus'] != 'Cancelled' &&
              _remaining(header) > 0) ...[
            const SizedBox(height: 12),
            AppButton(
              icon: Icons.payments_rounded,
              label: 'إضافة دفعة',
              color: AppColors.success,
              onTap: () => _addPayment(header),
            ),
          ],
          if (_canCancelInvoice &&
              header['InvoiceStatus'] != 'Cancelled' &&
              !(_numOf(header['GrandTotal']) > 0 &&
                  _numOf(header['PaidAmount']) >=
                      _numOf(header['GrandTotal']))) ...[
            const SizedBox(height: 12),
            AppButton(
              icon: Icons.cancel_rounded,
              label: 'إلغاء الفاتورة',
              color: AppColors.error,
              onTap: () => _cancelInvoice(header),
            ),
          ],
          if (_canViewHistory) ...[
            const SizedBox(height: 12),
            AppButton(
              icon: Icons.history_rounded,
              label: 'سجل التعديلات والاسترجاع',
              color: HomeAccent.indigo,
              onTap: _openEditHistory,
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ──────────── إضافة دفعة (Item 14) ────────────────
  Future<void> _addPayment(Map<String, dynamic> header) async {
    final remaining = _remaining(header).toDouble();
    final amountCtrl =
        TextEditingController(text: remaining.toStringAsFixed(2));
    final notesCtrl = TextEditingController();
    List<Map<String, dynamic>> boxes = [];
    try {
      boxes = (await CashboxService.getAllCashboxes())
          .where((b) => b['IsActive'] != false)
          .toList();
    } catch (_) {}
    if (!mounted) return;
    int? selectedBoxId;
    for (final b in boxes) {
      if (b['IsDefault'] == true) {
        selectedBoxId = (b['CashBoxID'] as num?)?.toInt();
        break;
      }
    }
    selectedBoxId ??=
        boxes.isNotEmpty ? (boxes.first['CashBoxID'] as num?)?.toInt() : null;
    String selectedMethod = 'Cash';
    // تحليل شرائح السداد 70/20/10 من الخادم — يُجلب عند فتح الحوار
    // ويُحدَّث بزر التحليل عند تغيير المبلغ، وخطؤه ظاهر داخل الحوار.
    Map<String, dynamic>? analysis;
    String? analysisError;
    var analysisRequested = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> loadAnalysis() async {
            try {
              final amount =
                  double.tryParse(amountCtrl.text.trim()) ?? remaining;
              final data = await PaymentService.instance.getAnalysis(
                widget.transactionId,
                amount: amount > 0 ? amount : remaining,
              );
              setDialogState(() {
                analysis = data;
                analysisError = null;
              });
            } on ApiException catch (e) {
              setDialogState(() => analysisError = e.message);
            }
          }

          if (!analysisRequested) {
            analysisRequested = true;
            loadAnalysis();
          }
          final tierAnalysis = analysis?['CurrentPaymentAnalysis'];
          return AlertDialog(
          title: const Text('إضافة دفعة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المبلغ *',
                    helperText: 'المتبقي: ${_fmt(remaining)} ج',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedBoxId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الخزينة *',
                    border: OutlineInputBorder(),
                  ),
                  items: boxes
                      .map((b) => DropdownMenuItem<int>(
                            value: (b['CashBoxID'] as num?)?.toInt(),
                            child: Text('${b['CashBoxName'] ?? ''}'),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedBoxId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع *',
                    border: OutlineInputBorder(),
                  ),
                  items: PaymentService.selectableMethods
                      .map((m) => DropdownMenuItem<String>(
                            value: m['value'],
                            child: Text(m['label']!),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedMethod = v ?? 'Cash'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (analysisError != null)
                  Text(
                    'تعذر تحميل تحليل الشرائح: $analysisError',
                    style: TextStyle(
                        color: AppColors.error, fontSize: 12),
                  )
                else if (tierAnalysis is Map) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HomeAccent.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'تحليل الشرائح (70/20/10)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5),
                              ),
                            ),
                            IconButton(
                              tooltip: 'تحديث التحليل بالمبلغ الحالي',
                              icon: const Icon(Icons.refresh_rounded,
                                  size: 18),
                              onPressed: loadAnalysis,
                            ),
                          ],
                        ),
                        if ((tierAnalysis['Description'] ?? '')
                            .toString()
                            .isNotEmpty)
                          Text(
                            tierAnalysis['Description'].toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        for (final alloc
                            in (tierAnalysis['Allocations'] as List? ?? []))
                          Text(
                            '${(alloc as Map)['TierName']}: ${_fmt((alloc['AmountAllocated'] as num?)?.toDouble() ?? 0)} ج',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ الدفعة'),
            ),
          ],
          );
        },
      ),
    );
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    final notesText = notesCtrl.text.trim();
    amountCtrl.dispose();
    notesCtrl.dispose();
    if (confirmed != true || !mounted) return;
    if (amount <= 0 || selectedBoxId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغًا صحيحًا واختر الخزينة')),
      );
      return;
    }
    try {
      await InvoiceService.instance.addPayment(
        widget.transactionId,
        amount: amount,
        cashBoxId: selectedBoxId!,
        paymentMethod: selectedMethod,
        notes: notesText.isEmpty ? null : notesText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة الدفعة بنجاح')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  // ──────────── تعديل دفعة من سجل الفاتورة ────────────────
  // وحدات التحكم مملوكة للحوار وتُحرَّر بعد إغلاقه مباشرة.
  Future<void> _editPaymentFromDetails(Map<String, dynamic> payment) async {
    List<Map<String, dynamic>> boxes = [];
    try {
      boxes = (await CashboxService.getAllCashboxes())
          .where((b) => b['IsActive'] != false)
          .toList();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;
    final amountCtrl = TextEditingController(
        text: _numOf(payment['Amount']).toDouble().toStringAsFixed(2));
    final notesCtrl =
        TextEditingController(text: '${payment['Notes'] ?? ''}');
    int? boxId = (payment['CashBoxID'] as num?)?.toInt() ??
        (boxes.isNotEmpty ? (boxes.first['CashBoxID'] as num?)?.toInt() : null);
    String method = PaymentService.selectableMethods
            .any((m) => m['value'] == '${payment['PaymentMethod'] ?? ''}')
        ? '${payment['PaymentMethod']}'
        : 'Cash';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('تعديل الدفعة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: boxId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الخزينة *',
                    border: OutlineInputBorder(),
                  ),
                  items: boxes
                      .map((b) => DropdownMenuItem<int>(
                            value: (b['CashBoxID'] as num?)?.toInt(),
                            child: Text('${b['CashBoxName'] ?? ''}'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => boxId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع *',
                    border: OutlineInputBorder(),
                  ),
                  items: PaymentService.selectableMethods
                      .map((m) => DropdownMenuItem<String>(
                            value: m['value'],
                            child: Text(m['label']!),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => method = v ?? 'Cash'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    final notesText = notesCtrl.text.trim();
    amountCtrl.dispose();
    notesCtrl.dispose();
    if (confirmed != true || !mounted) return;
    if (amount <= 0 || boxId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغًا صحيحًا واختر الخزينة')),
      );
      return;
    }
    try {
      await PaymentService.instance.updatePayment(
        (payment['PaymentID'] as num).toInt(),
        amount: amount,
        cashBoxId: boxId!,
        paymentMethod: method,
        notes: notesText.isEmpty ? null : notesText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعديل الدفعة بنجاح')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ──────────── إلغاء دفعة من سجل الفاتورة (سبب إلزامي) ─────────
  Future<void> _deletePaymentFromDetails(Map<String, dynamic> payment) async {
    final reasonCtrl = TextEditingController();
    String? reasonError;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إلغاء الدفعة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'سيتم حذف دفعة ${_fmt(payment['Amount'])} ج نهائيًا مع حركتها في الخزينة، وإعادة حساب الفاتورة.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  labelText: 'سبب الإلغاء *',
                  errorText: reasonError,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  setDialogState(() => reasonError = 'سبب الإلغاء مطلوب');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('إلغاء الدفعة'),
            ),
          ],
        ),
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true || !mounted) return;
    try {
      await PaymentService.instance.deletePayment(
        (payment['PaymentID'] as num).toInt(),
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الدفعة ورد قيمتها للخزينة')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ──────────── سند دفعة من سجل الفاتورة ────────────────────────
  Future<void> _showPaymentReceipt(Map<String, dynamic> payment) async {
    Map<String, dynamic> receipt;
    try {
      receipt = await PaymentService.instance
          .getReceipt((payment['PaymentID'] as num).toInt());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;
    final pay =
        Map<String, dynamic>.from((receipt['Payment'] as Map?) ?? payment);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${receipt['ReceiptTypeAr'] ?? 'سند دفعة'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم السند: ${receipt['ReceiptNumber'] ?? ''}'),
              Text('الطرف: ${pay['PartyName'] ?? '—'}'),
              Text('الخزينة: ${pay['CashBoxName'] ?? '—'}'),
              const SizedBox(height: 10),
              Text(
                '${_fmt(pay['Amount'])} ج',
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text('${receipt['AmountInWords'] ?? ''}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print_rounded),
            label: const Text('طباعة / مشاركة'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _printPaymentReceipt(receipt, pay);
            },
          ),
        ],
      ),
    );
  }

  // طباعة/مشاركة سند الدفعة PDF — نمط سند الرسوم الإضافية نفسه
  Future<void> _printPaymentReceipt(
      Map<String, dynamic> receipt, Map<String, dynamic> pay) async {
    try {
      final regularData =
          await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      final regular = pw.Font.ttf(regularData);
      final bold = pw.Font.ttf(boldData);
      final document = pw.Document();
      document.addPage(pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(26),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text('${receipt['CompanyName'] ?? 'COCOBOLO'}',
                style: pw.TextStyle(font: bold, fontSize: 16)),
            pw.Text(
                '${receipt['ReceiptTypeAr'] ?? ''} — ${receipt['ReceiptNumber'] ?? ''}',
                style: pw.TextStyle(font: bold, fontSize: 13)),
            pw.SizedBox(height: 14),
            pw.Text('الطرف: ${pay['PartyName'] ?? '—'}',
                style: pw.TextStyle(font: regular, fontSize: 11)),
            pw.Text('الفاتورة: ${pay['InvoiceReferenceNumber'] ?? '—'}',
                style: pw.TextStyle(font: regular, fontSize: 11)),
            pw.Text('الخزينة: ${pay['CashBoxName'] ?? '—'}',
                style: pw.TextStyle(font: regular, fontSize: 11)),
            pw.SizedBox(height: 14),
            pw.Text('${_fmt(pay['Amount'])} ج',
                style: pw.TextStyle(font: bold, fontSize: 20)),
            pw.Text('${receipt['AmountInWords'] ?? ''}',
                style: pw.TextStyle(font: regular, fontSize: 11)),
          ],
        ),
      ));
      final bytes = await document.save();
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          receipt['ReceiptNumber'] ?? 'payment_${pay['PaymentID']}';
      final file = File('${directory.path}/$fileName.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: '${receipt['ReceiptTypeAr'] ?? 'سند دفعة'}',
        text: '${receipt['ReceiptTypeAr'] ?? 'سند دفعة'} — ${pay['PartyName'] ?? ''}',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء السند: $e')),
        );
      }
    }
  }

  // ──────────── إلغاء الفاتورة (Item 14) ────────────────
  Future<void> _cancelInvoice(Map<String, dynamic> header) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الفاتورة'),
        content: Text(
          'سيتم إلغاء الفاتورة ${header['ReferenceNumber'] ?? ''} نهائيًا وإعادة المخزون. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء الفاتورة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await InvoiceService.instance.cancelInvoice(widget.transactionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الفاتورة')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  num _remaining(Map<String, dynamic> header) {
    final grand = header['GrandTotal'] is num ? header['GrandTotal'] as num : 0;
    final paid = header['PaidAmount'] is num ? header['PaidAmount'] as num : 0;
    return grand - paid;
  }
}

// ═════════════════ Widgets احترافية ═════════════════

class _ProfitTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool hasCurrency;

  const _ProfitTile({
    required this.label,
    required this.value,
    required this.color,
    this.hasCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              )),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AmountText(
              value: hasCurrency ? '$value ج' : value,
              color: color,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: Colors.white70),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AmountText(value: value, color: color, size: 14),
          ),
          Text('ج.م',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 9)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SectionCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.child});

  @override
  Widget build(BuildContext context) {
    // مبنية الآن على مكوّنات النظام: AppCard + AppSectionHeader
    return AppCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: AppSectionHeader(title: title, icon: icon, accent: color),
          ),
          child,
        ],
      ),
    );
  }
}

class _InfoTileData {
  final IconData icon;
  final String label;
  final String value;
  _InfoTileData({required this.icon, required this.label, required this.value});
}

class _InfoTile extends StatelessWidget {
  final _InfoTileData data;
  const _InfoTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(data.icon,
                size: 16, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9.5,
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Map<String, dynamic> detail;
  final bool canEditPrice;
  final VoidCallback onEditPrice;

  const _ProductRow(
      {required this.detail,
      required this.canEditPrice,
      required this.onEditPrice});

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return NumberFormat('#,##0.00')
        .format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productId = detail['ProductID'];
    final desc = (detail['ProductDescription'] ?? '').toString().trim();
    final qty = detail['Quantity'] ?? 0;
    final unitPrice = detail['UnitPrice'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // صورة
          if (productId != null)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                '$baseUrl/api/product-images/$productId',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                    Icons.inventory_2_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 22),
                loadingBuilder: (c, child, progress) {
                  if (progress == null) return child;
                  return Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: HomeAccent.accent)));
                },
              ),
            ),
          if (productId != null) const SizedBox(width: 12),

          // معلومات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail['ProductName'] ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: theme.colorScheme.onSurface),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.8,
                          height: 1.2,
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: HomeAccent.accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: HomeAccent.accent
                                    .withValues(alpha: 0.18))),
                        child: Text(
                          '${qty.toString()} × ${_fmt(unitPrice)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: HomeAccent.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // إجمالي + تعديل
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                child: Text(_fmt(detail['TotalAmount']),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface)),
              ),
              Text('ج.م',
                  style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant)),
              if (canEditPrice) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: onEditPrice,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: HomeAccent.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color:
                              HomeAccent.accent.withValues(alpha: 0.22)),
                    ),
                    child: Icon(Icons.edit_rounded,
                        size: 14, color: HomeAccent.accent),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final dynamic payment;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onReceipt;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _PaymentRow({
    required this.payment,
    this.canEdit = false,
    this.canDelete = false,
    this.onReceipt,
    this.onEdit,
    this.onDelete,
  });

  String _date(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return NumberFormat('#,##0.00')
        .format(v is num ? v : double.tryParse(v.toString()) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActions =
        onReceipt != null || (canEdit && onEdit != null) || (canDelete && onDelete != null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: HomeAccent.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: HomeAccent.teal.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.check_rounded,
                    size: 18, color: HomeAccent.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_date(payment['PaymentDate'] ?? payment['CreatedAt']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface)),
                    if ((payment['PaymentMethod'] ?? '')
                        .toString()
                        .isNotEmpty)
                      Text(
                          PaymentService.methodLabel(
                              payment['PaymentMethod'].toString()),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant)),
                    if ((payment['CashBoxName'] ?? '').toString().isNotEmpty)
                      Text('الخزينة: ${payment['CashBoxName']}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant)),
                    if (payment['Percentage'] != null)
                      Text(
                          'نسبة الدفعة: ${(payment['Percentage'] as num).toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AmountText(
                value: '${_fmt(payment['Amount'])} ج',
                size: 13.5,
                color: HomeAccent.teal,
              ),
            ],
          ),
          if (hasActions)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReceipt != null)
                  IconButton(
                    tooltip: 'سند الدفعة',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.receipt_rounded, size: 19),
                    onPressed: onReceipt,
                  ),
                if (canEdit && onEdit != null)
                  IconButton(
                    tooltip: 'تعديل الدفعة',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_rounded, size: 19),
                    onPressed: onEdit,
                  ),
                if (canDelete && onDelete != null)
                  IconButton(
                    tooltip: 'إلغاء الدفعة',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_rounded,
                        size: 19, color: AppColors.error),
                    onPressed: onDelete,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EditRequestCard extends StatelessWidget {
  final int editStatus;
  final String? editBy;
  final dynamic editDate;
  final String? editReason;

  const _EditRequestCard(
      {required this.editStatus, this.editBy, this.editDate, this.editReason});

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('yyyy/MM/dd HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, IconData icon, String title) = switch (editStatus) {
      1 => (
          AppStatus.editPending,
          Icons.hourglass_top_rounded,
          'طلب تعديل معلق'
        ),
      2 => (
          AppColors.success,
          Icons.lock_open_rounded,
          'تمت الموافقة على فتح التعديل'
        ),
      3 => (
          AppColors.error,
          Icons.cancel_rounded,
          'تم رفض طلب التعديل'
        ),
      _ => (
          AppColors.info,
          Icons.edit_rounded,
          'تم تنفيذ التعديل'
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: color)),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _row(theme, 'مقدم من:', editBy ?? '—'),
          _row(theme, 'التاريخ:', _fmtDate(editDate)),
          if (editReason != null && editReason!.isNotEmpty)
            _row(theme, 'السبب:', editReason!),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
