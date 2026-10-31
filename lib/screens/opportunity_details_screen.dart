import 'package:http/http.dart' as http;
import '../services/app_colors.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../constants.dart';
import '../services/icon_utils.dart';
import '../services/opportunities_service.dart';
import 'add_interaction_screen.dart';
import 'add_opportunity_screen.dart';
import '../core/auth/session_service.dart';
import '../widgets/design_kit.dart';
import '../services/design_tokens.dart';

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
  State<OpportunityDetailsScreen> createState() =>
      _OpportunityDetailsScreenState();
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
    currentOpp = Map<String, dynamic>.from(widget.opportunity);
    _loadTimeline();
    _initializeDateFormatting();
    _refreshOpportunityData();
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('ar_SA', null);
    if (mounted) {
      setState(() => _dateFormattingInitialized = true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════
  //  🔄 تحميل البيانات
  // ══════════════════════════════════════

  Future<void> _loadTimeline() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service
          .getOpportunityTimeline(currentOpp['OpportunityID']);
      if (mounted) {
        setState(() {
          timeline = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

    /// ✅ إعادة تحميل بيانات الفرصة بعد التعديل
  Future<void> _refreshOpportunityData() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/${currentOpp['OpportunityID']}'),
       headers: SessionService.instance.authHeaders,);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data != null && mounted) {
          setState(() => currentOpp = Map<String, dynamic>.from(data));
        }
      }
    } catch (e) {
      debugPrint('Error refreshing opportunity: $e');
    }
  }

  // ══════════════════════════════════════
  //  🔍 Getters مساعدة
  // ══════════════════════════════════════

  /// هل الفرصة خاسرة؟
  bool get _isLost {
    final stageAr =
        (currentOpp['StageNameAr'] ?? '').toString().toLowerCase();
    final stageEn =
        (currentOpp['StageName'] ?? '').toString().toLowerCase();
    return stageAr.contains('خسارة') ||
        stageAr.contains('خسار') ||
        stageAr.contains('مغلق') ||
        stageEn.contains('lost') ||
        stageEn.contains('closed lost');
  }

  /// سبب الخسارة
  String get _lossReason {
    return (currentOpp['LostReasonNameAr'] ??
            currentOpp['LostReasonName'] ??
            '')
        .toString()
        .trim();
  }

  /// ملاحظات الخسارة
  String get _lossNotes {
    return (currentOpp['LostNotes'] ?? '').toString().trim();
  }

  /// نسبة اكتمال البيانات
  double get _dataCompletionPercentage {
    int filled = 0;
    int total = 10;

    if (_hasValue(currentOpp['ClientName'])) filled++;
    if (_hasValue(currentOpp['Phone1'])) filled++;
    if (_hasValue(currentOpp['SourceID'])) filled++;
    if (_hasValue(currentOpp['EmployeeID'])) filled++;
    if (_hasValue(currentOpp['InterestedProduct'])) filled++;
    if (_hasValue(currentOpp['ExpectedValue']) &&
        currentOpp['ExpectedValue'] != 0)
      filled++;
    if (_hasValue(currentOpp['Location'])) filled++;
    if (_hasValue(currentOpp['CategoryID'])) filled++;
    if (_hasValue(currentOpp['NextFollowUpDate'])) filled++;
    if (_hasValue(currentOpp['Notes'])) filled++;

    return filled / total;
  }

  bool _hasValue(dynamic val) {
    if (val == null) return false;
    if (val is String && val.trim().isEmpty) return false;
    return true;
  }

  /// عدد أيام بدون تواصل
  int get _daysSinceLastContact {
    if (currentOpp['LastContactDate'] == null) return -1;
    try {
      final last = DateTime.parse(currentOpp['LastContactDate']);
      return DateTime.now().difference(last).inDays;
    } catch (_) {
      return -1;
    }
  }

  // ══════════════════════════════════════
  //  📞 دوال الاتصال
  // ══════════════════════════════════════

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '20${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('20')) {
      cleanPhone = '20$cleanPhone';
    }
    final uri = Uri.parse('whatsapp://send?phone=$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(Uri.parse('https://wa.me/$cleanPhone'),
          mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareOpportunity() async {
    final String shareText = '''
🏢 فرصة بيع - ${currentOpp['ClientName']}
📞 ${currentOpp['Phone1'] ?? ''}
📦 المنتج: ${currentOpp['InterestedProduct'] ?? '-'}
💰 القيمة: ${currentOpp['ExpectedValue'] ?? '0'} ج.م
📍 المرحلة: ${currentOpp['StageNameAr'] ?? '-'}
👤 المسؤول: ${currentOpp['EmployeeName'] ?? '-'}
📅 تاريخ الإضافة: ${_formatDate(currentOpp['CreatedAt'])}
${currentOpp['Notes'] != null && currentOpp['Notes'].toString().isNotEmpty ? '💼 ملاحظات: ${currentOpp['Notes']}' : ''}
    ''';

    await Share.share(shareText, subject: 'تفاصيل فرصة البيع');
  }

  void _copyToClipboard(String? text) {
    if (text == null || text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const FaFaIcon(FontAwesomeIcons.copy,
                color: Colors.white, size: 14),
            const SizedBox(width: 8),
            Text('تم نسخ: $text', style: GoogleFonts.cairo()),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ══════════════════════════════════════
  //  🎨 ألوان مساعدة
  // ══════════════════════════════════════

  Color _getStageColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return AppColors.neutral;
    try {
      return Color(
          int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.neutral;
    }
  }

  Color _getStatusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.contains('مكتمل') || s.contains('closed')) return AppColors.success;
    if (s.contains('معلق') || s.contains('pending')) return AppColors.warning;
    if (s.contains('ملغي') || s.contains('cancelled')) return AppColors.error;
    return AppColors.info;
  }

  // ══════════════════════════════════════
  //  📱 بناء الواجهة الرئيسية
  // ══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_dateFormattingInitialized) {
      return Scaffold(
        body: const AppLoading(message: 'جاري التحميل...'),
      );
    }

    Color stageColor = _isLost
        ? AppColors.error
        : _getStageColor(currentOpp['StageColor']);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.18),
                borderRadius: AppRadius.all(AppRadius.sm),
              ),
              child: Icon(Icons.trending_up_rounded,
                  color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تفاصيل الفرصة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    currentOpp['ClientName'] ?? 'بدون اسم',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded, color: AppColors.gold),
            onPressed: _shareOpportunity,
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed: () async {
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
              if (result == true) {
                await _refreshOpportunityData();
                await _loadTimeline();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildEnhancedHeader(stageColor),
          _buildTabBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _selectedTab = i),
              children: [
                _buildDetailsTab(),
                _buildActivitiesTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ══════════════════════════════════════
  //  🔷 الهيدر
  // ══════════════════════════════════════

  Widget _buildEnhancedHeader(Color stageColor) {
    String daysOpen = '';
    if (currentOpp['CreatedAt'] != null) {
      try {
        final created = DateTime.parse(currentOpp['CreatedAt']);
        final days = DateTime.now().difference(created).inDays;
        if (days == 0)
          daysOpen = 'اليوم';
        else if (days == 1)
          daysOpen = 'من يوم';
        else if (days == 2)
          daysOpen = 'من يومين';
        else
          daysOpen = 'منذ $days يوم';
      } catch (_) {}
    }

    final stageLabel =
        currentOpp['StageNameAr'] ?? currentOpp['StageName'] ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppGradients.identityCard,
          ),
          borderRadius: AppRadius.all(AppRadius.xxl),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── المرحلة + مدة الفتح ──
            Row(
              children: [
                StatusBadge(
                  label: stageLabel,
                  color: stageColor,
                  filled: true,
                ),
                const Spacer(),
                if (daysOpen.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: AppRadius.all(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded,
                            color: Colors.white70, size: 11),
                        const SizedBox(width: 6),
                        Text(
                          'مفتوحة $daysOpen',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // ── معلومات العميل + القيمة المتوقعة ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        stageColor,
                        stageColor.withValues(alpha: 0.55),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _isLost
                        ? const FaFaIcon(FontAwesomeIcons.xmark,
                            color: Colors.white, size: 20)
                        : Text(
                            _getInitials(currentOpp['ClientName'] ?? 'CL'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentOpp['ClientName'] ?? 'بدون اسم',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: ui.TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'القيمة المتوقعة',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AmountText(
                        value: '${currentOpp['ExpectedValue'] ?? '0'} ج.م',
                        size: 22,
                        color: AppColors.gold,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // ── أزرار التواصل ──
            Row(
              children: [
                const Icon(Icons.call_rounded,
                    size: 12, color: Colors.white70),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    currentOpp['Phone1'] ?? '',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppIconChip(
                  icon: Icons.call_rounded,
                  color: AppColors.success,
                  tooltip: 'اتصال',
                  onTap: () => _makePhoneCall(currentOpp['Phone1']),
                ),
                const SizedBox(width: AppSpacing.sm),
                WhatsAppChip(
                  onTap: () => _openWhatsApp(currentOpp['Phone1']),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppIconChip(
                  icon: Icons.copy_rounded,
                  color: Colors.white,
                  tooltip: 'نسخ الرقم',
                  onTap: () => _copyToClipboard(currentOpp['Phone1']),
                ),
              ],
            ),
            if (_hasValue(currentOpp['Phone2'])) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.call_rounded,
                      size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      currentOpp['Phone2'].toString(),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppIconChip(
                    icon: Icons.call_rounded,
                    color: AppColors.info,
                    tooltip: 'اتصال',
                    onTap: () => _makePhoneCall(currentOpp['Phone2']),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppIconChip(
                    icon: Icons.copy_rounded,
                    color: Colors.white,
                    tooltip: 'نسخ الرقم',
                    onTap: () => _copyToClipboard(currentOpp['Phone2']),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // ── المصدر + الحملة ──
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: AppRadius.all(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSourceIcon(currentOpp['SourceNameAr'] ??
                            currentOpp['SourceName']),
                        const SizedBox(width: 6),
                        Text('المصدر: ',
                            style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.6),
                                fontSize: 10)),
                        Flexible(
                          child: Text(
                            currentOpp['SourceNameAr'] ??
                                currentOpp['SourceName'] ??
                                '-',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_hasValue(currentOpp['AdTypeNameAr']) ||
                    _hasValue(currentOpp['AdTypeName'])) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            AppStatus.editPending.withValues(alpha: 0.18),
                        borderRadius: AppRadius.all(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_rounded,
                              color: AppStatus.editPending, size: 11),
                          const SizedBox(width: 6),
                          Text('الحملة: ',
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.6),
                                  fontSize: 10)),
                          Flexible(
                            child: Text(
                              currentOpp['AdTypeNameAr'] ??
                                  currentOpp['AdTypeName'] ??
                                  '-',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
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
    );
  }

  // ══════════════════════════════════════
  //  🔴 بانر الخسارة
  // ══════════════════════════════════════

  Widget _buildLossBanner() {
    final theme = Theme.of(context);
    return AppCard(
      color: AppColors.error.withValues(alpha: 0.07),
      child: Column(
        children: [
          // العنوان
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cancel_rounded,
                    color: AppColors.error, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تم خسارة هذه الفرصة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    Text(
                      'الفرصة مغلقة ولم تتحول لصفقة',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // سبب الخسارة
          if (_lossReason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: AppRadius.all(AppRadius.md),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Text(
                        'سبب الخسارة:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lossReason,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ملاحظات الخسارة
          if (_lossNotes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.07),
                borderRadius: AppRadius.all(AppRadius.md),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تفاصيل الخسارة:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _lossNotes,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // لو مفيش سبب
          if (_lossReason.isEmpty && _lossNotes.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: AppRadius.all(AppRadius.sm),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'لم يتم تسجيل سبب الخسارة',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  // ══════════════════════════════════════
  //  ⚠️ تنبيه بدون تواصل
  // ══════════════════════════════════════

  Widget _buildNoContactWarning() {
    final days = _daysSinceLastContact;
    if (days < 7) return const SizedBox.shrink();

    Color warningColor;
    String warningText;
    dynamic warningIcon;

    if (days >= 30) {
      warningColor = AppColors.error;
      warningText = '⚠️ لم يتم التواصل منذ $days يوم!';
      warningIcon = FontAwesomeIcons.triangleExclamation;
    } else if (days >= 14) {
      warningColor = AppColors.warning;
      warningText = '⏰ لم يتم التواصل منذ $days يوم';
      warningIcon = FontAwesomeIcons.clockRotateLeft;
    } else {
      warningColor = AppStatus.overdue;
      warningText = '📌 آخر تواصل من $days أيام';
      warningIcon = FontAwesomeIcons.bell;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        color: warningColor.withValues(alpha: 0.08),
        child: Row(
          children: [
            compatIcon(warningIcon, color: warningColor, size: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                warningText,
                style: TextStyle(
                  color: warningColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideX(begin: 0.05),
    );
  }

  // ══════════════════════════════════════
  //  📊 نسبة اكتمال البيانات
  // ══════════════════════════════════════

  Widget _buildCompletionBar() {
    final percentage = _dataCompletionPercentage;
    final percentInt = (percentage * 100).toInt();

    Color barColor;
    if (percentage >= 0.8) {
      barColor = AppColors.success;
    } else if (percentage >= 0.5) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.error;
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: 'اكتمال البيانات',
              icon: Icons.pie_chart_rounded,
              accent: barColor,
              trailing: Text(
                '$percentInt%',
                style: TextStyle(
                  color: barColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms),
    );
  }

  // ══════════════════════════════════════
  //  📋 تبويب التفاصيل
  // ══════════════════════════════════════

  Widget _buildDetailsTab() {
    // حالة المتابعة
    String followUpText = 'غير محدد';
    Color followUpColor = AppColors.neutral;
    dynamic followUpIcon = FontAwesomeIcons.calendar;

    if (currentOpp['NextFollowUpDate'] != null) {
      try {
        final followDate =
            DateTime.parse(currentOpp['NextFollowUpDate']);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final followDateOnly = DateTime(
            followDate.year, followDate.month, followDate.day);
        final difference =
            followDateOnly.difference(today).inDays;
        final dateStr =
            '${followDate.day}/${followDate.month}/${followDate.year}';

        if (difference < 0) {
          followUpText =
              'متأخرة من ${difference.abs()} يوم ($dateStr)';
          followUpColor = AppColors.error;
          followUpIcon = FontAwesomeIcons.triangleExclamation;
        } else if (difference == 0) {
          followUpText = 'اليوم $dateStr';
          followUpColor = AppColors.warning;
          followUpIcon = FontAwesomeIcons.bell;
        } else if (difference == 1) {
          followUpText = 'غداً $dateStr';
          followUpColor = AppColors.info;
          followUpIcon = FontAwesomeIcons.clock;
        } else {
          followUpText = 'بعد $difference يوم ($dateStr)';
          followUpColor = AppColors.success;
          followUpIcon = FontAwesomeIcons.calendarCheck;
        }
      } catch (_) {}
    }

    // آخر تواصل
    String lastContactText = 'لا يوجد';
    if (currentOpp['LastContactDate'] != null) {
      try {
        final lastDate =
            DateTime.parse(currentOpp['LastContactDate']);
        final days =
            DateTime.now().difference(lastDate).inDays;
        final lastDateStr =
            '${lastDate.day}/${lastDate.month}/${lastDate.year}';

        if (days == 0)
          lastContactText = 'اليوم ($lastDateStr)';
        else if (days == 1)
          lastContactText = 'من يوم ($lastDateStr)';
        else if (days == 2)
          lastContactText = 'من يومين ($lastDateStr)';
        else
          lastContactText = 'من $days يوم ($lastDateStr)';
      } catch (_) {}
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ بانر الخسارة
          if (_isLost) ...[
            _buildLossBanner(),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ✅ تنبيه بدون تواصل
          if (!_isLost) _buildNoContactWarning(),

          // ✅ نسبة اكتمال البيانات
          _buildCompletionBar(),

          // الإحصائيات
          Row(
            children: [
              Expanded(
                child: AppStatCard(
                  value: '${currentOpp['ExpectedValue'] ?? '0'}',
                  label: 'القيمة المتوقعة',
                  icon: Icons.payments_rounded,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppStatCard(
                  value: timeline.length.toString(),
                  label: 'التواصلات',
                  icon: Icons.forum_rounded,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppStatCard(
                  value: currentOpp['FirstContactDate'] != null
                      ? '${DateTime.parse(currentOpp['FirstContactDate']).day}/${DateTime.parse(currentOpp['FirstContactDate']).month}/${DateTime.parse(currentOpp['FirstContactDate']).year}'
                      : '-',
                  label: 'أول تواصل',
                  icon: Icons.event_available_rounded,
                  color: AppColors.infoLight,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // موعد المتابعة
          if (!_isLost)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: followUpColor.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: followUpColor.withValues(alpha: 0.15),
                      borderRadius: AppRadius.all(AppRadius.sm),
                    ),
                    child: compatIcon(followUpIcon,
                        color: followUpColor, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'موعد المتابعة القادمة',
                          style: TextStyle(
                              color: followUpColor, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          followUpText,
                          style: TextStyle(
                            color: followUpColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (!_isLost) const SizedBox(height: AppSpacing.md),

          // آخر تواصل
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.warning.withValues(alpha: 0.08),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: AppRadius.all(AppRadius.sm),
                  ),
                  child: FaIcon(
                      FontAwesomeIcons.clockRotateLeft,
                      color: AppColors.warning,
                      size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'آخر تواصل',
                        style: TextStyle(
                            color: AppColors.warning, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastContactText,
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ✅ بيانات العميل (عنوان + إيميل)
          if (_hasValue(currentOpp['Address']) ||
              _hasValue(currentOpp['Email']))
            _buildDetailSection(
              'بيانات العميل',
              FontAwesomeIcons.addressCard,
              [
                if (_hasValue(currentOpp['Address']))
                  _buildDetailRow(
                      'العنوان',
                      currentOpp['Address'],
                      FontAwesomeIcons.locationDot),
                if (_hasValue(currentOpp['Email']))
                  _buildDetailRow(
                      'البريد الإلكتروني',
                      currentOpp['Email'],
                      FontAwesomeIcons.envelope),
              ],
            ),

          if (_hasValue(currentOpp['Address']) ||
              _hasValue(currentOpp['Email']))
            const SizedBox(height: AppSpacing.xl),

          // معلومات الفرصة
          _buildDetailSection(
            'معلومات الفرصة',
            FontAwesomeIcons.infoCircle,
            [
              _buildDetailRow(
                  'المنتج المهتم به',
                  currentOpp['InterestedProduct'] ?? '-',
                  FontAwesomeIcons.box),
              _buildDetailRow(
                  'الموقع',
                  currentOpp['Location'] ?? '-',
                  FontAwesomeIcons.locationDot),
              _buildDetailRow(
                  'فئة الاهتمام',
                  currentOpp['CategoryNameAr'] ?? '-',
                  FontAwesomeIcons.tags),
              _buildAmountDetailRow(
                  'القيمة المتوقعة',
                  '${currentOpp['ExpectedValue'] ?? '0'} ج.م',
                  FontAwesomeIcons.coins),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // الحالة
          _buildDetailSection(
            'الحالة',
            FontAwesomeIcons.timeline,
            [
              _buildStatusRow(
                  'المرحلة',
                  currentOpp['StageNameAr'] ?? '-',
                  _isLost
                      ? AppColors.error
                      : _getStageColor(
                          currentOpp['StageColor'])),
              _buildStatusRow(
                  'حالة التواصل',
                  currentOpp['StatusNameAr'] ?? '-',
                  _getStatusColor(
                      currentOpp['StatusNameAr'])),
              _buildDetailRow(
                  'الموظف المسؤول',
                  currentOpp['EmployeeName'] ?? '-',
                  FontAwesomeIcons.userTie),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // ✅ الملاحظات
          if (_hasValue(currentOpp['Notes']))
            _buildNotesCard(
              title: 'ملخص التواصل',
              icon: FontAwesomeIcons.commentDots,
              color: AppColors.warning,
              text: currentOpp['Notes'],
            ),

          if (_hasValue(currentOpp['Notes']))
            const SizedBox(height: AppSpacing.lg),

          // ✅ التوجيهات
          if (_hasValue(currentOpp['Guidance']))
            _buildNotesCard(
              title: 'توجيهات المتابعة',
              icon: FontAwesomeIcons.compass,
              color: AppColors.infoLight,
              text: currentOpp['Guidance'],
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  💬 تبويب النشاطات
  // ══════════════════════════════════════

  Widget _buildActivitiesTab() {
    if (_isLoading) return const AppLoading();
    if (timeline.isEmpty) {
      return AppEmpty(
        message: 'لا يوجد سجل تواصل',
        hint: 'ابدأ بإضافة أول تواصل',
        icon: Icons.event_busy_rounded,
        onRefresh: _loadTimeline,
      );
    }
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _loadTimeline,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: timeline.length,
        itemBuilder: (context, index) =>
            _buildTimelineCard(timeline[index], index),
      ),
    );
  }

  Widget _buildTimelineCard(dynamic item, int index) {
    final theme = Theme.of(context);
    final date = DateTime.parse(item['InteractionDate']);
    final bool hasStageChange = item['StageBefore'] != null &&
        item['StageAfter'] != null &&
        item['StageBefore'] != item['StageAfter'];

    String contactType = 'تواصل';
    dynamic contactIcon = FontAwesomeIcons.comment;
    Color contactColor = AppColors.info;

    final statusId = item['StatusID'];
    final statusNameAr = item['StatusNameAr'] ?? '';

    switch (statusId) {
      case 1:
        contactType = 'أول تواصل';
        contactIcon = FontAwesomeIcons.starOfLife;
        contactColor = AppColors.infoLight;
        break;
      case 2:
        contactType = 'تم الاتصال';
        contactIcon = FontAwesomeIcons.phoneVolume;
        contactColor = AppColors.success;
        break;
      case 4:
        contactType = 'عميل قديم';
        contactIcon = FontAwesomeIcons.userClock;
        contactColor = AppColors.warning;
        break;
      case 5:
        contactType = 'زيارة المعرض';
        contactIcon = FontAwesomeIcons.store;
        contactColor = AppStatus.editPending;
        break;
      case 6:
        contactType = 'رسالة واتساب';
        contactIcon = FontAwesomeIcons.commentDots;
        contactColor = AppColors.whatsapp;
        break;
      default:
        contactType = statusNameAr.isNotEmpty
            ? statusNameAr
            : 'تواصل';
    }

    final sourceName =
        (item['SourceName'] ?? '').toString().toLowerCase();
    dynamic sourceIcon = FontAwesomeIcons.comment;
    if (sourceName.contains('whatsapp') ||
        sourceName.contains('واتساب')) {
      sourceIcon = FontAwesomeIcons.whatsapp;
    } else if (sourceName.contains('phone') ||
        sourceName.contains('مكالمة') ||
        sourceName.contains('هاتف')) {
      sourceIcon = FontAwesomeIcons.phone;
    } else if (sourceName.contains('facebook') ||
        sourceName.contains('فيسبوك')) {
      sourceIcon = FontAwesomeIcons.facebook;
    } else if (sourceName.contains('showroom') ||
        sourceName.contains('معرض') ||
        sourceName.contains('زيارة')) {
      sourceIcon = FontAwesomeIcons.store;
    }

    final bool isFirstInteraction =
        index == timeline.length - 1;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: contactColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: contactColor, width: 2),
                  ),
                  child: Center(
                    child: compatIcon(contactIcon,
                        color: contactColor, size: 14),
                  ),
                ),
                if (index != timeline.length - 1)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الهيدر
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color:
                            contactColor.withValues(alpha: 0.06),
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3),
                              decoration: BoxDecoration(
                                color: contactColor
                                    .withValues(alpha: 0.15),
                                borderRadius:
                                    AppRadius.all(AppRadius.pill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  compatIcon(contactIcon,
                                      color: contactColor,
                                      size: 10),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      isFirstInteraction
                                          ? 'أول تواصل'
                                          : contactType,
                                      style: TextStyle(
                                        color: contactColor,
                                        fontSize: 10,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3),
                            decoration: BoxDecoration(
                              color: theme
                                  .colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius:
                                  AppRadius.all(AppRadius.pill),
                            ),
                            child: compatIcon(sourceIcon,
                                color: theme
                                    .colorScheme.onSurfaceVariant,
                                size: 10),
                          ),
                          const Spacer(),
                          Text(
                            '${date.day}/${date.month}/${date.year}',
                            style: TextStyle(
                                color: theme
                                    .colorScheme.onSurfaceVariant,
                                fontSize: 10),
                          ),
                        ],
                      ),
                    ),

                    // المحتوى
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              FaIcon(
                                  FontAwesomeIcons.userTie,
                                  color: AppColors.gold,
                                  size: 11),
                              const SizedBox(width: 6),
                              Text(
                                item['EmployeeName'] ??
                                    'النظام',
                                style: TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (_hasValue(item['Summary']))
                            Text(
                              item['Summary'],
                              style: TextStyle(
                                  color:
                                      theme.colorScheme.onSurface,
                                  fontSize: 13),
                            ),
                          if (hasStageChange) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding:
                                  const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.info
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    AppRadius.all(AppRadius.sm),
                                border: Border.all(
                                    color: AppColors.info
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  FaIcon(
                                      FontAwesomeIcons
                                          .arrowRightArrowLeft,
                                      size: 12,
                                      color: AppColors.info),
                                  const SizedBox(width: AppSpacing.sm),
                                  Container(
                                    padding: const EdgeInsets
                                        .symmetric(
                                        horizontal: 8,
                                        vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.info
                                          .withValues(alpha: 0.15),
                                      borderRadius: AppRadius.all(
                                          AppRadius.xs),
                                    ),
                                    child: Text(
                                      item['StageBefore']!,
                                      style: TextStyle(
                                          color: AppColors.info,
                                          fontSize: 10),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets
                                        .symmetric(horizontal: 6),
                                    child: FaIcon(
                                        FontAwesomeIcons
                                            .arrowRight,
                                        size: 10,
                                        color: theme.colorScheme
                                            .onSurfaceVariant),
                                  ),
                                  Container(
                                    padding: const EdgeInsets
                                        .symmetric(
                                        horizontal: 8,
                                        vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.15),
                                      borderRadius: AppRadius.all(
                                          AppRadius.xs),
                                    ),
                                    child: Text(
                                      item['StageAfter']!,
                                      style: TextStyle(
                                          color: AppColors.success,
                                          fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_hasValue(item['Notes'])) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding:
                                  const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.warning
                                    .withValues(alpha: 0.06),
                                borderRadius:
                                    AppRadius.all(AppRadius.sm),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  FaIcon(
                                      FontAwesomeIcons
                                          .noteSticky,
                                      size: 11,
                                      color: AppColors.warning),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      item['Notes']!,
                                      style: TextStyle(
                                          color: theme.colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 12),
                                    ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  🔽 البار السفلي
  // ══════════════════════════════════════

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: theme.colorScheme.outlineVariant
                  .withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                icon: Icons.call_rounded,
                label: 'اتصال',
                color: AppColors.success,
                onTap: () =>
                    _makePhoneCall(currentOpp['Phone1']),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _FaAppButton(
                icon: FontAwesomeIcons.whatsapp,
                label: 'واتساب',
                color: AppColors.whatsapp,
                onTap: () =>
                    _openWhatsApp(currentOpp['Phone1']),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                icon: Icons.add_rounded,
                label: 'تواصل',
                color: AppColors.gold,
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddInteractionScreen(
                        userId: widget.userId,
                        username: widget.username,
                        preSelectedPartyId:
                            currentOpp['PartyID'],
                        preSelectedOpportunityId:
                            currentOpp['OpportunityID'],
                      ),
                    ),
                  );
                  if (result == true) {
                    await _refreshOpportunityData();
                    await _loadTimeline();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  🧩 Widgets مشتركة
  // ══════════════════════════════════════

  Widget _buildSourceIcon(String? sourceName) {
    String name = (sourceName ?? '').toLowerCase();
    dynamic icon = FontAwesomeIcons.globe;
    Color color = AppColors.neutralLight;

    if (name.contains('facebook') || name.contains('فيسبوك')) {
      icon = FontAwesomeIcons.facebook;
      color = const Color(0xFF1877F2);
    } else if (name.contains('whatsapp') ||
        name.contains('واتساب')) {
      icon = FontAwesomeIcons.whatsapp;
      color = AppColors.whatsapp;
    } else if (name.contains('instagram') ||
        name.contains('انستجرام')) {
      icon = FontAwesomeIcons.instagram;
      color = const Color(0xFFE4405F);
    } else if (name.contains('tiktok') ||
        name.contains('تيك توك')) {
      icon = FontAwesomeIcons.tiktok;
      color = Colors.white;
    } else if (name.contains('google') ||
        name.contains('جوجل')) {
      icon = FontAwesomeIcons.google;
      color = const Color(0xFFDB4437);
    } else if (name.contains('phone') ||
        name.contains('هاتف') ||
        name.contains('مكالمة')) {
      icon = FontAwesomeIcons.phone;
      color = AppColors.success;
    } else if (name.contains('referral') ||
        name.contains('ترشيح')) {
      icon = FontAwesomeIcons.userGroup;
      color = AppColors.warning;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.all(AppRadius.xs),
      ),
      child: Center(
          child: compatIcon(icon, color: color, size: 13)),
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          _buildTabItem('تفاصيل الفرصة', 0),
          _buildTabItem('سجل التواصلات', 1),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final theme = Theme.of(context);
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
          padding:
              const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? AppColors.gold
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? AppColors.gold
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(
      String title, dynamic icon, List<Widget> children) {
    // مبنية على بطاقة النظام AppCard + ترويسة القسم الموحدة
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: title,
            icon: (icon is IconData) ? icon : Icons.info_rounded,
            accent: AppColors.gold,
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAmountDetailRow(
      String label, String value, dynamic icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: AppRadius.all(AppRadius.xs),
            ),
            child: Center(
                child: compatIcon(icon,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12)),
                const SizedBox(height: 2),
                AmountText(
                    value: value,
                    size: 14,
                    color: theme.colorScheme.onSurface),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, dynamic icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: AppRadius.all(AppRadius.xs),
            ),
            child: Center(
                child: compatIcon(icon,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
      String label, String value, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.all(AppRadius.xs),
            ),
            child: Center(
                child: FaFaIcon(FontAwesomeIcons.circle,
                    size: 14, color: color)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12)),
                const SizedBox(height: 2),
                StatusBadge(label: value, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ كارد ملاحظات/توجيهات
  Widget _buildNotesCard({
    required String title,
    required dynamic icon,
    required Color color,
    required String text,
  }) {
    final theme = Theme.of(context);
    return AppCard(
      color: color.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: title,
            icon: (icon is IconData) ? icon : Icons.notes_rounded,
            accent: color,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: AppRadius.all(AppRadius.md),
            ),
            child: Text(
              text,
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  🔧 دوال التنسيق
  // ══════════════════════════════════════

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) return 'اليوم';
      if (difference.inDays == 1) return 'أمس';
      if (difference.inDays < 7)
        return 'منذ ${difference.inDays} أيام';
      if (difference.inDays < 30)
        return 'منذ ${difference.inDays ~/ 7} أسابيع';
      if (difference.inDays < 365)
        return 'منذ ${difference.inDays ~/ 30} أشهر';

      return '${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return '-';
    }
  }
}

/// زر إجراء بأيقونة FontAwesome — مرآة AppButton شكليًا لأن أيقونات
/// FontAwesome (FaIconData) لا تدخل في خانة IconData الخاصة بالكيت.
class _FaAppButton extends StatelessWidget {
  final String label;
  final FaIconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FaAppButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: AppRadius.all(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.all(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.all(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
