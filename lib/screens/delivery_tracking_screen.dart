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
import 'package:url_launcher/url_launcher.dart';

import '../services/app_colors.dart';
import '../services/delivery_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_states.dart';
import 'delivery_details_screen.dart';
import 'purchase_receipts_screen.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final int userId;
  final String username;

  const DeliveryTrackingScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final DeliveryService _service = DeliveryService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _employees = <Map<String, dynamic>>[];
  Map<String, dynamic> _stats = <String, dynamic>{};
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _busy = false;
  bool _exporting = false;
  String? _error;
  String _status = 'overdue';
  String _dateType = 'due';
  String _debt = 'all';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _hasMore = false;
  Timer? _debounce;

  bool get _isDark => ThemeService().isDarkMode;
  bool _can(String name) => _capabilities[name] == true;

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
      final data = await _service.getDeliveries(
        status: _status,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        dateFrom: _from,
        dateTo: _to,
        dateFilterType: _dateType,
        debt: _debt,
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
      if (_can('canEditFull') && _employees.isEmpty) {
        try {
          _employees = await _service.getEmployees();
          if (mounted) setState(() {});
        } catch (_) {}
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

  Future<void> _confirm(Map<String, dynamic> row) async {
    final id = _int(row['TransactionID']);
    final remaining = _num(row['RemainingAmount']);
    final pending = row['HasPendingPermissionRequest'] == true;
    final canOverride = _can('canOverrideRemaining');

    if (remaining > 0.005 && !canOverride && pending) {
      _message('طلب إذن التسليم معلّق لدى الإدارة', error: true);
      return;
    }
    if (remaining > 0.005 && !canOverride && !pending) {
      final request = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('مبلغ متبقٍ على الفاتورة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: Text(
            'يوجد مبلغ متبقٍ بقيمة ${_money(remaining)}. يجب الحصول على إذن من الإدارة أو مدير الحسابات قبل التسليم.',
            style: GoogleFonts.cairo(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.approval_rounded, size: 18),
              label: Text('طلب إذن', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      );
      if (request == true) await _requestPermission(id);
      return;
    }

    int? employeeId = row['DeliveryEmployeeId'] is num
        ? (row['DeliveryEmployeeId'] as num).toInt()
        : null;
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('تأكيد التسليم',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'تأكيد تسليم ${row['ReferenceNumber'] ?? '#$id'} إلى ${row['ClientName'] ?? ''}${remaining > 0 ? ' مع وجود مبلغ متبقٍ' : ''}.',
                style: GoogleFonts.cairo(height: 1.5),
              ),
              if (_can('canEditFull') && _employees.isNotEmpty) ...[
                const SizedBox(height: 14),
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
                    ..._employees.map((employee) => DropdownMenuItem<int?>(
                          value: _int(employee['EmployeeID']),
                          child: Text('${employee['FullName'] ?? ''}',
                              style: GoogleFonts.cairo()),
                        )),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => employeeId = value),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
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
              label: Text('تم التسليم', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => _service.confirmDelivery(
          id: id,
          deliveryEmployeeId: employeeId,
          notes: notesController.text.trim(),
        ));
  }

  Future<void> _requestPermission(int id) async {
    await _run(() => _service.requestPermission(id));
  }

  Future<void> _grantPermission(Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('منح إذن التسليم',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        content: Text(
          'السماح بتسليم ${row['ReferenceNumber'] ?? '#${row['TransactionID']}'} رغم وجود مبلغ متبقٍ؟',
          style: GoogleFonts.cairo(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('منح الإذن', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (yes == true) {
      await _run(() => _service.grantPermission(_int(row['TransactionID'])));
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

  Future<void> _pickDate(bool from) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null) return;
    setState(() {
      if (from) {
        _from = date;
      } else {
        _to = date;
      }
    });
    await _load();
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    await launchUrl(Uri.parse('tel:${phone.trim()}'));
  }

  Future<void> _whatsapp(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    var value = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.startsWith('0')) value = '2$value';
    await launchUrl(Uri.parse('https://wa.me/$value'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _exportDailySheet() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final rows = await _service.getDailySheet(
        dateFrom: _from,
        dateTo: _to,
        search: _searchController.text.trim(),
      );
      final regularData =
          await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
      final regular = pw.Font.ttf(regularData);
      final bold = pw.Font.ttf(boldData);
      final document = pw.Document();
      document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (_) => pw.Column(children: [
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('كشف التسليمات غير المسلّمة',
                    style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: const PdfColor.fromInt(0xFF13273F))),
                pw.Text(DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now()),
                    style: pw.TextStyle(font: regular, fontSize: 8)),
              ]),
          pw.Divider(color: const PdfColor.fromInt(0xFFDBBF74), thickness: 1.5),
        ]),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: [
              '#',
              'الفاتورة',
              'العميل',
              'الهاتف',
              'العنوان',
              'موعد التسليم',
              'الحالة',
              'المندوب'
            ],
            data: rows.asMap().entries.map((entry) {
              final row = entry.value;
              return [
                '${entry.key + 1}',
                '${row['ReferenceNumber'] ?? '#${row['TransactionID']}'}',
                '${row['PartyName'] ?? ''}',
                '${row['Phone'] ?? '—'}',
                '${row['Address'] ?? '—'}',
                _date(row['DueDate']),
                _statusLabel('${row['DeliveryStatus'] ?? ''}'),
                '${row['DeliveryEmployeeName'] ?? '—'}',
              ];
            }).toList(),
            headerStyle:
                pw.TextStyle(font: bold, fontSize: 7, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF13273F)),
            cellStyle: pw.TextStyle(font: regular, fontSize: 6.5),
            cellAlignment: pw.Alignment.centerRight,
          ),
        ],
        footer: (_) => pw.Center(
          child: pw.Text('كشف تشغيلي بدون مبالغ مالية',
              style: pw.TextStyle(
                  font: regular, fontSize: 7, color: PdfColors.grey600)),
        ),
      ));
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/Delivery_Sheet_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
      await file.writeAsBytes(await document.save(), flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        text: 'كشف التسليمات غير المسلّمة',
      ));
    } catch (error) {
      if (mounted) _message('تعذر إنشاء الكشف: $error', error: true);
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
        title: Text('متابعة التسليمات',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        actions: [
          if (_can('canViewPurchaseReceipts'))
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PurchaseReceiptsScreen(
                    userId: widget.userId,
                    username: widget.username,
                  ),
                ),
              ),
              icon: const Icon(Icons.inventory_rounded),
              tooltip: 'استلامات الشراء',
            ),
          if (_can('canPrint'))
            IconButton(
              onPressed: _exporting ? null : _exportDailySheet,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'كشف التسليمات',
            ),
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(children: [
        if (_loading)
          const AppLoading(message: 'جاري تحميل التسليمات')
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
                    message: 'لا توجد تسليمات مطابقة',
                    hint: 'غيّر الفلاتر أو حدّث البيانات',
                    icon: Icons.local_shipping_outlined,
                    onRefresh: _load,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 24),
                  sliver: SliverList.builder(
                    itemCount: _rows.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (index == _rows.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _loadingMore
                                ? const CircularProgressIndicator()
                                : OutlinedButton.icon(
                                    onPressed: () => _load(append: true),
                                    icon: const Icon(Icons.expand_more_rounded),
                                    label: Text('تحميل المزيد',
                                        style: GoogleFonts.cairo()),
                                  ),
                          ),
                        );
                      }
                      return _card(_rows[index]);
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
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.32)),
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
            child: const Icon(Icons.local_shipping_rounded,
                color: AppColors.gold, size: 27),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مركز التسليم',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              Text('المواعيد، التحصيل، الأذونات، وتأكيد التسليم',
                  style:
                      GoogleFonts.cairo(color: Colors.white60, fontSize: 10.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _stat('الكل', _stats['TotalCount'], Icons.list_alt_rounded,
                AppColors.gold, 'all'),
            _stat('متأخر', _stats['Overdue'], Icons.warning_rounded,
                AppColors.error, 'overdue'),
            _stat('اليوم', _stats['Today'], Icons.today_rounded,
                AppColors.warning, 'today'),
            _stat('قريب', _stats['Soon'], Icons.schedule_rounded,
                AppColors.info, 'soon'),
            _stat('تم التسليم', _stats['Delivered'], Icons.check_circle_rounded,
                AppColors.success, 'delivered'),
          ]),
        ),
        if (_can('canSeeAmounts')) ...[
          const SizedBox(height: 12),
          Row(children: [
            _amount('الإجمالي', _stats['TotalGrandTotal']),
            _amount('المدفوع', _stats['TotalPaidAmount']),
            _amount('المتبقي', _stats['TotalRemaining']),
          ]),
        ] else ...[
          const SizedBox(height: 11),
          Row(children: [
            const Icon(Icons.lock_outline_rounded,
                size: 14, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              'الفواتير التي عليها مديونية: ${_int(_stats['WithRemainingCount'])}',
              style: GoogleFonts.cairo(color: Colors.white60, fontSize: 10),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _stat(
      String label, dynamic value, IconData icon, Color color, String status) {
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
          width: 96,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: active ? color : Colors.white12),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 17),
            Text('${_int(value)}',
                style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
            Text(label,
                maxLines: 1,
                style: GoogleFonts.cairo(color: Colors.white60, fontSize: 8.5)),
          ]),
        ),
      ),
    );
  }

  Widget _amount(String label, dynamic value) => Expanded(
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
            hintText: 'العميل، الهاتف، أو رقم الفاتورة',
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
            child: DropdownButtonFormField<String>(
              initialValue: _dateType,
              decoration: InputDecoration(
                labelText: 'نوع التاريخ',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'due', child: Text('موعد التسليم')),
                DropdownMenuItem(
                    value: 'invoice', child: Text('تاريخ الفاتورة')),
                DropdownMenuItem(
                    value: 'delivered', child: Text('تاريخ التسليم')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _dateType = value);
                _load();
              },
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _debt,
              decoration: InputDecoration(
                labelText: 'التحصيل',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('الكل')),
                DropdownMenuItem(
                    value: 'remaining', child: Text('عليها متبقي')),
                DropdownMenuItem(value: 'settled', child: Text('مسددة')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _debt = value);
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
    final status = '${row['DeliveryStatus'] ?? 'upcoming'}';
    final delivered = status == 'delivered';
    final color = _statusColor(status);
    final remaining = _num(row['RemainingAmount']);
    final pending = row['HasPendingPermissionRequest'] == true;
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
                delivered
                    ? Icons.check_circle_rounded
                    : Icons.local_shipping_rounded,
                color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['ClientName'] ?? '—'}',
                  style: GoogleFonts.cairo(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              Text('${row['ReferenceNumber'] ?? '#${row['TransactionID']}'}',
                  style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(_isDark), fontSize: 10)),
            ]),
          ),
          _badge(_statusLabel(status), color),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 7, children: [
          _chip(Icons.event_rounded, _date(row['DueDate'])),
          if ((row['DeliveryEmployeeName'] ?? '').toString().isNotEmpty)
            _chip(Icons.person_rounded, '${row['DeliveryEmployeeName']}'),
          if (_can('canSeeAmounts'))
            _chip(Icons.payments_outlined,
                remaining > 0 ? 'متبقي ${_money(remaining)}' : 'مسددة',
                color: remaining > 0 ? AppColors.error : AppColors.success),
          if (pending)
            _chip(Icons.hourglass_top_rounded, 'إذن التسليم معلّق',
                color: AppColors.warning),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeliveryDetailsScreen(
                  transactionId: _int(row['TransactionID']),
                  username: widget.username,
                ),
              ),
            ).then((_) => _load()),
            icon: const Icon(Icons.visibility_rounded),
            tooltip: 'التفاصيل',
          ),
          if ((row['Phone'] ?? '').toString().isNotEmpty) ...[
            IconButton(
              onPressed: () => _call('${row['Phone']}'),
              icon: const Icon(Icons.call_rounded, color: AppColors.success),
              tooltip: 'اتصال',
            ),
            IconButton(
              onPressed: () => _whatsapp('${row['Phone']}'),
              icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
              tooltip: 'واتساب',
            ),
          ],
          const Spacer(),
          if (!delivered && pending && _can('canOverrideRemaining'))
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _grantPermission(row),
              icon: const Icon(Icons.approval_rounded, size: 16),
              label: Text('منح الإذن', style: GoogleFonts.cairo(fontSize: 10)),
            ),
          if (!delivered && _can('canConfirmDelivery')) ...[
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: _busy ? null : () => _confirm(row),
              icon: const Icon(Icons.check_circle_rounded, size: 17),
              label: Text('تسليم', style: GoogleFonts.cairo(fontSize: 10)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20)),
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
