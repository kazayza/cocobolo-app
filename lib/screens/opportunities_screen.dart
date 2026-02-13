import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import 'add_opportunity_screen.dart';
import 'add_interaction_screen.dart';
import 'opportunity_details_screen.dart';

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
  List<dynamic> adTypes = [];
  List<dynamic> employees = [];

  Map<String, dynamic> summary = {};
  bool loading = true;
    // ✅ Pagination
  int currentPage = 1;
  int totalPages = 1;
  bool hasMore = true;
  bool loadingMore = false;
  final ScrollController _scrollController = ScrollController();
    // ✅ متغيرات الـ Summary Carousel
  int _currentSummaryPage = 0;
  final PageController _summaryPageController = PageController(viewportFraction: 0.93);
  String searchQuery = '';

  int? selectedStageId;
  int? selectedSourceId;
  int? selectedAdTypeId;
  int? selectedEmployeeId;
  String? selectedFollowUpStatus;
  String? sortBy;
  
  // ✅ فلتر التاريخ
  DateTime? dateFrom;
  DateTime? dateTo;
  
  Timer? _debounceTimer;

  final TextEditingController _searchController = TextEditingController();

  int get _activeFiltersCount {
    int count = 0;
    if (selectedStageId != null) count++;
    if (selectedSourceId != null) count++;
    if (selectedAdTypeId != null) count++;
    if (selectedEmployeeId != null) count++;
    if (selectedFollowUpStatus != null) count++;
    if (searchQuery.isNotEmpty) count++;
    if (sortBy != null) count++;
    if (dateFrom != null) count++;
    if (dateTo != null) count++;
    return count;
  }

