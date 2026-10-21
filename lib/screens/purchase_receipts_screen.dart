import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../services/app_colors.dart';
import '../services/purchase_receipt_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_states.dart';
import 'invoice/invoice_details_screen.dart';
import 'job_order_details_screen.dart';

class PurchaseReceiptsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? initialTransactionId;

  const PurchaseReceiptsScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialTransactionId,
  });

  @override
  State<PurchaseReceiptsScreen> createState() => _PurchaseReceiptsScreenState();
}

class _PurchaseReceiptsScreenState extends State<PurchaseReceiptsScreen> {
  final PurchaseReceiptService _service = PurchaseReceiptService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  Map<String, dynamic> _stats = <String, dynamic>{};
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _busy = false;
  String? _error;
  String _status = 'all';
  String _dateType = 'DueDate';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _hasMore = false;
  Timer? _debounce;
  bool _openedInitial = false;

  bool get _isDark => ThemeService().isDarkMode;
  bool _can(String key) => _capabilities[key] == true;

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
      final data = await _service.getReceipts(
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        status: _status,
        dateFrom: _from,
        dateTo: _to,
        dateFilterType: _dateType,
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
          widget.initialTransactionId != null &&
          widget.initialTransactionId! > 0) {
        _openedInitial = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showDetails(<String, dynamic>{
              'TransactionID': widget.initialTransactionId,
            });
          }
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

