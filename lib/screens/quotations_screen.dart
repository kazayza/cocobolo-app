import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_colors.dart';
import '../services/app_text_styles.dart';
import '../services/quotation_service.dart';
import '../services/theme_service.dart';
import 'quotation_details_screen.dart';
import 'quotation_form_screen.dart';

class QuotationsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const QuotationsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  final QuotationService _service = QuotationService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  Map<String, dynamic> _stats = <String, dynamic>{};
  Map<String, dynamic> _capabilities = <String, dynamic>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _exporting = false;
  String? _error;
  String _search = '';
  String? _status;
  bool? _converted;
  bool? _pendingOnly;
  bool? _expired;
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _hasMore = false;
  Timer? _searchDebounce;

  bool get _isDark => ThemeService().isDarkMode;
  Color get _cardColor => AppColors.card(_isDark);
  Color get _textColor => AppColors.text(_isDark);
  Color get _secondaryTextColor => AppColors.textSecondary(_isDark);
  bool _can(String key) => _capabilities[key] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _bool(dynamic value) {
    return value == true || value == 1 || value?.toString() == '1';
  }

  Future<void> _load({bool append = false}) async {
    if (append) {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }

    try {
      final data = await _service.getQuotations(
        search: _search.trim().isEmpty ? null : _search.trim(),
        status: _status,
        converted: _converted,
        pendingOnly: _pendingOnly,
        expired: _expired,
        startDate: _from,
        endDate: _to,
        page: append ? _page + 1 : 1,
      );
      final incoming = ((data['rows'] as List?) ?? const <dynamic>[])
          .map<Map<String, dynamic>>(_map)
          .toList();
      final pagination = _map(data['pagination']);
      if (!mounted) return;
      setState(() {
        if (append) {
          _rows.addAll(incoming);
          _page++;
        } else {
          _rows = incoming;
          _page = _int(pagination['page']).clamp(1, 999999);
        }
        _stats = _map(data['stats']);
        _capabilities = _map(data['capabilities']);
        _hasMore = pagination['hasMore'] == true;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error.toString();
      });
    }
  }

  void _onSearch(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 420), () {
      _search = value;
      _load();
    });
  }

  void _applyQuick(String key) {
    setState(() {
      _status = null;
      _converted = null;
      _pendingOnly = null;
      _expired = null;
      switch (key) {
        case 'accepted':
          _status = 'Accepted';
          break;
        case 'rejected':
          _status = 'Rejected';
          break;
        case 'converted':
          _converted = true;
          break;
        case 'pending':
          _pendingOnly = true;
          break;
        case 'expired':
          _expired = true;
          break;
      }
    });
    _load();
  }

  bool _quickActive(String key) {
    return switch (key) {
      'accepted' => _status == 'Accepted',
      'rejected' => _status == 'Rejected',
      'converted' => _converted == true,
      'pending' => _pendingOnly == true,
      'expired' => _expired == true,
      _ => _status == null &&
          _converted == null &&
          _pendingOnly == null &&
          _expired == null,
    };
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _search = '';
      _status = null;
      _converted = null;
      _pendingOnly = null;
      _expired = null;
      _from = null;
      _to = null;
    });
    _load();
  }

  // ===========================================================================
  // 🎨 الواجهة الرسومية العصرية (Executive CRM Quotations Hub)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final bgColor =
        _isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.request_quote_rounded,
                  color: AppColors.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'إدارة عروض الأسعار',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  Text(
                    _can('isCostOnlyViewer')
                        ? 'مراجعة التكاليف الفنية للأصناف'
                        : 'متابعة العروض والتحويل للفواتير',
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            if (_can('canExport'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: AppColors.gold,
                  ),
                  tooltip: 'تصدير لتقرير Excel',
                  onPressed: _exporting ? null : _exportExcel,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.gold,
                          ),
                        )
                      : const Icon(Icons.table_view_rounded, size: 20),
                ),
              ),
            IconButton(
              tooltip: 'تحديث البيانات',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.sync_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder:
              (BuildContext context, bool innerBoxIsScrolled) => <Widget>[
            SliverToBoxAdapter(child: _buildExecutiveHeaderAndKpis()),
            SliverToBoxAdapter(child: _buildModernControls()),
          ],
          body: _body(),
        ),
        floatingActionButton: _can('canAdd')
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                onPressed: _openNew,
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.post_add_rounded,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
                label: Text(
                  'إنشاء عرض سعر',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              )
                .animate()
                .fadeIn(delay: 200.ms)
                .scale(begin: const Offset(0.92, 0.92))
            : null,
      ),
    );
  }

  String _compactMoney(dynamic value) {
    final amount = _num(value);
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M ج';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K ج';
    return '${NumberFormat('#,##0').format(amount)} ج';
  }

  // 1️⃣ لوحة المؤشرات التنفيذية المدمجة (Executive Bento KPI Banner)
  Widget _buildExecutiveHeaderAndKpis() {
    final masked = _can('isCostOnlyViewer');
    final cards = masked
        ? <_KpiSpec>[
            const _KpiSpec(
              icon: Icons.all_inbox_rounded,
              label: 'العروض الجارية',
              color: AppColors.gold,
            ),
            const _KpiSpec(
              icon: Icons.edit_note_rounded,
              label: 'قيد المسودة',
              color: Colors.amberAccent,
            ),
          ]
        : <_KpiSpec>[
            const _KpiSpec(
              icon: Icons.payments_rounded,
              label: 'إجمالي القيمة',
              color: AppColors.gold,
            ),
            const _KpiSpec(
              icon: Icons.groups_2_rounded,
              label: 'العملاء',
              color: Color(0xFF38BDF8),
            ),
            const _KpiSpec(
              icon: Icons.auto_graph_rounded,
              label: 'معدل التحويل',
              color: Color(0xFF4ADE80),
            ),
            const _KpiSpec(
              icon: Icons.layers_rounded,
              label: 'إجمالي العروض',
              color: Color(0xFFC084FC),
            ),
          ];

    final values = masked
        ? <String>[
            '${_int(_stats['TotalCount'])}',
            '${_int(_stats['DraftCount'])}',
          ]
        : <String>[
            _compactMoney(_stats['TotalValue']),
            '${_int(_stats['DistinctCustomersCount'])}',
            '${_num(_stats['SentConversionRate']).toStringAsFixed(1)}%',
            '${_int(_stats['TotalCount'])}',
          ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            AppColors.navy,
            Color(0xFF1E293B),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < cards.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _buildGlassKpiTile(cards[i], values[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassKpiTile(_KpiSpec spec, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(spec.icon, size: 16, color: spec.color),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            spec.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 2️⃣ شريط البحث والفلاتر الذكية (Modern Search & Pill Filters)
  Widget _buildModernControls() {
    final quicks = <(String, String, int, IconData, Color)>[
      (
        'all',
        'الكل',
        _int(_stats['TotalCount']),
        Icons.grid_view_rounded,
        AppColors.navy
      ),
      (
        'accepted',
        'مقبول',
        _int(_stats['AcceptedCount']),
        Icons.verified_rounded,
        AppColors.success
      ),
      (
        'converted',
        'محوّل لفاتورة',
        _int(_stats['ConvertedCount']),
        Icons.price_check_rounded,
        Colors.teal
      ),
      (
        'pending',
        'قيد الانتظار',
        _int(_stats['DraftCount']) + _int(_stats['SentCount']),
        Icons.pending_actions_rounded,
        AppColors.warning
      ),
      (
        'rejected',
        'مرفوض',
        _int(_stats['RejectedCount']),
        Icons.do_not_disturb_on_rounded,
        AppColors.error
      ),
      (
        'expired',
        'منتهي الصلاحية',
        _int(_stats['ExpiredCount']),
        Icons.history_toggle_off_rounded,
        Colors.deepOrange
      ),
    ];

    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider(_isDark)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.12 : 0.03),
            blurRadius: 12,
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
                  style: GoogleFonts.cairo(
                    color: _textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم العميل، الهاتف، أو رقم العرض...',
                    hintStyle: GoogleFonts.cairo(
                      color: AppColors.textHint(_isDark),
                      fontSize: 11,
                    ),
                    prefixIcon: const Icon(
                      Icons.manage_search_rounded,
                      color: AppColors.goldDark,
                      size: 22,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _search = '';
                              _load();
                            },
                            icon: const Icon(Icons.cancel_rounded, size: 18),
                          ),
                    filled: true,
                    fillColor: _isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.divider(_isDark)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.gold, width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openFilters,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: _hasFilters
                        ? AppColors.gold.withValues(alpha: 0.18)
                        : AppColors.navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _hasFilters
                          ? AppColors.gold
                          : AppColors.divider(_isDark),
                    ),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: _hasFilters ? AppColors.goldDark : _textColor,
                    size: 21,
                  ),
                ),
              ),
              if (_hasFilters) ...<Widget>[
                const SizedBox(width: 6),
                InkWell(
                  onTap: _resetFilters,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 46,
                    width: 42,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.filter_alt_off_rounded,
                      color: AppColors.error,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quicks.expand<Widget>((item) {
                return <Widget>[
                  _quickChip(
                    keyName: item.$1,
                    label: item.$2,
                    count: item.$3,
                    icon: item.$4,
                    color: item.$5,
                  ),
                  const SizedBox(width: 8),
                ];
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasFilters {
    return _search.isNotEmpty ||
        _status != null ||
        _converted != null ||
        _pendingOnly != null ||
        _expired != null ||
        _from != null ||
        _to != null;
  }

  Widget _quickChip({
    required String keyName,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final active = _quickActive(keyName);
    final effectiveColor =
        (keyName == 'all' && _isDark) ? AppColors.gold : color;

    return InkWell(
      onTap: () => _applyQuick(keyName),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? effectiveColor.withValues(alpha: 0.14)
              : (_isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? effectiveColor.withValues(alpha: 0.5)
                : AppColors.divider(_isDark),
            width: active ? 1.3 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              color: active ? effectiveColor : _secondaryTextColor,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: active ? _textColor : _secondaryTextColor,
                fontSize: 11,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? effectiveColor
                    : Colors.grey.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.cairo(
                  color: active ? Colors.white : _secondaryTextColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_error != null) return _errorState();
    if (_rows.isEmpty) return _emptyState();
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: _rows.length + (_hasMore ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index == _rows.length) return _loadMoreButton();
          return _quotationCard(_rows[index], index);
        },
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 46, color: AppColors.error),
            ),
            const SizedBox(height: 12),
            Text(
              'تعذر تحميل عروض الأسعار',
              style: GoogleFonts.cairo(
                color: _textColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.cairo(color: _secondaryTextColor, fontSize: 11),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: <Widget>[
        const SizedBox(height: 60),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.request_quote_outlined,
              size: 44,
              color: AppColors.goldDark,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'لا توجد عروض أسعار مطابقة',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: _textColor,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _hasFilters
              ? 'جرّب مسح الفلاتر الحالية أو البحث بكلمات أخرى.'
              : 'ابدأ الآن بإنشاء أول عرض سعر لعملائك.',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(color: _secondaryTextColor, fontSize: 12),
        ),
      ],
    );
  }

  Widget _loadMoreButton() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.goldDark,
            side: const BorderSide(color: AppColors.gold),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _loadingMore ? null : () => _load(append: true),
          icon: _loadingMore
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.keyboard_double_arrow_down_rounded),
          label: Text(
            _loadingMore ? 'جاري التحميل...' : 'عرض المزيد من السجلات',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  // 3️⃣ بطاقة عرض السعر التنفيذية (Executive Quotation Card)
  Widget _quotationCard(Map<String, dynamic> row, int index) {
    final id = _int(row['QuotationID']);
    final status = '${row['Status'] ?? 'Draft'}';
    final converted = row['InvoiceID'] != null;
    final expired = _isExpired(row);
    final masked = _bool(row['PricesMasked']);
    final effectiveStatus = converted ? 'Converted' : status;
    final statusColor = _statusColor(effectiveStatus);
    final date = DateTime.tryParse('${row['QuotationDate'] ?? ''}');
    final surface = _isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: converted
              ? Colors.teal.withValues(alpha: 0.35)
              : AppColors.divider(_isDark),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.15 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openDetails(id),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // الشريط الجانبي الملون المعبر عن حالة العرض
                  Container(
                    width: 5,
                    color: statusColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // السطر العلوي: أيقونة فخمة + رقم المرجع والتاريخ + شارة الحالة
                          Row(
                            children: <Widget>[
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Icon(
                                  _statusIcon(effectiveStatus),
                                  color: statusColor,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      '${row['ReferenceNumber'] ?? 'QT-${date?.year ?? ''}-$id'}',
                                      style: GoogleFonts.cairo(
                                        color: _textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 11,
                                          color: _secondaryTextColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          date == null
                                              ? ''
                                              : DateFormat('yyyy/MM/dd')
                                                  .format(date.toLocal()),
                                          style: GoogleFonts.cairo(
                                            color: _secondaryTextColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              _statusBadge(effectiveStatus),
                              if (expired) ...<Widget>[
                                const SizedBox(width: 5),
                                _statusBadge('Expired'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          // الكبسولة الوسطى: بيانات العميل + الإجمالي المالي
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: AppColors.divider(_isDark)),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.navy,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Text(
                                    _initial('${row['PartyName'] ?? ''}'),
                                    style: GoogleFonts.cairo(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        '${row['PartyName'] ?? 'عميل غير محدد'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.cairo(
                                          color: _textColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if ('${row['PartyPhone'] ?? ''}'
                                          .trim()
                                          .isNotEmpty)
                                        Text(
                                          '📞 ${row['PartyPhone']}',
                                          style: GoogleFonts.cairo(
                                            color: _secondaryTextColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!masked)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Text(
                                        '${_money(row['GrandTotal'])} ج.م',
                                        style: GoogleFonts.cairo(
                                          color: _isDark
                                              ? AppColors.gold
                                              : AppColors.navy,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (_can('canViewCost') &&
                                          row['TotalCost'] != null)
                                        Text(
                                          'التكلفة: ${_money(row['TotalCost'])} ج',
                                          style: GoogleFonts.cairo(
                                            color: _secondaryTextColor,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  )
                                else if (row['TotalCost'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'التكلفة: ${_money(row['TotalCost'])} ج',
                                      style: GoogleFonts.cairo(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // شارات المعلومات السريعة (Metadata Chips)
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            children: <Widget>[
                              _infoChip(
                                Icons.layers_outlined,
                                '${_int(row['ItemsCount'])} أصناف',
                              ),
                              _infoChip(
                                Icons.workspace_premium_rounded,
                                _tierLabel('${row['PricingType'] ?? 'Premium'}'),
                              ),
                              if (_int(row['MaxManufacturingDays']) > 0)
                                _infoChip(
                                  Icons.precision_manufacturing_rounded,
                                  '${_int(row['MaxManufacturingDays'])} يوم تصنيع',
                                ),
                              if ('${row['EmpName'] ?? ''}'.isNotEmpty)
                                _infoChip(
                                  Icons.badge_outlined,
                                  '${row['EmpName']}',
                                ),
                              if (converted &&
                                  '${row['InvoiceReference'] ?? ''}'.isNotEmpty)
                                _infoChip(
                                  Icons.receipt_long_rounded,
                                  'فاتورة ${row['InvoiceReference']}',
                                  highlightColor: Colors.teal,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          // شريط الإجراءات السفلية للكارت
                          Row(
                            children: <Widget>[
                              InkWell(
                                onTap: () => _openDetails(id),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.visibility_outlined,
                                        size: 16,
                                        color: AppColors.info,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'استعراض التفاصيل',
                                        style: GoogleFonts.cairo(
                                          color: AppColors.info,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_can('canEdit') && !converted) ...<Widget>[
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () => _openEdit(id),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: Row(
                                      children: <Widget>[
                                        const Icon(
                                          Icons.edit_note_rounded,
                                          size: 18,
                                          color: AppColors.goldDark,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'تعديل',
                                          style: GoogleFonts.cairo(
                                            color: AppColors.goldDark,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 13,
                                color: _secondaryTextColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: (index > 10 ? 10 : index) * 30),
          duration: 300.ms,
        )
        .slideY(begin: 0.04, end: 0);
  }

  Widget _infoChip(IconData icon, String label, {Color? highlightColor}) {
    final c = highlightColor ?? AppColors.goldDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlightColor != null
            ? highlightColor.withValues(alpha: 0.1)
            : AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlightColor != null
              ? highlightColor.withValues(alpha: 0.3)
              : AppColors.divider(_isDark),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: c, size: 13),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 135),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                color: highlightColor ?? _secondaryTextColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'Sent' => AppColors.info,
      'Accepted' => AppColors.success,
      'Rejected' => AppColors.error,
      'Converted' => Colors.teal,
      'Expired' => Colors.deepOrange,
      _ => AppColors.goldDark,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'Sent' => Icons.forward_to_inbox_rounded,
      'Accepted' => Icons.verified_rounded,
      'Rejected' => Icons.do_not_disturb_on_rounded,
      'Converted' => Icons.price_check_rounded,
      'Expired' => Icons.history_toggle_off_rounded,
      _ => Icons.edit_document,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'Sent' => 'تم الإرسال',
      'Accepted' => 'مقبول',
      'Rejected' => 'مرفوض',
      'Converted' => 'تحوّل لفاتورة',
      'Expired' => 'منتهي',
      _ => 'مسودة',
    };
  }

  String _tierLabel(String tier) {
    return switch (tier) {
      'CClass' => 'ستاندرد',
      'Elite' => 'إيليت',
      'Mixed' => 'مختلط',
      _ => 'بريميوم',
    };
  }

  bool _isExpired(Map<String, dynamic> row) {
    if (row['InvoiceID'] != null) return false;
    final status = '${row['Status'] ?? 'Draft'}';
    if (status != 'Draft' && status != 'Sent') return false;
    final date = DateTime.tryParse('${row['ValidUntil'] ?? ''}');
    return date != null &&
        date.toLocal().isBefore(DateUtils.dateOnly(DateTime.now()));
  }

  String _initial(String value) {
    final clean = value.trim();
    return clean.isEmpty ? 'ع' : clean.substring(0, 1);
  }

  String _money(dynamic value) {
    return NumberFormat('#,##0.##', 'en_US').format(_num(value));
  }

  Future<void> _openFilters() async {
    DateTime? from = _from;
    DateTime? to = _to;
    String? status = _status;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.divider(_isDark),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.filter_alt_rounded,
                            color: AppColors.gold, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تصفية متقدمة لعروض الأسعار',
                            style: GoogleFonts.cairo(
                              color: _textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration:
                          _fieldDecoration('حالة العرض', Icons.flag_rounded),
                      dropdownColor: _cardColor,
                      items: <String>[
                        'Draft',
                        'Sent',
                        'Accepted',
                        'Rejected',
                        'Converted',
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(_statusLabel(value)),
                        );
                      }).toList(),
                      onChanged: (String? value) =>
                          setSheetState(() => status = value),
                    ),
                    const SizedBox(height: 12),
                    _dateTile(
                      label: 'من تاريخ إصدار',
                      value: from,
                      onTap: () async {
                        final picked = await _pickDate(from);
                        if (picked != null) setSheetState(() => from = picked);
                      },
                      onClear: from == null
                          ? null
                          : () => setSheetState(() => from = null),
                    ),
                    const SizedBox(height: 10),
                    _dateTile(
                      label: 'إلى تاريخ إصدار',
                      value: to,
                      onTap: () async {
                        final picked = await _pickDate(to);
                        if (picked != null) setSheetState(() => to = picked);
                      },
                      onClear: to == null
                          ? null
                          : () => setSheetState(() => to = null),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => setSheetState(() {
                              from = null;
                              to = null;
                              status = null;
                            }),
                            icon: const Icon(Icons.restart_alt_rounded),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => Navigator.pop(sheetContext, true),
                            icon: const Icon(Icons.check_circle_rounded,
                                color: AppColors.gold),
                            label: Text(
                              'تطبيق الفلاتر',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w900),
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
    if (applied != true || !mounted) return;
    setState(() {
      _from = from;
      _to = to;
      _status = status;
      _converted = null;
      _pendingOnly = null;
      _expired = null;
    });
    _load();
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(color: _secondaryTextColor),
      prefixIcon: Icon(icon, color: AppColors.goldDark),
      filled: true,
      fillColor: AppColors.inputFill(_isDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider(_isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.divider(_isDark)),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider(_isDark)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.date_range_rounded, color: AppColors.goldDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value == null ? label : DateFormat('yyyy/MM/dd').format(value),
                style: GoogleFonts.cairo(
                  color: value == null ? _secondaryTextColor : _textColor,
                  fontSize: 12.5,
                  fontWeight:
                      value == null ? FontWeight.normal : FontWeight.w800,
                ),
              ),
            ),
            if (onClear != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
  }

  void _openNew() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QuotationFormScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    ).then((dynamic changed) {
      if (changed == true) _load();
    });
  }

  void _openEdit(int id) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QuotationFormScreen(
          userId: widget.userId,
          username: widget.username,
          quotationId: id,
        ),
      ),
    ).then((dynamic changed) {
      if (changed == true) _load();
    });
  }

  void _openDetails(int id) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QuotationDetailsScreen(
          userId: widget.userId,
          username: widget.username,
          quotationId: id,
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _exportExcel() async {
    if (_exporting || !_can('canExport')) return;
    setState(() => _exporting = true);
    try {
      final workbook = excel.Excel.createExcel();
      final sheet = workbook['عروض الأسعار'];
      sheet.appendRow(<excel.CellValue>[
        excel.TextCellValue('المرجع'),
        excel.TextCellValue('التاريخ'),
        excel.TextCellValue('العميل'),
        excel.TextCellValue('الموظف'),
        excel.TextCellValue('الباقة'),
        excel.TextCellValue('الإجمالي'),
        if (_can('canViewCost')) excel.TextCellValue('التكلفة'),
        excel.TextCellValue('الأصناف'),
        excel.TextCellValue('الحالة'),
        excel.TextCellValue('الفاتورة'),
      ]);
      for (final row in _rows) {
        sheet.appendRow(<excel.CellValue>[
          excel.TextCellValue('${row['ReferenceNumber'] ?? ''}'),
          excel.TextCellValue('${row['QuotationDate'] ?? ''}'),
          excel.TextCellValue('${row['PartyName'] ?? ''}'),
          excel.TextCellValue('${row['EmpName'] ?? ''}'),
          excel.TextCellValue(_tierLabel('${row['PricingType'] ?? ''}')),
          excel.DoubleCellValue(_num(row['GrandTotal'])),
          if (_can('canViewCost'))
            excel.DoubleCellValue(_num(row['TotalCost'])),
          excel.IntCellValue(_int(row['ItemsCount'])),
          excel.TextCellValue(_statusLabel('${row['Status'] ?? 'Draft'}')),
          excel.TextCellValue('${row['InvoiceReference'] ?? ''}'),
        ]);
      }
      final bytes = workbook.save();
      if (bytes == null) throw StateError('تعذر إنشاء الملف');
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/quotations_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx',
      );
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
          text: 'تقرير عروض الأسعار',
        ),
      );
    } catch (error) {
      if (mounted) _message('تعذر التصدير: $error', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.cairo()),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// وصف بطاقة إحصائية في صف الـ KPI.
class _KpiSpec {
  final IconData icon;
  final String label;
  final Color color;

  const _KpiSpec({
    required this.icon,
    required this.label,
    required this.color,
  });
}