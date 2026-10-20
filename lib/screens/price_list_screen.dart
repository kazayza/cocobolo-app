import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import '../services/app_colors.dart';
import '../services/price_list_service.dart';
import '../services/theme_service.dart';
import 'price_requests_screen.dart';
import 'product_details_screen.dart';

class PriceListScreen extends StatefulWidget {
  final int userId;
  final String username;

  const PriceListScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  static const List<String> _tiers = <String>[
    'CClass',
    'Premium',
    'Elite',
  ];

  final PriceListService _service = PriceListService();
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _compareIds = <int>{};

  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  List<String> _groups = <String>[];

  bool _loading = true;
  bool _isGridView = true;
  bool _websiteOnly = false;
  bool _exporting = false;
  String? _error;
  String _search = '';
  String? _group;
  int? _branchId;
  String _tierView = 'all';
  String _priceFilter = 'all';
  int _visibleCount = 60;
  Timer? _searchDebounce;

  bool get _isDark => ThemeService().isDarkMode;
  Color get _cardColor => AppColors.card(_isDark);
  Color get _textColor => AppColors.text(_isDark);
  Color get _secondaryTextColor => AppColors.textSecondary(_isDark);

  bool _can(String key) => _capabilities[key] == true;
  bool get _canSeeSalePrices => _can('canSeeSalePrices');
  bool get _canSeeCosts => _can('canSeeCosts');
  bool get _canEditSalePrice => _can('canEditSalePrice');
  bool get _canEditCost => _can('canEditCost');
  bool get _canRequestPriceChange => _can('canRequestPriceChange');
  bool get _canReviewRequests => _can('canReviewRequests');
  bool get _canViewHistory => _can('canViewHistory');
  bool get _canExport => _can('canExport');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _boolValue(dynamic value) {
    return value == true || value == 1 || value?.toString() == '1';
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _service.getPriceList(branchId: _branchId);
      final rows = ((data['rows'] as List?) ?? const <dynamic>[])
          .map<Map<String, dynamic>>(_map)
          .toList();
      final branches = ((data['branches'] as List?) ?? const <dynamic>[])
          .map<Map<String, dynamic>>(_map)
          .toList();
      final capabilities = _map(data['capabilities']);
      final groups = rows
          .map((Map<String, dynamic> row) => '${row['GroupName'] ?? ''}'.trim())
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _branches = branches;
        _capabilities = capabilities;
        _groups = groups;
        _compareIds.removeWhere(
          (int id) =>
              !_rows.any((Map<String, dynamic> row) => _productId(row) == id),
        );
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  int _productId(Map<String, dynamic> row) {
    return _intValue(row['ProductID'] ?? row['ProductId']);
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9]'), '');
  }

  bool _matchesCore(Map<String, dynamic> row) {
    if (_search.trim().isNotEmpty) {
      final term = _normalizeText(_search.trim());
      final productName = _normalizeText('${row['ProductName'] ?? ''}');
      final groupName = _normalizeText('${row['GroupName'] ?? ''}');
      final byId = _productId(row).toString() == _search.trim();
      if (!byId && !productName.contains(term) && !groupName.contains(term)) {
        return false;
      }
    }

    if (_group != null && '${row['GroupName'] ?? ''}' != _group) return false;
    if (_branchId != null && _number(row['StockQuantity']) <= 0) return false;
    if (_tierView != 'all' && _price(row, _tierView) <= 0) return false;
    return true;
  }

  bool _hasAnyPrice(Map<String, dynamic> row) {
    return _tiers.any((String tier) => _price(row, tier) > 0);
  }

  List<Map<String, dynamic>> get _coreFiltered {
    return _rows.where(_matchesCore).toList();
  }