  Future<void> _pickDate({required bool from}) async {
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

  Future<void> _confirm(Map<String, dynamic> row) async {
    if (!_can('canConfirmReceipt') || row['IsDelivered'] == true) return;
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تأكيد استلام فاتورة الشراء',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيتم إدخال جميع أصناف ${row['ReferenceNumber'] ?? '#${row['TransactionID']}'} إلى مخزن ${row['WarehouseName'] ?? ''}.',
              style: GoogleFonts.cairo(height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesController,
              maxLines: 3,
              style: GoogleFonts.cairo(),
              decoration: InputDecoration(
                labelText: 'ملاحظات الاستلام',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.inventory_rounded, size: 18),
            label: Text('تأكيد الاستلام', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await _service.confirmReceipt(
        id: _int(row['TransactionID']),
        notes: notesController.text.trim(),
      );
      if (!mounted) return;
      _toast('${result['message'] ?? 'تم الاستلام بنجاح'}', true);
      await _load();
    } catch (error) {
      if (mounted) _toast(error.toString(), false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.cairo()),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
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
    );
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Text('استلامات الشراء',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_loading)
            const AppLoading(message: 'جاري تحميل استلامات الشراء')
          else if (_error != null)
            AppError(message: _error!, onRetry: _load)
          else
            RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverToBoxAdapter(child: _filters()),
                  if (_rows.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmpty(
                        message: 'لا توجد استلامات شراء',
                        hint: 'غيّر الفلاتر أو حدّث البيانات',
                        icon: Icons.inventory_2_outlined,
                        onRefresh: _load,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      sliver: SliverList.builder(
                        itemCount: _rows.length + (_hasMore ? 1 : 0),
                        itemBuilder: (_, index) {
                          if (index == _rows.length) {
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: Center(
                                child: _loadingMore
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton.icon(
                                        onPressed: () => _load(append: true),
                                        icon: const Icon(Icons.expand_more),
                                        label: Text('تحميل المزيد',
                                            style: GoogleFonts.cairo()),
                                      ),
                              ),
                            );
                          }
                          return _receiptCard(_rows[index]);
                        },
                      ),
                    ),
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
        ],
      ),
    );
  }

  Widget _header() {
    final canSeeAmounts = _can('canSeeAmounts');
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.inventory_rounded,
                  color: AppColors.gold, size: 26),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('متابعة توريدات المعرض',
                      style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17)),
                  Text('تأكيد الاستلام وإضافة الأصناف إلى المخزون',
                      style: GoogleFonts.cairo(
                          color: Colors.white60, fontSize: 10.5)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _stat('الكل', _stats['TotalCount'], Icons.list_alt_rounded,
                  AppColors.gold, 'all'),
              _stat('بانتظار الاستلام', _stats['PendingCount'],
                  Icons.pending_actions_rounded, AppColors.warning, 'pending'),
              _stat('تم الاستلام', _stats['ReceivedCount'],
                  Icons.inventory_rounded, AppColors.success, 'received'),
              _stat('متأخر', _stats['OverdueCount'], Icons.warning_rounded,
                  AppColors.error, 'overdue'),
            ]),
          ),
          if (canSeeAmounts) ...[
            const SizedBox(height: 12),
            Row(children: [
              _amount('الإجمالي', _stats['TotalGrandTotal']),
              _amount('المدفوع', _stats['TotalPaidAmount']),
              _amount('المتبقي', _stats['TotalRemaining']),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    dynamic value,
    IconData icon,
    Color color,
    String status,
  ) {
    final active = _status == status;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: () {
          setState(() => _status = status);
          _load();
        },
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 112,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.23)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: active ? color : Colors.white12),
          ),
          child: Row(children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_int(value)}',
                      style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                          color: Colors.white60, fontSize: 8.5)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _amount(String label, dynamic value) {
    return Expanded(
      child: Column(children: [
        Text(_money(value),
            style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12)),
        Text(label,
            style: GoogleFonts.cairo(color: Colors.white54, fontSize: 9)),
      ]),
    );
  }

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
            hintText: 'ابحث بالمورد أو الفاتورة أو المخزن',
            hintStyle: GoogleFonts.cairo(fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _load();
                    },
                    icon: const Icon(Icons.clear_rounded),
                  ),
            filled: true,
            fillColor: AppColors.inputFill(_isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _dateType,
              decoration: InputDecoration(
                labelText: 'نوع التاريخ',
                labelStyle: GoogleFonts.cairo(fontSize: 11),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'DueDate', child: Text('موعد الاستلام')),
                DropdownMenuItem(
                    value: 'InvoiceDate', child: Text('تاريخ الفاتورة')),
                DropdownMenuItem(
                    value: 'ReceivedDate', child: Text('تاريخ الاستلام')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _dateType = value);
                _load();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: _dateButton('من', _from, () => _pickDate(from: true))),
          const SizedBox(width: 8),
          Expanded(
              child: _dateButton('إلى', _to, () => _pickDate(from: false))),
        ]),
        if (_from != null || _to != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _from = null;
                  _to = null;
                });
                _load();
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label:
                  Text('مسح التاريخ', style: GoogleFonts.cairo(fontSize: 11)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_month_rounded, size: 16),
      label: Text(date == null ? label : DateFormat('MM/dd').format(date),
          style: GoogleFonts.cairo(fontSize: 10)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }

  Widget _receiptCard(Map<String, dynamic> row) {
    final status = '${row['ReceiptStatus'] ?? ''}';
    final received = row['IsDelivered'] == true || status == 'تم الاستلام';
    final overdue = status == 'متأخر';
    final color = received
        ? AppColors.success
        : overdue
            ? AppColors.error
            : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.32)),
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
            child: Icon(
                received
                    ? Icons.inventory_rounded
                    : Icons.local_shipping_rounded,
                color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['SupplierName'] ?? 'المصنع'}',
                  style: GoogleFonts.cairo(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              Text('${row['ReferenceNumber'] ?? '#${row['TransactionID']}'}',
                  style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(_isDark), fontSize: 10)),
            ]),
          ),
          _badge(status, color),
        ]),
        const SizedBox(height: 11),
        Wrap(spacing: 8, runSpacing: 7, children: [
          _chip(Icons.warehouse_rounded, '${row['WarehouseName'] ?? '—'}'),
          _chip(Icons.inventory_2_outlined, '${_int(row['ItemsCount'])} صنف'),
          _chip(Icons.event_rounded, _date(row['DueDate'])),
          if (_can('canSeeAmounts'))
            _chip(Icons.payments_outlined, _money(row['GrandTotal']),
                color: AppColors.goldDark),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton.icon(
            onPressed: () => _showDetails(row),
            icon: const Icon(Icons.visibility_rounded, size: 17),
            label: Text('التفاصيل', style: GoogleFonts.cairo(fontSize: 10)),
          ),
          const SizedBox(width: 7),
          IconButton(
            onPressed: () => _openJobOrder(row),
            icon: const Icon(Icons.factory_rounded),
            tooltip: 'أمر التوريد',
          ),
          if (_can('canOpenInvoice'))
            IconButton(
              onPressed: () => _openInvoice(row),
              icon: const Icon(Icons.receipt_long_rounded),
              tooltip: 'الفاتورة',
            ),
          const Spacer(),
          if (!received && _can('canConfirmReceipt'))
            FilledButton.icon(
              onPressed: _busy ? null : () => _confirm(row),
              icon: const Icon(Icons.inventory_rounded, size: 17),
              label: Text('استلام', style: GoogleFonts.cairo(fontSize: 11)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ]),
      ]),
    );
  }

  Future<void> _showDetails(Map<String, dynamic> row) async {
    setState(() => _busy = true);
    try {
      final detail = await _service.getReceipt(_int(row['TransactionID']));
      if (!mounted) return;
      setState(() => _busy = false);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card(_isDark),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          maxChildSize: 0.94,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(18),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider(_isDark),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('تفاصيل استلام ${detail['ReferenceNumber'] ?? ''}',
                  style: GoogleFonts.cairo(
                      color: AppColors.text(_isDark),
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _detailLine('المورد', detail['SupplierName']),
              _detailLine('المخزن', detail['WarehouseName']),
              _detailLine('موعد الاستلام', _date(detail['DueDate'])),
              _detailLine('الحالة', detail['ReceiptStatus']),
              if (_can('canSeeAmounts')) ...[
                _detailLine('الإجمالي', _money(detail['GrandTotal'])),
                _detailLine('المتبقي', _money(detail['RemainingAmount'])),
              ],
              const Divider(height: 28),
              Text('الأصناف',
                  style: GoogleFonts.cairo(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final raw in (detail['items'] as List? ?? const []))
                Builder(builder: (_) {
                  final item = _map(raw);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined,
                        color: AppColors.goldDark),
                    title: Text('${item['ProductName'] ?? '—'}',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    subtitle: Text('الكمية: ${item['Quantity'] ?? 0}',
                        style: GoogleFonts.cairo(fontSize: 11)),
                    trailing: _can('canSeeAmounts')
                        ? Text(_money(item['TotalAmount']),
                            style:
                                GoogleFonts.cairo(fontWeight: FontWeight.w700))
                        : null,
                  );
                }),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(error.toString(), false);
      }
    }
  }

  Widget _detailLine(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
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

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: GoogleFonts.cairo(
                color: color, fontSize: 9, fontWeight: FontWeight.w800)),
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

  String _money(dynamic value) =>
      '${NumberFormat('#,##0.00').format(_num(value))} ج.م';

  String _date(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? 'غير محدد' : DateFormat('yyyy/MM/dd').format(date);
  }
}
