import 'package:flutter/material.dart';

import '../../features/home/widgets/home_accent.dart';
import '../../services/admin_service.dart';

/// ─────────────────────────────────────────────────────────────
///  ربط الصلاحيات بالمستخدم
///  (مطابقة لصفحة ManagePermissions في الـ Blazor)
///  - جدول كل صلاحيات النظام مع 4 أزرار: عرض/إضافة/تعديل/حذف
///  - تحديد الكل / إلغاء الكل
///  - حفظ (حذف كل القديم + إضافة المفعل فقط)
/// ─────────────────────────────────────────────────────────────
class UserPermissionsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final AdminUser targetUser;

  const UserPermissionsScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.targetUser,
  });

  @override
  State<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> {
  List<AdminPermission> _allPermissions = [];
  final Map<int, UserPermissionState> _states = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchText = '';
  String? _categoryFilter;
  final Set<String> _expandedCategories = {};

  List<String> get _categories {
    final cats = <String>{};
    for (final p in _allPermissions) {
      if (p.category != null && p.category!.isNotEmpty) {
        cats.add(p.category!);
      }
    }
    return cats.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    // جلب كل الصلاحيات + صلاحيات المستخدم بالتوازي
    final results = await Future.wait([
      AdminService.getPermissions(),
      AdminService.getUserPermissions(widget.targetUser.userId),
    ]);

    if (!mounted) return;

    setState(() {
      _allPermissions = results[0] as List<AdminPermission>;
      final userPerms = results[1] as Map<int, UserPermissionState>;

      _states.clear();
      for (final p in _allPermissions) {
        _states[p.permissionId] =
            userPerms[p.permissionId] ??
            UserPermissionState(permissionId: p.permissionId);
      }

      // فتح كل الفئات افتراضياً
      for (final c in _categories) {
        _expandedCategories.add(c);
      }

      _isLoading = false;
    });
  }

  int get _enabledCount => _states.values.where((s) => s.isAnyEnabled).length;

  List<AdminPermission> get _filteredPermissions {
    var list = _allPermissions;
    if (_searchText.trim().isNotEmpty) {
      final q = _searchText.trim().toLowerCase();
      list = list
          .where(
            (p) =>
                p.permissionName.toLowerCase().contains(q) ||
                (p.formName ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    if (_categoryFilter != null) {
      list = list.where((p) => p.category == _categoryFilter).toList();
    }
    return list;
  }

  void _setAll(bool value) {
    setState(() {
      for (final p in _filteredPermissions) {
        final s = _states[p.permissionId]!;
        s.canView = value;
        s.canAdd = value;
        s.canEdit = value;
        s.canDelete = value;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final result = await AdminService.saveUserPermissions(
      userId: widget.targetUser.userId,
      permissions: _states.values.toList(),
      assignedBy: widget.username,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'تم الحفظ'),
        backgroundColor: result['success'] == true
            ? const Color(0xFF43A047)
            : const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'Administration':
        return const Color(0xFFEF5350);
      case 'Forms':
        return const Color(0xFF42A5F5);
      case 'Reports':
        return const Color(0xFF66BB6A);
      case 'Settings':
        return const Color(0xFFFFA726);
      case 'CRM':
        return const Color(0xFF5C6BC0);
      case 'HR':
        return const Color(0xFFAB47BC);
      case 'Finance':
        return const Color(0xFF26A69A);
      case 'Inventory':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF78909C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ربط الصلاحيات'),
        actions: [
          // تحديد الكل / إلغاء الكل
          IconButton(
            tooltip: 'تحديد الكل',
            icon: const Icon(Icons.select_all_rounded),
            color: const Color(0xFF43A047),
            onPressed: _isLoading ? null : () => _setAll(true),
          ),
          IconButton(
            tooltip: 'إلغاء الكل',
            icon: const Icon(Icons.deselect_rounded),
            color: const Color(0xFFE53935),
            onPressed: _isLoading ? null : () => _setAll(false),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── بطاقة المستخدم ─────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HomeAccent.tintedSurface(context, HomeAccent.indigo),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: HomeAccent.border(context, HomeAccent.indigo),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [HomeAccent.indigo, Color(0xFF454E99)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      widget.targetUser.fullName.isNotEmpty
                          ? widget.targetUser.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.targetUser.fullName,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${widget.targetUser.username}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
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
                    '$_enabledCount مفعلة',
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

          // ── بحث + فلتر فئات ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _searchText = v),
              decoration: InputDecoration(
                hintText: 'ابحث في الصلاحيات...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),

          // فلاتر الفئات
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _CategoryChip(
                  label: 'الكل',
                  color: null,
                  selected: _categoryFilter == null,
                  onTap: () => setState(() => _categoryFilter = null),
                ),
                for (final cat in _categories) ...[
                  const SizedBox(width: 6),
                  _CategoryChip(
                    label: cat,
                    color: _categoryColor(cat),
                    selected: _categoryFilter == cat,
                    onTap: () => setState(() => _categoryFilter = cat),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 4),
          Expanded(child: _buildList(theme)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _isSaving || _isLoading ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: HomeAccent.gold,
              foregroundColor: const Color(0xFF13273F),
              padding: const EdgeInsets.symmetric(vertical: 15),
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
                : const Icon(Icons.save_rounded),
            label: Text(
              _isSaving ? 'جاري الحفظ...' : 'حفظ الصلاحيات',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }

    if (_allPermissions.isEmpty) {
      return Center(
        child: Text(
          'لا توجد صلاحيات في النظام',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final filtered = _filteredPermissions;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'لا توجد نتائج مطابقة',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final perm = filtered[index];
        final state = _states[perm.permissionId]!;
        return _PermissionRow(
          permission: perm,
          state: state,
          color: _categoryColor(perm.category),
          onChanged: () => setState(() {}),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// صف الصلاحية
// ═══════════════════════════════════════════════════════════

class _PermissionRow extends StatelessWidget {
  final AdminPermission permission;
  final UserPermissionState state;
  final Color color;
  final VoidCallback onChanged;

  const _PermissionRow({
    required this.permission,
    required this.state,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: state.isAnyEnabled
              ? color.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      permission.permissionName,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (permission.formName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        permission.formName!,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // شارة الفئة
              if (permission.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    permission.category!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // ── الأزرار الأربعة ────────────────────────────
          Row(
            children: [
              _ActionCheckbox(
                label: 'عرض',
                value: state.canView,
                color: const Color(0xFF42A5F5),
                onChanged: (v) {
                  state.canView = v;
                  onChanged();
                },
              ),
              const SizedBox(width: 8),
              _ActionCheckbox(
                label: 'إضافة',
                value: state.canAdd,
                color: const Color(0xFF66BB6A),
                onChanged: (v) {
                  state.canAdd = v;
                  onChanged();
                },
              ),
              const SizedBox(width: 8),
              _ActionCheckbox(
                label: 'تعديل',
                value: state.canEdit,
                color: const Color(0xFFFFA726),
                onChanged: (v) {
                  state.canEdit = v;
                  onChanged();
                },
              ),
              const SizedBox(width: 8),
              _ActionCheckbox(
                label: 'حذف',
                value: state.canDelete,
                color: const Color(0xFFEF5350),
                onChanged: (v) {
                  state.canDelete = v;
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _ActionCheckbox({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: value ? color.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value
                  ? color.withValues(alpha: 0.4)
                  : Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: value ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: value ? color : Colors.grey.shade500,
                    width: 1.5,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: value
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? c.withValues(alpha: 0.4) : Colors.grey.shade400,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? c : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
