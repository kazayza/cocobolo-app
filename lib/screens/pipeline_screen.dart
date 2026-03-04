import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/pipeline_service.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import 'stage_clients_screen.dart';

class PipelineScreen extends StatefulWidget {
  final int userId;
  final String username;

  const PipelineScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> {
  // ===================================
  // 📦 المتغيرات
  // ===================================
  Map<String, dynamic>? _pipelineData;
  List<dynamic> _employees = [];
  List<dynamic> _sources = [];
  List<dynamic> _adTypes = [];
  bool _isLoading = true;
  bool _isFilterVisible = false;
  bool get _isDark => ThemeService().isDarkMode;

  // الفلاتر
  int? _selectedEmployeeId;
  int? _selectedSourceId;
  int? _selectedAdTypeId;
  DateTimeRange? _selectedDateRange;

  bool get _hasActiveFilters =>
      _selectedEmployeeId != null ||
      _selectedSourceId != null ||
      _selectedAdTypeId != null ||
      _selectedDateRange != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ===================================
  // 📡 جلب البيانات
  // ===================================
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        PipelineService.getPipelineSummary(
          employeeId: _selectedEmployeeId,
          sourceId: _selectedSourceId,
          adTypeId: _selectedAdTypeId,
          dateFrom: _selectedDateRange != null
              ? DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)
              : null,
          dateTo: _selectedDateRange != null
              ? DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)
              : null,
        ),
        PipelineService.getEmployees(),
        PipelineService.getSources(),
        PipelineService.getAdTypes(),
      ]);

      setState(() {
        _pipelineData = results[0] as Map<String, dynamic>?;
        _employees = results[1] as List<dynamic>;
        _sources = results[2] as List<dynamic>;
        _adTypes = results[3] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ خطأ: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  void _resetFilters() {
    setState(() {
      _selectedEmployeeId = null;
      _selectedSourceId = null;
      _selectedAdTypeId = null;
      _selectedDateRange = null;
    });
    _loadData();
  }

  // ===================================
  // 🎨 واجهة المستخدم
  // ===================================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: _buildAppBar(),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.gold),
                    const SizedBox(height: 16),
                    Text(
                      'جاري تحميل البيانات...',
                      style: GoogleFonts.cairo(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : _pipelineData == null
                ? _buildErrorView()
                : RefreshIndicator(
                    color: AppColors.gold,
                    onRefresh: _refresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // الفلاتر
                          if (_isFilterVisible)
                            _buildFilters()
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: -0.1, end: 0),

                          // شريط الفلاتر النشطة
                          if (_hasActiveFilters && !_isFilterVisible)
                            _buildActiveFiltersBar()
                                .animate()
                                .fadeIn(duration: 200.ms),

                          // كروت الملخص
                          _buildSummaryCards()
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 20),

                          // نسبة التحويل
                          _buildConversionCard()
                              .animate()
                              .fadeIn(duration: 500.ms, delay: 100.ms)
                              .slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 20),

                          // مراحل البيع
                          _buildPipelineStages(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // ===================================
  // 🔝 AppBar
  // ===================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _isDark ? AppColors.navy : Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(
        color: _isDark ? Colors.white : AppColors.navy,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_rounded, color: AppColors.gold, size: 24),
          const SizedBox(width: 8),
          Text(
            'مراحل البيع',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: _isDark ? Colors.white : AppColors.navy,
            ),
          ),
        ],
      ),
      actions: [
        // زرار الفلتر
        IconButton(
          icon: Badge(
            isLabelVisible: _hasActiveFilters,
            backgroundColor: AppColors.gold,
            label: Text(
              '${[
                _selectedEmployeeId,
                _selectedSourceId,
                _selectedAdTypeId,
                _selectedDateRange
              ].where((e) => e != null).length}',
              style: const TextStyle(fontSize: 10),
            ),
            child: Icon(
              _isFilterVisible ? Icons.tune_rounded : Icons.tune_outlined,
              color: _hasActiveFilters
                  ? AppColors.gold
                  : (_isDark ? Colors.white : AppColors.navy),
            ),
          ),
          onPressed: () {
            setState(() => _isFilterVisible = !_isFilterVisible);
          },
        ),
        // زرار التحديث
        IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            color: _isDark ? Colors.white : AppColors.navy,
          ),
          onPressed: _refresh,
        ),
      ],
    );
  }

  // ===================================
  // 🏷️ شريط الفلاتر النشطة
  // ===================================
  Widget _buildActiveFiltersBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(_isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list_rounded, color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedEmployeeId != null)
                    _buildFilterChip(
                      _employees.firstWhere(
                        (e) => e['EmployeeID'] == _selectedEmployeeId,
                        orElse: () => {'FullName': 'موظف'},
                      )['FullName'],
                      () {
                        setState(() => _selectedEmployeeId = null);
                        _loadData();
                      },
                    ),
                  if (_selectedSourceId != null)
                    _buildFilterChip(
                      _sources.firstWhere(
                        (s) => s['SourceID'] == _selectedSourceId,
                        orElse: () => {'SourceNameAr': 'مصدر'},
                      )['SourceNameAr'] ?? 'مصدر',
                      () {
                        setState(() => _selectedSourceId = null);
                        _loadData();
                      },
                    ),
                  if (_selectedAdTypeId != null)
                    _buildFilterChip(
                      _adTypes.firstWhere(
                        (a) => a['AdTypeID'] == _selectedAdTypeId,
                        orElse: () => {'AdTypeNameAr': 'إعلان'},
                      )['AdTypeNameAr'] ?? 'إعلان',
                      () {
                        setState(() => _selectedAdTypeId = null);
                        _loadData();
                      },
                    ),
                  if (_selectedDateRange != null)
                    _buildFilterChip(
                      '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                      () {
                        setState(() => _selectedDateRange = null);
                        _loadData();
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _resetFilters,
            child: Text(
              'مسح الكل',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(_isDark ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.text(_isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: AppColors.textSecondary(_isDark)),
          ),
        ],
      ),
    );
  }

  // ===================================
  // 🔽 الفلاتر
  // ===================================
  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                'الفلاتر',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.text(_isDark),
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: Icon(Icons.restart_alt, size: 18, color: AppColors.gold),
                  label: Text(
                    'إعادة تعيين',
                    style: GoogleFonts.cairo(fontSize: 12, color: AppColors.gold),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // فلتر الموظف
          _buildFilterDropdown<int>(
            label: 'الموظف',
            icon: Icons.person_outline,
            value: _selectedEmployeeId,
            items: [
              DropdownMenuItem<int>(
                value: null,
                child: Text('الكل', style: GoogleFonts.cairo()),
              ),
              ..._employees.map((emp) => DropdownMenuItem<int>(
                    value: emp['EmployeeID'],
                    child: Text(emp['FullName'] ?? '', style: GoogleFonts.cairo()),
                  )),
            ],
            onChanged: (value) {
              setState(() => _selectedEmployeeId = value);
              _loadData();
            },
          ),

          const SizedBox(height: 12),

          // فلتر المصدر ونوع الإعلان في صف واحد
          Row(
            children: [
              // فلتر المصدر
              Expanded(
                child: _buildFilterDropdown<int>(
                  label: 'المصدر',
                  icon: Icons.source_outlined,
                  value: _selectedSourceId,
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text('الكل', style: GoogleFonts.cairo()),
                    ),
                    ..._sources.map((s) => DropdownMenuItem<int>(
                          value: s['SourceID'],
                          child: Text(
                            s['SourceNameAr'] ?? s['SourceName'] ?? '',
                            style: GoogleFonts.cairo(fontSize: 13),
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedSourceId = value);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 10),
              // فلتر نوع الإعلان
              Expanded(
                child: _buildFilterDropdown<int>(
                  label: 'الإعلان',
                  icon: Icons.campaign_outlined,
                  value: _selectedAdTypeId,
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text('الكل', style: GoogleFonts.cairo()),
                    ),
                    ..._adTypes.map((a) => DropdownMenuItem<int>(
                          value: a['AdTypeID'],
                          child: Text(
                            a['AdTypeNameAr'] ?? a['AdTypeName'] ?? '',
                            style: GoogleFonts.cairo(fontSize: 13),
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedAdTypeId = value);
                    _loadData();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // فلتر التاريخ
          InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialDateRange: _selectedDateRange,
                locale: const Locale('ar'),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppColors.gold,
                        onPrimary: AppColors.navy,
                        surface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _selectedDateRange = picked);
                _loadData();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.inputFill(_isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider(_isDark)),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range_rounded, color: AppColors.gold, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDateRange != null
                        ? '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}'
                        : 'اختر الفترة',
                    style: GoogleFonts.cairo(
                      color: _selectedDateRange != null
                          ? AppColors.text(_isDark)
                          : AppColors.textHint(_isDark),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedDateRange != null)
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedDateRange = null);
                        _loadData();
                      },
                      child: Icon(Icons.close, size: 18, color: AppColors.textHint(_isDark)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: AppColors.card(_isDark),
      style: GoogleFonts.cairo(
        color: AppColors.text(_isDark),
        fontSize: 14,
      ),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary(_isDark)),
        prefixIcon: Icon(icon, color: AppColors.gold, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider(_isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider(_isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gold, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: AppColors.inputFill(_isDark),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  // ===================================
  // 📊 كروت الملخص العلوي (2×2)
  // ===================================
  Widget _buildSummaryCards() {
    final totals = _pipelineData!['totals'] ?? {};
    final totalOpps = totals['TotalOpportunities'] ?? 0;
    final wonCount = totals['WonCount'] ?? 0;
    final wonValue = (totals['WonValue'] ?? 0).toDouble();
    final lostCount = totals['LostCount'] ?? 0;
    final overdueCount = totals['OverdueCount'] ?? 0;
    final todayFollowUps = totals['TodayFollowUps'] ?? 0;

    // الفرص النشطة = الإجمالي - المكسوب - الخسران
    final activeCount = totalOpps - wonCount - lostCount;

    return Column(
      children: [
        // الصف الأول
        Row(
          children: [
            _buildSummaryCard(
              icon: Icons.people_alt_rounded,
              label: 'إجمالي الفرص',
              value: '$totalOpps',
              color: AppColors.gold,
            ),
            const SizedBox(width: 10),
            _buildSummaryCard(
              icon: Icons.rocket_launch_rounded,
              label: 'فرص نشطة',
              value: '$activeCount',
              color: const Color(0xFF3498DB),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // الصف الثاني
        Row(
          children: [
            _buildSummaryCard(
              icon: Icons.emoji_events_rounded,
              label: 'مكسوب',
              value: '$wonCount',
              subtitle: wonValue > 0
                  ? '${NumberFormat('#,###').format(wonValue)} ج.م'
                  : null,
              color: const Color(0xFF27AE60),
            ),
            const SizedBox(width: 10),
            _buildSummaryCard(
              icon: Icons.schedule_rounded,
              label: 'متأخر / اليوم',
              value: '$overdueCount / $todayFollowUps',
              color: overdueCount > 0
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFFFF9800),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card(_isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(_isDark ? 0.3 : 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // الأيقونة
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(_isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            // النص
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(_isDark),
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.textSecondary(_isDark),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.bold,
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

  // ===================================
  // 📈 كارت نسبة التحويل
  // ===================================
  Widget _buildConversionCard() {
    final totals = _pipelineData!['totals'] ?? {};
    final conversionRate = (totals['ConversionRate'] ?? 0).toDouble();
    final totalValue = (totals['TotalExpectedValue'] ?? 0).toDouble();

    Color rateColor;
    String rateLabel;
    IconData rateIcon;

    if (conversionRate >= 30) {
      rateColor = const Color(0xFF27AE60);
      rateLabel = 'ممتاز';
      rateIcon = Icons.trending_up_rounded;
    } else if (conversionRate >= 15) {
      rateColor = const Color(0xFFFF9800);
      rateLabel = 'جيد';
      rateIcon = Icons.trending_flat_rounded;
    } else {
      rateColor = const Color(0xFFE74C3C);
      rateLabel = 'يحتاج تحسين';
      rateIcon = Icons.trending_down_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rateColor.withOpacity(_isDark ? 0.3 : 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: rateColor.withOpacity(_isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(rateIcon, color: rateColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نسبة التحويل',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.textSecondary(_isDark),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${conversionRate.toStringAsFixed(1)}%',
                          style: GoogleFonts.cairo(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: rateColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: rateColor.withOpacity(_isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rateLabel,
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: rateColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // القيمة الإجمالية
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'القيمة المتوقعة',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.textSecondary(_isDark),
                    ),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(totalValue)}',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                  Text(
                    'ج.م',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.textSecondary(_isDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // شريط التحويل
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (conversionRate / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.divider(_isDark),
              valueColor: AlwaysStoppedAnimation<Color>(rateColor),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  // 🏗️ مراحل البيع
  // ===================================
  Widget _buildPipelineStages() {
    final stages = _pipelineData!['stages'] as List<dynamic>? ?? [];
    final totals = _pipelineData!['totals'] ?? {};
    final totalOpps = totals['TotalOpportunities'] ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.account_tree_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              Text(
                'المراحل',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(_isDark),
                ),
              ),
              const Spacer(),
              Text(
                '${stages.length} مراحل',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textSecondary(_isDark),
                ),
              ),
            ],
          ),
        ),
        ...List.generate(stages.length, (index) {
          final stage = stages[index];
          final isLast = index == stages.length - 1;
          return Column(
            children: [
              _buildStageCard(stage, totalOpps)
                  .animate()
                  .fadeIn(
                    duration: 400.ms,
                    delay: Duration(milliseconds: 100 * index),
                  )
                  .slideX(begin: 0.1, end: 0),
              if (!isLast) _buildConnector(stage),
            ],
          );
        }),
      ],
    );
  }

  // ===================================
  // 🎴 كارت المرحلة
  // ===================================
  Widget _buildStageCard(Map<String, dynamic> stage, int totalOpps) {
    final color = _hexToColor(stage['StageColor'] ?? '#3498db');
    final count = stage['Count'] ?? 0;
    final percentage = stage['Percentage'] ?? 0.0;
    final expectedValue = (stage['ExpectedValue'] ?? 0).toDouble();
    final overdueCount = stage['OverdueCount'] ?? 0;
    final todayCount = stage['TodayCount'] ?? 0;
    final stageNameAr = stage['StageNameAr'] ?? '';

    return GestureDetector(
      onTap: () {
        if (count > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StageClientsScreen(
                stageId: stage['StageID'],
                stageName: stageNameAr,
                stageColor: stage['StageColor'] ?? '#3498db',
                count: count,
                employeeId: _selectedEmployeeId,
                sourceId: _selectedSourceId,       // ✅ جديد
                adTypeId: _selectedAdTypeId,       // ✅ جديد
                userId: widget.userId,
                username: widget.username,
                dateFrom: _selectedDateRange != null
                    ? DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)
                    : null,
                dateTo: _selectedDateRange != null
                    ? DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)
                    : null,
              ),
            ),
          ).then((_) => _refresh());
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(_isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(_isDark ? 0.4 : 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.3 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // الصف العلوي
            Row(
              children: [
                // رقم العدد
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(_isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.3), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // اسم المرحلة والقيمة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stageNameAr,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(_isDark),
                        ),
                      ),
                      if (expectedValue > 0)
                        Text(
                          '${NumberFormat('#,###').format(expectedValue)} ج.م',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textSecondary(_isDark),
                          ),
                        ),
                    ],
                  ),
                ),

                // شارات المتأخر واليوم
                if (overdueCount > 0 || todayCount > 0)
                  Row(
                    children: [
                      if (overdueCount > 0)
                        _buildBadge('$overdueCount', Colors.red, Icons.warning_rounded),
                      if (todayCount > 0) ...[
                        const SizedBox(width: 4),
                        _buildBadge('$todayCount', Colors.orange, Icons.today_rounded),
                      ],
                    ],
                  ),

                const SizedBox(width: 8),

                // سهم
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: count > 0
                        ? color.withOpacity(_isDark ? 0.2 : 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: count > 0 ? color : AppColors.textHint(_isDark),
                    size: 24,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // شريط النسبة
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.divider(_isDark),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),

            const SizedBox(height: 8),

            // النسبة + العدد
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$count عميل',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary(_isDark),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(_isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$percentage%',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===================================
  // 🔗 خط الربط
  // ===================================
  Widget _buildConnector(Map<String, dynamic> stage) {
    final color = _hexToColor(stage['StageColor'] ?? '#3498db');
    return Container(
      height: 24,
      width: 3,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.6), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ===================================
  // 🔴 شارة محسنة
  // ===================================
  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  // ❌ شاشة الخطأ
  // ===================================
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 80, color: AppColors.textHint(_isDark)),
          const SizedBox(height: 16),
          Text(
            'فشل تحميل البيانات',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: AppColors.textSecondary(_isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تأكد من اتصالك بالإنترنت وحاول مرة أخرى',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textHint(_isDark),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.buttonGradient(_isDark),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: _isDark ? AppColors.navy : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  // 🎨 تحويل Hex لـ Color
  // ===================================
  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}