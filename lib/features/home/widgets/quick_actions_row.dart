import 'package:flutter/material.dart';

import '../../../services/permission_service.dart';
import '../models/home_quick_action.dart';
import 'home_accent.dart';
import 'section_header.dart';

/// إجراءات سريعة — تظهر حسب صلاحيات الإضافة لكل شاشة
class QuickActionsRow extends StatelessWidget {
  final void Function(HomeQuickAction action) onAction;
  final int? employeeId;

  const QuickActionsRow({
    super.key,
    required this.onAction,
    this.employeeId,
  });

  static Color _accentFor(String action) {
    switch (action) {
      case 'add_client':
        return HomeAccent.indigo;
      case 'add_lead':
        return HomeAccent.amber;
      case 'add_opportunity':
        return HomeAccent.purple;
      case 'add_expense':
        return HomeAccent.red;
      case 'add_task':
        return HomeAccent.cyan;
      case 'attendance':
        return HomeAccent.teal;
      case 'add_complaint':
        return HomeAccent.pink;
      case 'delivery_tracking':
        return HomeAccent.orange;
      case 'follow_ups':
        return HomeAccent.teal;
      default:
        return HomeAccent.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = HomeQuickAction.available(
      PermissionService(),
      employeeId: employeeId ?? PermissionService().employeeId,
    );
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'إجراءات سريعة',
          subtitle: 'الأكثر استخداماً',
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final action = actions[index];
              return _QuickActionTile(
                action: action,
                accent: _accentFor(action.action),
                onTap: () => onAction(action),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final HomeQuickAction action;
  final Color accent;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.action,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: HomeAccent.tintedSurface(context, accent),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: HomeAccent.border(context, accent)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: HomeAccent.gradient(accent),
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 21),
                ),
                const SizedBox(height: 8),
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