  List<Map<String, dynamic>> get _filtered {
    return _coreFiltered.where((Map<String, dynamic> row) {
      if (_websiteOnly && !_boolValue(row['IsWebsite'])) return false;
      if (_priceFilter == 'priced' && !_hasAnyPrice(row)) return false;
      if (_priceFilter == 'missing' && _hasAnyPrice(row)) return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleRows {
    final rows = _filtered;
    return rows.take(_visibleCount).toList();
  }

  int get _pricedCount => _coreFiltered.where(_hasAnyPrice).length;
  int get _missingCount => _coreFiltered.length - _pricedCount;
  int get _websiteCount => _coreFiltered
      .where((Map<String, dynamic> row) => _boolValue(row['IsWebsite']))
      .length;

  double _price(Map<String, dynamic> row, String tier) {
    switch (tier) {
      case 'CClass':
        return _number(row['StdPrice']);
      case 'Elite':
        return _number(row['ElitePrice']);
      default:
        return _number(row['PremiumPrice']);
    }
  }

  double _cost(Map<String, dynamic> row, String tier) {
    switch (tier) {
      case 'CClass':
        return _number(row['StdCost']);
      case 'Elite':
        return _number(row['EliteCost']);
      default:
        return _number(row['PremiumCost']);
    }
  }

  String _tierLabel(String tier) {
    switch (tier) {
      case 'CClass':
        return 'ستاندرد';
      case 'Elite':
        return 'إيليت';
      case 'Premium':
        return 'بريميوم';
      default:
        return 'كل الفئات';
    }
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'CClass':
        return const Color(0xFF64748B);
      case 'Elite':
        return AppColors.goldDark;
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _formatMoney(dynamic value) {
    return NumberFormat('#,##0.##', 'en_US').format(_number(value));
  }

  void _onSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _search = value;
        _visibleCount = 60;
      });
    });
  }

  Future<void> _selectBranch(int? branchId) async {
    if (_branchId == branchId) return;
    setState(() {
      _branchId = branchId;
      _visibleCount = 60;
    });
    await _loadData();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _search = '';
      _group = null;
      _tierView = 'all';
      _priceFilter = 'all';
      _websiteOnly = false;
      _visibleCount = 60;
    });
    if (_branchId != null) _selectBranch(null);
  }

  bool get _hasFilters {
    return _search.trim().isNotEmpty ||
        _group != null ||
        _branchId != null ||
        _tierView != 'all' ||
        _priceFilter != 'all' ||
        _websiteOnly;
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
              expandedHeight: 246,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              title: Text(
                'قائمة الأسعار',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: <Widget>[
                if (_canRequestPriceChange || _canReviewRequests)
                  IconButton(
                    tooltip: 'طلبات تعديل الأسعار',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PriceRequestsScreen(
                          username: widget.username,
                        ),
                      ),
                    ).then((_) => _loadData(showLoader: false)),
                    icon: const Icon(Icons.pending_actions_rounded),
                  ),
                if (_canExport)
                  IconButton(
                    tooltip: 'تصدير Excel',
                    onPressed: _exporting ? null : _exportExcel,
                    icon: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.file_download_rounded),
                  ),
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: _loading ? null : _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _buildHero(),
              ),
            ),
            SliverToBoxAdapter(child: _buildControls()),
          ],
          body: _buildBody(),
        ),
        bottomNavigationBar: _compareIds.isEmpty ? null : _buildCompareBar(),
      ),
    );
  }

  Widget _buildHero() {
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
            top: -45,
            left: -30,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 66, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.32),
                          ),
                        ),
                        child: const Icon(
                          Icons.sell_rounded,
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
                              'الكتالوج العام',
                              style: GoogleFonts.cairo(
                                color: AppColors.goldLight,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              'قائمة الأسعار',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _canSeeSalePrices
                                  ? 'أسعار البيع للفئات الثلاثة مع رصيد الفروع'
                                  : 'كتالوج المنتجات والأرصدة المتاحة',
                              style: GoogleFonts.cairo(
                                color: Colors.white60,
                                fontSize: 10,
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
                        _heroStat(
                          label: 'الإجمالي',
                          value: _coreFiltered.length,
                          icon: Icons.inventory_2_rounded,
                          color: AppColors.gold,
                          active: _priceFilter == 'all' && !_websiteOnly,
                          onTap: () => setState(() {
                            _priceFilter = 'all';
                            _websiteOnly = false;
                          }),
                        ),
                        if (_canSeeSalePrices) ...<Widget>[
                          const SizedBox(width: 8),
                          _heroStat(
                            label: 'بأسعار',
                            value: _pricedCount,
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF4ADE80),
                            active: _priceFilter == 'priced',
                            onTap: () => setState(() {
                              _priceFilter =
                                  _priceFilter == 'priced' ? 'all' : 'priced';
                            }),
                          ),
                          const SizedBox(width: 8),
                          _heroStat(
                            label: 'بدون سعر',
                            value: _missingCount,
                            icon: Icons.price_change_rounded,
                            color: const Color(0xFFFBBF24),
                            active: _priceFilter == 'missing',
                            onTap: () => setState(() {
                              _priceFilter =
                                  _priceFilter == 'missing' ? 'all' : 'missing';
                            }),
                          ),
                        ],
                        const SizedBox(width: 8),
                        _heroStat(
                          label: 'الموقع',
                          value: _websiteCount,
                          icon: Icons.public_rounded,
                          color: const Color(0xFF22D3EE),
                          active: _websiteOnly,
                          onTap: () =>
                              setState(() => _websiteOnly = !_websiteOnly),
                        ),
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

  Widget _heroStat({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.60) : Colors.white12,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$value',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: Colors.white60,
                      fontSize: 8.5,
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

  Widget _buildControls() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider(_isDark)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.12 : 0.04),
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
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  style: GoogleFonts.cairo(
                    color: _textColor,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو المجموعة أو الكود',
                    hintStyle: GoogleFonts.cairo(
                      color: AppColors.textHint(_isDark),
                      fontSize: 10.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.goldDark,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
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
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _squareControl(
                tooltip: 'الفلاتر',
                icon: Icons.tune_rounded,
                active: _hasFilters,
                onTap: _openFilters,
              ),
              const SizedBox(width: 8),
              Container(
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
                    _viewButton(
                      icon: Icons.grid_view_rounded,
                      selected: _isGridView,
                      onTap: () => setState(() => _isGridView = true),
                    ),
                    _viewButton(
                      icon: Icons.view_agenda_rounded,
                      selected: !_isGridView,
                      onTap: () => setState(() => _isGridView = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_canSeeSalePrices) ...<Widget>[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _tierChip('all'),
                  const SizedBox(width: 7),
                  ..._tiers.expand<Widget>(
                    (String tier) => <Widget>[
                      _tierChip(tier),
                      const SizedBox(width: 7),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: <Widget>[
              Icon(
                _branchId == null ? Icons.public_rounded : Icons.store_rounded,
                color: AppColors.goldDark,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _branchId == null
                      ? 'الرصيد المعروض عبر جميع المخازن'
                      : 'يعرض فقط المنتجات المتاحة في ${_selectedBranchName()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: _secondaryTextColor,
                    fontSize: 9.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_filtered.length} صنف',
                  style: GoogleFonts.cairo(
                    color: _isDark ? AppColors.goldLight : AppColors.navy,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (_hasFilters) ...<Widget>[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: ActionChip(
                avatar: const Icon(
                  Icons.filter_alt_off_rounded,
                  color: Colors.red,
                  size: 17,
                ),
                label: Text(
                  'مسح كل الفلاتر',
                  style: GoogleFonts.cairo(
                    color: Colors.red.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _clearFilters,
                backgroundColor: Colors.red.withValues(alpha: 0.06),
                side: BorderSide(color: Colors.red.withValues(alpha: 0.20)),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.04, end: 0);
  }

  Widget _squareControl({
    required String tooltip,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 45,
          height: 48,
          decoration: BoxDecoration(
            color: active
                ? AppColors.gold.withValues(alpha: 0.12)
                : AppColors.inputFill(_isDark),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: active
                  ? AppColors.gold.withValues(alpha: 0.55)
                  : AppColors.divider(_isDark),
            ),
          ),
          child: Icon(
            icon,
            color: active ? AppColors.goldDark : _secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _viewButton({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
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
    );
  }

  Widget _tierChip(String tier) {
    final selected = _tierView == tier;
    final color = tier == 'all' ? AppColors.navyLight : _tierColor(tier);
    return InkWell(
      onTap: () => setState(() {
        _tierView = tier;
        _visibleCount = 60;
      }),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.13)
              : AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.45)
                : AppColors.divider(_isDark),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (tier != 'all') ...<Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              _tierLabel(tier),
              style: GoogleFonts.cairo(
                color: selected ? color : _secondaryTextColor,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();
    if (_filtered.isEmpty) return _buildEmpty();
    return _isGridView ? _buildGrid() : _buildList();
  }

  Widget _buildLoading() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: 7,
      itemBuilder: (_, int index) => Container(
        height: 112,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(_isDark)),
        ),
        child: Center(
          child: index == 2
              ? const CircularProgressIndicator(color: AppColors.gold)
              : const SizedBox.shrink(),
        ),
      ).animate(onPlay: (AnimationController c) => c.repeat()).shimmer(
            duration: 1200.ms,
            color: AppColors.gold.withValues(alpha: 0.08),
          ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.cloud_off_rounded,
                  color: Colors.red.shade400, size: 46),
              const SizedBox(height: 14),
              Text(
                'تعذر تحميل قائمة الأسعار',
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: _secondaryTextColor,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        children: <Widget>[
          const SizedBox(height: 70),
          const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.goldDark,
            size: 64,
          ),
          const SizedBox(height: 15),
          Text(
            'لا توجد منتجات مطابقة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: _textColor,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'عدّل الفلاتر أو البحث لعرض نتائج أخرى.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: _secondaryTextColor,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: Text('مسح الفلاتر', style: GoogleFonts.cairo()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => _loadData(showLoader: false),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 4
              : constraints.maxWidth >= 700
                  ? 3
                  : 2;
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 92),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: _canSeeCosts ? 405 : 374,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _visibleRows.length +
                (_visibleRows.length < _filtered.length ? 1 : 0),
            itemBuilder: (BuildContext context, int index) {
              if (index >= _visibleRows.length) return _loadMoreCard();
              return _priceGridCard(_visibleRows[index], index);
            },
          );
        },
      ),
    );
  }

  Widget _loadMoreCard() {
    return InkWell(
      onTap: () => setState(() => _visibleCount += 60),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.35),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.expand_more_rounded,
                color: AppColors.goldDark, size: 34),
            const SizedBox(height: 7),
            Text(
              'تحميل المزيد',
              style: GoogleFonts.cairo(
                color: _textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${_filtered.length - _visibleRows.length} صنف متبقٍ',
              style: GoogleFonts.cairo(
                color: _secondaryTextColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceGridCard(Map<String, dynamic> row, int index) {
    final id = _productId(row);
    final selected = _compareIds.contains(id);
    final pending = _boolValue(row['HasPendingRequest']);
    final website = _boolValue(row['IsWebsite']);
    final stock = _number(row['StockQuantity']);
    final mainImageId = _intValue(row['MainImageId']);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color:
              selected ? const Color(0xFF6366F1) : AppColors.divider(_isDark),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.13 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openProduct(row),
          onLongPress: () => _toggleCompare(row),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  Container(
                    height: 118,
                    color: AppColors.inputFill(_isDark),
                    child: mainImageId > 0
                        ? Image.network(
                            '$baseUrl/api/product-image-by-id/$mainImageId',
                            width: double.infinity,
                            height: 118,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: InkWell(
                      onTap: () => _toggleCompare(row),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF6366F1)
                              : Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: Icon(
                          selected
                              ? Icons.check_rounded
                              : Icons.compare_arrows_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                  if (pending)
                    Positioned(
                      top: 7,
                      left: 7,
                      child: _photoBadge(
                        label: 'طلب معلق',
                        icon: Icons.pending_actions_rounded,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  Positioned(
                    bottom: 7,
                    right: 7,
                    child: _photoBadge(
                      label: stock > 0
                          ? 'متاح ${_formatMoney(stock)}'
                          : 'غير متاح',
                      icon: Icons.inventory_rounded,
                      color: stock > 0
                          ? const Color(0xFF15803D)
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${row['ProductName'] ?? 'بدون اسم'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                color: _textColor,
                                fontSize: 11.8,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (website)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.public_rounded,
                                color: Color(0xFF0891B2),
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#$id · ${row['GroupName'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: _secondaryTextColor,
                          fontSize: 9,
                        ),
                      ),
                      if (_intValue(row['SaleDiscountPercent']) >
                          0) ...<Widget>[
                        const SizedBox(height: 4),
                        _discountChip(row),
                      ],
                      const SizedBox(height: 7),
                      if (_canSeeSalePrices)
                        _priceRows(row, compact: true)
                      else
                        _hiddenPricesNotice(),
                      const Spacer(),
                      _cardActions(row),
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

  Widget _photoBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 8.3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _discountChip(Map<String, dynamic> row) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.local_offer_rounded, color: Colors.red.shade600, size: 12),
          const SizedBox(width: 4),
          Text(
            'تخفيض ${_intValue(row['SaleDiscountPercent'])}%',
            style: GoogleFonts.cairo(
              color: Colors.red.shade600,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRows(Map<String, dynamic> row, {required bool compact}) {
    final tiers = _tierView == 'all' ? _tiers : <String>[_tierView];
    return Column(
      children: tiers.map<Widget>((String tier) {
        final color = _tierColor(tier);
        final value = _price(row, tier);
        final cost = _cost(row, tier);
        final premiumDiscount = tier == 'Premium' &&
            _intValue(row['SaleDiscountPercent']) > 0 &&
            _number(row['PreviousPremiumPrice']) > 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 10,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _tierLabel(tier),
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: compact ? 8.5 : 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (premiumDiscount)
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Text(
                    _formatMoney(row['PreviousPremiumPrice']),
                    style: GoogleFonts.cairo(
                      color: _secondaryTextColor,
                      fontSize: 8,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              Text(
                value > 0 ? '${_formatMoney(value)} ج' : '—',
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: compact ? 10 : 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (_canSeeCosts && cost > 0) ...<Widget>[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color:
                        Colors.black.withValues(alpha: _isDark ? 0.16 : 0.04),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'ت ${_formatMoney(cost)}',
                    style: GoogleFonts.cairo(
                      color: _secondaryTextColor,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _hiddenPricesNotice() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.visibility_off_rounded,
              color: _secondaryTextColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'أسعار البيع غير متاحة لهذا الدور',
              style: GoogleFonts.cairo(
                color: _secondaryTextColor,
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardActions(Map<String, dynamic> row) {
    final canChange = _canEditSalePrice ||
        _canEditCost ||
        (_canRequestPriceChange && !_boolValue(row['HasPendingRequest']));
    return Row(
      children: <Widget>[
        _miniAction(
          tooltip: 'الصور',
          icon: Icons.photo_library_rounded,
          onTap:
              _intValue(row['ImageCount']) > 0 ? () => _openGallery(row) : null,
        ),
        if (_canViewHistory) ...<Widget>[
          const SizedBox(width: 5),
          _miniAction(
            tooltip: 'سجل الأسعار',
            icon: Icons.history_rounded,
            onTap: () => _openHistory(row),
          ),
        ],
        const Spacer(),
        if (canChange)
          SizedBox(
            height: 32,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                backgroundColor: _canRequestPriceChange
                    ? AppColors.goldDark
                    : AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _openPriceAction(row),
              icon: Icon(
                _canRequestPriceChange
                    ? Icons.outlined_flag_rounded
                    : Icons.edit_rounded,
                size: 14,
              ),
              label: Text(
                _canRequestPriceChange ? 'طلب' : 'تعديل',
                style: GoogleFonts.cairo(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _miniAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: AppColors.inputFill(_isDark),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider(_isDark)),
          ),
          child: Icon(
            icon,
            size: 15,
            color: onTap == null
                ? Colors.grey.withValues(alpha: 0.35)
                : AppColors.goldDark,
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.inputFill(_isDark),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        color: _secondaryTextColor,
        size: 34,
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => _loadData(showLoader: false),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 92),
        itemCount: _visibleRows.length +
            (_visibleRows.length < _filtered.length ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= _visibleRows.length) {
            return Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _visibleCount += 60),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text(
                  'تحميل المزيد (${_filtered.length - _visibleRows.length})',
                  style: GoogleFonts.cairo(),
                ),
              ),
            );
          }
          return _priceListCard(_visibleRows[index], index);
        },
      ),
    );
  }

  Widget _priceListCard(Map<String, dynamic> row, int index) {
    final id = _productId(row);
    final imageId = _intValue(row['MainImageId']);
    final selected = _compareIds.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              selected ? const Color(0xFF6366F1) : AppColors.divider(_isDark),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openProduct(row),
          onLongPress: () => _toggleCompare(row),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    Container(
                      width: 74,
                      height: 82,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.inputFill(_isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: imageId > 0
                          ? Image.network(
                              '$baseUrl/api/product-image-by-id/$imageId',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                    if (_boolValue(row['IsWebsite']))
                      const Positioned(
                        top: 5,
                        left: 5,
                        child: Icon(
                          Icons.public_rounded,
                          color: Color(0xFF22D3EE),
                          size: 16,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${row['ProductName'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                color: _textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: selected
                                ? 'إزالة من المقارنة'
                                : 'إضافة للمقارنة',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _toggleCompare(row),
                            icon: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.compare_arrows_rounded,
                              color: selected
                                  ? const Color(0xFF6366F1)
                                  : _secondaryTextColor,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '#$id · ${row['GroupName'] ?? ''} · رصيد ${_formatMoney(row['StockQuantity'])}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: _secondaryTextColor,
                          fontSize: 9.5,
                        ),
                      ),
                      const SizedBox(height: 7),
                      if (_canSeeSalePrices)
                        _priceRows(row, compact: false)
                      else
                        _hiddenPricesNotice(),
                      _cardActions(row),
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
          delay: Duration(milliseconds: (index > 10 ? 10 : index) * 25),
          duration: 280.ms,
        )
        .slideY(begin: 0.03, end: 0);
  }

  Future<void> _openFilters() async {
    String? tempGroup = _group;
    int? tempBranch = _branchId;
    String tempPriceFilter = _priceFilter;
    bool tempWebsite = _websiteOnly;

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetSetState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
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
                        const Icon(Icons.tune_rounded,
                            color: AppColors.goldDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تصفية قائمة الأسعار',
                            style: GoogleFonts.cairo(
                              color: _textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _filterDropdown<String>(
                      label: 'المجموعة',
                      icon: Icons.category_rounded,
                      value: tempGroup,
                      items: _groups
                          .map<DropdownMenuItem<String>>(
                            (String group) => DropdownMenuItem<String>(
                              value: group,
                              child: Text(group),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) =>
                          sheetSetState(() => tempGroup = value),
                    ),
                    _filterDropdown<int>(
                      label: 'الفرع',
                      icon: Icons.store_rounded,
                      value: tempBranch,
                      items: _branches
                          .map<DropdownMenuItem<int>>(
                            (Map<String, dynamic> branch) =>
                                DropdownMenuItem<int>(
                              value: _intValue(
                                branch['BranchId'] ?? branch['BranchID'],
                              ),
                              child: Text('${branch['BranchName'] ?? ''}'),
                            ),
                          )
                          .toList(),
                      onChanged: (int? value) =>
                          sheetSetState(() => tempBranch = value),
                    ),
                    if (_canSeeSalePrices)
                      _filterDropdown<String>(
                        label: 'حالة السعر',
                        icon: Icons.price_check_rounded,
                        value: tempPriceFilter,
                        includeAll: false,
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                              value: 'all', child: Text('الكل')),
                          DropdownMenuItem<String>(
                              value: 'priced', child: Text('بأسعار')),
                          DropdownMenuItem<String>(
                              value: 'missing', child: Text('بدون سعر')),
                        ],
                        onChanged: (String? value) {
                          if (value != null) {
                            sheetSetState(() => tempPriceFilter = value);
                          }
                        },
                      ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: tempWebsite,
                      activeThumbColor: AppColors.goldDark,
                      title: Text(
                        'منتجات الموقع فقط',
                        style: GoogleFonts.cairo(
                          color: _textColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      secondary: const Icon(
                        Icons.public_rounded,
                        color: Color(0xFF0891B2),
                      ),
                      onChanged: (bool value) =>
                          sheetSetState(() => tempWebsite = value),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => sheetSetState(() {
                              tempGroup = null;
                              tempBranch = null;
                              tempPriceFilter = 'all';
                              tempWebsite = false;
                            }),
                            icon: const Icon(Icons.filter_alt_off_rounded),
                            label:
                                Text('إعادة ضبط', style: GoogleFonts.cairo()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(sheetContext, true),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              'تطبيق الفلاتر',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800),
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
      ),
    );

    if (apply != true || !mounted) return;
    setState(() {
      _group = tempGroup;
      _priceFilter = tempPriceFilter;
      _websiteOnly = tempWebsite;
      _visibleCount = 60;
    });
    await _selectBranch(tempBranch);
  }

  Widget _filterDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool includeAll = true,
  }) {
    final effectiveItems = <DropdownMenuItem<T>>[
      if (includeAll)
        DropdownMenuItem<T>(value: null, child: const Text('الكل')),
      ...items,
    ];
    final exists = value == null ||
        effectiveItems.any((DropdownMenuItem<T> item) => item.value == value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        key: ValueKey<T?>(value),
        initialValue: exists ? value : null,
        isExpanded: true,
        items: effectiveItems,
        onChanged: onChanged,
        dropdownColor: _cardColor,
        style: GoogleFonts.cairo(color: _textColor, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(color: _secondaryTextColor),
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
        ),
      ),
    );
  }

  String _selectedBranchName() {
    final branch = _branches.cast<Map<String, dynamic>?>().firstWhere(
          (Map<String, dynamic>? item) =>
              _intValue(item?['BranchId'] ?? item?['BranchID']) == _branchId,
          orElse: () => null,
        );
    return '${branch?['BranchName'] ?? 'الفرع المحدد'}';
  }

  void _toggleCompare(Map<String, dynamic> row) {
    final id = _productId(row);
    setState(() {
      if (_compareIds.contains(id)) {
        _compareIds.remove(id);
      } else if (_compareIds.length < 4) {
        _compareIds.add(id);
      } else {
        _showMessage('يمكن مقارنة أربعة منتجات كحد أقصى', isError: true);
      }
    });
  }

  Widget _buildCompareBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: _cardColor,
          border: Border(
            top: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.compare_arrows_rounded,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '${_compareIds.length} منتجات محددة للمقارنة',
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(_compareIds.clear),
              child: Text('مسح', style: GoogleFonts.cairo()),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              onPressed: _openComparison,
              icon: const Icon(Icons.visibility_rounded, size: 17),
              label: Text(
                'عرض المقارنة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openComparison() async {
    final selected = _rows
        .where(
            (Map<String, dynamic> row) => _compareIds.contains(_productId(row)))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.78,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
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
                    const Icon(Icons.compare_arrows_rounded,
                        color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'مقارنة المنتجات',
                        style: GoogleFonts.cairo(
                          color: _textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: selected.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (_, int index) {
                      final row = selected[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill(_isDark),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider(_isDark)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${row['ProductName'] ?? ''}',
                              style: GoogleFonts.cairo(
                                color: _textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '#${_productId(row)} · ${row['GroupName'] ?? ''} · رصيد ${_formatMoney(row['StockQuantity'])}',
                              style: GoogleFonts.cairo(
                                color: _secondaryTextColor,
                                fontSize: 9.5,
                              ),
                            ),
                            const SizedBox(height: 9),
                            if (_canSeeSalePrices)
                              _priceRows(row, compact: false),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPriceAction(Map<String, dynamic> row) async {
    if (_canRequestPriceChange && _boolValue(row['HasPendingRequest'])) {
      _showMessage('يوجد طلب تعديل سعر معلق لهذا المنتج', isError: true);
      return;
    }

    String mode = _canEditSalePrice
        ? 'sale'
        : _canEditCost
            ? 'cost'
            : 'request';
    String tier = _tierView == 'all' ? 'Premium' : _tierView;
    final valueController = TextEditingController();
    final reasonController = TextEditingController();
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetSetState) {
            final currentValue =
                mode == 'cost' ? _cost(row, tier) : _price(row, tier);
            final actionLabel = mode == 'request'
                ? 'إرسال طلب المراجعة'
                : mode == 'cost'
                    ? 'حفظ التكلفة'
                    : 'حفظ سعر البيع';
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
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
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                mode == 'request'
                                    ? Icons.outlined_flag_rounded
                                    : Icons.edit_rounded,
                                color: AppColors.goldDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    mode == 'request'
                                        ? 'طلب تعديل سعر'
                                        : 'تعديل بيانات التسعير',
                                    style: GoogleFonts.cairo(
                                      color: _textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${row['ProductName'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.cairo(
                                      color: _secondaryTextColor,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        if (_canEditSalePrice && _canEditCost) ...<Widget>[
                          const SizedBox(height: 13),
                          SegmentedButton<String>(
                            segments: const <ButtonSegment<String>>[
                              ButtonSegment<String>(
                                value: 'sale',
                                icon: Icon(Icons.sell_rounded),
                                label: Text('سعر البيع'),
                              ),
                              ButtonSegment<String>(
                                value: 'cost',
                                icon: Icon(Icons.factory_rounded),
                                label: Text('التكلفة'),
                              ),
                            ],
                            selected: <String>{mode},
                            onSelectionChanged: saving
                                ? null
                                : (Set<String> value) => sheetSetState(() {
                                      mode = value.first;
                                      valueController.clear();
                                    }),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: _tiers.map<Widget>((String value) {
                            final selected = tier == value;
                            final color = _tierColor(value);
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  onTap: saving
                                      ? null
                                      : () => sheetSetState(() {
                                            tier = value;
                                            valueController.clear();
                                          }),
                                  borderRadius: BorderRadius.circular(11),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? color.withValues(alpha: 0.12)
                                          : AppColors.inputFill(_isDark),
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(
                                        color: selected
                                            ? color
                                            : AppColors.divider(_isDark),
                                      ),
                                    ),
                                    child: Text(
                                      _tierLabel(value),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.cairo(
                                        color: selected
                                            ? color
                                            : _secondaryTextColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 13),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill(_isDark),
                            borderRadius: BorderRadius.circular(11),
                            border:
                                Border.all(color: AppColors.divider(_isDark)),
                          ),
                          child: Row(
                            children: <Widget>[
                              Text(
                                mode == 'cost'
                                    ? 'التكلفة الحالية'
                                    : 'السعر الحالي',
                                style: GoogleFonts.cairo(
                                  color: _secondaryTextColor,
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_formatMoney(currentValue)} ج.م',
                                style: GoogleFonts.cairo(
                                  color: _textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: valueController,
                          enabled: !saving,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]')),
                          ],
                          style: GoogleFonts.cairo(color: _textColor),
                          decoration: _sheetInputDecoration(
                            label: mode == 'cost'
                                ? 'التكلفة الجديدة *'
                                : mode == 'request'
                                    ? 'السعر المطلوب *'
                                    : 'سعر البيع الجديد *',
                            icon: mode == 'cost'
                                ? Icons.factory_rounded
                                : Icons.payments_rounded,
                            suffix: 'ج.م',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: reasonController,
                          enabled: !saving,
                          maxLines: 3,
                          maxLength: 300,
                          style: GoogleFonts.cairo(color: _textColor),
                          decoration: _sheetInputDecoration(
                            label: mode == 'request'
                                ? 'سبب الطلب *'
                                : 'سبب التعديل *',
                            icon: Icons.notes_rounded,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: mode == 'request'
                                  ? AppColors.goldDark
                                  : AppColors.navy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    final value = double.tryParse(
                                      valueController.text.replaceAll(',', ''),
                                    );
                                    final reason = reasonController.text.trim();
                                    if (value == null || value < 0) {
                                      _showMessage('أدخل قيمة صحيحة',
                                          isError: true);
                                      return;
                                    }
                                    if (reason.isEmpty) {
                                      _showMessage('سبب التعديل أو الطلب مطلوب',
                                          isError: true);
                                      return;
                                    }

                                    sheetSetState(() => saving = true);
                                    try {
                                      Map<String, dynamic> result;
                                      if (mode == 'request') {
                                        result =
                                            await _service.requestPriceChange(
                                          productId: _productId(row),
                                          tier: tier,
                                          requestedPrice: value,
                                          reason: reason,
                                        );
                                      } else if (mode == 'cost') {
                                        result = await _service.updateCost(
                                          productId: _productId(row),
                                          tier: tier,
                                          newCost: value,
                                          reason: reason,
                                        );
                                      } else {
                                        result = await _service.updateSalePrice(
                                          productId: _productId(row),
                                          tier: tier,
                                          newPrice: value,
                                          reason: reason,
                                        );
                                      }
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }
                                      Navigator.pop(sheetContext);
                                      _showMessage(
                                        '${result['message'] ?? 'تم الحفظ بنجاح'}',
                                      );
                                      await _loadData(showLoader: false);
                                    } catch (error) {
                                      if (mounted) {
                                        _showMessage(error.toString(),
                                            isError: true);
                                      }
                                      if (sheetContext.mounted) {
                                        sheetSetState(() => saving = false);
                                      }
                                    }
                                  },
                            icon: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    mode == 'request'
                                        ? Icons.send_rounded
                                        : Icons.save_rounded,
                                  ),
                            label: Text(
                              saving ? 'جاري الحفظ...' : actionLabel,
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    valueController.dispose();
    reasonController.dispose();
  }

  InputDecoration _sheetInputDecoration({
    required String label,
    required IconData icon,
    String? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(color: _secondaryTextColor),
      prefixIcon: Icon(icon, color: AppColors.goldDark, size: 19),
      suffixText: suffix,
      suffixStyle: GoogleFonts.cairo(
        color: AppColors.goldDark,
        fontWeight: FontWeight.w700,
      ),
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
    );
  }

  Future<void> _openHistory(Map<String, dynamic> row) async {
    final productId = _productId(row);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.78,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider(_isDark),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: <Widget>[
                    const Icon(Icons.history_rounded,
                        color: AppColors.goldDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'سجل الأسعار',
                            style: GoogleFonts.cairo(
                              color: _textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${row['ProductName'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: _secondaryTextColor,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: _service.getHistory(productId),
                    builder: (BuildContext context,
                        AsyncSnapshot<List<dynamic>> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child:
                              CircularProgressIndicator(color: AppColors.gold),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style:
                                GoogleFonts.cairo(color: Colors.red.shade400),
                          ),
                        );
                      }
                      final history = snapshot.data ?? const <dynamic>[];
                      if (history.isEmpty) {
                        return Center(
                          child: Text(
                            'لا يوجد سجل أسعار لهذا المنتج',
                            style:
                                GoogleFonts.cairo(color: _secondaryTextColor),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, int index) =>
                            _historyCard(_map(history[index])),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> record) {
    final type = '${record['PriceType'] ?? ''}';
    final oldValue = _number(record['OldPrice']);
    final newValue = _number(record['NewPrice']);
    final increase = newValue > oldValue;
    final tier = type.replaceAll('_Cost', '');
    final isCost = type.endsWith('_Cost');
    final color = _tierColor(_tiers.contains(tier) ? tier : 'Premium');
    final date = DateTime.tryParse('${record['ChangedAt'] ?? ''}');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${isCost ? 'تكلفة' : 'بيع'} ${_tierLabel(tier)}',
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                increase
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: increase ? Colors.red.shade500 : Colors.green.shade600,
                size: 17,
              ),
              const SizedBox(width: 4),
              Text(
                date == null
                    ? '${record['ChangedAt'] ?? ''}'
                    : DateFormat('yyyy/MM/dd HH:mm').format(date.toLocal()),
                style: GoogleFonts.cairo(
                  color: _secondaryTextColor,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                '${_formatMoney(oldValue)} ج',
                style: GoogleFonts.cairo(
                  color: _secondaryTextColor,
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 9),
                child: Icon(Icons.arrow_back_rounded,
                    color: Colors.grey, size: 17),
              ),
              Text(
                '${_formatMoney(newValue)} ج',
                style: GoogleFonts.cairo(
                  color: _textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${record['ChangedBy'] ?? ''}',
                style: GoogleFonts.cairo(
                  color: _secondaryTextColor,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          if ('${record['ChangeReason'] ?? ''}'.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '${record['ChangeReason']}',
              style: GoogleFonts.cairo(
                color: _secondaryTextColor,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openGallery(Map<String, dynamic> row) async {
    try {
      final ids = await _service.getImageIds(_productId(row));
      if (!mounted) return;
      if (ids.isEmpty) {
        _showMessage('لا توجد صور لهذا المنتج', isError: true);
        return;
      }

      var index = 0;
      final controller = PageController();
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (BuildContext dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter dialogSetState) {
              return Dialog.fullscreen(
                backgroundColor: AppColors.navyDark,
                child: SafeArea(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${row['ProductName'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${index + 1}/${ids.length}',
                              style: GoogleFonts.cairo(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: controller,
                          itemCount: ids.length,
                          onPageChanged: (int value) =>
                              dialogSetState(() => index = value),
                          itemBuilder: (_, int imageIndex) => InteractiveViewer(
                            child: Center(
                              child: Image.network(
                                '$baseUrl/api/product-image-by-id/${ids[imageIndex]}',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.white54,
                                  size: 60,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (ids.length > 1)
                        SizedBox(
                          height: 76,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(8),
                            itemCount: ids.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 7),
                            itemBuilder: (_, int imageIndex) => InkWell(
                              onTap: () => controller.animateToPage(
                                imageIndex,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              ),
                              child: Container(
                                width: 58,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: index == imageIndex
                                        ? AppColors.gold
                                        : Colors.white24,
                                    width: index == imageIndex ? 2 : 1,
                                  ),
                                ),
                                child: Image.network(
                                  '$baseUrl/api/product-image-by-id/${ids[imageIndex]}',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      controller.dispose();
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    }
  }

  void _openProduct(Map<String, dynamic> row) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailsScreen(
          productId: _productId(row),
          username: widget.username,
        ),
      ),
    ).then((_) => _loadData(showLoader: false));
  }

  Future<void> _exportExcel() async {
    if (!_canExport || _exporting) return;
    setState(() => _exporting = true);
    try {
      final workbook = excel.Excel.createExcel();
      final sheet = workbook['قائمة الأسعار'];
      final headers = <excel.CellValue>[
        excel.TextCellValue('الكود'),
        excel.TextCellValue('الصنف'),
        excel.TextCellValue('المجموعة'),
        excel.TextCellValue('ستاندرد'),
        excel.TextCellValue('بريميوم'),
        excel.TextCellValue('إيليت'),
        if (_canSeeCosts) excel.TextCellValue('تكلفة ستاندرد'),
        if (_canSeeCosts) excel.TextCellValue('تكلفة بريميوم'),
        if (_canSeeCosts) excel.TextCellValue('تكلفة إيليت'),
        excel.TextCellValue('الرصيد'),
        excel.TextCellValue('منتج موقع'),
      ];
      sheet.appendRow(headers);
      for (final row in _filtered) {
        sheet.appendRow(<excel.CellValue>[
          excel.IntCellValue(_productId(row)),
          excel.TextCellValue('${row['ProductName'] ?? ''}'),
          excel.TextCellValue('${row['GroupName'] ?? ''}'),
          excel.DoubleCellValue(_price(row, 'CClass')),
          excel.DoubleCellValue(_price(row, 'Premium')),
          excel.DoubleCellValue(_price(row, 'Elite')),
          if (_canSeeCosts) excel.DoubleCellValue(_cost(row, 'CClass')),
          if (_canSeeCosts) excel.DoubleCellValue(_cost(row, 'Premium')),
          if (_canSeeCosts) excel.DoubleCellValue(_cost(row, 'Elite')),
          excel.DoubleCellValue(_number(row['StockQuantity'])),
          excel.TextCellValue(_boolValue(row['IsWebsite']) ? 'نعم' : 'لا'),
        ]);
      }

      final bytes = workbook.save();
      if (bytes == null) throw StateError('تعذر إنشاء ملف Excel');
      final directory = await getApplicationDocumentsDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/price_list_$stamp.xlsx');
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
          text: 'قائمة الأسعار',
        ),
      );
      if (mounted) _showMessage('تم تجهيز ملف Excel بنجاح');
    } catch (error) {
      if (mounted) _showMessage('تعذر التصدير: $error', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }
}
