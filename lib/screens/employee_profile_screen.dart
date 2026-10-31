import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../services/employee_photo_service.dart';
import '../services/permission_service.dart';
import '../services/penalty_service.dart';
import '../core/auth/session_service.dart';
import 'add_employee_screen.dart';
import 'add_penalty_screen.dart';
import 'hr/loan_detail_screen.dart';

// ألوان الحالة — نفس خريطة قائمة الموظفين وملف بلازور، بدرجة الوضع:
// الفاتحة في الليلي والقاعدية في النهاري (قانون الشارات الموحّد)
Color employeeStatusColor(String? status, bool isDark) {
  switch (status) {
    case 'نشط':
      return isDark ? AppColors.successLight : AppColors.success;
    case 'موقوف':
      return isDark ? AppColors.errorLight : AppColors.error;
    case 'بالإجازة':
      return isDark ? AppColors.infoLight : AppColors.info;
    case 'مستقيل':
      return AppColors.errorLight;
    default:
      return isDark ? AppColors.neutralLight : AppColors.neutral;
  }
}

/// ملف الموظف — مرآة EmployeeProfile في بلازور بالأقسام التي تدعمها
/// واجهات الباك إند القائمة: نظرة عامة (بيانات أساسية + سجل تغيّر
/// المرتب) + الرواتب + السلف + الشيفتات. القراءة فقط، والتعديل من
/// نموذج الموظف نفسه.
class EmployeeProfileScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int employeeId;
  final Map<String, dynamic>? initialEmployee;

  const EmployeeProfileScreen({
    Key? key,
    required this.userId,
    required this.username,
    required this.employeeId,
    this.initialEmployee,
  }) : super(key: key);

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  Map<String, dynamic>? _employee;
  List<dynamic> _salaryHistory = [];
  List<dynamic> _payrolls = [];
  List<dynamic> _loans = [];
  int _activeLoansCount = 0;
  List<dynamic> _penalties = [];
  List<dynamic> _shifts = [];
  Map<int, String> _branches = {};
  bool _loading = true;
  bool _notFound = false;
  bool _dirty = false;

  final _moneyFmt = intl.NumberFormat('#,##0.00');
  final _dateFmt = intl.DateFormat('yyyy/MM/dd');

  /// وضع الثيم الحالي — كل سطح ولون في هذه الشاشة يُشتق منه
  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _employee = widget.initialEmployee;
    _loadAll();
    _loadPhoto();
  }

  Future<dynamic> _getJson(String url) async {
    final res = await http.get(
      Uri.parse(url),
      headers: SessionService.instance.authHeaders,
    );
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body);
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _getJson('$baseUrl/api/employees/${widget.employeeId}'),
        _getJson('$baseUrl/api/employees/${widget.employeeId}/salary-history'),
        _getJson('$baseUrl/api/payroll/employee/${widget.employeeId}'),
        _getJson('$baseUrl/api/loans/statement/${widget.employeeId}'),
        _getJson('$baseUrl/api/shifts/employee/${widget.employeeId}'),
        _getJson('$baseUrl/api/employees/lookups'),
        PenaltyService()
            .forEmployee(widget.employeeId)
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;
      final detail = results[0];
      if (detail == null) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }

      final statement = results[3];
      final lookups = results[5];
      setState(() {
        _employee = Map<String, dynamic>.from(detail as Map);
        _salaryHistory = (results[1] as List?) ?? [];
        _payrolls = (results[2] as List?) ?? [];
        if (statement is Map) {
          _loans = (statement['Loans'] as List?) ?? [];
          _activeLoansCount = (statement['ActiveLoansCount'] as num?)?.toInt() ?? 0;
        }
        _shifts = (results[4] as List?) ?? [];
        _penalties = (results[6] as List?) ?? [];
        if (lookups is Map && lookups['branches'] is List) {
          _branches = {
            for (final b in lookups['branches'] as List)
              (b['id'] as num).toInt(): b['name']?.toString() ?? '',
          };
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('فشل تحميل ملف الموظف'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    return d == null ? '—' : _dateFmt.format(d);
  }

  /// تحويل متسامح لقيمة رقمية قادمة من الباك إند: المبالغ قد تصل
  /// أرقامًا أو نصوصًا («9500.00») بحسب نوع العمود والسائق — القراءة
  /// الآمنة بدل التحويل القسري الذي يُسقط البناء بخطأ نوع
  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double? _asDoubleOrNull(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  String _fmtMoney(dynamic v) {
    final n = _asDoubleOrNull(v);
    return n == null ? '—' : '${_moneyFmt.format(n)} جـ';
  }

  Color _payrollStatusColor(String? s) {
    switch (s) {
      case 'مدفوع':
        return _isDark ? AppColors.successLight : AppColors.success;
      case 'معتمد':
        // الذهبي لون الشارة: في النهاري تُستخدم درجته الداكنة للنص
        return _isDark ? AppColors.gold : AppColors.goldDark;
      case 'قيد المراجعة':
        return _isDark ? AppColors.infoLight : AppColors.info;
      case 'مرفوض':
      case 'ملغي':
        return _isDark ? AppColors.errorLight : AppColors.error;
      default:
        return _isDark ? AppColors.neutralLight : AppColors.neutral;
    }
  }

  String _loanStatusAr(String? s) {
    switch (s) {
      case 'Active':
        return 'نشطة';
      case 'Completed':
        return 'مكتملة';
      case 'Cancelled':
        return 'ملغاة';
      default:
        return s ?? '—';
    }
  }

  Color _loanStatusColor(String? s) {
    switch (s) {
      case 'Active':
        return _isDark ? AppColors.successLight : AppColors.success;
      case 'Cancelled':
        return _isDark ? AppColors.errorLight : AppColors.error;
      default:
        return _isDark ? AppColors.neutralLight : AppColors.neutral;
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    var phone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.startsWith('0')) phone = '2$phone';
    final Uri uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openEdit() async {
    if (_employee == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEmployeeScreen(
          userId: widget.userId,
          username: widget.username,
          existingEmployee: _employee,
        ),
      ),
    );
    if (result == true) {
      _dirty = true;
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = PermissionService().canEdit(FormNames.employeesAdd);
    final emp = _employee;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _dirty);
      },
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context, _dirty),
          ),
          title: Text(
            'ملف الموظف',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
            if (canEdit && emp != null)
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _openEdit),
          ],
        ),
        body: _loading
            ? const AppLoading()
            : _notFound || emp == null
                ? const AppEmpty(icon: Icons.person_off_outlined, message: 'لم يتم العثور على الموظف المطلوب.')
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHero(emp),
                      const SizedBox(height: 12),
                      _buildBasicData(emp),
                      const SizedBox(height: 12),
                      _buildSalaryHistory(),
                      const SizedBox(height: 12),
                      _buildPayrolls(),
                      const SizedBox(height: 12),
                      _buildLoans(),
                      const SizedBox(height: 12),
                      _buildPenalties(),
                      const SizedBox(height: 12),
                      _buildShifts(),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }

  /// تحميل الصورة المحلية المحفوظة لهذا الموظف على الجهاز (إن وُجدت)
  /// — لا تأتي من الباك إند إطلاقًا
  Future<void> _loadPhoto() async {
    await EmployeePhotoService().loadFor(widget.employeeId);
    if (mounted) setState(() {});
  }

  /// الصورة الافتراضية المطابقة لنوع الموظف (حقل Gender): «أنثى»
  /// للأنثى، وما عداها (ذكر أو غائب) للذكر — أصل مُجمّع داخل التطبيق
  Widget _defaultHeroImage(Map<String, dynamic> emp) {
    return Image.asset(
      emp['Gender']?.toString() == 'أنثى'
          ? 'assets/images/default_avatar_female.png'
          : 'assets/images/default_avatar_male.png',
      fit: BoxFit.cover,
      // لا يحدث عمليًا (أصل مُجمّع) — رمز شخص احتياطي أخير فقط
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.person_rounded, size: 30, color: AppColors.gold),
      ),
    );
  }

  /// صورة البطل الدائرية 64px بحلقة ذهبية: الصورة المحلية عند توفرها
  /// (وفشل رسمها يرجع للافتراضية)، وإلا الصورة الافتراضية بحسب النوع
  Widget _buildHeroAvatar(Map<String, dynamic> emp) {
    final Uint8List? bytes =
        EmployeePhotoService().bytesFor(widget.employeeId);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: ClipOval(
          child: bytes == null
              ? _defaultHeroImage(emp)
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _defaultHeroImage(emp),
                ),
        ),
      ),
    );
  }

  /// بلاطة إحصاء صغيرة داخل بطاقة البطل الكحلية: القيمة بيضاء عريضة
  /// فوق تسمية ذهبية فاتحة، على أرضية بيضاء خافتة — لغة بلاطات المرساة
  Widget _heroTile(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.goldLight,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(Map<String, dynamic> emp) {
    final status = emp['Status']?.toString();
    // البطاقة كحلية في الوضعين، فدرجة شارة الحالة هي درجة الأسطح الداكنة
    final color = employeeStatusColor(status, true);
    final phone = emp['MobilePhone']?.toString();
    final branchName = _branches[(emp['BranchID'] as num?)?.toInt()];
    dynamic currentShift;
    for (final s in _shifts) {
      if (s['EffectiveTo'] == null) {
        currentShift = s;
        break;
      }
    }
    final textTheme = Theme.of(context).textTheme;

    // بلاطات أسفل البطل من قيم محمّلة فعلًا فقط — ما غاب يُحذف ولا يُخترع
    final tiles = <Widget>[
      if (branchName != null && branchName.isNotEmpty)
        _heroTile('الفرع', branchName),
      if (currentShift != null)
        _heroTile('الشيفت الحالي', currentShift['ShiftType']?.toString() ?? ''),
      if (status != null && status.isNotEmpty)
        _heroTile('الحالة الوظيفية', status),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyDark.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildHeroAvatar(emp),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp['FullName']?.toString() ?? 'بدون اسم',
                              style: textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${emp['JobTitle'] ?? 'بدون وظيفة'} • ${emp['Department'] ?? 'بدون قسم'}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.goldLight,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(label: status ?? '—', color: color, small: true),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (emp['BioEmployeeID'] != null)
                        _heroChip(Icons.fingerprint, 'كود البصمة: ${emp['BioEmployeeID']}'),
                      if (emp['IsPermanentlyExempt'] == true)
                        _heroChip(Icons.verified_user_outlined, 'معفى من البصمة'),
                      if (branchName != null && branchName.isNotEmpty)
                        _heroChip(Icons.business_outlined, branchName),
                      if (currentShift != null)
                        _heroChip(Icons.schedule_outlined, 'الشيفت الحالي: ${currentShift['ShiftType'] ?? ''}'),
                    ],
                  ),
                  if (phone != null && phone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _circleActionButton(
                          background: AppColors.success.withValues(alpha: 0.12),
                          onTap: () => _makePhoneCall(phone),
                          child: Icon(
                            Icons.call_rounded,
                            size: 19,
                            color: AppColors.successLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _circleActionButton(
                          background: AppColors.whatsapp.withValues(alpha: 0.12),
                          onTap: () => _openWhatsApp(phone),
                          child: const FaIcon(
                            FontAwesomeIcons.whatsapp,
                            size: 19,
                            color: AppColors.whatsapp,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (tiles.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (var i = 0; i < tiles.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          tiles[i],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // خط شعري ذهبي متدرج على الحافة الداخلية السفلية للبطاقة
            PositionedDirectional(
              bottom: 0,
              start: 0,
              end: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.6),
                      AppColors.goldLight.withValues(alpha: 0.6),
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

  /// زر إجراء دائري مظلّل (40px) — نفس نمط كروت القائمة
  Widget _circleActionButton({
    required Widget child,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: child),
        ),
      ),
    );
  }

  /// ترويسة قسم بهوية واحدة: شريط ذهبي + أيقونة داخل رقاقة مظلّلة بالذهبي
  Widget _sectionHeader({
    required String title,
    required IconData icon,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: _isDark ? 0.18 : 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: _isDark ? AppColors.gold : AppColors.navy,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(_isDark),
                ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  /// رقاقة داخل بطاقة البطل الكحلية (كحلية في الوضعين): أرضية وحدّ
  /// أبيضان خافتان، وأيقونة ذهبية، ونص أبيض شبه كامل
  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.gold,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }

  /// بلاطة بيانات مصغّرة داخل قسم البيانات الأساسية: رقاقة أيقونة
  /// مظلّلة (30px) بجانب تسمية خافتة صغيرة فوق قيمة شبه عريضة، على
  /// أرضية لوحة داخلية (درجة البطاقة ليليًا ودرجة تعبئة الحقول نهاريًا)
  Widget _basicTile(IconData icon, String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: _isDark ? 0.18 : 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 17,
              color: _isDark ? AppColors.gold : AppColors.navy,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  softWrap: true,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.text(_isDark),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicData(Map<String, dynamic> emp) {
    // الحقول نفسها وبنفس الترتيب السابق تمامًا — العرض فقط تغيّر:
    // شبكة بلاطات بعمودين، والقيم الطويلة (العنوان/الملاحظات) بعرض كامل
    final entries = <(IconData, String, String, bool)>[
      (Icons.person_rounded, 'الاسم', emp['FullName']?.toString() ?? '—', false),
      (Icons.business_rounded, 'القسم', emp['Department']?.toString() ?? '—', false),
      (Icons.supervisor_account_rounded, 'المدير المباشر', emp['directManagerName']?.toString() ?? emp['DirectManagerName']?.toString() ?? '—', false),
      (Icons.work_rounded, 'الوظيفة', emp['JobTitle']?.toString() ?? '—', false),
      (Icons.wc_rounded, 'النوع', emp['Gender']?.toString() ?? '—', false),
      (Icons.credit_card_rounded, 'الرقم القومي', emp['NationalID']?.toString() ?? '—', false),
      (Icons.cake_rounded, 'تاريخ الميلاد', _fmtDate(emp['BirthDate']), false),
      (Icons.school_rounded, 'المؤهل العلمي', emp['qualification']?.toString() ?? '—', false),
      (Icons.event_rounded, 'سنة التخرج', emp['yearqualification']?.toString() ?? '—', false),
      (Icons.event_available_rounded, 'تاريخ التعيين', _fmtDate(emp['HireDate']), false),
      (Icons.event_busy_rounded, 'تاريخ الانتهاء', _fmtDate(emp['EndDate']), false),
      (Icons.info_rounded, 'الحالة', emp['Status']?.toString() ?? '—', false),
      (Icons.payments_rounded, 'المرتب الحالي', _fmtMoney(emp['CurrentSalaryBase']), false),
      (Icons.fingerprint_rounded, 'معفى من البصمة', emp['IsPermanentlyExempt'] == true ? 'نعم' : 'لا', false),
      (Icons.email_rounded, 'البريد', emp['EmailAddress']?.toString() ?? '—', false),
      (Icons.phone_rounded, 'الموبايل', emp['MobilePhone']?.toString() ?? '—', false),
      (Icons.phone_android_rounded, 'موبايل إضافي', emp['MobilePhone2']?.toString() ?? '—', false),
      (Icons.location_on_rounded, 'العنوان', emp['Address']?.toString() ?? '—', true),
      if (emp['Notes'] != null && emp['Notes'].toString().isNotEmpty)
        (Icons.notes_rounded, 'ملاحظات', emp['Notes'].toString(), true),
    ];
    final rows = <Widget>[];
    var i = 0;
    while (i < entries.length) {
      final e = entries[i];
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      if (e.$4 || i + 1 >= entries.length || entries[i + 1].$4) {
        rows.add(_basicTile(e.$1, e.$2, e.$3));
        i += 1;
      } else {
        final n = entries[i + 1];
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _basicTile(e.$1, e.$2, e.$3)),
              const SizedBox(width: 8),
              Expanded(child: _basicTile(n.$1, n.$2, n.$3)),
            ],
          ),
        );
        i += 2;
      }
    }
    return AppCard(
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title: 'البيانات الأساسية', icon: Icons.badge_outlined),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildSalaryHistory() {
    return AppCard(
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: 'سجل تغيّر المرتب',
            icon: Icons.history_outlined,
            trailing: _salaryHistory.isEmpty ? null : StatusBadge(label: '${_salaryHistory.length} سجل', color: AppColors.gold, small: true),
          ),
          const SizedBox(height: 8),
          if (_salaryHistory.isEmpty)
            Text(
              'لا يوجد سجل تغييرات مرتبات حتى الآن.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 13,
                  ),
            )
          else
            _buildSalaryTimeline(),
        ],
      ),
    );
  }

  /// خط زمني لسجل تغيّر المرتب — نفس مكوّن نموذج الموظف: خط عمودي
  /// متصل بلون الفاصل ونقاط ذهبية محاطة بحلقة، والإدخالات كما حُمّلت
  Widget _buildSalaryTimeline() {
    return Column(
      children: [
        for (var i = 0; i < _salaryHistory.length; i++)
          _buildSalaryTimelineEntry(
            _salaryHistory[i],
            isFirst: i == 0,
            isLast: i == _salaryHistory.length - 1,
          ),
      ],
    );
  }

  Widget _buildSalaryTimelineEntry(
    dynamic h, {
    required bool isFirst,
    required bool isLast,
  }) {
    final oldS = _asDouble(h['OldSalary']);
    final newS = _asDouble(h['NewSalary']);
    final diff = newS - oldS;
    final diffColor = diff > 0
        ? (_isDark ? AppColors.successLight : AppColors.success)
        : (diff < 0
            ? (_isDark ? AppColors.errorLight : AppColors.error)
            : AppColors.textSecondary(_isDark));
    final textTheme = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // سكة الخط: مقطع علوي قصير يصل بالعقدة السابقة، نقطة ذهبية
          // محاطة بحلقة بلون السطح، ثم خط ممتد حتى العقدة التالية
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst
                      ? Colors.transparent
                      : AppColors.divider(_isDark),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold,
                    border: Border.all(
                      color: AppColors.surface(_isDark),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : AppColors.divider(_isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _fmtDate(h['ChangeDate']),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(_isDark),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'من ${_moneyFmt.format(oldS)} إلى ${_moneyFmt.format(newS)} جـ',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.text(_isDark),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${diff > 0 ? '+' : ''}${_moneyFmt.format(diff)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: diffColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (h['Reason'] != null && h['Reason'].toString().isNotEmpty)
                    Text(
                      'السبب: ${h['Reason']}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 12,
                      ),
                    ),
                  if (h['CreatedBy'] != null && h['CreatedBy'].toString().isNotEmpty)
                    Text(
                      'بواسطة: ${h['CreatedBy']}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 12,
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

  /// شريط ملخص الرواتب: صافي أحدث سجل (بحسب شهر الراتب نفسه) رقمًا
  /// كبيرًا بمعالجة الهوية (الذهبي في الليلي، والكحلي في النهاري —
  /// قانون التباين) على أرضية مظلّلة بالذهبي، مع تسمية فترته
  Widget _buildPayrollSummary(Map<String, dynamic> latest) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: _isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آخر راتب — الصافي',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  latest['PayrollMonth']?.toString() ?? '—',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _fmtMoney(latest['NetSalary']),
            style: textTheme.headlineSmall?.copyWith(
              color: _isDark ? AppColors.gold : AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// صف راتب واحد: الفترة عنوانًا مع شارة الحالة، والصافي مُبرزًا،
  /// والأساسي قيمة خافتة مصاحبة — من الحقول نفسها التي كان الصف يقرؤها
  Widget _buildPayrollRow(dynamic p) {
    final status = p['PaymentStatus']?.toString();
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                p['PayrollMonth']?.toString() ?? '—',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.text(_isDark),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              StatusBadge(label: status ?? '—', color: _payrollStatusColor(status), small: true),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'الصافي ',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 12,
                ),
              ),
              Text(
                _fmtMoney(p['NetSalary']),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.text(_isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'الأساسي ${_fmtMoney(p['BasicSalary'])}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayrolls() {
    // أحدث سجل بحسب حقل شهر الراتب نفسه (الأشهر بصيغة ISO تُقارن
    // نصيًا بأمان) — لا افتراض لترتيب وصول القائمة
    Map<String, dynamic>? latest;
    for (final p in _payrolls) {
      final m = p as Map<String, dynamic>;
      if (latest == null ||
          (m['PayrollMonth']?.toString() ?? '')
                  .compareTo(latest['PayrollMonth']?.toString() ?? '') >
              0) {
        latest = m;
      }
    }
    return AppCard(
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: 'الرواتب',
            icon: Icons.payments_outlined,
            trailing: _payrolls.isEmpty ? null : StatusBadge(label: '${_payrolls.length} راتب', color: AppColors.gold, small: true),
          ),
          const SizedBox(height: 8),
          if (_payrolls.isEmpty)
            Text(
              'لا توجد رواتب مسجلة لهذا الموظف.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 13,
                  ),
            )
          else ...[
            _buildPayrollSummary(latest!),
            ..._payrolls.map(_buildPayrollRow),
          ],
        ],
      ),
    );
  }

  Widget _buildLoans() {
    double remainingTotal = 0;
    for (final l in _loans) {
      if (l['Status'] == 'Active') {
        remainingTotal += _asDouble(l['RemainingAmount']);
      }
    }
    return AppCard(
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: 'السلف',
            icon: Icons.account_balance_outlined,
            trailing: _loans.isEmpty ? null : StatusBadge(label: '${_loans.length} سلفة', color: AppColors.gold, small: true),
          ),
          const SizedBox(height: 8),
          if (_loans.isEmpty)
            Text(
              'لا توجد سلف مسجلة لهذا الموظف.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 13,
                  ),
            )
          else ...[
            Text(
              'سلف نشطة: $_activeLoansCount • إجمالي المتبقي: ${_moneyFmt.format(remainingTotal)} جـ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    // الذهبي نصًا في الليلي فقط — النهاري كحلي الهوية
                    color: _isDark ? AppColors.gold : AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            ..._loans.map(_buildLoanCard),
          ],
        ],
      ),
    );
  }

  /// فتح تفاصيل السلفة من بطاقتها في الملف؛ أي إجراء داخلها (إلغاء/
  /// تخطي/تقسيم/تعديل) يرجع true فتُعاد قراءة أقسام الملف
  Future<void> _openLoanDetail(dynamic l) async {
    final loanId = (l['LoanId'] as num?)?.toInt() ??
        (l['LoanID'] as num?)?.toInt() ??
        0;
    if (loanId <= 0) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LoanDetailScreen(loanId: loanId, username: widget.username),
      ),
    );
    if (changed == true) {
      _dirty = true;
      _loadAll();
    }
  }

  /// بطاقة سلفة واحدة: القيمة الإجمالية مُبرزة مع التاريخ وشارة
  /// الحالة، وشريط تقدم ذهبي (المدفوع ÷ الإجمالي من الحقول نفسها:
  /// القيمة والمتبقي)، والمتبقي والقسط خافتين أسفله
  Widget _buildLoanCard(dynamic l) {
    final total = _asDouble(l['LoanAmount']);
    final remaining = _asDouble(l['RemainingAmount']);
    final ratio =
        total > 0 ? ((total - remaining) / total).clamp(0.0, 1.0) : 0.0;
    final status = l['Status']?.toString();
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => _openLoanDetail(l),
      child: Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _fmtMoney(l['LoanAmount']),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.text(_isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmtDate(l['LoanDate']),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 11.5,
                ),
              ),
              const Spacer(),
              StatusBadge(label: _loanStatusAr(status), color: _loanStatusColor(status), small: true),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.divider(_isDark),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'المتبقي ${_fmtMoney(l['RemainingAmount'])}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                'القسط ${_fmtMoney(l['MonthlyInstallment'])}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  /// صف شيفت واحد: رقاقة أيقونة مظلّلة، الاسم شبه العريض، نطاق
  /// الوقت رقاقة صغيرة، وفترة السريان خافتة أسفل الاسم — الحقول نفسها
  Widget _buildShiftRow(dynamic s) {
    final isCurrent = s['EffectiveTo'] == null;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: _isDark ? 0.18 : 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 17,
              color: _isDark ? AppColors.gold : AppColors.navy,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      s['ShiftType']?.toString() ?? '—',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.text(_isDark),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _isDark
                            ? AppColors.card(_isDark)
                            : AppColors.inputFill(_isDark),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${s['StartTime'] ?? ''} - ${s['EndTime'] ?? ''}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(_isDark),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'من ${_fmtDate(s['EffectiveFrom'])}${isCurrent ? '' : ' إلى ${_fmtDate(s['EffectiveTo'])}'}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            StatusBadge(
              label: 'الحالي',
              color: _isDark ? AppColors.successLight : AppColors.success,
              small: true,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openNewPenalty() async {
    final emp = _employee;
    if (emp == null) return;
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddPenaltyScreen(
          userId: widget.userId,
          username: widget.username,
          preselectedEmployeeId: widget.employeeId,
          preselectedEmployeeName: emp['FullName']?.toString(),
          preselectedEmployeeJob: emp['JobTitle']?.toString(),
        ),
      ),
    );
    if (created == true) {
      _dirty = true;
      _loadAll();
    }
  }

  /// قسم الجزاءات — بعد قسم السلف وبنفس لغته: شارة عدد في الترويسة
  /// وحبة «جزاء جديد» عند توفر صلاحية الإنشاء، وصفوف بشارة الحالة
  /// والنوع والقيمة المحسوبة والشهر والسبب
  Widget _buildPenalties() {
    final canCreate = PermissionService().canCreatePenalties;
    return AppCard(
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: 'الجزاءات',
            icon: Icons.gavel_outlined,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_penalties.isNotEmpty)
                  StatusBadge(label: '${_penalties.length} جزاء', color: AppColors.gold, small: true),
                if (canCreate) ...[
                  if (_penalties.isNotEmpty) const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _openNewPenalty,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: Text(
                      'جزاء جديد',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_penalties.isEmpty)
            Text(
              'لا توجد جزاءات مسجلة لهذا الموظف.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 13,
                  ),
            )
          else
            ..._penalties.map(_buildPenaltyRow),
        ],
      ),
    );
  }

  /// صف جزاء واحد: سطر النوع مع شارة الحالة، والمبلغ المحسوب عند
  /// الاعتماد/التطبيق (وإلا القيمة الخام)، والشهر المستهدف والسبب
  Widget _buildPenaltyRow(dynamic p) {
    final row = Map<String, dynamic>.from(p as Map);
    final status = row['status']?.toString();
    final isDays = row['penaltyType']?.toString() != 'Amount';
    final computed = (row['computedAmount'] as num?)?.toDouble() ??
        double.tryParse('${row['computedAmount'] ?? ''}');
    final fixed = (row['fixedAmount'] as num?)?.toDouble() ??
        double.tryParse('${row['fixedAmount'] ?? ''}');
    final amountText = (computed != null &&
            (status == 'Approved' || status == 'Applied'))
        ? _fmtMoney(computed)
        : (!isDays && fixed != null)
            ? _fmtMoney(fixed)
            : (isDays ? '${formatPenaltyDays(row['daysCount'])} يوم' : '—');
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                penaltyTypeLine(row),
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.text(_isDark),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              StatusBadge(label: penaltyStatusLabel(status), color: penaltyStatusColor(status, _isDark), small: true),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                amountText,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.text(_isDark),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'شهر الخصم: ${row['targetMonth'] ?? '—'}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (row['rolledFrom'] != null)
            Text(
              'نُقل من شهر ${row['rolledFrom']}',
              style: textTheme.bodySmall?.copyWith(
                color: _isDark ? AppColors.warningLight : AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (row['reason'] != null && row['reason'].toString().isNotEmpty)
            Text(
              'السبب: ${row['reason']}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary(_isDark),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShifts() {
    return AppCard(
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            title: 'الشيفتات',
            icon: Icons.schedule_outlined,
            trailing: _shifts.isEmpty ? null : StatusBadge(label: '${_shifts.length} سجل', color: AppColors.gold, small: true),
          ),
          const SizedBox(height: 8),
          if (_shifts.isEmpty)
            Text(
              'لا يوجد سجل شيفتات لهذا الموظف.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 13,
                  ),
            )
          else
            ..._shifts.map(_buildShiftRow),
        ],
      ),
    );
  }
}
