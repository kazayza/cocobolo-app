import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../services/app_colors.dart';
import '../services/factory_purchase_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_states.dart';
import 'invoice/invoice_details_screen.dart';

class FactoryPurchaseFormScreen extends StatefulWidget {
  final int userId;
  final String username;

  const FactoryPurchaseFormScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<FactoryPurchaseFormScreen> createState() =>
      _FactoryPurchaseFormScreenState();
}

class _FactoryPurchaseFormScreenState extends State<FactoryPurchaseFormScreen> {
  final FactoryPurchaseService _service = FactoryPurchaseService();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _discountController =
      TextEditingController(text: '0');
  final TextEditingController _paidController =
      TextEditingController(text: '0');
  List<Map<String, dynamic>> _warehouses = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _cashboxes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _products = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _customers = <Map<String, dynamic>>[];
  final List<_FactoryPurchaseItem> _items = <_FactoryPurchaseItem>[];
  final List<_FactoryChargeItem> _charges = <_FactoryChargeItem>[];
  Map<String, dynamic>? _supplier;
  Map<String, dynamic>? _linkedCustomer;
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  DateTime _transactionDate = DateTime.now();
  DateTime? _dueDate;
  int? _warehouseId;
  int? _cashBoxId;
  String _paymentMethod = 'Credit';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Timer? _productDebounce;
  Timer? _customerDebounce;

  bool get _isDark => ThemeService().isDarkMode;
  bool _can(String key) => _capabilities[key] == true;

  double get _totalAmount => _items.fold<double>(
      0, (sum, item) => sum + item.quantity * item.unitPrice);
  double get _discountPercentage =>
      (double.tryParse(_discountController.text) ?? 0).clamp(0, 100);
  double get _discountAmount => _totalAmount * _discountPercentage / 100;
  double get _chargesTotal =>
      _charges.fold<double>(0, (sum, item) => sum + item.amount);
  double get _grandTotal => _totalAmount - _discountAmount + _chargesTotal;
  double get _paidAmount => double.tryParse(_paidController.text) ?? 0;
  double get _remaining => _grandTotal - _paidAmount;

  @override
  void initState() {
    super.initState();
    _discountController.addListener(_refreshTotals);
    _paidController.addListener(_refreshTotals);
    _load();
  }

  @override
  void dispose() {
    _productDebounce?.cancel();
    _customerDebounce?.cancel();
    _referenceController.dispose();
    _notesController.dispose();
    _productSearchController.dispose();
    _customerSearchController.dispose();
    _discountController.removeListener(_refreshTotals);
    _discountController.dispose();
    _paidController.removeListener(_refreshTotals);
    _paidController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    for (final charge in _charges) {
      charge.dispose();
    }
    super.dispose();
  }

