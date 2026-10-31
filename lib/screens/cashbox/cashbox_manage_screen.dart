import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';
import '../../widgets/design_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../constants.dart';
import '../../features/home/widgets/home_accent.dart';
import '../../core/auth/session_service.dart';
import '../../services/cashbox_service.dart';
import '../../services/permission_service.dart';

/// ─────────────────────────────────────────────────────────────
///  🏦 إدارة الخزن — إنشاء + تعديل + حذف
///  (مطابقة لـ CashBoxManage + CashBoxForm في بلازور)
/// ─────────────────────────────────────────────────────────────
class CashBoxManageScreen extends StatefulWidget {
  final int userId;
  final String username;

  const CashBoxManageScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<CashBoxManageScreen> createState() => _CashBoxManageScreenState();
}

class _CashBoxManageScreenState extends State<CashBoxManageScreen> {
  List<Map<String, dynamic>> _boxes = [];
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;
  String? _error;

  // حذف الخزينة ببوابة frmCashBox:Delete (Item 6)
  bool get _canDelete =>
      PermissionService().isAdmin || PermissionService().canDelete('frmCashBox');

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
      final res = await http.get(Uri.parse('$baseUrl/api/cashbox'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> list = [];
        if (data is List) {
          list = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (data is Map && data['data'] is List) {
          list = (data['data'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        setState(() {
          _boxes = list;
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
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/inventory/branches'),
        headers: SessionService.instance.authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && mounted) {
          setState(() {
            _branches =
                data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          });
        }
      }
    } catch (_) {}
  }

  // نموذج موحد إنشاء/تعديل — Item 15 (مرآة CashBoxForm في بلازور)
  Future<void> _openBoxForm({Map<String, dynamic>? box}) async {
    final editing = box != null;
    final nameCtrl =
        TextEditingController(text: editing ? '${box['CashBoxName'] ?? ''}' : '');
    final descCtrl =
        TextEditingController(text: editing ? '${box['Description'] ?? ''}' : '');
    final openCtrl = TextEditingController(
        text: editing ? '${box['OpeningBalance'] ?? 0}' : '0');
    String kind = editing ? '${box['CashBoxKind'] ?? 'Cash'}' : 'Cash';
    int? branchId = editing ? (box['BranchID'] as num?)?.toInt() : null;
    bool isDefault = editing && box['IsDefault'] == true;
    bool isActive = !editing || box['IsActive'] != false;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(editing ? 'تعديل خزينة' : 'خزينة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الخزينة *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الوصف (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: branchId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الفرع *',
                    border: OutlineInputBorder(),
                  ),
                  items: _branches
                      .map((b) => DropdownMenuItem<int>(
                            value: (b['BranchId'] as num?)?.toInt(),
                            child: Text(
                                '${b['BranchNameAr'] ?? b['BranchName'] ?? ''}'),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => branchId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: openCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'الرصيد الافتتاحي',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(
                    labelText: 'النوع',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('خزينة نقدية')),
                    DropdownMenuItem(value: 'Bank', child: Text('حساب بنكي')),
                    DropdownMenuItem(
                        value: 'Wallet', child: Text('محفظة إلكترونية')),
                    DropdownMenuItem(value: 'Other', child: Text('أخرى')),
                  ],
                  onChanged: (v) => setDialogState(() => kind = v ?? 'Cash'),
                ),
                SwitchListTile(
                  title: const Text('الخزينة الافتراضية'),
                  value: isDefault,
                  onChanged: (v) => setDialogState(() => isDefault = v),
                ),
                SwitchListTile(
                  title: const Text('نشطة'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
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
                foregroundColor: AppColors.navy,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(editing ? 'حفظ التعديل' : 'إنشاء'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) {
      nameCtrl.dispose();
      descCtrl.dispose();
      openCtrl.dispose();
      return;
    }
    if (nameCtrl.text.trim().isEmpty) {
      _showMsg('اسم الخزينة مطلوب', false);
      nameCtrl.dispose();
      descCtrl.dispose();
      openCtrl.dispose();
      return;
    }
    if (branchId == null) {
      // الفرع إلزامي كما في بلازور (Item 4)
      _showMsg('الفرع مطلوب', false);
      nameCtrl.dispose();
      descCtrl.dispose();
      openCtrl.dispose();
      return;
    }

    final payload = {
      'cashBoxName': nameCtrl.text.trim(),
      'description': descCtrl.text.trim(),
      'branchId': branchId,
      'cashBoxKind': kind,
      'openingBalance': double.tryParse(openCtrl.text.trim()) ?? 0,
      'isDefault': isDefault,
      'isActive': isActive,
      'createdBy': widget.username,
    };
    try {
      final res = editing
          ? await http.put(
              Uri.parse('$baseUrl/api/cashbox/${box['CashBoxID']}'),
              headers: {
                ...SessionService.instance.authHeaders,
                'Content-Type': 'application/json'
              },
              body: jsonEncode(payload),
            )
          : await http.post(
              Uri.parse('$baseUrl/api/cashbox'),
              headers: {
                ...SessionService.instance.authHeaders,
                'Content-Type': 'application/json'
              },
              body: jsonEncode(payload),
            );
      final result = jsonDecode(res.body);
      _showMsg(
        result['message'] ?? (editing ? 'تم تعديل الخزينة' : 'تم إنشاء الخزينة'),
        result['success'] == true || res.statusCode == 200,
      );
      _load();
    } catch (e) {
      _showMsg('خطأ في الاتصال', false);
    }
    nameCtrl.dispose();
    descCtrl.dispose();
    openCtrl.dispose();
  }

  // حذف خزينة — حوار تأكيد يذكر هوية الخزينة بالاسم، والخادم يرفض
  // الحذف برسالة بلازور عند وجود حركات (Item 6)
  Future<void> _confirmDelete(Map<String, dynamic> box) async {
    final name = '${box['CashBoxName'] ?? ''}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الخزينة'),
        content: Text(
          'سيتم حذف الخزينة «$name» نهائيًا. '
          'لا يمكن حذف خزينة بها حركات — عطّلها بدلًا من ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result =
          await CashboxService.deleteCashbox((box['CashBoxID'] as num).toInt());
      _showMsg(result['message'] ?? 'تم حذف الخزينة بنجاح', true);
      _load();
    } catch (e) {
      _showMsg(e.toString(), false);
    }
  }

  void _showMsg(String message, bool isSuccess) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? AppColors.success
            : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _fmt(dynamic v) {
    final n = v is num
        ? v.toDouble()
        : double.tryParse(v?.toString() ?? '') ?? 0;
    return NumberFormat('#,##0').format(n);
  }

  String _kindLabel(String? kind) {
    switch (kind) {
      case 'Bank':
        return 'بنكي';
      case 'Wallet':
        return 'محفظة';
      case 'Cash':
        return 'نقدية';
      default:
        return 'أخرى';
    }
  }

  IconData _kindIcon(String? kind) {
    switch (kind) {
      case 'Bank':
        return Icons.account_balance_rounded;
      case 'Wallet':
        return Icons.phone_android_rounded;
      case 'Cash':
        return Icons.attach_money_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الخزن'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'خزينة جديدة',
            onPressed: () => _openBoxForm(),
          ),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? _buildError(theme)
              : _boxes.isEmpty
                  ? _buildEmpty(theme)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _boxes.length,
                        itemBuilder: (context, index) => _BoxCard(
                              box: _boxes[index],
                              fmt: _fmt,
                              onTap: () => _openBoxForm(box: _boxes[index]),
                              onDelete: _canDelete
                                  ? () => _confirmDelete(_boxes[index])
                                  : null,
                            ),
                      ),
                    ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return AppError(message: _error!, onRetry: _load);
  }

  Widget _buildEmpty(ThemeData theme) {
    return const AppEmpty(
      icon: Icons.account_balance_wallet_rounded,
      message: 'لا توجد خزن — اضغط + لإنشاء أول خزينة',
    );
  }
}

class _BoxCard extends StatelessWidget {
  final Map<String, dynamic> box;
  final String Function(dynamic) fmt;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _BoxCard({required this.box, required this.fmt, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = box['CurrentBalance'] ?? 0;
    final isPositive = (balance is num ? balance : 0) >= 0;
    final color =
        isPositive ? AppColors.success : AppColors.error;
    final kind = box['CashBoxKind']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        radius: AppRadius.lg,
        child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: HomeAccent.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _kindIcon(kind),
              color: HomeAccent.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  box['CashBoxName'] ?? '—',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _kindLabel(kind),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (box['BranchName'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${box['BranchName']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(value: fmt(balance), size: 15, color: color),
              Text(
                'الرصيد',
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (box['TransactionsCount'] != null)
                Text(
                  '${box['TransactionsCount']} حركة',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppColors.error,
              tooltip: 'حذف الخزينة',
              onPressed: onDelete,
            ),
        ],
        ),
      ),
    );
  }

  String _kindLabel(String? kind) {
    switch (kind) {
      case 'Bank':
        return 'بنكي';
      case 'Wallet':
        return 'محفظة';
      case 'Cash':
        return 'نقدية';
      default:
        return 'أخرى';
    }
  }

  IconData _kindIcon(String? kind) {
    switch (kind) {
      case 'Bank':
        return Icons.account_balance_rounded;
      case 'Wallet':
        return Icons.phone_android_rounded;
      case 'Cash':
        return Icons.attach_money_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }
}
