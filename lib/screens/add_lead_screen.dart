import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/home/widgets/home_accent.dart';
import '../services/leads_service.dart';
import '../widgets/speech_text_field.dart';

/// ─────────────────────────────────────────────────────────────
/// ➕ إضافة Lead يدوي — مطابق لنموذج بلازور (LeadsCrmCreateDto)
///
/// 📌 إضافة حقل جديد؟ اتبع الخطوات:
///   1) أضف الحقل في السيرفس:  lib/services/leads_service.dart (createLead)
///   2) أضف سطر حقل هنا في المجموعة المناسبة (استخدم _field / _halfField)
///   3) أضف القيمة في دالة _submit → body
/// ─────────────────────────────────────────────────────────────
class AddLeadScreen extends StatefulWidget {
  final int? userId;
  final String? username;

  const AddLeadScreen({super.key, this.userId, this.username});

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  // ═══════════════ الحقول (Controllers) ═══════════════
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _projectTypeCtrl = TextEditingController();
  final _projectStageCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _decisionMakerCtrl = TextEditingController();
  final _nextActionCtrl = TextEditingController();
  final _bestTimeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  int? _assignedEmployeeId;
  List<dynamic> _employees = [];
  bool _loadingEmployees = true;
  bool _saving = false;

  // ── حقول الفرص البيعية (المصدر + الحملة + المتابعة) ──
  List<Map<String, dynamic>> _sources = [];
  List<Map<String, dynamic>> _adTypes = [];
  Map<String, dynamic>? _selectedSource;
  Map<String, dynamic>? _selectedAdType;
  DateTime? _nextFollowUp;
  final _guidanceCtrl = TextEditingController();

