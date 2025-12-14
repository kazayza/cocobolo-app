import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants.dart';

class OpportunitiesScreen extends StatefulWidget {
  final int userId;
  final String username;

  const OpportunitiesScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  List<dynamic> opportunities = [];
  List<dynamic> stages = [];
  List<dynamic> sources = [];
  Map<String, dynamic> summary = {};
  bool loading = true;
  String searchQuery = '';
  int? selectedStageId;
  int? selectedSourceId;
  String? selectedFollowUpStatus;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    await Future.wait([
      _fetchStages(),
      _fetchSources(),
      _fetchSummary(),
      _fetchOpportunities(),
    ]);
    setState(() => loading = false);
  }

  Future<void> _fetchStages() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/stages'));
      if (res.statusCode == 200) {
        setState(() => stages = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching stages: $e');
    }
  }

  Future<void> _fetchSources() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/sources'));
      if (res.statusCode == 200) {
        setState(() => sources = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching sources: $e');
    }
  }

  Future<void> _fetchSummary() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/summary?username=${widget.username}'),
      );
      if (res.statusCode == 200) {
        setState(() => summary = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching summary: $e');
    }
  }

  Future<void> _fetchOpportunities() async {
    try {
      String url = '$baseUrl/api/opportunities?';
      
      if (searchQuery.isNotEmpty) {
        url += 'search=$searchQuery&';
      }
      if (selectedStageId != null) {
        url += 'stageId=$selectedStageId&';
      }
      if (selectedSourceId != null) {
        url += 'sourceId=$selectedSourceId&';
      }
      if (selectedFollowUpStatus != null) {
        url += 'followUpStatus=$selectedFollowUpStatus&';
      }

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        setState(() => opportunities = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching opportunities: $e');
    }
  }

  Color _getStageColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  Color _getFollowUpStatusColor(String? status) {
    switch (status) {
      case 'Overdue':
        return Colors.red;
      case 'Today':
        return Colors.orange;
      case 'Tomorrow':
        return Colors.blue;
      case 'Upcoming':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getFollowUpStatusText(String? status) {
    switch (status) {
      case 'Overdue':
        return 'متأخر';
      case 'Today':
        return 'اليوم';
      case 'Tomorrow':
        return 'غداً';
      case 'Upcoming':
        return 'قادم';
      case 'NotSet':
        return 'غير محدد';
      default:
        return '';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ✅ أيقونات المصادر الاحترافية
  // ═══════════════════════════════════════════════════════════════
  
  Widget _getSourceIcon(String? sourceName, {double size = 18}) {
    final name = sourceName?.toLowerCase() ?? '';
    
    if (name.contains('whatsapp') || name.contains('واتساب')) {
      return FaIcon(FontAwesomeIcons.whatsapp, size: size, color: const Color(0xFF25D366));
    } else if (name.contains('facebook') || name.contains('فيسبوك')) {
      return FaIcon(FontAwesomeIcons.facebook, size: size, color: const Color(0xFF1877F2));
    } else if (name.contains('instagram') || name.contains('انستجرام')) {
      return FaIcon(FontAwesomeIcons.instagram, size: size, color: const Color(0xFFE4405F));
    } else if (name.contains('tiktok') || name.contains('تيك توك')) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: FaIcon(FontAwesomeIcons.tiktok, size: size - 6, color: Colors.black),
      );
    } else if (name.contains('phone') || name.contains('مكالمة') || name.contains('تليفون')) {
      return FaIcon(FontAwesomeIcons.phoneVolume, size: size, color: const Color(0xFF4CAF50));
    } else if (name.contains('showroom') || name.contains('معرض') || name.contains('زيارة')) {
      return FaIcon(FontAwesomeIcons.store, size: size, color: const Color(0xFF9C27B0));
    } else if (name.contains('referral') || name.contains('توصية')) {
      return FaIcon(FontAwesomeIcons.userGroup, size: size, color: const Color(0xFF2196F3));
    } else if (name.contains('google') || name.contains('جوجل')) {
      return FaIcon(FontAwesomeIcons.google, size: size, color: const Color(0xFF4285F4));
    } else {
      return FaIcon(FontAwesomeIcons.globe, size: size, color: Colors.grey);
    }
  }

  // ✅ أيقونة المرحلة
  Widget _getStageIconWidget(int? stageId, Color color, {double size = 14}) {
    IconData iconData;
    switch (stageId) {
      case 1:
        iconData = FontAwesomeIcons.userPlus;
        break;
      case 2:
        iconData = FontAwesomeIcons.fire;
        break;
      case 3:
        iconData = FontAwesomeIcons.circleCheck;
        break;
      case 4:
        iconData = FontAwesomeIcons.circleXmark;
        break;
      case 5:
        iconData = FontAwesomeIcons.ban;
        break;
      default:
        iconData = FontAwesomeIcons.circle;
    }
    return FaIcon(iconData, size: size, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppBar(),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFFFFD700),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildSummaryCards()),
                  SliverToBoxAdapter(child: _buildFilters()),
                  SliverToBoxAdapter(child: _buildStageFilter()),
                  opportunities.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildOpportunityCard(opportunities[index], index),
                            childCount: opportunities.length,
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(FontAwesomeIcons.lightbulb, color: Color(0xFFFFD700), size: 20),
          const SizedBox(width: 10),
          Text(
            'فرص البيع',
            style: GoogleFonts.cairo(
              color: const Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.filter, color: Colors.white, size: 18),
          onPressed: _showFilterBottomSheet,
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.chartPie, color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 8),
              Text(
                'ملخص الفرص',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniSummaryCard(
                  'متأخرة',
                  '${summary['overdueFollowUp'] ?? 0}',
                  Colors.red,
                  FontAwesomeIcons.triangleExclamation,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniSummaryCard(
                  'اليوم',
                  '${summary['todayFollowUp'] ?? 0}',
                  Colors.orange,
                  FontAwesomeIcons.calendarDay,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniSummaryCard(
                  'مكسبة',
                  '${summary['closedCount'] ?? 0}',
                  Colors.green,
                  FontAwesomeIcons.trophy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniSummaryCard(
                  'الكل',
                  '${summary['totalOpportunities'] ?? 0}',
                  const Color(0xFFFFD700),
                  FontAwesomeIcons.layerGroup,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildMiniSummaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          FaIcon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.cairo(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'بحث بالاسم أو الهاتف...',
          hintStyle: GoogleFonts.cairo(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = '');
                    _fetchOpportunities();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() => searchQuery = value);
        },
        onSubmitted: (_) => _fetchOpportunities(),
      ),
    );
  }

  Widget _buildStageFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStageChip(null, 'الكل', const Color(0xFFFFD700), null),
            ...stages.map((stage) => _buildStageChip(
              stage['StageID'],
              stage['StageNameAr'] ?? stage['StageName'],
              _getStageColor(stage['StageColor']),
              stage['StageID'],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStageChip(int? stageId, String label, Color color, int? stageIdForIcon) {
    final isSelected = selectedStageId == stageId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: stageIdForIcon != null 
            ? _getStageIconWidget(stageIdForIcon, isSelected ? Colors.black : color, size: 12)
            : null,
        label: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => selectedStageId = selected ? stageId : null);
          _fetchOpportunities();
        },
        backgroundColor: color.withOpacity(0.2),
        selectedColor: color,
        checkmarkColor: Colors.black,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildOpportunityCard(dynamic opportunity, int index) {
    final stageColor = _getStageColor(opportunity['StageColor']);
    final followUpStatus = opportunity['FollowUpStatus'];
    final followUpColor = _getFollowUpStatusColor(followUpStatus);
    final stageId = opportunity['StageID'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          right: BorderSide(color: stageColor, width: 4),
        ),
      ),
      child: InkWell(
        onTap: () => _openOpportunityDetails(opportunity),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: الاسم + المرحلة
              Row(
                children: [
                  // أيقونة المرحلة
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: stageColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _getStageIconWidget(stageId, stageColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opportunity['ClientName'] ?? 'بدون اسم',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opportunity['StageNameAr'] ?? opportunity['StageName'] ?? '',
                          style: GoogleFonts.cairo(
                            color: stageColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // حالة المتابعة
                  if (followUpStatus != null && followUpStatus != 'NotSet')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: followUpColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: followUpColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            followUpStatus == 'Overdue' 
                                ? FontAwesomeIcons.clockRotateLeft
                                : FontAwesomeIcons.clock,
                            color: followUpColor,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getFollowUpStatusText(followUpStatus),
                            style: GoogleFonts.cairo(
                              color: followUpColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // خط فاصل
              Divider(color: Colors.grey.withOpacity(0.2), height: 1),
              
              const SizedBox(height: 12),

              // الصف الثاني: الهاتف + المصدر
              Row(
                children: [
                  // الهاتف
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.phone, color: Colors.grey, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          opportunity['Phone1'] ?? 'لا يوجد',
                          style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // المصدر
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _getSourceIcon(opportunity['SourceName'], size: 14),
                        const SizedBox(width: 6),
                        Text(
                          opportunity['SourceNameAr'] ?? opportunity['SourceName'] ?? '',
                          style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),

              // الصف الثالث: القيمة + المنتج
              Row(
                children: [
                  // القيمة المتوقعة
                  if (opportunity['ExpectedValue'] != null && opportunity['ExpectedValue'] > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.withOpacity(0.2),
                            Colors.green.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(FontAwesomeIcons.coins, color: Colors.green, size: 12),
                          const SizedBox(width: 6),
                          Text(
                            '${_formatCurrency(opportunity['ExpectedValue'])}',
                            style: GoogleFonts.cairo(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // المنتج المهتم به
                  if (opportunity['InterestedProduct'] != null &&
                      opportunity['InterestedProduct'].toString().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(FontAwesomeIcons.box, color: Colors.grey, size: 12),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                opportunity['InterestedProduct'],
                                style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms)
        .slideX(begin: 0.1, end: 0);
  }

  // ✅ تنسيق العملة
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 ج.م';
    final num = double.tryParse(amount.toString()) ?? 0;
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M ج.م';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K ج.م';
    }
    return '${num.toInt()} ج.م';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(FontAwesomeIcons.folderOpen, size: 60, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'لا توجد فرص',
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'أضف فرصة جديدة للبدء',
            style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNewOpportunity,
            icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
            label: Text('إضافة فرصة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _addNewOpportunity,
      backgroundColor: const Color(0xFFFFD700),
      icon: const FaIcon(FontAwesomeIcons.plus, color: Colors.black, size: 18),
      label: Text(
        'فرصة جديدة',
        style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold),
      ),
    ).animate().scale(delay: 500.ms, duration: 300.ms);
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const FaIcon(FontAwesomeIcons.filter, color: Color(0xFFFFD700), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'فلترة الفرص',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // فلترة حسب حالة المتابعة
              Text('حالة المتابعة', style: GoogleFonts.cairo(color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip('الكل', null, selectedFollowUpStatus == null, (selected) {
                    setModalState(() => selectedFollowUpStatus = null);
                  }, FontAwesomeIcons.layerGroup),
                  _buildFilterChip('متأخرة', 'Overdue', selectedFollowUpStatus == 'Overdue', (selected) {
                    setModalState(() => selectedFollowUpStatus = selected ? 'Overdue' : null);
                  }, FontAwesomeIcons.triangleExclamation),
                  _buildFilterChip('اليوم', 'Today', selectedFollowUpStatus == 'Today', (selected) {
                    setModalState(() => selectedFollowUpStatus = selected ? 'Today' : null);
                  }, FontAwesomeIcons.calendarDay),
                  _buildFilterChip('غداً', 'Tomorrow', selectedFollowUpStatus == 'Tomorrow', (selected) {
                    setModalState(() => selectedFollowUpStatus = selected ? 'Tomorrow' : null);
                  }, FontAwesomeIcons.calendarWeek),
                ],
              ),
              const SizedBox(height: 24),

              // زر تطبيق
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                    _fetchOpportunities();
                  },
                  icon: const FaIcon(FontAwesomeIcons.check, size: 16),
                  label: Text(
                    'تطبيق الفلتر',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // زر إعادة تعيين
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    setModalState(() {
                      selectedFollowUpStatus = null;
                      selectedSourceId = null;
                    });
                    setState(() {
                      selectedFollowUpStatus = null;
                      selectedSourceId = null;
                      selectedStageId = null;
                    });
                    Navigator.pop(context);
                    _fetchOpportunities();
                  },
                  icon: const FaIcon(FontAwesomeIcons.rotateLeft, size: 14, color: Colors.grey),
                  label: Text(
                    'إعادة تعيين',
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, bool isSelected, Function(bool) onSelected, IconData icon) {
    return FilterChip(
      avatar: FaIcon(icon, size: 12, color: isSelected ? Colors.black : Colors.grey),
      label: Text(
        label,
        style: GoogleFonts.cairo(
          color: isSelected ? Colors.black : Colors.white,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Colors.grey[800],
      selectedColor: const Color(0xFFFFD700),
      checkmarkColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _openOpportunityDetails(dynamic opportunity) {
    // TODO: Navigate to details screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const FaIcon(FontAwesomeIcons.circleInfo, color: Colors.white, size: 16),
            const SizedBox(width: 10),
            Text(
              'تفاصيل: ${opportunity['ClientName']}',
              style: GoogleFonts.cairo(),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _addNewOpportunity() {
    // TODO: Navigate to add screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const FaIcon(FontAwesomeIcons.rocket, color: Color(0xFFFFD700), size: 16),
            const SizedBox(width: 10),
            Text('إضافة فرصة جديدة - قريباً!', style: GoogleFonts.cairo()),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}