import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/permission_service.dart';
import '../models/home_dashboard_config.dart';
import '../providers/home_provider.dart';
import 'home_accent.dart';
import 'section_header.dart';

/// التنبيهات — درجات خطورة ملونة + فلترة حسب الصلاحيات
class AlertsSection extends StatelessWidget {
  final HomeDashboardConfig config;

  const AlertsSection({super.key, required this.config});

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<HomeProvider>();
    final summary = provider.summary;
    final permissions = PermissionService();

    final canFollowUps = config.hasCard('leads') ||
        config.hasCard('tasks') ||
        config.hasCard('crm');
    final canInventory = config.hasCard('inventory');

    final tiles = <_AlertData>[];

    // متابعات متأخرة — درجة صفراء
    if (canFollowUps) {
      final overdue = _toInt(summary['followUpsOverdue']);
      if (overdue > 0) {
        tiles.add(
          _AlertData(
            icon: Icons.event_busy_rounded,
            title: 'متابعات متأخرة',
            value: overdue,
            color: const Color(0xFFFFA000),
          ),
        );
      }
    }

    // مخزون منخفض — درجة برتقالية
    if (canInventory) {
      final lowStock = _toInt(summary['lowStock']);
      if (lowStock > 0) {
        tiles.add(
          _AlertData(
            icon: Icons.inventory_rounded,
            title: 'أصناف منخفضة المخزون',
            value: lowStock,
            color: const Color(0xFFF4511E),
          ),
        );
      }
    }

    // طلبات اعتماد — درجة حمراء (للمدراء فقط)
    if (permissions.canSeeAllData) {
      final pending = _toInt(summary['pendingApprovals']);
      if (pending > 0) {
        tiles.add(
          _AlertData(
            icon: Icons.pending_actions_rounded,
            title: 'طلبات تحتاج اعتماد',
            value: pending,
            color: const Color(0xFFE53935),
          ),
        );
      }
    }

    // ── لا توجد تنبيهات ────────────────────────────────
    if (tiles.isEmpty) {
      const ok = Color(0xFF43A047);
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: HomeAccent.tintedSurface(context, ok),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: HomeAccent.border(context, ok)),
        ),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ok.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: ok,
            ),
          ),
          title: const Text(
            'لا توجد تنبيهات عاجلة',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          subtitle: Text(
            'كل شيء يبدو جيداً',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'التنبيهات',
          subtitle: 'تحتاج انتباهك اليوم',
        ),
        const SizedBox(height: 14),
        for (final tile in tiles) ...[
          _AlertTile(data: tile),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AlertData {
  final IconData icon;
  final String title;
  final int value;
  final Color color;

  const _AlertData({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
}

class _AlertTile extends StatelessWidget {
  final _AlertData data;

  const _AlertTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: HomeAccent.tintedSurface(context, data.color),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: HomeAccent.border(context, data.color)),
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(data.icon, color: data.color, size: 22),
        ),
        title: Text(
          data.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${data.value}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: data.color,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
