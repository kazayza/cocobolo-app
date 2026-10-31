import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import '../core/auth/session_service.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/permission_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/design_kit.dart';
import 'add_shift_screen.dart';
import 'all_shifts_screen.dart';
import 'employee_shifts_screen.dart';

/// إدارة الشيفتات — شاشة موحّدة تستضيف المحتوىين القائمين دون
/// ازدواج منطق: تبويب «المتابعة» هو محتوى AllShiftsScreen نفسه،
/// وتبويب «حسب الموظف» هو محتوى EmployeeShiftsScreen نفسه.
/// الظهور والبوابات كما كانت: التبويب يظهر لمن كان يرى مدخله في
/// القائمة، وزر الإسناد بصلاحية التعديل نفسها التي تحرس الإضافة.
class ShiftsManagementScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ShiftsManagementScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ShiftsManagementScreen> createState() => _ShiftsManagementScreenState();
}

class _ShiftsManagementScreenState extends State<ShiftsManagementScreen> {
  final _followUpKey = GlobalKey<AllShiftsContentState>();
  final _perEmployeeKey = GlobalKey<EmployeeShiftsContentState>();

  late final bool _canFollowUp;
  late final bool _canPerEmployee;
  late final bool _canAssign;

  int _activeTab = 0;

  bool get _isDark => ThemeService().isDarkMode;

  /// التبويبات المتاحة لهذا المستخدم بترتيبها الثابت
  List<String> get _tabIds => [
        if (_canFollowUp) 'follow',
        if (_canPerEmployee) 'employee',
      ];

  @override
  void initState() {
    super.initState();
    final perms = PermissionService();
    _canFollowUp = perms.canView(FormNames.allShifts);
    _canPerEmployee = perms.canView(FormNames.employeeShifts);
    // نفس بوابة إجراء الإضافة اليوم: canEdit على نموذج شيفتات الموظفين
    _canAssign = perms.canEdit(FormNames.employeeShifts);
  }

  void _refreshActiveTab() {
    final ids = _tabIds;
    if (ids.isEmpty) return;
    switch (ids[_activeTab]) {
      case 'follow':
        _followUpKey.currentState?.fetchShifts();
        break;
      case 'employee':
        _perEmployeeKey.currentState?.fetchData();
        break;
    }
  }

