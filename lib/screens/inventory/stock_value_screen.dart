import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../widgets/design_kit.dart';
import '../../services/theme_service.dart';
import '../../services/inventory_service.dart';
import '../../widgets/crm_design_system.dart';

import '../../widgets/app_drawer.dart';
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

  String? _error;

  Future<void> _loadData() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // قيمة المخزون تُحسب خادميًا فقط (GET /api/inventory/stock-value —
      // مرآة GetStockValueAsync): أسعار الشراء محجوبة عن أغلب الأدوار في
      // واجهة المنتجات، فأي حساب محلي كان يخرج أصفارًا مضللة. الشاشة
      // مقصورة خادميًا على المدير ومدير الحسابات، وخطأ 403 يظهر بصدق.
      final result = await InventoryService.getStockValue(
        branchId: _branchId,
        warehouseId: _warehouseId,
        priceTier: _tier,
      );
      final rows = (result['rows'] as List?) ?? const [];
      final summary = result['summary'];
      if (mounted) setState(() {
        _rows = rows;
        if (summary is Map) {
          _summary = Map<String, dynamic>.from(summary);
        }
      });
    } catch (e) {
      debugPrint('StockValue error: $e');
      if (mounted) setState(() {
        _rows = [];
        _error = e is InventoryApiException && e.statusCode == 403
            ? 'غير مصرح لك بعرض قيمة المخزون — الشاشة مقصورة على المدير ومدير الحسابات'
            : 'فشل تحميل قيمة المخزون: $e';
      });
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
        drawer: buildAppDrawer(currentRoute: 'frm_StockValue'),
        backgroundColor: AppColors.background(_isDark),
        body: NestedScrollView(
          headerSliverBuilder: (ctx, inner) => [
            SliverAppBar( leading: const AppDrawerMenuButton(),
              pinned: true,
              expandedHeight: 150,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text('قيمة المخزون', style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
              actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData)],
              flexibleSpace: FlexibleSpaceBar(background: _buildHero()),
            ),
            SliverToBoxAdapter(child: _buildFilters()),
            SliverToBoxAdapter(child: _buildKpis()),
          ],
          body: _loading
              ? const AppLoading()
              : _error != null
                  ? AppEmpty(message: _error!, hint: 'تحقق من الصلاحية ثم أعد المحاولة', icon: Icons.lock_outline_rounded, onRefresh: _loadData)
                  : _rows.isEmpty
                  ? AppEmpty(message: 'لا توجد بيانات قيمة مخزون', hint: 'جرب تغيير الفلاتر', icon: Icons.attach_money_rounded, onRefresh: _loadData)
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
      decoration: BoxDecoration(gradient: LinearGradient(colors: AppGradients.identityHeader, begin: Alignment.topRight, end: Alignment.bottomLeft)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.md,
      child: Row(children: [
        Expanded(child: DropdownButtonFormField<int?>(value: _branchId, decoration: InputDecoration(labelText: 'الفرع', labelStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)), items: [DropdownMenuItem<int?>(value: null, child: Text('كل الفروع', style: GoogleFonts.cairo(fontSize: 12))), ..._branches.map((b) => DropdownMenuItem<int?>(value: b['BranchId'] ?? b['BranchID'], child: Text(b['BranchNameAr'] ?? b['BranchName'] ?? '', style: GoogleFonts.cairo(fontSize: 12))))], onChanged: (v) => _onBranchChanged(v))),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<int?>(value: _warehouseId, decoration: InputDecoration(labelText: 'المخزن', labelStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)), items: [DropdownMenuItem<int?>(value: null, child: Text('كل المخازن', style: GoogleFonts.cairo(fontSize: 12))), ..._warehouses.map((w) => DropdownMenuItem<int?>(value: w['WarehouseID'] ?? w['WarehouseId'], child: Text(w['WarehouseName'] ?? '', style: GoogleFonts.cairo(fontSize: 12))))], onChanged: (v) { setState(() => _warehouseId = v); _loadData(); })),
        const SizedBox(width: 8),
        Expanded(child: DropdownButtonFormField<String>(value: _tier, decoration: InputDecoration(labelText: 'باقة السعر', labelStyle: GoogleFonts.cairo(fontSize: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)), items: [DropdownMenuItem<String>(value: 'Premium', child: Text('بريميوم', style: GoogleFonts.cairo(fontSize: 12))), DropdownMenuItem<String>(value: 'CClass', child: Text('ستاندرد', style: GoogleFonts.cairo(fontSize: 12))), DropdownMenuItem<String>(value: 'Elite', child: Text('إيليت', style: GoogleFonts.cairo(fontSize: 12)))], onChanged: (v) { setState(() => _tier = v ?? 'Premium'); _loadData(); })),
        const SizedBox(width: 8),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _busy ? null : _loadData, icon: _busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh_rounded, size: 16, color: Colors.white), label: Text(_busy ? 'جاري...' : 'تحديث', style: GoogleFonts.cairo(color: Colors.white, fontSize: 11))),
      ]),
      ),
    );
  }

  Widget _buildKpis() {
    return Container(
      color: AppColors.background(_isDark),
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
    return Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: [c.withOpacity(0.85), c], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: c.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), AmountText(value: val, color: Colors.white, size: 13)])));
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.sm,
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
      ),
    );
  }

  Widget _valBox(String label, String val, Color c) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Column(children: [Text(label, style: GoogleFonts.cairo(fontSize: 9, color: Colors.grey.shade600)), const SizedBox(height: 2), AmountText(value: val, color: c, size: 11)])));
  }
}
