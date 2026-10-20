import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';
import '../../services/app_colors.dart';
import '../../services/inventory_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/inventory_design.dart';

class StockTransferScreen extends StatefulWidget {
  final int userId;
  final String username;

  const StockTransferScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  final _productSearchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<dynamic> _branches = [];
  List<dynamic> _sourceWarehouses = [];
  List<dynamic> _destinationWarehouses = [];
  Map<String, dynamic>? _selectedProduct;
  int? _sourceBranchId;
  int? _sourceWarehouseId;
  int? _destinationBranchId;
  int? _destinationWarehouseId;
  int _sourceStock = 0;
  int _destinationStock = 0;
  String? _lastTransferReference;

  bool get _isDark => ThemeService().isDarkMode;
  int get _quantity => int.tryParse(_quantityController.text) ?? 0;
  int get _sourceAfter =>
      (_sourceStock - _quantity).clamp(0, 999999999).toInt();
  int get _destinationAfter => _destinationStock + _quantity;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_refreshPreview);
    _loadData();
  }

  @override
  void dispose() {
    _quantityController.removeListener(_refreshPreview);
    _quantityController.dispose();
    _notesController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final branches = await InventoryService.getBranches();
      if (!mounted) return;
      setState(() {
        _branches = branches;
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

  Future<void> _changeSourceBranch(int? value) async {
    setState(() {
      _sourceBranchId = value;
      _sourceWarehouseId = null;
      _sourceWarehouses = [];
      _selectedProduct = null;
      _productSearchController.clear();
      _sourceStock = 0;
      _destinationStock = 0;
    });
    if (value == null) return;
    try {
      final warehouses = await InventoryService.getWarehouses(branchId: value);
      if (mounted) setState(() => _sourceWarehouses = warehouses);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _changeDestinationBranch(int? value) async {
    setState(() {
      _destinationBranchId = value;
      _destinationWarehouseId = null;
      _destinationWarehouses = [];
      _destinationStock = 0;
    });
    if (value == null) return;
    try {
      final warehouses = await InventoryService.getWarehouses(branchId: value);
      if (mounted) setState(() => _destinationWarehouses = warehouses);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _changeSourceWarehouse(int? value) async {
    setState(() {
      _sourceWarehouseId = value;
      _selectedProduct = null;
      _productSearchController.clear();
      _sourceStock = 0;
      _destinationStock = 0;
    });
  }

  Future<void> _changeDestinationWarehouse(int? value) async {
    setState(() => _destinationWarehouseId = value);
    await _refreshStocks();
  }

  Future<List<dynamic>> _searchProducts(String query) async {
    if (_sourceWarehouseId == null || query.trim().length < 2) {
      return const [];
    }
    final uri = Uri.parse('$baseUrl/api/products').replace(
      queryParameters: {
        'search': query.trim(),
        'warehouseId': '$_sourceWarehouseId',
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body);
    final rows = decoded is List
        ? decoded
        : decoded is Map && decoded['data'] is List
            ? decoded['data'] as List
            : const [];
    return rows
        .where((item) =>
            (item['StockQuantity'] ?? item['QTY'] ?? 0) is num
                ? (item['StockQuantity'] ?? item['QTY'] ?? 0) > 0
                : (int.tryParse('${item['StockQuantity'] ?? item['QTY']}') ?? 0) >
                    0)
        .toList();
  }

  Future<void> _pickProduct() async {
    if (_sourceWarehouseId == null) {
      _message('اختر مخزن المصدر أولاً', error: true);
      return;
    }
    final products = await _searchProducts(_productSearchController.text);
    if (!mounted) return;
    if (products.isEmpty) {
      _message('لا توجد منتجات برصيد مطابق للبحث', error: true);
      return;
    }

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.sizeOf(context).height * 0.68,
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
                    'منتجات متاحة في مخزن المصدر',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 7),
                itemBuilder: (_, index) {
                  final product = Map<String, dynamic>.from(
                    products[index] as Map,
                  );
                  final stock = product['StockQuantity'] ?? product['QTY'] ?? 0;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x1513273F),
                      child: Icon(Icons.chair_alt_rounded, color: AppColors.navy),
                    ),
                    title: Text(
                      product['ProductName'] ?? 'منتج بدون اسم',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'الرصيد المتاح: $stock',
                      style: GoogleFonts.cairo(fontSize: 10.5),
                    ),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => Navigator.pop(context, product),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedProduct = picked;
        _productSearchController.text = picked['ProductName'] ?? '';
      });
      await _refreshStocks();
    }
  }

  Future<void> _refreshStocks() async {
    final product = _selectedProduct;
    if (product == null) return;
    final rawId = product['ProductID'] ?? product['ProductId'];
    final productId = rawId is int ? rawId : int.tryParse('$rawId');
    if (productId == null) return;

    try {
      final results = await Future.wait<int>([
        if (_sourceWarehouseId != null)
          InventoryService.getCurrentStock(
            productId: productId,
            warehouseId: _sourceWarehouseId!,
          )
        else
          Future.value(0),
        if (_destinationWarehouseId != null)
          InventoryService.getCurrentStock(
            productId: productId,
            warehouseId: _destinationWarehouseId!,
          )
        else
          Future.value(0),
      ]);
      if (mounted) {
        setState(() {
          _sourceStock = results[0];
          _destinationStock = results[1];
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _save() async {
    if (_sourceWarehouseId == null || _destinationWarehouseId == null) {
      _message('حدد مخزن المصدر والوجهة', error: true);
      return;
    }
    if (_sourceWarehouseId == _destinationWarehouseId) {
      _message('مخزن المصدر والوجهة يجب أن يكونا مختلفين', error: true);
      return;
    }
    if (_selectedProduct == null) {
      _message('اختيار المنتج مطلوب', error: true);
      return;
    }
    if (_quantity <= 0) {
      _message('الكمية يجب أن تكون أكبر من صفر', error: true);
      return;
    }
    if (_sourceStock < _quantity) {
      _message(
        'الرصيد غير كافٍ. المتاح $_sourceStock والمطلوب $_quantity',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/inventory/transfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromWarehouseId': _sourceWarehouseId,
          'toWarehouseId': _destinationWarehouseId,
          'productId': _selectedProduct!['ProductID'] ??
              _selectedProduct!['ProductId'],
          'quantity': _quantity,
          'notes': _notesController.text.trim(),
          'createdBy': widget.username,
        }),
      );
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        throw InventoryApiException(
          decoded['message']?.toString() ?? 'فشل تنفيذ التحويل',
          statusCode: response.statusCode,
        );
      }
      if (!mounted) return;
      setState(() {
        _lastTransferReference = decoded['transferReference']?.toString();
        _sourceStock = int.tryParse('${decoded['sourceNewQuantity']}') ??
            _sourceAfter;
        _destinationStock =
            int.tryParse('${decoded['destinationNewQuantity']}') ??
                _destinationAfter;
      });
      _message('تم التحويل وتسجيل حركتي الخروج والدخول');
      _resetProductOnly();
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value, style: GoogleFonts.cairo()),
        backgroundColor: error ? Colors.red.shade700 : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetProductOnly() {
    setState(() {
      _selectedProduct = null;
      _productSearchController.clear();
      _quantityController.text = '1';
      _notesController.clear();
      _sourceStock = 0;
      _destinationStock = 0;
    });
  }

  void _resetAll() {
    setState(() {
      _sourceBranchId = null;
      _sourceWarehouseId = null;
      _destinationBranchId = null;
      _destinationWarehouseId = null;
      _sourceWarehouses = [];
      _destinationWarehouses = [];
      _lastTransferReference = null;
    });
    _resetProductOnly();
  }

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
            'تحويل مخزني',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث الأرصدة',
              onPressed: _saving ? null : _refreshStocks,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                children: [
                  InventoryHero(
                    icon: Icons.swap_horiz_rounded,
                    title: 'تحويل رصيد بين المخازن',
                    subtitle:
                        'انقل كمية من منتج بين موقعين مع تسجيل حركة خروج وحركة دخول مترابطتين.',
                    stats: [
                      InventoryHeroStat(
                        icon: Icons.outbox_rounded,
                        label: 'رصيد المصدر',
                        value: '$_sourceStock',
                        color: const Color(0xFFFCA5A5),
                      ),
                      InventoryHeroStat(
                        icon: Icons.move_down_rounded,
                        label: 'كمية التحويل',
                        value: '$_quantity',
                        color: AppColors.gold,
                      ),
                      InventoryHeroStat(
                        icon: Icons.inbox_rounded,
                        label: 'رصيد الوجهة',
                        value: '$_destinationStock',
                        color: const Color(0xFF6EE7B7),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _errorBanner(),
                  ],
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 780;
                      final form = _transferForm();
                      final preview = _transferPreview();
                      if (compact) {
                        return Column(
                          children: [
                            form,
                            const SizedBox(height: 14),
                            preview,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: form),
                          const SizedBox(width: 14),
                          Expanded(flex: 2, child: preview),
                        ],
                      );
                    },
                  ),
                ],
              ),
            if (_saving)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black38,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.card(_isDark),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 12),
                          Text('جاري تنفيذ التحويل...', style: GoogleFonts.cairo()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _transferForm() {
    return InventorySection(
      title: 'بيانات التحويل',
      subtitle: 'اختر المصدر والوجهة ثم المنتج والكمية.',
      icon: Icons.swap_horiz_rounded,
      color: AppColors.gold,
      child: Column(
        children: [
          _locationBlock(
            title: 'موقع المصدر',
            icon: Icons.outbox_rounded,
            color: const Color(0xFFDC2626),
            branchValue: _sourceBranchId,
            warehouseValue: _sourceWarehouseId,
            warehouses: _sourceWarehouses,
            onBranchChanged: _changeSourceBranch,
            onWarehouseChanged: _changeSourceWarehouse,
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_downward_rounded,
                color: AppColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _locationBlock(
            title: 'موقع الوجهة',
            icon: Icons.inbox_rounded,
            color: const Color(0xFF059669),
            branchValue: _destinationBranchId,
            warehouseValue: _destinationWarehouseId,
            warehouses: _destinationWarehouses,
            onBranchChanged: _changeDestinationBranch,
            onWarehouseChanged: _changeDestinationWarehouse,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _productSearchController,
            enabled: _sourceWarehouseId != null,
            onSubmitted: (_) => _pickProduct(),
            decoration: inventoryInputDecoration(
              context,
              label: _selectedProduct == null
                  ? 'المنتج *'
                  : _selectedProduct!['ProductName'] ?? 'المنتج',
              hint: _sourceWarehouseId == null
                  ? 'اختر مخزن المصدر أولاً'
                  : 'ابحث في رصيد مخزن المصدر',
              icon: Icons.inventory_2_rounded,
            ).copyWith(
              suffixIcon: IconButton(
                onPressed: _sourceWarehouseId == null ? null : _pickProduct,
                icon: const Icon(Icons.manage_search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: inventoryInputDecoration(
              context,
              label: 'كمية التحويل *',
              icon: Icons.numbers_rounded,
            ),
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: inventoryInputDecoration(
              context,
              label: 'سبب أو ملاحظات التحويل',
              icon: Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _resetAll,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('مسح'),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 13,
                  ),
                ),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: Text(
                  'تنفيذ التحويل',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationBlock({
    required String title,
    required IconData icon,
    required Color color,
    required int? branchValue,
    required int? warehouseValue,
    required List<dynamic> warehouses,
    required ValueChanged<int?> onBranchChanged,
    required ValueChanged<int?> onWarehouseChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.17)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 7),
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 480;
              final branch = _branchDropdown(
                value: branchValue,
                onChanged: onBranchChanged,
              );
              final warehouse = _warehouseDropdown(
                value: warehouseValue,
                warehouses: warehouses,
                onChanged: onWarehouseChanged,
              );
              if (compact) {
                return Column(
                  children: [
                    branch,
                    const SizedBox(height: 9),
                    warehouse,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: branch),
                  const SizedBox(width: 9),
                  Expanded(child: warehouse),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _transferPreview() {
    return Column(
      children: [
        InventorySection(
          title: 'أثر التحويل',
          subtitle: _selectedProduct == null
              ? 'اختر منتجًا لمعاينة الأرصدة.'
              : _selectedProduct!['ProductName']?.toString(),
          icon: Icons.compare_arrows_rounded,
          color: const Color(0xFF2563EB),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InventoryMetricCard(
                      icon: Icons.outbox_rounded,
                      label: 'المصدر بعد التحويل',
                      value: '$_sourceAfter',
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: InventoryMetricCard(
                      icon: Icons.inbox_rounded,
                      label: 'الوجهة بعد التحويل',
                      value: '$_destinationAfter',
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              if (_lastTransferReference != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'مرجع آخر تحويل: $_lastTransferReference',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        InventorySection(
          title: 'ضوابط التحويل',
          icon: Icons.rule_rounded,
          color: const Color(0xFFD97706),
          child: Column(
            children: [
              _rule(
                Icons.inventory_2_outlined,
                'لا يمكن تحويل كمية أكبر من الرصيد المتاح بالمصدر.',
              ),
              _rule(
                Icons.location_on_outlined,
                'يجب أن يختلف مخزن المصدر عن مخزن الوجهة.',
              ),
              _rule(
                Icons.history_rounded,
                'يُسجل النظام حركتي خروج ودخول بنفس مرجع التحويل.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _branchDropdown({
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int?>(
      value: value,
      isExpanded: true,
      decoration: inventoryInputDecoration(
        context,
        label: 'الفرع *',
        icon: Icons.business_rounded,
      ),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text('اختر الفرع', style: GoogleFonts.cairo()),
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
      onChanged: onChanged,
    );
  }

  Widget _warehouseDropdown({
    required int? value,
    required List<dynamic> warehouses,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int?>(
      value: value,
      isExpanded: true,
      decoration: inventoryInputDecoration(
        context,
        label: 'المخزن *',
        icon: Icons.warehouse_rounded,
      ),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text('اختر المخزن', style: GoogleFonts.cairo()),
        ),
        ...warehouses.map(
          (warehouse) => DropdownMenuItem<int?>(
            value: warehouse['WarehouseID'] ?? warehouse['WarehouseId'],
            child: Text(
              warehouse['WarehouseName'] ?? '',
              style: GoogleFonts.cairo(),
            ),
          ),
        ),
      ],
      onChanged: warehouses.isEmpty ? null : onChanged,
    );
  }

  Widget _rule(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(fontSize: 11, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.red.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(_error ?? 'حدث خطأ')),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
