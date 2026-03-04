import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/dashboard_model.dart';
import '../../services/dashboard_service.dart';
import '../../services/theme_service.dart';
import '../../../services/app_colors.dart';
import 'widgets/crm_period_chips.dart';
import 'widgets/crm_filter_bar.dart';
import 'widgets/crm_story_cards.dart';
import 'widgets/crm_funnel_chart.dart';
import 'widgets/crm_trend_chart.dart';
import 'widgets/crm_sources_chart.dart';
import 'widgets/crm_ad_types.dart';
import 'widgets/crm_categories.dart';
import 'widgets/crm_tasks_summary.dart';
import 'widgets/crm_interactions.dart';
import 'widgets/crm_leaderboard.dart';
import 'widgets/crm_lost_reasons.dart';
import 'widgets/crm_follow_ups.dart';
import 'widgets/crm_section_header.dart';
import 'widgets/crm_shimmer_loading.dart';
import '../../services/crm_pdf_generator.dart';
import 'package:share_plus/share_plus.dart';

class CrmDashboardScreen extends StatefulWidget {
  final int userId;
  final String username;

  const CrmDashboardScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<CrmDashboardScreen> createState() => _CrmDashboardScreenState();
}

class _CrmDashboardScreenState extends State<CrmDashboardScreen> {
  final DashboardService _service = DashboardService();
  final ScrollController _scrollController = ScrollController();

  // === State ===
  DashboardData? _data;
  bool _loading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showScrollToTop = false;
  DateTime _lastUpdate = DateTime.now();

  // === Filters ===
  String _selectedPeriod = 'month';
  String? _dateFrom;
  String? _dateTo;
  int? _selectedEmployeeId;
  int? _selectedSourceId;
  int? _selectedStageId;
  int? _selectedAdTypeId;

  // === Expandable Sections ===
  bool _isTrendExpanded = false;
  bool _isSourcesExpanded = false;
  bool _isAdTypesExpanded = false;
  bool _isCategoriesExpanded = false;
  bool _isTasksExpanded = false;
  bool _isInteractionsExpanded = false;
  bool _isLeaderboardExpanded = false;
  bool _isLostReasonsExpanded = false;
  bool _isFollowUpsExpanded = false;
  bool _isFiltersExpanded = true;

