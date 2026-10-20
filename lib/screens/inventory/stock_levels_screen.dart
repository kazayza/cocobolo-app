import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/app_colors.dart';
import '../../services/inventory_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/inventory_design.dart';
import 'stock_entry_screen.dart';

class StockLevelsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const StockLevelsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<StockLevelsScreen> createState() => _StockLevelsScreenState();
}

class _StockLevelsScreenState extends State<StockLevelsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<dynamic> _branches = [];
  List<dynamic> _warehouses = [];
  List<dynamic> _levels = [];
  int? _branchId;
  int? _warehouseId;
  String _stockFilter = 'all';

  bool get _isDark => ThemeService().isDarkMode;

  List<Map<String, dynamic>> get _rows {
    final query = _searchController.text.trim().toLowerCase();
    return _levels
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((row) {
          final quantity = _toInt(row['Quantity']);
          if (_stockFilter == 'available' && quantity <= 0) return false;
          if (_stockFilter == 'low' && (quantity <= 0 || quantity > 5)) {
            return false;
          }
          if (_stockFilter == 'out' && quantity != 0) return false;
          if (query.isEmpty) return true;
          final text = [
            row['ProductName'],
            row['ProductDescription'],
            row['ProductID'],
            row['WarehouseName'],
            row['BranchNameAr'],
          ].join(' ').toLowerCase();
          return text.contains(query);
        })
        .toList();
  }

  int get _totalQuantity =>
      _levels.fold(0, (sum, row) => sum + _toInt(row['Quantity']));
  int get _availableCount =>
      _levels.where((row) => _toInt(row['Quantity']) > 0).length;
  int get _lowCount => _levels
      .where((row) => _toInt(row['Quantity']) > 0 && _toInt(row['Quantity']) <= 5)
      .length;
  int get _outCount =>
      _levels.where((row) => _toInt(row['Quantity']) == 0).length;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) =>
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
      await _loadLevels(keepLoading: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadLevels({bool keepLoading = false}) async {
    if (!keepLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final levels = await InventoryService.getStockLevels(
        branchId: _branchId,
        warehouseId: _warehouseId,
      );
      if (!mounted) return;
      setState(() {
        _levels = levels;
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
      await _loadLevels();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() {});
    });
  }

  void _resetFilters() {
    setState(() {
      _branchId = null;
      _warehouseId = null;
      _stockFilter = 'all';
      _searchController.clear();
    });
    _bootstrap();
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
            'أرصدة المخزون',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _loadLevels,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _loadLevels,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: [
              InventoryHero(
                icon: Icons.inventory_rounded,
                title: 'أرصدة المخزون الحالية',
                subtitle:
                    'عرض الرصيد الفعلي لكل منتج حسب الفرع والمخزن مع تنبيه النواقص.',
                action: IconButton.filledTonal(
                  tooltip: 'إضافة رصيد',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockEntryScreen(
                          userId: widget.userId,
                          username: widget.username,
                        ),
                      ),
                    );
                    _loadLevels();
                  },
                  icon: const Icon(Icons.add_box_rounded),
                ),
                stats: [
                  InventoryHeroStat(
                    icon: Icons.category_rounded,
                    label: 'منتجات',
                    value: '${_levels.length}',
                    color: Colors.white,
                  ),
                  InventoryHeroStat(
                    icon: Icons.inventory_2_rounded,
                    label: 'إجمالي الوحدات',
                    value: NumberFormat('#,###').format(_totalQuantity),
                    color: AppColors.gold,
                  ),
                  InventoryHeroStat(
                    icon: Icons.warning_amber_rounded,
                    label: 'رصيد منخفض',
                    value: '$_lowCount',
                    color: const Color(0xFFF59E0B),
                  ),
                  InventoryHeroStat(
                    icon: Icons.remove_shopping_cart_rounded,
                    label: 'نفد الرصيد',
                    value: '$_outCount',
                    color: const Color(0xFFFB7185),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InventorySection(
                title: 'البحث والتصفية',
                subtitle: 'حدد موقع المخزون أو ابحث باسم المنتج أو الكود.',
                icon: Icons.tune_rounded,
                color: AppColors.gold,
                trailing: TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.restart_alt_rounded, size: 17),
                  label: Text('إعادة ضبط', style: GoogleFonts.cairo()),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      decoration: inventoryInputDecoration(
                        context,
                        label: 'بحث',
                        hint: 'اسم المنتج، الوصف أو الكود',
                        icon: Icons.search_rounded,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 620;
                        final fields = [
                          _branchDropdown(),
                          _warehouseDropdown(),
                        ];
                        if (compact) {
                          return Column(
                            children: [
                              fields[0],
                              const SizedBox(height: 10),
                              fields[1],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: fields[0]),
                            const SizedBox(width: 10),
                            Expanded(child: fields[1]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'all',
                            label: Text('الكل'),
                            icon: Icon(Icons.select_all_rounded),
                          ),
                          ButtonSegment(
                            value: 'available',
                            label: Text('متاح'),
                            icon: Icon(Icons.check_circle_outline_rounded),
                          ),
                          ButtonSegment(
                            value: 'low',
                            label: Text('منخفض'),
                            icon: Icon(Icons.warning_amber_rounded),
                          ),
                          ButtonSegment(
                            value: 'out',
                            label: Text('نفد'),
                            icon: Icon(Icons.remove_circle_outline_rounded),
                          ),
                        ],
                        selected: {_stockFilter},
                        onSelectionChanged: (value) {
                          setState(() => _stockFilter = value.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _errorCard()
              else if (_rows.isEmpty)
                _emptyCard()
              else ...[
                Row(
                  children: [
                    Text(
                      'نتائج الأرصدة',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_rows.length} سجل',
                      style: GoogleFonts.cairo(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._rows.map((row) => _StockLevelCard(row: row)),
              ],
            ],
          ),
        ),
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
        _loadLevels();
      },
    );
  }

  Widget _errorCard() {
    return InventorySection(
      title: 'تعذر تحميل الأرصدة',
      subtitle: _error,
      icon: Icons.error_outline_rounded,
      color: Colors.red,
      child: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _bootstrap,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      ),
    );
  }

  Widget _emptyCard() {
    return InventorySection(
      title: 'لا توجد أرصدة مطابقة',
      subtitle: 'غيّر الفلاتر أو أضف رصيدًا للمخزن المختار.',
      icon: Icons.inventory_2_outlined,
      color: AppColors.gold,
      child: const SizedBox.shrink(),
    );
  }
}

class _StockLevelCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _StockLevelCard({required this.row});

  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final dark = ThemeService().isDarkMode;
    final quantity = _int(row['Quantity']);
    final color = quantity == 0
        ? const Color(0xFFDC2626)
        : quantity <= 5
            ? const Color(0xFFD97706)
            : const Color(0xFF059669);
    final lastUpdated = DateTime.tryParse('${row['LastUpdatedAt'] ?? ''}');

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.inventory_2_rounded, color: color, size: 23),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['ProductName'] ?? 'منتج بدون اسم',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 10,
                  runSpacing: 3,
                  children: [
                    _info(Icons.tag_rounded, '#${row['ProductID']}'),
                    _info(
                      Icons.warehouse_rounded,
                      row['WarehouseName'] ?? '—',
                    ),
                    if ((row['BranchNameAr'] ?? '').toString().isNotEmpty)
                      _info(Icons.business_rounded, row['BranchNameAr']),
                    if (lastUpdated != null)
                      _info(
                        Icons.update_rounded,
                        DateFormat('yyyy/MM/dd HH:mm').format(lastUpdated),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 62),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              children: [
                Text(
                  NumberFormat('#,###').format(quantity),
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  quantity == 0
                      ? 'نفد'
                      : quantity <= 5
                          ? 'منخفض'
                          : 'متاح',
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
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}
