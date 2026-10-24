import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_colors.dart';
import '../services/factory_purchase_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_states.dart';
import 'factory_purchase_form_screen.dart';
import 'invoice/invoice_details_screen.dart';
import 'job_order_details_screen.dart';

class FactoryPurchasesScreen extends StatefulWidget {
  final int userId;
  final String username;

  const FactoryPurchasesScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<FactoryPurchasesScreen> createState() => _FactoryPurchasesScreenState();
}

class _FactoryPurchasesScreenState extends State<FactoryPurchasesScreen> {
  final FactoryPurchaseService _service = FactoryPurchaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  Map<String, dynamic> _stats = <String, dynamic>{};
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _busy = false;
  bool _exporting = false;
  String? _error;
  String? _status;
  String _receipt = 'all';
  bool _overdue = false;
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _hasMore = false;
  Timer? _debounce;

  bool get _isDark => ThemeService().isDarkMode;
  bool _can(String key) => _capabilities[key] == true;

  static const Map<String, String> _statusNames = <String, String>{
    'Open': 'مفتوحة',
    'PartiallyPaid': 'مدفوعة جزئيًا',
    'Paid': 'مدفوعة',
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
      final data = await _service.getPurchases(
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        dateFrom: _from,
        dateTo: _to,
        status: _status,
        receipt: _receipt,
        overdue: _overdue,
        page: append ? _page + 1 : 1,
      );
      final incoming = ((data['rows'] as List?) ?? const <dynamic>[])
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
      lastDate: DateTime.now().add(const Duration(days: 730)),
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

  Future<void> _openCreate() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FactoryPurchaseFormScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    );
    if (changed == true || mounted) await _load();
  }

  void _openInvoice(Map<String, dynamic> row) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailsScreen(
          transactionId: _int(row['TransactionID']),
          username: widget.username,
          invoiceType: 'Purchase',
        ),
      ),
    ).then((_) => _load());
  }

  void _openJobOrder(Map<String, dynamic> row) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobOrderDetailsScreen(
          userId: widget.userId,
          username: widget.username,
          transactionId: _int(row['TransactionID']),
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _receive(Map<String, dynamic> row) async {
    if (!_can('canReceive') || row['IsDelivered'] == true) return;
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تأكيد استلام توريد المصنع',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'سيتم إدخال ${_int(row['ItemsCount'])} صنف إلى مخزن ${row['WarehouseName'] ?? ''} وإغلاق أمر التوريد.',
            style: GoogleFonts.cairo(height: 1.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notes,
            maxLines: 3,
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
              labelText: 'ملاحظات الاستلام',
              labelStyle: GoogleFonts.cairo(),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.inventory_rounded),
            label: Text('تأكيد الاستلام', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _service.receive(
          _int(row['TransactionID']),
          notes: notes.text.trim(),
        ));
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    if (!_can('canCancel')) return;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إلغاء فاتورة شراء المصنع',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            row['IsDelivered'] == true
                ? 'الفاتورة مستلمة. سيتم عكس المخزون فقط إذا كان الرصيد الحالي يسمح بذلك.'
                : 'سيتم إغلاق الفاتورة وأمر التوريد.',
            style: GoogleFonts.cairo(height: 1.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reason,
            maxLines: 3,
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
              labelText: 'سبب الإلغاء *',
              labelStyle: GoogleFonts.cairo(),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('رجوع', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (reason.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: Text('إلغاء الفاتورة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _service.cancel(
          _int(row['TransactionID']),
          reason: reason.text.trim(),
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

  Future<void> _export() async {
    if (_exporting || _rows.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final workbook = excel.Excel.createExcel();
      if (workbook.sheets.containsKey('Sheet1')) workbook.delete('Sheet1');
      final sheet = workbook['فواتير شراء المصنع'];
      sheet.appendRow(<excel.CellValue>[
        excel.TextCellValue('رقم الفاتورة'),
        excel.TextCellValue('التاريخ'),
        excel.TextCellValue('موعد الاستلام'),
        excel.TextCellValue('المخزن'),
        excel.TextCellValue('العميل المرتبط'),
        excel.TextCellValue('الأصناف'),
        excel.TextCellValue('الكمية'),
        excel.TextCellValue('الحالة المالية'),
        excel.TextCellValue('حالة الاستلام'),
        if (_can('canSeeAmounts')) excel.TextCellValue('الإجمالي'),
        if (_can('canSeeAmounts')) excel.TextCellValue('المدفوع'),
        if (_can('canSeeAmounts')) excel.TextCellValue('المتبقي'),
      ]);
      for (final row in _rows) {
        sheet.appendRow(<excel.CellValue>[
          excel.TextCellValue(
              '${row['ReferenceNumber'] ?? '#${row['TransactionID']}'}'),
          excel.TextCellValue(_date(row['TransactionDate'])),
          excel.TextCellValue(_date(row['DueDate'])),
          excel.TextCellValue('${row['WarehouseName'] ?? ''}'),
          excel.TextCellValue('${row['LinkedCustomerName'] ?? ''}'),
          excel.IntCellValue(_int(row['ItemsCount'])),
          excel.DoubleCellValue(_num(row['TotalQuantity'])),
          excel.TextCellValue(_statusName('${row['InvoiceStatus'] ?? 'Open'}')),
          excel.TextCellValue('${row['ReceiptStatus'] ?? ''}'),
          if (_can('canSeeAmounts'))
            excel.DoubleCellValue(_num(row['GrandTotal'])),
          if (_can('canSeeAmounts'))
            excel.DoubleCellValue(_num(row['PaidAmount'])),
          if (_can('canSeeAmounts'))
            excel.DoubleCellValue(_num(row['RemainingAmount'])),
        ]);
      }
      final bytes = workbook.save();
      if (bytes == null) throw StateError('تعذر إنشاء ملف Excel');
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/FactoryPurchases_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: <XFile>[
          XFile(file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
        ],
        text: 'فواتير شراء المصنع',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Text('فواتير شراء المصنع',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _exporting ? null : _export,
            icon: const Icon(Icons.file_download_rounded),
            tooltip: 'تصدير Excel',
          ),
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: !_loading && _can('canCreate')
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _openCreate,
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navyDark,
              icon: const Icon(Icons.add_rounded),
              label: Text('فاتورة شراء',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
            )
          : null,
      body: Stack(children: [
        if (_loading)
          const AppLoading(message: 'جاري تحميل فواتير شراء المصنع')
        else if (_error != null)
          AppError(message: _error!, onRetry: _load)
        else
          RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _hero()),
              SliverToBoxAdapter(child: _filters()),
              if (_rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmpty(
                    message: 'لا توجد فواتير شراء مصنع مطابقة',
                    hint: 'غيّر الفلاتر أو أنشئ فاتورة جديدة',
                    icon: Icons.factory_outlined,
                    onRefresh: _load,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
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
                      return _purchaseCard(_rows[index]);
                    },
                  ),
                ),
            ]),
          ),
        if (_busy || _exporting)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.28),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ]),
    );
  }

  Widget _hero() {
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.factory_rounded,
                color: AppColors.gold, size: 27),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('التوريد والتصنيع للمخزون',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              Text('فاتورة المصنع، أمر التوريد، الاستلام، والمخزون',
                  style:
                      GoogleFonts.cairo(color: Colors.white60, fontSize: 10.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _stat('الكل', _stats['TotalCount'], Icons.receipt_long_rounded,
                AppColors.gold, null, 'all'),
            _stat('اليوم', _stats['TodayCount'], Icons.today_rounded,
                AppColors.info, null, 'all'),
            _stat(
                'بانتظار الاستلام',
                _stats['PendingReceiptCount'],
                Icons.pending_actions_rounded,
                AppColors.warning,
                null,
                'pending'),
            _stat('تم الاستلام', _stats['ReceivedCount'],
                Icons.inventory_rounded, AppColors.success, null, 'received'),
            _stat('متأخرة', _stats['OverdueCount'], Icons.warning_rounded,
                AppColors.error, 'overdue', 'all'),
          ]),
        ),
        if (_can('canSeeAmounts')) ...[
          const SizedBox(height: 12),
          Row(children: [
            _amount('الإجمالي', _stats['TotalAmount']),
            _amount('المدفوع', _stats['TotalPaid']),
            _amount('المتبقي', _stats['TotalRemaining']),
          ]),
        ],
      ]),
    );
  }

  Widget _stat(String label, dynamic value, IconData icon, Color color,
      String? action, String receipt) {
    final active = action == 'overdue' ? _overdue : _receipt == receipt;
    return InkWell(
      onTap: () {
        setState(() {
          if (action == 'overdue') {
            _overdue = !_overdue;
          } else {
            _receipt = receipt;
            _overdue = false;
          }
        });
        _load();
      },
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 112,
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: active ? color : Colors.white12),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          Text('${_int(value)}',
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(color: Colors.white60, fontSize: 8.5)),
        ]),
      ),
    );
  }

  Widget _amount(String label, dynamic value) => Expanded(
        child: Column(children: [
          Text(_money(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: GoogleFonts.cairo(color: Colors.white54, fontSize: 8.5)),
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
            hintText: 'رقم الفاتورة، العميل المرتبط، المخزن',
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
              initialValue: _status,
              decoration: InputDecoration(
                labelText: 'الحالة المالية',
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
          const SizedBox(width: 7),
          Expanded(child: _dateButton('من', _from, () => _pickDate(true))),
          const SizedBox(width: 7),
          Expanded(child: _dateButton('إلى', _to, () => _pickDate(false))),
        ]),
        if (_from != null || _to != null || _overdue || _receipt != 'all')
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _from = null;
                  _to = null;
                  _overdue = false;
                  _receipt = 'all';
                  _status = null;
                });
                _load();
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label:
                  Text('مسح الفلاتر', style: GoogleFonts.cairo(fontSize: 10)),
            ),
          ),
      ]),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap) =>
      OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        ),
        child: Text(date == null ? label : DateFormat('MM/dd').format(date),
            style: GoogleFonts.cairo(fontSize: 9.5)),
      );

  Widget _purchaseCard(Map<String, dynamic> row) {
    final received = row['IsDelivered'] == true;
    final receiptStatus = '${row['ReceiptStatus'] ?? ''}';
    final receiptColor = received
        ? AppColors.success
        : receiptStatus == 'متأخر'
            ? AppColors.error
            : AppColors.warning;
    final invoiceStatus = '${row['InvoiceStatus'] ?? 'Open'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: receiptColor.withValues(alpha: 0.30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: receiptColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
                received ? Icons.inventory_rounded : Icons.factory_rounded,
                color: receiptColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['ReferenceNumber'] ?? '#${row['TransactionID']}'}',
                  style: GoogleFonts.cairo(
                      color: AppColors.text(_isDark),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900)),
              Text(
                row['LinkedCustomerName'] == null
                    ? '${row['SupplierName'] ?? 'المصنع'}'
                    : '${row['SupplierName'] ?? 'المصنع'} — ${row['LinkedCustomerName']}',
                style: GoogleFonts.cairo(
                    color: AppColors.textSecondary(_isDark), fontSize: 9.5),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (_can('canSeeAmounts'))
              Text(_money(row['GrandTotal']),
                  style: GoogleFonts.cairo(
                      color: AppColors.text(_isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            _badge(receiptStatus, receiptColor),
          ]),
        ]),
        const SizedBox(height: 9),
        Wrap(spacing: 7, runSpacing: 6, children: [
          _chip(Icons.warehouse_rounded, '${row['WarehouseName'] ?? '—'}'),
          _chip(Icons.inventory_2_outlined,
              '${_int(row['ItemsCount'])} صنف — كمية ${_num(row['TotalQuantity']).toStringAsFixed(0)}'),
          _chip(Icons.event_rounded, _date(row['DueDate'])),
          _chip(Icons.payments_outlined, _statusName(invoiceStatus),
              color: _invoiceStatusColor(invoiceStatus)),
          if (_int(row['AlternativeItemsCount']) > 0)
            _chip(Icons.tune_rounded,
                '${_int(row['AlternativeItemsCount'])} بديل'),
        ]),
        const SizedBox(height: 9),
        Row(children: [
          IconButton(
            onPressed: _can('canOpenInvoice') ? () => _openInvoice(row) : null,
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'تفاصيل الفاتورة',
          ),
          IconButton(
            onPressed:
                _can('canOpenJobOrder') ? () => _openJobOrder(row) : null,
            icon: const Icon(Icons.factory_rounded),
            tooltip: 'أمر التوريد',
          ),
          const Spacer(),
          if (!received && _can('canReceive'))
            FilledButton.icon(
              onPressed: _busy ? null : () => _receive(row),
              icon: const Icon(Icons.inventory_rounded, size: 17),
              label: Text('استلام', style: GoogleFonts.cairo(fontSize: 10)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
            ),
          if (_can('canCancel'))
            IconButton(
              onPressed: _busy ? null : () => _cancel(row),
              icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
              tooltip: 'إلغاء الفاتورة',
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

  Color _invoiceStatusColor(String status) => switch (status) {
        'Paid' => AppColors.success,
        'PartiallyPaid' => AppColors.warning,
        _ => AppColors.info,
      };

  String _statusName(String status) => _statusNames[status] ?? status;

  String _date(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? 'غير محدد' : DateFormat('yyyy/MM/dd').format(date);
  }

  String _money(dynamic value) =>
      '${NumberFormat('#,##0.00').format(_num(value))} ج.م';
}