@override
void initState() {
  super.initState();
  _loadData();
  
  // ✅ Listener للـ Scroll
  _scrollController.addListener(() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreOpportunities();
    }
  });
}

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    await Future.wait([
      _fetchStages(),
      _fetchSources(),
      _fetchAdTypes(),
      _fetchEmployees(),
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

  Future<void> _fetchAdTypes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/ad-types'));
      if (res.statusCode == 200) {
        setState(() => adTypes = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching ad types: $e');
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/employees'));
      if (res.statusCode == 200) {
        setState(() => employees = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
    }
  }

  Future<void> _fetchSummary() async {
  try {
    String url = '$baseUrl/api/opportunities/summary?username=${widget.username}';
    if (selectedEmployeeId != null) url += '&employeeId=$selectedEmployeeId';
    if (selectedSourceId != null) url += '&sourceId=$selectedSourceId';
    if (selectedAdTypeId != null) url += '&adTypeId=$selectedAdTypeId';
    if (selectedStageId != null) url += '&stageId=$selectedStageId';
    if (dateFrom != null) url += '&dateFrom=${_formatDateForApi(dateFrom!)}';
    if (dateTo != null) url += '&dateTo=${_formatDateForApi(dateTo!)}';

    debugPrint('📊 Summary URL: $url'); // ✅ للتأكد

    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      setState(() => summary = jsonDecode(res.body));
    }
  } catch (e) {
    debugPrint('Error fetching summary: $e');
  }
}

Future<void> _fetchOpportunities({bool reset = true}) async {
  try {
    if (reset) {
      currentPage = 1;
      hasMore = true;
    }

    String url = '$baseUrl/api/opportunities?page=$currentPage&limit=30';

    if (searchQuery.isNotEmpty) url += '&search=$searchQuery';
    if (selectedStageId != null) url += '&stageId=$selectedStageId';
    if (selectedSourceId != null) url += '&sourceId=$selectedSourceId';
    if (selectedAdTypeId != null) url += '&adTypeId=$selectedAdTypeId';
    if (selectedEmployeeId != null) url += '&employeeId=$selectedEmployeeId';
    if (selectedFollowUpStatus != null) url += '&followUpStatus=$selectedFollowUpStatus';
    if (sortBy != null) url += '&sortBy=$sortBy';
    if (dateFrom != null) url += '&dateFrom=${_formatDateForApi(dateFrom!)}';
    if (dateTo != null) url += '&dateTo=${_formatDateForApi(dateTo!)}';

    final res = await http.get(Uri.parse(url));

    if (res.statusCode == 200) {
      final responseData = jsonDecode(res.body);
      
      setState(() {
        if (reset) {
          opportunities = responseData['data'];
        } else {
          opportunities.addAll(responseData['data']);
        }
        
        currentPage = responseData['pagination']['page'];
        totalPages = responseData['pagination']['totalPages'];
        hasMore = responseData['pagination']['hasMore'];
      });
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> _loadMoreOpportunities() async {
  if (loadingMore || !hasMore) return;

  setState(() => loadingMore = true);

  currentPage++;
  await _fetchOpportunities(reset: false);

  setState(() => loadingMore = false);
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

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar('لا يوجد رقم هاتف', Colors.red);
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar('لا يوجد رقم هاتف', Colors.red);
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.startsWith('00')) {
      cleanPhone = cleanPhone.substring(2);
    } else if (cleanPhone.startsWith('0')) {
      cleanPhone = '20${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 10 && !cleanPhone.startsWith('20')) {
      cleanPhone = '20$cleanPhone';
    }

    final waUrl = 'https://wa.me/$cleanPhone';

    try {
      final uri = Uri.parse(waUrl);
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched) {
        final waUri = Uri.parse('whatsapp://send?phone=$cleanPhone');
        launched = await launchUrl(waUri);

        if (!launched) {
          _showSnackBar('لم يتم العثور على واتساب', Colors.orange);
        }
      }
    } catch (e) {
      debugPrint('❌ WhatsApp Error: $e');
      _showSnackBar('حدث خطأ: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  
  // حساب عدد الأيام من تاريخ معين
String _formatDaysAgo(String? dateStr) {
  if (dateStr == null) return 'لا يوجد';
  try {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'اليوم';
    if (difference == 1) return 'من يوم';
    if (difference == 2) return 'من يومين';
    if (difference <= 7) return 'من $difference أيام';
    if (difference <= 30) return 'من ${(difference / 7).floor()} أسابيع';
    return 'من ${(difference / 30).floor()} شهور';
  } catch (e) {
    return 'لا يوجد';
  }
}

// تنسيق التاريخ
String _formatDateShort(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year}';
  } catch (e) {
    return '';
  }
}

// التحقق إذا كانت الفرصة جديدة (أقل من 3 أيام)
bool _isNewOpportunity(String? createdAt) {
  if (createdAt == null) return false;
  try {
    final date = DateTime.parse(createdAt);
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
      return difference <= 3;
    } catch (e) {
      return false;
    }
  }
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

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

// ✅ جديد - للـ API
String _formatDateForApi(DateTime date) {
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

  // ✅ اختيار التاريخ
// ✅ اختيار التاريخ - النسخة المصححة
Future<void> _selectDate(BuildContext context, bool isFromDate, StateSetter setModalState) async {
  final DateTime initialDate = isFromDate 
      ? (dateFrom ?? DateTime.now()) 
      : (dateTo ?? DateTime.now());
  
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    builder: (context, child) {
      return Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFD700),
            onPrimary: Colors.black,
            surface: Color(0xFF1A1A1A),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1A1A1A),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFFD700),
            ),
          ),
        ),
        child: child!,
      );
    },
  );

  if (picked != null) {
    setModalState(() {
      if (isFromDate) {
        dateFrom = picked;
        if (dateTo != null && dateFrom!.isAfter(dateTo!)) {
          dateTo = dateFrom;
        }
      } else {
        dateTo = picked;
        if (dateFrom != null && dateTo!.isBefore(dateFrom!)) {
          dateFrom = dateTo;
        }
      }
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppBar(),
      body: loading
          ? _buildShimmerLoading()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFFFFD700),
              child: CustomScrollView(
                controller: _scrollController, 
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildSummaryCards()),
                  SliverToBoxAdapter(child: _buildSearchAndSort()),
                  // ✅ عرض الفلاتر النشطة
                  if (_activeFiltersCount > 0)
                    SliverToBoxAdapter(child: _buildActiveFiltersBar()),
                  SliverToBoxAdapter(child: _buildStageFilter()),
                  opportunities.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildOpportunityCard(opportunities[index], index),
                            childCount: opportunities.length,
                          ),
                        ),
                        // ✅ Loading Indicator للـ Pagination
