import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/network/api_client.dart';
import '../services/app_colors.dart';
import '../services/cashbox_service.dart';
import '../services/design_tokens.dart';
import '../services/payment_service.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/design_kit.dart';

/// المدفوعات — قائمة بلازور PaymentList بتبويبي بيع/شراء: بحث وفلاتر
/// (تاريخ/طريقة/خزينة)، إحصائيات، نسبة تراكمية لكل دفعة، وسند قبض/صرف
/// مع الطباعة والمشاركة. إجراءات الصف محكومة بمرآة بوابات الخادم:
/// التعديل باتحاد frm_Payments:Edit والأدوار، والحذف بـ
/// frm_Payments:Delete أو Admin حصرًا. كل فشل ظاهر برسالة الخادم.
class PaymentsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String initialType;

  const PaymentsScreen({
    super.key,
    this.userId = 0,
    required this.username,
    this.initialType = 'Sale',
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final PaymentService _service = PaymentService.instance;
  final PermissionService _perms = PermissionService();
  final TextEditingController _searchCtrl = TextEditingController();
  final _moneyFmt = NumberFormat('#,##0.00');

  String _type = 'Sale';
  List<dynamic> _items = [];
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _boxes = [];
  int _totalCount = 0;
  int _page = 1;
  static const int _pageSize = 25;
  bool _loading = true;
  String? _error;

  String? _method;
  int? _cashBoxId;
  DateTime? _from;
  DateTime? _to;

  bool get _isDark => ThemeService().isDarkMode;
  bool get _isPurchase => _type == 'Purchase';

  bool get _canViewPayments =>
      _perms.isAdmin || _perms.canView(FormNames.payments);

  // مرآة payments.canEdit في الخادم (اتحاد بلازور)
  bool _canEditPayment(bool isPurchase) =>
      _perms.isAdmin ||
      _perms.canEdit(FormNames.payments) ||
      _perms.isAccountManager ||
      _perms.isAccount ||
      (!isPurchase && _perms.isSales);

  // مرآة payments.canDelete: Admin أو ادعاء الحذف فقط — بلا بديل أدوار
  bool get _canDeletePayment =>
      _perms.isAdmin || _perms.canDelete(FormNames.payments);

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  String _money(dynamic v) => _moneyFmt.format(_num(v));

  String _date(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('yyyy/MM/dd').format(dt);
  }

  String _dayParam(DateTime? d) =>
      d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

  @override
  void initState() {
    super.initState();
    _type = widget.initialType == 'Purchase' ? 'Purchase' : 'Sale';
    _loadBoxes();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBoxes() async {
    try {
      final boxes = (await CashboxService.getAllCashboxes())
          .where((b) => b['IsActive'] != false)
          .toList();
      if (mounted) setState(() => _boxes = boxes);
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      // قائمة الخزائن مساعدة للفلاتر فقط؛ فشلها لا يمنع عرض المدفوعات
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getPayments(
        type: _type,
        search: _searchCtrl.text,
        from: _from == null ? null : _dayParam(_from),
        to: _to == null ? null : _dayParam(_to),
        method: _method,
        cashBoxId: _cashBoxId,
        page: _page,
        pageSize: _pageSize,
      );
      final stats = await _service.getStats(type: _type);
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List?) ?? [];
        _totalCount = (data['totalCount'] as num?)?.toInt() ?? _items.length;
        _stats = stats;
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

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _applyFilters() {
    _page = 1;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: FormNames.payments),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'المدفوعات',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _anchorHeader(),
          const SizedBox(height: 14),
          _statsStrip(),
          const SizedBox(height: 14),
          _typeTabs(),
          const SizedBox(height: 12),
          _filtersCard(),
          const SizedBox(height: 12),
          _listBody(),
          if (_totalCount > _pageSize) _pager(),
        ],
      ),
    );
  }

  // مرساة الهوية الكحلية: عنوان النوع الحالي وإجمالي الفترة
  Widget _anchorHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_rounded,
                  color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              Text(
                _isPurchase ? 'مدفوعات المشتريات' : 'مقبوضات المبيعات',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_money(_stats['TotalAmount'])} ج',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'إجمالي $_totalCount دفعة (باستثناء الدفعات المقدمة)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
          ),
        ],
      ),
    );
  }

  Widget _statsStrip() {
    return Row(
      children: [
        Expanded(
          child: AppStatCard(
            label: 'اليوم',
            value: '${_money(_stats['TodayAmount'])} ج',
            color: AppColors.info,
            icon: Icons.today_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppStatCard(
            label: 'هذا الشهر',
            value: '${_money(_stats['MonthAmount'])} ج',
            color: AppColors.success,
            icon: Icons.calendar_month_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppStatCard(
            label: 'عدد الخزائن',
            value: '${(_stats['CashBoxesCount'] as num?)?.toInt() ?? 0}',
            color: AppColors.gold,
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
      ],
    );
  }

  Widget _typeTabs() {
    return Row(
      children: [
        Expanded(child: _tabButton('Sale', 'مبيعات', Icons.receipt_rounded)),
        const SizedBox(width: 10),
        Expanded(
            child: _tabButton('Purchase', 'مشتريات', Icons.shopping_bag_rounded)),
      ],
    );
  }

  Widget _tabButton(String type, String label, IconData icon) {
    final selected = _type == type;
    final isDark = _isDark;
    return Material(
      color: selected
          ? AppColors.navy
          : AppColors.surface(isDark),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          if (_type == type) return;
          setState(() {
            _type = type;
            _page = 1;
          });
          _load();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? AppColors.gold
                      : AppColors.textSecondary(isDark)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? Colors.white
                      : AppColors.text(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtersCard() {
    final isDark = _isDark;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'البحث والفلاتر',
            icon: Icons.filter_alt_rounded,
            trailing: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppColors.gold : AppColors.navy,
              ),
              onPressed: () {
                setState(() {
                  _searchCtrl.clear();
                  _method = null;
                  _cashBoxId = null;
                  _from = null;
                  _to = null;
                });
                _applyFilters();
              },
              child: const Text('مسح الفلاتر'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: 'بحث بالعميل أو الهاتف أو مرجع الفاتورة',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.inputFill(isDark),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _method,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'طريقة الدفع',
                    filled: true,
                    fillColor: AppColors.inputFill(isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('الكل')),
                    ...PaymentService.selectableMethods.map(
                      (m) => DropdownMenuItem<String>(
                        value: m['value'],
                        child: Text(m['label']!),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _method = v);
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _cashBoxId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'الخزينة',
                    filled: true,
                    fillColor: AppColors.inputFill(isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                        value: null, child: Text('الكل')),
                    ..._boxes.map(
                      (b) => DropdownMenuItem<int>(
                        value: (b['CashBoxID'] as num?)?.toInt(),
                        child: Text('${b['CashBoxName'] ?? ''}'),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _cashBoxId = v);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _dateButton('من', _from, (d) => _from = d)),
              const SizedBox(width: 12),
              Expanded(child: _dateButton('إلى', _to, (d) => _to = d)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime? value,
      void Function(DateTime?) assign) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.date_range_rounded, size: 18),
      label: Text(value == null
          ? '$label: الكل'
          : '$label: ${DateFormat('yyyy/MM/dd').format(value)}'),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked == null) return;
        setState(() => assign(picked));
        _applyFilters();
      },
    );
  }

  Widget _pager() {
    final pages = (_totalCount / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _load();
                  }
                : null,
          ),
          Text('صفحة $_page من $pages'),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _page < pages
                ? () {
                    setState(() => _page++);
                    _load();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _listBody() {
    if (!_canViewPayments) {
      return const AppEmpty(
        icon: Icons.lock_rounded,
        message: 'لا توجد صلاحية عرض المدفوعات',
        hint: 'يلزم ادعاء عرض المدفوعات أو دور المدير',
      );
    }
    if (_loading) return const AppLoading();
    if (_error != null) {
      return AppEmpty(
        icon: Icons.error_outline_rounded,
        message: _error!,
        hint: 'اضغط إعادة المحاولة',
        onRefresh: _load,
        refreshLabel: 'إعادة المحاولة',
      );
    }
    if (_items.isEmpty) {
      return const AppEmpty(
        icon: Icons.payments_rounded,
        message: 'لا توجد مدفوعات',
        hint: 'جرّب تعديل الفلاتر أو تغيير التبويب',
      );
    }
    return Column(
      children: [
        for (int i = 0; i < _items.length; i++) ...[
          _paymentCard(Map<String, dynamic>.from(_items[i] as Map)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _paymentCard(Map<String, dynamic> row) {
    final isDark = _isDark;
    final isPurchaseRow = row['TransactionType'] == 'Purchase';
    final canEdit = _canEditPayment(isPurchaseRow);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: '${row['ReceiptNumber'] ?? ''}',
                color: AppColors.gold,
                icon: Icons.receipt_long_rounded,
                small: true,
              ),
              const Spacer(),
              Text(
                '${_money(row['Amount'])} ج',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${row['PartyName'] ?? '—'} • فاتورة ${row['InvoiceReferenceNumber'] ?? '—'}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.text(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusBadge(
                label: PaymentService.methodLabel(
                    row['PaymentMethod']?.toString()),
                color: AppColors.info,
                small: true,
              ),
              StatusBadge(
                label: 'تراكمي ${_num(row['Percentage']).toStringAsFixed(1)}%',
                color: AppColors.success,
                small: true,
              ),
              if ((row['CashBoxName'] ?? '').toString().isNotEmpty)
                StatusBadge(
                  label: '${row['CashBoxName']}',
                  color: isDark ? AppColors.neutralLight : AppColors.neutral,
                  small: true,
                ),
              StatusBadge(
                label: _date(row['PaymentDate']),
                color: isDark ? AppColors.neutralLight : AppColors.neutral,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'سند الدفعة',
                icon: const Icon(Icons.receipt_rounded),
                onPressed: () => _showReceipt(row),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'تعديل الدفعة',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => _editPayment(row),
                ),
              if (_canDeletePayment)
                IconButton(
                  tooltip: 'إلغاء الدفعة',
                  icon: Icon(Icons.delete_rounded,
                      color: AppColors.error),
                  onPressed: () => _deletePayment(row),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── تعديل دفعة: وحدات التحكم مملوكة للحوار وتُحرَّر بعد إغلاقه ──
  Future<void> _editPayment(Map<String, dynamic> row) async {
    final amountCtrl =
        TextEditingController(text: _num(row['Amount']).toStringAsFixed(2));
    final notesCtrl = TextEditingController(text: '${row['Notes'] ?? ''}');
    int? boxId = (row['CashBoxID'] as num?)?.toInt();
    boxId ??= _boxes.isNotEmpty
        ? (_boxes.first['CashBoxID'] as num?)?.toInt()
        : null;
    String method = PaymentService.selectableMethods
            .any((m) => m['value'] == '${row['PaymentMethod'] ?? ''}')
        ? '${row['PaymentMethod']}'
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
                  items: _boxes
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
    final notes = notesCtrl.text.trim();
    amountCtrl.dispose();
    notesCtrl.dispose();
    if (confirmed != true || !mounted) return;
    if (amount <= 0 || boxId == null) {
      _showError('أدخل مبلغًا صحيحًا واختر الخزينة');
      return;
    }
    try {
      await _service.updatePayment(
        (row['PaymentID'] as num).toInt(),
        amount: amount,
        cashBoxId: boxId!,
        paymentMethod: method,
        notes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      _showError('تم تعديل الدفعة بنجاح');
      await _load();
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  // ── إلغاء دفعة: سبب إلزامي في حوار بوحدات تحكم مملوكة له ──
  Future<void> _deletePayment(Map<String, dynamic> row) async {
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
                'سيتم حذف دفعة ${_money(row['Amount'])} ج نهائيًا مع حركتها في الخزينة، وإعادة حساب الفاتورة ${row['InvoiceReferenceNumber'] ?? ''}.',
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
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.error),
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
      await _service.deletePayment((row['PaymentID'] as num).toInt(),
          reason: reason);
      if (!mounted) return;
      _showError('تم إلغاء الدفعة ورد قيمتها للخزينة');
      await _load();
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  // ── سند الدفعة: عرض + طباعة/مشاركة PDF (نمط قسيمة الراتب) ──
  Future<void> _showReceipt(Map<String, dynamic> row) async {
    Map<String, dynamic> receipt;
    try {
      receipt = await _service
          .getReceipt((row['PaymentID'] as num).toInt());
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
      return;
    }
    if (!mounted) return;
    final payment =
        Map<String, dynamic>.from((receipt['Payment'] as Map?) ?? row);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${receipt['ReceiptTypeAr'] ?? 'سند دفعة'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _receiptLine('رقم السند', '${receipt['ReceiptNumber'] ?? ''}'),
              _receiptLine('التاريخ', _date(payment['PaymentDate'])),
              _receiptLine('الطرف', '${payment['PartyName'] ?? '—'}'),
              _receiptLine(
                  'الفاتورة', '${payment['InvoiceReferenceNumber'] ?? '—'}'),
              _receiptLine('طريقة الدفع',
                  PaymentService.methodLabel(payment['PaymentMethod']?.toString())),
              _receiptLine('الخزينة', '${payment['CashBoxName'] ?? '—'}'),
              const SizedBox(height: 10),
              Text(
                '${_money(payment['Amount'])} ج',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text(_isDark),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${receipt['AmountInWords'] ?? ''}',
                style: TextStyle(color: AppColors.textSecondary(_isDark)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('مشاركة'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _shareReceiptPdf(receipt, payment);
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print_rounded),
            label: const Text('طباعة'),
            onPressed: () async {
              Navigator.pop(ctx);
              final bytes = await _receiptPdfBytes(receipt, payment);
              await Printing.layoutPdf(onLayout: (_) async => bytes);
            },
          ),
        ],
      ),
    );
  }

  Widget _receiptLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(color: AppColors.textSecondary(_isDark))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _receiptPdfBytes(
      Map<String, dynamic> receipt, Map<String, dynamic> payment) async {
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
          pw.Text('${receipt['ReceiptTypeAr'] ?? ''} — ${receipt['ReceiptNumber'] ?? ''}',
              style: pw.TextStyle(font: bold, fontSize: 13)),
          pw.SizedBox(height: 14),
          pw.Text('الطرف: ${payment['PartyName'] ?? '—'}',
              style: pw.TextStyle(font: regular, fontSize: 11)),
          pw.Text('الفاتورة: ${payment['InvoiceReferenceNumber'] ?? '—'}',
              style: pw.TextStyle(font: regular, fontSize: 11)),
          pw.Text('التاريخ: ${_date(payment['PaymentDate'])}',
              style: pw.TextStyle(font: regular, fontSize: 11)),
          pw.Text(
              'طريقة الدفع: ${PaymentService.methodLabel(payment['PaymentMethod']?.toString())}',
              style: pw.TextStyle(font: regular, fontSize: 11)),
          pw.Text('الخزينة: ${payment['CashBoxName'] ?? '—'}',
              style: pw.TextStyle(font: regular, fontSize: 11)),
          pw.SizedBox(height: 14),
          pw.Text('${_money(payment['Amount'])} ج',
              style: pw.TextStyle(font: bold, fontSize: 20)),
          pw.Text('${receipt['AmountInWords'] ?? ''}',
              style: pw.TextStyle(font: regular, fontSize: 11)),
        ],
      ),
    ));
    return document.save();
  }

  Future<void> _shareReceiptPdf(
      Map<String, dynamic> receipt, Map<String, dynamic> payment) async {
    try {
      final bytes = await _receiptPdfBytes(receipt, payment);
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          receipt['ReceiptNumber'] ?? 'payment_${payment['PaymentID']}';
      final file = File('${directory.path}/$fileName.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: '${receipt['ReceiptTypeAr'] ?? 'سند دفعة'}',
        text:
            '${receipt['ReceiptTypeAr'] ?? 'سند دفعة'} — ${payment['PartyName'] ?? ''}',
      ));
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('تعذر مشاركة السند: $e');
    }
  }
}
