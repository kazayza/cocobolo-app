import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../constants.dart';
import '../../features/home/widgets/home_accent.dart';

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
      final res = await http.get(Uri.parse('$baseUrl/api/cashbox'));
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
  }

  Future<void> _createBox() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final openCtrl = TextEditingController();
    String kind = 'Cash';

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('خزينة جديدة'),
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
                  labelText: 'وصف (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: openCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'رصيد افتتاحي',
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
                  DropdownMenuItem(value: 'Cash', child: Text('نقدية')),
                  DropdownMenuItem(value: 'Bank', child: Text('بنكي')),
                  DropdownMenuItem(value: 'Wallet', child: Text('محفظة')),
                ],
                onChanged: (v) => kind = v ?? 'Cash',
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
      _showMsg('اسم الخزينة مطلوب', false);
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/cashbox'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cashBoxName': nameCtrl.text.trim(),
          'description': descCtrl.text.trim(),
          'cashBoxKind': kind,
          'openingBalance': double.tryParse(openCtrl.text.trim()) ?? 0,
          'createdBy': widget.username,
        }),
      );
      final result = jsonDecode(res.body);
      _showMsg(
        result['message'] ?? 'تم إنشاء الخزينة',
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

  String _fmt(dynamic v) {
    if (v == null) return '0';
    return v is num
        ? v.toStringAsFixed(0)
        : double.tryParse(v.toString())?.toStringAsFixed(0) ?? '0';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'خزينة جديدة',
            onPressed: _createBox,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : _error != null
              ? _buildError(theme)
              : _boxes.isEmpty
                  ? _buildEmpty(theme)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _boxes.length,
                        itemBuilder: (context, index) =>
                            _BoxCard(box: _boxes[index], fmt: _fmt),
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
            Icons.account_balance_wallet_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد خزن — اضغط + لإنشاء أول خزينة',
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

class _BoxCard extends StatelessWidget {
  final Map<String, dynamic> box;
  final String Function(dynamic) fmt;

  const _BoxCard({required this.box, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = box['CurrentBalance'] ?? 0;
    final isPositive = (balance is num ? balance : 0) >= 0;
    final color =
        isPositive ? const Color(0xFF43A047) : const Color(0xFFE53935);
    final kind = box['CashBoxKind']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
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
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt(balance),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                'الرصيد',
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
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