if (loadingMore)
  const SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
      ),
    ),
  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ✅ شريط الفلاتر النشطة
  Widget _buildActiveFiltersBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (dateFrom != null || dateTo != null)
              _buildActiveFilterChip(
                '${dateFrom != null ? _formatDate(dateFrom!) : '...'} - ${dateTo != null ? _formatDate(dateTo!) : '...'}',
                FontAwesomeIcons.calendar,
                Colors.cyan,
                () {
                  setState(() {
                    dateFrom = null;
                    dateTo = null;
                  });
                  _fetchOpportunities();
                  _fetchSummary();
                },
              ),
            if (selectedEmployeeId != null)
              _buildActiveFilterChip(
                employees.firstWhere((e) => e['EmployeeID'] == selectedEmployeeId, orElse: () => {'FullName': ''})['FullName'] ?? '',
                FontAwesomeIcons.userTie,
                Colors.amber,
                () {
                  setState(() => selectedEmployeeId = null);
                  _fetchOpportunities();
                  _fetchSummary();
                },
              ),
            if (selectedAdTypeId != null)
              _buildActiveFilterChip(
                adTypes.firstWhere((a) => a['AdTypeID'] == selectedAdTypeId, orElse: () => {'AdTypeName': ''})['AdTypeName'] ?? '',
                FontAwesomeIcons.bullhorn,
                Colors.purple,
                () {
                  setState(() => selectedAdTypeId = null);
                  _fetchOpportunities();
                  _fetchSummary();
                },
              ),
            if (selectedFollowUpStatus != null)
              _buildActiveFilterChip(
                _getFollowUpStatusText(selectedFollowUpStatus),
                FontAwesomeIcons.clock,
                _getFollowUpStatusColor(selectedFollowUpStatus),
                () {
                  setState(() => selectedFollowUpStatus = null);
                  _fetchOpportunities();
                },
              ),
            if (selectedSourceId != null)
              _buildActiveFilterChip(
                sources.firstWhere((s) => s['SourceID'] == selectedSourceId, orElse: () => {'SourceNameAr': ''})['SourceNameAr'] ?? '',
                FontAwesomeIcons.shareNodes,
                Colors.teal,
                () {
                  setState(() => selectedSourceId = null);
                  _fetchOpportunities();
                  _fetchSummary();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, IconData icon, Color color, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildShimmerBox(40, 40, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmerBox(double.infinity, 16),
                        const SizedBox(height: 8),
                        _buildShimmerBox(100, 12),
                      ],
                    ),
                  ),
                  _buildShimmerBox(60, 24, radius: 12),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildShimmerBox(120, 30, radius: 8),
                  const Spacer(),
                  _buildShimmerBox(100, 30, radius: 8),
                ],
              ),
            ],
          ),
        ).animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.1));
      },
    );
  }

  Widget _buildShimmerBox(double width, double height, {double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
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
        Stack(
          children: [
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.filter, color: Colors.white, size: 18),
              onPressed: _showFilterBottomSheet,
            ),
            if (_activeFiltersCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD700),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_activeFiltersCount',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

// ===================================
// 🎠 Summary Carousel
// ===================================
// ===================================
// 🎠 Summary Carousel (New Design)
// ===================================

Widget _buildSummaryCards() {
  if (summary.isEmpty) return const SizedBox.shrink();
  final stats = summary['stats'] ?? {};
  final topSources = summary['topSources'] as List? ?? [];
  final topCampaigns = summary['topCampaigns'] as List? ?? [];
  
  return Column(
    children: [
      SizedBox(
        height: 200, // ✅ زودنا الارتفاع لـ 200
        child: PageView(
          controller: _summaryPageController,
          onPageChanged: (index) => setState(() => _currentSummaryPage = index),
          children: [
            // 1️⃣ نظرة عامة (الذهب والأسود)
            _buildArtisticCard(
              title: 'نظرة عامة',
              icon: FontAwesomeIcons.chartPie,
              gradientColors: [const Color(0xFF1A1A1A), const Color(0xFF4A4A4A)],
              accentColor: const Color(0xFFFFD700),
              content: Column(
                children: [
                  _buildRow('الكل', '${stats['totalOpportunities'] ?? 0}'),
                  _buildRow('جدد هذا الشهر', '${stats['newThisMonth'] ?? 0}'),
                  const Divider(color: Colors.white24),
                  _buildRow('القيمة المتوقعة', _formatCurrency(stats['totalExpectedValue']), isValueBold: true, valueColor: const Color(0xFFFFD700)),
                ],
              ),
            ),

           // 2️⃣ المتابعة والاهتمام
_buildArtisticCard(
  title: 'المتابعة والاهتمام',
  icon: FontAwesomeIcons.listCheck,
  gradientColors: [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)],
  accentColor: Colors.cyanAccent,
  content: Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('محتمل (Lead)', '${stats['leadCount'] ?? 0}', Colors.white), // ✅ أضفنا ده
          _buildMiniStat('مهتم', '${stats['potentialCount'] ?? 0}', Colors.amber),
          _buildMiniStat('عالي الاهتمام', '${stats['highInterestCount'] ?? 0}', Colors.orangeAccent),
        ],
      ),
      const SizedBox(height: 12),
      const Divider(color: Colors.white10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('اليوم', '${stats['todayCount'] ?? 0}', Colors.greenAccent),
          _buildMiniStat('متأخرة', '${stats['overdueCount'] ?? 0}', Colors.redAccent),
        ],
      ),
    ],
  ),
),

            // 3️⃣ المصادر (البنفسجي والأسود)
            _buildArtisticCard(
              title: 'أهم المصادر',
              icon: FontAwesomeIcons.shareNodes,
              gradientColors: [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)],
              accentColor: Colors.white,
              content: Column(
                children: [
                  if (topSources.isEmpty)
                    const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey)))
                  else
                    ...topSources.take(3).map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          FaIcon(_getSourceIconData(s['name']), color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(s['name'] ?? '', style: GoogleFonts.cairo(color: Colors.white, fontSize: 12)),
                          const Spacer(),
                          Text('${s['count']}', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                ],
              ),
            ),

            // 4️⃣ الأداء (الأخضر والأسود)
            _buildArtisticCard(
              title: 'الأداء والتحويل',
              icon: FontAwesomeIcons.trophy,
              gradientColors: [const Color(0xFF134E5E), const Color(0xFF71B280)],
              accentColor: Colors.lightGreenAccent,
              content: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('مكسبة', '${stats['wonCount'] ?? 0}', Colors.white),
                      _buildMiniStat('خسارة', '${stats['lostCount'] ?? 0}', Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildWinRateBar(stats['wonCount'] ?? 0, (stats['wonCount'] ?? 0) + (stats['lostCount'] ?? 0)),
                ],
              ),
            ),
            // 5️⃣ كارت الحملات الإعلانية
