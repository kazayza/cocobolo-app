import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/leads_service.dart';
import 'lead_detail_screen.dart';
import 'dart:async';

class LeadsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const LeadsScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  bool _isLoading = true;
  List<dynamic> _allLeads = [];
  List<dynamic> _leads = [];
  String _selectedStatus = 'الكل';
  String _sortBy = 'الأحدث';
  String _dateFilter = 'الكل';
  DateTimeRange? _customDateRange;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final List<Map<String, dynamic>> _statuses = [
    {'label': 'الكل', 'icon': Icons.all_inclusive, 'color': Colors.blueGrey},
    {'label': 'جديد', 'icon': Icons.fiber_new_rounded, 'color': Colors.blue},
    {'label': 'تم التواصل', 'icon': Icons.phone_callback, 'color': Colors.orange},
    {'label': 'تم الإسناد', 'icon': Icons.assignment_ind, 'color': Colors.purple},
    {'label': 'محول', 'icon': Icons.check_circle, 'color': Colors.green},
    {'label': 'مرفوض', 'icon': Icons.cancel, 'color': Colors.red},
  ];

  final List<Map<String, dynamic>> _dateFilters = [
    {'label': 'الكل', 'icon': Icons.all_inclusive},
    {'label': 'اليوم', 'icon': Icons.today_rounded},
    {'label': 'آخر أسبوع', 'icon': Icons.date_range_rounded},
    {'label': 'آخر شهر', 'icon': Icons.calendar_month_rounded},
    {'label': 'مخصص', 'icon': Icons.edit_calendar_rounded},
  ];

  final List<String> _sortOptions = ['الأحدث', 'الأقدم', 'الاسم', 'الحالة'];

  @override
  void initState() {
    super.initState();
    _fetchLeads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _fetchLeads();
    });
  }

  bool get _hasActiveFilters =>
      _selectedStatus != 'الكل' ||
      _searchController.text.trim().isNotEmpty ||
      _dateFilter != 'الكل';

  int get _activeFilterCount {
    int count = 0;
    if (_selectedStatus != 'الكل') count++;
    if (_dateFilter != 'الكل') count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatus = 'الكل';
      _dateFilter = 'الكل';
      _customDateRange = null;
    });
    _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final leads = await LeadsService.getLeads(
      status: _selectedStatus == 'الكل' ? null : _selectedStatus,
      search: _searchController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _allLeads = leads;
      _leads = _applyDateFilter(leads);
      _sortLeads();
      _isLoading = false;
    });
  }

  void _sortLeads() {
    switch (_sortBy) {
      case 'الأحدث':
        _leads.sort((a, b) => (b['LeadDate'] ?? '').compareTo(a['LeadDate'] ?? ''));
        break;
      case 'الأقدم':
        _leads.sort((a, b) => (a['LeadDate'] ?? '').compareTo(b['LeadDate'] ?? ''));
        break;
      case 'الاسم':
        _leads.sort((a, b) => (a['FullName'] ?? '').compareTo(b['FullName'] ?? ''));
        break;
      case 'الحالة':
        _leads.sort((a, b) => (a['LeadStatus'] ?? '').compareTo(b['LeadStatus'] ?? ''));
        break;
    }
  }

  List<dynamic> _applyDateFilter(List<dynamic> leads) {
    if (_dateFilter == 'الكل') return List.from(leads);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return leads.where((lead) {
      final dateStr = lead['LeadDate'] as String?;
      if (dateStr == null || dateStr.isEmpty) return false;

      DateTime? leadDate;
      try {
        leadDate = DateTime.tryParse(dateStr);
        if (leadDate == null) {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            leadDate = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
          }
        }
      } catch (_) {}

      if (leadDate == null) return true;

      switch (_dateFilter) {
        case 'اليوم':
          return leadDate.year == today.year &&
              leadDate.month == today.month &&
              leadDate.day == today.day;
        case 'آخر أسبوع':
          return leadDate.isAfter(today.subtract(const Duration(days: 7)));
        case 'آخر شهر':
          return leadDate.isAfter(today.subtract(const Duration(days: 30)));
        case 'مخصص':
          if (_customDateRange == null) return true;
          final start = DateTime(
              _customDateRange!.start.year,
              _customDateRange!.start.month,
              _customDateRange!.start.day);
          final end = DateTime(
              _customDateRange!.end.year,
              _customDateRange!.end.month,
              _customDateRange!.end.day, 23, 59, 59);
          return leadDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
              leadDate.isBefore(end.add(const Duration(seconds: 1)));
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _pickCustomDateRange() async {
    final isDark = ThemeService().isDarkMode;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF60a5fa),
                    onPrimary: Color(0xFF0f172a),
                    surface: Color(0xFF1e293b),
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: const Color(0xFF1e293b),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF60a5fa),
                    ),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF2563eb),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF0f172a),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563eb),
                    ),
                  ),
                ),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: child!,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _customDateRange = picked;
        _dateFilter = 'مخصص';
      });
      _fetchLeads();
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'جديد': return Colors.blue;
      case 'تم التواصل': return Colors.orange;
      case 'تم الإسناد': return Colors.purple;
      case 'محول': return Colors.green;
      case 'مرفوض': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'جديد': return Icons.fiber_new_rounded;
      case 'تم التواصل': return Icons.phone_callback;
      case 'تم الإسناد': return Icons.assignment_ind;
      case 'محول': return Icons.check_circle;
      case 'مرفوض': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  // ══════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(
          'العملاء المحتملين',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchLeads,
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchLeads,
          color: const Color(0xFF2563eb),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _buildHeroSummary(isDark)),
              SliverToBoxAdapter(child: _buildFilterSection(isDark)),
              SliverToBoxAdapter(child: _buildResultsBar(isDark)),

              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF2563eb))),
                )
              else if (_leads.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(isDark),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildLeadCard(_leads[index], isDark),
                      childCount: _leads.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // HERO SUMMARY (Clickable)
  // ══════════════════════════════════════════════
  Widget _buildHeroSummary(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0f172a), Color(0xFF1e3a8a), Color(0xFF2563eb)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0f172a).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Total — clickable
            GestureDetector(
              onTap: () {
                setState(() => _selectedStatus = 'الكل');
                _fetchLeads();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedStatus == 'الكل'
                      ? Colors.white.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: _selectedStatus == 'الكل'
                      ? Border.all(color: Colors.white.withOpacity(0.25))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إجمالي العملاء المحتملين',
                              style: GoogleFonts.cairo(
                                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('${_leads.length}',
                              style: GoogleFonts.cairo(
                                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    if (_selectedStatus == 'الكل')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('مفعّل',
                            style: GoogleFonts.cairo(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Status mini cards — clickable
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _statuses.where((s) => s['label'] != 'الكل').length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filtered = _statuses.where((s) => s['label'] != 'الكل').toList();
                  final item = filtered[index];
                  final label = item['label'] as String;
                  final color = item['color'] as Color;
                  final icon = item['icon'] as IconData;
                  final count = _allLeads.where((l) => l['LeadStatus'] == label).length;
                  final isSelected = _selectedStatus == label;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedStatus = isSelected ? 'الكل' : label);
                      _fetchLeads();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.18)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(color: color.withOpacity(0.6), width: 1.5)
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 13, color: isSelected ? color : Colors.white54),
                              const SizedBox(width: 4),
                              Text('$count',
                                  style: GoogleFonts.cairo(
                                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(label,
                              style: GoogleFonts.cairo(
                                  color: isSelected ? Colors.white : Colors.white54,
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // FILTER SECTION
  // ══════════════════════════════════════════════
  Widget _buildFilterSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0f172a) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) {
                        setState(() {});
                        _onSearchChanged();
                      },
                      onSubmitted: (_) => _fetchLeads(),
                      style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0f172a)),
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم، الهاتف، أو الحملة...',
                        hintStyle: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF94a3b8)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94a3b8), size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94a3b8)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                  _fetchLeads();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionIcon(icon: Icons.sort_rounded, isDark: isDark, onTap: () => _showSortSheet(isDark)),
                const SizedBox(width: 6),
                _buildActionIcon(
                    icon: Icons.tune_rounded, isDark: isDark,
                    badge: _hasActiveFilters, onTap: () => _showAdvancedFilters(isDark)),
              ],
            ),

            const SizedBox(height: 10),

            // Date filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _dateFilters.map((df) {
                  final label = df['label'] as String;
                  final icon = df['icon'] as IconData;
                  final isSelected = _dateFilter == label;

                  return Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: GestureDetector(
                      onTap: () {
                        if (label == 'مخصص') {
                          _pickCustomDateRange();
                        } else {
                          setState(() {
                            _dateFilter = label;
                            _customDateRange = null;
                          });
                          _fetchLeads();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563eb).withOpacity(0.12)
                              : (isDark ? const Color(0xFF0f172a) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563eb)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3)),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 13,
                                color: isSelected ? const Color(0xFF2563eb) : const Color(0xFF94a3b8)),
                            const SizedBox(width: 4),
                            Text(
                              _dateFilter == 'مخصص' && label == 'مخصص' && _customDateRange != null
                                  ? '${_customDateRange!.start.day}/${_customDateRange!.start.month} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}'
                                  : label,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF2563eb)
                                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Status chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuses.map((status) {
                  final label = status['label'] as String;
                  final color = status['color'] as Color;
                  final icon = status['icon'] as IconData;
                  final isSelected = _selectedStatus == label;

                  return Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedStatus = label);
                        _fetchLeads();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.15)
                              : (isDark ? const Color(0xFF0f172a) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3)),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: isSelected ? color : const Color(0xFF94a3b8)),
                            const SizedBox(width: 5),
                            Text(label,
                                style: GoogleFonts.cairo(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected
                                        ? color
                                        : (isDark ? Colors.white70 : const Color(0xFF334155)))),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required bool isDark,
    bool badge = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0f172a) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: badge
                    ? const Color(0xFF2563eb).withOpacity(0.5)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3)),
              ),
            ),
            child: Icon(icon,
                color: badge
                    ? const Color(0xFF2563eb)
                    : (isDark ? Colors.white70 : const Color(0xFF64748b)),
                size: 20),
          ),
          if (badge && icon == Icons.tune_rounded && _activeFilterCount > 0)
            Positioned(
              top: -4, right: -4,
              child: Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563eb),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$_activeFilterCount',
                      style: GoogleFonts.cairo(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // RESULTS BAR
  // ══════════════════════════════════════════════
  Widget _buildResultsBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1 — count + sort
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF64748b)),
                    children: [
                      const TextSpan(text: 'عرض '),
                      TextSpan(
                        text: '${_leads.length}',
                        style: GoogleFonts.cairo(
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0f172a)),
                      ),
                      const TextSpan(text: ' عميل محتمل'),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showSortSheet(isDark),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1e293b) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_rounded, size: 13, color: Color(0xFF64748b)),
                      const SizedBox(width: 3),
                      Text(_sortBy,
                          style: GoogleFonts.cairo(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF334155))),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Row 2 — active filter chips
          if (_hasActiveFilters) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedStatus != 'الكل')
                    _buildActiveFilterChip(
                      label: _selectedStatus,
                      color: _getStatusColor(_selectedStatus),
                      isDark: isDark,
                      onRemove: () {
                        setState(() => _selectedStatus = 'الكل');
                        _fetchLeads();
                      },
                    ),
                  if (_dateFilter != 'الكل')
                    _buildActiveFilterChip(
                      label: _dateFilter == 'مخصص' && _customDateRange != null
                          ? '${_customDateRange!.start.day}/${_customDateRange!.start.month} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}'
                          : _dateFilter,
                      color: const Color(0xFF2563eb),
                      isDark: isDark,
                      onRemove: () {
                        setState(() {
                          _dateFilter = 'الكل';
                          _customDateRange = null;
                        });
                        _fetchLeads();
                      },
                    ),
                  if (_searchController.text.trim().isNotEmpty)
                    _buildActiveFilterChip(
                      label: '"${_searchController.text.trim()}"',
                      color: const Color(0xFF64748b),
                      isDark: isDark,
                      onRemove: () {
                        _searchController.clear();
                        setState(() {});
                        _fetchLeads();
                      },
                    ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _clearAllFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF450a0a) : const Color(0xFFfef2f2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFfca5a5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.restart_alt_rounded, size: 13, color: Color(0xFFdc2626)),
                          const SizedBox(width: 3),
                          Text('مسح الكل',
                              style: GoogleFonts.cairo(
                                  fontSize: 11, fontWeight: FontWeight.w800,
                                  color: const Color(0xFFdc2626))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, size: 10, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0f172a) : const Color(0xFFf1f5f9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.search_off_rounded, size: 32, color: Color(0xFF94a3b8)),
            ),
            const SizedBox(height: 16),
            Text('لا توجد نتائج مطابقة',
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0f172a))),
            const SizedBox(height: 6),
            Text('جرّب تغيير كلمات البحث أو إعادة تعيين الفلاتر.',
                style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748b)),
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            if (_hasActiveFilters)
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text('مسح الفلاتر', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563eb),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // LEAD CARD
  // ══════════════════════════════════════════════
  Widget _buildLeadCard(dynamic lead, bool isDark) {
    final status = lead['LeadStatus'] ?? 'جديد';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final name = lead['FullName'] ?? 'بدون اسم';
    final phone = lead['Phone'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e293b) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            final leadId = lead['LeadId'];
            if (leadId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeadDetailScreen(
                    leadId: leadId is int ? leadId : int.tryParse(leadId.toString()) ?? 0,
                    userId: widget.userId,
                    username: widget.username,
                  ),
                ),
              );
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status accent bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name + Status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.cairo(
                                  fontSize: 16, fontWeight: FontWeight.w900, color: statusColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: GoogleFonts.cairo(
                                      fontSize: 14, fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0f172a)),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(phone,
                                  style: GoogleFonts.cairo(
                                      fontSize: 12, color: const Color(0xFF64748b))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(status,
                                  style: GoogleFonts.cairo(
                                      fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Meta chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildMetaChip(
                            icon: Icons.campaign_rounded,
                            text: lead['CampaignName'] ?? 'إعلان عام', isDark: isDark),
                        _buildMetaChip(
                            icon: Icons.calendar_today_rounded,
                            text: lead['LeadDate'] ?? '', isDark: isDark),
                        _buildMetaChip(
                          icon: Icons.person_outline_rounded,
                          text: lead['EmployeeName'] ?? 'غير مسند',
                          isDark: isDark,
                          highlight: lead['EmployeeName'] != null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Quick actions
                    Container(
                      padding: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFedf2f7),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(lead['LeadDate'] ?? '',
                                style: GoogleFonts.cairo(fontSize: 10.5, color: const Color(0xFF94a3b8))),
                          ),
                          if (phone.isNotEmpty) ...[
                            _buildQuickAction(
                              icon: Icons.phone_rounded,
                              color: Colors.green,
                              isDark: isDark,
                              tooltip: 'اتصال',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('جاري الاتصال بـ $phone',
                                        style: GoogleFonts.cairo()),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildQuickAction(
                              icon: Icons.chat_rounded,
                              color: const Color(0xFF25D366),
                              isDark: isDark,
                              tooltip: 'واتساب',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('فتح واتساب $phone',
                                        style: GoogleFonts.cairo()),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    required bool isDark,
    bool highlight = false,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? (isDark ? const Color(0xFF1e3a5f) : const Color(0xFFeff6ff))
            : (isDark ? const Color(0xFF0f172a) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? (isDark ? const Color(0xFF3b82f6) : const Color(0xFFbfdbfe))
              : (isDark ? const Color(0xFF334155) : const Color(0xFFedf2f7)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12,
              color: highlight ? const Color(0xFF2563eb) : const Color(0xFF94a3b8)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    fontSize: 10.5,
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                    color: highlight
                        ? (isDark ? const Color(0xFF60a5fa) : const Color(0xFF1d4ed8))
                        : const Color(0xFF64748b))),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required Color color,
    required bool isDark,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // SORT BOTTOM SHEET
  // ══════════════════════════════════════════════
  void _showSortSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1e293b) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFFcbd5e1), borderRadius: BorderRadius.circular(99)),
            ),
            Text('ترتيب النتائج',
                style: GoogleFonts.cairo(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0f172a))),
            const SizedBox(height: 14),
            ..._sortOptions.map((option) => ListTile(
                  leading: Icon(
                    _sortBy == option ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: _sortBy == option ? const Color(0xFF2563eb) : const Color(0xFF94a3b8),
                    size: 20,
                  ),
                  title: Text(option,
                      style: GoogleFonts.cairo(
                          fontWeight: _sortBy == option ? FontWeight.w800 : FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0f172a))),
                  onTap: () {
                    setState(() {
                      _sortBy = option;
                      _sortLeads();
                    });
                    Navigator.pop(ctx);
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ADVANCED FILTERS
  // ══════════════════════════════════════════════
  void _showAdvancedFilters(bool isDark) {
    String tempStatus = _selectedStatus;
    String tempSort = _sortBy;
    String tempDate = _dateFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.85,
            minChildSize: 0.4,
            builder: (ctx, scrollController) => Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1e293b) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFcbd5e1), borderRadius: BorderRadius.circular(99)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('فلاتر متقدمة',
                            style: GoogleFonts.cairo(
                                fontSize: 18, fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0f172a))),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempStatus = 'الكل';
                              tempSort = 'الأحدث';
                              tempDate = 'الكل';
                            });
                          },
                          child: Text('إعادة تعيين',
                              style: GoogleFonts.cairo(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  color: const Color(0xFFdc2626))),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Status
                        Text('الحالة',
                            style: GoogleFonts.cairo(
                                fontSize: 14, fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0f172a))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _statuses.map((s) {
                            final label = s['label'] as String;
                            final isSelected = tempStatus == label;
                            final color = s['color'] as Color;
                            return GestureDetector(
                              onTap: () => setSheetState(() => tempStatus = label),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withOpacity(0.15)
                                      : (isDark ? const Color(0xFF0f172a) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? color
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3)),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(s['icon'] as IconData, size: 15,
                                        color: isSelected ? color : const Color(0xFF94a3b8)),
                                    const SizedBox(width: 6),
                                    Text(label,
                                        style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected
                                                ? color
                                                : (isDark ? Colors.white70 : const Color(0xFF334155)))),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // Date
                        Text('الفترة الزمنية',
                            style: GoogleFonts.cairo(
                                fontSize: 14, fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0f172a))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _dateFilters.map((df) {
                            final label = df['label'] as String;
                            final icon = df['icon'] as IconData;
                            final isSelected = tempDate == label;
                            return GestureDetector(
                              onTap: () {
                                if (label == 'مخصص') {
                                  Navigator.pop(ctx);
                                  _pickCustomDateRange();
                                } else {
                                  setSheetState(() => tempDate = label);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563eb).withOpacity(0.12)
                                      : (isDark ? const Color(0xFF0f172a) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2563eb)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3)),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 15,
                                        color: isSelected
                                            ? const Color(0xFF2563eb) : const Color(0xFF94a3b8)),
                                    const SizedBox(width: 6),
                                    Text(label,
                                        style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected
                                                ? const Color(0xFF2563eb)
                                                : (isDark ? Colors.white70 : const Color(0xFF334155)))),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // Sort
                        Text('ترتيب',
                            style: GoogleFonts.cairo(
                                fontSize: 14, fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0f172a))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _sortOptions.map((option) {
                            final isSelected = tempSort == option;
                            return GestureDetector(
                              onTap: () => setSheetState(() => tempSort = option),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563eb).withOpacity(0.12)
                                      : (isDark ? const Color(0xFF0f172a) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2563eb)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3)),
                                  ),
                                ),
                                child: Text(option,
                                    style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFF2563eb)
                                            : (isDark ? Colors.white70 : const Color(0xFF334155)))),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Apply
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFe4eaf3),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity, height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedStatus = tempStatus;
                            _sortBy = tempSort;
                            _dateFilter = tempDate;
                            if (tempDate != 'مخصص') _customDateRange = null;
                          });
                          _fetchLeads();
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563eb),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text('تطبيق الفلاتر',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}