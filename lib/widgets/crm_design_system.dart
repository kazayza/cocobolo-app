import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';

/// نظام تصميم موحد لكل شاشات CRM بهوية فلاتر الخاصة (navy+gold)
/// المرجع للورك فلو: بلازور (CrmOpportunityDetail, MyCalendar, LostRecovery)
/// لكن التصميم بهوية فلاتر 100%

class CrmDesignSystem {
  static bool get isDark => ThemeService().isDarkMode;

  // ── Premium Header - مطابق MyCalendar premium-header-v2 لكن بألوان فلاتر ──
  static Widget premiumHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    List<Widget>? actions,
    List<Widget>? stats,
    Widget? progressBox,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, const Color(0xFF1E3A5F), const Color(0xFF1E40AF), AppColors.navy.withOpacity(0.9)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -30, right: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle))),
          Positioned(bottom: -30, left: 10, child: Container(width: 140, height: 140, decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.08), shape: BoxShape.circle))),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                      boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.12), blurRadius: 10)],
                    ),
                    child: Icon(icon, color: AppColors.gold, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF34D399), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF34D399).withOpacity(0.5), blurRadius: 6)])),
                        const SizedBox(width: 6),
                        Text('CRM • COCOBOLO', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                      Text(title, style: GoogleFonts.cairo(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, height: 1.2)),
                      Text(subtitle, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11, height: 1.3)),
                    ]),
                  ),
                  if (actions != null) ...actions,
                ]),
                if (progressBox != null) ...[const SizedBox(height: 12), progressBox],
                if (stats != null) ...[const SizedBox(height: 12), Row(children: stats)],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Card - radius 20 + shadow + icon circle 32px ──
  static Widget sectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    Widget? trailing,
  }) {
    final dark = isDark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(dark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider(dark).withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? 0.20 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text(dark)))),
          if (trailing != null) trailing,
          Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        ]),
        const SizedBox(height: 12),
        Divider(height: 1, color: AppColors.divider(dark)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  // ── KPI Card - 110px width + check icon ──
  static Widget kpiCard({
    required String emoji,
    required String value,
    required String label,
    required Color color,
    bool selected = false,
    VoidCallback? onTap,
    double width = 110,
  }) {
    final dark = isDark;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(dark ? 0.22 : 0.12) : (dark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? color : (dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)), width: selected ? 1.6 : 1),
            boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.20), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16)))),
              const Spacer(),
              if (selected) Icon(Icons.check_circle_rounded, size: 14, color: color),
            ]),
            const SizedBox(height: 8),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, color: dark ? Colors.white : const Color(0xFF0F172A))),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ),
    );
  }

  // ── Filter Chip - radius 20 ──
  static Widget filterChip({
    required String label,
    bool selected = false,
    required VoidCallback onTap,
    Color? color,
    bool isClear = false,
  }) {
    final c = color ?? AppColors.navy;
    Color bg, fg, border;
    if (isClear) {
      bg = AppColors.errorLight.withValues(alpha: 0.15);
      fg = AppColors.error;
      border = AppColors.errorLight;
    } else if (selected) {
      bg = c;
      fg = Colors.white;
      border = Colors.transparent;
    } else {
      bg = AppColors.card(isDark);
      fg = AppColors.textSecondary(isDark);
      border = AppColors.divider(isDark);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
          child: Text(label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
        ),
      ),
    );
  }

  // ── Smart Toggle Bar - All/Client/Lead ──
  static Widget smartToggleBar({
    required List<({String key, String label, bool selected})> items,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.card(isDark).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: items.map((it) {
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(it.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: it.selected ? (isDark ? AppColors.navy : Colors.white) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: it.selected ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)] : null,
                ),
                child: Center(child: Text(it.label, style: GoogleFonts.cairo(fontSize: 11, fontWeight: it.selected ? FontWeight.w900 : FontWeight.w600, color: it.selected ? AppColors.gold : AppColors.textSecondary(isDark)))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Status Badge ──
  static Widget statusBadge(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 4)],
        Text(text, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  // ── Info Row with icon circle ──
  static Widget infoRow(IconData icon, String label, String value, {Color? color, bool highlight = false}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final dark = isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: (color ?? AppColors.gold).withOpacity(0.10), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: color ?? AppColors.gold)),
        const SizedBox(width: 10),
        SizedBox(width: 85, child: Text('$label:', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary(dark), fontWeight: FontWeight.w700))),
        Expanded(child: Text(value, style: GoogleFonts.cairo(fontSize: highlight ? 13 : 12.5, fontWeight: highlight ? FontWeight.w900 : FontWeight.w600, color: highlight ? (color ?? AppColors.navy) : AppColors.text(dark), height: 1.3))),
      ]),
    );
  }

  // ── Empty State ──
  static Widget emptyState({required String message, String? hint, IconData? icon, VoidCallback? onRefresh}) {
    final dark = isDark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon ?? Icons.inbox_rounded, size: 40, color: AppColors.gold)),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text(dark))),
          if (hint != null) ...[const SizedBox(height: 6), Text(hint, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary(dark)))],
          if (onRefresh != null) ...[const SizedBox(height: 16), OutlinedButton.icon(onPressed: onRefresh, icon: Icon(Icons.refresh_rounded, color: AppColors.gold), label: Text('تحديث', style: GoogleFonts.cairo(color: AppColors.gold)), style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.gold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))],
        ]),
      ),
    );
  }

  // ── Busy Overlay ──
  static Widget busyOverlay({String text = 'جاري التنفيذ...'}) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.card(isDark), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20)]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(height: 12),
            Text(text, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}
