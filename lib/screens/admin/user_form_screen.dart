import 'package:flutter/material.dart';

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
  List<Map<String, dynamic>> _employees = [];
  int? _employeeId;
  bool _loadingEmployees = false;

  static const List<({String value, String label})> _roles = [
    (value: 'Admin', label: 'مدير النظام'),
    (value: 'GeneralManager', label: 'مدير عام'),
    (value: 'SalesManager', label: 'مدير مبيعات'),
    (value: 'AccountManager', label: 'مدير حسابات'),
    (value: 'HrManager', label: 'مدير الموارد البشرية'),
    (value: 'SocialManager', label: 'مدير السوشيال ميديا'),
    (value: 'Factory', label: 'المصنع'),
    (value: 'Sales', label: 'مندوب مبيعات'),
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

    // تحميل الموظفين النشطين (لربط المستخدم بموظف)
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
        backgroundColor: success
            ? const Color(0xFF43A047)
            : const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (success) {
      // ── لو مستخدم جديد → نسأل عن تحديد الصلاحيات ─────
      if (!_isEdit) {
        final newUserId =
            (result['data'] is Map ? result['data']['userId'] : null) as int?;

        // حتى لو مفيش userId راجع من الـ API، نكمل عادي
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
                  foregroundColor: const Color(0xFF13273F),
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
          navigator.pop(true); // نقفل الفورم (بقيمة true)
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل مستخدم' : 'إضافة مستخدم جديد'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── معلومات الحساب ────────────────────────────
            _SectionTitle(
              icon: Icons.account_circle_rounded,
              title: 'معلومات الحساب',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              enabled: !_isEdit, // لا يمكن تعديل اسم المستخدم
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
              initialValue: _employeeId,
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

            const SizedBox(height: 24),

            // ── الصلاحيات والحالة ─────────────────────────
            _SectionTitle(icon: Icons.shield_rounded, title: 'الدور والحالة'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: _inputDecoration(
                label: 'الدور الوظيفي *',
                icon: Icons.workspace_premium_rounded,
              ),
              items: [
                for (final r in _roles)
                  DropdownMenuItem(value: r.value, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'User'),
            ),
            const SizedBox(height: 14),
            // حالة الحساب
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isActive
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: _isActive
                        ? const Color(0xFF43A047)
                        : const Color(0xFFE53935),
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
                  // Toggle
                  GestureDetector(
                    onTap: () => setState(() => _isActive = !_isActive),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 56,
                      height: 30,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _isActive
                            ? const Color(0xFF43A047)
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

            const SizedBox(height: 32),

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
                      foregroundColor: const Color(0xFF13273F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF13273F),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [HomeAccent.gold, HomeAccent.goldDark],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: HomeAccent.gold),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
