import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../services/employee_photo_service.dart';
import '../services/permission_service.dart';
import 'add_employee_screen.dart'; // هننشئها بعدين
import 'employee_profile_screen.dart';
import '../core/auth/session_service.dart';

import '../widgets/app_drawer.dart';
class EmployeesScreen extends StatefulWidget {
  final int userId;
  final String username;

  const EmployeesScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<dynamic> employees = [];
  List<dynamic> filteredEmployees = [];
  List<String> departments = [];
  bool loading = true;
  String searchQuery = '';
  String? selectedDepartment;
  String selectedStatus = 'نشط'; // الافتراضي «نشط» بطلب المالك (تبويبات بلازور الأربع + الكل)

  // طريقة العرض: بطاقات (cards) افتراضيًا أو شبكة (grid) أو مدمجة
  // (compact) — تُحفظ في تفضيلات الجهاز وتُستعاد عند فتح الشاشة
  String _viewMode = 'cards';

  /// وضع الثيم الحالي — كل سطح ولون في هذه الشاشة يُشتق منه
  bool get _isDark => ThemeService().isDarkMode;

  // ألوان الحالة مطابقة لشارة ملف الموظف في بلازور — الدرجة الفاتحة
  // في الوضع الليلي والقاعدية في النهاري (قانون الشارات الموحّد)
  static Color statusColor(String? status, bool isDark) {
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

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    fetchEmployees();
    fetchLookups();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('employees_view_mode');
    final String mode = (stored == 'compact' ||
            stored == 'grid' ||
            stored == 'cards')
        ? stored!
        : 'cards';
    if (mounted && mode != _viewMode) {
      setState(() => _viewMode = mode);
    }
  }