_buildArtisticCard(
  title: 'أهم الحملات',
  icon: FontAwesomeIcons.bullhorn,
  gradientColors: [const Color(0xFF4568DC), const Color(0xFFB06AB3)],
  accentColor: Colors.white,
  content: Column(
    children: [
      if (topCampaigns.isEmpty)
        const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey)))
      else
        ...topCampaigns.take(3).map((c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const FaIcon(FontAwesomeIcons.rectangleAd, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(c['name'] ?? '', style: GoogleFonts.cairo(color: Colors.white, fontSize: 12)),
              const Spacer(),
              Text('${c['count']}', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        )),
    ],
  ),
),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // المؤشر (Dots)
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) => AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), height: 6, width: _currentSummaryPage == index ? 24 : 6, decoration: BoxDecoration(color: _currentSummaryPage == index ? const Color(0xFFFFD700) : Colors.grey[800], borderRadius: BorderRadius.circular(3)))),
      ),
      const SizedBox(height: 20),
    ],
  );
}

// 🔧 دوال التصميم الجديدة

Widget _buildArtisticCard({
  required String title,
  required IconData icon,
  required List<Color> gradientColors,
  required Color accentColor,
  required Widget content,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: FaIcon(icon, size: 14, color: accentColor),
            ),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.cairo(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: content),
      ],
    ),
  );
}

