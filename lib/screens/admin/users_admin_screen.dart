import 'package:flutter/material.dart';

import '../../features/home/widgets/home_accent.dart';
import '../../services/admin_service.dart';
import '../../services/permission_service.dart';
import 'user_form_screen.dart';
import 'user_permissions_screen.dart';

/// ─────────────────────────────────────────────────────────────
///  إدارة المستخدمين — قائمة + بحث + فلتر نشط/غير نشط
///  (مطابقة لصفحة Users في الـ Blazor)
/// ─────────────────────────────────────────────────────────────
class UsersAdminScreen extends StatefulWidget {
  final int userId;
  final String username;

  const UsersAdminScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  List<AdminUser> _allUsers = [];
  List<AdminUser> _filtered = [];
  bool _isLoading = true;
  String _searchText = '';
  bool? _filterActive; // null = الكل
  final PermissionService _perms = PermissionService();

  bool get _canAdd => _perms.canAdd(FormNames.addUser);
  bool get _canEdit => _perms.canEdit(FormNames.addUser);
  bool get _canDelete => _perms.canDelete(FormNames.addUser);
  bool get _canManagePermissions =>
      _perms.canView(FormNames.managePermissions) ||
      _perms.canEdit(FormNames.managePermissions) ||
      _perms.isAdmin;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await AdminService.getUsers();
    if (!mounted) return;
    setState(() {
      _allUsers = users;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    var query = _allUsers;
    if (_searchText.trim().isNotEmpty) {
      final q = _searchText.trim().toLowerCase();
      query = query.where((u) {
        return u.fullName.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q) ||
            (u.email ?? '').toLowerCase().contains(q);
      }).toList();
    }
    if (_filterActive != null) {
      query = query.where((u) => u.isActive == _filterActive).toList();
    }
    _filtered = query;
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchText = value;
      _applyFilters();
    });
  }

  void _openAdd() {
    if (!_canAdd) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            UserFormScreen(userId: widget.userId, username: widget.username),
      ),
    ).then((changed) {
      if (changed == true) _loadUsers();
    });
  }

  void _openEdit(AdminUser user) {
    if (!_canEdit) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserFormScreen(
          userId: widget.userId,
          username: widget.username,
          editUser: user,
        ),
      ),
    ).then((changed) {
      if (changed == true) _loadUsers();
    });
  }

  void _openPermissions(AdminUser user) {
    if (!_canManagePermissions) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPermissionsScreen(
          userId: widget.userId,
          username: widget.username,
          targetUser: user,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(AdminUser user) async {
    if (!_canDelete) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مستخدم'),
        content: Text('هل أنت متأكد من حذف "${user.fullName}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await AdminService.deleteUser(user.userId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'تم الحذف'),
        backgroundColor: result['success'] == true
            ? const Color(0xFF43A047)
            : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (result['success'] == true) _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        actions: [
          if (_canAdd)
            IconButton(
              tooltip: 'إضافة مستخدم',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: _openAdd,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── شريط البحث ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو اسم المستخدم أو البريد...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => _onSearchChanged(''),
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── الفلاتر ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Text(
                  'الحالة:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'الكل',
                  selected: _filterActive == null,
                  onTap: () => setState(() {
                    _filterActive = null;
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'نشط',
                  color: const Color(0xFF43A047),
                  selected: _filterActive == true,
                  onTap: () => setState(() {
                    _filterActive = true;
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'غير نشط',
                  color: const Color(0xFFE53935),
                  selected: _filterActive == false,
                  onTap: () => setState(() {
                    _filterActive = false;
                    _applyFilters();
                  }),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: HomeAccent.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filtered.length} مستخدم',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: HomeAccent.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          Expanded(child: _buildBody(isDark)),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _searchText.isNotEmpty || _filterActive != null
                  ? 'لا توجد نتائج مطابقة'
                  : 'لا يوجد مستخدمين في النظام',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = _filtered[index];
        return _UserCard(
          user: user,
          isDark: isDark,
          canEdit: _canEdit,
          canDelete: _canDelete,
          canManagePermissions: _canManagePermissions,
          onEdit: () => _openEdit(user),
          onDelete: () => _confirmDelete(user),
          onPermissions: () => _openPermissions(user),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// كارت المستخدم
// ═══════════════════════════════════════════════════════════

class _UserCard extends StatelessWidget {
  final AdminUser user;
  final bool isDark;
  final bool canEdit;
  final bool canDelete;
  final bool canManagePermissions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPermissions;

  const _UserCard({
    required this.user,
    required this.isDark,
    required this.canEdit,
    required this.canDelete,
    required this.canManagePermissions,
    required this.onEdit,
    required this.onDelete,
    required this.onPermissions,
  });

  Color _roleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
      case 'generalmanager':
        return HomeAccent.gold;
      case 'salesmanager':
        return const Color(0xFF4CAF50);
      case 'accountmanager':
        return const Color(0xFF9C27B0);
      case 'hrmanager':
        return const Color(0xFF26A69A);
      case 'socialmanager':
        return const Color(0xFFEC407A);
      case 'factory':
        return const Color(0xFFFF9800);
      case 'sales':
        return const Color(0xFF2196F3);
      case 'account':
        return const Color(0xFFEF5350);
      case 'social':
        return const Color(0xFFE91E63);
      case 'viewer':
      case 'socialview':
        return const Color(0xFF78909C);
      case 'b2b':
        return const Color(0xFF00ACC1);
      default:
        return const Color(0xFF607D8B);
    }
  }

  String _roleTitle(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'مدير النظام';
      case 'generalmanager':
        return 'مدير عام';
      case 'salesmanager':
        return 'مدير مبيعات';
      case 'accountmanager':
        return 'مدير حسابات';
      case 'hrmanager':
        return 'مدير الموارد البشرية';
      case 'socialmanager':
        return 'مدير السوشيال ميديا';
      case 'factory':
        return 'المصنع';
      case 'sales':
        return 'مندوب مبيعات';
      case 'account':
        return 'محاسب';
      case 'social':
        return 'مسؤول سوشيال ميديا';
      case 'viewer':
        return 'مشاهد (عرض فقط)';
      case 'socialview':
        return 'متصفح سوشيال ميديا';
      case 'b2b':
        return 'بوابة B2B';
      default:
        return role ?? 'مستخدم';
    }
  }

  String _date(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'اليوم';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleColor = _roleColor(user.role);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: user.isActive
              ? roleColor.withValues(alpha: 0.25)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // أفاتار
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        roleColor,
                        Color.lerp(roleColor, Colors.black, 0.25)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
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
                        user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _roleTitle(user.role),
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            user.isActive ? Icons.circle : Icons.cancel_rounded,
                            size: 8,
                            color: user.isActive
                                ? const Color(0xFF43A047)
                                : const Color(0xFFE53935),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            user.isActive ? 'نشط' : 'غير نشط',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // زر الصلاحيات
                if (canManagePermissions)
                  IconButton(
                    tooltip: 'الصلاحيات',
                    icon: const Icon(Icons.shield_rounded),
                    color: HomeAccent.indigo,
                    onPressed: onPermissions,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // المعلومات
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _InfoItem(
                  icon: Icons.person_outline_rounded,
                  text: '@${user.username}',
                ),
                if (user.email != null && user.email!.isNotEmpty)
                  _InfoItem(icon: Icons.email_outlined, text: user.email!),
                _InfoItem(
                  icon: Icons.shield_outlined,
                  text: '${user.permissionsCount} صلاحية',
                ),
                if (user.lastLogin != null)
                  _InfoItem(
                    icon: Icons.login_rounded,
                    text: 'آخر دخول: ${_date(user.lastLogin)}',
                  ),
              ],
            ),
            // الأزرار
            if (canEdit || canDelete)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canEdit)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('تعديل'),
                    ),
                  if (canDelete) ...[
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE53935),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('حذف'),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? c.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? c : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
