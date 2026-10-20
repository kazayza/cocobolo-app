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
              expandedHeight: 152,
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              title: Text(
                'عروض الأسعار',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              actions: <Widget>[
                if (_can('canExport'))
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
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _hero(),
              ),
            ),
            SliverToBoxAdapter(child: _controls()),
            SliverToBoxAdapter(child: _kpiRow()),
          ],
          body: _body(),
        ),
        floatingActionButton: _can('canAdd')
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navy,
                onPressed: _openNew,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'عرض جديد',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              )
                .animate()
                .fadeIn(delay: 250.ms)
                .scale(begin: const Offset(0.9, 0.9))
            : null,
      ),
    );
  }

  Widget _hero() {
    final masked = _can('isCostOnlyViewer');
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
            left: -35,
            top: -45,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.32),
                          ),
                        ),
                        child: const Icon(
                          Icons.description_rounded,
                          color: AppColors.gold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              masked ? 'عرض التكاليف' : 'إدارة دورة العرض',
                              style: GoogleFonts.cairo(
                                color: AppColors.goldLight,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              masked
                                  ? 'العروض الجارية وتكلفة أصنافها'
                                  : 'من المسودة حتى التحويل إلى فاتورة',
                              style: GoogleFonts.cairo(
                                color: Colors.white70,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _compactMoney(dynamic value) {
    final amount = _num(value);
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M ج';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K ج';
    return '${NumberFormat('#,##0').format(amount)} ج';
  }

  /// صف بطاقات إحصائية مستقل أسفل الهيدر — متناسق مع بقية شاشات التطبيق.
  Widget _kpiRow() {
    final masked = _can('isCostOnlyViewer');
    final cards = masked
        ? <_KpiSpec>[
            const _KpiSpec(
              icon: Icons.inventory_2_rounded,
              label: 'العروض الجارية',
              color: AppColors.gold,
            ),
            const _KpiSpec(
              icon: Icons.insert_drive_file_rounded,
              label: 'مسودة',
              color: AppColors.neutral,
            ),
          ]
        : <_KpiSpec>[
            const _KpiSpec(
              icon: Icons.account_balance_wallet_rounded,
              label: 'إجمالي القيمة',
              color: AppColors.gold,
            ),
            const _KpiSpec(
              icon: Icons.people_alt_rounded,
              label: 'العملاء',
              color: AppColors.info,
            ),
            const _KpiSpec(
              icon: Icons.trending_up_rounded,
              label: 'نسبة التحويل',
              color: AppColors.success,
            ),
            const _KpiSpec(
              icon: Icons.description_rounded,
              label: 'إجمالي العروض',
              color: AppColors.neutral,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < cards.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _kpiCard(cards[i], values[i])),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard(_KpiSpec spec, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(_isDark)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: 0.13),
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
                color: _textColor,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            spec.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: _secondaryTextColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    final quicks = <(String, String, int, IconData, Color)>[
      (
        'all',
        'الكل',
        _int(_stats['TotalCount']),
        Icons.dashboard_rounded,
        AppColors.neutral
      ),
      (
        'accepted',
        'مقبول',
        _int(_stats['AcceptedCount']),
        Icons.check_circle_rounded,
        AppColors.success
      ),
      (
        'rejected',
        'مرفوض',
        _int(_stats['RejectedCount']),
        Icons.cancel_rounded,
        AppColors.error
      ),
      (
        'converted',
        'محوّل',
        _int(_stats['ConvertedCount']),
        Icons.assignment_turned_in_rounded,
        AppColors.info
      ),
      (
        'pending',
        'انتظار',
        _int(_stats['DraftCount']) + _int(_stats['SentCount']),
        Icons.hourglass_bottom_rounded,
        AppColors.warning
      ),
      (
        'expired',
        'منتهي',
        _int(_stats['ExpiredCount']),
        Icons.timer_off_rounded,
        AppColors.errorLight
      ),
    ];
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
                  style: GoogleFonts.cairo(color: _textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'بحث بالعميل أو الهاتف أو رقم العرض',
                    hintStyle: GoogleFonts.cairo(
                      color: AppColors.textHint(_isDark),
                      fontSize: 10.5,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.goldDark),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _search = '';
                              _load();
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
                      borderSide: BorderSide(color: AppColors.divider(_isDark)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'فلاتر التاريخ والحالة',
                onPressed: _openFilters,
                icon: const Icon(Icons.tune_rounded),
              ),
              if (_hasFilters) ...<Widget>[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'مسح الفلاتر',
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded,
                      color: AppColors.error),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
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
                  const SizedBox(width: 7),
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
    return InkWell(
      onTap: () => _applyQuick(keyName),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.12)
              : AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.45)
                : AppColors.divider(_isDark),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              '$label $count',
              style: GoogleFonts.cairo(
                color: active ? color : _secondaryTextColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 92),
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
            Icon(Icons.cloud_off_rounded, size: 50, color: AppColors.error),
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
        const SizedBox(height: 80),
        const Icon(Icons.description_outlined,
            size: 70, color: AppColors.goldDark),
        const SizedBox(height: 14),
        Text(
          'لا توجد عروض أسعار مطابقة',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: _textColor,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _hasFilters
              ? 'جرّب مسح أو تعديل الفلاتر.'
              : 'ابدأ بإنشاء أول عرض سعر.',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(color: _secondaryTextColor),
        ),
      ],
    );
  }

  Widget _loadMoreButton() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: OutlinedButton.icon(
          onPressed: _loadingMore ? null : () => _load(append: true),
          icon: _loadingMore
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more_rounded),
          label: Text(
            _loadingMore ? 'جاري التحميل...' : 'تحميل المزيد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _quotationCard(Map<String, dynamic> row, int index) {
    final id = _int(row['QuotationID']);
    final status = '${row['Status'] ?? 'Draft'}';
    final converted = row['InvoiceID'] != null;
    final expired = _isExpired(row);
    final masked = _bool(row['PricesMasked']);
    final statusColor = _statusColor(converted ? 'Converted' : status);
    final date = DateTime.tryParse('${row['QuotationDate'] ?? ''}');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.12 : 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => _openDetails(id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _statusIcon(converted ? 'Converted' : status),
                        color: statusColor,
                        size: 21,
                      ),
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
                                  '${row['ReferenceNumber'] ?? 'QT-${date?.year ?? ''}-$id'}',
                                  style: AppTextStyles.titleMedium(_isDark)
                                      .copyWith(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _statusBadge(converted ? 'Converted' : status),
                              if (expired) ...<Widget>[
                                const SizedBox(width: 5),
                                _statusBadge('Expired'),
                              ],
                            ],
                          ),
                          Text(
                            date == null
                                ? ''
                                : DateFormat('yyyy/MM/dd')
                                    .format(date.toLocal()),
                            style: GoogleFonts.cairo(
                              color: _secondaryTextColor,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.gold.withValues(alpha: 0.14),
                      child: Text(
                        _initial('${row['PartyName'] ?? ''}'),
                        style: GoogleFonts.cairo(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${row['PartyName'] ?? 'عميل غير محدد'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium(_isDark)
                                .copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${row['PartyPhone'] ?? ''}',
                            style: GoogleFonts.cairo(
                              color: _secondaryTextColor,
                              fontSize: 9.5,
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
                              color: AppColors.goldDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (_can('canViewCost') && row['TotalCost'] != null)
                            Text(
                              'تكلفة ${_money(row['TotalCost'])}',
                              style: GoogleFonts.cairo(
                                color: _secondaryTextColor,
                                fontSize: 8.5,
                              ),
                            ),
                        ],
                      )
                    else if (row['TotalCost'] != null)
                      Text(
                        'تكلفة ${_money(row['TotalCost'])} ج',
                        style: GoogleFonts.cairo(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: <Widget>[
                    _infoChip(
                      Icons.inventory_2_rounded,
                      '${_int(row['ItemsCount'])} صنف',
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
                          Icons.support_agent_rounded, '${row['EmpName']}'),
                    if (converted &&
                        '${row['InvoiceReference'] ?? ''}'.isNotEmpty)
                      _infoChip(
                        Icons.receipt_long_rounded,
                        '${row['InvoiceReference']}',
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: () => _openDetails(id),
                      icon: const Icon(Icons.visibility_rounded, size: 17),
                      label: Text('عرض', style: GoogleFonts.cairo()),
                    ),
                    if (_can('canEdit') && !converted)
                      TextButton.icon(
                        onPressed: () => _openEdit(id),
                        icon: const Icon(Icons.edit_rounded, size: 17),
                        label: Text('تعديل', style: GoogleFonts.cairo()),
                      ),
                    const Spacer(),
                    const Icon(Icons.chevron_left_rounded, color: AppColors.neutral),
                  ],
                ),
              ],
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

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.goldDark, size: 13),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                color: _secondaryTextColor,
                fontSize: 8.8,
                fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        _statusLabel(status),
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'Sent' => AppColors.info,
      'Accepted' => AppColors.success,
      'Rejected' => AppColors.error,
      'Converted' => AppColors.successLight,
      'Expired' => AppColors.errorLight,
      _ => AppColors.neutral,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'Sent' => Icons.send_rounded,
      'Accepted' => Icons.check_circle_rounded,
      'Rejected' => Icons.cancel_rounded,
      'Converted' => Icons.receipt_long_rounded,
      'Expired' => Icons.timer_off_rounded,
      _ => Icons.insert_drive_file_rounded,
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
    return clean.isEmpty ? 'ع' : clean.characters.first;
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
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
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
                    Text(
                      'فلترة عروض الأسعار',
                      style: GoogleFonts.cairo(
                        color: _textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration:
                          _fieldDecoration('الحالة', Icons.flag_rounded),
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
                      label: 'من تاريخ',
                      value: from,
                      onTap: () async {
                        final picked = await _pickDate(from);
                        if (picked != null) setSheetState(() => from = picked);
                      },
                      onClear: from == null
                          ? null
                          : () => setSheetState(() => from = null),
                    ),
                    const SizedBox(height: 9),
                    _dateTile(
                      label: 'إلى تاريخ',
                      value: to,
                      onTap: () async {
                        final picked = await _pickDate(to);
                        if (picked != null) setSheetState(() => to = picked);
                      },
                      onClear: to == null
                          ? null
                          : () => setSheetState(() => to = null),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setSheetState(() {
                              from = null;
                              to = null;
                              status = null;
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
                            onPressed: () => Navigator.pop(sheetContext, true),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              'تطبيق',
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
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: AppColors.divider(_isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
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
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.divider(_isDark)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.calendar_month_rounded, color: AppColors.goldDark),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                value == null ? label : DateFormat('yyyy/MM/dd').format(value),
                style: GoogleFonts.cairo(
                  color: value == null ? _secondaryTextColor : _textColor,
                  fontSize: 12,
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
