import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants.dart';
import '../../services/app_colors.dart';
import '../../services/theme_service.dart';
import '../../services/inventory_service.dart';
import '../../widgets/crm_design_system.dart';

/// قيمة المخزون - مطابق بلازور Inventory/StockValue.razor
/// تقييم مالي: تكلفة + بيع متوقعة + ربح حسب الفرع/المخزن/باقة السعر
/// تصميم بهوية فلاتر navy+gold
class StockValueScreen extends StatefulWidget {
  final int userId;
  final String username;

  const StockValueScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<StockValueScreen> createState() => _StockValueScreenState();
}

class _StockValueScreenState extends State<StockValueScreen> {
  bool _loading = true;
  bool _busy = false;
  List<dynamic> _branches = [];
  List<dynamic> _warehouses = [];
  List<dynamic> _allWarehouses = [];
  List<dynamic> _rows = [];
  Map<String, dynamic> _summary = {
    'TotalCostValue': 0,
    'TotalSaleValue': 0,
    'TotalExpectedProfit': 0,
    'TotalProducts': 0,
    'TotalQuantity': 0,
    'WarehousesCount': 0,
  };

  int? _branchId;
  int? _warehouseId;
  String _tier = 'Premium'; // Premium | CClass | Elite

  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _loadData();
  }

  Future<void> _loadLookups() async {
    try {
      final branches = await InventoryService.getBranches();
      final warehouses = await InventoryService.getAllWarehouses();
      if (mounted) setState(() {
        _branches = branches;
        _warehouses = warehouses;
        _allWarehouses = warehouses;
      });
    } catch (_) {}
  }

  Future<void> _onBranchChanged(int? branchId) async {
    setState(() {
      _branchId = branchId;
      _warehouseId = null;
    });
    if (branchId != null) {
      final wh = await InventoryService.getWarehouses(branchId: branchId);
      if (mounted) setState(() => _warehouses = wh);
    } else {
      setState(() => _warehouses = _allWarehouses);
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _busy = true);
    try {
      // نحسب قيمة المخزون من StockLevels + Products أسعار حسب الباقة
      String url = '$baseUrl/api/products?';
      if (_branchId != null) url += 'branchId=$_branchId&';
      if (_warehouseId != null) url += 'warehouseId=$_warehouseId&';
      url = url.endsWith('&') || url.endsWith('?') ? url.substring(0, url.length - 1) : url;

      final productsRes = await http.get(Uri.parse(url));
      List<dynamic> products = [];
      if (productsRes.statusCode == 200) {
        products = jsonDecode(productsRes.body) as List;
      }

      // جلب كل مستويات المخزون
      final stockLevels = await InventoryService.getStockLevels(warehouseId: _warehouseId);

      // Build rows: لكل مستوى مخزون + أسعار المنتج حسب الباقة
      final Map<int, Map<String, dynamic>> productMap = {};
      for (final p in products) {
        final id = p['ProductID'] ?? p['ProductId'] ?? 0;
        if (id is int) productMap[id] = Map<String, dynamic>.from(p as Map);
        else if (int.tryParse('$id') != null) productMap[int.parse('$id')] = Map<String, dynamic>.from(p as Map);
      }

      List<dynamic> rows = [];
      double totalCost = 0;
      double totalSale = 0;
      int totalQty = 0;
      final Set<int> whSet = {};

      for (final sl in stockLevels) {
        final pid = sl['ProductID'] ?? sl['ProductId'] ?? 0;
        final whId = sl['WarehouseID'] ?? sl['WarehouseId'] ?? 0;
        final qty = sl['Quantity'] ?? 0;
        if (qty <= 0) continue;

        // لو فيه فلتر فرع، تأكد المخزن تابع للفرع
        if (_branchId != null) {
          final wh = _allWarehouses.firstWhere((w) => (w['WarehouseID'] ?? w['WarehouseId']) == whId, orElse: () => null);
          if (wh != null) {
            final bId = wh['BranchId'] ?? wh['BranchID'];
            if (bId != _branchId) continue;
          }
        }

        final product = productMap[pid] ?? {};
        double unitCost = 0;
        double unitSale = 0;

        switch (_tier) {
          case 'CClass':
            unitCost = (product['PurchasePriceCClass'] ?? product['PurchasePrice'] ?? 0).toDouble();
            unitSale = (product['SuggestedSalePriceCClass'] ?? product['SuggestedSalePrice'] ?? 0).toDouble();
            break;
          case 'Elite':
            unitCost = (product['PurchasePriceElite'] ?? product['PurchasePrice'] ?? 0).toDouble();
            unitSale = (product['SuggestedSalePriceElite'] ?? product['SuggestedSalePrice'] ?? 0).toDouble();
            break;
          case 'Premium':
          default:
            unitCost = (product['PurchasePrice'] ?? 0).toDouble();
            unitSale = (product['SuggestedSalePrice'] ?? 0).toDouble();
            break;
        }

        final costValue = unitCost * qty;
        final saleValue = unitSale * qty;
        final profit = saleValue - costValue;

        final whName = sl['WarehouseName'] ?? _allWarehouses.firstWhere((w) => (w['WarehouseID'] ?? w['WarehouseId']) == whId, orElse: () => {'WarehouseName': '—'})['WarehouseName'] ?? '—';
        final branchName = _branches.firstWhere((b) => (b['BranchId'] ?? b['BranchID']) == (sl['BranchId'] ?? 0), orElse: () => null)?['BranchNameAr'] ?? '';

        rows.add({
          'ProductId': pid,
          'ProductName': product['ProductName'] ?? sl['ProductName'] ?? '—',
          'WarehouseName': whName,
          'BranchNameAr': branchName,
          'Quantity': qty,
          'UnitCost': unitCost,
          'CostValue': costValue,
          'UnitSalePrice': unitSale,
          'SaleValue': saleValue,
          'ExpectedProfit': profit,
        });

        totalCost += costValue;
        totalSale += saleValue;
        totalQty += qty as int;
        whSet.add(whId is int ? whId : int.tryParse('$whId') ?? 0);
      }

      if (mounted) setState(() {
        _rows = rows;
        _summary = {
          'TotalCostValue': totalCost,
          'TotalSaleValue': totalSale,
          'TotalExpectedProfit': totalSale - totalCost,
          'TotalProducts': productMap.length,
          'TotalQuantity': totalQty,
          'WarehousesCount': whSet.length,
        };
      });
    } catch (e) {
      debugPrint('StockValue error: $e');
    } finally {
      if (mounted) setState(() {
        _loading = false;
        _busy = false;
      });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    try {
      final numericValue = v is num ? v : double.tryParse('$v') ?? 0;
      return NumberFormat('#,###').format(numericValue);
    } catch (_) {
      return '$v';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
        body: NestedScrollView(
          headerSliverBuilder: (ctx, inner) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 150,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              title: Text('قيمة المخزون', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
              actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
              flexibleSpace: FlexibleSpaceBar(background: _buildHero()),
            ),
            SliverToBoxAdapter(child: _buildFilters()),
            SliverToBoxAdapter(child: _buildKpis()),
          ],
          body: _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
              : _rows.isEmpty
                  ? CrmDesignSystem.emptyState(message: 'لا توجد بيانات قيمة مخزون', hint: 'جرب تغيير الفلاتر', icon: Icons.attach_money_rounded, onRefresh: _loadData)
                  : RefreshIndicator(
                      color: AppColors.gold,
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                        itemCount: _rows.length,
                        itemBuilder: (_, i) => _ValueRowCard(row: _rows[i], isDark: _isDark, fmt: _fmt),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF1E293B), const Color(0xFF134E4A), const Color(0xFF166534)], begin: Alignment.topRight, end: Alignment.bottomLeft)),
      child: Stack(children: [
        Positioned(top: -20, right: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle))),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
            child: Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.inventory_2_rounded, color: AppColors.gold, size: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('قيمة المخزون', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text('تقييم مالي للمخزون: قيمة التكلفة وقيمة البيع المتوقعة — حسب الفلاتر وباقة السعر', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11, height: 1.3)),
              ])),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card(_isDark), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withOpacity(0.06))),
      child: Row(children: [
        Expanded(child: DropdownButtonFormField<int?>(value: _branchId, decoration: InputDecoration(labelText: 'الفرع', labelStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)), items: [DropdownMenuItem<int?>(value: null, child: Text('كل الفروع', style: GoogleFonts.cairo(fontSize: 12))), ..._branches.map((b) => DropdownMenuItem<int?>(value: b['BranchId'] ?? b['BranchID'], child: Text(b['BranchNameAr'] ?? b['BranchName'] ?? '', style: GoogleFonts.cairo(fontSize: 12))))], onChanged: (v) => _onBranchChanged(v))),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<int?>(value: _warehouseId, decoration: InputDecoration(labelText: 'المخزن', labelStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)), items: [DropdownMenuItem<int?>(value: null, child: Text('كل المخازن', style: GoogleFonts.cairo(fontSize: 12))), ..._warehouses.map((w) => DropdownMenuItem<int?>(value: w['WarehouseID'] ?? w['WarehouseId'], child: Text(w['WarehouseName'] ?? '', style: GoogleFonts.cairo(fontSize: 12))))], onChanged: (v) { setState(() => _warehouseId = v); _loadData(); })),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String>(value: _tier, decoration: InputDecoration(labelText: 'باقة السعر', labelStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)), items: [DropdownMenuItem<String>(value: 'Premium', child: Text('بريميوم', style: GoogleFonts.cairo(fontSize: 12))), DropdownMenuItem<String>(value: 'CClass', child: Text('ستاندرد', style: GoogleFonts.cairo(fontSize: 12))), DropdownMenuItem<String>(value: 'Elite', child: Text('إيليت', style: GoogleFonts.cairo(fontSize: 12)))], onChanged: (v) { setState(() => _tier = v ?? 'Premium'); _loadData(); })),
        const SizedBox(width: 8),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _busy ? null : _loadData, icon: _busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh_rounded, size: 16, color: Colors.white), label: Text(_busy ? 'جاري...' : 'تحديث', style: GoogleFonts.cairo(color: Colors.white, fontSize: 11))),
      ]),
    );
  }

  Widget _buildKpis() {
    return Container(
      color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(children: [
        _kpi('إجمالي قيمة التكلفة', _fmt(_summary['TotalCostValue']), const Color(0xFFB45309)),
        const SizedBox(width: 8),
        _kpi('إجمالي قيمة البيع', _fmt(_summary['TotalSaleValue']), const Color(0xFF16A34A)),
        const SizedBox(width: 8),
        _kpi('الربح المتوقع', _fmt(_summary['TotalExpectedProfit']), const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        _kpi('${_summary['TotalProducts']} صنف • ${_summary['TotalQuantity']} وحدة • ${_summary['WarehousesCount']} مخزن', '${_rows.length} سجل', const Color(0xFF475569)),
      ]),
    );
  }

  Widget _kpi(String label, String val, Color c) {
    return Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: [c.withOpacity(0.85), c], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: c.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text(val, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)])));
  }
}