  // === Search ===
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSavedFilters();
    _fetchData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // === Scroll listener ===
  void _onScroll() {
    final show = _scrollController.offset > 300;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  // === حفظ واسترجاع الفلاتر ===
  Future<void> _loadSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPeriod = prefs.getString('crm_period') ?? 'month';
      _selectedEmployeeId = prefs.getInt('crm_employeeId');
      _selectedSourceId = prefs.getInt('crm_sourceId');
      _selectedStageId = prefs.getInt('crm_stageId');
      _selectedAdTypeId = prefs.getInt('crm_adTypeId');
      // حالة الطي
      _isTrendExpanded = prefs.getBool('crm_trend_expanded') ?? false;
      _isSourcesExpanded = prefs.getBool('crm_sources_expanded') ?? false;
      _isAdTypesExpanded = prefs.getBool('crm_adtypes_expanded') ?? false;
      _isCategoriesExpanded = prefs.getBool('crm_categories_expanded') ?? false;
      _isTasksExpanded = prefs.getBool('crm_tasks_expanded') ?? false;
      _isInteractionsExpanded = prefs.getBool('crm_interactions_expanded') ?? false;
      _isLeaderboardExpanded = prefs.getBool('crm_leaderboard_expanded') ?? false;
      _isLostReasonsExpanded = prefs.getBool('crm_lostreasons_expanded') ?? false;
      _isFollowUpsExpanded = prefs.getBool('crm_followups_expanded') ?? false;
      _isFiltersExpanded = prefs.getBool('crm_filters_expanded') ?? true;
    });
    _calculateDates();
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_period', _selectedPeriod);
    if (_selectedEmployeeId != null) {
      await prefs.setInt('crm_employeeId', _selectedEmployeeId!);
    } else {
      await prefs.remove('crm_employeeId');
    }
    if (_selectedSourceId != null) {
      await prefs.setInt('crm_sourceId', _selectedSourceId!);
    } else {
      await prefs.remove('crm_sourceId');
    }
    if (_selectedStageId != null) {
      await prefs.setInt('crm_stageId', _selectedStageId!);
    } else {
      await prefs.remove('crm_stageId');
    }
    if (_selectedAdTypeId != null) {
      await prefs.setInt('crm_adTypeId', _selectedAdTypeId!);
    } else {
      await prefs.remove('crm_adTypeId');
    }
    // حفظ حالة الطي
    await prefs.setBool('crm_trend_expanded', _isTrendExpanded);
    await prefs.setBool('crm_sources_expanded', _isSourcesExpanded);
    await prefs.setBool('crm_adtypes_expanded', _isAdTypesExpanded);
    await prefs.setBool('crm_categories_expanded', _isCategoriesExpanded);
    await prefs.setBool('crm_tasks_expanded', _isTasksExpanded);
    await prefs.setBool('crm_interactions_expanded', _isInteractionsExpanded);
    await prefs.setBool('crm_leaderboard_expanded', _isLeaderboardExpanded);
    await prefs.setBool('crm_lostreasons_expanded', _isLostReasonsExpanded);
    await prefs.setBool('crm_followups_expanded', _isFollowUpsExpanded);
    await prefs.setBool('crm_filters_expanded', _isFiltersExpanded);
  }

  // === حساب التواريخ من الفترة المختارة ===
  void _calculateDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'today':
        _dateFrom = _formatDate(now);
        _dateTo = _formatDate(now);
        break;
      case 'week':
        _dateFrom = _formatDate(now.subtract(Duration(days: now.weekday - 1)));
        _dateTo = _formatDate(now);
        break;
      case 'month':
        _dateFrom = _formatDate(DateTime(now.year, now.month, 1));
        _dateTo = _formatDate(now);
        break;
      case '3months':
        _dateFrom = _formatDate(DateTime(now.year, now.month - 2, 1));
        _dateTo = _formatDate(now);
        break;
      case '6months':
        _dateFrom = _formatDate(DateTime(now.year, now.month - 5, 1));
        _dateTo = _formatDate(now);
        break;
      case 'year':
        _dateFrom = _formatDate(DateTime(now.year, 1, 1));
        _dateTo = _formatDate(now);
        break;
      case 'custom':
        // التواريخ تتحدد من الـ date picker
        break;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // === جلب البيانات ===
  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final data = await _service.getDashboardData(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        employeeId: _selectedEmployeeId,
        sourceId: _selectedSourceId,
        stageId: _selectedStageId,
        adTypeId: _selectedAdTypeId,
      );

      setState(() {
        _data = data;
        _loading = false;
        _lastUpdate = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _hasError = true;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // === تغيير الفترة ===
  void _onPeriodChanged(String period) {
    setState(() => _selectedPeriod = period);
    _calculateDates();
    _saveFilters();
    _fetchData();
  }

  // === تغيير الفلاتر ===
  void _onFiltersChanged({
    int? employeeId,
    int? sourceId,
    int? stageId,
    int? adTypeId,
    bool clear = false,
  }) {
    setState(() {
      if (clear) {
        _selectedEmployeeId = null;
        _selectedSourceId = null;
        _selectedStageId = null;
        _selectedAdTypeId = null;
      } else {
        _selectedEmployeeId = employeeId;
        _selectedSourceId = sourceId;
        _selectedStageId = stageId;
        _selectedAdTypeId = adTypeId;
      }
    });
    _saveFilters();
    _fetchData();
  }

  // === تاريخ مخصص ===
  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(
              start: DateTime.parse(_dateFrom!),
              end: DateTime.parse(_dateTo!),
            )
          : null,
      builder: (context, child) {
        final isDark = ThemeService().isDarkMode;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: isDark ? Brightness.dark : Brightness.light,
              primary: AppColors.gold,
              onPrimary: Colors.black,
              secondary: AppColors.gold,
              onSecondary: Colors.black,
              error: Colors.red,
              onError: Colors.white,
              surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              onSurface: isDark ? Colors.white : AppColors.navy,
              background: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              onBackground: isDark ? Colors.white : AppColors.navy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _dateFrom = _formatDate(picked.start);
        _dateTo = _formatDate(picked.end);
      });
      _saveFilters();
      _fetchData();
    }
  }

  // === عدد الفلاتر النشطة ===
  int get _activeFiltersCount {
    int count = 0;
    if (_selectedEmployeeId != null) count++;
    if (_selectedSourceId != null) count++;
    if (_selectedStageId != null) count++;
    if (_selectedAdTypeId != null) count++;
    return count;
  }

  // === الرجوع لأعلى ===
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.gold,
              onPressed: _scrollToTop,
              child: const Icon(Icons.keyboard_arrow_up, color: Colors.black),
            ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.5, 0.5))
          : null,
      body: _loading
          ? _buildLoading(isDark)
          : _hasError
              ? _buildError(isDark)
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  color: AppColors.gold,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _buildAppBar(isDark),
                                            SliverToBoxAdapter(
                        child: Column(
                          children: [
                            // 1. شريط الفترات
                            CrmPeriodChips(
                              selectedPeriod: _selectedPeriod,
                              onPeriodChanged: _onPeriodChanged,
                              onCustomDatePick: _pickCustomDateRange,
                              dateFrom: _dateFrom,
                              dateTo: _dateTo,
                              isDark: isDark,
                            ),

                            // 2. شريط الفلاتر النشطة (قابل للطي)
                            if (_activeFiltersCount > 0 && _data != null)
                              ExpansionTile(
                                initiallyExpanded: _isFiltersExpanded,
                                onExpansionChanged: (expanded) => setState(() => _isFiltersExpanded = expanded),
                                title: Text(
                                  'الفلاتر النشطة ($_activeFiltersCount)',
                                  style: GoogleFonts.cairo(
                                    color: AppColors.text(isDark),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                children: [
                                  CrmFilterBar(
                                    filterLists: _data!.filterLists,
                                    selectedEmployeeId: _selectedEmployeeId,
                                    selectedSourceId: _selectedSourceId,
                                    selectedStageId: _selectedStageId,
                                    selectedAdTypeId: _selectedAdTypeId,
                                    onClear: () => _onFiltersChanged(clear: true),
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                            // 2.5. شريط البحث
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: TextField(
                                style: GoogleFonts.cairo(color: AppColors.text(isDark), fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'ابحث في البيانات...',
                                  hintStyle: GoogleFonts.cairo(color: AppColors.textSecondary(isDark), fontSize: 14),
                                  prefixIcon: Icon(Icons.search, color: AppColors.gold),
                                  filled: true,
                                  fillColor: AppColors.surface(isDark),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onChanged: (value) => setState(() => _searchQuery = value),
                              ),
                            ),

                            // 3. Story Cards
                            if (_data != null)
                              CrmStoryCards(
                                kpi: _data!.kpi,
                                period: _data!.period,
                                isDark: isDark,
                              ),

                            _buildSectionDivider(isDark),

                            // 4. قمع المبيعات
                            if (_data != null && _data!.funnel.isNotEmpty)
                              CrmFunnelChart(
                                funnel: _data!.funnel,
                                isDark: isDark,
                              ),

                            _buildSectionDivider(isDark),

                            // 5. الترند (قابل للطي)
                            if (_data != null && _data!.trend.data.isNotEmpty)
                              ExpansionTile(
                                initiallyExpanded: _isTrendExpanded,
                                onExpansionChanged: (expanded) => setState(() => _isTrendExpanded = expanded),
                                title: CrmSectionHeader(
                                  title: 'الترند الزمني',
                                  icon: Icons.trending_up,
                                  isDark: isDark,
                                ),
                                children: [
                                  CrmTrendChart(
                                    trend: _data!.trend,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                            _buildSectionDivider(isDark),

                            // 6. تحليل المصادر (قابل للطي)
                            if (_data != null && _data!.sources.isNotEmpty)
                              ExpansionTile(
                                initiallyExpanded: _isSourcesExpanded,
                                onExpansionChanged: (expanded) => setState(() => _isSourcesExpanded = expanded),
                                title: CrmSectionHeader(
                                  title: 'تحليل المصادر',
                                  icon: Icons.source,
                                  isDark: isDark,
                                ),
                                children: [
                                  CrmSourcesChart(
                                    sources: _data!.sources,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                            _buildSectionDivider(isDark),

                            // 7. أنواع الإعلانات (قابل للطي)
                            if (_data != null && _data!.adTypes.isNotEmpty)
                              ExpansionTile(
                                initiallyExpanded: _isAdTypesExpanded,
                                onExpansionChanged: (expanded) => setState(() => _isAdTypesExpanded = expanded),
                                title: CrmSectionHeader(
                                  title: 'أنواع الإعلانات',
                                  icon: Icons.ad_units,
                                  isDark: isDark,
                                ),
                                children: [
                                  CrmAdTypes(
                                    adTypes: _data!.adTypes,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                            _buildSectionDivider(isDark),

                            // 8. تصنيفات الاهتمام (قابل للطي)
                            if (_data != null && _data!.categories.isNotEmpty)
                              ExpansionTile(
                                initiallyExpanded: _isCategoriesExpanded,
                                onExpansionChanged: (expanded) => setState(() => _isCategoriesExpanded = expanded),
                                title: CrmSectionHeader(
                                  title: 'تصنيفات الاهتمام',
                                  icon: Icons.category,
                                  isDark: isDark,
                                ),
                                children: [
                                  CrmCategories(
                                    categories: _data!.categories,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                            _buildSectionDivider(isDark),

                            // 9. ملخص المهام (قابل للطي)
                            if (_data != null)
                              ExpansionTile(
                                initiallyExpanded: _isTasksExpanded,
                                onExpansionChanged: (expanded) => setState(() => _isTasksExpanded = expanded),
                                title: CrmSectionHeader(
                                  title: 'ملخص المهام',
                                  icon: Icons.task,
                                  isDark: isDark,
                                ),
                                children: [
                                  CrmTasksSummary(
                                    tasks: _data!.tasks,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                            _buildSectionDivider(isDark),

                            // 10. تحليل التفاعلات (قابل للطي)
                            if (_data != null)
                              ExpansionTile(
                                initiallyExpanded: _isInteractionsExpanded,
                                onExpansionChanged: (expanded) => setState(() => _isInteractionsExpanded = expanded),
                                title: CrmSectionHeader(
                                  title: 'تحليل التفاعلات',
                                  icon: Icons.touch_app,
                                  isDark: isDark,
                                ),
                                children: [
                                  CrmInteractions(
                                    interactions: _data!.interactions,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                            _buildSectionDivider(isDark),

                            // 11. لوحة الشرف (قابل للطي)
                            if (_data != null && _data!.leaderboard.isNotEmpty)
                              ExpansionTile(
                                initiallyExpanded: _isLeaderboardExpanded,
                                onExpansionChanged: (expanded) => setState(() => _isLeaderboardExpanded = expanded),
                                title: CrmSectionHeader(
                                  title: 'لوحة الشرف',
                                  icon: Icons.leaderboard,
                                  isDark: isDark,
                                ),
                                children: [
                                  CrmLeaderboard(
                                    leaderboard: _data!.leaderboard,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                            _buildSectionDivider(isDark),

                            // 12. أسباب الخسارة (قابل للطي)
                            if (_data != null && _data!.lostReasons.isNotEmpty)
                              ExpansionTile(
                                initiallyExpanded: _isLostReasonsExpanded,
                                onExpansionChanged: (expanded) => setState(() => _isLostReasonsExpanded = expanded),
                                title: CrmSectionHeader(
                                  title: 'أسباب الخسارة',
                                  icon: Icons.cancel,
                                  isDark: isDark,
                                ),
                                children: [
                                  CrmLostReasons(
                                    lostReasons: _data!.lostReasons,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                            _buildSectionDivider(isDark),

                            // 13. المتابعات + الراكدة (قابل للطي)
                            if (_data != null)
                              ExpansionTile(
                                initiallyExpanded: _isFollowUpsExpanded,
                                onExpansionChanged: (expanded) => setState(() => _isFollowUpsExpanded = expanded),
                                title: CrmSectionHeader(
                                  title: 'المتابعات والراكدة',
                                  icon: Icons.follow_the_signs,
                                  isDark: isDark,
                                ),
                                children: [
                                  CrmFollowUps(
                                    followUps: _data!.followUps,
                                    stagnant: _data!.stagnant,
                                    isDark: isDark,
                                  ),
                                ],
                              ),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // === App Bar ===
  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 70,
      floating: true,
      pinned: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.text(isDark),
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'لوحة تحكم المبيعات',
            style: GoogleFonts.cairo(
              color: AppColors.text(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'آخر تحديث: ${_getLastUpdateText()}',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary(isDark),
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
              // زرار الإجراءات (مشاركة وطباعة)
        if (_data != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.share_rounded, color: AppColors.gold),
            tooltip: 'تصدير ومشاركة',
            onSelected: (value) {
              if (value == 'print') {
                _printPdfReport(); // طباعة
              } else if (value == 'share_pdf') {
                _sharePdfReport(); // مشاركة PDF
              } else if (value == 'whatsapp') {
                _shareTextSummary(); // واتساب
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'whatsapp',
                child: Row(
                  children: [
                    const Icon(Icons.chat, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text('ملخص واتساب', style: GoogleFonts.cairo()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share_pdf',
                child: Row(
                  children: [
                    const Icon(Icons.share, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text('مشاركة PDF', style: GoogleFonts.cairo()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    const Icon(Icons.print, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text('طباعة / معاينة', style: GoogleFonts.cairo()),
                  ],
                ),
              ),
            ],
          ),
        // عدد الفلاتر النشطة
        if (_activeFiltersCount > 0)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_activeFiltersCount',
              style: GoogleFonts.cairo(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        // زرار الفلتر
        IconButton(
          icon: Icon(
            Icons.tune_rounded,
            color: _activeFiltersCount > 0 ? AppColors.gold : AppColors.textSecondary(isDark),
          ),
          onPressed: () => _showFilterSheet(isDark),
        ),
        // زرار التحديث
        IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            color: AppColors.textSecondary(isDark),
          ),
          onPressed: _fetchData,
        ),
      ],
    );
  }

  // === Bottom Sheet للفلاتر ===
  void _showFilterSheet(bool isDark) {
    if (_data == null) return;

    int? tempEmployee = _selectedEmployeeId;
    int? tempSource = _selectedSourceId;
    int? tempStage = _selectedStageId;
    int? tempAdType = _selectedAdTypeId;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint(isDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, color: AppColors.gold, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'الفلاتر',
                        style: GoogleFonts.cairo(
                          color: AppColors.text(isDark),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 👤 الموظف
                  _buildFilterDropdown(
                    isDark: isDark,
                    label: '👤 الموظف',
                    value: tempEmployee,
                    items: _data!.filterLists.employees
                        .map((e) => DropdownMenuItem<int>(
                              value: e.employeeId,
                              child: Text(e.fullName,
                                  style: GoogleFonts.cairo(
                                      color: AppColors.text(isDark))),
                            ))
                        .toList(),
                    onChanged: (v) => setSheetState(() => tempEmployee = v),
                  ),
                  const SizedBox(height: 12),

                  // 📱 المصدر
                  _buildFilterDropdown(
                    isDark: isDark,
                    label: '📱 المصدر',
                    value: tempSource,
                    items: _data!.filterLists.sources
                        .map((e) => DropdownMenuItem<int>(
                              value: e.sourceId,
                              child: Text(e.name,
                                  style: GoogleFonts.cairo(
                                      color: AppColors.text(isDark))),
                            ))
                        .toList(),
                    onChanged: (v) => setSheetState(() => tempSource = v),
                  ),
                  const SizedBox(height: 12),

                  // 📊 المرحلة
                  _buildFilterDropdown(
                    isDark: isDark,
                    label: '📊 المرحلة',
                    value: tempStage,
                    items: _data!.filterLists.stages
                        .map((e) => DropdownMenuItem<int>(
                              value: e.stageId,
                              child: Text(e.name,
                                  style: GoogleFonts.cairo(
                                      color: AppColors.text(isDark))),
                            ))
                        .toList(),
                    onChanged: (v) => setSheetState(() => tempStage = v),
                  ),
                  const SizedBox(height: 12),

                  // 📢 الحملة الإعلانية
                  _buildFilterDropdown(
                    isDark: isDark,
                    label: '📢 الحملة الإعلانية',
                    value: tempAdType,
                    items: _data!.filterLists.adTypes
                        .map((e) => DropdownMenuItem<int>(
                              value: e.adTypeId,
                              child: Text(e.name,
                                  style: GoogleFonts.cairo(
                                      color: AppColors.text(isDark))),
                            ))
                        .toList(),
                    onChanged: (v) => setSheetState(() => tempAdType = v),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _onFiltersChanged(clear: true);
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text('إعادة تعيين',
                              style: GoogleFonts.cairo()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary(isDark),
                            side: BorderSide(
                                color: AppColors.divider(isDark)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _onFiltersChanged(
                              employeeId: tempEmployee,
                              sourceId: tempSource,
                              stageId: tempStage,
                              adTypeId: tempAdType,
                            );
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: Text('تطبيق',
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // === Dropdown Builder ===
  Widget _buildFilterDropdown({
    required bool isDark,
    required String label,
    required int? value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            color: AppColors.textSecondary(isDark),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.inputFill(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider(isDark)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              hint: Text(
                'الكل',
                style: GoogleFonts.cairo(
                  color: AppColors.textHint(isDark),
                ),
              ),
              isExpanded: true,
              dropdownColor:
                  isDark ? AppColors.darkCard : AppColors.lightCard,
              icon: Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary(isDark)),
              items: [
                DropdownMenuItem<int>(
                  value: null,
                  child: Text('الكل',
                      style: GoogleFonts.cairo(
                          color: AppColors.textHint(isDark))),
                ),
                ...items,
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // === Loading ===
  Widget _buildLoading(bool isDark) {
    return CrmShimmerLoading(isDark: isDark);
  }

  // === Error ===
  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 64),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: GoogleFonts.cairo(
                color: AppColors.text(isDark),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: GoogleFonts.cairo(
                color: AppColors.textSecondary(isDark),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh),
              label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === Last Update Text ===
  String _getLastUpdateText() {
    final diff = DateTime.now().difference(_lastUpdate);
    if (diff.inSeconds < 30) return 'الآن';
    if (diff.inMinutes < 1) return '${diff.inSeconds} ث';
    if (diff.inMinutes < 60) return '${diff.inMinutes} د';
    if (diff.inHours < 24) return '${diff.inHours} س';
    return '${diff.inDays} ي';
  }

    // === فاصل بين الأقسام ===
  Widget _buildSectionDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.divider(isDark).withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.diamond_outlined,
              size: 8,
              color: AppColors.gold.withOpacity(0.4),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.divider(isDark).withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

    String _getPeriodName() {
    switch (_selectedPeriod) {
      case 'today': return 'اليوم';
      case 'week': return 'هذا الأسبوع';
      case 'month': return 'هذا الشهر';
      case '3months': return 'آخر 3 شهور';
      case '6months': return 'آخر 6 شهور';
      case 'year': return 'هذا العام';
      case 'custom': 
        if (_dateFrom != null && _dateTo != null) {
          return '$_dateFrom إلى $_dateTo';
        }
        return 'فترة مخصصة';
      default: return '';
    }
  }
  
    // === 1. طباعة التقرير ===
  void _printPdfReport() {
    _createPdfGenerator().generateAndPrint();
  }

  // === 2. مشاركة PDF ===
  void _sharePdfReport() {
    _createPdfGenerator().generateAndShare();
  }

  // === Helper لإنشاء الـ Generator (عشان منكررش الكود) ===
  CrmPdfGenerator _createPdfGenerator() {
    String? employeeName;
    if (_selectedEmployeeId != null) {
      final emp = _data!.filterLists.employees.firstWhere(
          (e) => e.employeeId == _selectedEmployeeId,
          orElse: () => FilterEmployee(employeeId: 0, fullName: ''));
      if (emp.fullName.isNotEmpty) employeeName = emp.fullName;
    }

    String? sourceName;
    if (_selectedSourceId != null) {
      final src = _data!.filterLists.sources.firstWhere(
          (e) => e.sourceId == _selectedSourceId,
          orElse: () => FilterSource(sourceId: 0, name: ''));
      if (src.name.isNotEmpty) sourceName = src.name;
    }

    return CrmPdfGenerator(
      data: _data!,
      username: widget.username,
      periodName: _getPeriodName(),
      employeeName: employeeName,
      sourceName: sourceName,
    );
  }

  // === 3. مشاركة واتساب (تم إضافة الفلاتر) ===
  void _shareTextSummary() {
    if (_data == null) return;
    final kpi = _data!.kpi;

    // تجهيز أسماء الفلاتر
    String filtersText = '';
    if (_selectedEmployeeId != null) {
      final emp = _data!.filterLists.employees.firstWhere(
          (e) => e.employeeId == _selectedEmployeeId,
          orElse: () => FilterEmployee(employeeId: 0, fullName: ''));
      if (emp.fullName.isNotEmpty) filtersText += '\n👤 الموظف: ${emp.fullName}';
    }
    if (_selectedSourceId != null) {
      final src = _data!.filterLists.sources.firstWhere(
          (e) => e.sourceId == _selectedSourceId,
          orElse: () => FilterSource(sourceId: 0, name: ''));
      if (src.name.isNotEmpty) filtersText += '\n📱 المصدر: ${src.name}';
    }

    final String summary = '''
*📊 ملخص مؤشرات CRM - COCOBOLO*
📅 الفترة: ${_getPeriodName()}$filtersText

*💰 الموقف المالي:*
• الإيراد الفعلي: ${_formatCurrency(kpi.currentActualRevenue)} ج.م
• الإيراد المتوقع: ${_formatCurrency(kpi.currentExpectedRevenue)} ج.م
• المحصل (كاش): ${_formatCurrency(kpi.currentCollected)} ج.م

*📈 الأداء البيعي:*
• فرص جديدة: ${kpi.currentOpportunities}
• صفقات ناجحة: ${kpi.currentWon}
• نسبة التحويل: ${kpi.currentConversion}%

*⚠️ تنبيهات هامة:*
• مهام متأخرة: ${kpi.overdueTasks}
• فرص راكدة: ${kpi.stagnantOpportunities}
• متابعات فائتة: ${kpi.overdueFollowUps}

_تم الاستخراج بواسطة: ${widget.username}_
''';

    Share.share(summary);
  }
  
    String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }
}