Widget _buildRow(String label, String value, {bool isValueBold = false, Color valueColor = Colors.white}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
        Text(value, style: GoogleFonts.cairo(color: valueColor, fontSize: 15, fontWeight: isValueBold ? FontWeight.bold : FontWeight.normal)),
      ],
    ),
  );
}

Widget _buildMiniStat(String label, String value, Color color) {
  return Column(
    children: [
      Text(value, style: GoogleFonts.cairo(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11)),
    ],
  );
}

// 🔧 الدوال المساعدة للكروت

Widget _buildSummaryCard({
  required String title,
  required IconData icon,
  required Gradient gradient,
  required Color borderColor,
  required List<Widget> children,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor.withOpacity(0.3), width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: borderColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: FaIcon(icon, size: 14, color: borderColor),
            ),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

Widget _buildSummaryRow(String label, String value, IconData icon, Color color, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        FaIcon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13)),
        const Spacer(),
        Text(value, style: GoogleFonts.cairo(color: isBold ? color : Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

Widget _buildSummaryItem(String label, String value, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: GoogleFonts.cairo(color: color, fontSize: 12)),
    ],
  );
}

Widget _buildWinRateBar(int won, int total) {
  double rate = total == 0 ? 0 : (won / total);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('نسبة النجاح', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
          Text('${(rate * 100).toStringAsFixed(1)}%', style: GoogleFonts.cairo(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
      const SizedBox(height: 8),
      Stack(
        children: [
          Container(height: 8, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
          FractionallySizedBox(widthFactor: rate, child: Container(height: 8, decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)))),
        ],
      ),
    ],
  );
}

