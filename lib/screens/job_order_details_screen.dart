import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../services/app_colors.dart';
import '../services/job_order_service.dart';
import '../services/theme_service.dart';
import 'invoice/invoice_details_screen.dart';

class JobOrderDetailsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int transactionId;

  const JobOrderDetailsScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.transactionId,
  });

  @override
  State<JobOrderDetailsScreen> createState() => _JobOrderDetailsScreenState();
}

class _JobOrderDetailsScreenState extends State<JobOrderDetailsScreen> {
  final JobOrderService _service = JobOrderService();
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _isDark => ThemeService().isDarkMode;
  Color get _cardColor => AppColors.card(_isDark);
  Color get _textColor => AppColors.text(_isDark);
  Color get _secondaryTextColor => AppColors.textSecondary(_isDark);
  Map<String, dynamic> get _capabilities => _map(_order?['capabilities']);
  bool _can(String key) => _capabilities[key] == true;
  List<Map<String, dynamic>> get _items =>
      ((_order?['items'] as List?) ?? const <dynamic>[])
          .map<Map<String, dynamic>>(_map)
          .toList();

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
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getJobOrder(widget.transactionId);
      if (!mounted) return;
      setState(() {
        _order = data;
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          title: Text(
            '${_order?['ReferenceNumber'] ?? 'أمر التشغيل'}',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          actions: <Widget>[
            if (!_loading && _order != null)
              IconButton(
                tooltip: 'طباعة ومشاركة',
                onPressed: _busy ? null : _sharePdf,
                icon: const Icon(Icons.print_rounded),
              ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : _error != null
                ? _errorState()
                : _body(),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: FilledButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded),
        label: Text('إعادة المحاولة: $_error', style: GoogleFonts.cairo()),
      ),
    );
  }

  Widget _body() {
    final order = _order!;
    final purchase = '${order['TransactionType']}' == 'Purchase';
    final maxPeriod = _items.fold<int>(
      0,
      (int max, Map<String, dynamic> item) =>
          _int(item['Period']) > max ? _int(item['Period']) : max,
    );
    final alternatives = _items
        .where((Map<String, dynamic> item) =>
            item['SelectedAlternativeID'] != null)
        .length;
    return Stack(
      children: <Widget>[
        RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              14,
              14,
              14,
              80 + MediaQuery.paddingOf(context).bottom,
            ),
            children: <Widget>[
              _hero(order, purchase),
              const SizedBox(height: 13),
              Row(
                children: <Widget>[
                  Expanded(
                      child: _stat('عدد البنود', '${_items.length}',
                          Icons.inventory_2_rounded)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _stat('أكبر مدة', '$maxPeriod يوم',
                          Icons.schedule_rounded)),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          _stat('بدائل', '$alternatives', Icons.tune_rounded)),
                ],
              ),
              const SizedBox(height: 13),
              _summary(order),
              const SizedBox(height: 13),
              ..._items.asMap().entries.map<Widget>((entry) {
                return _itemCard(entry.value, entry.key);
              }),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _sharePdf,
                    icon: const Icon(Icons.print_rounded),
                    label: Text('طباعة ومشاركة', style: GoogleFonts.cairo()),
                  ),
                  if (_can('canOpenInvoices'))
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => InvoiceDetailsScreen(
                            transactionId: widget.transactionId,
                            username: widget.username,
                            invoiceType: purchase ? 'Purchase' : 'Sale',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: Text('فتح الفاتورة', style: GoogleFonts.cairo()),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold)),
            ),
          ),
      ],
    );
  }

  Widget _hero(Map<String, dynamic> order, bool purchase) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF3B82F6)
          ],
        ),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              purchase ? Icons.local_shipping_rounded : Icons.factory_rounded,
              color: AppColors.gold,
              size: 27,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  purchase ? 'أمر توريد' : 'أمر تشغيل فاتورة',
                  style: GoogleFonts.cairo(
                    color: AppColors.goldLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${order['ReferenceNumber'] ?? '#${widget.transactionId}'}',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${order['PartyName'] ?? ''}',
                  style: GoogleFonts.cairo(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ),
          _badge(
            order['IsDelivered'] == true || order['IsDelivered'] == 1
                ? 'تم التسليم'
                : 'غير مسلّم',
            order['IsDelivered'] == true || order['IsDelivered'] == 1
                ? Colors.green
                : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: AppColors.goldDark, size: 19),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: _textColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label,
              style:
                  GoogleFonts.cairo(color: _secondaryTextColor, fontSize: 8.5)),
        ],
      ),
    );
  }

  Widget _summary(Map<String, dynamic> order) {
    final purchase = '${order['TransactionType']}' == 'Purchase';
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _info(
            purchase ? Icons.factory_rounded : Icons.person_rounded,
            purchase
                ? 'المورد: ${order['PartyName'] ?? ''}'
                : '${order['PartyName'] ?? ''}',
          ),
          _info(Icons.phone_rounded, '${order['Phone'] ?? '—'}'),
          if (purchase &&
              '${order['LinkedCustomerName'] ?? ''}'.trim().isNotEmpty)
            _info(
              Icons.person_outline_rounded,
              'العميل المرتبط: ${order['LinkedCustomerName']}',
            )
          else if (!purchase)
            _info(Icons.badge_rounded, '${order['EmpName'] ?? '—'}'),
          _info(Icons.calendar_today_rounded, _date(order['TransactionDate'])),
          _info(Icons.event_available_rounded, _date(order['DueDate'])),
          _info(Icons.warehouse_rounded, '${order['WarehouseName'] ?? '—'}'),
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item, int index) {
    final imageUrl = _imageUrl(item);
    final hasAlternative = item['SelectedAlternativeID'] != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InkWell(
                onTap: imageUrl == null
                    ? null
                    : () => _previewImage(imageUrl, '${item['ProductName']}'),
                child: Container(
                  width: 82,
                  height: 82,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.inputFill(_isDark),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: imageUrl == null
                      ? const Icon(Icons.inventory_2_outlined)
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.inventory_2_outlined),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${item['ProductName'] ?? ''}',
                            style: GoogleFonts.cairo(
                              color: _textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '#${item['ProductID']}',
                          style: GoogleFonts.cairo(
                            color: _secondaryTextColor,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: <Widget>[
                        _badge(_tier('${item['PricingTier']}'), Colors.blue),
                        _badge(
                          hasAlternative ? 'بديل مختار' : 'الأصلي الحالي',
                          hasAlternative ? Colors.green : Colors.blueGrey,
                        ),
                        _badge('${_num(item['Quantity'])} قطعة', Colors.purple),
                        if (_int(item['Period']) > 0)
                          _badge('${_int(item['Period'])} يوم', Colors.orange),
                      ],
                    ),
                    if (hasAlternative &&
                        '${item['AlternativeName'] ?? ''}'
                            .isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'المواصفة: ${item['AlternativeName']}',
                        style: GoogleFonts.cairo(
                          color: Colors.green.shade700,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _noteBox(
              'وصف البند', '${item['ProductDescription'] ?? 'لا يوجد وصف.'}'),
          const SizedBox(height: 7),
          _noteBox(
            'ملاحظات التصنيع',
            '${item['ManufacturingDescription'] ?? 'لا توجد ملاحظات تصنيع.'}',
          ),
          if ('${item['Notes'] ?? ''}'.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 7),
            _noteBox('ملاحظات البند', '${item['Notes']}'),
          ],
          if (item['PdfPath'] != null || item['HasOldPdf'] == true) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openProductPdf(item),
                icon:
                    const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                label: Text('فتح PDF المنتج', style: GoogleFonts.cairo()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _imageUrl(Map<String, dynamic> item) {
    final alt = '${item['AlternativeImagePath'] ?? ''}'.trim();
    if (alt.isNotEmpty) {
      if (alt.startsWith('http')) return alt;
      return '$baseUrl${alt.startsWith('/') ? '' : '/'}$alt';
    }
    final imageId = _int(item['MainImageId']);
    return imageId > 0 ? '$baseUrl/api/product-image-by-id/$imageId' : null;
  }

  Widget _noteBox(String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.cairo(
              color: AppColors.goldDark,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            text,
            style: GoogleFonts.cairo(
              color: _secondaryTextColor,
              fontSize: 10.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.goldDark, size: 13),
          const SizedBox(width: 4),
          Text(text,
              style:
                  GoogleFonts.cairo(color: _secondaryTextColor, fontSize: 9)),
        ],
      ),
    );
  }

  String _tier(String value) {
    return switch (value) {
      'CClass' => 'ستاندرد',
      'Elite' => 'إيليت',
      _ => 'بريميوم',
    };
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? '—' : DateFormat('yyyy/MM/dd').format(date.toLocal());
  }

  Future<void> _previewImage(String url, String title) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        title,
                        style: GoogleFonts.cairo(color: Colors.white),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  child: Center(child: Image.network(url, fit: BoxFit.contain)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openProductPdf(Map<String, dynamic> item) async {
    final productId = _int(item['ProductID']);
    final path = '${item['PdfPath'] ?? ''}'.trim();
    final uri = path.isNotEmpty
        ? Uri.parse(path.startsWith('http')
            ? path
            : '$baseUrl${path.startsWith('/') ? '' : '/'}$path')
        : Uri.parse('$baseUrl/api/products/$productId/pdf');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sharePdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final purchase = '${_order?['TransactionType']}' == 'Purchase';
      final documentName = purchase ? 'أمر توريد' : 'أمر تشغيل';
      final file = await _buildPdf();
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
          subject: '$documentName ${_order?['ReferenceNumber'] ?? ''}',
          text:
              '$documentName ${_order?['ReferenceNumber'] ?? ''} - ${_order?['PartyName'] ?? ''}',
        ),
      );
    } catch (error) {
      if (mounted) _message('تعذر إنشاء أمر التشغيل: $error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _buildPdf() async {
    final purchase = '${_order?['TransactionType']}' == 'Purchase';
    final regularData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final logoData = await rootBundle.load('assets/images/logo.png');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final imageMap = <int, pw.MemoryImage>{};
    for (final item in _items) {
      final url = _imageUrl(item);
      if (url == null) continue;
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          imageMap[_int(item['ProductID'])] =
              pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {}
    }
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (_) => pw.Column(
          children: <pw.Widget>[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Row(
                  children: <pw.Widget>[
                    pw.Image(logo, width: 45, height: 45),
                    pw.SizedBox(width: 8),
                    pw.Text('COCOBOLO',
                        style: pw.TextStyle(font: bold, fontSize: 15)),
                  ],
                ),
                pw.Column(
                  children: <pw.Widget>[
                    pw.Text(
                      purchase ? 'أمر توريد المصنع' : 'أمر تشغيل الفاتورة',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 17,
                        color: const PdfColor.fromInt(0xFF1E3A8A),
                      ),
                    ),
                    pw.Text(
                      '${_order?['ReferenceNumber'] ?? ''}',
                      style: pw.TextStyle(font: bold, fontSize: 10),
                    ),
                  ],
                ),
                pw.Text(
                  _date(_order?['TransactionDate']),
                  style: pw.TextStyle(font: regular, fontSize: 8),
                ),
              ],
            ),
            pw.Divider(color: const PdfColor.fromInt(0xFF0F172A)),
          ],
        ),
        build: (_) => <pw.Widget>[
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF8FAFC),
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text(
                  '${purchase ? 'المورد' : 'العميل'}: ${_order?['PartyName'] ?? ''}',
                ),
                pw.Text(
                  '${purchase ? 'العميل المرتبط' : 'الموظف'}: ${_order?['EmpName'] ?? '—'}',
                ),
                pw.Text('التسليم المتوقع: ${_date(_order?['DueDate'])}'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          ..._items.asMap().entries.map<pw.Widget>((entry) {
            final item = entry.value;
            final productId = _int(item['ProductID']);
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Container(
                    width: 80,
                    height: 80,
                    alignment: pw.Alignment.center,
                    color: PdfColors.grey100,
                    child: imageMap[productId] == null
                        ? pw.Text('بدون صورة',
                            style: pw.TextStyle(font: regular, fontSize: 7))
                        : pw.Image(imageMap[productId]!, fit: pw.BoxFit.cover),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        pw.Text(
                          '${entry.key + 1}. ${item['ProductName'] ?? ''}',
                          style: pw.TextStyle(font: bold, fontSize: 11),
                        ),
                        pw.Text(
                          'الكود: #$productId | الكمية: ${_num(item['Quantity'])} | الباقة: ${_tier('${item['PricingTier']}')}',
                          style: pw.TextStyle(font: regular, fontSize: 7.5),
                        ),
                        if (item['SelectedAlternativeID'] != null)
                          pw.Text(
                            'المواصفة المختارة: ${item['AlternativeName'] ?? ''}',
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 7.5,
                              color: PdfColors.green700,
                            ),
                          ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'وصف البند: ${item['ProductDescription'] ?? 'لا يوجد وصف.'}',
                          style: pw.TextStyle(font: regular, fontSize: 7.5),
                        ),
                        pw.Text(
                          'ملاحظات التصنيع: ${item['ManufacturingDescription'] ?? 'لا توجد ملاحظات.'}',
                          style: pw.TextStyle(font: regular, fontSize: 7.5),
                        ),
                        if ('${item['Notes'] ?? ''}'.trim().isNotEmpty)
                          pw.Text(
                            'ملاحظات البند: ${item['Notes']}',
                            style: pw.TextStyle(font: regular, fontSize: 7.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
    final directory = await getApplicationDocumentsDirectory();
    final reference = '${_order?['ReferenceNumber'] ?? widget.transactionId}'
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    final file = File('${directory.path}/Job_Order_$reference.pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.cairo()),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }
}
