import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../constants.dart';
import '../../features/home/widgets/home_accent.dart';

/// ─────────────────────────────────────────────────────────────
///  💰 مجموعات المصروفات — عرض + إنشاء
///  (مطابقة لـ ExpenseGroups في بلازور)
/// ─────────────────────────────────────────────────────────────
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
      final res = await http.get(Uri.parse('$baseUrl/api/expenses/groups'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _groups = (data as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'فشل التحميل (${res.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'فشل الاتصال';
        _loading = false;
      });
    }
  }

  Future<void> _createGroup({int? parentId}) async {
    final nameCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(parentId == null ? 'مجموعة جديدة' : 'مجموعة فرعية جديدة'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'اسم المجموعة *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HomeAccent.accent,
              foregroundColor: const Color(0xFF13273F),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    if (submitted != true || !mounted) return;
    if (nameCtrl.text.trim().isEmpty) {
      _showMsg('اسم المجموعة مطلوب', false);
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/expenses/groups'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'expenseGroupName': nameCtrl.text.trim(),
          'parentGroupId': parentId,
        }),
      );
      final result = jsonDecode(res.body);
      _showMsg(
        result['message'] ?? 'تم إنشاء المجموعة',
        result['success'] == true || res.statusCode == 200,
      );
      _load();
    } catch (e) {
      _showMsg('خطأ في الاتصال', false);
    }
  }

  void _showMsg(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? const Color(0xFF43A047)
            : const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // تقسيم: أم + فرعية
    final parents = _groups.where((g) => g['ParentGroupID'] == null).toList();
    final children = _groups.where((g) => g['ParentGroupID'] != null).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مجموعات المصروفات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'مجموعة جديدة',
            onPressed: () => _createGroup(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _error != null
              ? _buildError(theme)
              : _groups.isEmpty
                  ? _buildEmpty(theme)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final parent in parents)
                            _ParentGroupCard(
                              group: parent,
                              children: children
                                  .where((c) =>
                                      c['ParentGroupID'] ==
                                      parent['ExpenseGroupID'])
                                  .toList(),
                              onAddChild: () =>
                                  _createGroup(
                                    parentId: (parent['ExpenseGroupID']
                                            as num)
                                        .toInt(),
                                  ),
                            ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 60, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(_error!,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مجموعات — اضغط + لإنشاء أول مجموعة',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> children;
  final VoidCallback onAddChild;

  const _ParentGroupCard({
    required this.group,
    required this.children,
    required this.onAddChild,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // المجموعة الأم
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HomeAccent.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.folder_rounded,
                color: HomeAccent.gold,
                size: 20,
              ),
            ),
            title: Text(
              (group['ExpenseGroupName'] ?? '—').toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              '${children.length} مجموعة فرعية',
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              tooltip: 'مجموعة فرعية',
              onPressed: onAddChild,
            ),
          ),
          // المجموعات الفرعية
          if (children.isNotEmpty)
            for (final child in children)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_left_rounded,
                      size: 16,
                      color: HomeAccent.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (child['ExpenseGroupName'] ?? '—').toString(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
