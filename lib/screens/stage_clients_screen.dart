import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/pipeline_service.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import 'opportunity_detail_screen.dart';
import 'add_interaction_screen.dart';

class StageClientsScreen extends StatefulWidget {
  final int stageId;
  final String stageName;
  final String stageColor;
  final int count;
  final int? employeeId;
  final int userId;           // ✅ جديد
  final String username;
  final String? dateFrom;
  final String? dateTo;
  final int? sourceId;      // ✅ جديد
  final int? adTypeId;      // ✅ جديد

  const StageClientsScreen({
    Key? key,
    required this.stageId,
    required this.stageName,
    required this.stageColor,
    required this.count,
    this.employeeId,
    required this.userId,      // ✅ جديد
    required this.username,
    this.dateFrom,
    this.dateTo,
    this.sourceId,      // ✅ جديد
    this.adTypeId,      // ✅ جديد
  }) : super(key: key);

  @override
  State<StageClientsScreen> createState() => _StageClientsScreenState();
}

class _StageClientsScreenState extends State<StageClientsScreen> {
  // ===================================
  // 📦 المتغيرات
  // ===================================
  List<dynamic> _opportunities = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _limit = 30;
  bool get _isDark => ThemeService().isDarkMode;

  String? _selectedFollowUpStatus;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ===================================
  // 📡 جلب البيانات
  // ===================================
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _page = 1;
      _opportunities = [];
    });

    try {
      final result = await PipelineService.getOpportunitiesByStage(
        stageId: widget.stageId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        employeeId: widget.employeeId,
        sourceId: widget.sourceId,       // ✅ جديد
        adTypeId: widget.adTypeId,  
        followUpStatus: _selectedFollowUpStatus,
        dateFrom: widget.dateFrom,
        dateTo: widget.dateTo,
        page: _page,
        limit: _limit,
      );

      if (result != null) {
        setState(() {
          _opportunities = result['data'] ?? [];
          _hasMore = result['pagination']?['hasMore'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    _page++;

    try {
      final result = await PipelineService.getOpportunitiesByStage(
        stageId: widget.stageId,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        employeeId: widget.employeeId,
        sourceId: widget.sourceId,       // ✅ جديد
        adTypeId: widget.adTypeId,  
        followUpStatus: _selectedFollowUpStatus,
        dateFrom: widget.dateFrom,
        dateTo: widget.dateTo,
        page: _page,
        limit: _limit,
      );

      if (result != null) {
        setState(() {
          _opportunities.addAll(result['data'] ?? []);
          _hasMore = result['pagination']?['hasMore'] ?? false;
          _isLoadingMore = false;
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  // ===================================
  // 🎨 واجهة المستخدم
  // ===================================
  @override
  Widget build(BuildContext context) {
    final stageColor = _hexToColor(widget.stageColor);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          backgroundColor: _isDark ? AppColors.navy : stageColor,
          elevation: 0,
          centerTitle: true,
          title: Column(
            children: [
              Text(
                widget.stageName,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              Text(
                '${_opportunities.length} عميل',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildFollowUpFilter(),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : _opportunities.isEmpty
                      ? _buildEmptyView()
                      : RefreshIndicator(
                          color: AppColors.gold,
                          onRefresh: _loadData,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _opportunities.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _opportunities.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: CircularProgressIndicator(color: AppColors.gold),
                                  ),
                                );
                              }
                              return _buildClientCard(_opportunities[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================
  // 🔍 شريط البحث
  // ===================================
  Widget _buildSearchBar() {
    return Container(
      color: AppColors.card(_isDark),
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        textDirection: ui.TextDirection.rtl,
        style: GoogleFonts.cairo(color: AppColors.text(_isDark)),
        decoration: InputDecoration(
          hintText: 'بحث بالاسم أو التليفون...',
          hintStyle: GoogleFonts.cairo(color: AppColors.textHint(_isDark)),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.gold),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textHint(_isDark)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _loadData();
                  },
                )
              : null,
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
          filled: true,
          fillColor: AppColors.inputFill(_isDark),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (value) {
          setState(() => _searchQuery = value);
          _loadData();
        },
      ),
    );
  }

  // ===================================
  // 🏷️ فلتر حالة المتابعة
  // ===================================
  Widget _buildFollowUpFilter() {
    final filters = [
      {'label': 'الكل', 'value': null},
      {'label': 'متأخر', 'value': 'Overdue', 'color': Colors.red},
      {'label': 'اليوم', 'value': 'Today', 'color': Colors.orange},
      {'label': 'قادم', 'value': 'Upcoming', 'color': Colors.green},
    ];

    return Container(
      color: AppColors.card(_isDark),
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFollowUpStatus == filter['value'];
          final filterColor = filter['color'] as Color? ?? AppColors.gold;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                filter['label'] as String,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? (_isDark ? AppColors.navy : Colors.white)
                      : AppColors.text(_isDark),
                ),
              ),
              selectedColor: filterColor,
              backgroundColor: AppColors.inputFill(_isDark),
              side: BorderSide(
                color: isSelected ? filterColor : AppColors.divider(_isDark),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFollowUpStatus = selected ? filter['value'] as String? : null;
                });
                _loadData();
              },
            ),
          );
        },
      ),
    );
  }

  // ===================================
  // 🎴 كارت العميل
  // ===================================
  Widget _buildClientCard(Map<String, dynamic> opp) {
    final followUpStatus = opp['FollowUpStatus'] ?? 'NotSet';
    final clientName = opp['ClientName'] ?? 'بدون اسم';
    final phone1 = opp['Phone1'] ?? '';
    final employeeName = opp['EmployeeName'] ?? '';
    final sourceName = opp['SourceNameAr'] ?? '';
    final adTypeName = opp['AdTypeNameAr'] ?? '';
    final expectedValue = (opp['ExpectedValue'] ?? 0).toDouble();
    final nextFollowUp = opp['NextFollowUpDate'];
    final daysSince = opp['DaysSinceFirstContact'] ?? 0;
    final interactionCount = opp['InteractionCount'] ?? 0;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (followUpStatus) {
      case 'Overdue':
        statusColor = Colors.red;
        statusText = 'متأخر';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'Today':
        statusColor = Colors.orange;
        statusText = 'اليوم';
        statusIcon = Icons.today_rounded;
        break;
      case 'Tomorrow':
        statusColor = Colors.blue;
        statusText = 'غداً';
        statusIcon = Icons.event_rounded;
        break;
      case 'Upcoming':
        statusColor = Colors.green;
        statusText = 'قادم';
        statusIcon = Icons.upcoming_rounded;
        break;
      default:
        statusColor = AppColors.textHint(_isDark);
        statusText = 'غير محدد';
        statusIcon = Icons.remove_circle_outline;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OpportunityDetailScreen(
              opportunityId: opp['OpportunityID'],
              userId: widget.userId,        // ✅ تمرير userId
              username: widget.username,
            ),
          ),
        ).then((_) => _loadData());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(_isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withOpacity(_isDark ? 0.3 : 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.3 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف الأول: الاسم + حالة المتابعة
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: statusColor.withOpacity(_isDark ? 0.2 : 0.1),
                  child: Text(
                    clientName.isNotEmpty ? clientName[0] : '?',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(_isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (employeeName.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary(_isDark)),
                            const SizedBox(width: 4),
                            Text(
                              employeeName,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.textSecondary(_isDark),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(_isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // الصف الثاني: التليفون + أزرار الأكشن
            Row(
              children: [
                Icon(Icons.phone_rounded, size: 14, color: AppColors.textSecondary(_isDark)),
                const SizedBox(width: 4),
                Text(
                  phone1,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.textSecondary(_isDark),
                  ),
                ),
                const Spacer(),
                if (phone1.isNotEmpty) ...[
                  // ✅ زرار تسجيل تواصل سريع
                  _buildActionButton(
                    icon: Icons.add_comment_rounded,
                    color: AppColors.gold,
                    onTap: () => _openAddInteraction(opp),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.phone_rounded,
                    color: const Color(0xFF27AE60),
                    onTap: () => _makeCall(phone1),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: FontAwesomeIcons.whatsapp,
                    color: const Color(0xFF25D366),
                    onTap: () => _openWhatsApp(phone1),
                  ),
                ],
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Divider(height: 1, color: AppColors.divider(_isDark)),
            ),

            const SizedBox(height: 8),

            // الصف الثالث: معلومات إضافية
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (sourceName.isNotEmpty)
                  _buildInfoChip(Icons.source_rounded, sourceName),
                if (adTypeName.isNotEmpty)
                  _buildInfoChip(Icons.campaign_rounded, adTypeName),
                if (expectedValue > 0)
                  _buildInfoChip(Icons.payments_rounded, '${NumberFormat('#,###').format(expectedValue)}'),
                if (nextFollowUp != null)
                  _buildInfoChip(Icons.event_note_rounded, _formatDate(nextFollowUp), color: statusColor),
                _buildInfoChip(Icons.chat_bubble_outline_rounded, '$interactionCount'),
                _buildInfoChip(Icons.schedule_rounded, '$daysSince يوم'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===================================
  // ✅ فتح شاشة تسجيل تواصل
  // ===================================
  void _openAddInteraction(Map<String, dynamic> opp) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInteractionScreen(
          userId: widget.userId,
          username: widget.username,
          preSelectedPartyId: opp['PartyID'],
          preSelectedOpportunityId: opp['OpportunityID'],
        ),
      ),
    );
    if (result == true) _loadData();
  }

  // ===================================
  // 🔘 زرار أكشن
  // ===================================
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(_isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  // ===================================
  // 🏷️ شريحة معلومات
  // ===================================
  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    final chipColor = color ?? AppColors.textSecondary(_isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(_isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(fontSize: 11, color: chipColor),
          ),
        ],
      ),
    );
  }

  // ===================================
  // 📭 شاشة فارغة
  // ===================================
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 80, color: AppColors.textHint(_isDark)),
          const SizedBox(height: 16),
          Text(
            'لا يوجد عملاء في هذه المرحلة',
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: AppColors.textSecondary(_isDark),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  // 🔧 Helpers
  // ===================================
  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    String formattedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedPhone.startsWith('0')) formattedPhone = '2$formattedPhone';
    final uri = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd/MM').format(dt);
    } catch (_) {
      return date;
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}