// 🔧 دالة لجلب أيقونة المصدر
IconData _getSourceIconData(String? sourceName) {
  final name = (sourceName ?? '').toLowerCase();
  if (name.contains('whatsapp') || name.contains('واتساب')) return FontAwesomeIcons.whatsapp;
  if (name.contains('facebook') || name.contains('فيسبوك')) return FontAwesomeIcons.facebook;
  if (name.contains('instagram') || name.contains('انستجرام')) return FontAwesomeIcons.instagram;
  if (name.contains('tiktok') || name.contains('تيك توك')) return FontAwesomeIcons.tiktok;
  if (name.contains('phone') || name.contains('هاتف') || name.contains('تليفون')) return FontAwesomeIcons.phone;
  if (name.contains('google') || name.contains('جوجل')) return FontAwesomeIcons.google;
  return FontAwesomeIcons.shareNodes;
}

  Widget _buildMiniSummaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          FaIcon(icon, color: color, size: 14),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                setState(() => searchQuery = value);
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                  _fetchOpportunities();
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: sortBy != null
                  ? const Color(0xFFFFD700).withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: sortBy != null
                  ? Border.all(color: const Color(0xFFFFD700).withOpacity(0.5))
                  : null,
            ),
            child: IconButton(
              icon: FaIcon(
                FontAwesomeIcons.arrowDownWideShort,
                color: sortBy != null ? const Color(0xFFFFD700) : Colors.grey,
                size: 18,
              ),
              onPressed: _showSortBottomSheet,
            ),
          ),
        ],
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

    return Dismissible(
      key: Key(opportunity['OpportunityID'].toString()),
      background: _buildSwipeBackground(Colors.green, FontAwesomeIcons.phone, 'اتصال', Alignment.centerRight),
      secondaryBackground: _buildSwipeBackground(const Color(0xFF25D366), FontAwesomeIcons.whatsapp, 'واتساب', Alignment.centerLeft),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _makePhoneCall(opportunity['Phone1']);
        } else {
          _openWhatsApp(opportunity['Phone1']);
        }
        return false;
      },
      child: Container(
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
                // الصف الأول: اسم العميل + الحالة (يسار) | رقم التليفون (يمين)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
      Row(
        children: [
          Flexible(
            child: Text(
              opportunity['ClientName'] ?? 'بدون اسم',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isNewOpportunity(opportunity['CreatedAt'])) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Text(
                '🆕 جديد',
                style: GoogleFonts.cairo(
                  color: Colors.green,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
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
                  ],
                ),

                const SizedBox(height: 12),
                Divider(color: Colors.grey.withOpacity(0.2), height: 1),
                const SizedBox(height: 12),
                
                // ✅ الصف الجديد: أول تواصل + آخر تواصل
Row(
  children: [
    Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.cyan.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.calendarPlus, color: Colors.cyan, size: 12),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'أول تواصل: ${_formatDateShort(opportunity['FirstContactDate'])}',
                style: GoogleFonts.cairo(color: Colors.cyan, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.clockRotateLeft, color: Colors.amber, size: 12),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'آخر تواصل: ${_formatDaysAgo(opportunity['LastContactDate'])}',
                style: GoogleFonts.cairo(color: Colors.amber, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  ],
),
                // الصف الثاني: صاحب الفرصة + عدد التواصلات + حالة المتابعة
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.userTie, color: Color(0xFFFFD700), size: 12),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        opportunity['EmployeeName'] ?? 'غير محدد',
                        style: GoogleFonts.cairo(color: const Color(0xFFFFD700), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const FaIcon(FontAwesomeIcons.comments, color: Colors.blue, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            '${opportunity['InteractionCount'] ?? 0}',
                            style: GoogleFonts.cairo(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (followUpStatus != null && followUpStatus != 'NotSet') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: followUpColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
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
                  ],
                ),

                const SizedBox(height: 10),

                // الصف الثالث: المصدر + الحملة الإعلانية
                Row(
                  children: [
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
                            _getSourceIcon(opportunity['SourceName'], size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                opportunity['SourceNameAr'] ?? opportunity['SourceName'] ?? '',
                                style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(FontAwesomeIcons.bullhorn, color: Colors.purple, size: 12),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                opportunity['AdTypeName'] ?? 'بدون حملة',
                                style: GoogleFonts.cairo(color: Colors.purple[200], fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // الصف الرابع: القيمة + المنتج
                Row(
                  children: [
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
                              _formatCurrency(opportunity['ExpectedValue']),
                              style: GoogleFonts.cairo(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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

                const SizedBox(height: 12),

                // Quick Actions
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: FontAwesomeIcons.phone,
                        label: 'اتصال',
                        color: Colors.green,
                        onTap: () => _makePhoneCall(opportunity['Phone1']),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: FontAwesomeIcons.whatsapp,
                        label: 'واتساب',
                        color: const Color(0xFF25D366),
                        onTap: () => _openWhatsApp(opportunity['Phone1']),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: FontAwesomeIcons.circleInfo,
                        label: 'تفاصيل',
                        color: const Color(0xFFFFD700),
                        onTap: () => _openOpportunityDetails(opportunity),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildSwipeBackground(Color color, IconData icon, String label, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Text(label, style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
          ],
          FaIcon(icon, color: color, size: 24),
          if (alignment == Alignment.centerRight) ...[
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
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

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
                const FaIcon(FontAwesomeIcons.arrowDownWideShort, color: Color(0xFFFFD700), size: 18),
                const SizedBox(width: 10),
                Text(
                  'ترتيب حسب',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSortOption('newest', 'الأحدث أولاً', FontAwesomeIcons.arrowDown),
            _buildSortOption('oldest', 'الأقدم أولاً', FontAwesomeIcons.arrowUp),
            _buildSortOption('value_high', 'القيمة (الأعلى)', FontAwesomeIcons.arrowUp),
            _buildSortOption('value_low', 'القيمة (الأقل)', FontAwesomeIcons.arrowDown),
            _buildSortOption('name', 'الاسم (أ → ي)', FontAwesomeIcons.arrowDownAZ),
            _buildSortOption('stage', 'حسب المرحلة', FontAwesomeIcons.stairs),
            const SizedBox(height: 10),
            if (sortBy != null)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => sortBy = null);
                    Navigator.pop(context);
                    _fetchOpportunities();
                  },
                  icon: const FaIcon(FontAwesomeIcons.rotateLeft, size: 14, color: Colors.grey),
                  label: Text('إزالة الترتيب', style: GoogleFonts.cairo(color: Colors.grey)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon) {
    final isSelected = sortBy == value;
    return ListTile(
      leading: FaIcon(icon, color: isSelected ? const Color(0xFFFFD700) : Colors.grey, size: 16),
      title: Text(
        label,
        style: GoogleFonts.cairo(
          color: isSelected ? const Color(0xFFFFD700) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const FaIcon(FontAwesomeIcons.check, color: Color(0xFFFFD700), size: 16) : null,
      onTap: () {
        setState(() => sortBy = value);
        Navigator.pop(context);
        _fetchOpportunities();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: isSelected ? const Color(0xFFFFD700).withOpacity(0.1) : null,
    );
  }

  // ✅ الفلتر المتقدم مع التاريخ
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
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
              const SizedBox(height: 24),

              // ✅ قسم التاريخ (من - إلى)
              Text('الفترة الزمنية', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true, setModalState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: dateFrom != null 
                                ? const Color(0xFFFFD700).withOpacity(0.5) 
                                : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.calendarDay, 
                              size: 14, 
                              color: dateFrom != null ? const Color(0xFFFFD700) : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dateFrom != null ? _formatDate(dateFrom!) : 'من تاريخ',
                                style: GoogleFonts.cairo(
                                  color: dateFrom != null ? Colors.white : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (dateFrom != null)
                              InkWell(
                                onTap: () => setModalState(() => dateFrom = null),
                                child: const Icon(Icons.close, size: 16, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const FaIcon(FontAwesomeIcons.arrowRight, size: 12, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false, setModalState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: dateTo != null 
                                ? const Color(0xFFFFD700).withOpacity(0.5) 
                                : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.calendarCheck, 
                              size: 14, 
                              color: dateTo != null ? const Color(0xFFFFD700) : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dateTo != null ? _formatDate(dateTo!) : 'إلى تاريخ',
                                style: GoogleFonts.cairo(
                                  color: dateTo != null ? Colors.white : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (dateTo != null)
                              InkWell(
                                onTap: () => setModalState(() => dateTo = null),
                                child: const Icon(Icons.close, size: 16, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ✅ اختصارات سريعة للتاريخ
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDateQuickChip('اليوم', () {
                      setModalState(() {
                        dateFrom = DateTime.now();
                        dateTo = DateTime.now();
                      });
                    }),
                    _buildDateQuickChip('آخر 7 أيام', () {
                      setModalState(() {
                        dateTo = DateTime.now();
                        dateFrom = DateTime.now().subtract(const Duration(days: 7));
                      });
                    }),
                    _buildDateQuickChip('آخر 30 يوم', () {
                      setModalState(() {
                        dateTo = DateTime.now();
                        dateFrom = DateTime.now().subtract(const Duration(days: 30));
                      });
                    }),
                    _buildDateQuickChip('هذا الشهر', () {
                      setModalState(() {
                        dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
                        dateTo = DateTime.now();
                      });
                    }),
                    _buildDateQuickChip('الشهر الماضي', () {
                      setModalState(() {
                        dateFrom = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
                        dateTo = DateTime(DateTime.now().year, DateTime.now().month, 0);
                      });
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // قسم الموظف - Dropdown
              Text('الموظف المسؤول', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: selectedEmployeeId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A2A2A),
                    hint: Text('اختر الموظف', style: GoogleFonts.cairo(color: Colors.grey)),
                    icon: const FaIcon(FontAwesomeIcons.chevronDown, color: Colors.grey, size: 14),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('الكل', style: GoogleFonts.cairo(color: Colors.white)),
                      ),
                      ...employees.map((e) => DropdownMenuItem<int?>(
                            value: e['EmployeeID'],
                            child: Text(e['FullName'] ?? '', style: GoogleFonts.cairo(color: Colors.white)),
                          )),
                    ],
                    onChanged: (value) {
                      setModalState(() => selectedEmployeeId = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // قسم الحملة الإعلانية - Dropdown
              Text('الحملة الإعلانية', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: selectedAdTypeId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2A2A2A),
                    hint: Text('اختر الحملة', style: GoogleFonts.cairo(color: Colors.grey)),
                    icon: const FaIcon(FontAwesomeIcons.chevronDown, color: Colors.grey, size: 14),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('الكل', style: GoogleFonts.cairo(color: Colors.white)),
                      ),
                      ...adTypes.map((a) => DropdownMenuItem<int?>(
                            value: a['AdTypeID'],
                            child: Text(a['AdTypeName'] ?? '', style: GoogleFonts.cairo(color: Colors.white)),
                          )),
                    ],
                    onChanged: (value) {
                      setModalState(() => selectedAdTypeId = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // حالة المتابعة - Chips
              Text('حالة المتابعة', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFollowUpChip('الكل', null, Colors.grey, setModalState),
                  _buildFollowUpChip('متأخرة', 'Overdue', Colors.red, setModalState),
                  _buildFollowUpChip('اليوم', 'Today', Colors.orange, setModalState),
                  _buildFollowUpChip('غداً', 'Tomorrow', Colors.blue, setModalState),
                  _buildFollowUpChip('قادم', 'Upcoming', Colors.green, setModalState),
                ],
              ),
              const SizedBox(height: 20),

              // المصدر - Chips
              Text('المصدر', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSourceChip(null, 'الكل', setModalState),
                  ...sources.map((source) => _buildSourceChip(
                        source['SourceID'],
                        source['SourceNameAr'] ?? source['SourceName'],
                        setModalState,
                      )),
                ],
              ),
              const SizedBox(height: 24),

              // زر تطبيق الفلتر
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                    _fetchOpportunities();
                    _fetchSummary();
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
                      selectedAdTypeId = null;
                      selectedEmployeeId = null;
                      dateFrom = null;
                      dateTo = null;
                    });
                    setState(() {
                      selectedFollowUpStatus = null;
                      selectedSourceId = null;
                      selectedStageId = null;
                      selectedAdTypeId = null;
                      selectedEmployeeId = null;
                      dateFrom = null;
                      dateTo = null;
                      sortBy = null;
                    });
                    Navigator.pop(context);
                    _fetchOpportunities();
                    _fetchSummary();
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

  Widget _buildDateQuickChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.cyan.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyan.withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(color: Colors.cyan, fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowUpChip(String label, String? value, Color color, StateSetter setModalState) {
    final isSelected = selectedFollowUpStatus == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.cairo(
          color: isSelected ? Colors.black : Colors.white,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() => selectedFollowUpStatus = selected ? value : null);
      },
      backgroundColor: color.withOpacity(0.2),
      selectedColor: color,
      checkmarkColor: Colors.black,
      side: BorderSide(color: color.withOpacity(0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildSourceChip(int? sourceId, String label, StateSetter setModalState) {
    final isSelected = selectedSourceId == sourceId;

    String? sourceName;
    if (sourceId != null) {
      final source = sources.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['SourceID'] == sourceId,
        orElse: () => <String, dynamic>{},
      );
      sourceName = source['SourceName'] ?? source['SourceNameAr'];
    }

    return FilterChip(
      avatar: sourceId != null ? _getSourceIcon(sourceName, size: 14) : null,
      label: Text(
        label,
        style: GoogleFonts.cairo(
          color: isSelected ? Colors.black : Colors.white,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() => selectedSourceId = selected ? sourceId : null);
      },
      backgroundColor: Colors.grey[800],
      selectedColor: const Color(0xFFFFD700),
      checkmarkColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _openOpportunityDetails(dynamic opportunity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OpportunityDetailsScreen(
          opportunity: opportunity,
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  void _addNewOpportunity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddOpportunityScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }
}