class _ValueRowCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isDark;
  final String Function(dynamic) fmt;

  const _ValueRowCard({required this.row, required this.isDark, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final profit = (row['ExpectedProfit'] ?? 0).toDouble();
    final profitColor = profit >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card(isDark), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(row['ProductName'] ?? '', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12))),
          Text('الكمية ${row['Quantity']}', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
        ]),
        const SizedBox(height: 6),
        Text('${row['WarehouseName']} • ${row['BranchNameAr'] ?? '—'}', style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Row(children: [
          _valBox('تكلفة الوحدة', fmt(row['UnitCost']), Colors.orange),
          const SizedBox(width: 6),
          _valBox('قيمة التكلفة', fmt(row['CostValue']), const Color(0xFFB45309)),
          const SizedBox(width: 6),
          _valBox('سعر البيع', fmt(row['UnitSalePrice']), Colors.green),
          const SizedBox(width: 6),
          _valBox('قيمة البيع', fmt(row['SaleValue']), const Color(0xFF16A34A)),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: profitColor.withOpacity(0.10), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(profit >=0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 14, color: profitColor), const SizedBox(width: 6), Text('الربح المتوقع ${fmt(profit)} ج', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: profitColor))])),
      ]),
    );
  }

  Widget _valBox(String label, String val, Color c) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Column(children: [Text(label, style: GoogleFonts.cairo(fontSize: 9, color: Colors.grey.shade600)), const SizedBox(height: 2), Text(val, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: c))])));
  }
}