  // ── خيارات النموذج (من جدول الليدز بدون تكرار) ──
  List<String> _projectTypes = [];
  List<String> _cities = [];
  List<String> _bestTimes = [];
  List<String> _nextActions = [];
  Map<String, List<String>> _areasByCity = {};
  List<String> _areaSuggestions = []; // مناطق المدينة المختارة حاليًا
  bool _loadingFormOptions = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadSources();
    _loadAdTypes();
    _loadFormOptions();
  }

  Future<void> _loadFormOptions() async {
    final opts = await LeadsService.getLeadFormOptions();
    if (!mounted) return;
    setState(() {
      _projectTypes = opts.projectTypes;
      _cities = opts.cities;
      _bestTimes = opts.bestTimes;
      _nextActions = opts.nextActions;
      _areasByCity = opts.areasByCity;
      _loadingFormOptions = false;
    });
  }

  /// لما المستخدم يختار مدينة → نجيب مناطقها من الداتا المسجلة
  void _onCityPicked(String city) {
    setState(() {
      _areaSuggestions = _areasByCity[city.trim()] ?? [];
      // لو المنطقة الحالية مش تابعة للمدينة الجديدة → نفضيها
      final current = _areaCtrl.text.trim();
      if (current.isNotEmpty && !_areaSuggestions.contains(current)) {
        _areaCtrl.clear();
      }
    });
  }

  Future<void> _loadSources() async {
    final list = await LeadsService.getSources();
    if (mounted) setState(() => _sources = list);
  }

  Future<void> _loadAdTypes() async {
    final list = await LeadsService.getAdTypes();
    if (mounted) setState(() => _adTypes = list);
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _phone2Ctrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _areaCtrl.dispose();
    _addressCtrl.dispose();
    _projectTypeCtrl.dispose();
    _projectStageCtrl.dispose();
    _budgetCtrl.dispose();
    _decisionMakerCtrl.dispose();
    _nextActionCtrl.dispose();
    _bestTimeCtrl.dispose();
    _notesCtrl.dispose();
    _guidanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final emps = await LeadsService.getEmployees();
    if (!mounted) return;
    setState(() {
      _employees = emps;
      _loadingEmployees = false;
    });
  }

  String _uname() => widget.username ?? '';

  // ═══════════════ الحفظ ═══════════════

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final result = await LeadsService.createLead(
        fullName: _fullNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        phone2: _phone2Ctrl.text.trim(),
        email: _emailCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        area: _areaCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        projectType: _projectTypeCtrl.text.trim(),
        projectStage: _projectStageCtrl.text.trim(),
        budget: _budgetCtrl.text.trim(),
        decisionMaker: _decisionMakerCtrl.text.trim(),
        nextAction: _nextActionCtrl.text.trim(),
        bestTimeToReach: _bestTimeCtrl.text.trim(),
        assignedEmployeeId: _assignedEmployeeId,
        notes: _notesCtrl.text.trim(),
        // المصدر + الحملة + المتابعة (من الفرص البيعية)
        platform: _selectedSource?['SourceName']?.toString(),
        sourceNameAr: _selectedSource?['SourceNameAr']?.toString(),
        campaignName: _selectedAdType?['AdTypeName']?.toString(),
        adTypeNameAr: _selectedAdType?['AdTypeNameAr']?.toString(),
        guidance: _guidanceCtrl.text.trim(),
        nextFollowUp: _nextFollowUp != null
            ? _nextFollowUp!.toIso8601String()
            : null,
        userName: _uname(),
      );

      if (!mounted) return;

      final ok = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '✅ تم إنشاء الـ Lead بنجاح${result['leadId'] != null ? ' — #${result['leadId']}' : ''}'
                : (result['message']?.toString() ?? 'حدث خطأ'),
            style: GoogleFonts.cairo(fontSize: 13),
          ),
          backgroundColor: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      if (ok) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e', style: GoogleFonts.cairo(fontSize: 13)),
          backgroundColor: const Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ═══════════════ الواجهة ═══════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0f172a) : const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text(
          'إضافة Lead يدوي',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        backgroundColor: HomeAccent.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'حفظ',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white70),
                  )
                : const Icon(Icons.check_rounded),
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            _buildHeroCard(isDark),

            const SizedBox(height: 16),

            // ═══ 1) بيانات العميل الأساسية ═══
            _buildGroup(
              isDark,
              icon: Icons.badge_rounded,
              title: 'بيانات العميل',
              color: HomeAccent.indigo,
              children: [
                _field(
                  isDark,
                  icon: Icons.person_rounded,
                  label: 'اسم العميل *',
                  hint: 'الاسم الكامل',
                  controller: _fullNameCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 12),
                // رقم الهاتف الأساسي — سطر كامل + زر واتساب
                _phoneField(
                  isDark,
                  icon: Icons.phone_rounded,
                  label: 'رقم الهاتف *',
                  hint: '01xxxxxxxxx',
                  controller: _phoneCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'الهاتف مطلوب' : null,
                ),
                const SizedBox(height: 12),
                // الرقم البديل — سطر كامل + زر واتساب
                _phoneField(
                  isDark,
                  icon: Icons.phone_android_rounded,
                  label: 'رقم بديل',
                  hint: 'اختياري',
                  controller: _phone2Ctrl,
                ),
                const SizedBox(height: 12),
                _field(
                  isDark,
                  icon: Icons.email_rounded,
                  label: 'البريد الإلكتروني',
                  hint: 'اختياري',
                  controller: _emailCtrl,
                  keyboard: TextInputType.emailAddress,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ═══ 2) الموقع ═══
            _buildGroup(
              isDark,
              icon: Icons.location_on_rounded,
              title: 'الموقع',
              color: HomeAccent.teal,
              children: [
                // المدينة — قائمة من المدن المسجلة + إضافة جديدة
                _suggestField(
                  isDark,
                  controller: _cityCtrl,
                  icon: Icons.location_city_rounded,
                  label: 'المدينة',
                  hint: _loadingFormOptions
                      ? 'جاري تحميل المدن...'
                      : 'اختر أو اكتب المدينة',
                  suggestions: _cities,
                  onPicked: _onCityPicked,
                ),
                const SizedBox(height: 12),
                // المنطقة — مناطق المدينة المختارة (أو كتابة حرة)
                _suggestField(
                  isDark,
                  controller: _areaCtrl,
                  icon: Icons.map_rounded,
                  label: 'المنطقة',
                  hint: _cityCtrl.text.trim().isNotEmpty
                      ? (_areaSuggestions.isEmpty
                          ? 'لا توجد مناطق مسجلة — اكتب منطقة جديدة'
                          : 'اختر أو اكتب المنطقة')
                      : 'اختر المدينة أولاً أو اكتب مباشرة',
                  suggestions: _areaSuggestions,
                ),
                const SizedBox(height: 12),
                _field(
                  isDark,
                  icon: Icons.home_work_rounded,
                  label: 'العنوان',
                  hint: 'اختياري',
                  controller: _addressCtrl,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ═══ 3) مصدر التواصل (من الفرص البيعية) ═══
            _buildGroup(
              isDark,
              icon: Icons.contact_phone_rounded,
              title: 'مصدر التواصل',
              color: HomeAccent.purple,
              children: [
                _sourceDropdown(isDark),
                const SizedBox(height: 12),
                _adTypeDropdown(isDark),
                const SizedBox(height: 12),
                _followUpDateBtn(isDark),
              ],
            ),

            const SizedBox(height: 14),

            // ═══ 4) بيانات المشروع ═══
            _buildGroup(
              isDark,
              icon: Icons.shopping_bag_rounded,
              title: 'بيانات المشروع',
              color: const Color(0xFF2563EB),
              children: [
                // نوع المشروع — قائمة منسدلة + كتابة + إضافة جديدة
                _suggestField(
                  isDark,
                  controller: _projectTypeCtrl,
                  icon: Icons.category_rounded,
                  label: 'نوع المشروع / المنتج',
                  hint: _loadingFormOptions
                      ? 'جاري تحميل الأنواع...'
                      : 'اختر أو اكتب نوع المشروع',
                  suggestions: _projectTypes,
                ),
                const SizedBox(height: 12),
                _field(
                  isDark,
                  icon: Icons.attach_money_rounded,
                  label: 'الميزانية',
                  hint: 'مثال: 2,500,000',
                  controller: _budgetCtrl,
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _field(
                  isDark,
                  icon: Icons.assignment_rounded,
                  label: 'مرحلة المشروع',
                  hint: 'مثال: بحث / بناء',
                  controller: _projectStageCtrl,
                ),
                const SizedBox(height: 12),
                _field(
                  isDark,
                  icon: Icons.person_outline_rounded,
                  label: 'صاحب القرار',
                  hint: 'اختياري',
                  controller: _decisionMakerCtrl,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ═══ 5) المتابعة ═══
            _buildGroup(
              isDark,
              icon: Icons.event_available_rounded,
              title: 'المتابعة',
              color: HomeAccent.amber,
              children: [
                // الإجراء التالي — سطر كامل + قائمة من المسجل
                _suggestField(
                  isDark,
                  controller: _nextActionCtrl,
                  icon: Icons.touch_app_rounded,
                  label: 'الإجراء التالي',
                  hint: _loadingFormOptions
                      ? 'جاري تحميل الإجراءات...'
                      : 'اختر أو اكتب الإجراء التالي',
                  suggestions: _nextActions,
                ),
                const SizedBox(height: 12),
                // أفضل وقت للتواصل — سطر كامل + قائمة من المسجل
                _suggestField(
                  isDark,
                  controller: _bestTimeCtrl,
                  icon: Icons.schedule_rounded,
                  label: 'أفضل وقت للتواصل',
                  hint: _loadingFormOptions
                      ? 'جاري تحميل الأوقات...'
                      : 'اختر أو اكتب أفضل وقت',
                  suggestions: _bestTimes,
                ),
                const SizedBox(height: 12),
                // توجيهات المتابعة (من الفرص البيعية) — بالميكرفون
                SpeechTextField(
                  controller: _guidanceCtrl,
                  label: 'توجيهات المتابعة',
                  hint: 'مثال: أرسل الكتالوج... أو اضغط المايك 🎤',
                  icon: Icons.format_list_bulleted_rounded,
                  maxLines: 3,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ═══ 7) الموظف المسؤول ═══
            _buildGroup(
              isDark,
              icon: Icons.person_rounded,
              title: 'الموظف المسؤول',
              color: HomeAccent.green,
              children: [
                _employeeDropdown(isDark),
              ],
            ),

            const SizedBox(height: 14),

            // ═══ 6) ملاحظات ═══
            _buildGroup(
              isDark,
              icon: Icons.notes_rounded,
              title: 'ملاحظات',
              color: HomeAccent.orange,
              children: [
                SpeechTextField(
                  controller: _notesCtrl,
                  label: 'ملاحظات',
                  hint: 'أي تفاصيل إضافية... أو اضغط المايك 🎤',
                  icon: Icons.notes_rounded,
                  maxLines: 3,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ═══ زر الحفظ ═══
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: HomeAccent.gold,
                  foregroundColor: const Color(0xFF0D1A2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF0D1A2A)),
                      )
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  _saving ? 'جاري الحفظ...' : 'حفظ الـ Lead',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }

  // ═══════════════ مكونات مساعدة ═══════════════

  Widget _buildHeroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [HomeAccent.navyDark, HomeAccent.navyLight],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeAccent.gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: HomeAccent.gold.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة عميل محتمل يدوياً',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'أدخل بيانات العميل المحتمل — الحقول المطلوبة: الاسم والهاتف',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(
    bool isDark, {
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// حقل نصي كامل العرض
  /// — أضف أي حقل جديد هنا بنسخ سطر واحد
  Widget _field(
    bool isDark, {
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      style: GoogleFonts.cairo(fontSize: 14),
      validator: validator,
      decoration: _inputDecoration(isDark, icon: icon, label: label, hint: hint),
    );
  }

  /// حقل هاتف بسطر كامل + زر واتساب جنبه (يفتح wa.me بالرقم)
  Widget _phoneField(
    bool isDark, {
    required IconData icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      style: GoogleFonts.cairo(fontSize: 14),
      validator: validator,
      decoration: _inputDecoration(isDark, icon: icon, label: label, hint: hint)
          .copyWith(
        suffixIcon: IconButton(
          tooltip: 'فتح واتساب بهذا الرقم',
          icon: const Icon(Icons.chat_rounded),
          color: const Color(0xFF25D366),
          onPressed: () => _openWhatsApp(controller.text),
        ),
      ),
    );
  }

  /// فتح محادثة واتساب بالرقم (بتحويل 01... → 201... للأرقام المصرية)
  Future<void> _openWhatsApp(String phone) async {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتب رقم الهاتف الأول ثم اضغط واتساب'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (digits.startsWith('0')) digits = '2$digits'; // 01x → 201x
    final url = 'https://wa.me/$digits';
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        throw Exception('لا يمكن فتح واتساب');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر فتح واتساب: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// حقل نوع المشروع — كتابة حرة + قائمة منسدلة من جدول الليدز + إضافة قيمة جديدة
  /// حقل مع اقتراحات من جدول الليدز + إضافة قيمة جديدة (نمط موحد)
  /// بيستخدمه: نوع المشروع، المدينة، المنطقة، الإجراء التالي، أفضل وقت
  Widget _suggestField(
    bool isDark, {
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    required List<String> suggestions,
    String? Function(String?)? validator,
    ValueChanged<String>? onPicked,
  }) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.cairo(fontSize: 14),
      validator: validator,
      decoration: _inputDecoration(isDark, icon: icon, label: label, hint: hint)
          .copyWith(
        suffixIcon: IconButton(
          tooltip: 'اختر من القائمة',
          icon: const Icon(Icons.arrow_drop_down_circle_rounded),
          color: HomeAccent.accent,
          onPressed: () => _showSuggestPicker(
            title: label,
            icon: icon,
            suggestions: suggestions,
          ).then((picked) {
            if (picked == null || !mounted) return;
            if (picked == '__ADD__') {
              _askNewValue(label: label, icon: icon).then((newValue) {
                if (newValue != null && newValue.trim().isNotEmpty && mounted) {
                  final v = newValue.trim();
                  setState(() => controller.text = v);
                  onPicked?.call(v);
                }
              });
            } else {
              setState(() => controller.text = picked);
              onPicked?.call(picked);
            }
          }),
        ),
      ),
    );
  }

  /// قائمة منسدلة بالاقتراحات + خيار إضافة جديدة
  Future<String?> _showSuggestPicker({
    required String title,
    required IconData icon,
    required List<String> suggestions,
  }) async {
    final theme = Theme.of(context);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: HomeAccent.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'اختر $title',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in suggestions)
                    ListTile(
                      leading: Icon(icon, size: 20, color: HomeAccent.accent),
                      title: Text(s, style: GoogleFonts.cairo(fontSize: 13.5)),
                      onTap: () => Navigator.pop(context, s),
                    ),
                  if (suggestions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'لا توجد قيم مسجلة بعد — أضف أول قيمة من الزر تحت 👇',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.add_circle_rounded,
                        size: 20, color: Color(0xFF43A047)),
                    title: Text(
                      'إضافة قيمة جديدة',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF43A047),
                      ),
                    ),
                    onTap: () => Navigator.pop(context, '__ADD__'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// حوار كتابة قيمة جديدة (نوع مشروع / مدينة / وقت / إجراء...)
  Future<String?> _askNewValue({
    required String label,
    required IconData icon,
  }) async {
    final ctrl = TextEditingController();
    final theme = Theme.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(icon, size: 20, color: HomeAccent.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'إضافة $label جديد',
                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.cairo(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'اكتب القيمة...',
            hintStyle: GoogleFonts.cairo(fontSize: 12.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء',
                style: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            style: FilledButton.styleFrom(
              backgroundColor: HomeAccent.gold,
              foregroundColor: const Color(0xFF0D1A2A),
            ),
            child: Text('إضافة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }


  /// تنسيق موحد لكل الحقول
  InputDecoration _inputDecoration(
    bool isDark, {
    required IconData icon,
    String? label,
    required String hint,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: GoogleFonts.cairo(
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      labelStyle: GoogleFonts.cairo(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: isDark
          ? theme.colorScheme.surfaceContainerHighest
          : Colors.white,
      // مساحة أوسع للحقول — أريح للكتابة على الموبايل
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: HomeAccent.gold, width: 1.6),
      ),
    );
  }

  // ═══════════════ حقول مصدر التواصل (من الفرص البيعية) ═══════════════

  /// قائمة المصادر — نفس قيم الفرص (ContactSources) مع الأيقونة
  Widget _sourceDropdown(bool isDark) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<Map<String, dynamic>?>(
      initialValue: _selectedSource,
      isExpanded: true,
      decoration: _inputDecoration(
        isDark,
        icon: Icons.contact_phone_rounded,
        hint: _sources.isEmpty
            ? 'جاري تحميل المصادر...'
            : 'اختر مصدر التواصل (اختياري)',
      ),
      items: [
        const DropdownMenuItem<Map<String, dynamic>?>(
          value: null,
          child: Text('بدون مصدر', style: TextStyle(fontSize: 13)),
        ),
        ..._sources.map((s) => DropdownMenuItem<Map<String, dynamic>?>(
              value: s,
              child: Row(
                children: [
                  Text('${s['SourceIcon'] ?? '📌'}  ',
                      style: const TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      s['SourceNameAr']?.toString() ??
                          s['SourceName']?.toString() ??
                          '',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
      ],
      onChanged: _saving
          ? null
          : (v) => setState(() {
                _selectedSource = v;
                // لو المصدر اتغير → نفضي الحملة (كل حملة ليها مصدرها)
                _selectedAdType = null;
              }),
      style: GoogleFonts.cairo(fontSize: 13.5),
      dropdownColor: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
    );
  }

  /// قائمة الحملات الإعلانية — نفس قيم الفرص (AdTypes)
  Widget _adTypeDropdown(bool isDark) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<Map<String, dynamic>?>(
      initialValue: _selectedAdType,
      isExpanded: true,
      decoration: _inputDecoration(
        isDark,
        icon: Icons.campaign_rounded,
        hint: _adTypes.isEmpty
            ? 'جاري تحميل الحملات...'
            : 'اختر الحملة الإعلانية (اختياري)',
      ),
      items: [
        const DropdownMenuItem<Map<String, dynamic>?>(
          value: null,
          child: Text('بدون حملة', style: TextStyle(fontSize: 13)),
        ),
        ..._adTypes.map((a) => DropdownMenuItem<Map<String, dynamic>?>(
              value: a,
              child: Text(
                a['AdTypeNameAr']?.toString() ??
                    a['AdTypeName']?.toString() ??
                    '',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            )),
      ],
      onChanged: _saving
          ? null
          : (v) => setState(() => _selectedAdType = v),
      style: GoogleFonts.cairo(fontSize: 13.5),
      dropdownColor: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
    );
  }

  /// تاريخ المتابعة القادمة — منتَقي تاريخ
  Widget _followUpDateBtn(bool isDark) {
    final theme = Theme.of(context);
    final hasDate = _nextFollowUp != null;
    return InkWell(
      onTap: _saving ? null : _pickFollowUpDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.event_available_rounded,
                size: 18,
                color: hasDate
                    ? HomeAccent.accent
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasDate
                    ? 'المتابعة القادمة: ${DateFormat('yyyy/MM/dd').format(_nextFollowUp!)}'
                    : 'تاريخ المتابعة القادمة (اختياري)',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: hasDate ? FontWeight.w800 : FontWeight.w500,
                  color: hasDate
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (hasDate)
              InkWell(
                onTap: _saving
                    ? null
                    : () => setState(() => _nextFollowUp = null),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextFollowUp ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'تاريخ المتابعة القادمة',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
    );
    if (picked != null && mounted) {
      setState(() => _nextFollowUp = picked);
    }
  }

  Widget _employeeDropdown(bool isDark) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<int?>(
      initialValue: _assignedEmployeeId,
      isExpanded: true,
      decoration: _inputDecoration(
        isDark,
        icon: Icons.person_rounded,
        hint: _loadingEmployees ? 'جاري تحميل الموظفين...' : 'اختر الموظف المسؤول (اختياري)',
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('بدون إسناد', style: TextStyle(fontSize: 13)),
        ),
        ..._employees.map((e) {
          final id = (e['EmployeeID'] ?? e['employeeId'] ?? e['EmployeeId']);
          final name = (e['FullName'] ?? e['fullName'] ?? 'موظف').toString();
          return DropdownMenuItem<int?>(
            value: id is num ? id.toInt() : int.tryParse(id.toString()),
            child: Text(name,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: _saving
          ? null
          : (v) => setState(() => _assignedEmployeeId = v),
      style: GoogleFonts.cairo(fontSize: 13.5),
      dropdownColor: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
    );
  }
}