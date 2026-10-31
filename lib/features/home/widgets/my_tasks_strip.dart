import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../constants.dart';
import '../../../core/auth/session_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../screens/general_tasks_screen.dart';
import '../../../services/app_colors.dart';
import '../../../services/design_tokens.dart';
import '../../../widgets/design_kit.dart';

/// شريط «مهامي» — مقابل شريط مهامي في رئيسية بلازور:
/// عدّادات التكليفات العامة المسندة إليّ (مفتوحة/متأخرة) من نفس
/// مصدر بيانات شاشة التكليفات العامة نفسها، ويفتحها عند الضغط.
/// يظهر فقط للحساب المرتبط بموظف. عدّاد الإشارات (@) من نقطة
/// /api/tasks/my-mentions-count (مرآة عدّاد بلازور) ويظهر كشيب
/// ذهبي عند وجود إشارات فقط؛ فشله لا يؤثر في العدّادات.
class MyTasksStrip extends StatefulWidget {
  const MyTasksStrip({super.key});

  @override
  State<MyTasksStrip> createState() => _MyTasksStripState();
}

class _MyTasksStripState extends State<MyTasksStrip> {
  int? _openCount;
  int _overdueCount = 0;
  int _mentionsCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = AuthProvider();
    final userId = auth.userId;
    final username = auth.username;
    if (userId == null || username == null) return;

    try {
      // رقم الموظف: من الجلسة أو بنفس نداء شاشة التكليفات العامة
      int? employeeId = auth.employeeId;
      if (employeeId == null) {
        final res = await http.get(
          Uri.parse('$baseUrl/api/auth/users/$userId/employee'),
          headers: SessionService.instance.authHeaders,
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map) employeeId = data['employeeID'] as int?;
        }
      }
      if (employeeId == null || !mounted) return;

      // عدّاد الإشارات — نداء مستقل بفشل صامت حتى لا يمسّ العدّادات
      try {
        final mentionsRes = await http.get(
          Uri.parse('$baseUrl/api/tasks/my-mentions-count'),
          headers: SessionService.instance.authHeaders,
        );
        if (mentionsRes.statusCode == 200 && mounted) {
          final mentionsData = jsonDecode(mentionsRes.body);
          final count = (mentionsData is Map && mentionsData['data'] is Map)
              ? (mentionsData['data']['count'] as num?)?.toInt() ?? 0
              : 0;
          setState(() => _mentionsCount = count);
        }
      } catch (_) {
        // الإشارات زينة على الشريط — غيابها لا يكسر شيئًا
      }

      final res = await http.get(
        Uri.parse(
          '$baseUrl/api/tasks/general?userName=${Uri.encodeQueryComponent(username)}',
        ),
        headers: SessionService.instance.authHeaders,
      );
      if (res.statusCode != 200 || !mounted) return;

      final data = jsonDecode(res.body);
      if (data is! List) return;

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      var open = 0;
      var overdue = 0;
      for (final raw in data) {
        if (raw is! Map) continue;
        if (raw['AssignedTo'] != employeeId) continue;
        final status = (raw['Status'] ?? '').toString();
        if (status == 'Completed' || status == 'Cancelled') continue;
        open++;
        final due = DateTime.tryParse((raw['DueDate'] ?? '').toString());
        if (due != null &&
            DateTime(due.year, due.month, due.day).isBefore(todayDate)) {
          overdue++;
        }
      }

      if (!mounted) return;
      setState(() {
        _openCount = open;
        _overdueCount = overdue;
      });
    } catch (_) {
      // قسم رئيسية اختياري — أي فشل يخفيه بصمت ولا يكسر الرئيسية
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_openCount == null) return const SizedBox.shrink();

    final auth = AuthProvider();

    return Column(
      children: [
        const SizedBox(height: 24),
        AppCard(
          onTap: () {
            if (auth.userId == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GeneralTasksScreen(
                  userId: auth.userId!,
                  username: auth.username ?? '',
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                title: 'مهامي',
                subtitle: 'التكليفات العامة المسندة إليك',
                icon: Icons.assignment_ind_rounded,
                trailing: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  StatusBadge(
                    label: 'مفتوحة $_openCount',
                    color: AppColors.info,
                    icon: Icons.assignment_rounded,
                  ),
                  if (_overdueCount > 0)
                    StatusBadge(
                      label: 'متأخرة $_overdueCount',
                      color: AppColors.error,
                      icon: Icons.warning_amber_rounded,
                    ),
                  if (_mentionsCount > 0)
                    StatusBadge(
                      label: 'إشارات: $_mentionsCount',
                      color: AppColors.gold,
                      icon: Icons.alternate_email_rounded,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
