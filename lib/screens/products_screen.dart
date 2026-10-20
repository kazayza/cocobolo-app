import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../core/network/api_client.dart';
import '../services/app_colors.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import 'add_product_screen.dart';
import 'inventory/stock_entry_screen.dart';
import 'price_requests_screen.dart';
import 'price_list_screen.dart';
import 'product_details_screen.dart';

class ProductsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ProductsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ApiClient _api = ApiClient.instance;
  final PermissionService _permissions = PermissionService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> products = <dynamic>[];
  List<dynamic> productGroups = <dynamic>[];
  List<dynamic> pricingStatuses = <dynamic>[];
  List<dynamic> branches = <dynamic>[];
  List<dynamic> warehouses = <dynamic>[];
  List<dynamic> allWarehouses = <dynamic>[];
  Map<String, dynamic> productStats = <String, dynamic>{};

  bool loading = true;
  bool _isRefreshing = false;
  bool _isExporting = false;
  bool _isGridView = false;
  bool _showCostPrices = false;
  String? _errorMessage;
  Timer? _searchDebounce;

  String searchQuery = '';
  int? selectedGroupId;
  int? selectedStatusId;
  int? selectedBranchId;
  int? selectedWarehouseId;
  String ownershipFilter = 'all';
  String pricedFilter = 'all';

  bool get _isDark => ThemeService().isDarkMode;
  bool get _canAdd =>
      _permissions.canAdd(FormNames.productsAdd) &&
      !_permissions.isFactory &&
      !_permissions.isAccount;
  bool get _canEdit =>
      _permissions.canEdit(FormNames.productsAdd) || _permissions.isFactory;
  bool get _canDelete => _permissions.canDelete(FormNames.productsAdd);
  bool get _canOpenPriceList => _permissions.canViewPriceList;
  bool get _canOpenPriceRequests =>
      _permissions.canRequestPriceChange ||
      _permissions.canReviewPriceRequests ||
      _permissions.isAdmin ||
      _permissions.isAccountManager;
  bool get _canExport =>
      _permissions.isAdmin || _permissions.isAccountManager;
  bool get _canStockEntry =>
      _permissions.isAdmin ||
      _permissions.isGeneralManager ||
      _permissions.isAccountManager ||
      _permissions.isWarehouse ||
      _permissions.canAdd(FormNames.stockEntry);
  bool get _canToggleCostPrices =>
      _permissions.canSeeFullProductPricing;
  bool get _displayCostPrices =>
      _permissions.canSeeCostOnlyProductPricing ||
      (_canToggleCostPrices && _showCostPrices);

  Color get _cardColor => AppColors.card(_isDark);
  Color get _textColor => AppColors.text(_isDark);
  Color get _secondaryTextColor => AppColors.textSecondary(_isDark);

  int get _activeFilterCount {
    int count = 0;
    if (selectedGroupId != null) count++;
    if (selectedStatusId != null) count++;
    if (selectedBranchId != null) count++;
    if (selectedWarehouseId != null) count++;
    if (ownershipFilter != 'all') count++;
    if (pricedFilter != 'all') count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }

  List<dynamic> _decodeList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List) {
      return List<dynamic>.from(decoded['data'] as List);
    }
    return <dynamic>[];
  }

  Map<String, dynamic> _decodeMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<List<dynamic>> _fetchList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _api.get(path, query: query);
    return _decodeList(_api.decode(response));
  }

  Future<Map<String, dynamic>> _fetchMap(String path) async {
    final response = await _api.get(path);
    return _decodeMap(_api.decode(response));
  }

  Future<List<dynamic>> _fetchBranchesRaw() async {
    try {
      return await _fetchList('/api/inventory/branches');
    } catch (_) {
      return _fetchList('/api/lookups/branches');
    }
  }

  Future<List<dynamic>> _fetchWarehousesRaw({int? branchId}) {
    return _fetchList(
      '/api/inventory/warehouses/active',
      query: <String, dynamic>{'branchId': branchId},
    );
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        loading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _fetchList('/api/products/groups'),
        _fetchList('/api/products/pricing-statuses'),
        _fetchBranchesRaw(),
        _fetchWarehousesRaw(),
        _fetchMap('/api/products/stats'),
      ]);

      if (!mounted) return;
      productGroups = results[0] as List<dynamic>;
      pricingStatuses = results[1] as List<dynamic>;
      branches = results[2] as List<dynamic>;
      allWarehouses = results[3] as List<dynamic>;
      warehouses = List<dynamic>.from(allWarehouses);
      productStats = results[4] as Map<String, dynamic>;

      await fetchProducts(showLoader: false, clearPreviousError: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> fetchProductGroups() async {
    try {
      final List<dynamic> data = await _fetchList('/api/products/groups');
      if (mounted) setState(() => productGroups = data);
    } catch (error) {
      if (mounted) _showError('تعذر تحميل مجموعات المنتجات: $error');
    }
  }

  Future<void> fetchPricingStatuses() async {
    try {
      final List<dynamic> data =
          await _fetchList('/api/products/pricing-statuses');
      if (mounted) setState(() => pricingStatuses = data);
    } catch (error) {
      if (mounted) _showError('تعذر تحميل حالات التسعير: $error');
    }
  }

  Future<void> fetchStats() async {
    try {
      final Map<String, dynamic> data =
          await _fetchMap('/api/products/stats');
      if (mounted) setState(() => productStats = data);
    } catch (error) {
      if (mounted) _showError('تعذر تحديث الإحصائيات: $error');
    }
  }

  Future<void> fetchBranches() async {
    try {
      final List<dynamic> data = await _fetchBranchesRaw();
      if (mounted) setState(() => branches = data);
    } catch (error) {
      if (mounted) _showError('تعذر تحميل الفروع: $error');
    }
  }

  Future<void> fetchWarehouses({int? branchId}) async {
    try {
      final List<dynamic> data =
          await _fetchWarehousesRaw(branchId: branchId);
      if (!mounted) return;
      setState(() {
        warehouses = data;
        if (branchId == null) {
          allWarehouses = List<dynamic>.from(data);
        }
      });
    } catch (error) {
      if (mounted) _showError('تعذر تحميل المخازن: $error');
    }
  }

  Future<void> fetchProducts({
    bool showLoader = true,
    bool clearPreviousError = true,
  }) async {
    if (mounted && showLoader) {
      setState(() {
        loading = true;
        if (clearPreviousError) _errorMessage = null;
      });
    }

    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'search': searchQuery.trim().isEmpty ? null : searchQuery.trim(),
        'groupId': selectedGroupId,
        'statusId': selectedStatusId,
        'ownership': ownershipFilter == 'all' ? null : ownershipFilter,
        'priced': pricedFilter == 'all' ? null : pricedFilter,
        'branchId': selectedBranchId,
        'warehouseId': selectedWarehouseId,
      };

      final List<dynamic> data = await _fetchList(
        '/api/products',
        query: query,
      );

      if (!mounted) return;
      setState(() {
        products = data;
        loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _refreshAll() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await Future.wait<void>(<Future<void>>[
        fetchStats(),
        fetchProductGroups(),
        fetchPricingStatuses(),
        fetchBranches(),
        fetchWarehouses(branchId: selectedBranchId),
      ]);
      await fetchProducts(showLoader: false);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _onSearch(String value) {
    setState(() => searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => fetchProducts(),
    );
  }

  void clearAllFilters() {
    _searchDebounce?.cancel();
    setState(() {
      selectedGroupId = null;
      selectedStatusId = null;
      selectedBranchId = null;
      selectedWarehouseId = null;
      ownershipFilter = 'all';
      pricedFilter = 'all';
      searchQuery = '';
      _searchController.clear();
      warehouses = List<dynamic>.from(allWarehouses);
    });
    fetchProducts();
  }

  Future<void> _deleteProduct(int productId, String productName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تأكيد حذف المنتج',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'هل تريد حذف المنتج "$productName"؟\nهذا الإجراء لا يمكن التراجع عنه.',
            style: GoogleFonts.cairo(height: 1.6),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: Text('حذف نهائي', style: GoogleFonts.cairo()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final response = await _api.delete('/api/products/$productId');
      final dynamic decoded = _api.decode(response, allowEmpty: true);
      final bool success = decoded == null ||
          (decoded is Map && decoded['success'] == true);
      if (!success) {
        final String message = decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'تعذر حذف المنتج';
        throw StateError(message);
      }

      if (!mounted) return;
      _showSuccess('تم حذف المنتج بنجاح');
      await Future.wait<void>(<Future<void>>[
        fetchProducts(showLoader: false),
        fetchStats(),
      ]);
    } catch (error) {
      if (mounted) _showError('تعذر حذف المنتج: $error');
    }
  }

  void _showError(String message) {
    _showMessage(
      message,
      color: Colors.red.shade700,
      icon: Icons.error_outline_rounded,
    );
  }

  void _showSuccess(String message) {
    _showMessage(
      message,
      color: Colors.green.shade700,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  void _showMessage(
    String message, {
    required Color color,
    required IconData icon,
  }) {
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  void _showProductOptions(Map<String, dynamic> product) {
    final int productId =
        _asInt(product['ProductID'] ?? product['ProductId']) ?? 0;
    final String productName =
        (product['ProductName'] ?? 'منتج').toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider(_isDark),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        _buildProductThumbnail(product, size: 54),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                productName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  color: _textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'كود المنتج: $productId',
                                style: GoogleFonts.cairo(
                                  color: _secondaryTextColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildOptionTile(
                      icon: Icons.visibility_rounded,
                      title: 'عرض التفاصيل',
                      subtitle: 'الصور والأسعار والمكونات وكل بيانات المنتج',
                      color: AppColors.goldDark,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openDetails(product);
                      },
                    ),
                    if (_canEdit)
                      _buildOptionTile(
                        icon: Icons.edit_rounded,
                        title: 'تعديل المنتج',
                        subtitle: 'تعديل البيانات والصور والأسعار المتاحة لك',
                        color: const Color(0xFF3B82F6),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _openEdit(product);
                        },
                      ),
                    if (_permissions.canRequestPriceChange)
                      _buildOptionTile(
                        icon: Icons.price_change_rounded,
                        title: 'طلب تعديل سعر',
                        subtitle: 'فتح تفاصيل المنتج وإرسال طلب التسعير',
                        color: Colors.orange.shade700,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _openDetails(product);
                        },
                      ),
                    if (_canDelete)
                      _buildOptionTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'حذف المنتج',
                        subtitle: 'حذف نهائي بعد التأكيد',
                        color: Colors.red.shade600,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _deleteProduct(productId, productName);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.11),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          color: _textColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.cairo(
          color: _secondaryTextColor,
          fontSize: 10,
        ),
      ),
      trailing: Icon(
        Icons.chevron_left_rounded,
        color: _secondaryTextColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        body: NestedScrollView(
          headerSliverBuilder:
              (BuildContext context, bool innerBoxIsScrolled) => <Widget>[
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 300,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              elevation: innerBoxIsScrolled ? 2 : 0,
              title: Text(
                'إدارة المنتجات',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: <Widget>[
                if (_canOpenPriceRequests)
                  IconButton(
                    tooltip: 'طلبات تعديل الأسعار',
                    onPressed: _openPriceRequests,
                    icon: const Icon(Icons.price_change_rounded),
                  ),
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: _isRefreshing ? null : _refreshAll,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _buildPremiumHeader(),
              ),
            ),
            SliverToBoxAdapter(child: _buildSearchAndFilter()),
          ],
          body: _buildProductsBody(),
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.navyDark,
            AppColors.navy,
            AppColors.navyLight,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -40,
            left: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -65,
            right: -30,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.045),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 66, 16, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.16),
                          ),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: AppColors.gold,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'كتالوج المنتجات والمخزون',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getInventoryScopeDescription(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                color: Colors.white70,
                                fontSize: 10.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _buildHeaderMetric(
                          icon: Icons.inventory_rounded,
                          value: '${productStats['total'] ?? products.length}',
                          label: 'إجمالي المنتجات',
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 8),
                        _buildHeaderMetric(
                          icon: Icons.sell_rounded,
                          value: '${productStats['priced'] ?? 0}',
                          label: 'تم تسعيرها',
                          color: const Color(0xFF72D6A0),
                        ),
                        const SizedBox(width: 8),
                        _buildHeaderMetric(
                          icon: Icons.pending_actions_rounded,
                          value: '${productStats['unpriced'] ?? 0}',
                          label: 'تحتاج تسعير',
                          color: const Color(0xFFF6C768),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        if (_canOpenPriceList)
                          _headerAction(
                            label: 'قائمة الأسعار',
                            icon: Icons.sell_rounded,
                            onTap: _openPriceList,
                            primary: true,
                          ),
                        if (_canAdd) ...<Widget>[
                          if (_canOpenPriceList) const SizedBox(width: 8),
                          _headerAction(
                            label: 'منتج جديد',
                            icon: Icons.add_rounded,
                            onTap: _openAddProduct,
                            primary: true,
                          ),
                        ],
                        if (_canStockEntry) ...<Widget>[
                          if (_canAdd || _canOpenPriceList) const SizedBox(width: 8),
                          _headerAction(
                            label: 'إضافة رصيد',
                            icon: Icons.add_box_rounded,
                            onTap: _openStockEntry,
                          ),
                        ],
                        if (_canExport) ...<Widget>[
                          const SizedBox(width: 8),
                          _headerAction(
                            label: _isExporting ? 'جاري التصدير' : 'تصدير Excel',
                            icon: Icons.file_download_rounded,
                            onTap: _isExporting ? null : _exportToExcel,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMetric({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: Colors.white60,
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerAction({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool primary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: primary ? AppColors.gold : Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: primary
                  ? AppColors.gold
                  : Colors.white.withOpacity(0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 15,
                color: primary ? AppColors.navy : AppColors.goldLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: primary ? AppColors.navy : Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(_isDark)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.cairo(
                    color: _textColor,
                    fontSize: 13,
                  ),
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو العميل أو كود المنتج',
                    hintStyle: GoogleFonts.cairo(
                      color: AppColors.textHint(_isDark),
                      fontSize: 11,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.goldDark,
                      size: 20,
                    ),
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                    filled: true,
                    fillColor: AppColors.inputFill(_isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: AppColors.divider(_isDark),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(
                        color: AppColors.gold,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterButton(),
              const SizedBox(width: 8),
              _buildViewToggle(),
            ],
          ),
          const SizedBox(height: 10),
          _buildScopeBanner(),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _statChip(
                  label: 'الكل',
                  count: _statValue('total', products.length),
                  active: pricedFilter == 'all',
                  icon: Icons.apps_rounded,
                  color: AppColors.navyLight,
                  onTap: () {
                    setState(() => pricedFilter = 'all');
                    fetchProducts();
                  },
                ),
                const SizedBox(width: 8),
                _statChip(
                  label: 'مسعرة',
                  count: _statValue('priced', 0),
                  active: pricedFilter == 'priced',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF22A06B),
                  onTap: () {
                    setState(() => pricedFilter = 'priced');
                    fetchProducts();
                  },
                ),
                const SizedBox(width: 8),
                _statChip(
                  label: 'بدون سعر',
                  count: _statValue('unpriced', 0),
                  active: pricedFilter == 'unpriced',
                  icon: Icons.price_check_rounded,
                  color: Colors.orange.shade700,
                  onTap: () {
                    setState(() => pricedFilter = 'unpriced');
                    fetchProducts();
                  },
                ),
                const SizedBox(width: 8),
                _statChip(
                  label: 'منتجات المعرض',
                  count: _statValue('showroom', 0),
                  active: ownershipFilter == 'showroom',
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    setState(() {
                      ownershipFilter = ownershipFilter == 'showroom'
                          ? 'all'
                          : 'showroom';
                    });
                    fetchProducts();
                  },
                ),
                if (_activeFilterCount > 0 || searchQuery.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.filter_alt_off_rounded,
                      color: Colors.red,
                      size: 17,
                    ),
                    label: Text(
                      'مسح الفلاتر',
                      style: GoogleFonts.cairo(
                        color: Colors.red.shade700,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: Colors.red.withOpacity(0.07),
                    side: BorderSide(color: Colors.red.withOpacity(0.22)),
                    onPressed: clearAllFilters,
                  ),
                ],
              ],
            ),
          ),
          if (_canToggleCostPrices) ...<Widget>[
            const SizedBox(height: 10),
            _buildPriceModeSelector(),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.04, end: 0);
  }

  Widget _buildFilterButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openFilters,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 44,
              height: 48,
              decoration: BoxDecoration(
                color: _activeFilterCount > 0
                    ? AppColors.gold.withOpacity(0.13)
                    : AppColors.inputFill(_isDark),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: _activeFilterCount > 0
                      ? AppColors.gold.withOpacity(0.55)
                      : AppColors.divider(_isDark),
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: _activeFilterCount > 0
                    ? AppColors.goldDark
                    : _secondaryTextColor,
              ),
            ),
          ),
        ),
        if (_activeFilterCount > 0)
          Positioned(
            top: -5,
            left: -5,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$_activeFilterCount',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _viewToggleButton(
            icon: Icons.view_agenda_rounded,
            selected: !_isGridView,
            tooltip: 'عرض قائمة',
            onTap: () => setState(() => _isGridView = false),
          ),
          _viewToggleButton(
            icon: Icons.grid_view_rounded,
            selected: _isGridView,
            tooltip: 'عرض شبكة',
            onTap: () => setState(() => _isGridView = true),
          ),
        ],
      ),
    );
  }

  Widget _viewToggleButton({
    required IconData icon,
    required bool selected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 32,
          height: 38,
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: selected ? Colors.white : _secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildScopeBanner() {
    final bool scoped =
        selectedBranchId != null || selectedWarehouseId != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: (scoped ? const Color(0xFF3B82F6) : AppColors.gold)
            .withOpacity(0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: (scoped ? const Color(0xFF3B82F6) : AppColors.gold)
              .withOpacity(0.22),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            scoped ? Icons.location_on_rounded : Icons.public_rounded,
            color: scoped ? const Color(0xFF3B82F6) : AppColors.goldDark,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _getInventoryScopeDescription(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                color: _secondaryTextColor,
                fontSize: 9.8,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required String label,
    required int count,
    required bool active,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.13) : AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? color.withOpacity(0.40)
                : AppColors.divider(_isDark),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: GoogleFonts.cairo(
                color: active ? color : _textColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: active ? color : _secondaryTextColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _priceModeButton(
              label: 'أسعار البيع',
              icon: Icons.sell_rounded,
              selected: !_showCostPrices,
              onTap: () => setState(() => _showCostPrices = false),
            ),
          ),
          Expanded(
            child: _priceModeButton(
              label: 'أسعار التكلفة',
              icon: Icons.factory_rounded,
              selected: _showCostPrices,
              onTap: () => setState(() => _showCostPrices = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceModeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.gold : _secondaryTextColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: selected ? Colors.white : _secondaryTextColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilters() async {
    int? tempGroupId = selectedGroupId;
    int? tempStatusId = selectedStatusId;
    int? tempBranchId = selectedBranchId;
    int? tempWarehouseId = selectedWarehouseId;
    String tempOwnership = ownershipFilter;
    String tempPriced = pricedFilter;

    final bool? applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter sheetSetState) {
              final List<dynamic> availableWarehouses = tempBranchId == null
                  ? allWarehouses
                  : allWarehouses.where((dynamic warehouse) {
                      final int? branchId = _asInt(
                        warehouse['BranchId'] ?? warehouse['BranchID'],
                      );
                      return branchId == null || branchId == tempBranchId;
                    }).toList();

              final bool warehouseExists = tempWarehouseId == null ||
                  availableWarehouses.any((dynamic warehouse) =>
                      _asInt(warehouse['WarehouseID'] ??
                          warehouse['WarehouseId']) ==
                      tempWarehouseId);
              if (!warehouseExists) tempWarehouseId = null;

              return SafeArea(
                top: false,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    16 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider(_isDark),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: AppColors.goldDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'تصفية المنتجات',
                                  style: GoogleFonts.cairo(
                                    color: _textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'يمكن دمج أكثر من فلتر للوصول للنتيجة المطلوبة',
                                  style: GoogleFonts.cairo(
                                    color: _secondaryTextColor,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: <Widget>[
                              _filterDropdown<int>(
                                label: 'مجموعة المنتج',
                                icon: Icons.category_rounded,
                                value: tempGroupId,
                                items: productGroups
                                    .map<DropdownMenuItem<int>>(
                                        (dynamic group) {
                                  return DropdownMenuItem<int>(
                                    value: _asInt(group['ProductGroupID'] ??
                                        group['ProductGroupId']),
                                    child: Text(
                                      (group['GroupName'] ?? '').toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (int? value) => sheetSetState(
                                  () => tempGroupId = value,
                                ),
                              ),
                              _filterDropdown<int>(
                                label: 'حالة التسعير',
                                icon: Icons.flag_rounded,
                                value: tempStatusId,
                                items: pricingStatuses
                                    .map<DropdownMenuItem<int>>(
                                        (dynamic status) {
                                  return DropdownMenuItem<int>(
                                    value: _asInt(status['PricingStatusID'] ??
                                        status['StatusID']),
                                    child: Text(
                                      _statusName(
                                        (status['StatusName'] ?? '').toString(),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (int? value) => sheetSetState(
                                  () => tempStatusId = value,
                                ),
                              ),
                              _filterDropdown<String>(
                                label: 'نوع الملكية',
                                icon: Icons.store_rounded,
                                value: tempOwnership,
                                includeAll: false,
                                items: <DropdownMenuItem<String>>[
                                  const DropdownMenuItem<String>(
                                    value: 'all',
                                    child: Text('كل المنتجات'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'showroom',
                                    child: Text('منتجات المعرض'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'linked',
                                    child: Text('مرتبطة بعميل'),
                                  ),
                                ],
                                onChanged: (String? value) {
                                  if (value != null) {
                                    sheetSetState(
                                      () => tempOwnership = value,
                                    );
                                  }
                                },
                              ),
                              _filterDropdown<String>(
                                label: 'حالة السعر',
                                icon: Icons.price_check_rounded,
                                value: tempPriced,
                                includeAll: false,
                                items: <DropdownMenuItem<String>>[
                                  const DropdownMenuItem<String>(
                                    value: 'all',
                                    child: Text('الكل'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'priced',
                                    child: Text('مسعرة'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'unpriced',
                                    child: Text('بدون سعر'),
                                  ),
                                ],
                                onChanged: (String? value) {
                                  if (value != null) {
                                    sheetSetState(() => tempPriced = value);
                                  }
                                },
                              ),
                              _filterDropdown<int>(
                                label: 'الفرع',
                                icon: Icons.business_rounded,
                                value: tempBranchId,
                                items: branches
                                    .map<DropdownMenuItem<int>>(
                                        (dynamic branch) {
                                  return DropdownMenuItem<int>(
                                    value: _asInt(branch['BranchId'] ??
                                        branch['BranchID']),
                                    child: Text(
                                      (branch['BranchNameAr'] ??
                                              branch['BranchName'] ??
                                              '')
                                          .toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (int? value) => sheetSetState(() {
                                  tempBranchId = value;
                                  tempWarehouseId = null;
                                }),
                              ),
                              _filterDropdown<int>(
                                label: 'المخزن',
                                icon: Icons.warehouse_rounded,
                                value: tempWarehouseId,
                                items: availableWarehouses
                                    .map<DropdownMenuItem<int>>(
                                        (dynamic warehouse) {
                                  return DropdownMenuItem<int>(
                                    value: _asInt(warehouse['WarehouseID'] ??
                                        warehouse['WarehouseId']),
                                    child: Text(
                                      (warehouse['WarehouseName'] ?? '')
                                          .toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (int? value) => sheetSetState(
                                  () => tempWarehouseId = value,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => sheetSetState(() {
                                tempGroupId = null;
                                tempStatusId = null;
                                tempBranchId = null;
                                tempWarehouseId = null;
                                tempOwnership = 'all';
                                tempPriced = 'all';
                              }),
                              icon: const Icon(
                                Icons.filter_alt_off_rounded,
                                size: 18,
                              ),
                              label: Text(
                                'إعادة ضبط',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                              ),
                              onPressed: () =>
                                  Navigator.pop(sheetContext, true),
                              icon: const Icon(Icons.check_rounded, size: 19),
                              label: Text(
                                'تطبيق الفلاتر',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (applied != true || !mounted) return;
    setState(() {
      selectedGroupId = tempGroupId;
      selectedStatusId = tempStatusId;
      selectedBranchId = tempBranchId;
      selectedWarehouseId = tempWarehouseId;
      ownershipFilter = tempOwnership;
      pricedFilter = tempPriced;
      warehouses = tempBranchId == null
          ? List<dynamic>.from(allWarehouses)
          : allWarehouses.where((dynamic warehouse) {
              final int? branchId =
                  _asInt(warehouse['BranchId'] ?? warehouse['BranchID']);
              return branchId == null || branchId == tempBranchId;
            }).toList();
    });
    await fetchProducts();
  }

  Widget _filterDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool includeAll = true,
  }) {
    final List<DropdownMenuItem<T>> effectiveItems = <DropdownMenuItem<T>>[
      if (includeAll)
        DropdownMenuItem<T>(
          value: null,
          child: const Text('الكل'),
        ),
      ...items,
    ];
    final bool valueExists = value == null ||
        effectiveItems.any((DropdownMenuItem<T> item) => item.value == value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: valueExists ? value : null,
        isExpanded: true,
        items: effectiveItems,
        onChanged: onChanged,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        dropdownColor: _cardColor,
        style: GoogleFonts.cairo(color: _textColor, fontSize: 12.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(
            color: _secondaryTextColor,
            fontSize: 11.5,
          ),
          prefixIcon: Icon(icon, color: AppColors.goldDark, size: 19),
          filled: true,
          fillColor: AppColors.inputFill(_isDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: AppColors.divider(_isDark)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: AppColors.divider(_isDark)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: AppColors.gold),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsBody() {
    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(height: 14),
            Text(
              'جاري تحميل المنتجات...',
              style: GoogleFonts.cairo(color: _secondaryTextColor),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) return _buildErrorState();
    if (products.isEmpty) return _buildEmptyState();
    return _isGridView ? _buildProductsGrid() : _buildProductsList();
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.red.withOpacity(0.24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.red.shade400,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'تعذر تحميل المنتجات',
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: _secondaryTextColor,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
          Center(
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.goldDark,
                size: 42,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'لا توجد منتجات مطابقة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: _textColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _activeFilterCount > 0 || searchQuery.isNotEmpty
                ? 'جرّب تعديل البحث أو مسح الفلاتر الحالية.'
                : 'لم يتم تسجيل منتجات حتى الآن.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: _secondaryTextColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 17),
          if (_activeFilterCount > 0 || searchQuery.isNotEmpty)
            Center(
              child: OutlinedButton.icon(
                onPressed: clearAllFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: Text('مسح الفلاتر', style: GoogleFonts.cairo()),
              ),
            )
          else if (_canAdd)
            Center(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                onPressed: _openAddProduct,
                icon: const Icon(Icons.add_rounded),
                label: Text('إضافة منتج', style: GoogleFonts.cairo()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: AppColors.gold,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 92),
        itemCount: products.length,
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> product =
              Map<String, dynamic>.from(products[index] as Map);
          return _buildProductCard(product, index);
        },
      ),
    );
  }

  Widget _buildProductsGrid() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: AppColors.gold,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = constraints.maxWidth >= 1000
              ? 4
              : constraints.maxWidth >= 700
                  ? 3
                  : 2;
          final double cardHeight = constraints.maxWidth < 390 ? 354 : 366;
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 92),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: cardHeight,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: products.length,
            itemBuilder: (BuildContext context, int index) {
              final Map<String, dynamic> product =
                  Map<String, dynamic>.from(products[index] as Map);
              return _buildProductGridCard(product, index);
            },
          );
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    final String productName =
        (product['ProductName'] ?? 'بدون اسم').toString();
    final String customerName =
        (product['CustomerName'] ?? '').toString().trim();
    final String groupName = (product['GroupName'] ?? '').toString();
    final String? statusName = product['PricingStatusName']?.toString();
    final double stockQuantity =
        _asDouble(product['StockQuantity'] ?? product['QTY']);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.divider(_isDark)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => _openDetails(product),
          onLongPress: () => _showProductOptions(product),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildProductThumbnail(product, size: 76),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                color: _textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'خيارات المنتج',
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 34,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showProductOptions(product),
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: _secondaryTextColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: <Widget>[
                          _smallInfoChip(
                            icon: Icons.tag_rounded,
                            label:
                                '${product['ProductID'] ?? product['ProductId'] ?? '-'}',
                            color: AppColors.navyLight,
                          ),
                          if (groupName.isNotEmpty)
                            _smallInfoChip(
                              icon: Icons.category_outlined,
                              label: groupName,
                              color: AppColors.goldDark,
                            ),
                          if (statusName != null && statusName.isNotEmpty)
                            _statusBadge(statusName),
                        ],
                      ),
                      if (customerName.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.person_outline_rounded,
                              size: 15,
                              color: _secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  color: _secondaryTextColor,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 7),
                      _buildStockLine(stockQuantity),
                      const SizedBox(height: 8),
                      _buildPackagePrices(product, compact: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: (index > 8 ? 8 : index) * 35),
          duration: 300.ms,
        )
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildProductGridCard(
    Map<String, dynamic> product,
    int index,
  ) {
    final String productName =
        (product['ProductName'] ?? 'بدون اسم').toString();
    final String customerName =
        (product['CustomerName'] ?? '').toString().trim();
    final String groupName = (product['GroupName'] ?? '').toString();
    final String? statusName = product['PricingStatusName']?.toString();
    final double stockQuantity =
        _asDouble(product['StockQuantity'] ?? product['QTY']);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.divider(_isDark)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.13 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetails(product),
          onLongPress: () => _showProductOptions(product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  _buildGridImage(product),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#${product['ProductID'] ?? product['ProductId'] ?? '-'}',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 5,
                    child: IconButton.filledTonal(
                      tooltip: 'خيارات المنتج',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showProductOptions(product),
                      icon: const Icon(Icons.more_horiz_rounded, size: 18),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: _textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (groupName.isNotEmpty)
                        Text(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            color: AppColors.goldDark,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (customerName.isNotEmpty)
                        Text(
                          customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            color: _secondaryTextColor,
                            fontSize: 9.5,
                          ),
                        ),
                      if (statusName != null && statusName.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        _statusBadge(statusName),
                      ],
                      const Spacer(),
                      _buildStockLine(stockQuantity, compact: true),
                      const SizedBox(height: 7),
                      _buildPackagePrices(product, compact: false),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: (index > 10 ? 10 : index) * 30),
          duration: 300.ms,
        )
        .scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1));
  }

  Widget _buildGridImage(Map<String, dynamic> product) {
    final dynamic mainImageId = product['MainImageId'];
    return Container(
      height: 123,
      color: AppColors.inputFill(_isDark),
      child: mainImageId == null
          ? _buildThumbnailPlaceholderIcon()
          : Image.network(
              '$baseUrl/api/product-image-by-id/$mainImageId',
              width: double.infinity,
              height: 123,
              fit: BoxFit.cover,
              loadingBuilder: (
                BuildContext context,
                Widget child,
                ImageChunkEvent? progress,
              ) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  ),
                );
              },
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) =>
                  _buildThumbnailPlaceholderIcon(),
            ),
    );
  }

  Widget _buildStockLine(double quantity, {bool compact = false}) {
    final bool available = quantity > 0;
    final Color color = available ? const Color(0xFF22A06B) : Colors.red.shade500;
    final Widget label = Text(
      '${_getStockHeaderText()}: ${_formatQuantity(quantity)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.cairo(
        color: color,
        fontSize: compact ? 8.8 : 10,
        fontWeight: FontWeight.w800,
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.inventory_rounded, color: color, size: compact ? 13 : 15),
          const SizedBox(width: 5),
          if (compact) Expanded(child: label) else label,
        ],
      ),
    );
  }

  Widget _buildPackagePrices(
    Map<String, dynamic> product, {
    required bool compact,
  }) {
    final List<Map<String, dynamic>> packages = <Map<String, dynamic>>[
      <String, dynamic>{
        'label': 'Standard',
        'short': 'S',
        'sale': product['SuggestedSalePriceCClass'],
        'cost': product['PurchasePriceCClass'],
        'color': const Color(0xFF4D8DFF),
      },
      <String, dynamic>{
        'label': 'Premium',
        'short': 'P',
        'sale': product['SuggestedSalePrice'],
        'cost': product['PurchasePrice'],
        'color': AppColors.goldDark,
      },
      <String, dynamic>{
        'label': 'Elite',
        'short': 'E',
        'sale': product['SuggestedSalePriceElite'],
        'cost': product['PurchasePriceElite'],
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return Row(
      children: packages.asMap().entries.map<Widget>((entry) {
        final Map<String, dynamic> package = entry.value;
        final dynamic value =
            _displayCostPrices ? package['cost'] : package['sale'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: entry.key == packages.length - 1 ? 0 : 4),
            child: _priceBox(
              label: compact ? package['label'].toString() : package['short'].toString(),
              value: value,
              color: package['color'] as Color,
              compact: compact,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _priceBox({
    required String label,
    required dynamic value,
    required Color color,
    required bool compact,
  }) {
    final double price = _asDouble(value);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 4,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment:
            compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: compact ? 8.2 : 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              price > 0 ? _formatNumber(price) : '-',
              style: GoogleFonts.cairo(
                color: _textColor,
                fontSize: compact ? 10.5 : 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 8.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusName(String? name) {
    switch (name) {
      case 'Draft':
        return 'مسودة';
      case 'WaitingForPricing':
        return 'بانتظار التسعير';
      case 'Priced':
        return 'تم التسعير';
      case 'PriceChangeRequested':
        return 'طلب تعديل سعر';
      case 'PriceApproved':
        return 'تمت الموافقة';
      case 'PriceRejected':
        return 'مرفوض';
      case 'SalePriceChangeRequested':
        return 'طلب تعديل سعر بيع';
      case 'CostChangeRequested':
        return 'طلب تعديل تكلفة';
      default:
        return name == null || name.trim().isEmpty ? 'غير محدد' : name;
    }
  }

  Color _statusColor(String? statusName) {
    switch (statusName) {
      case 'WaitingForPricing':
        return Colors.orange.shade700;
      case 'Priced':
      case 'PriceApproved':
        return const Color(0xFF22A06B);
      case 'PriceChangeRequested':
      case 'SalePriceChangeRequested':
      case 'CostChangeRequested':
        return const Color(0xFF3B82F6);
      case 'PriceRejected':
        return Colors.red.shade600;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _statusBadge(String? statusName) {
    final Color color = _statusColor(statusName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        _statusName(statusName),
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 8.6,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildProductThumbnail(
    Map<String, dynamic> product, {
    double size = 70,
  }) {
    final dynamic mainImageId = product['MainImageId'];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.gold.withOpacity(0.24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: mainImageId == null
            ? (product['ProductImage'] != null || product['ImageProduct'] != null
                ? _buildProductImage(product, width: size, height: size)
                : _buildProductThumbnailPlaceholder(size: size))
            : Image.network(
                '$baseUrl/api/product-image-by-id/$mainImageId',
                fit: BoxFit.cover,
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? progress,
                ) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    ),
                  );
                },
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) =>
                    _buildThumbnailPlaceholderIcon(),
              ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholderIcon() {
    return Container(
      color: AppColors.inputFill(_isDark),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 31,
        color: _secondaryTextColor,
      ),
    );
  }

  Widget _buildProductImage(
    Map<String, dynamic> product, {
    double width = 90,
    double height = 90,
  }) {
    final dynamic encodedImage =
        product['ProductImage'] ?? product['ImageProduct'];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.gold.withOpacity(0.24)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: encodedImage == null
            ? _buildPlaceholder()
            : Image.memory(
                base64Decode(encodedImage.toString()),
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) =>
                    _buildPlaceholder(),
              ),
      ),
    );
  }

  Widget _buildProductThumbnailPlaceholder({double size = 70}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.gold.withOpacity(0.24)),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: 31,
        color: _secondaryTextColor,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.inputFill(_isDark),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 38,
        color: _secondaryTextColor,
      ),
    );
  }

  String _getStockHeaderText() {
    if (selectedWarehouseId != null) return 'رصيد المخزن';
    if (selectedBranchId != null) return 'رصيد الفرع';
    return 'إجمالي الرصيد';
  }

  String _getInventoryScopeDescription() {
    if (selectedWarehouseId != null) {
      final dynamic warehouse = _findById(
        allWarehouses,
        selectedWarehouseId,
        <String>['WarehouseID', 'WarehouseId'],
      );
      final String warehouseName =
          (warehouse?['WarehouseName'] ?? 'المخزن المحدد').toString();
      final String branchName =
          (warehouse?['BranchNameAr'] ?? warehouse?['BranchName'] ?? '')
              .toString();
      return branchName.isEmpty
          ? 'عرض المنتجات ذات الرصيد الفعلي داخل $warehouseName.'
          : 'عرض المنتجات ذات الرصيد الفعلي داخل $warehouseName في $branchName.';
    }

    if (selectedBranchId != null) {
      final dynamic branch = _findById(
        branches,
        selectedBranchId,
        <String>['BranchId', 'BranchID'],
      );
      final String branchName =
          (branch?['BranchNameAr'] ?? branch?['BranchName'] ?? 'الفرع المحدد')
              .toString();
      return 'عرض المنتجات ذات الرصيد الفعلي داخل مخازن $branchName.';
    }

    return 'عرض إجمالي أرصدة المنتجات عبر جميع المخازن النشطة.';
  }

  dynamic _findById(List<dynamic> list, int? id, List<String> keys) {
    if (id == null) return null;
    for (final dynamic item in list) {
      for (final String key in keys) {
        if (_asInt(item[key]) == id) return item;
      }
    }
    return null;
  }

  int _statValue(String key, int fallback) {
    return _asInt(productStats[key]) ?? fallback;
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return NumberFormat('#,##0.##', 'en_US').format(value);
  }

  String _formatNumber(dynamic number) {
    final double value = _asDouble(number);
    return NumberFormat('#,##0.##', 'en_US').format(value);
  }

  Widget _buildFAB() {
    if (!_canAdd) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: _openAddProduct,
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.navy,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'منتج جديد',
        style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
      ),
    )
        .animate()
        .fadeIn(delay: 250.ms, duration: 300.ms)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  void _openDetails(Map<String, dynamic> product) {
    final int productId =
        _asInt(product['ProductID'] ?? product['ProductId']) ?? 0;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProductDetailsScreen(
          productId: productId,
          username: widget.username,
        ),
      ),
    ).then((_) => fetchProducts(showLoader: false));
  }

  void _openEdit(Map<String, dynamic> product) {
    final int productId =
        _asInt(product['ProductID'] ?? product['ProductId']) ?? 0;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AddProductScreen(
          username: widget.username,
          productId: productId,
          existingProduct: product,
        ),
      ),
    ).then((_) {
      fetchProducts(showLoader: false);
      fetchStats();
    });
  }

  void _openAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AddProductScreen(
          username: widget.username,
        ),
      ),
    ).then((_) {
      fetchProducts(showLoader: false);
      fetchStats();
    });
  }

  void _openPriceList() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PriceListScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    ).then((_) => fetchProducts(showLoader: false));
  }

  void _openPriceRequests() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PriceRequestsScreen(
          username: widget.username,
        ),
      ),
    ).then((_) {
      fetchProducts(showLoader: false);
      fetchStats();
    });
  }

  void _openStockEntry() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => StockEntryScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    ).then((_) => fetchProducts(showLoader: false));
  }

  Future<void> _exportToExcel() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      if (products.isEmpty) {
        _showError('لا توجد بيانات للتصدير');
        return;
      }

      final excel.Excel workbook = excel.Excel.createExcel();
      final excel.Sheet sheet = workbook['المنتجات'];
      sheet.appendRow(<excel.CellValue>[
        excel.TextCellValue('الكود'),
        excel.TextCellValue('اسم المنتج'),
        excel.TextCellValue('المجموعة'),
        excel.TextCellValue('العميل'),
        excel.TextCellValue('حالة التسعير'),
        excel.TextCellValue('رصيد المخزون'),
        excel.TextCellValue('بيع Standard'),
        excel.TextCellValue('بيع Premium'),
        excel.TextCellValue('بيع Elite'),
      ]);

      for (final dynamic rawProduct in products) {
        final Map<String, dynamic> product =
            Map<String, dynamic>.from(rawProduct as Map);
        sheet.appendRow(<excel.CellValue>[
          excel.TextCellValue(
            '${product['ProductID'] ?? product['ProductId'] ?? ''}',
          ),
          excel.TextCellValue('${product['ProductName'] ?? ''}'),
          excel.TextCellValue('${product['GroupName'] ?? ''}'),
          excel.TextCellValue('${product['CustomerName'] ?? ''}'),
          excel.TextCellValue(
            _statusName(product['PricingStatusName']?.toString()),
          ),
          excel.DoubleCellValue(
            _asDouble(product['StockQuantity'] ?? product['QTY']),
          ),
          excel.DoubleCellValue(
            _asDouble(product['SuggestedSalePriceCClass']),
          ),
          excel.DoubleCellValue(
            _asDouble(product['SuggestedSalePrice']),
          ),
          excel.DoubleCellValue(
            _asDouble(product['SuggestedSalePriceElite']),
          ),
        ]);
      }

      final List<int>? bytes = workbook.save();
      if (bytes == null) throw StateError('تعذر إنشاء ملف Excel');

      final Directory directory = await getApplicationDocumentsDirectory();
      final String timestamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final File file = File('${directory.path}/products_$timestamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile(
              file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          text: 'تقرير المنتجات',
        ),
      );

      if (mounted) _showSuccess('تم تجهيز ملف Excel بنجاح');
    } catch (error) {
      if (mounted) _showError('تعذر تصدير الملف: $error');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
