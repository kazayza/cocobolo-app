import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/home_dashboard_model.dart';
import '../providers/home_provider.dart';
import 'home_accent.dart';
import 'section_header.dart';

/// مهامي اليوم — مع شارات الأولوية الملونة والموعد
class TasksSection extends StatelessWidget {
  const TasksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HomeProvider>();
    final tasks = provider.urgentTasks;

    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'مهامي اليوم',
          subtitle: 'متابعات تحتاج إجراء',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: HomeAccent.cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${tasks.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: HomeAccent.cyan,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: HomeAccent.tintedSurface(context, HomeAccent.cyan),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: HomeAccent.border(context, HomeAccent.cyan)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < tasks.length && i < 5; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                _TaskTile(task: tasks[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final HomeTaskModel task;

  const _TaskTile({required this.task});

  static Color? _priorityColor(String? priority) {
    if (priority == null) return null;
    final p = priority.toLowerCase();
    if (p.contains('عال') || p.contains('high') || p.contains('urgent')) {
      return const Color(0xFFE53935);
    }
    if (p.contains('متوسط') || p.contains('medium') || p.contains('normal')) {
      return const Color(0xFFFFA000);
    }
    if (p.contains('منخف') || p.contains('low')) {
      return const Color(0xFF43A047);
    }
    return null;
  }

  static String _dueText(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(d.year, d.month, d.day);
    final diff = due.difference(today).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'غداً';
    if (diff == -1) return 'أمس';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _priorityColor(task.priority);

    return CheckboxListTile(
      value: task.isCompleted,
      onChanged: (_) {
        // TODO: ربط إتمام المهمة بالـ API
      },
      activeColor: HomeAccent.cyan,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      subtitle: (task.priority != null || task.dueDate != null)
          ? Row(
              children: [
                if (color != null && task.priority != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task.priority!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (task.dueDate != null)
                  Text(
                    _dueText(task.dueDate!),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}
