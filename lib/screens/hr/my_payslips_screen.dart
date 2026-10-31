import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../services/payroll_service.dart';
import '../../services/permission_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/design_kit.dart';
import '../../widgets/employee_picker.dart';
import 'payroll_status.dart';
import 'payslip_screen.dart';

/// «قسيمتي» — قسائم راتب المستخدم نفسه بحسب ربط حسابه بموظف.
///
/// سلوك الشاشة:
/// - مربوط بموظف: قسائمه هو فقط، الأحدث أولًا.
/// - مدير رواتب (نفس بوابة الدرج لعنصر «سجل المرتبات») ومربوط:
///   قسائمه + إجراء «قسيمة موظف آخر» في شريط العنوان.
/// - مدير وغير مربوط: يبدأ مباشرة من حالة اختيار موظف.
/// - غير مدير وغير مربوط: حالة فارغة صريحة بلا أي منتقٍ.
/// غير المدير لا يرى المنتقِي إطلاقًا مهما كانت حالته.
class MyPayslipsScreen extends StatefulWidget {
  final int userId;
  final String username;
  const MyPayslipsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<MyPayslipsScreen> createState() => _MyPayslipsScreenState();
}

class _MyPayslipsScreenState extends State<MyPayslipsScreen> {
  final PayrollService _service = PayrollService();

  bool _loading = true;
  String? _error;
  int? _linkedEmployeeId;
  int? _viewEmployeeId;
  String? _viewEmployeeName;
  bool _viewingOther = false;
  List<dynamic> _payrolls = [];

  bool get _isDark => ThemeService().isDarkMode;

  /// مدير رواتب = بوابة عرض الرواتب في الـAPI وبلازور معًا
  /// (canViewPayrollModule: تشمل المحاسب ومدير الحسابات بصيغتيه
  /// ومطالبتي العرض)، مع بقاء ظهور المدير العام كما استقر.
  /// (النسخة السابقة سألت عن صلاحية «frm_PayrollList» — اسم لا وجود
  /// له في جدول صلاحيات بلازور أصلًا، فكان ذلك المسار ميتًا.)
  bool get _isManager {
    final perms = PermissionService();
    return perms.canViewPayrollModule ||
        perms.canSeeAllHR ||
        perms.isGeneralManager;
  }

  String _formatMonth(String m) {
    try {
      final parts = m.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMMM yyyy', 'ar').format(d);
    } catch (_) {
      return m;
    }
  }