  Future<void> _setViewMode(String mode) async {
    setState(() => _viewMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('employees_view_mode', mode);
  }

  Future<void> fetchEmployees() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/employees'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        setState(() {
          employees = jsonDecode(res.body);
          _filterEmployees();
          loading = false;
        });
        _preloadPhotos();
      }
    } catch (e) {
      setState(() => loading = false);
      _showErrorSnackBar('فشل في تحميل الموظفين');
    }
  }

  Future<void> fetchLookups() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/employees/lookups'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          departments = List<String>.from(data['departments']);
        });
      }
    } catch (e) {
      print('Error fetching lookups: $e');
    }
  }

  void _filterEmployees() {
    setState(() {
      filteredEmployees = employees.where((emp) {
        // فلترة البحث
        final name = emp['FullName']?.toString().toLowerCase() ?? '';
        final phone = emp['MobilePhone']?.toString() ?? '';
        final job = emp['JobTitle']?.toString().toLowerCase() ?? '';
        final matchesSearch = searchQuery.isEmpty ||
            name.contains(searchQuery.toLowerCase()) ||
            phone.contains(searchQuery) ||
            job.contains(searchQuery.toLowerCase());

        // فلترة القسم
        final matchesDept = selectedDepartment == null ||
            emp['Department'] == selectedDepartment;

        // فلترة الحالة — مطابقة حرفية للحالة (كانت «موقوف» تجمع كل
        // من ليس «نشط» فتُظهر المستقيل وبالإجازة بوصفهما موقوفين)
        final matchesStatus = selectedStatus == 'الكل' ||
            emp['Status'] == selectedStatus;

        return matchesSearch && matchesDept && matchesStatus;
      }).toList();
    });
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

  /// فتح شاشة إضافة موظف ثم تحديث القائمة عند الحفظ — نفس إجراء زر
  /// الإضافة العائم السابق، نُقل إلى زر بطاقة المرساة الذهبي
  Future<void> _openAddEmployee() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEmployeeScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    );
    if (result == true) fetchEmployees();
  }

  /// فتح ملف الموظف ثم تحديث القائمة عند رجوع تغيير — نفس إجراء نقر
  /// البطاقة السابق، تستخدمه البطاقات والصفوف المدمجة معًا
  Future<void> _openProfile(Map<String, dynamic> emp) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeProfileScreen(
          userId: widget.userId,
          username: widget.username,
          employeeId: emp['EmployeeID'],
          initialEmployee: emp,
        ),
      ),
    );
    if (changed == true) fetchEmployees();
  }

  /// بايتات صورة الموظف من التخزين المحلي على الجهاز فقط
  /// (EmployeePhotoService) — لا تأتي من الباك إند إطلاقًا؛ الغائب
  /// عن التخزين يرجع null فتُعرض الصورة الافتراضية بحسب النوع
  Uint8List? _photoBytes(Map<String, dynamic> emp) {
    return EmployeePhotoService()
        .bytesFor((emp['EmployeeID'] as num?)?.toInt());
  }

  /// الصورة الافتراضية المطابقة لنوع الموظف (حقل Gender كما يأتي من
  /// الباك إند): «أنثى» للأنثى، وما عداها (ذكر أو غائب) للذكر —
  /// أصل مُجمّع داخل التطبيق لا يأتي من أي خادم
  Widget _defaultAvatarImage(Map<String, dynamic> emp) {
    return Image.asset(
      emp['Gender']?.toString() == 'أنثى'
          ? 'assets/images/default_avatar_female.png'
          : 'assets/images/default_avatar_male.png',
      fit: BoxFit.cover,
      // لا يحدث عمليًا (أصل مُجمّع) — رمز شخص احتياطي أخير فقط
      errorBuilder: (_, __, ___) => Center(
        child: Icon(
          Icons.person_rounded,
          size: 26,
          color: _isDark ? AppColors.gold : AppColors.navy,
        ),
      ),
    );
  }

  /// محتوى الأفاتار المقصوص دائريًا: الصورة المحلية عند توفرها
  /// وسلامتها (وفشل رسمها يرجع للافتراضية)، وإلا الصورة الافتراضية
  Widget _avatarContent(Map<String, dynamic> emp, Uint8List? bytes) {
    if (bytes == null) return _defaultAvatarImage(emp);
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _defaultAvatarImage(emp),
    );
  }

  /// تحميل صور الموظفين المحلية إلى ذاكرة الخدمة ثم إعادة الرسم —
  /// تُستدعى بعد كل جلب ناجح للقائمة
  Future<void> _preloadPhotos() async {
    final service = EmployeePhotoService();
    await Future.wait([
      for (final emp in employees)
        if ((emp['EmployeeID'] as num?)?.toInt() != null)
          service.loadFor((emp['EmployeeID'] as num).toInt()),
    ]);
    if (mounted) setState(() {});
  }

  /// صورة الموظف الدائرية بحلقة ذهبية ونقطة حالة في ركنها — تُستخدم في
  /// البطاقة (48) والصف المدمج (36) بنفس اللغة: الصورة المحلية عند
  /// توفرها وسلامتها (وفشل رسمها يرجع للافتراضية)، وإلا الصورة
  /// الافتراضية المطابقة للنوع داخل الإطار الدائري نفسه
  Widget _buildAvatar(
    Map<String, dynamic> emp, {
    required double size,
    required Color dotColor,
  }) {
    final bytes = _photoBytes(emp);
    final dotOuter = size >= 48 ? 14.0 : 12.0;
    final dotInner = size >= 48 ? 10.0 : 8.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.navy.withValues(alpha: 0.08),
            // حلقة ذهبية دقيقة حول الصورة — لمسة الهوية
            border: Border.all(
              color: _isDark
                  ? AppColors.gold.withValues(alpha: 0.55)
                  : AppColors.goldDark.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.5),
            child: ClipOval(child: _avatarContent(emp, bytes)),
          ),
        ),
        PositionedDirectional(
          bottom: -2,
          start: -2,
          child: Container(
            width: dotOuter,
            height: dotOuter,
            decoration: BoxDecoration(
              color: AppColors.surface(_isDark),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: dotInner,
                height: dotInner,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frm_Employeeslist'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar( leading: const AppDrawerMenuButton(),
        title: Text(
          'الموظفين',
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              fetchEmployees();
              fetchLookups();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ترويسة ثابتة لا تتحرك مع التمرير: بطاقة مرساة مدمجة + بحث
          // وتبديل عرض + تبويبات الحالات — وما يتحرك هو الأقسام والبطاقات فقط
          _buildAnchorCard(),
          _buildSearchAndFilter(),
          _buildStatusTabs(),
          Expanded(
            child: loading
                ? const AppLoading()
                : filteredEmployees.isEmpty
                    ? Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _buildDeptChipsRow(),
                          ),
                          Expanded(child: _buildEmptyState()),
                        ],
                      )
                    : _viewMode == 'compact'
                        ? _buildCompactList()
                        : _viewMode == 'grid'
                            ? _buildGridList()
                            : _buildCardsList(),
          ),
        ],
      ),
    );
  }

  /// قائمة البطاقات: رقائق الأقسام أول عنصر متحرك، ثم البطاقات بدخولها
  /// المتدرج كما كانت
  Widget _buildCardsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredEmployees.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDeptChipsRow(),
          );
        }
        final i = index - 1;
        return _StaggeredItem(
          index: i,
          child: _buildEmployeeCard(filteredEmployees[i], i),
        );
      },
    );
  }

  /// العرض المدمج: رقائق الأقسام، ثم كتلة سطحية واحدة بصفوف رفيعة
  /// (56px) وفواصل شعرية — بلا حركة دخول، والنقر يفتح الملف نفسه
  Widget _buildCompactList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _buildDeptChipsRow(),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface(_isDark),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < filteredEmployees.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 60,
                    endIndent: 16,
                    color: AppColors.divider(_isDark),
                  ),
                _buildCompactRow(filteredEmployees[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// صف مدمج لموظف واحد: صورة 36 بنقطة الحالة، الاسم والوظيفة • القسم،
  /// وشارة الحالة — والإجراءات (اتصال/واتساب/تعديل) تبقى في ملف الموظف
  Widget _buildCompactRow(Map<String, dynamic> emp) {
    final color = statusColor(emp['Status']?.toString(), _isDark);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openProfile(emp),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildAvatar(emp, size: 36, dotColor: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp['FullName'] ?? 'بدون اسم',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.text(_isDark),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${emp['JobTitle'] ?? 'بدون وظيفة'} • ${emp['Department'] ?? 'بدون قسم'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: emp['Status']?.toString() ?? '—',
                color: color,
                small: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// العرض الشبكي: رقائق الأقسام أول عنصر متحرك، ثم شبكة بعمودين على
  /// نمط لوحة الموارد البشرية التي أرسلها المالك — خلايا بطاقية بصورة
  /// كبيرة ونقطة حالة في ركن الخلية، بلا أزرار إجراءات، ونقر الخلية
  /// كلها يفتح ملف الموظف، وبدخول متدرج كالبطاقات
  Widget _buildGridList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _buildDeptChipsRow(),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.74,
          ),
          itemCount: filteredEmployees.length,
          itemBuilder: (context, i) => _StaggeredItem(
            index: i,
            child: _buildGridCell(filteredEmployees[i]),
          ),
        ),
      ],
    );
  }

  /// خلية شبكية لموظف واحد: نقطة حالة في الركن الختامي العلوي، صورة
  /// دائرية كبيرة (80px) بحلقة ذهبية رفيعة، الاسم، الوظيفة • القسم،
  /// شارة الحالة، ثم فاصل شعري وتذييل «عرض التفاصيل» بمعالجة الهوية
  /// (الذهبي نصًا في الليلي فقط — قانون التباين)
  Widget _buildGridCell(Map<String, dynamic> emp) {
    final color = statusColor(emp['Status']?.toString(), _isDark);
    final textTheme = Theme.of(context).textTheme;
    final linkColor = _isDark ? AppColors.gold : AppColors.navy;
    return AppCard(
      padding: EdgeInsets.zero,
      color: AppColors.surface(_isDark),
      onTap: () => _openProfile(emp),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: Column(
              children: [
                _buildGridAvatar(emp),
                const SizedBox(height: 10),
                Text(
                  emp['FullName'] ?? 'بدون اسم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.text(_isDark),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${emp['JobTitle'] ?? 'بدون وظيفة'} • ${emp['Department'] ?? 'بدون قسم'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 7),
                StatusBadge(
                  label: emp['Status']?.toString() ?? '—',
                  color: color,
                  small: true,
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: AppColors.divider(_isDark)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'عرض التفاصيل',
                      style: textTheme.labelLarge?.copyWith(
                        color: linkColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 16,
                      color: linkColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // نقطة الحالة في الركن الختامي العلوي للخلية (نهاية اتجاه
          // القراءة) — بحلقة بلون السطح تفصلها عن الخلفية
          PositionedDirectional(
            top: 10,
            end: 10,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surface(_isDark),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// أفاتار الخلية الشبكية الكبير (80px): حلقة ذهبية رفيعة والمحتوى
  /// نفسه (محلي أو افتراضي بحسب النوع)، وبلا نقطة حالة — نقطة الخلية
  /// في ركنها هي مؤشر الحالة هنا
  Widget _buildGridAvatar(Map<String, dynamic> emp) {
    final bytes = _photoBytes(emp);
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.navy.withValues(alpha: 0.08),
        border: Border.all(
          color: _isDark
              ? AppColors.gold.withValues(alpha: 0.55)
              : AppColors.goldDark.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: ClipOval(child: _avatarContent(emp, bytes)),
      ),
    );
  }

  /// بطاقة المرساة الكحلية المدمجة — ثابتة أعلى الشاشة لا تتحرك مع
  /// التمرير وبطلب المالك صارت صفًا واحدًا مدمجًا (~70px): العنوان
  /// ورقاقة الإجمالي الذهبية وسطر إحصاءات رفيع وزر الإضافة الذهبي
  Widget _buildAnchorCard() {
    final canAdd = PermissionService().canAdd(FormNames.employeesAdd);
    final textTheme = Theme.of(context).textTheme;
    int countOf(String status) =>
        employees.where((e) => e['Status'] == status).length;

    return _StaggeredItem(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Container(
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
                // حلقتان ذهبيتان متّحدتا المركز — زخرفة حرفية خافتة مقصوصة
                // في الركن العلوي من البطاقة، خلف المحتوى ودون لمس
                PositionedDirectional(
                  top: -34,
                  start: -34,
                  child: _anchorRing(80, 0.10),
                ),
                PositionedDirectional(
                  top: -60,
                  start: -60,
                  child: _anchorRing(132, 0.06),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'فريق العمل',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // رقاقة الإجمالي الذهبية: العدد و«موظف» معًا
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    '${employees.length} موظف',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: AppColors.navy,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // سطر إحصاءات رفيع واحد: التسمية بلون أبيض
                            // خافت والعدد بلون ذهبي فاتح عريض
                            Text.rich(
                              TextSpan(
                                children: [
                                  _anchorStat('نشط', countOf('نشط')),
                                  _anchorStatSep(),
                                  _anchorStat('موقوف', countOf('موقوف')),
                                  _anchorStatSep(),
                                  _anchorStat('بالإجازة', countOf('بالإجازة')),
                                  _anchorStatSep(),
                                  _anchorStat('مستقيل', countOf('مستقيل')),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (canAdd) ...[
                        const SizedBox(width: 10),
                        Material(
                          color: AppColors.gold,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _openAddEmployee,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_add_rounded,
                                    size: 17,
                                    color: AppColors.navy,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'موظف جديد',
                                    style: textTheme.labelLarge?.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
        ),
      ),
    );
  }

  /// حلقة زخرفية ذهبية خافتة لبطاقة المرساة (حدّ خارجي فقط، بلا تعبئة)
  Widget _anchorRing(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: alpha),
          width: 1.5,
        ),
      ),
    );
  }

  /// جزء إحصاء واحد في سطر بطاقة المرساة الرفيع: التسمية بيضاء خافتة
  /// والعدد ذهبي فاتح عريض، بحجم 11
  TextSpan _anchorStat(String label, int count) {
    final base = Theme.of(context).textTheme.labelSmall;
    return TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: base?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        TextSpan(
          text: '$count',
          style: base?.copyWith(
            color: AppColors.goldLight,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// فاصل نقطي بين إحصاءات سطر بطاقة المرساة
  TextSpan _anchorStatSep() {
    return TextSpan(
      text: '  ·  ',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.goldLight.withValues(alpha: 0.6),
            fontSize: 11,
          ),
    );
  }

  Widget _buildSearchAndFilter() {
    // وضوح البحث في الليلي: تعبئة بدرجة البطاقة الأخف (لا درجة السطح
    // نفسها)، وحدّ أبيض خافت، وتلميح بلون النص الثانوي المقروء، وأيقونة
    // ذهبية — والنهاري كما هو تمامًا
    final darkBorder = _isDark
        ? BorderSide(color: Colors.white.withValues(alpha: 0.12))
        : BorderSide.none;
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.surface(_isDark),
      child: Row(
        children: [
          // شريط البحث — حبة كاملة الاستدارة
          Expanded(
            child: TextField(
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.text(_isDark),
                  ),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم، الوظيفة، أو الهاتف...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _isDark
                          ? AppColors.textSecondary(_isDark)
                          : AppColors.textHint(_isDark),
                    ),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                filled: true,
                fillColor:
                    _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: darkBorder,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: darkBorder,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: ThemeService().accentColor),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                searchQuery = value;
                _filterEmployees();
              },
            ),
          ),
          const SizedBox(width: 8),
          _buildViewToggle(),
        ],
      ),
    );
  }

  /// مفتاح تبديل طريقة العرض: بطاقات / شبكة / مدمجة — المختار بمعالجة
  /// الهوية (ذهبي بنص كحلي ليليًا، وكحلي بنص أبيض نهاريًا) ويُحفظ
  /// اختيار المستخدم
  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(999),
        border: _isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.12))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewToggleButton(Icons.view_agenda_rounded, 'cards'),
          _viewToggleButton(Icons.grid_view_rounded, 'grid'),
          _viewToggleButton(Icons.view_list_rounded, 'compact'),
        ],
      ),
    );
  }

  Widget _viewToggleButton(IconData icon, String mode) {
    final selected = _viewMode == mode;
    return Material(
      color: selected
          ? (_isDark ? AppColors.gold : AppColors.navy)
          : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _setViewMode(mode),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 18,
            color: selected
                ? (_isDark ? AppColors.navy : Colors.white)
                : AppColors.textSecondary(_isDark),
          ),
        ),
      ),
    );
  }

  /// صف رقائق فلترة الأقسام — أول عنصر متحرك في القائمة (بطاقات أو
  /// مدمجة)، بعد أن كان مثبّتًا داخل حاوية البحث
  Widget _buildDeptChipsRow() {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('الكل', selectedDepartment == null, () {
            setState(() {
              selectedDepartment = null;
              _filterEmployees();
            });
          }),
          ...departments.map((dept) => _buildFilterChip(
                dept,
                selectedDepartment == dept,
                () {
                  setState(() {
                    selectedDepartment = dept;
                    _filterEmployees();
                  });
                },
              )),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        border: Border(bottom: BorderSide(color: AppColors.divider(_isDark))),
      ),
      child: Row(
        children: [
          _buildStatusTab('الكل', employees.length),
          _buildStatusTab('نشط', employees.where((e) => e['Status'] == 'نشط').length),
          _buildStatusTab('موقوف', employees.where((e) => e['Status'] == 'موقوف').length),
          _buildStatusTab('بالإجازة', employees.where((e) => e['Status'] == 'بالإجازة').length),
          _buildStatusTab('مستقيل', employees.where((e) => e['Status'] == 'مستقيل').length),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String title, int count) {
    final isSelected = selectedStatus == title;
    // التبويب المختار بلون التمييز — الذهبي مسموح كنص في الليلي فقط،
    // وفي النهاري يُستخدم الكحلي (قانون التباين في ملف القواعد)
    final selectedColor = _isDark ? ThemeService().accentColor : AppColors.navy;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedStatus = title;
            _filterEmployees();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: isSelected
                ? Border(bottom: BorderSide(color: selectedColor, width: 2))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? selectedColor
                            : AppColors.textSecondary(_isDark),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? selectedColor
                          : AppColors.textSecondary(_isDark),
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? AppColors.navy
                    : AppColors.text(_isDark),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.gold,
        backgroundColor:
            _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp, int index) {
    final color = statusColor(emp['Status']?.toString(), _isDark);
    final canEdit = PermissionService().canEdit(FormNames.employeesAdd);
    final textTheme = Theme.of(context).textTheme;
    final callColor = _isDark ? AppColors.successLight : AppColors.success;
    final editColor = _isDark ? AppColors.gold : AppColors.navy;
    final hasActions = emp['MobilePhone'] != null || canEdit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        color: AppColors.surface(_isDark),
        onTap: () => _openProfile(emp),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // حافة حالة قائدة: شريط عمودي 3px بلون الحالة بكامل ارتفاع
              // البطاقة وبحواف مستديرة، داخل بنية حشوة البطاقة
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
            children: [
              Row(
                children: [
                  // الصورة (من التخزين المحلي عند توفرها) أو الافتراضية
                  // بحسب النوع — دائرية بحلقة ذهبية ونقطة حالة في ركنها
                  _buildAvatar(emp, size: 48, dotColor: color),
                  const SizedBox(width: 12),
                  // البيانات
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp['FullName'] ?? 'بدون اسم',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.text(_isDark),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          emp['JobTitle'] ?? 'بدون وظيفة',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary(_isDark),
                            fontSize: 12.5,
                          ),
                        ),
                        if (emp['Department'] != null) ...[
                          const SizedBox(height: 5),
                          // القسم رقاقة صغيرة مظلّلة بالهوية لا نصًا عاريًا
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : AppColors.navy.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              emp['Department'],
                              style: textTheme.bodySmall?.copyWith(
                                color: _isDark
                                    ? AppColors.goldLight
                                    : AppColors.navy,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // الحالة — النص الفعلي لحالة الموظف لا ثنائية نشط/موقوف
                  StatusBadge(
                    label: emp['Status']?.toString() ?? '—',
                    color: color,
                    small: true,
                  ),
                ],
              ),
              // خط فاصل شعري ثم صف إجراءات مُسمّاة بعرض متساوٍ لكل إجراء —
              // نفس شروط الظهور والمعالجات السابقة تمامًا
              if (hasActions) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: AppColors.divider(_isDark)),
                _buildActionRow(emp, canEdit, callColor, editColor),
              ],
            ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// صف إجراءات البطاقة: إجراءات مُسمّاة بعرض متساوٍ، بين كل إجراءين
  /// فاصل شعري عمودي — نفس شروط الظهور والمعالجات السابقة تمامًا
  Widget _buildActionRow(
    Map<String, dynamic> emp,
    bool canEdit,
    Color callColor,
    Color editColor,
  ) {
    final actions = <Widget>[
      if (emp['MobilePhone'] != null) ...[
        _cardAction(
          icon: Icon(
            Icons.call_rounded,
            size: 18,
            color: callColor,
          ),
          label: 'اتصال',
          color: callColor,
          onTap: () {
            _makePhoneCall(emp['MobilePhone']);
          },
        ),
        _cardAction(
          icon: const FaIcon(
            FontAwesomeIcons.whatsapp,
            size: 18,
            color: AppColors.whatsapp,
          ),
          label: 'واتساب',
          color: AppColors.whatsapp,
          onTap: () {
            _openWhatsApp(emp['MobilePhone']);
          },
        ),
      ],
      if (canEdit)
        _cardAction(
          icon: Icon(
            Icons.edit_rounded,
            size: 18,
            color: editColor,
          ),
          label: 'تعديل',
          color: editColor,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEmployeeScreen(
                  userId: widget.userId,
                  username: widget.username,
                  existingEmployee: emp,
                ),
              ),
            );
            if (result == true) fetchEmployees();
          },
        ),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 18,
              color: AppColors.divider(_isDark),
            ),
          actions[i],
        ],
      ],
    );
  }

  /// إجراء مُسمّى في صف إجراءات البطاقة: أيقونة 18 + تسمية 11.5 عريضة،
  /// بعرض متساوٍ مع بقية الإجراءات الظاهرة في الصف
  Widget _cardAction({
    required Widget icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmpty(
      icon: Icons.people_outline,
      message: 'لا يوجد موظفين',
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
/// دخول متدرج خفيف (تلاشٍ + انزلاق لأعلى ~260ms) بتأخير متدرج محدود
/// بحسب موضع العنصر — ينتهي دائمًا عند الشفافية الكاملة، بلا حركات متكررة
class _StaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredItem({required this.index, required this.child});

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _opacity = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curved);

    final delayMs = widget.index.clamp(0, 8) * 45;
    if (delayMs == 0) {
      _controller.forward();
    } else {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
