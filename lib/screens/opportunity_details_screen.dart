import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // إضافة مهمة
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../services/opportunities_service.dart';
import 'add_interaction_screen.dart';
import 'add_opportunity_screen.dart';

class OpportunityDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> opportunity;
  final int userId;
  final String username;

  const OpportunityDetailsScreen({
    super.key,
    required this.opportunity,
    required this.userId,
    required this.username,
  });

  @override
  State<OpportunityDetailsScreen> createState() => _OpportunityDetailsScreenState();
}

class _OpportunityDetailsScreenState extends State<OpportunityDetailsScreen> {
  final _service = OpportunitiesService();
  List<dynamic> timeline = [];
  bool _isLoading = true;
  late Map<String, dynamic> currentOpp;
  int _selectedTab = 0;
  final _pageController = PageController();
  bool _dateFormattingInitialized = false;

  @override
  void initState() {
    super.initState();
    currentOpp = widget.opportunity;
    _loadTimeline();
    // تهيئة تنسيق التاريخ بشكل آمن
    _initializeDateFormatting();
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('ar_SA', null);
    setState(() {
      _dateFormattingInitialized = true;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTimeline() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getOpportunityTimeline(currentOpp['OpportunityID']);
      if (mounted) setState(() { timeline = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('20')) cleanPhone = '20$cleanPhone';
    final uri = Uri.parse('whatsapp://send?phone=$cleanPhone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
    else await launchUrl(Uri.parse('https://wa.me/$cleanPhone'), mode: LaunchMode.externalApplication);
  }

  Future<void> _shareOpportunity() async {
    final String shareText = '''
🏢 **فرصة بيع - ${currentOpp['ClientName']}** 📈
📞 ${currentOpp['Phone1'] ?? ''}
📦 المنتج: ${currentOpp['InterestedProduct'] ?? '-'}
💰 القيمة المتوقعة: ${currentOpp['ExpectedValue'] ?? '0'} ج.م
📍 المرحلة: ${currentOpp['StageNameAr'] ?? '-'}
👤 الموظف المسؤول: ${currentOpp['EmployeeName'] ?? '-'}
📅 تاريخ الإضافة: ${_formatDate(currentOpp['CreatedAt'])}
💼 ${currentOpp['Notes'] != null && currentOpp['Notes']!.toString().isNotEmpty ? 'ملاحظات: ${currentOpp['Notes']}' : ''}
    ''';
    
    await Share.share(shareText, subject: 'تفاصيل فرصة البيع');
  }

  Color _getStageColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return Colors.grey;
    try { return Color(int.parse(colorHex.replaceFirst('#', '0xFF'))); } catch (e) { return Colors.grey; }
  }

  Color _getStatusColor(String? status) {
    final statusName = (status ?? '').toLowerCase();
    if (statusName.contains('مكتمل') || statusName.contains('closed')) return Colors.green;
    if (statusName.contains('معلق') || statusName.contains('pending')) return Colors.orange;
    if (statusName.contains('ملغي') || statusName.contains('cancelled')) return Colors.red;
    return Colors.blue;
  }

  Widget _buildSourceIcon(String? sourceName) {
    String name = (sourceName ?? '').toLowerCase();
    IconData icon = FontAwesomeIcons.globe;
    Color color = Colors.grey;
    
    if (name.contains('facebook') || name.contains('فيسبوك')) { 
      icon = FontAwesomeIcons.facebook; 
      color = const Color(0xFF1877F2); 
    } else if (name.contains('whatsapp') || name.contains('واتساب')) { 
      icon = FontAwesomeIcons.whatsapp; 
      color = const Color(0xFF25D366); 
    } else if (name.contains('instagram') || name.contains('انستجرام')) { 
      icon = FontAwesomeIcons.instagram; 
      color = const Color(0xFFE4405F); 
    } else if (name.contains('tiktok') || name.contains('تيك توك')) { 
      icon = FontAwesomeIcons.tiktok; 
      color = Colors.white; 
    } else if (name.contains('google') || name.contains('جوجل')) { 
      icon = FontAwesomeIcons.google; 
      color = const Color(0xFFDB4437); 
    } else if (name.contains('phone') || name.contains('هاتف') || name.contains('مكالمة')) {
      icon = FontAwesomeIcons.phone;
      color = Colors.green;
    } else if (name.contains('referral') || name.contains('ترشيح')) {
      icon = FontAwesomeIcons.userGroup;
      color = Colors.orange;
    }
    
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: FaIcon(icon, color: color, size: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_dateFormattingInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: const Color(0xFFFFD700)),
              const SizedBox(height: 20),
              Text('جاري التحميل...', style: GoogleFonts.cairo(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    Color stageColor = _getStageColor(currentOpp['StageColor']);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Column(
        children: [
          // 🔹 الهيدر المميز مع التبويبات
          _buildEnhancedHeader(stageColor),
          
          // 🔹 التبويبات
          _buildTabBar(),
          
          // 🔹 المحتوى المتغير
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _selectedTab = index),
              children: [
                // تبويب التفاصيل
                _buildDetailsTab(),
                // تبويب النشاطات
                _buildActivitiesTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  // 🔹 الهيدر المحسن مع الجرافيكس
  Widget _buildEnhancedHeader(Color stageColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            stageColor.withOpacity(0.3),
            const Color(0xFF1A1A1A),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔸 الصف العلوي (الأزرار)
              Row(
                children: [
                  _buildHeaderButton(
                    icon: Icons.arrow_back_ios,
                    color: Colors.white,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _buildHeaderButton(
                    icon: Icons.share,
                    color: const Color(0xFFFFD700),
                    onTap: _shareOpportunity,
                  ),
                  const SizedBox(width: 10),
                  _buildHeaderButton(
                    icon: FontAwesomeIcons.penToSquare,
                    color: Colors.blue,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddOpportunityScreen(
                            userId: widget.userId,
                            username: widget.username,
                            opportunityToEdit: currentOpp,
                          ),
                        ),
                      );
                      if (result == true) Navigator.pop(context);
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 🔸 معلومات العميل
              Row(
                children: [
                  // صورة العميل (أو أحرف أولى)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [stageColor, stageColor.withOpacity(0.5)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(currentOpp['ClientName'] ?? 'CL'),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 15),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentOpp['ClientName'] ?? 'بدون اسم',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 5),
                        
                        Row(
                          children: [
                            _buildContactChip(
                              icon: FontAwesomeIcons.phone,
                              text: currentOpp['Phone1'] ?? '',
                              color: Colors.green,
                              onTap: () => _makePhoneCall(currentOpp['Phone1']),
                            ),
                            
                            if (currentOpp['Phone2'] != null && currentOpp['Phone2'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _buildContactChip(
                                  icon: FontAwesomeIcons.phone,
                                  text: currentOpp['Phone2'].toString(),
                                  color: Colors.blue,
                                  onTap: () => _makePhoneCall(currentOpp['Phone2']),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 🔸 الإحصائيات السريعة
              Row(
                children: [
                  _buildStatCard(
                    value: '${currentOpp['ExpectedValue'] ?? '0'}',
                    label: 'القيمة المتوقعة',
                    icon: FontAwesomeIcons.coins,
                    color: const Color(0xFFFFD700),
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    value: timeline.length.toString(),
                    label: 'التواصلات',
                    icon: FontAwesomeIcons.comments,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    value: _formatDate(currentOpp['CreatedAt']),
                    label: 'منذ',
                    icon: FontAwesomeIcons.calendar,
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  Widget _buildHeaderButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: FaIcon(icon, size: 18, color: color),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildContactChip({required IconData icon, required String text, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.cairo(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required String value, required String label, required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: FaIcon(icon, size: 14, color: color)),
                ),
                const Spacer(),
                if (label == 'القيمة المتوقعة')
                  Text('ج.م', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.cairo(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Row(
        children: [
          _buildTabItem('تفاصيل الفرصة', 0),
          _buildTabItem('سجل التواصلات', 1),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.cairo(
                color: isSelected ? const Color(0xFFFFD700) : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔸 معلومات الفرصة
          _buildDetailSection('معلومات الفرصة', FontAwesomeIcons.infoCircle, [
            _buildDetailRow('المنتج المهتم به', currentOpp['InterestedProduct'] ?? '-', FontAwesomeIcons.box),
            _buildDetailRow('الموقع', currentOpp['Location'] ?? '-', FontAwesomeIcons.locationDot),
            _buildDetailRow('فئة الاهتمام', currentOpp['CategoryNameAr'] ?? '-', FontAwesomeIcons.tags),
          ]),
          
          const SizedBox(height: 20),
          
          // 🔸 الحالة والمتابعة
          _buildDetailSection('الحالة والمتابعة', FontAwesomeIcons.timeline, [
            _buildStatusRow('المرحلة', currentOpp['StageNameAr'] ?? '-', _getStageColor(currentOpp['StageColor'])),
            _buildStatusRow('حالة التواصل', currentOpp['StatusNameAr'] ?? '-', _getStatusColor(currentOpp['StatusNameAr'])),
            if (currentOpp['NextFollowUpDate'] != null)
              _buildDetailRow('موعد المتابعة', _formatDate(currentOpp['NextFollowUpDate']), FontAwesomeIcons.calendarCheck),
          ]),
          
          const SizedBox(height: 20),
          
          // 🔸 معلومات التواصل
          _buildDetailSection('معلومات التواصل', FontAwesomeIcons.shareAlt, [
            _buildSourceRow(),
            _buildDetailRow('نوع الإعلان', currentOpp['AdTypeNameAr'] ?? '-', FontAwesomeIcons.bullhorn),
            _buildDetailRow('الموظف المسؤول', currentOpp['EmployeeName'] ?? '-', FontAwesomeIcons.userTie),
          ]),
          
          const SizedBox(height: 20),
          
          // 🔸 الملاحظات
          if (currentOpp['Notes'] != null && currentOpp['Notes'].toString().isNotEmpty)
            _buildNotesSection(),
            
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: FaIcon(icon, color: const Color(0xFFFFD700), size: 16)),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: FaIcon(icon, size: 14, color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: FaIcon(FontAwesomeIcons.circle, size: 14, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.cairo(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceRow() {
    String sourceName = currentOpp['SourceNameAr'] ?? currentOpp['SourceName'] ?? '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _buildSourceIcon(sourceName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المصدر', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  sourceName,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: FaIcon(FontAwesomeIcons.noteSticky, size: 16, color: Colors.amber)),
              ),
              const SizedBox(width: 12),
              Text('ملاحظات', style: GoogleFonts.cairo(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              currentOpp['Notes']!,
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
        : timeline.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FontAwesomeIcons.calendarXmark, size: 50, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 20),
                    Text('لا يوجد سجل تواصل', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 10),
                    Text('ابدأ بإضافة أول تواصل', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFFFFD700),
                backgroundColor: const Color(0xFF1A1A1A),
                onRefresh: _loadTimeline,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: timeline.length,
                  itemBuilder: (context, index) => _buildTimelineCard(timeline[index]),
                ),
              );
  }

  Widget _buildTimelineCard(dynamic item) {
    final date = DateTime.parse(item['InteractionDate']);
    final bool hasStageChange = item['StageBefore'] != null && 
                               item['StageAfter'] != null && 
                               item['StageBefore'] != item['StageAfter'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔸 هيدر البطاقة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // التاريخ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('dd').format(date),
                        style: GoogleFonts.cairo(
                          color: const Color(0xFFFFD700),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getArabicMonth(date),
                        style: GoogleFonts.cairo(
                          color: const Color(0xFFFFD700).withOpacity(0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTimelineDate(date),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'بواسطة: ${item['EmployeeName'] ?? 'النظام'}',
                        style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                
                if (item['SourceName'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildSourceIcon(item['SourceName']),
                        const SizedBox(width: 8),
                        Text(
                          item['SourceName'],
                          style: GoogleFonts.cairo(
                            color: const Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // 🔸 محتوى البطاقة
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ملخص التواصل
                Text(
                  item['Summary'] ?? 'لا توجد تفاصيل',
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                ),
                
                // تغيير المرحلة
                if (hasStageChange) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.arrowRightArrowLeft, size: 14, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تغيير المرحلة',
                                style: GoogleFonts.cairo(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item['StageBefore']!,
                                      style: GoogleFonts.cairo(color: Colors.blue[200], fontSize: 11),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: FaIcon(FontAwesomeIcons.arrowRight, size: 12, color: Colors.grey),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item['StageAfter']!,
                                      style: GoogleFonts.cairo(color: Colors.green[200], fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // الملاحظات
                if (item['Notes'] != null && item['Notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FaIcon(FontAwesomeIcons.stickyNote, size: 12, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text('ملاحظة', style: GoogleFonts.cairo(color: Colors.amber, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['Notes']!,
                          style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // زر إضافة تواصل
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddInteractionScreen(
                    userId: widget.userId,
                    username: widget.username,
                    preSelectedPartyId: currentOpp['PartyID'],
                    preSelectedOpportunityId: currentOpp['OpportunityID'],
                  ),
                ),
              );
              if (result == true) _loadTimeline();
            },
            backgroundColor: const Color(0xFFFFD700),
            icon: const FaIcon(FontAwesomeIcons.commentMedical, color: Colors.black, size: 16),
            label: Text('تواصل جديد', style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
        
        // زر الاتصال المباشر
        FloatingActionButton(
          onPressed: () => _makePhoneCall(currentOpp['Phone1']),
          backgroundColor: Colors.green,
          child: const FaIcon(FontAwesomeIcons.phone, color: Colors.white),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) return 'اليوم';
      if (difference.inDays == 1) return 'أمس';
      if (difference.inDays < 7) return 'منذ ${difference.inDays} أيام';
      if (difference.inDays < 30) return 'منذ ${difference.inDays ~/ 7} أسابيع';
      if (difference.inDays < 365) return 'منذ ${difference.inDays ~/ 30} أشهر';
      
      // استخدام تنسيق تاريخ بدون locale
      return '${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return '-';
    }
  }

  String _formatTimelineDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    final timeStr = DateFormat('h:mm a', 'en').format(date); // استخدام انجليزي للوقت
    
    if (dateOnly == today) {
      return 'اليوم، $timeStr';
    } else if (dateOnly == yesterday) {
      return 'أمس، $timeStr';
    } else {
      // استخدام أسماء الأشهر العربية يدوياً
      final monthName = _getArabicMonth(date);
      final dayName = _getArabicDayName(date.weekday);
      return '$dayName، ${date.day} $monthName، $timeStr';
    }
  }

  String _getArabicMonth(DateTime date) {
    final months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[date.month];
  }

  String _getArabicDayName(int weekday) {
    final days = ['', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[weekday];
  }
}