  String _formatMoney(dynamic v) {
    final n = v is num ? v : num.tryParse('$v') ?? 0;
    return NumberFormat('#,##0').format(n);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final linked = await _service.getLinkedEmployee(widget.userId);
      if (!mounted) return;
      _linkedEmployeeId = linked;
      if (linked != null) {
        await _loadPayrolls(linked, viewingOther: false);
      } else if (_isManager) {
        // مدير بلا ربط: حالة اختيار موظف مباشرة (بلا قائمة)
        setState(() {
          _payrolls = [];
          _viewEmployeeId = null;
          _viewingOther = true;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadPayrolls(int employeeId, {required bool viewingOther}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.getByEmployee(employeeId);
      if (!mounted) return;
      setState(() {
        _payrolls = rows;
        _viewEmployeeId = employeeId;
        _viewingOther = viewingOther;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickOtherEmployee() async {
    if (!_isManager) return;
    final employees = await fetchActiveEmployeeOptions();
    if (!mounted) return;
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تعذر تحميل قائمة الموظفين'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final picked = await showEmployeePickerSheet(
      context,
      employees: employees,
      title: 'قسيمة موظف آخر — اختر الموظف',
    );
    if (picked == null || !mounted) return;
    _viewEmployeeName = picked.name;
    await _loadPayrolls(picked.id, viewingOther: true);
  }

  void _backToMine() {
    final linked = _linkedEmployeeId;
    if (linked == null) return;
    _viewEmployeeName = null;
    _loadPayrolls(linked, viewingOther: false);
  }

  void _openPayslip(Map row) {
    final id = (row['PayrollID'] as num?)?.toInt() ??
        (row['PayrollId'] as num?)?.toInt() ??
        0;
    if (id <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayslipScreen(payrollId: id, username: widget.username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPickerAction = _isManager && _linkedEmployeeId != null;
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frm_Payslip'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        title: Text(
          'قسيمتي',
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
          if (showPickerAction)
            IconButton(
              icon: const Icon(Icons.people_alt_rounded),
              tooltip: 'قسيمة موظف آخر',
              onPressed: _pickOtherEmployee,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _init),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? AppError(message: _error!, onRetry: _init)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    // غير مدير وغير مربوط: حالة صريحة، بلا منتقٍ في أي موضع
    if (_linkedEmployeeId == null && !_isManager) {
      return const AppEmpty(
        icon: Icons.link_off_rounded,
        message: 'لا يوجد موظف مرتبط بهذا الحساب',
        hint: 'قسائم الراتب تظهر هنا بعد ربط حسابك بملف موظف',
      );
    }

    // مدير غير مربوط ولم يختر موظفًا بعد: حالة اختيار مباشرة
    if (_viewEmployeeId == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAnchorHeader(),
            const SizedBox(height: 24),
            const AppEmpty(
              icon: Icons.person_search_rounded,
              message: 'اختر موظفًا لعرض قسائمه',
              hint: 'حسابك غير مرتبط بموظف — اختر موظفًا من القائمة',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _pickOtherEmployee,
              style: FilledButton.styleFrom(
                backgroundColor: _isDark ? AppColors.gold : AppColors.navy,
                foregroundColor: _isDark ? AppColors.navy : Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              icon: const Icon(Icons.person_search_rounded, size: 18),
              label: const Text('اختيار موظف'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPayrolls(
        _viewEmployeeId!,
        viewingOther: _viewingOther,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildAnchorHeader(),
          if (_viewingOther) ...[
            const SizedBox(height: 12),
            _buildViewingOtherBanner(),
          ],
          const SizedBox(height: 16),
          if (_payrolls.isEmpty)
            const AppEmpty(
              icon: Icons.receipt_long_outlined,
              message: 'لا توجد قسائم راتب بعد',
              hint: 'ستظهر قسائم الشهور المحسوبة هنا فور حفظها',
            )
          else
            for (var i = 0; i < _payrolls.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _buildMonthCard(
                Map<String, dynamic>.from(_payrolls[i] as Map),
                i,
              ),
            ],
        ],
      ),
    );
  }

  /// المرساة الكحلية: سياق من تُعرض قسائمه وعددها وأحدث صافي.
  Widget _buildAnchorHeader() {
    final textTheme = Theme.of(context).textTheme;
    final mine = !_viewingOther;
    final title = mine
        ? 'قسائم راتبي'
        : 'قسائم ${_viewEmployeeName ?? 'موظف آخر'}';
    final latestNet = _payrolls.isNotEmpty
        ? _payrolls.first['NetSalary']
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.gold,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _payrolls.isEmpty
                      ? 'الأشهر مرتبة من الأحدث إلى الأقدم'
                      : '${_payrolls.length} قسيمة — أحدث صافي: ${_formatMoney(latestNet)} جـ',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.goldLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isManager && mine && _linkedEmployeeId != null)
            OutlinedButton.icon(
              onPressed: _pickOtherEmployee,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.people_alt_rounded, size: 16),
              label: Text(
                'موظف آخر',
                style: textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewingOtherBanner() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_rounded,
            size: 17,
            color: _isDark ? AppColors.gold : AppColors.navy,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تعرض الآن قسائم: ${_viewEmployeeName ?? ''}',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.text(_isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_linkedEmployeeId != null)
            TextButton(
              onPressed: _backToMine,
              child: Text(
                'عرض قسائمي',
                style: textTheme.labelLarge?.copyWith(
                  color: _isDark ? AppColors.gold : AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// بطاقة شهر: اسم الشهر بصيغة عربية، الصافي الحقيقي بارزًا،
  /// وشارة حالة الدفع — والنقر يفتح قسيمة ذلك الشهر.
  Widget _buildMonthCard(Map<String, dynamic> row, int idx) {
    final textTheme = Theme.of(context).textTheme;
    final statusKey = payrollStatusKey(row);
    final monthRaw = '${row['PayrollMonth'] ?? ''}';
    final deductions = row['Deductions'];
    final netColor = _isDark ? AppColors.gold : AppColors.navy;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPayslip(row),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold
                        .withValues(alpha: _isDark ? 0.2 : 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: _isDark ? AppColors.gold : AppColors.navy,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthRaw.isEmpty ? '—' : _formatMonth(monthRaw),
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.text(_isDark),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'الأساسي ${_formatMoney(row['BasicSalary'])} جـ'
                        '${deductions != null ? ' • الخصومات ${_formatMoney(deductions)} جـ' : ''}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(_isDark),
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(
                        label: payrollStatusLabel(
                          statusKey,
                          raw: '${row['PaymentStatus'] ?? ''}',
                        ),
                        color: payrollStatusColor(statusKey, _isDark),
                        small: true,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'الصافي',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AmountText(
                      value: '${_formatMoney(row['NetSalary'])} جـ',
                      color: netColor,
                      size: 17,
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: AppColors.textSecondary(_isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: idx * 40))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0);
  }
}
