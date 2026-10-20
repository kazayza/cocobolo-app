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

class StockEntryScreen extends StatefulWidget {
  final int userId;
  final String username;

  const StockEntryScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends State<StockEntryScreen> {
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _productSearchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<dynamic> _branches = [];
  List<dynamic> _warehouses = [];
  Map<String, dynamic>? _selectedProduct;
  int? _branchId;
  int? _warehouseId;
  String _entryReason = 'OpeningBalance';
  int _currentStock = 0;

  bool get _isDark => ThemeService().isDarkMode;
  int get _quantity => int.tryParse(_quantityController.text) ?? 0;
  int get _projectedStock => _currentStock + _quantity;

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
    _priceController.dispose();
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

  Future<void> _changeBranch(int? value) async {
    setState(() {
      _branchId = value;
      _warehouseId = null;
      _warehouses = [];
      _selectedProduct = null;
      _productSearchController.clear();
      _currentStock = 0;
    });
    if (value == null) return;
    try {
      final warehouses = await InventoryService.getWarehouses(branchId: value);
      if (mounted) setState(() => _warehouses = warehouses);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _changeWarehouse(int? value) async {
    setState(() {
      _warehouseId = value;
      _currentStock = 0;
    });
    await _refreshStock();
  }

  Future<List<dynamic>> _searchProducts(String query) async {
    if (query.trim().length < 2) return const [];
    final uri = Uri.parse('$baseUrl/api/products').replace(
      queryParameters: {
        'search': query.trim(),
        if (_warehouseId != null) 'warehouseId': '$_warehouseId',
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List) {
      return decoded['data'] as List;
    }
    return const [];
  }

  Future<void> _pickProduct() async {
    if (_warehouseId == null) {
      _message('اختر الفرع والمخزن أولاً', error: true);
      return;
    }
    final products = await _searchProducts(_productSearchController.text);
    if (!mounted) return;
    if (products.isEmpty) {
      _message('لا توجد منتجات مطابقة للبحث', error: true);
      return;
    }

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.sizeOf(context).height * 0.70,
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
                  const SizedBox(width: 9),
                  Text(
                    'اختر المنتج',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
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
                  final id = product['ProductID'] ?? product['ProductId'];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: _isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    tileColor: _isDark
                        ? const Color(0xFF111C2D)
                        : const Color(0xFFF8FAFC),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x1513273F),
                      child: Icon(Icons.chair_alt_rounded, color: AppColors.navy),
                    ),
                    title: Text(
                      product['ProductName'] ?? 'منتج بدون اسم',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'كود المنتج: $id',
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
      await _refreshStock();
    }
  }

  Future<void> _refreshStock() async {
    final product = _selectedProduct;
    final warehouseId = _warehouseId;
    if (product == null || warehouseId == null) return;
    try {
      final productId = product['ProductID'] ?? product['ProductId'];
      final quantity = await InventoryService.getCurrentStock(
        productId: productId is int ? productId : int.parse('$productId'),
        warehouseId: warehouseId,
      );
      if (mounted) setState(() => _currentStock = quantity);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _save() async {
    if (_branchId == null || _warehouseId == null) {
      _message('اختيار الفرع والمخزن مطلوب', error: true);
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

    setState(() => _saving = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/inventory/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'productId': _selectedProduct!['ProductID'] ??
              _selectedProduct!['ProductId'],
          'warehouseId': _warehouseId,
          'transactionType': 'In',
          'quantity': _quantity,
          'unitPrice': double.tryParse(_priceController.text) ?? 0,
          'referenceType': _entryReason,
          'notes': _notesController.text.trim(),
          'createdBy': widget.username,
        }),
      );
      final decoded = jsonDecode(response.body);
      final success = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (decoded['success'] == true || decoded['success'] == null);
      if (!success) {
        throw InventoryApiException(
          decoded['message']?.toString() ?? 'فشل إضافة الرصيد',
          statusCode: response.statusCode,
        );
      }
      if (!mounted) return;
      setState(() => _currentStock = _projectedStock);
      _message('تمت إضافة الرصيد وتسجيل حركة الدخول');
      _resetEntry();
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

  void _changeQuantity(int delta) {
    final next = (_quantity + delta).clamp(1, 999999);
    _quantityController.text = '$next';
  }

  void _resetEntry() {
    setState(() {
      _selectedProduct = null;
      _productSearchController.clear();
      _quantityController.text = '1';
      _priceController.clear();
      _notesController.clear();
    });
  }

  void _resetAll() {
    setState(() {
      _branchId = null;
      _warehouseId = null;
      _warehouses = [];
      _currentStock = 0;
      _entryReason = 'OpeningBalance';
    });
    _resetEntry();
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
            'إضافة رصيد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
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
                    icon: Icons.add_box_rounded,
                    title: 'إضافة رصيد للمخزن',
                    subtitle:
                        'سجل دخول كمية فعلية لمنتج داخل مخزن محدد مع توثيق سبب الحركة.',
                    stats: [
                      InventoryHeroStat(
                        icon: Icons.inventory_rounded,
                        label: 'الرصيد الحالي',
                        value: '$_currentStock',
                        color: Colors.white,
                      ),
                      InventoryHeroStat(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'الكمية المضافة',
                        value: '$_quantity',
                        color: AppColors.gold,
                      ),
                      InventoryHeroStat(
                        icon: Icons.assessment_outlined,
                        label: 'الرصيد بعد الحفظ',
                        value: '$_projectedStock',
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
                      final compact = constraints.maxWidth < 760;
                      final form = _formSection();
                      final preview = _previewSection();
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
                          Text('جاري تسجيل الرصيد...', style: GoogleFonts.cairo()),
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

  Widget _formSection() {
    return InventorySection(
      title: 'بيانات حركة الدخول',
      subtitle: 'أكمل البيانات بالترتيب لضمان تسجيل الرصيد في الموقع الصحيح.',
      icon: Icons.playlist_add_rounded,
      color: AppColors.gold,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              if (compact) {
                return Column(
                  children: [
                    _branchDropdown(),
                    const SizedBox(height: 10),
                    _warehouseDropdown(),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _branchDropdown()),
                  const SizedBox(width: 10),
                  Expanded(child: _warehouseDropdown()),
                ],
              );
            },
          ),
          const SizedBox(height: 11),
          TextField(
            controller: _productSearchController,
            enabled: _warehouseId != null,
            onSubmitted: (_) => _pickProduct(),
            decoration: inventoryInputDecoration(
              context,
              label: _selectedProduct == null
                  ? 'المنتج *'
                  : _selectedProduct!['ProductName'] ?? 'المنتج',
              hint: _warehouseId == null
                  ? 'اختر المخزن أولاً'
                  : 'اكتب حرفين على الأقل ثم ابحث',
              icon: Icons.inventory_2_rounded,
            ).copyWith(
              suffixIcon: IconButton(
                tooltip: 'اختيار المنتج',
                onPressed: _warehouseId == null ? null : _pickProduct,
                icon: const Icon(Icons.manage_search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final quantity = _quantityField();
              final price = TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: inventoryInputDecoration(
                  context,
                  label: 'تكلفة مرجعية',
                  icon: Icons.payments_outlined,
                ),
              );
              if (compact) {
                return Column(
                  children: [
                    quantity,
                    const SizedBox(height: 10),
                    price,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: quantity),
                  const SizedBox(width: 10),
                  Expanded(child: price),
                ],
              );
            },
          ),
          const SizedBox(height: 11),
          _reasonDropdown(),
          const SizedBox(height: 11),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: inventoryInputDecoration(
              context,
              label: 'ملاحظات الحركة',
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
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  'حفظ حركة الدخول',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewSection() {
    return Column(
      children: [
        InventorySection(
          title: 'معاينة الرصيد',
          subtitle: _selectedProduct == null
              ? 'اختر منتجًا لعرض أثر الحركة.'
              : _selectedProduct!['ProductName']?.toString(),
          icon: Icons.assessment_rounded,
          color: const Color(0xFF2563EB),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InventoryMetricCard(
                      icon: Icons.inventory_outlined,
                      label: 'قبل الإضافة',
                      value: '$_currentStock',
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: InventoryMetricCard(
                      icon: Icons.inventory_rounded,
                      label: 'بعد الإضافة',
                      value: '$_projectedStock',
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _previewLine(
                Icons.business_rounded,
                'الفرع',
                _selectedBranchName(),
              ),
              _previewLine(
                Icons.warehouse_rounded,
                'المخزن',
                _selectedWarehouseName(),
              ),
              _previewLine(
                Icons.description_outlined,
                'سبب الحركة',
                _reasonLabel(_entryReason),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        InventorySection(
          title: 'ضوابط التسجيل',
          icon: Icons.verified_user_outlined,
          color: const Color(0xFFD97706),
          child: Column(
            children: [
              _rule(
                Icons.check_circle_outline_rounded,
                'تأكد أن الكمية موجودة فعليًا داخل الموقع المختار.',
              ),
              _rule(
                Icons.receipt_long_outlined,
                'اكتب ملاحظة واضحة عند التسويات أو الرصيد الافتتاحي.',
              ),
              _rule(
                Icons.history_rounded,
                'بعد الحفظ ستظهر الحركة في سجل حركة المخزون.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _branchDropdown() {
    return DropdownButtonFormField<int?>(
      value: _branchId,
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
      onChanged: _changeBranch,
    );
  }

  Widget _warehouseDropdown() {
    return DropdownButtonFormField<int?>(
      value: _warehouseId,
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
      onChanged: _warehouses.isEmpty ? null : _changeWarehouse,
    );
  }

  Widget _quantityField() {
    return TextField(
      controller: _quantityController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: inventoryInputDecoration(
        context,
        label: 'الكمية *',
        icon: Icons.numbers_rounded,
      ).copyWith(
        suffixIcon: IconButton(
          onPressed: () => _changeQuantity(1),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
        prefixIcon: IconButton(
          onPressed: () => _changeQuantity(-1),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
      ),
    );
  }

  Widget _reasonDropdown() {
    return DropdownButtonFormField<String>(
      value: _entryReason,
      isExpanded: true,
      decoration: inventoryInputDecoration(
        context,
        label: 'سبب الحركة *',
        icon: Icons.description_outlined,
      ),
      items: [
        DropdownMenuItem(
          value: 'OpeningBalance',
          child: Text('رصيد افتتاحي', style: GoogleFonts.cairo()),
        ),
        DropdownMenuItem(
          value: 'ShowroomSupply',
          child: Text('إدخال للمخزن أو صالة العرض', style: GoogleFonts.cairo()),
        ),
        DropdownMenuItem(
          value: 'FactoryReceive',
          child: Text('استلام من المصنع', style: GoogleFonts.cairo()),
        ),
        DropdownMenuItem(
          value: 'Adjustment',
          child: Text('تسوية مخزنية', style: GoogleFonts.cairo()),
        ),
      ],
      onChanged: (value) {
        setState(() => _entryReason = value ?? 'OpeningBalance');
      },
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

  Widget _previewLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 7),
          Text('$label:', style: GoogleFonts.cairo(fontSize: 11)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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

  String _selectedBranchName() {
    final id = _branchId;
    if (id == null) return 'لم يتم الاختيار';
    final value = _branches.firstWhere(
      (branch) => (branch['BranchId'] ?? branch['BranchID']) == id,
      orElse: () => null,
    );
    return value == null
        ? '—'
        : '${value['BranchNameAr'] ?? value['BranchName'] ?? '—'}';
  }

  String _selectedWarehouseName() {
    final id = _warehouseId;
    if (id == null) return 'لم يتم الاختيار';
    final value = _warehouses.firstWhere(
      (warehouse) =>
          (warehouse['WarehouseID'] ?? warehouse['WarehouseId']) == id,
      orElse: () => null,
    );
    return value == null ? '—' : '${value['WarehouseName'] ?? '—'}';
  }

  String _reasonLabel(String value) => switch (value) {
        'ShowroomSupply' => 'إدخال للمخزن أو صالة العرض',
        'FactoryReceive' => 'استلام من المصنع',
        'Adjustment' => 'تسوية مخزنية',
        _ => 'رصيد افتتاحي',
      };
}
