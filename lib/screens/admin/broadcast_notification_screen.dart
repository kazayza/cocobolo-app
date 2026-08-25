import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../constants.dart';
import '../../features/home/widgets/home_accent.dart';

/// ─────────────────────────────────────────────────────────────
///  📢 إرسال إشعار عام (Broadcast) — خاص بالأدمن
///  - يبعت Push مباشر لكل المستخدمين النشطين
///  - مش بيتسجل في جدول الإشعارات (بث لحظي فقط)
/// ─────────────────────────────────────────────────────────────
class BroadcastNotificationScreen extends StatefulWidget {
  final String username;

  const BroadcastNotificationScreen({
    super.key,
    required this.username,
  });

  @override
  State<BroadcastNotificationScreen> createState() =>
      _BroadcastNotificationScreenState();
}

class _BroadcastNotificationScreenState
    extends State<BroadcastNotificationScreen> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  // 🎯 نوع المستلم
  String _targetType = 'all'; // all | role | user
  String? _selectedRole;
  String? _selectedUser;
  List<String> _roles = [];      // قائمة الصلاحيات
  List<Map<String, dynamic>> _users = []; // قائمة المستخدمين
  bool _loadingTargets = false;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  // تحميل الأدوار والمستخدمين
  Future<void> _loadTargets() async {
    setState(() => _loadingTargets = true);
    try {
      // جلب المستخدمين (لاختيار مستخدم محدد)
      final usersRes = await http.get(
        Uri.parse('$baseUrl/api/admin/users'),
      ).timeout(const Duration(seconds: 15));
      if (usersRes.statusCode == 200) {
        final body = jsonDecode(usersRes.body);
        final data = body is List
            ? body
            : (body['data'] is List ? body['data'] as List : <dynamic>[]);
        _users = data.cast<Map<String, dynamic>>();
        // استخراج الأدوار الفريدة
        final rolesSet = <String>{};
        for (final u in _users) {
          final role = (u['role'] ?? u['Role'] ?? '').toString().trim();
          if (role.isNotEmpty) rolesSet.add(role);
        }
        _roles = rolesSet.toList()..sort();
      }
    } catch (e) {
      print('خطأ في تحميل المستخدمين: $e');
    }
    if (mounted) setState(() => _loadingTargets = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (title.isEmpty || message.isEmpty) {
      _showMsg('أدخل العنوان والرسالة', false);
      return;
    }

    // تحديد وصف المستلم
    final targetLabel = _targetType == 'role'
        ? 'كل المستخدمين بدور: $_selectedRole'
        : _targetType == 'user'
            ? 'المستخدم: $_selectedUser'
            : 'جميع المستخدمين النشطين';

    // تأكيد قبل الإرسال
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('📢 تأكيد البث'),
        content: Text(
          'سيتم إرسال هذا الإشعار إلى: $targetLabel\n\n'
          '"$title"\n$message',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إرسال للجميع'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/notifications/broadcast'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'message': message,
          'sender': widget.username,
          'targetType': _targetType,
          'target': _targetType == 'role'
              ? _selectedRole
              : _targetType == 'user'
                  ? _selectedUser
                  : null,
        }),
      ).timeout(const Duration(seconds: 30));

      final result = jsonDecode(res.body);

      if (!mounted) return;
      setState(() => _sending = false);

      if (result['success'] == true) {
        _showMsg(result['message'] ?? 'تم إرسال البث', true);
        // تنظيف الحقول بعد النجاح
        _titleCtrl.clear();
        _messageCtrl.clear();
      } else {
        _showMsg(result['message'] ?? 'فشل الإرسال', false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showMsg('خطأ في الاتصال: $e', false);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('إرسال إشعار عام'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── بطاقة توضيحية ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HomeAccent.indigo.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: HomeAccent.indigo.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.campaign_rounded, color: HomeAccent.indigo),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'يُرسل هذا الإشعار لجميع المستخدمين النشطين فوراً '
                    'عبر Push مباشر — ولا يُسجل في سجل الإشعارات.',
                    style: TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── 🎯 اختيار المستلم ──────────────────────────
          Text(
            'إرسال إلى',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // نوع المستلم (كل / صلاحية / مستخدم)
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'all',
                icon: Icon(Icons.groups_rounded),
                label: Text('الكل'),
              ),
              ButtonSegment(
                value: 'role',
                icon: Icon(Icons.badge_rounded),
                label: Text('صلاحية'),
              ),
              ButtonSegment(
                value: 'user',
                icon: Icon(Icons.person_rounded),
                label: Text('مستخدم'),
              ),
            ],
            selected: {_targetType},
            onSelectionChanged: (selection) {
              setState(() => _targetType = selection.first);
            },
          ),
          const SizedBox(height: 12),

          // لو صلاحية → قائمة الأدوار
          if (_targetType == 'role') ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'اختر الصلاحية',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
              items: _roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedRole = v),
            ),
            const SizedBox(height: 12),
          ],

          // لو مستخدم → قائمة المستخدمين
          if (_targetType == 'user') ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedUser,
              decoration: const InputDecoration(
                labelText: 'اختر المستخدم',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
              items: _users
                  .map((u) => DropdownMenuItem(
                        value: (u['username'] ?? u['Username'] ?? '').toString(),
                        child: Text(
                          '${u['fullName'] ?? u['FullName'] ?? u['username'] ?? u['Username'] ?? ''}'
                          ' (${u['role'] ?? u['Role'] ?? ''})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedUser = v),
            ),
            const SizedBox(height: 12),
          ],

          // ── العنوان ────────────────────────────────────
          TextField(
            controller: _titleCtrl,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'عنوان الإشعار *',
              hintText: 'مثال: إعلان هام — تحديث النظام الليلة',
              prefixIcon: const Icon(Icons.title_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── الرسالة ────────────────────────────────────
          TextField(
            controller: _messageCtrl,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'الرسالة *',
              hintText: 'اكتب نص الإشعار...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── زر الإرسال ─────────────────────────────────
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.campaign_rounded),
            label: Text(
              _sending ? 'جاري الإرسال...' : 'إرسال للجميع',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── تنبيه ──────────────────────────────────────
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'خاص بمدير النظام فقط',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant,
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
