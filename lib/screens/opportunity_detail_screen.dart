import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/icon_utils.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/pipeline_service.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import 'add_interaction_screen.dart';
import 'add_opportunity_screen.dart';

class OpportunityDetailScreen extends StatefulWidget {
  final int opportunityId;
  final int userId;
  final String username;

  const OpportunityDetailScreen({
    Key? key,
    required this.opportunityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  Map<String, dynamic>? _opportunity;
  List<dynamic> _interactions = [];
  List<dynamic> _stages = [];
  bool _isLoading = true;
  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        PipelineService.getOpportunityById(widget.opportunityId),
        PipelineService.getInteractions(widget.opportunityId),
        PipelineService.getStages(),
      ]);
      setState(() {
        _opportunity = results[0] as Map<String, dynamic>?;
        _interactions = results[1] as List<dynamic>;
        _stages = results[2] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════
  //  🔍 هل الفرصة خسارة؟
  // ═══════════════════════════════════
  bool get _isLost {
    if (_opportunity == null) return false;

    final stageName =
        (_opportunity!['StageNameAr'] ?? '').toString().toLowerCase();
    final stageNameEn =
        (_opportunity!['StageName'] ?? '').toString().toLowerCase();
    final status =
        (_opportunity!['Status'] ?? '').toString().toLowerCase();

    return stageName.contains('خسارة') ||
        stageName.contains('خسار') ||
        stageName.contains('مغلق') ||
        stageNameEn.contains('lost') ||
        stageNameEn.contains('closed lost') ||
        status.contains('lost') ||
        status.contains('خسارة');
  }

  // ═══════════════════════════════════
  //  📝 سبب الخسارة
  // ═══════════════════════════════════
    String get _lossReason {
    if (_opportunity == null) return '';

    // سبب الخسارة من جدول LostReasons
    final reasonName = _opportunity!['LostReasonNameAr'] ??
        _opportunity!['LostReasonName'] ??
        '';

    // ملاحظات الخسارة من عمود LostNotes
    final lostNotes = (_opportunity!['LostNotes'] ?? '').toString().trim();

    // تجميع السبب + الملاحظات
    String result = reasonName.toString().trim();

    if (result.isNotEmpty && lostNotes.isNotEmpty) {
      result += '\n📝 $lostNotes';
    } else if (result.isEmpty && lostNotes.isNotEmpty) {
      result = lostNotes;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final stageColor =
        _hexToColor(_opportunity?['StageColor'] ?? '#DBBF74');

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          // ✅ تغيير: عنوان ثابت بدل اسم العميل
          backgroundColor: _isLost
              ? (_isDark ? const Color(0xFF3D1515) : Colors.red[700])
              : (_isDark ? AppColors.navy : stageColor),
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isLost ? Icons.cancel_rounded : Icons.assignment_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isLost ? 'فرصة خاسرة' : 'تفاصيل الفرصة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            if (_opportunity != null)
              IconButton(
                icon:
                    const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: _openEditOpportunity,
                tooltip: 'تعديل الفرصة',
              ),
          ],
        ),
        body: _isLoading
            ? Center(
                child:
                    CircularProgressIndicator(color: AppColors.gold))
            : _opportunity == null
                ? _buildErrorView()
                : RefreshIndicator(
                    color: AppColors.gold,
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // ✅ بانر الخسارة لو الحالة خسارة
                          if (_isLost) ...[
                            _buildLossBanner(),
                            const SizedBox(height: 16),
                          ],
                          _buildStatusHeader(),
                          const SizedBox(height: 16),
                          _buildClientInfo(),
                          const SizedBox(height: 16),
                          _buildOpportunityInfo(),
                          const SizedBox(height: 16),
                          _buildInteractionTimeline(),
                          const SizedBox(height: 16),
                          _buildActionButtons(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // ═══════════════════════════════════
  //  🔴 بانر الخسارة
  // ═══════════════════════════════════
  Widget _buildLossBanner() {
    final reason = _lossReason;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDark
              ? [
                  const Color(0xFF3D1515),
                  const Color(0xFF2A0E0E),
                ]
              : [
                  Colors.red.shade50,
                  Colors.red.shade100,
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark
              ? Colors.red.withOpacity(0.4)
              : Colors.red.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(_isDark ? 0.2 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── أيقونة وعنوان ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(_isDark ? 0.3 : 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cancel_rounded,
                  color: _isDark ? Colors.red[300] : Colors.red[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تم خسارة هذه الفرصة',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isDark
                          ? Colors.red[300]
                          : Colors.red[800],
                    ),
                  ),
                  Text(
                    'الفرصة مغلقة ولم تتحول لصفقة',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: _isDark
                          ? Colors.red[200]?.withOpacity(0.7)
                          : Colors.red[600],
                    ),
                  ),
                ],
              ),
            ],
          ),

                   // ── سبب الخسارة ──
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDark
                    ? Colors.red.withOpacity(0.1)
                    : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // سبب الخسارة الرئيسي
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: _isDark
                            ? Colors.red[300]
                            : Colors.red[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سبب الخسارة:',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isDark
                                    ? Colors.red[300]
                                    : Colors.red[800],
                              ),
                            ),
                            const SizedBox(height: 2),
                            // ✅ بنعرض السبب (ممكن يكون فيه سطرين لو فيه ملاحظات)
                            ...reason.split('\n').map((line) {
                              final isNote = line.startsWith('📝');
                              return Padding(
                                padding: EdgeInsets.only(top: isNote ? 8 : 0),
                                child: Text(
                                  line,
                                  style: GoogleFonts.cairo(
                                    fontSize: isNote ? 13 : 14,
                                    color: _isDark
                                        ? (isNote ? Colors.orange[200] : Colors.red[200])
                                        : (isNote ? Colors.orange[900] : Colors.red[900]),
                                    fontWeight: isNote ? FontWeight.normal : FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isDark
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم يتم تسجيل سبب الخسارة',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.orange[700],
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

  // ═══════════════════════════════════
  //  ✏️ فتح شاشة تعديل الفرصة
  // ═══════════════════════════════════
  void _openEditOpportunity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddOpportunityScreen(
          userId: widget.userId,
          username: widget.username,
          opportunityToEdit: _opportunity,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  // ═══════════════════════════════════
  //  💬 فتح شاشة تسجيل تواصل
  // ═══════════════════════════════════
  void _openAddInteraction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInteractionScreen(
          userId: widget.userId,
          username: widget.username,
          preSelectedPartyId: _opportunity!['PartyID'],
          preSelectedOpportunityId: _opportunity!['OpportunityID'],
        ),
      ),
    );
    if (result == true) _loadData();
  }

  // ═══════════════════════════════════
  //  🔵 هيدر الحالة
  // ═══════════════════════════════════
  Widget _buildStatusHeader() {
    final stageNameAr = _opportunity!['StageNameAr'] ?? '';
    final stageColor =
        _hexToColor(_opportunity!['StageColor'] ?? '#3498db');
    final followUpDate = _opportunity!['NextFollowUpDate'];

    String followUpText = 'غير محدد';
    Color followUpColor = AppColors.textHint(_isDark);
    IconData followUpIcon = Icons.remove_circle_outline;

    if (followUpDate != null) {
      try {
        final dt = DateTime.parse(followUpDate);
        final now = DateTime.now();
        final diff = dt
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;
        if (diff < 0) {
          followUpText = 'متأخر ${diff.abs()} يوم';
          followUpColor = Colors.red;
          followUpIcon = Icons.warning_amber_rounded;
        } else if (diff == 0) {
          followUpText = 'اليوم';
          followUpColor = Colors.orange;
          followUpIcon = Icons.today_rounded;
        } else if (diff == 1) {
          followUpText = 'غداً';
          followUpColor = Colors.blue;
          followUpIcon = Icons.event_rounded;
        } else {
          followUpText = 'بعد $diff يوم';
          followUpColor = Colors.green;
          followUpIcon = Icons.upcoming_rounded;
        }
      } catch (_) {}
    }

    // ✅ لو خسارة → لون مختلف للهيدر
    final headerColor = _isLost ? Colors.red : stageColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDark
              ? [
                  AppColors.darkCard,
                  headerColor.withOpacity(0.3),
                ]
              : [headerColor, headerColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: _isDark
            ? Border.all(color: headerColor.withOpacity(0.4))
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(_isDark ? 0.1 : 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLost
                      ? Icons.cancel_rounded
                      : Icons.flag_rounded,
                  size: 16,
                  color: _isDark ? headerColor : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  stageNameAr,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: _isDark ? headerColor : Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // ✅ لو مش خسارة → نعرض المتابعة القادمة
          if (!_isLost)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isDark
                    ? followUpColor.withOpacity(0.2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: _isDark
                    ? Border.all(
                        color: followUpColor.withOpacity(0.4))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(followUpIcon,
                      size: 14, color: followUpColor),
                  const SizedBox(width: 4),
                  Text(
                    followUpText,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: followUpColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════
  //  👤 بيانات العميل (مع الاسم)
  // ═══════════════════════════════════
  Widget _buildClientInfo() {
    final clientName = _opportunity!['ClientName'] ?? 'بدون اسم';
    final phone1 = _opportunity!['Phone1'] ?? '';
    final phone2 = _opportunity!['Phone2'] ?? '';
    final address = _opportunity!['Address'] ?? '';
    final email = _opportunity!['Email'] ?? '';

    return _buildSection(
      icon: Icons.person_rounded,
      title: 'بيانات العميل',
      children: [
        // ✅ جديد: اسم العميل بشكل بارز
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isDark
                  ? [
                      AppColors.gold.withOpacity(0.1),
                      AppColors.gold.withOpacity(0.05),
                    ]
                  : [
                      AppColors.gold.withOpacity(0.08),
                      AppColors.gold.withOpacity(0.03),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.gold.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  clientName.isNotEmpty
                      ? clientName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(_isDark),
                      ),
                    ),
                    if (phone1.isNotEmpty)
                      Text(
                        phone1,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.textSecondary(_isDark),
                        ),
                      ),
                  ],
                ),
              ),
              // ✅ أزرار سريعة
              if (phone1.isNotEmpty) ...[
                _buildMiniAction(
                  Icons.phone_rounded,
                  const Color(0xFF27AE60),
                  () => _makeCall(phone1),
                ),
                const SizedBox(width: 8),
                _buildMiniAction(
                  FontAwesomeIcons.whatsapp,
                  const Color(0xFF25D366),
                  () => _openWhatsApp(phone1),
                ),
              ],
            ],
          ),
        ),

        // باقي بيانات التواصل
        if (phone2.isNotEmpty)
          _buildContactRow(
            icon: Icons.phone_android_rounded,
            text: 'هاتف 2: $phone2',
            actions: [
              _buildMiniAction(
                Icons.phone_rounded,
                const Color(0xFF27AE60),
                () => _makeCall(phone2),
              ),
              const SizedBox(width: 8),
              _buildMiniAction(
                FontAwesomeIcons.whatsapp,
                const Color(0xFF25D366),
                () => _openWhatsApp(phone2),
              ),
            ],
          ),
        if (address.isNotEmpty)
          _buildInfoRow(Icons.location_on_rounded, 'العنوان: $address'),
        if (email.isNotEmpty)
          _buildInfoRow(Icons.email_rounded, 'البريد: $email'),
      ],
    );
  }

  // ═══════════════════════════════════
  //  📊 بيانات الفرصة
  // ═══════════════════════════════════
  Widget _buildOpportunityInfo() {
    final sourceName = _opportunity!['SourceNameAr'] ?? '';
    final adTypeName = _opportunity!['AdTypeNameAr'] ?? '';
    final categoryName = _opportunity!['CategoryNameAr'] ?? '';
    final employeeName = _opportunity!['EmployeeName'] ?? '';
    final expectedValue =
        (_opportunity!['ExpectedValue'] ?? 0).toDouble();
    final interestedProduct =
        _opportunity!['InterestedProduct'] ?? '';
    final location = _opportunity!['Location'] ?? '';
    final notes = _opportunity!['Notes'] ?? '';
    final guidance = _opportunity!['Guidance'] ?? '';
    final firstContact = _opportunity!['FirstContactDate'];
    final lastContact = _opportunity!['LastContactDate'];
    final nextFollowUp = _opportunity!['NextFollowUpDate'];

    return _buildSection(
      icon: Icons.analytics_rounded,
      title: 'بيانات الفرصة',
      children: [
        if (employeeName.isNotEmpty)
          _buildInfoRow(
              Icons.person_outline_rounded, 'المسؤول: $employeeName'),
        if (sourceName.isNotEmpty)
          _buildInfoRow(Icons.source_rounded, 'المصدر: $sourceName'),
        if (adTypeName.isNotEmpty)
          _buildInfoRow(
              Icons.campaign_rounded, 'الإعلان: $adTypeName'),
        if (categoryName.isNotEmpty)
          _buildInfoRow(
              Icons.category_rounded, 'الفئة: $categoryName'),
        if (expectedValue > 0)
          _buildInfoRow(Icons.payments_rounded,
              'القيمة المتوقعة: ${NumberFormat('#,###').format(expectedValue)} ج.م'),
        if (interestedProduct.isNotEmpty)
          _buildInfoRow(Icons.shopping_bag_rounded,
              'المنتج: $interestedProduct'),
        if (location.isNotEmpty)
          _buildInfoRow(
              Icons.location_on_rounded, 'الموقع: $location'),
        if (firstContact != null)
          _buildInfoRow(Icons.event_rounded,
              'أول تواصل: ${_formatDate(firstContact)}'),
        if (lastContact != null)
          _buildInfoRow(Icons.event_available_rounded,
              'آخر تواصل: ${_formatDate(lastContact)}'),
        if (nextFollowUp != null)
          _buildInfoRow(Icons.event_note_rounded,
              'المتابعة القادمة: ${_formatDate(nextFollowUp)}'),
        if (notes.isNotEmpty)
          _buildInfoRow(Icons.notes_rounded, 'ملاحظات: $notes'),
        if (guidance.isNotEmpty)
          _buildInfoRow(
              Icons.lightbulb_rounded, 'توجيهات: $guidance'),
      ],
    );
  }

  // ═══════════════════════════════════
  //  💬 سجل التواصل
  // ═══════════════════════════════════
  Widget _buildInteractionTimeline() {
    return _buildSection(
      icon: Icons.timeline_rounded,
      title: 'سجل التواصل (${_interactions.length})',
      children: [
        if (_interactions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 40,
                      color: AppColors.textHint(_isDark)),
                  const SizedBox(height: 8),
                  Text(
                    'لا يوجد سجل تواصل بعد',
                    style: GoogleFonts.cairo(
                        color: AppColors.textHint(_isDark)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openAddInteraction,
                    icon: Icon(Icons.add_rounded,
                        color: AppColors.gold),
                    label: Text(
                      'سجل أول تواصل',
                      style:
                          GoogleFonts.cairo(color: AppColors.gold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.gold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(_interactions.length, (index) {
            final interaction = _interactions[index];
            final isLast = index == _interactions.length - 1;
            return _buildTimelineItem(interaction, isLast);
          }),
      ],
    );
  }

  // ═══════════════════════════════════
  //  ⏱️ عنصر Timeline
  // ═══════════════════════════════════
  Widget _buildTimelineItem(
      Map<String, dynamic> interaction, bool isLast) {
    final date = interaction['InteractionDate'];
    final employeeName = interaction['EmployeeName'] ?? '';
    final summary = interaction['Summary'] ?? '';
    final notes = interaction['Notes'] ?? '';
    final stageBefore = interaction['StageBefore'] ?? '';
    final stageAfter = interaction['StageAfter'] ?? '';
    final statusName = interaction['StatusNameAr'] ?? '';
    final sourceIcon = interaction['SourceIcon'] ?? '📞';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.divider(_isDark),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputFill(_isDark),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.divider(_isDark)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(sourceIcon,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _formatDate(date),
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          employeeName,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color:
                                AppColors.textSecondary(_isDark),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (statusName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppColors.gold.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusName,
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.gold),
                        ),
                      ),
                    ),
                  if (stageBefore.isNotEmpty &&
                      stageAfter.isNotEmpty &&
                      stageBefore != stageAfter)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(
                              _isDark ? 0.15 : 0.08),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.swap_horiz_rounded,
                                size: 14,
                                color: Colors.orange),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$stageBefore ← $stageAfter',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (summary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        summary,
                        style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: AppColors.text(_isDark)),
                      ),
                    ),
                  if (notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_rounded,
                              size: 14,
                              color: AppColors.gold),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              notes,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.textSecondary(
                                    _isDark),
                              ),
                            ),
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

  // ═══════════════════════════════════
  //  🔘 أزرار الأكشن
  // ═══════════════════════════════════
  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        AppColors.buttonGradient(_isDark),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  onPressed: _openAddInteraction,
                  icon: const Icon(
                      Icons.add_comment_rounded,
                      size: 20),
                  label: Text('تسجيل تواصل',
                      style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: _isDark
                        ? AppColors.navy
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: null,
                icon: Icon(Icons.swap_horiz_rounded,
                    size: 20, color: AppColors.gold),
                label: Text(
                  'نقل مرحلة',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.gold),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60)
                      .withOpacity(_isDark ? 0.2 : 1),
                  borderRadius: BorderRadius.circular(12),
                  border: _isDark
                      ? Border.all(
                          color: const Color(0xFF27AE60)
                              .withOpacity(0.4))
                      : null,
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final phone =
                        _opportunity?['Phone1'] ?? '';
                    if (phone.isNotEmpty) _makeCall(phone);
                  },
                  icon: Icon(
                    Icons.phone_rounded,
                    color: _isDark
                        ? const Color(0xFF27AE60)
                        : Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    'اتصال',
                    style: GoogleFonts.cairo(
                      color: _isDark
                          ? const Color(0xFF27AE60)
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366)
                      .withOpacity(_isDark ? 0.2 : 1),
                  borderRadius: BorderRadius.circular(12),
                  border: _isDark
                      ? Border.all(
                          color: const Color(0xFF25D366)
                              .withOpacity(0.4))
                      : null,
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final phone =
                        _opportunity?['Phone1'] ?? '';
                    if (phone.isNotEmpty)
                      _openWhatsApp(phone);
                  },
                  icon: FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: _isDark
                        ? const Color(0xFF25D366)
                        : Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    'واتساب',
                    style: GoogleFonts.cairo(
                      color: _isDark
                          ? const Color(0xFF25D366)
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════
  //  🔧 Widgets مشتركة
  // ═══════════════════════════════════
  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider(_isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(_isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(_isDark),
                ),
              ),
            ],
          ),
          Divider(color: AppColors.divider(_isDark)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String text,
    required List<Widget> actions,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: AppColors.textSecondary(_isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.text(_isDark)),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18,
              color: AppColors.textSecondary(_isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.text(_isDark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAction(
      dynamic icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(_isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: compatIcon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 80, color: AppColors.textHint(_isDark)),
          const SizedBox(height: 16),
          Text(
            'فشل تحميل البيانات',
            style: GoogleFonts.cairo(
                fontSize: 18,
                color: AppColors.textSecondary(_isDark)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('إعادة المحاولة',
                style: GoogleFonts.cairo()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return date;
    }
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    String formattedPhone =
        phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedPhone.startsWith('0'))
      formattedPhone = '2$formattedPhone';
    final uri = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(uri))
      await launchUrl(uri,
          mode: LaunchMode.externalApplication);
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}