  void _refreshTotals() {
    if (mounted) setState(() {});
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
      final data = await _service.getLookups();
      if (!mounted) return;
      setState(() {
        _supplier = _map(data['supplier']);
        _warehouses = (data['warehouses'] as List? ?? const [])
            .map<Map<String, dynamic>>(_map)
            .toList();
        _cashboxes = (data['cashboxes'] as List? ?? const [])
            .map<Map<String, dynamic>>(_map)
            .toList();
        _capabilities = _map(data['capabilities']);
        if (_warehouses.isNotEmpty) {
          _warehouseId = _int(_warehouses.first['WarehouseID']);
        }
        if (_cashboxes.isNotEmpty) {
          _cashBoxId = _int(_cashboxes.first['CashBoxID']);
        }
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

  void _searchProducts(String value) {
    _productDebounce?.cancel();
    _productDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (value.trim().length < 2) {
        if (mounted) setState(() => _products = <Map<String, dynamic>>[]);
        return;
      }
      try {
        final rows = await _service.searchProducts(value.trim());
        if (mounted) setState(() => _products = rows);
      } catch (_) {}
    });
  }

  void _searchCustomers(String value) {
    _customerDebounce?.cancel();
    _customerDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (value.trim().length < 2) {
        if (mounted) setState(() => _customers = <Map<String, dynamic>>[]);
        return;
      }
      try {
        final rows = await _service.searchCustomers(value.trim());
        if (mounted) setState(() => _customers = rows);
      } catch (_) {}
    });
  }

  Future<void> _addProduct(Map<String, dynamic> product) async {
    final productId = _int(product['ProductID']);
    if (productId <= 0 || _items.any((item) => item.productId == productId)) {
      return;
    }
    List<Map<String, dynamic>> alternatives = <Map<String, dynamic>>[];
    if (_int(product['AlternativesCount']) > 0) {
      try {
        alternatives = await _service.getAlternatives(productId);
      } catch (_) {}
    }
    final pricingType = '${product['PricingType'] ?? ''}'.toLowerCase();
    final tier =
        pricingType.contains('cclass') || pricingType.contains('standard')
            ? 'CClass'
            : pricingType.contains('elite')
                ? 'Elite'
                : 'Premium';
    final item = _FactoryPurchaseItem(
      product: product,
      alternatives: alternatives,
      tier: tier,
      onChanged: _itemChanged,
    );
    setState(() {
      _items.add(item);
      _products = <Map<String, dynamic>>[];
      _productSearchController.clear();
    });
    _recalculateDueDate();
  }

  void _itemChanged() {
    _recalculateDueDate();
    if (mounted) setState(() {});
  }

  void _recalculateDueDate() {
    final maxPeriod = _items.fold<int>(
      0,
      (current, item) => mathMax(current, item.periodDays),
    );
    if (maxPeriod > 0) {
      _dueDate = _transactionDate.add(Duration(days: maxPeriod));
    }
  }

  int mathMax(int a, int b) => a > b ? a : b;

  Future<void> _pickDate({required bool transactionDate}) async {
    final value = await showDatePicker(
      context: context,
      initialDate: transactionDate
          ? _transactionDate
          : (_dueDate ?? DateTime.now().add(const Duration(days: 7))),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (value == null) return;
    setState(() {
      if (transactionDate) {
        _transactionDate = value;
        _recalculateDueDate();
      } else {
        _dueDate = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_can('canCreate')) {
      _message('ليس لديك صلاحية إنشاء فاتورة شراء مصنع', error: true);
      return;
    }
    if (_warehouseId == null) {
      _message('اختر المخزن', error: true);
      return;
    }
    if (_dueDate == null) {
      _message('حدد موعد الاستلام المتوقع', error: true);
      return;
    }
    if (_items.isEmpty) {
      _message('أضف صنفًا واحدًا على الأقل', error: true);
      return;
    }
    if (_items.any((item) => item.quantity <= 0 || item.unitPrice < 0)) {
      _message('راجع كميات وأسعار الأصناف', error: true);
      return;
    }
    if (_paidAmount < 0 || _paidAmount > _grandTotal) {
      _message('المبلغ المدفوع غير صالح', error: true);
      return;
    }
    if (_paidAmount > 0 && _cashBoxId == null) {
      _message('اختر الخزينة لتسجيل دفعة الشراء', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _service.create(<String, dynamic>{
        'referenceNumber': _referenceController.text.trim(),
        'transactionDate': _transactionDate.toIso8601String(),
        'dueDate': _dueDate?.toIso8601String(),
        'warehouseId': _warehouseId,
        'linkedCustomerId': _linkedCustomer?['PartyID'],
        'discountPercentage': _discountPercentage,
        'paidAmount': _paidAmount,
        'paymentMethod': _paymentMethod,
        'cashBoxId': _paidAmount > 0 ? _cashBoxId : null,
        'notes': _notesController.text.trim(),
        'items': _items.map((item) => item.toJson()).toList(),
        'charges': _charges
            .where((charge) =>
                charge.description.trim().isNotEmpty && charge.amount > 0)
            .map((charge) => charge.toJson())
            .toList(),
      });
      final data = _map(result['data']);
      if (!mounted) return;
      _message('${result['message'] ?? 'تم إنشاء فاتورة الشراء'}');
      final id = _int(data['transactionId']);
      if (id > 0) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailsScreen(
              transactionId: id,
              username: widget.username,
              invoiceType: 'Purchase',
            ),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: Text('فاتورة شراء مصنع جديدة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              tooltip: 'حفظ',
            ),
        ],
      ),
      body: _loading
          ? const AppLoading(message: 'جاري تجهيز فاتورة شراء المصنع')
          : _error != null
              ? AppError(message: _error!, onRetry: _load)
              : Form(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    children: [
                      _hero(),
                      const SizedBox(height: 10),
                      _section(
                        title: 'بيانات الفاتورة والتوريد',
                        icon: Icons.receipt_long_rounded,
                        child: _invoiceData(),
                      ),
                      const SizedBox(height: 10),
                      _section(
                        title: 'المصنع والعميل المرتبط',
                        icon: Icons.factory_rounded,
                        child: _partyData(),
                      ),
                      const SizedBox(height: 10),
                      _section(
                        title: 'منتجات المعرض (${_items.length})',
                        icon: Icons.inventory_2_rounded,
                        child: _itemsSection(),
                      ),
                      const SizedBox(height: 10),
                      _section(
                        title: 'رسوم إضافية (${_charges.length})',
                        icon: Icons.add_card_rounded,
                        trailing: TextButton.icon(
                          onPressed: () => setState(() {
                            _charges.add(_FactoryChargeItem(
                              onChanged: _refreshTotals,
                            ));
                          }),
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: Text('إضافة', style: GoogleFonts.cairo()),
                        ),
                        child: _chargesSection(),
                      ),
                      const SizedBox(height: 10),
                      _section(
                        title: 'الدفع والإجماليات',
                        icon: Icons.payments_rounded,
                        child: _financialSection(),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.card(_isDark),
                  border: Border(
                    top: BorderSide(color: AppColors.divider(_isDark)),
                  ),
                ),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    _saving ? 'جاري الحفظ' : 'إنشاء الفاتورة وأمر التوريد',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.navy,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.navyDark, AppColors.navy, AppColors.navyLight],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
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
              Text('شراء منتجات المعرض من المصنع',
                  style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              Text(
                'يُنشأ أمر توريد الآن، والمخزون يدخل فقط عند تأكيد الاستلام',
                style: GoogleFonts.cairo(color: Colors.white60, fontSize: 9.5),
              ),
            ]),
          ),
        ]),
      );

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppColors.goldDark, size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Text(title,
                style: GoogleFonts.cairo(
                    color: AppColors.text(_isDark),
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) trailing,
        ]),
        const Divider(height: 20),
        child,
      ]),
    );
  }

  Widget _invoiceData() {
    return Column(children: [
      TextField(
        controller: _referenceController,
        style: GoogleFonts.cairo(),
        decoration: InputDecoration(
          labelText: 'رقم الفاتورة',
          hintText: 'اتركه فارغًا للتوليد التلقائي',
          labelStyle: GoogleFonts.cairo(),
          hintStyle: GoogleFonts.cairo(fontSize: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      const SizedBox(height: 9),
      Row(children: [
        Expanded(
          child: _dateTile(
            label: 'تاريخ الفاتورة',
            date: _transactionDate,
            onTap: () => _pickDate(transactionDate: true),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _dateTile(
            label: 'موعد الاستلام *',
            date: _dueDate,
            onTap: () => _pickDate(transactionDate: false),
          ),
        ),
      ]),
      const SizedBox(height: 9),
      DropdownButtonFormField<int>(
        initialValue: _warehouseId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'المخزن المستلم *',
          labelStyle: GoogleFonts.cairo(),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: _warehouses
            .map((warehouse) => DropdownMenuItem<int>(
                  value: _int(warehouse['WarehouseID']),
                  child: Text(
                    '${warehouse['WarehouseName'] ?? ''} — ${warehouse['BranchName'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(fontSize: 11),
                  ),
                ))
            .toList(),
        onChanged: (value) => setState(() => _warehouseId = value),
      ),
      const SizedBox(height: 9),
      TextField(
        controller: _notesController,
        maxLines: 2,
        style: GoogleFonts.cairo(),
        decoration: InputDecoration(
          labelText: 'ملاحظات الفاتورة',
          labelStyle: GoogleFonts.cairo(),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]);
  }

  Widget _dateTile({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(fontSize: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_month_rounded, size: 17),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              date == null ? 'غير محدد' : DateFormat('yyyy/MM/dd').format(date),
              style: GoogleFonts.cairo(fontSize: 10.5),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _partyData() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.factory_rounded, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'المورد الثابت: ${_supplier?['PartyName'] ?? 'المصنع'} — كود ${_supplier?['PartyID'] ?? 11}',
              style: GoogleFonts.cairo(
                  color: AppColors.text(_isDark),
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _customerSearchController,
        onChanged: _searchCustomers,
        style: GoogleFonts.cairo(),
        decoration: InputDecoration(
          labelText: 'عميل مرتبط اختياري',
          hintText: 'ابحث بالاسم أو الهاتف',
          prefixIcon: const Icon(Icons.person_search_rounded),
          suffixIcon: _linkedCustomer == null
              ? null
              : IconButton(
                  onPressed: () => setState(() {
                    _linkedCustomer = null;
                    _customerSearchController.clear();
                  }),
                  icon: const Icon(Icons.clear_rounded),
                ),
          labelStyle: GoogleFonts.cairo(),
          hintStyle: GoogleFonts.cairo(fontSize: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      if (_customers.isNotEmpty) ...[
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _customers.length,
            itemBuilder: (_, index) {
              final customer = _customers[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline_rounded),
                title: Text('${customer['PartyName'] ?? ''}',
                    style: GoogleFonts.cairo(fontSize: 11.5)),
                subtitle: Text('${customer['Phone'] ?? ''}',
                    style: GoogleFonts.cairo(fontSize: 9.5)),
                onTap: () => setState(() {
                  _linkedCustomer = customer;
                  _customerSearchController.text =
                      '${customer['PartyName'] ?? ''}';
                  _customers = <Map<String, dynamic>>[];
                }),
              );
            },
          ),
        ),
      ],
    ]);
  }

  Widget _itemsSection() {
    return Column(children: [
      TextField(
        controller: _productSearchController,
        onChanged: _searchProducts,
        style: GoogleFonts.cairo(),
        decoration: InputDecoration(
          labelText: 'ابحث عن منتج معرض لإضافته',
          hintText: 'اسم المنتج أو الكود',
          prefixIcon: const Icon(Icons.search_rounded),
          labelStyle: GoogleFonts.cairo(),
          hintStyle: GoogleFonts.cairo(fontSize: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      if (_products.isNotEmpty) ...[
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 230),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _products.length,
            itemBuilder: (_, index) {
              final product = _products[index];
              final added = _items
                  .any((item) => item.productId == _int(product['ProductID']));
              return ListTile(
                dense: true,
                leading: const Icon(Icons.inventory_2_outlined,
                    color: AppColors.goldDark),
                title: Text('${product['ProductName'] ?? ''}',
                    style: GoogleFonts.cairo(fontSize: 11.5)),
                subtitle: Text(
                  '${product['GroupName'] ?? ''} — مدة ${_int(product['Period'])} يوم — ${_int(product['AlternativesCount'])} بديل',
                  style: GoogleFonts.cairo(fontSize: 9.5),
                ),
                trailing: Icon(
                  added ? Icons.check_circle_rounded : Icons.add_circle_outline,
                  color: added ? AppColors.success : AppColors.navy,
                ),
                onTap: added ? null : () => _addProduct(product),
              );
            },
          ),
        ),
      ],
      const SizedBox(height: 8),
      if (_items.isEmpty)
        const AppEmpty(
          message: 'لا توجد أصناف مضافة',
          hint: 'ابحث عن منتجات المعرض وأضفها لأمر التوريد',
          icon: Icons.inventory_2_outlined,
        )
      else
        for (var index = 0; index < _items.length; index++)
          _itemCard(_items[index], index),
    ]);
  }

  Widget _itemCard(_FactoryPurchaseItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(item.productName,
                style: GoogleFonts.cairo(
                    fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                final removed = _items.removeAt(index);
                removed.dispose();
                _recalculateDueDate();
              });
            },
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 19),
          ),
        ]),
        if (item.productDescription.isNotEmpty)
          Text(item.productDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                  fontSize: 9.5, color: AppColors.textSecondary(_isDark))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: item.tier,
              decoration: InputDecoration(
                labelText: 'الباقة',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: const [
                DropdownMenuItem(value: 'CClass', child: Text('C Class')),
                DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                DropdownMenuItem(value: 'Elite', child: Text('Elite')),
              ],
              onChanged: (value) {
                if (value != null) item.setTier(value);
              },
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: DropdownButtonFormField<int?>(
              initialValue: item.alternativeId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'بديل المصنع',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: <DropdownMenuItem<int?>>[
                DropdownMenuItem<int?>(
                    value: null,
                    child: Text('المنتج الأساسي',
                        style: GoogleFonts.cairo(fontSize: 10))),
                ...item.alternatives
                    .map((alternative) => DropdownMenuItem<int?>(
                          value: _int(alternative['AlternativeID']),
                          child: Text('${alternative['AlternativeName'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(fontSize: 10)),
                        )),
              ],
              onChanged: item.setAlternative,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: item.quantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'الكمية',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: item.priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'سعر الشراء',
                suffixText: 'ج.م',
                labelStyle: GoogleFonts.cairo(fontSize: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 7),
        Row(children: [
          _smallInfo(Icons.schedule_rounded, '${item.periodDays} يوم'),
          const Spacer(),
          Text(_money(item.total),
              style: GoogleFonts.cairo(
                  color: AppColors.goldDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _smallInfo(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.info),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.cairo(fontSize: 9)),
        ]),
      );

  Widget _chargesSection() {
    if (_charges.isEmpty) {
      return Text('لا توجد رسوم إضافية',
          style: GoogleFonts.cairo(
              color: AppColors.textSecondary(_isDark), fontSize: 10.5));
    }
    return Column(
      children: _charges.asMap().entries.map((entry) {
        final charge = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: charge.descriptionController,
                style: GoogleFonts.cairo(fontSize: 11),
                decoration: InputDecoration(
                  labelText: 'الوصف',
                  labelStyle: GoogleFonts.cairo(fontSize: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: TextField(
                controller: charge.amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.cairo(fontSize: 11),
                decoration: InputDecoration(
                  labelText: 'المبلغ',
                  labelStyle: GoogleFonts.cairo(fontSize: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  final removed = _charges.removeAt(entry.key);
                  removed.dispose();
                });
              },
              icon: const Icon(Icons.close_rounded, color: AppColors.error),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _financialSection() {
    return Column(children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
              labelText: 'نسبة الخصم',
              suffixText: '%',
              labelStyle: GoogleFonts.cairo(fontSize: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: InputDecoration(
              labelText: 'طريقة الدفع',
              labelStyle: GoogleFonts.cairo(fontSize: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
            ),
            items: const [
              DropdownMenuItem(value: 'Credit', child: Text('آجل')),
              DropdownMenuItem(value: 'Cash', child: Text('نقدي')),
              DropdownMenuItem(value: 'Bank', child: Text('تحويل بنكي')),
              DropdownMenuItem(value: 'Card', child: Text('بطاقة')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _paymentMethod = value);
            },
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _paidController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
              labelText: 'دفعة عند الإنشاء',
              suffixText: 'ج.م',
              labelStyle: GoogleFonts.cairo(fontSize: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: DropdownButtonFormField<int?>(
            initialValue: _cashBoxId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'الخزينة',
              labelStyle: GoogleFonts.cairo(fontSize: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
            ),
            items: _cashboxes
                .map((cashbox) => DropdownMenuItem<int?>(
                      value: _int(cashbox['CashBoxID']),
                      child: Text('${cashbox['CashBoxName'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(fontSize: 10)),
                    ))
                .toList(),
            onChanged: _paidAmount > 0
                ? (value) => setState(() => _cashBoxId = value)
                : null,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      _totalLine('إجمالي الأصناف', _totalAmount),
      _totalLine('الخصم', -_discountAmount),
      _totalLine('الرسوم', _chargesTotal),
      const Divider(),
      _totalLine('الإجمالي النهائي', _grandTotal,
          bold: true, color: AppColors.goldDark),
      _totalLine('المدفوع', _paidAmount, color: AppColors.success),
      _totalLine('المتبقي', _remaining,
          bold: true,
          color: _remaining > 0 ? AppColors.error : AppColors.success),
    ]);
  }

  Widget _totalLine(String label, double value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 10.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        ),
        Text(_money(value),
            style: GoogleFonts.cairo(
                color: color ?? AppColors.text(_isDark),
                fontSize: bold ? 13 : 11,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
      ]),
    );
  }

  String _money(dynamic value) =>
      '${NumberFormat('#,##0.00').format(_num(value))} ج.م';
}

class _FactoryPurchaseItem {
  final Map<String, dynamic> product;
  final List<Map<String, dynamic>> alternatives;
  final VoidCallback onChanged;
  late final TextEditingController quantityController;
  late final TextEditingController priceController;
  String tier;
  int? alternativeId;

  _FactoryPurchaseItem({
    required this.product,
    required this.alternatives,
    required this.tier,
    required this.onChanged,
  }) {
    quantityController = TextEditingController(text: '1');
    priceController =
        TextEditingController(text: _priceForTier().toStringAsFixed(2));
    quantityController.addListener(onChanged);
    priceController.addListener(onChanged);
  }

  int get productId => _int(product['ProductID']);
  String get productName => '${product['ProductName'] ?? ''}';
  String get productDescription => '${product['ProductDescription'] ?? ''}';
  double get quantity => _num(quantityController.text);
  double get unitPrice => _num(priceController.text);
  double get total => quantity * unitPrice;

  Map<String, dynamic>? get selectedAlternative {
    if (alternativeId == null) return null;
    for (final alternative in alternatives) {
      if (_int(alternative['AlternativeID']) == alternativeId) {
        return alternative;
      }
    }
    return null;
  }

  int get periodDays => _int(
        selectedAlternative?['Period'] ?? product['Period'],
      );

  void setTier(String value) {
    tier = value;
    priceController.text = _priceForTier().toStringAsFixed(2);
    onChanged();
  }

  void setAlternative(int? value) {
    alternativeId = value;
    priceController.text = _priceForTier().toStringAsFixed(2);
    onChanged();
  }

  double _priceForTier() {
    final source = selectedAlternative ?? product;
    if (selectedAlternative != null) {
      if (tier == 'CClass') return _num(source['PurchasePriceCClass']);
      if (tier == 'Elite') {
        return _num(
            source['PurchasePriceElite'] ?? source['PurchasePricePremium']);
      }
      return _num(source['PurchasePricePremium']);
    }
    if (tier == 'CClass') return _num(source['PurchasePriceCClass']);
    if (tier == 'Elite') {
      return _num(source['PurchasePriceElite'] ?? source['PurchasePrice']);
    }
    return _num(source['PurchasePrice']);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'pricingTier': tier,
        'selectedAlternativeId': alternativeId,
      };

  void dispose() {
    quantityController.removeListener(onChanged);
    priceController.removeListener(onChanged);
    quantityController.dispose();
    priceController.dispose();
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }
}

class _FactoryChargeItem {
  final VoidCallback onChanged;
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController amountController =
      TextEditingController(text: '0');

  _FactoryChargeItem({required this.onChanged}) {
    descriptionController.addListener(onChanged);
    amountController.addListener(onChanged);
  }

  String get description => descriptionController.text;
  double get amount => double.tryParse(amountController.text) ?? 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'chargeType': 'Other',
        'description': description.trim(),
        'amount': amount,
      };

  void dispose() {
    descriptionController.removeListener(onChanged);
    amountController.removeListener(onChanged);
    descriptionController.dispose();
    amountController.dispose();
  }
}
