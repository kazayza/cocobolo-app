import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../services/app_colors.dart';
import '../services/delivery_service.dart';
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
    final data = _data!;
    final remaining = _num(data['RemainingAmount']);
    if (remaining > 0 && !_can('canOverrideRemaining')) {
      if (data['HasPendingPermissionRequest'] == true) {
        _message('طلب الإذن ما زال قيد المراجعة', error: true);
      } else if (data['LastPermissionAction'] != 'DeliveryPermissionGranted') {
        await _requestPermission();
      } else {
        await _showConfirmDialog();
      }
      return;
    }
    await _showConfirmDialog();
  }

  Future<void> _showConfirmDialog() async {
    int? employeeId = _data?['DeliveryEmployeeId'] is num
        ? (_data!['DeliveryEmployeeId'] as num).toInt()
        : null;
    final notes =
        TextEditingController(text: '${_data?['DeliveredNotes'] ?? ''}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('تأكيد التسليم',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_can('canEditFull') && _employees.isNotEmpty)
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
                      child:
                          Text('المستخدم الحالي', style: GoogleFonts.cairo()),
                    ),
                    ..._employees.map((employee) => DropdownMenuItem<int?>(
                          value: _int(employee['EmployeeID']),
                          child: Text('${employee['FullName'] ?? ''}',
                              style: GoogleFonts.cairo()),
                        )),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => employeeId = value),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 3,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text('تأكيد', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(() => _service.confirmDelivery(
          id: widget.transactionId,
          deliveryEmployeeId: employeeId,
          notes: notes.text.trim(),
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
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.navyDark,
                  AppColors.navy,
                  AppColors.navyLight
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(22),
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
                    borderRadius: BorderRadius.circular(14),
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
                _badge(_statusLabel(status), color),
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
                      'الكمية: ${product['Quantity'] ?? 0}${(product['AlternativeName'] ?? '').toString().isEmpty ? '' : ' — ${product['AlternativeName']}'}',
                      style: GoogleFonts.cairo(fontSize: 10.5),
                    ),
                    trailing: _can('canSeeAmounts')
                        ? Text(_money(product['TotalAmount']),
                            style:
                                GoogleFonts.cairo(fontWeight: FontWeight.w700))
                        : null,
                  ),
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
                  icon: const Icon(Icons.chat_rounded),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppColors.goldDark, size: 19),
          const SizedBox(width: 7),
          Text(title,
              style: GoogleFonts.cairo(
                  color: AppColors.text(_isDark),
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ]),
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
          Text(_money(value),
              style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: GoogleFonts.cairo(color: Colors.white54, fontSize: 9)),
        ]),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: GoogleFonts.cairo(
                color: color, fontSize: 9, fontWeight: FontWeight.w800)),
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
        'returned' => Colors.purple,
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
