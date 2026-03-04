import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/pipeline_service.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import 'add_opportunity_screen.dart';


class ClientCardScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int? initialPartyId;

  const ClientCardScreen({
    Key? key,
    required this.userId,
    required this.username,
    this.initialPartyId,
  }) : super(key: key);

  @override
  State<ClientCardScreen> createState() => _ClientCardScreenState();
}

class _ClientCardScreenState extends State<ClientCardScreen> {
  bool get _isDark => ThemeService().isDarkMode;

  // بيانات العميل
  Map<String, dynamic>? _opportunity;
  List<dynamic> _interactions = [];
  Map<String, dynamic>? _nextTask;
  int? _currentPartyId;
  int? _currentOpportunityId;

  // البحث
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;
  Timer? _debounce;

  // حالة التحميل
  bool _isLoading = false;
  bool _hasData = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPartyId != null) {
      _currentPartyId = widget.initialPartyId;
      _loadClientData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ===================================
  // 🔍 البحث عن عميل
  // ===================================
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length >= 2) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _showResults = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);

    try {
      final results = await PipelineService.searchClients(query);
      setState(() {
        _searchResults = results;
        _showResults = true;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  // ===================================
  // 📡 تحميل بيانات العميل
  // ===================================
  Future<void> _loadClientData() async {
    if (_currentPartyId == null) return;

    setState(() {
      _isLoading = true;
      _showResults = false;
    });

    try {
      // ✅ 1. نسأل الباك اند: هل العميل ده عنده فرصة مفتوحة؟
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/check-open/$_currentPartyId'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        
        // لو عنده فرصة مفتوحة
        if (data['hasOpenOpportunity'] == true && data['opportunity'] != null) {
          final oppId = data['opportunity']['OpportunityID']; // نجيب الـ ID الصح
          _currentOpportunityId = oppId;

          // ✅ 2. نجيب التفاصيل بناءً على الـ ID الصح اللي جبناه
          final results = await Future.wait([
            PipelineService.getOpportunityById(oppId),
            PipelineService.getInteractions(oppId),
            PipelineService.getNextTask(_currentPartyId!),
          ]);

          setState(() {
            _opportunity = results[0] as Map<String, dynamic>?;
            _interactions = results[1] as List<dynamic>;
            _nextTask = results[2] as Map<String, dynamic>?;
            _hasData = true;
            _isLoading = false;
          });
        } else {
          // ⚠️ العميل موجود بس معندوش فرص مفتوحة حالياً
          setState(() {
            _opportunity = {
              'ClientName': 'عميل مسجل', // ممكن تجيب اسمه من البحث
              'Phone1': '',
            }; 
            _interactions = [];
            _nextTask = null;
            _hasData = false; // عشان يظهر إنه مفيش بيانات فرصة
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ خطأ في تحميل البيانات: $e');
      setState(() => _isLoading = false);
    }
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
        appBar: AppBar(
          backgroundColor: _isDark ? AppColors.navy : Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(
            color: _isDark ? Colors.white : AppColors.navy,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_rounded, color: AppColors.gold, size: 24),
              const SizedBox(width: 8),
              Text(
                'بطاقة العميل',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: _isDark ? Colors.white : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // 🔍 البحث
            _buildSearchSection(),

            // 📋 المحتوى
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : !_hasData && _currentPartyId == null
                      ? _buildEmptyState()
                      : !_hasData
                          ? _buildNoOpportunityState()
                          : RefreshIndicator(
                              color: AppColors.gold,
                              onRefresh: _loadClientData,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildClientInfoCard(),
                                    const SizedBox(height: 12),
                                    _buildOpportunityInfoCard(),
                                    const SizedBox(height: 12),
                                    _buildNextTaskCard(),
                                    const SizedBox(height: 12),
                                    _buildInteractionsCard(),
                                    const SizedBox(height: 12),
                                    _buildActionButtons(),
                                    const SizedBox(height: 30),
                                  ],
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================
  // 🔍 قسم البحث
  // ===================================
  Widget _buildSearchSection() {
    return Container(
      color: AppColors.card(_isDark),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // حقل البحث
          TextField(
            controller: _searchController,
            textDirection: ui.TextDirection.rtl,
            style: GoogleFonts.cairo(color: AppColors.text(_isDark)),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو رقم التليفون...',
              hintStyle: GoogleFonts.cairo(color: AppColors.textHint(_isDark)),
              prefixIcon: _isSearching
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      ),
                    )
                  : Icon(Icons.search_rounded, color: AppColors.gold),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.textHint(_isDark)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _showResults = false;
                        });
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
            onChanged: _onSearchChanged,
          ),

          // نتائج البحث
          if (_showResults) _buildSearchResults(),
        ],
      ),
    );
  }

  // ===================================
  // 📋 نتائج البحث
  // ===================================
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'لم يتم العثور على نتائج',
          style: GoogleFonts.cairo(color: AppColors.textHint(_isDark)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: AppColors.divider(_isDark),
        ),
        itemBuilder: (context, index) {
          final client = _searchResults[index];
          final stageColor = client['StageColor'] != null
              ? _hexToColor(client['StageColor'])
              : AppColors.textHint(_isDark);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: stageColor.withOpacity(_isDark ? 0.2 : 0.1),
              child: Text(
                (client['PartyName'] ?? '?')[0],
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: stageColor,
                ),
              ),
            ),
            title: Text(
              client['PartyName'] ?? '',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.text(_isDark),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📞 ${client['Phone'] ?? '-'}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary(_isDark),
                  ),
                ),
                if (client['CurrentStage'] != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: stageColor.withOpacity(_isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      client['CurrentStage'],
                      style: GoogleFonts.cairo(fontSize: 10, color: stageColor),
                    ),
                  ),
              ],
            ),
            trailing: Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textHint(_isDark),
            ),
            onTap: () {
              setState(() {
                _currentPartyId = client['PartyID'];
                _currentOpportunityId = client['OpenOpportunityID'];
                _searchController.text = client['PartyName'] ?? '';
                _showResults = false;
              });
              _loadClientDataDirect(client);
            },
          );
        },
      ),
    );
  }

  // ===================================
  // 📡 تحميل بيانات العميل مباشرة
  // ===================================
  Future<void> _loadClientDataDirect(Map<String, dynamic> client) async {
    setState(() => _isLoading = true);

    try {
      final oppId = client['OpenOpportunityID'];

      if (oppId != null) {
        _currentOpportunityId = oppId;

        final results = await Future.wait([
          PipelineService.getOpportunityById(oppId),
          PipelineService.getInteractions(oppId),
        ]);

        setState(() {
          _opportunity = results[0] as Map<String, dynamic>?;
          _interactions = results[1] as List<dynamic>;
          _hasData = true;
          _isLoading = false;
        });
      } else {
        // عميل بدون فرصة مفتوحة
        setState(() {
          _opportunity = {
            'ClientName': client['PartyName'],
            'Phone1': client['Phone'],
            'Phone2': client['Phone2'],
            'Address': client['Address'],
            'Email': client['Email'],
          };
          _interactions = [];
          _hasData = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ===================================
  // 👤 كارت بيانات العميل
  // ===================================
  Widget _buildClientInfoCard() {
    final clientName = _opportunity?['ClientName'] ?? '';
    final phone1 = _opportunity?['Phone1'] ?? _opportunity?['Phone'] ?? '';
    final phone2 = _opportunity?['Phone2'] ?? '';
    final address = _opportunity?['Address'] ?? '';
    final email = _opportunity?['Email'] ?? '';

    return _buildSection(
      icon: Icons.person_rounded,
      title: clientName,
      titleColor: AppColors.gold,
      children: [
        if (phone1.isNotEmpty)
          _buildContactRow(Icons.phone_rounded, 'تليفون 1: $phone1', phone1),
        if (phone2.isNotEmpty)
          _buildContactRow(Icons.phone_android_rounded, 'تليفون 2: $phone2', phone2),
        if (address.isNotEmpty)
          _buildInfoRow(Icons.location_on_rounded, 'العنوان: $address'),
        if (email.isNotEmpty)
          _buildInfoRow(Icons.email_rounded, 'الإيميل: $email'),
      ],
    );
  }

  // ===================================
  // 📊 كارت بيانات الفرصة
  // ===================================
  Widget _buildOpportunityInfoCard() {
    if (_currentOpportunityId == null) {
      return _buildSection(
        icon: Icons.analytics_rounded,
        title: 'بيانات الفرصة',
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'لا توجد فرصة بيع مفتوحة',
                style: GoogleFonts.cairo(color: AppColors.textHint(_isDark)),
              ),
            ),
          ),
        ],
      );
    }

    final stageNameAr = _opportunity?['StageNameAr'] ?? '';
    final stageColor = _hexToColor(_opportunity?['StageColor'] ?? '#DBBF74');
    final sourceName = _opportunity?['SourceNameAr'] ?? '';
    final adTypeName = _opportunity?['AdTypeNameAr'] ?? '';
    final employeeName = _opportunity?['EmployeeName'] ?? '';
    final firstContact = _opportunity?['FirstContactDate'];
    final notes = _opportunity?['Notes'] ?? '';
    final guidance = _opportunity?['Guidance'] ?? '';
    final expectedValue = (_opportunity?['ExpectedValue'] ?? 0).toDouble();

    return _buildSection(
      icon: Icons.analytics_rounded,
      title: 'بيانات الفرصة',
      headerWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: stageColor.withOpacity(_isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: stageColor.withOpacity(0.4)),
        ),
        child: Text(
          stageNameAr,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: stageColor,
          ),
        ),
      ),
      children: [
        if (sourceName.isNotEmpty) _buildInfoRow(Icons.source_rounded, 'المصدر: $sourceName'),
        if (adTypeName.isNotEmpty) _buildInfoRow(Icons.campaign_rounded, 'الإعلان: $adTypeName'),
        if (employeeName.isNotEmpty) _buildInfoRow(Icons.person_outline_rounded, 'الموظف: $employeeName'),
        if (firstContact != null) _buildInfoRow(Icons.event_rounded, 'أول تواصل: ${_formatDate(firstContact)}'),
        if (expectedValue > 0) _buildInfoRow(Icons.payments_rounded, 'القيمة المتوقعة: ${NumberFormat('#,###').format(expectedValue)} ج.م'),
        if (notes.isNotEmpty) _buildInfoRow(Icons.notes_rounded, 'ملاحظات: $notes'),
        if (guidance.isNotEmpty) _buildInfoRow(Icons.lightbulb_rounded, 'توجيهات: $guidance'),
      ],
    );
  }

  // ===================================
  // 📅 كارت المتابعة القادمة
  // ===================================
  Widget _buildNextTaskCard() {
    // نستخدم بيانات من الفرصة
    final nextFollowUp = _opportunity?['NextFollowUpDate'];

    Color taskColor = AppColors.textHint(_isDark);
    String taskStatus = 'لا توجد متابعة';
    IconData taskIcon = Icons.event_busy_rounded;

    if (nextFollowUp != null) {
      try {
        final dt = DateTime.parse(nextFollowUp);
        final now = DateTime.now();
        final diff = dt.difference(DateTime(now.year, now.month, now.day)).inDays;

        if (diff < 0) {
          taskColor = Colors.red;
          taskStatus = 'متأخر ${diff.abs()} يوم';
          taskIcon = Icons.warning_amber_rounded;
        } else if (diff == 0) {
          taskColor = Colors.orange;
          taskStatus = 'اليوم';
          taskIcon = Icons.today_rounded;
        } else if (diff == 1) {
          taskColor = Colors.blue;
          taskStatus = 'غداً';
          taskIcon = Icons.event_rounded;
        } else {
          taskColor = Colors.green;
          taskStatus = 'بعد $diff يوم';
          taskIcon = Icons.upcoming_rounded;
        }
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: taskColor.withOpacity(_isDark ? 0.4 : 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: taskColor.withOpacity(_isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(taskIcon, color: taskColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المتابعة القادمة',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary(_isDark),
                  ),
                ),
                Text(
                  nextFollowUp != null ? _formatDate(nextFollowUp) : 'غير محددة',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(_isDark),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: taskColor.withOpacity(_isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: taskColor.withOpacity(0.4)),
            ),
            child: Text(
              taskStatus,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: taskColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  // 💬 كارت سجل التواصل
  // ===================================
  Widget _buildInteractionsCard() {
    return _buildSection(
      icon: Icons.timeline_rounded,
      title: 'سجل التواصل (${_interactions.length})',
      children: [
        if (_interactions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textHint(_isDark)),
                  const SizedBox(height: 8),
                  Text(
                    'لا يوجد سجل تواصل',
                    style: GoogleFonts.cairo(color: AppColors.textHint(_isDark)),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(
            _interactions.length > 10 ? 10 : _interactions.length,
            (index) {
              final interaction = _interactions[index];
              return _buildInteractionItem(interaction);
            },
          ),
        if (_interactions.length > 10)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              onPressed: () {
                // ممكن تفتح شاشة كل التواصلات
              },
              child: Text(
                'عرض الكل (${_interactions.length})',
                style: GoogleFonts.cairo(color: AppColors.gold),
              ),
            ),
          ),
      ],
    );
  }

  // ===================================
  // 📝 عنصر تواصل
  // ===================================
  Widget _buildInteractionItem(Map<String, dynamic> interaction) {
    final date = interaction['InteractionDate'];
    final employeeName = interaction['EmployeeName'] ?? '';
    final summary = interaction['Summary'] ?? '';
    final statusName = interaction['StatusNameAr'] ?? '';
    final sourceIcon = interaction['SourceIcon'] ?? '📞';
    final stageBefore = interaction['StageBefore'] ?? '';
    final stageAfter = interaction['StageAfter'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // التاريخ والموظف
          Row(
            children: [
              Text(sourceIcon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                _formatDate(date),
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  employeeName,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.textSecondary(_isDark),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (statusName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusName,
                    style: GoogleFonts.cairo(fontSize: 9, color: AppColors.gold),
                  ),
                ),
            ],
          ),
          // تغيير المرحلة
          if (stageBefore.isNotEmpty && stageAfter.isNotEmpty && stageBefore != stageAfter)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$stageBefore ← $stageAfter',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          // الملخص
          if (summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                summary,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.text(_isDark),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  // ===================================
  // 🔘 أزرار الأكشن
  // ===================================
  Widget _buildActionButtons() {
    return Column(
      children: [
        // زرار تسجيل تواصل
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.buttonGradient(_isDark),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _currentPartyId != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddOpportunityScreen(
                            userId: widget.userId,
                            username: widget.username,
                          ),
                        ),
                      ).then((_) => _loadClientData());
                    }
                  : null,
              icon: const Icon(Icons.add_call, size: 20),
              label: Text(
                'تسجيل تواصل جديد',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: _isDark ? AppColors.navy : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // صف الأزرار الثانوية
        Row(
          children: [
            // اتصال
            Expanded(
              child: _buildSecondaryButton(
                icon: Icons.phone_rounded,
                label: 'اتصال',
                color: const Color(0xFF27AE60),
                onTap: () {
                  final phone = _opportunity?['Phone1'] ?? _opportunity?['Phone'] ?? '';
                  if (phone.isNotEmpty) _makeCall(phone);
                },
              ),
            ),
            const SizedBox(width: 8),
            // واتساب
            Expanded(
              child: _buildSecondaryButton(
                icon: FontAwesomeIcons.whatsapp,
                label: 'واتساب',
                color: const Color(0xFF25D366),
                onTap: () {
                  final phone = _opportunity?['Phone1'] ?? _opportunity?['Phone'] ?? '';
                  if (phone.isNotEmpty) _openWhatsApp(phone);
                },
              ),
            ),
            const SizedBox(width: 8),
            // عرض سعر (معطّل)
            Expanded(
              child: _buildSecondaryButton(
                icon: Icons.description_rounded,
                label: 'عرض سعر',
                color: AppColors.textHint(_isDark),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('قريباً!', style: GoogleFonts.cairo()),
                      backgroundColor: AppColors.gold,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===================================
  // 🔘 زرار ثانوي
  // ===================================
  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _currentPartyId != null ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(_isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================
  // 🔧 Widgets مشتركة
  // ===================================

  Widget _buildSection({
    required IconData icon,
    required String title,
    Color? titleColor,
    Widget? headerWidget,
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
            color: Colors.black.withOpacity(_isDark ? 0.3 : 0.04),
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
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: titleColor ?? AppColors.text(_isDark),
                  ),
                ),
              ),
              if (headerWidget != null) headerWidget,
            ],
          ),
          Divider(color: AppColors.divider(_isDark)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text, String phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary(_isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text(_isDark)),
            ),
          ),
          GestureDetector(
            onTap: () => _makeCall(phone),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60).withOpacity(_isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF27AE60)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _openWhatsApp(phone),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(_isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(FontAwesomeIcons.whatsapp, size: 16, color: Color(0xFF25D366)),
            ),
          ),
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
          Icon(icon, size: 18, color: AppColors.textSecondary(_isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(fontSize: 13, color: AppColors.text(_isDark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 80, color: AppColors.textHint(_isDark)),
          const SizedBox(height: 16),
          Text(
            'ابحث عن عميل لعرض بياناته',
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: AppColors.textSecondary(_isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك البحث بالاسم أو رقم التليفون',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textHint(_isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoOpportunityState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline_rounded, size: 80, color: AppColors.textHint(_isDark)),
          const SizedBox(height: 16),
          Text(
            'لا توجد بيانات لهذا العميل',
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
    // 1. تنظيف الرقم
    String formattedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '2$formattedPhone';
    }

    // 2. استخدام الرابط المباشر للتطبيق
    final uri = Uri.parse("whatsapp://send?phone=$formattedPhone");

    try {
      // 3. محاولة الفتح
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri); // ده هيفتح الـ chooser لو في تطبيقين
      } else {
        // Fallback: لو فشل (مثلاً مفيش واتساب خالص)، نفتح المتصفح
        final webUri = Uri.parse("https://wa.me/$formattedPhone");
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch WhatsApp';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل فتح الواتساب، تأكد من تثبيت التطبيق')),
        );
      }
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}