import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/additional_charge_service.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../widgets/app_states.dart';
import 'invoice/invoice_details_screen.dart';

class AdditionalChargesScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? initialPartyId;
  final int? initialChargeId;

  const AdditionalChargesScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialPartyId,
    this.initialChargeId,
  });

  @override
  State<AdditionalChargesScreen> createState() =>
      _AdditionalChargesScreenState();
}

class _AdditionalChargesScreenState extends State<AdditionalChargesScreen> {
  final AdditionalChargeService _service = AdditionalChargeService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  Map<String, dynamic> _stats = <String, dynamic>{};
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _busy = false;
  String? _error;
  String _mode = 'all';
  String? _type;
  String? _status;
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _hasMore = false;
  Timer? _debounce;
  bool _openedInitial = false;

  bool get _isDark => ThemeService().isDarkMode;
  bool _can(String key) => _capabilities[key] == true;
  bool get _advances => _mode == 'advances';

  static const Map<String, String> _typeNames = {
    'Inspection': 'رسوم معاينة',
    'Shipping': 'رسوم شحن',
    'Installation': 'رسوم تركيب',
    'Advance': 'دفعة مقدمة',
    'Other': 'رسوم أخرى',
  };
  static const Map<String, String> _statusNames = {
    'Paid': 'مدفوعة وغير مطبقة',
    'Applied': 'مطبقة على فاتورة',
    'NonRefundable': 'غير مستردة',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialPartyId != null) _mode = 'advances';
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

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
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
      final data = await _service.getCharges(
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        type: _advances ? null : _type,
        advanceLike: _advances,
        status: _status,
        partyId: widget.initialPartyId,
        dateFrom: _from,
        dateTo: _to,
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
        _stats = _map(data['stats']);
        _capabilities = _map(data['capabilities']);
        _hasMore = pagination['hasMore'] == true;
        _loading = false;
        _loadingMore = false;
      });
      if (!_openedInitial &&
          widget.initialChargeId != null &&
          widget.initialChargeId! > 0) {
        _openedInitial = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showChargeDetails(widget.initialChargeId!);
        });
      }
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

  Future<void> _openForm({Map<String, dynamic>? row}) async {
    final editing = row != null;
    if (editing && !_can('canEdit')) return;
    if (!editing && !_can('canCreate')) return;

    Map<String, dynamic>? selectedParty;
    int? cashBoxId;
    String type = editing
        ? '${row['ChargeType'] ?? 'Inspection'}'
        : (_advances ? 'Advance' : 'Inspection');
    final description = TextEditingController(
      text: editing
          ? '${row['ChargeDescription'] ?? ''}'
          : (_typeNames[type] ?? ''),
    );
    final amount = TextEditingController(
      text: editing ? '${row['ChargeAmount'] ?? ''}' : '',
    );
    final notes =
        TextEditingController(text: editing ? '${row['Notes'] ?? ''}' : '');
    final partySearch = TextEditingController();
    var lookups = await _service.getLookups(
      search: '',
      partyId: editing ? _int(row['PartyID']) : widget.initialPartyId,
    );
    var parties = (lookups['parties'] as List? ?? const [])
        .map<Map<String, dynamic>>(_map)
        .toList();
    final cashboxes = (lookups['cashboxes'] as List? ?? const [])
        .map<Map<String, dynamic>>(_map)
        .toList();
    if (editing) {
      selectedParty = {
        'PartyID': row['PartyID'],
        'PartyName': row['PartyName'],
      };
    } else if (widget.initialPartyId != null) {
      selectedParty = parties.cast<Map<String, dynamic>?>().firstWhere(
            (party) => _int(party?['PartyID']) == widget.initialPartyId,
            orElse: () => null,
          );
    }
    if (cashboxes.isNotEmpty) cashBoxId = _int(cashboxes.first['CashBoxID']);

    if (!mounted) return;
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(_isDark),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) {
          Future<void> searchParty() async {
            final data =
                await _service.getLookups(search: partySearch.text.trim());
            setSheetState(() {
              parties = (data['parties'] as List? ?? const [])
                  .map<Map<String, dynamic>>(_map)
                  .toList();
            });
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                18, 16, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider(_isDark),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                Text(editing ? 'تعديل الرسوم' : 'تسجيل رسوم أو دفعة مقدمة',
                    style: GoogleFonts.cairo(
                        color: AppColors.text(_isDark),
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 15),
                if (!editing) ...[
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: partySearch,
                        style: GoogleFonts.cairo(),
                        decoration: InputDecoration(
                          labelText: 'بحث عن العميل',
                          labelStyle: GoogleFonts.cairo(),
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onSubmitted: (_) => searchParty(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: searchParty,
                      icon: const Icon(Icons.search_rounded),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selectedParty == null
                        ? null
                        : _int(selectedParty!['PartyID']),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'العميل *',
                      labelStyle: GoogleFonts.cairo(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    items: parties
                        .map((party) => DropdownMenuItem<int>(
                              value: _int(party['PartyID']),
                              child: Text('${party['PartyName'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo()),
                            ))
                        .toList(),
                    onChanged: (id) => setSheetState(() {
                      selectedParty = parties.firstWhere(
                        (party) => _int(party['PartyID']) == id,
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(
                    labelText: 'نوع الرسوم *',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  items: _typeNames.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child:
                                Text(entry.value, style: GoogleFonts.cairo()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setSheetState(() {
                      type = value;
                      if (description.text.trim().isEmpty ||
                          _typeNames.values.contains(description.text.trim())) {
                        description.text = _typeNames[value] ?? '';
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  style: GoogleFonts.cairo(),
                  decoration: InputDecoration(
                    labelText: 'الوصف *',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.cairo(),
                  decoration: InputDecoration(
                    labelText: 'المبلغ *',
                    labelStyle: GoogleFonts.cairo(),
                    suffixText: 'ج.م',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: cashBoxId,
                  decoration: InputDecoration(
                    labelText: 'الخزينة',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  items: cashboxes
                      .map((cashbox) => DropdownMenuItem<int>(
                            value: _int(cashbox['CashBoxID']),
                            child: Text('${cashbox['CashBoxName'] ?? ''}',
                                style: GoogleFonts.cairo()),
                          ))
                      .toList(),
                  onChanged: (value) => setSheetState(() => cashBoxId = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  style: GoogleFonts.cairo(),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if ((!editing && selectedParty == null) ||
                          description.text.trim().isEmpty ||
                          _num(amount.text) <= 0) {
                        ScaffoldMessenger.of(sheetContext)
                            .showSnackBar(SnackBar(
                          content: Text('أكمل العميل والوصف والمبلغ الصحيح',
                              style: GoogleFonts.cairo()),
                        ));
                        return;
                      }
                      Navigator.pop(sheetContext, true);
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: Text('حفظ وتسجيل التحصيل',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
    if (save != true) return;
    final body = <String, dynamic>{
      'partyId': editing ? row['PartyID'] : selectedParty?['PartyID'],
      'cashBoxId': cashBoxId,
      'chargeType': type,
      'chargeDescription': description.text.trim(),
      'chargeAmount': _num(amount.text),
      'notes': notes.text.trim(),
    };
    await _run(() => editing
        ? _service.update(_int(row['ChargeID']), body)
        : _service.create(body));
  }

  Future<void> _apply(Map<String, dynamic> row) async {
    final data = await _service.getLookups(partyId: _int(row['PartyID']));
    final invoices = (data['invoices'] as List? ?? const [])
        .map<Map<String, dynamic>>(_map)
        .toList();
    int? transactionId;
    if (!mounted) return;
    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('تطبيق على فاتورة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '${row['ChargeDescription'] ?? ''} — ${_money(row['ChargeAmount'])}',
                style: GoogleFonts.cairo(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: transactionId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'فاتورة العميل',
                  labelStyle: GoogleFonts.cairo(),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                items: invoices
                    .map((invoice) => DropdownMenuItem<int>(
                          value: _int(invoice['TransactionID']),
                          child: Text(
                            '${invoice['ReferenceNumber'] ?? '#${invoice['TransactionID']}'} — متبقي ${_money(invoice['RemainingAmount'])}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(fontSize: 11),
                          ),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => transactionId = value),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              onPressed: transactionId == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text('تطبيق', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (apply == true && transactionId != null) {
      await _run(() => _service.applyToInvoice(
            id: _int(row['ChargeID']),
            transactionId: transactionId!,
          ));
    }
  }

  Future<void> _markNonRefundable(Map<String, dynamic> row) async {
    final controller = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تحديد كغير مستردة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: GoogleFonts.cairo(),
          decoration: InputDecoration(
            labelText: 'السبب *',
            labelStyle: GoogleFonts.cairo(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('تأكيد', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (save == true && controller.text.trim().isNotEmpty) {
      await _run(() => _service.markNonRefundable(
            id: _int(row['ChargeID']),
            reason: controller.text.trim(),
          ));
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('حذف الرسوم',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: Text(
          'سيتم حذف الرسوم وحركة التحصيل المرتبطة بها من الخزينة. هل تريد الاستمرار؟',
          style: GoogleFonts.cairo(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('حذف', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (yes == true) await _run(() => _service.delete(_int(row['ChargeID'])));
  }

  Future<void> _showChargeDetails(int chargeId) async {
    setState(() => _busy = true);
    try {
      final data = await _service.getCharge(chargeId);
      if (!mounted) return;
      setState(() => _busy = false);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card(_isDark),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.all(18),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(_isDark),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 15),
              Row(children: [
                Icon(_typeIcon('${data['ChargeType'] ?? 'Other'}'),
                    color: AppColors.goldDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${data['ChargeDescription'] ?? 'تفاصيل الرسوم'}',
                      style: GoogleFonts.cairo(
                          color: AppColors.text(_isDark),
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                ),
                _badge(_statusName('${data['Status'] ?? ''}'),
                    _statusColor('${data['Status'] ?? ''}')),
              ]),
              const Divider(height: 24),
              _detailLine('العميل', data['PartyName']),
              _detailLine('الهاتف', data['PartyPhone']),
              _detailLine('النوع', _typeName('${data['ChargeType'] ?? ''}')),
              _detailLine('المبلغ', _money(data['ChargeAmount'])),
              _detailLine('الحالة', _statusName('${data['Status'] ?? ''}')),
              _detailLine('الخزينة', data['CashBoxName']),
              _detailLine('تاريخ التسجيل', _date(data['CreatedAt'])),
              _detailLine('المحرر', data['CreatedBy']),
              if ((data['AppliedToTransactionRef'] ?? data['TransactionRef']) !=
                  null)
                _detailLine('الفاتورة',
                    data['AppliedToTransactionRef'] ?? data['TransactionRef']),
              if ((data['Notes'] ?? '').toString().isNotEmpty)
                _detailLine('ملاحظات', data['Notes']),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _receipt(data);
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label:
                      Text('طباعة ومشاركة الإيصال', style: GoogleFonts.cairo()),
                ),
              ),
            ]),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _message(error.toString(), error: true);
      }
    }
  }

  Widget _detailLine(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 105,
          child: Text(label,
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark), fontSize: 11)),
        ),
        Expanded(
          child: Text('${value ?? '—'}',
              style: GoogleFonts.cairo(
                  color: AppColors.text(_isDark),
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
      ]),
    );
  }

  Future<void> _receipt(Map<String, dynamic> row) async {
    setState(() => _busy = true);
    try {
      final data = await _service.getReceipt(_int(row['ChargeID']));
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
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF13273F),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(children: [
                pw.Text('${data['CompanyName'] ?? 'COCOBOLO'}',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: const PdfColor.fromInt(0xFFDBBF74))),
                pw.Text(_receiptTitle(data),
                    style: pw.TextStyle(
                        font: bold, fontSize: 14, color: PdfColors.white)),
                pw.Text('${data['ReceiptNumber'] ?? ''}',
                    style: pw.TextStyle(
                        font: regular, fontSize: 8, color: PdfColors.grey300)),
              ]),
            ),
            pw.SizedBox(height: 18),
            _pdfLine(
                'استلمنا من', '${data['PartyName'] ?? '—'}', regular, bold),
            _pdfLine(
                'رقم الهاتف', '${data['PartyPhone'] ?? '—'}', regular, bold),
            _pdfLine(
                'البيان', '${data['ChargeDescription'] ?? '—'}', regular, bold),
            _pdfLine('نوع التحصيل', _typeName('${data['ChargeType'] ?? ''}'),
                regular, bold),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF6F1E5),
                border:
                    pw.Border.all(color: const PdfColor.fromInt(0xFFDBBF74)),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Center(
                child: pw.Text(_money(data['ChargeAmount']),
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 23,
                        color: const PdfColor.fromInt(0xFF13273F))),
              ),
            ),
            pw.SizedBox(height: 12),
            _pdfLine('الخزينة', '${data['CashBoxName'] ?? '—'}', regular, bold),
            _pdfLine('التاريخ', _date(data['ReceiptDate'] ?? data['CreatedAt']),
                regular, bold),
            _pdfLine('المحرر', '${data['CreatedBy'] ?? '—'}', regular, bold),
            if ((data['AppliedToTransactionRef'] ?? data['TransactionRef']) !=
                null)
              _pdfLine(
                  'الفاتورة المرتبطة',
                  '${data['AppliedToTransactionRef'] ?? data['TransactionRef']}',
                  regular,
                  bold),
            if ((data['Notes'] ?? '').toString().isNotEmpty)
              _pdfLine('ملاحظات', '${data['Notes']}', regular, bold),
            pw.Spacer(),
            pw.Divider(color: const PdfColor.fromInt(0xFFDBBF74)),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('توقيع المستلم',
                      style: pw.TextStyle(font: regular, fontSize: 8)),
                  pw.Text('توقيع العميل',
                      style: pw.TextStyle(font: regular, fontSize: 8)),
                ]),
          ],
        ),
      ));
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/${data['ReceiptNumber'] ?? 'charge_${row['ChargeID']}'}.pdf');
      await file.writeAsBytes(await document.save(), flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: _receiptTitle(data),
        text: '${_receiptTitle(data)} — ${data['PartyName'] ?? ''}',
      ));
    } catch (error) {
      if (mounted) _message('تعذر إنشاء الإيصال: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  pw.Widget _pdfLine(
      String label, String value, pw.Font regular, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 9),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
            width: 90,
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: regular, fontSize: 9, color: PdfColors.grey700))),
        pw.Expanded(
            child:
                pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 10))),
      ]),
    );
  }

  String _receiptTitle(Map<String, dynamic> data) {
    final type = '${data['ChargeType'] ?? ''}';
    final description = '${data['ChargeDescription'] ?? ''}';
    if (type == 'Inspection' || description.contains('معاينة')) {
      return 'إيصال استلام رسوم معاينة';
    }
    if (type == 'Advance' || description.contains('دفعة')) {
      return 'إيصال استلام دفعة مقدمة';
    }
    if (description.contains('عربون')) return 'إيصال استلام عربون';
    return 'إيصال استلام رسوم إضافية';
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
        title: Text('الرسوم والدفعات المقدمة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: !_loading && _can('canCreate')
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : () => _openForm(),
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navyDark,
              icon: const Icon(Icons.add_rounded),
              label: Text(_advances ? 'دفعة مقدمة' : 'رسوم جديدة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            )
          : null,
      body: Stack(children: [
        if (_loading)
          const AppLoading(message: 'جاري تحميل الرسوم والدفعات')
        else if (_error != null)
          AppError(message: _error!, onRetry: _load)
        else
          RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(child: _filters()),
              if (_rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmpty(
                    message: _advances
                        ? 'لا توجد دفعات مقدمة مطابقة'
                        : 'لا توجد رسوم مطابقة',
                    hint: 'غيّر الفلاتر أو أضف حركة جديدة',
                    icon: Icons.account_balance_wallet_outlined,
                    onRefresh: _load,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 90),
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
                      return _card(_rows[index]);
                    },
                  ),
                ),
            ]),
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

  Widget _header() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navy, AppColors.navyLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.gold, size: 27),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_advances ? 'دفعات العملاء المقدمة' : 'الرسوم الإضافية',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17)),
              Text('تحصيل خزينة، تطبيق على الفواتير، وإيصالات PDF',
                  style:
                      GoogleFonts.cairo(color: Colors.white60, fontSize: 10.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 13),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'all',
                label: Text('كل الرسوم'),
                icon: Icon(Icons.receipt_long_rounded)),
            ButtonSegment(
                value: 'advances',
                label: Text('الدفعات المقدمة'),
                icon: Icon(Icons.savings_rounded)),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.navyDark
                    : Colors.white70),
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppColors.gold
                    : Colors.white.withValues(alpha: 0.06)),
          ),
          onSelectionChanged: (values) {
            setState(() {
              _mode = values.first;
              _type = null;
            });
            _load();
          },
        ),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _stat('الإجمالي', _stats['TotalAmount'], Icons.summarize_rounded,
                AppColors.gold),
            _stat('متاحة', _stats['AvailableAmount'], Icons.savings_rounded,
                AppColors.warning),
            _stat('مطبقة', _stats['AppliedAmount'], Icons.link_rounded,
                AppColors.success),
            _stat('غير مستردة', _stats['NonRefundableAmount'],
                Icons.block_rounded, AppColors.error),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String label, dynamic value, IconData icon, Color color) =>
      Container(
        width: 118,
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_money(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5)),
              Text(label,
                  style:
                      GoogleFonts.cairo(color: Colors.white60, fontSize: 8.5)),
            ]),
          ),
        ]),
      );

  Widget _filters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(children: [
        TextField(
          controller: _searchController,
          onChanged: _searchChanged,
          style: GoogleFonts.cairo(),
          decoration: InputDecoration(
            hintText: 'العميل، الهاتف، الوصف، أو رقم الفاتورة',
            hintStyle: GoogleFonts.cairo(fontSize: 11),
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
          if (!_advances)
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: 'النوع',
                  labelStyle: GoogleFonts.cairo(fontSize: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  DropdownMenuItem<String?>(
                      value: null,
                      child: Text('كل الأنواع', style: GoogleFonts.cairo())),
                  ..._typeNames.entries
                      .map((entry) => DropdownMenuItem<String?>(
                            value: entry.key,
                            child:
                                Text(entry.value, style: GoogleFonts.cairo()),
                          )),
                ],
                onChanged: (value) {
                  setState(() => _type = value);
                  _load();
                },
              ),
            ),
          if (!_advances) const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _status,
              decoration: InputDecoration(
                labelText: 'الحالة',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
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
          const SizedBox(width: 8),
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
    _load();
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_month_rounded, size: 16),
        label: Text(
            date == null ? label : DateFormat('yyyy/MM/dd').format(date),
            style: GoogleFonts.cairo(fontSize: 10)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _card(Map<String, dynamic> row) {
    final type = '${row['ChargeType'] ?? 'Other'}';
    final status = '${row['Status'] ?? 'Paid'}';
    final locked = row['IsLocked'] == true;
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_typeIcon(type), color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['ChargeDescription'] ?? _typeName(type)}',
                  style: GoogleFonts.cairo(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5)),
              Text('${row['PartyName'] ?? '—'}',
                  style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(_isDark), fontSize: 10.5)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_money(row['ChargeAmount']),
                style: GoogleFonts.cairo(
                    color: AppColors.text(_isDark),
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
            _badge(_statusName(status), color),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 7, children: [
          _chip(_typeIcon(type), _typeName(type)),
          _chip(Icons.calendar_month_rounded, _date(row['CreatedAt'])),
          if ((row['AppliedToTransactionRef'] ?? row['TransactionRef']) != null)
            _chip(Icons.receipt_long_rounded,
                '${row['AppliedToTransactionRef'] ?? row['TransactionRef']}',
                color: AppColors.success),
          if ((row['CreatedBy'] ?? '').toString().isNotEmpty)
            _chip(Icons.person_outline_rounded, '${row['CreatedBy']}'),
        ]),
        const SizedBox(height: 9),
        Row(children: [
          IconButton(
            onPressed:
                _busy ? null : () => _showChargeDetails(_int(row['ChargeID'])),
            icon: const Icon(Icons.visibility_rounded),
            tooltip: 'التفاصيل',
          ),
          IconButton(
            onPressed: _busy ? null : () => _receipt(row),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'الإيصال',
          ),
          if ((row['AppliedToTransactionId'] ?? row['TransactionID']) != null)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailsScreen(
                    transactionId: _int(
                        row['AppliedToTransactionId'] ?? row['TransactionID']),
                    username: widget.username,
                  ),
                ),
              ),
              icon: const Icon(Icons.receipt_long_rounded),
              tooltip: 'الفاتورة',
            ),
          if (!locked && status == 'Paid' && _can('canApply'))
            IconButton(
              onPressed: _busy ? null : () => _apply(row),
              icon: const Icon(Icons.link_rounded, color: AppColors.success),
              tooltip: 'تطبيق على فاتورة',
            ),
          const Spacer(),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _openForm(row: row);
              if (value == 'nonRefund') _markNonRefundable(row);
              if (value == 'delete') _delete(row);
            },
            itemBuilder: (_) => [
              if (!locked && _can('canEdit'))
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: Text('تعديل', style: GoogleFonts.cairo()),
                  ),
                ),
              if (!locked && status == 'Paid' && _can('canMarkNonRefundable'))
                PopupMenuItem(
                  value: 'nonRefund',
                  child: ListTile(
                    leading: const Icon(Icons.block_rounded),
                    title: Text('غير مستردة', style: GoogleFonts.cairo()),
                  ),
                ),
              if (!locked && _can('canDelete'))
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error),
                    title: Text('حذف',
                        style: GoogleFonts.cairo(color: AppColors.error)),
                  ),
                ),
            ],
          ),
        ]),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: GoogleFonts.cairo(
                color: color, fontSize: 8.5, fontWeight: FontWeight.w800)),
      );

  Widget _chip(IconData icon, String text, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: (color ?? AppColors.navy).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14, color: color ?? AppColors.textSecondary(_isDark)),
          const SizedBox(width: 5),
          Text(text,
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark), fontSize: 9.5)),
        ]),
      );

  String _typeName(String type) => _typeNames[type] ?? 'رسوم أخرى';
  String _statusName(String status) => _statusNames[status] ?? status;

  IconData _typeIcon(String type) => switch (type) {
        'Inspection' => Icons.search_rounded,
        'Shipping' => Icons.local_shipping_rounded,
        'Installation' => Icons.handyman_rounded,
        'Advance' => Icons.savings_rounded,
        _ => Icons.account_balance_wallet_rounded,
      };

  Color _statusColor(String status) => switch (status) {
        'Applied' => AppColors.success,
        'NonRefundable' => AppColors.error,
        _ => AppColors.warning,
      };

  String _money(dynamic value) =>
      '${NumberFormat('#,##0.00').format(_num(value))} ج.م';

  String _date(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? '—' : DateFormat('yyyy/MM/dd').format(date);
  }
}