  /// إسناد شيفت: اختيار موظف من نفس مصدر شاشة الموظفين، ثم نموذج
  /// الإضافة/التعديل نفسه وبنفس بوابة الصلاحية، ثم تحديث التبويبات.
  Future<void> _openAssignFlow() async {
    final emp = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const _AssignEmployeePickerScreen(),
      ),
    );
    if (emp == null || !mounted) return;

    // التحقق من صلاحية التعديل — نفس فحص _openAddShiftScreen حرفيًا
    if (!PermissionService().canEdit(FormNames.employeeShifts)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية التعديل')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddShiftScreen(
          username: widget.username,
          employeeId: (emp['EmployeeID'] as num).toInt(),
          employeeName: emp['FullName']?.toString() ?? '',
          currentShift: emp['EmployeeShiftID'] != null ? emp : null,
        ),
      ),
    );

    if (result == true && mounted) {
      // تحديث التبويبين معًا (كلاهما مركّب في IndexedStack) فلا
      // يرى المستخدم بيانات قديمة عند التبديل بينهما
      _followUpKey.currentState?.fetchShifts();
      _perEmployeeKey.currentState?.fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = _tabIds;
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: FormNames.shiftsManagement),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule_rounded,
                  color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'إدارة الشيفتات',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
            ),
          ],
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: const AppDrawerMenuButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            onPressed: _refreshActiveTab,
          ),
        ],
      ),
      body: ids.isEmpty
          ? const AppEmpty(
              icon: Icons.lock_rounded,
              message: 'ليس لديك صلاحية لعرض إدارة الشيفتات',
            )
          : Column(
              children: [
                _buildAnchorHeader(),
                if (ids.length > 1) _buildTabBar(ids),
                Expanded(
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      for (final id in ids) _buildTabContent(id),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabContent(String id) {
    switch (id) {
      case 'follow':
        return AllShiftsContent(
          key: _followUpKey,
          userId: widget.userId,
          username: widget.username,
        );
      default:
        return EmployeeShiftsContent(
          key: _perEmployeeKey,
          userId: widget.userId,
          username: widget.username,
        );
    }
  }

  // بطاقة مرساة كحلية: عنوان الشاشة + زر «إسناد شيفت» الذهبي الممتلئ
  Widget _buildAnchorHeader() {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.schedule_rounded,
                  color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إدارة الشيفتات',
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'متابعة شيفتات الموظفين وإسنادها',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (_canAssign) ...[
              const SizedBox(width: 10),
              Material(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: _openAssignFlow,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            color: AppColors.navy, size: 16),
                        const SizedBox(width: 5),
                        Text(
                          'إسناد شيفت',
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.navy,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
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
    );
  }

  // شريط تبويبات مجزّأ بهوية التطبيق (نفس نمط رقائق الفترات)
  Widget _buildTabBar(List<String> ids) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.divider(_isDark)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < ids.length; i++)
              Expanded(child: _buildTabSegment(ids[i], i)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSegment(String id, int index) {
    final selected = _activeTab == index;
    final label = id == 'follow' ? 'المتابعة' : 'حسب الموظف';
    final icon =
        id == 'follow' ? Icons.calendar_month_rounded : Icons.people_rounded;
    final selectedBg = _isDark ? AppColors.gold : AppColors.navy;
    final selectedFg = _isDark ? AppColors.navy : Colors.white;

    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? selectedFg : AppColors.textSecondary(_isDark),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? selectedFg
                        : AppColors.textSecondary(_isDark),
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// منتقي موظف لغرض الإسناد — نفس مصدر بيانات شاشة شيفتات الموظفين
/// (GET /api/shifts/status) ونفس مطابقة البحث فيها (الاسم/الوظيفة).
class _AssignEmployeePickerScreen extends StatefulWidget {
  const _AssignEmployeePickerScreen();

  @override
  State<_AssignEmployeePickerScreen> createState() =>
      _AssignEmployeePickerScreenState();
}

class _AssignEmployeePickerScreenState
    extends State<_AssignEmployeePickerScreen> {
  List<dynamic> _employees = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/shifts/status'),
        headers: SessionService.instance.authHeaders,
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _employees = data;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'فشل تحميل قائمة الموظفين (رمز ${res.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'فشل الاتصال بالخادم — تحقق من الشبكة وحاول مجددًا';
        });
      }
    }
  }

  List<dynamic> get _filtered {
    if (_query.isEmpty) return _employees;
    final q = _query.toLowerCase();
    return _employees.where((emp) {
      final name = emp['FullName']?.toString().toLowerCase() ?? '';
      final job = emp['JobTitle']?.toString().toLowerCase() ?? '';
      return name.contains(q) || job.contains(q);
    }).toList();
  }

  /// لون نوع الشيفت — نفس تعريف شاشتي الشيفتات (ألوان بلازور)
  Color _shiftTypeColor(String? type) {
    switch (type) {
      case 'صباحى':
        return _isDark ? AppColors.successLight : AppColors.success;
      case 'مسائى':
        return _isDark ? AppColors.warningLight : AppColors.warning;
      case 'عمل يومى':
        return _isDark ? AppColors.infoLight : AppColors.info;
      default:
        return _isDark ? AppColors.neutralLight : AppColors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_add_alt_rounded,
                  color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'اختيار الموظف',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
            ),
          ],
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? const AppLoading(message: 'جاري تحميل الموظفين...')
                : _error != null
                    ? AppError(message: _error!, onRetry: _fetch)
                    : _filtered.isEmpty
                        ? const AppEmpty(
                            icon: Icons.search_off_rounded,
                            message: 'لا توجد نتائج',
                            hint: 'حاول تعديل كلمات البحث',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) =>
                                _buildEmployeeRow(_filtered[index]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: TextField(
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.text(_isDark),
              fontSize: 14,
            ),
        decoration: InputDecoration(
          hintText: 'ابحث باسم الموظف أو الوظيفة...',
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _isDark
                    ? AppColors.textSecondary(_isDark)
                    : AppColors.textHint(_isDark),
                fontSize: 14,
              ),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.gold, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      color: AppColors.textSecondary(_isDark), size: 18),
                  onPressed: () => setState(() => _query = ''),
                )
              : null,
          filled: true,
          fillColor:
              _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: _isDark
                ? BorderSide(color: Colors.white.withValues(alpha: 0.12))
                : BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide(color: ThemeService().accentColor),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> emp) {
    final textTheme = Theme.of(context).textTheme;
    final hasShift = emp['EmployeeShiftID'] != null;
    final typeColor = _shiftTypeColor(emp['ShiftType']?.toString());
    final name = emp['FullName']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        color: AppColors.surface(_isDark),
        child: InkWell(
          onTap: () => Navigator.pop(context, emp),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (hasShift ? typeColor : AppColors.neutral)
                        .withValues(alpha: _isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '؟',
                      style: textTheme.titleMedium?.copyWith(
                        color: hasShift
                            ? typeColor
                            : AppColors.textSecondary(_isDark),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: textTheme.titleSmall?.copyWith(
                          color: AppColors.text(_isDark),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        emp['JobTitle']?.toString() ?? '',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(_isDark),
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (hasShift)
                  StatusBadge(
                    label: emp['ShiftType']?.toString() ?? '',
                    color: typeColor,
                    small: true,
                  )
                else
                  StatusBadge(
                    label: 'بدون شيفت',
                    color: _isDark ? AppColors.warningLight : AppColors.warning,
                    small: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
