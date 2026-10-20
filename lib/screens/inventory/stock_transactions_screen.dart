import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants.dart';
import '../../services/app_colors.dart';
import '../../services/inventory_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/inventory_design.dart';

class StockTransactionsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const StockTransactionsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<StockTransactionsScreen> createState() =>
      _StockTransactionsScreenState();
}

class _StockTransactionsScreenState extends State<StockTransactionsScreen> {
  final _searchController = TextEditingController();
  final _productSearchController = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  List<dynamic> _branches = [];
  List<dynamic> _warehouses = [];
  Map<String, dynamic>? _selectedProduct;
  int? _branchId;
  int? _warehouseId;
  String? _referenceType;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  bool get _isDark => ThemeService().isDarkMode;

  int get _inQuantity => _items
      .where((item) => '${item['TransactionType']}' == 'In')
      .fold(0, (sum, item) => sum + _int(item['Quantity']));
  int get _outQuantity => _items
      .where((item) => '${item['TransactionType']}' != 'In')
      .fold(0, (sum, item) => sum + _int(item['Quantity']));
  int get _netQuantity => _inQuantity - _outQuantity;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<List<dynamic>>([
        InventoryService.getBranches(),
        InventoryService.getWarehouses(),
      ]);
      if (!mounted) return;
      _branches = results[0];
      _warehouses = results[1];
      await _loadTransactions(keepLoading: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadTransactions({bool keepLoading = false}) async {
    if (!keepLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final product = _selectedProduct;
      final rawProductId = product?['ProductID'] ?? product?['ProductId'];
      final productId = rawProductId is int
          ? rawProductId
          : int.tryParse('${rawProductId ?? ''}');
      final items = await InventoryService.getTransactions(
        productId: productId,
        warehouseId: _warehouseId,
        branchId: _branchId,
        referenceType: _referenceType,
        search: _searchController.text.trim(),
        startDate: _dateFrom == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_dateFrom!),
        endDate:
            _dateTo == null ? null : DateFormat('yyyy-MM-dd').format(_dateTo!),
      );
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _changeBranch(int? value) async {
    setState(() {
      _branchId = value;
      _warehouseId = null;
      _warehouses = [];
    });
    try {
      final warehouses = await InventoryService.getWarehouses(branchId: value);
      if (!mounted) return;
      setState(() => _warehouses = warehouses);
      await _loadTransactions();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _loadTransactions);
  }

  Future<List<dynamic>> _searchProducts(String query) async {
    if (query.trim().length < 2) return const [];
    final response = await http.get(
      Uri.parse('$baseUrl/api/products').replace(
        queryParameters: {'search': query.trim()},
      ),
    );
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List) {
      return decoded['data'] as List;
    }
    return const [];
  }

  Future<void> _pickProduct() async {
    final products = await _searchProducts(_productSearchController.text);
    if (!mounted) return;
    if (products.isEmpty) return;
    final product = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.sizeOf(context).height * 0.65,
        decoration: BoxDecoration(
          color: AppColors.card(_isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    'تصفية بمنتج',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                itemCount: products.length,
                itemBuilder: (_, index) {
                  final item = Map<String, dynamic>.from(products[index] as Map);
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(
                      item['ProductName'] ?? '',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'كود ${item['ProductID'] ?? item['ProductId']}',
                      style: GoogleFonts.cairo(fontSize: 10),
                    ),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (product != null) {
      setState(() {
        _selectedProduct = product;
        _productSearchController.text = product['ProductName'] ?? '';
      });
      _loadTransactions();
    }
  }

  void _resetFilters() {
    setState(() {
      _branchId = null;
      _warehouseId = null;
      _referenceType = null;
      _selectedProduct = null;
      _dateFrom = null;
      _dateTo = null;
      _searchController.clear();
      _productSearchController.clear();
    });
    _bootstrap();
  }

  String _referenceLabel(String? value) => switch (value) {
        'OpeningBalance' => 'رصيد افتتاحي',
        'ShowroomSupply' => 'إدخال للمخزن',
        'FactoryReceive' => 'استلام من المصنع',
        'Adjustment' => 'تسوية مخزنية',
        'WarehouseTransferOut' => 'تحويل صادر',
        'WarehouseTransferIn' => 'تحويل وارد',
        'SaleInvoice' => 'فاتورة بيع',
        'SaleInvoiceEdit' => 'تعديل فاتورة بيع',
        'PurchaseInvoice' => 'فاتورة شراء',
        'PurchaseInvoiceReceipt' => 'استلام فاتورة شراء',
        'PurchaseInvoiceEdit' => 'تعديل فاتورة شراء',
        'PurchaseInvoiceCancel' => 'إلغاء فاتورة شراء',
        _ => value ?? 'غير محدد',
      };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            _isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          title: Text(
            'حركة المخزون',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _loadTransactions,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _loadTransactions,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: [
              InventoryHero(
                icon: Icons.history_rounded,
                title: 'سجل حركة المخزون',
                subtitle:
                    'تابع عمليات الدخول والخروج والتحويل وربط كل حركة بمصدرها وموقعها.',
                stats: [
                  InventoryHeroStat(
                    icon: Icons.receipt_long_outlined,
                    label: 'عدد الحركات',
                    value: '${_items.length}',
                    color: Colors.white,
                  ),
                  InventoryHeroStat(
                    icon: Icons.south_rounded,
                    label: 'كميات داخلة',
                    value: '$_inQuantity',
                    color: const Color(0xFF6EE7B7),
                  ),
                  InventoryHeroStat(
                    icon: Icons.north_rounded,
                    label: 'كميات خارجة',
                    value: '$_outQuantity',
                    color: const Color(0xFFFCA5A5),
                  ),
                  InventoryHeroStat(
                    icon: Icons.balance_rounded,
                    label: 'صافي الحركة',
                    value: '$_netQuantity',
                    color: AppColors.gold,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _filters(),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                InventorySection(
                  title: 'تعذر تحميل الحركات',
                  subtitle: _error,
                  icon: Icons.error_outline_rounded,
                  color: Colors.red,
                  child: FilledButton.icon(
                    onPressed: _bootstrap,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                )
              else if (_items.isEmpty)
                InventorySection(
                  title: 'لا توجد حركات مطابقة',
                  subtitle: 'غيّر الفلاتر أو نطاق التاريخ ثم أعد المحاولة.',
                  icon: Icons.history_toggle_off_rounded,
                  color: AppColors.gold,
                  child: const SizedBox.shrink(),
                )
              else ...[
                Row(
                  children: [
                    Text(
                      'الحركات المسجلة',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_items.length} حركة',
                      style: GoogleFonts.cairo(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._items.map(
                  (item) => _TransactionCard(
                    item: Map<String, dynamic>.from(item as Map),
                    referenceLabel: _referenceLabel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    return InventorySection(
      title: 'فلاتر الحركة',
      subtitle: 'استخدم أكثر من فلتر للوصول للحركة المطلوبة.',
      icon: Icons.filter_alt_outlined,
      color: AppColors.gold,
      trailing: IconButton(
        tooltip: 'مسح الفلاتر',
        onPressed: _resetFilters,
        icon: const Icon(Icons.filter_alt_off_rounded),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _searchChanged,
            onSubmitted: (_) => _loadTransactions(),
            decoration: inventoryInputDecoration(
              context,
              label: 'بحث عام',
              hint: 'المنتج، المخزن، الملاحظات أو المرجع',
              icon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final branch = _branchDropdown();
              final warehouse = _warehouseDropdown();
              if (compact) {
                return Column(
                  children: [
                    branch,
                    const SizedBox(height: 10),
                    warehouse,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: branch),
                  const SizedBox(width: 10),
                  Expanded(child: warehouse),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final type = _typeDropdown();
              final product = TextField(
                controller: _productSearchController,
                onSubmitted: (_) => _pickProduct(),
                decoration: inventoryInputDecoration(
                  context,
                  label: _selectedProduct == null
                      ? 'منتج محدد'
                      : _selectedProduct!['ProductName'] ?? 'المنتج',
                  hint: 'اكتب للبحث',
                  icon: Icons.inventory_2_rounded,
                ).copyWith(
                  suffixIcon: _selectedProduct == null
                      ? IconButton(
                          onPressed: _pickProduct,
                          icon: const Icon(Icons.manage_search_rounded),
                        )
                      : IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedProduct = null;
                              _productSearchController.clear();
                            });
                            _loadTransactions();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              );
              if (compact) {
                return Column(
                  children: [
                    type,
                    const SizedBox(height: 10),
                    product,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: type),
                  const SizedBox(width: 10),
                  Expanded(child: product),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _dateField('من تاريخ', _dateFrom, true)),
              const SizedBox(width: 10),
              Expanded(child: _dateField('إلى تاريخ', _dateTo, false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _branchDropdown() {
    return DropdownButtonFormField<int?>(
      value: _branchId,
      isExpanded: true,
      decoration: inventoryInputDecoration(
        context,
        label: 'الفرع',
        icon: Icons.business_rounded,
      ),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text('كل الفروع', style: GoogleFonts.cairo()),
        ),
        ..._branches.map(
          (branch) => DropdownMenuItem<int?>(
            value: branch['BranchId'] ?? branch['BranchID'],
            child: Text(
              branch['BranchNameAr'] ?? branch['BranchName'] ?? '',
              style: GoogleFonts.cairo(),
            ),
          ),
        ),
      ],
      onChanged: _changeBranch,
    );
  }

  Widget _warehouseDropdown() {
    return DropdownButtonFormField<int?>(
      value: _warehouseId,
      isExpanded: true,
      decoration: inventoryInputDecoration(
        context,
        label: 'المخزن',
        icon: Icons.warehouse_rounded,
      ),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text('كل المخازن', style: GoogleFonts.cairo()),
        ),
        ..._warehouses.map(
          (warehouse) => DropdownMenuItem<int?>(
            value: warehouse['WarehouseID'] ?? warehouse['WarehouseId'],
            child: Text(
              warehouse['WarehouseName'] ?? '',
              style: GoogleFonts.cairo(),
            ),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() => _warehouseId = value);
        _loadTransactions();
      },
    );
  }

  Widget _typeDropdown() {
    return DropdownButtonFormField<String?>(
      value: _referenceType,
      isExpanded: true,
      decoration: inventoryInputDecoration(
        context,
        label: 'نوع الحركة',
        icon: Icons.label_outline_rounded,
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('كل الأنواع', style: GoogleFonts.cairo()),
        ),
        ...[
          'OpeningBalance',
          'ShowroomSupply',
          'FactoryReceive',
          'Adjustment',
          'WarehouseTransferOut',
          'WarehouseTransferIn',
          'SaleInvoice',
          'PurchaseInvoice',
          'PurchaseInvoiceReceipt',
        ].map(
          (value) => DropdownMenuItem<String?>(
            value: value,
            child: Text(_referenceLabel(value), style: GoogleFonts.cairo()),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() => _referenceType = value);
        _loadTransactions();
      },
    );
  }

  Widget _dateField(String label, DateTime? value, bool from) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date == null) return;
        setState(() {
          if (from) {
            _dateFrom = date;
          } else {
            _dateTo = date;
          }
        });
        _loadTransactions();
      },
      child: InputDecorator(
        decoration: inventoryInputDecoration(
          context,
          label: label,
          icon: Icons.event_rounded,
        ),
        child: Text(
          value == null ? 'غير محدد' : DateFormat('yyyy/MM/dd').format(value),
          style: GoogleFonts.cairo(fontSize: 12),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(String?) referenceLabel;

  const _TransactionCard({
    required this.item,
    required this.referenceLabel,
  });

  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final dark = ThemeService().isDarkMode;
    final incoming = '${item['TransactionType']}' == 'In';
    final color = incoming ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final date = DateTime.tryParse('${item['TransactionDate'] ?? ''}');
    final branch = '${item['BranchNameAr'] ?? item['BranchName'] ?? ''}';
    final notes = '${item['Notes'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  incoming ? Icons.south_rounded : Icons.north_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['ProductName'] ?? 'منتج بدون اسم',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Wrap(
                      spacing: 9,
                      runSpacing: 3,
                      children: [
                        _info(Icons.tag_rounded, '#${item['ProductID']}'),
                        _info(
                          Icons.warehouse_rounded,
                          item['WarehouseName'] ?? '—',
                        ),
                        if (branch.isNotEmpty)
                          _info(Icons.business_rounded, branch),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_int(item['Quantity'])}',
                      style: GoogleFonts.cairo(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      incoming ? 'دخول' : 'خروج',
                      style: GoogleFonts.cairo(
                        color: color,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              if (date != null)
                _info(
                  Icons.event_rounded,
                  DateFormat('yyyy/MM/dd HH:mm').format(date.toLocal()),
                ),
              _info(
                Icons.label_outline_rounded,
                referenceLabel(item['ReferenceType']?.toString()),
              ),
              if ((item['ReferenceID'] ?? '').toString().isNotEmpty)
                _info(Icons.link_rounded, 'مرجع ${item['ReferenceID']}'),
              if ((item['CreatedBy'] ?? '').toString().isNotEmpty)
                _info(Icons.person_outline_rounded, item['CreatedBy']),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xFF111C2D)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(notes, style: GoogleFonts.cairo(fontSize: 10.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 3),
        Text(text, style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
