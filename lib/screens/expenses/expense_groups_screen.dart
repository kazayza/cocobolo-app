import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../services/expense_service.dart';
import '../../services/permission_service.dart';
import '../../services/theme_service.dart';
import '../../core/network/api_client.dart';
import '../../widgets/design_kit.dart';
import '../../widgets/app_drawer.dart';

/// مجموعات المصروفات — شجرة تكرارية بأي عمق مع إجماليات وعدد مصروفات
/// كل مجموعة (بالتعريف المعترف به من الخادم)، وإنشاء/تعديل/حذف محروس
/// بصلاحيات frm_ExpensesGroup (Add/Edit/Delete). منتقي الأب يستبعد
/// المجموعة نفسها وأحفادها، والحذف يختفي عندما توجد مصروفات أو أبناء
/// (ورسالة الخادم هي الحارس الأخير).
class ExpenseGroupsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ExpenseGroupsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ExpenseGroupsScreen> createState() => _ExpenseGroupsScreenState();
}

class _ExpenseGroupsScreenState extends State<ExpenseGroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  String? _error;

  final PermissionService _perms = PermissionService();

  bool get _canAdd => _perms.canAdd(FormNames.expensesGroup) || _perms.isAdmin;
  bool get _canEdit =>
      _perms.canEdit(FormNames.expensesGroup) || _perms.isAdmin;
  bool get _canDelete =>
      _perms.canDelete(FormNames.expensesGroup) || _perms.isAdmin;
  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await ExpenseService.getExpenseGroups();
      if (mounted) {
        setState(() {
          _groups = groups;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'فشل الاتصال';
          _loading = false;
        });
      }
    }
  }

  Set<int> _descendantsOf(int id) {
    final result = <int>{};
    final stack = [id];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      for (final g in _groups) {
        if (g['ParentGroupID'] == current) {
          final childId = (g['ExpenseGroupID'] as num).toInt();
          if (result.add(childId)) stack.add(childId);
        }
      }
    }
    return result;
  }

  Future<void> _showGroupDialog({
    Map<String, dynamic>? existing,
    int? presetParentId,
  }) async {
    final isEdit = existing != null;
    final selfId =
        isEdit ? (existing['ExpenseGroupID'] as num).toInt() : null;
    final excluded = selfId != null
        ? {selfId, ..._descendantsOf(selfId)}
        : <int>{};
    final candidates = _groups
        .where((g) => !excluded.contains((g['ExpenseGroupID'] as num).toInt()))
        .toList();

    // وحدات تحكم مملوكة للحوار وتُحرَّر بعد إغلاقه
    final nameCtrl = TextEditingController(
        text: isEdit ? (existing['ExpenseGroupName']?.toString() ?? '') : '');
    int? parentId = isEdit
        ? (existing['ParentGroupID'] as num?)?.toInt()
        : presetParentId;
    if (parentId != null &&
        !candidates.any((g) => g['ExpenseGroupID'] == parentId)) {
      parentId = null;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تعديل المجموعة' : 'مجموعة جديدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم المجموعة *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                value: parentId,
                decoration: const InputDecoration(
                  labelText: 'المجموعة الأم',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('بلا مجموعة أم (رئيسية)'),
                  ),
                  ...candidates.map((g) => DropdownMenuItem<int?>(
                        value: (g['ExpenseGroupID'] as num).toInt(),
                        child: Text(g['ExpenseGroupName']?.toString() ?? ''),
                      )),
                ],
                onChanged: (v) => setDialogState(() => parentId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isEdit ? 'حفظ' : 'إنشاء'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) {
      nameCtrl.dispose();
      return;
    }
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (name.isEmpty) {
      _showMsg('اسم المجموعة مطلوب', false);
      return;
    }
    try {
      if (isEdit) {
        final result = await ExpenseService.updateGroup(
            id: selfId!, name: name, parentGroupId: parentId);
        _showMsg(result['message']?.toString() ?? 'تم التحديث', true);
      } else {
        final result = await ExpenseService.createGroup(
            name: name, parentGroupId: parentId);
        _showMsg(result['message']?.toString() ?? 'تم إنشاء المجموعة', true);
      }
      _load();
    } on ApiException catch (e) {
      _showMsg(e.message, false);
    } catch (_) {
      _showMsg('خطأ في الاتصال', false);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content:
            Text('هل تريد حذف مجموعة "${group['ExpenseGroupName']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('حذف',
                style: TextStyle(
                    color:
                        _isDark ? AppColors.errorLight : AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await ExpenseService.deleteGroup(
          (group['ExpenseGroupID'] as num).toInt());
      _showMsg(result['message']?.toString() ?? 'تم الحذف', true);
      _load();
    } on ApiException catch (e) {
      // رسالة الخادم هي الحارس الأخير (مصروفات/أبناء ظهرت بعد التحميل)
      _showMsg(e.message, false);
    } catch (_) {
      _showMsg('خطأ في الاتصال', false);
    }
  }

  void _showMsg(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roots =
        _groups.where((g) => g['ParentGroupID'] == null).toList();
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      drawer: buildAppDrawer(currentRoute: 'frmExpenseTree'),
      appBar: AppBar(
        leading: const AppDrawerMenuButton(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('مجموعات المصروفات'),
        actions: [
          if (_canAdd)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'مجموعة جديدة',
              onPressed: () => _showGroupDialog(),
            ),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? AppError(message: _error!, onRetry: _load)
              : _groups.isEmpty
                  ? const AppEmpty(
                      icon: Icons.category_rounded,
                      message: 'لا توجد مجموعات — اضغط + لإنشاء أول مجموعة',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final root in roots)
                            _buildNode(root, 0),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildNode(Map<String, dynamic> group, int depth) {
    final id = (group['ExpenseGroupID'] as num).toInt();
    final children =
        _groups.where((g) => g['ParentGroupID'] == id).toList();
    final expensesCount = (group['ExpensesCount'] as num?)?.toInt() ?? 0;
    final childrenCount = (group['ChildrenCount'] as num?)?.toInt() ??
        children.length;
    final total = (group['TotalAmount'] as num?)?.toDouble() ?? 0;
    final canDeleteThis =
        _canDelete && expensesCount == 0 && childrenCount == 0;
    final isDark = _isDark;

    return Padding(
      padding: EdgeInsets.only(
          bottom: 10, right: depth == 0 ? 0 : 18.0 * depth.clamp(1, 4)),
      child: AppCard(
        padding: EdgeInsets.zero,
        radius: AppRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  depth == 0
                      ? Icons.folder_rounded
                      : Icons.folder_open_rounded,
                  color: AppColors.gold,
                  size: 20,
                ),
              ),
              title: Text(
                (group['ExpenseGroupName'] ?? '—').toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text(isDark),
                ),
              ),
              subtitle: Text(
                'الإجمالي ${NumberFormat('#,##0.00').format(total)} ج.م'
                ' — $expensesCount مصروف'
                ' — $childrenCount مجموعة فرعية'
                '${group['CreatedBy'] != null ? ' — بواسطة ${group['CreatedBy']}' : ''}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canAdd)
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      tooltip: 'مجموعة فرعية',
                      onPressed: () =>
                          _showGroupDialog(presetParentId: id),
                    ),
                  if (_canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 19),
                      tooltip: 'تعديل',
                      onPressed: () => _showGroupDialog(existing: group),
                    ),
                  if (canDeleteThis)
                    IconButton(
                      icon: Icon(Icons.delete_rounded,
                          size: 19,
                          color: isDark
                              ? AppColors.errorLight
                              : AppColors.error),
                      tooltip: 'حذف',
                      onPressed: () => _confirmDelete(group),
                    ),
                ],
              ),
            ),
            for (final child in children) _buildNode(child, depth + 1),
          ],
        ),
      ),
    );
  }
}
