import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../widgets/design_kit.dart';
import '../../services/inventory_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/inventory_design.dart';
import 'stock_entry_screen.dart';
import '../../widgets/app_drawer.dart';

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

  List get _rows {
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

  bool get _hasActiveFilters =>
      _branchId != null ||
      _warehouseId != null ||
      _stockFilter != 'all' ||
      _searchController.text.isNotEmpty;

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
    final rows = _rows;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        drawer: buildAppDrawer(currentRoute: 'frm_StockLevels'),
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          leading: const AppDrawerMenuButton(),
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'أرصدة المخزون',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _loadLevels,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 3,
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
          icon: const Icon(Icons.add_box_rounded, color: AppColors.gold),
          label: Text(
            'إضافة رصيد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
        ),
        body: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _loadLevels,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── شريط الإحصائيات التفاعلي والفلاتر السريعة ─────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // كروت فلترة تفاعلية بنقرة واحدة
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _InteractiveStatChip(
                              label: 'الكل',
                              value: '${_levels.length}',
                              subValue: '${NumberFormat('#,###').format(_totalQuantity)} وحدة',
                              icon: Icons.inventory_2_rounded,
                              activeColor: AppColors.navy,
                              isSelected: _stockFilter == 'all',
                              onTap: () => setState(() => _stockFilter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _InteractiveStatChip(
                              label: 'متاح',
                              value: '$_availableCount',
                              icon: Icons.check_circle_rounded,
                              activeColor: AppStatus.profit,
                              isSelected: _stockFilter == 'available',
                              onTap: () => setState(() => _stockFilter = 'available'),
                            ),
                            const SizedBox(width: 8),
                            _InteractiveStatChip(
                              label: 'منخفض',
                              value: '$_lowCount',
                              icon: Icons.warning_amber_rounded,
                              activeColor: AppColors.warning,
                              isSelected: _stockFilter == 'low',
                              onTap: () => setState(() => _stockFilter = 'low'),
                            ),
                            const SizedBox(width: 8),
                            _InteractiveStatChip(
                              label: 'نفد',
                              value: '$_outCount',
                              icon: Icons.remove_circle_outline_rounded,
                              activeColor: AppColors.error,
                              isSelected: _stockFilter == 'out',
                              onTap: () => setState(() => _stockFilter = 'out'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // صندوق التصفية والبحث المدمج
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card(_isDark),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: _onSearch,
                              style: GoogleFonts.cairo(fontSize: 13),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'ابحث باسم المنتج، الكود أو المخزن...',
                                hintStyle: GoogleFonts.cairo(fontSize: 12),
                                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: _isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF6F8FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: _branchDropdown()),
                                const SizedBox(width: 8),
                                Expanded(child: _warehouseDropdown()),
                                if (_hasActiveFilters) ...[
                                  const SizedBox(width: 6),
                                  IconButton.filledTonal(
                                    tooltip: 'إعادة ضبط الفلاتر',
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.error.withValues(alpha: 0.1),
                                      foregroundColor: AppColors.error,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: _resetFilters,
                                    icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ترويسة النتائج
                      if (!_loading && _error == null && rows.isNotEmpty)
                        Row(
                          children: [
                            Text(
                              'قائمة المنتجات',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${rows.length} سجل',
                                style: GoogleFonts.cairo(
                                  color: AppColors.navy,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── حالة التحميل أو الخطأ أو القائمة ─────────────────
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: AppLoading()),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _errorCard(),
                  ),
                )
              else if (rows.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _emptyCard(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _StockLevelCard(row: rows[index]),
                      childCount: rows.length,
                    ),
                  ),
                ),
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
      style: GoogleFonts.cairo(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        prefixIcon: const Icon(Icons.business_rounded, size: 18),
        filled: true,
        fillColor: _isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF6F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text('كل الفروع', style: GoogleFonts.cairo(fontSize: 12)),
        ),
        ..._branches.map(
          (branch) => DropdownMenuItem<int?>(
            value: branch['BranchId'] ?? branch['BranchID'],
            child: Text(
              branch['BranchNameAr'] ?? branch['BranchName'] ?? '',
              style: GoogleFonts.cairo(fontSize: 12),
              overflow: TextOverflow.ellipsis,
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
      style: GoogleFonts.cairo(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        prefixIcon: const Icon(Icons.warehouse_rounded, size: 18),
        filled: true,
        fillColor: _isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF6F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text('كل المخازن', style: GoogleFonts.cairo(fontSize: 12)),
        ),
        ..._warehouses.map(
          (warehouse) => DropdownMenuItem<int?>(
            value: warehouse['WarehouseID'] ?? warehouse['WarehouseId'],
            child: Text(
              warehouse['WarehouseName'] ?? '',
              style: GoogleFonts.cairo(fontSize: 12),
              overflow: TextOverflow.ellipsis,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
          const SizedBox(height: 8),
          Text(
            'تعذر تحميل الأرصدة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.error),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.neutral),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: _bootstrap,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 50, color: AppColors.neutral.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Text(
            'لا توجد منتجات مطابقة للبحث أو الفلتر',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'جرّب تغيير خيارات البحث أو إعادة ضبط الفلاتر.',
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.neutral),
          ),
        ],
      ),
    );
  }
}

// ── شريحة الإحصائية التفاعلية ──────────────────────────────────────
class _InteractiveStatChip extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final IconData icon;
  final Color activeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _InteractiveStatChip({
    required this.label,
    required this.value,
    this.subValue,
    required this.icon,
    required this.activeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : AppColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : Theme.of(context).dividerColor.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isSelected ? activeColor : AppColors.neutral).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: isSelected ? activeColor : AppColors.neutral),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? activeColor : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      value,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? activeColor : null,
                      ),
                    ),
                  ],
                ),
                if (subValue != null)
                  Text(
                    subValue!,
                    style: GoogleFonts.cairo(
                      fontSize: 9.5,
                      color: AppColors.neutral,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── بطاقة عرض رصيد المنتج ──────────────────────────────────────────
class _StockLevelCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _StockLevelCard({required this.row});

  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final dark = ThemeService().isDarkMode;
    final quantity = _int(row['Quantity']);
    final isOut = quantity == 0;
    final isLow = quantity > 0 && quantity <= 5;

    final color = isOut
        ? AppColors.error
        : isLow
            ? AppColors.warning
            : AppStatus.profit;

    final statusText = isOut
        ? 'نفد'
        : isLow
            ? 'منخفض'
            : 'متاح';

    final lastUpdated = DateTime.tryParse('${row['LastUpdatedAt'] ?? ''}');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card(dark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOut
              ? AppColors.error.withValues(alpha: 0.25)
              : Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // مؤشر لوني جانبي للحالة
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // تفاصيل المنتج
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
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
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _tag(Icons.tag_rounded, '#${row['ProductID']}'),
                        _tag(Icons.warehouse_rounded, row['WarehouseName'] ?? '—'),
                        if ((row['BranchNameAr'] ?? '').toString().isNotEmpty)
                          _tag(Icons.business_rounded, row['BranchNameAr']),
                        if (lastUpdated != null)
                          _tag(
                            Icons.access_time_rounded,
                            DateFormat('dd/MM HH:mm').format(lastUpdated),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // صندوق الكمية والبادج
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              constraints: const BoxConstraints(minWidth: 68),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    NumberFormat('#,###').format(quantity),
                    style: GoogleFonts.cairo(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    statusText,
                    style: GoogleFonts.cairo(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.neutral.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.neutral),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: AppColors.neutral,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}