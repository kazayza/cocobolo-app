import 'package:flutter/material.dart';
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../widgets/design_kit.dart';

import '../../features/home/widgets/home_accent.dart';
import '../../services/admin_service.dart';
import '../../services/permission_service.dart';
import 'user_permissions_screen.dart';

/// ─────────────────────────────────────────────────────────────
///  إضافة / تعديل مستخدم
///  (مطابقة لفورم UserForm في الـ Blazor)
/// ─────────────────────────────────────────────────────────────
class UserFormScreen extends StatefulWidget {
  final int userId;
  final String username;
  final AdminUser? editUser;

  const UserFormScreen({
    super.key,
    required this.userId,
    required this.username,
    this.editUser,
  });

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final bool _isEdit = widget.editUser != null;

  late final TextEditingController _username;
  late final TextEditingController _fullName;
  late final TextEditingController _password;
  late final TextEditingController _email;

String _role = 'User';
  bool _isActive = true;
  bool _isSaving = false;

  // ربط الموظف
  List<dynamic> _employees = [];
  int? _employeeId;
  bool _loadingEmployees = false;

  static const List<({String value, String label})> _roles = [
    (value: 'Admin', label: 'مدير النظام'),
    (value: 'GeneralManager', label: 'مدير عام'),
    (value: 'AccountManager', label: 'مدير حسابات'),
    (value: 'HrManager', label: 'مدير الموارد البشرية'),
    (value: 'SocialManager', label: 'مدير السوشيال ميديا'),
    (value: 'CustomerService', label: 'مسؤول خدمة العملاء'),
    (value: 'ProductionManager', label: 'مدير الإنتاج'),
    (value: 'DeliveryOfficer', label: 'مسؤول توصيل'), 
    (value: 'Delivery', label: 'توصيل / دليفري'),
    (value: 'factory', label: 'المصنع'),
    (value: 'Sales', label: 'مسؤول مبيعات'),
    (value: 'Account', label: 'محاسب'),
    (value: 'Social', label: 'مسؤول سوشيال ميديا'),
    (value: 'Viewer', label: 'مشاهد (عرض فقط)'),
    (value: 'SocialView', label: 'متصفح سوشيال ميديا'),
    (value: 'B2B', label: 'بوابة B2B'),
    (value: 'User', label: 'مستخدم'),
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.editUser;
    _username = TextEditingController(text: u?.username ?? '');
    _fullName = TextEditingController(text: u?.fullName ?? '');
    _password = TextEditingController();
    _email = TextEditingController(text: u?.email ?? '');
    _role = u?.role ?? 'User';
    _isActive = u?.isActive ?? true;
    _employeeId = u?.employeeId;

    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loadingEmployees = true);
    final employees = await AdminService.getActiveEmployees();
    if (!mounted) return;
    setState(() {
      _employees = employees;
      _loadingEmployees = false;
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _password.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final Map<String, dynamic> result;
    if (_isEdit) {
      result = await AdminService.updateUser(
        userId: widget.editUser!.userId,
        fullName: _fullName.text.trim(),
        password: _password.text,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        role: _role,
        isActive: _isActive,
        employeeId: _employeeId,
      );
    } else {
      result = await AdminService.createUser(
        username: _username.text.trim(),
        fullName: _fullName.text.trim(),
        password: _password.text,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        role: _role,
        isActive: _isActive,
        employeeId: _employeeId,
        createdBy: widget.username,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    final success = result['success'] == true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'تمت العملية'),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (success) {
      if (!_isEdit) {
        final newUserId =
            (result['data'] is Map ? result['data']['userId'] : null) as int?;

        final goToPermissions = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('✅ تم إضافة المستخدم'),
            content: Text(
              'هل تريد تحديد صلاحيات "${_fullName.text.trim()}" الآن؟',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('لاحقاً'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: HomeAccent.accent,
                  foregroundColor: AppColors.navy,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.shield_rounded, size: 18),
                label: const Text('تحديد الصلاحيات الآن'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (goToPermissions == true && newUserId != null) {
          final newUser = AdminUser(
            userId: newUserId,
            username: _username.text.trim(),
            fullName: _fullName.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            role: _role,
            isActive: _isActive,
          );
          final navigator = Navigator.of(context);
          navigator.pop(true);
          navigator.push(
            MaterialPageRoute(
              builder: (_) => UserPermissionsScreen(
                userId: widget.userId,
                username: widget.username,
                targetUser: newUser,
              ),
            ),
          );
          return;
        }
      }

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // تجهيز قائمة الأدوار مع التأكد من وجود الدور الحالي حتى لو لم يكن في القائمة الثابتة
    final availableRoles = List<({String value, String label})>.from(_roles);
    if (!availableRoles.any((r) => r.value == _role)) {
      availableRoles.insert(0, (value: _role, label: '$_role (مخصص)'));
    }

    // استخراج معرّفات الموظفين المتاحة للتأكد من وجود _employeeId فيها
    final availableEmployeeIds = _employees
        .map((e) => (e['EmployeeID'] ?? e['employeeID']) as int?)
        .whereType<int>()
        .toSet();

    final safeEmployeeValue =
        (_employeeId != null && availableEmployeeIds.contains(_employeeId))
            ? _employeeId
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل مستخدم' : 'إضافة مستخدم جديد'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ── معلومات الحساب ────────────────────────────
            _SectionTitle(
              icon: Icons.account_circle_rounded,
              title: 'معلومات الحساب',
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _username,
              enabled: !_isEdit,
              decoration: _inputDecoration(
                label: 'اسم المستخدم *',
                icon: Icons.person_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اسم المستخدم مطلوب' : null,
            ),
            if (_isEdit) ...[
              const SizedBox(height: 4),
              Text(
                'لا يمكن تعديل اسم المستخدم',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _fullName,
              decoration: _inputDecoration(
                label: 'الاسم الكامل *',
                icon: Icons.badge_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'الاسم الكامل مطلوب' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: _inputDecoration(
                label: _isEdit
                    ? 'كلمة المرور (اتركها فارغة للإبقاء على القديمة)'
                    : 'كلمة المرور *',
                icon: Icons.lock_rounded,
              ),
              validator: (v) {
                if (!_isEdit && (v == null || v.length < 8)) {
                  return '8 أحرف على الأقل';
                }
                if (_isEdit && v != null && v.isNotEmpty && v.length < 8) {
                  return '8 أحرف على الأقل';
                }
                return null;
              },
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 4),
              Text(
                'يجب أن تكون 8 أحرف على الأقل',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                label: 'البريد الإلكتروني',
                icon: Icons.email_rounded,
              ),
            ),

            const SizedBox(height: 14),

            // ── ربط الموظف ────────────────────────────────
            DropdownButtonFormField<int?>(
              value: safeEmployeeValue, // حماية من انهيار عدم وجود الموظف بالقائمة
              decoration: _inputDecoration(
                label: 'ربط الموظف',
                icon: Icons.badge_rounded,
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('— بدون موظف —'),
                ),
                for (final emp in _employees)
                  DropdownMenuItem<int?>(
                    value: (emp['EmployeeID'] ?? emp['employeeID']) as int?,
                    child: Text(
                      (emp['FullName'] ?? 'موظف').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _employeeId = v),
            ),
            const SizedBox(height: 4),
            Text(
              'اختر الموظف المرتبط بهذا الحساب (يُستخدم في المهام والتسليمات)',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── الصلاحيات والحالة ─────────────────────────
            _SectionTitle(icon: Icons.shield_rounded, title: 'الدور والحالة'),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: _role, // استخدام value بدلاً من initialValue لتحديث الواجهة دائماً
              decoration: _inputDecoration(
                label: 'الدور الوظيفي *',
                icon: Icons.workspace_premium_rounded,
              ),
              items: [
                for (final r in availableRoles)
                  DropdownMenuItem(value: r.value, child: Text(r.label)),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _role = v);
                }
              },
            ),
            const SizedBox(height: 14),
            // حالة الحساب
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              radius: AppRadius.md,
              child: Row(
                children: [
                  Icon(
                    _isActive
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: _isActive ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'حالة الحساب',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isActive = !_isActive),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 56,
                      height: 30,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _isActive
                            ? AppColors.success
                            : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Align(
                        alignment: _isActive
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── أزرار ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeAccent.accent,
                      foregroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.navy,
                            ),
                          )
                        : Icon(
                            _isEdit
                                ? Icons.save_rounded
                                : Icons.person_add_alt_1_rounded,
                          ),
                    label: Text(_isEdit ? 'حفظ التعديلات' : 'إضافة المستخدم'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(title: title, icon: icon);
  }
}