import 'package:flutter/material.dart';

import '../../../services/theme_service.dart';

import '../models/home_dashboard_config.dart';

/// Single source of truth for accent colors per dashboard card type.
/// كل نوع بطاقة له لون مميز → hierarchy بصري واضح بدل لون واحد لكل حاجة.
class HomeAccent {
  HomeAccent._();

  // ── ألوان العلامة التجارية ─────────────────────────────
  static const Color gold = Color(0xFFDBBF74);
  static const Color goldLight = Color(0xFFE8D49B);
  static const Color goldDark = Color(0xFFB8974A);
  static const Color navy = Color(0xFF13273F);
  static const Color navyLight = Color(0xFF1E3A5F);
  static const Color navyDark = Color(0xFF0D1A2A);

  // ── ألوان التمييز حسب الوحدة ──────────────────────────
  static const Color indigo = Color(0xFF5C6BC0);
  static const Color amber = Color(0xFFFFA726);
  static const Color purple = Color(0xFFAB47BC);
  static const Color teal = Color(0xFF26A69A);
  static const Color orange = Color(0xFFFF9800);
  static const Color pink = Color(0xFFEC407A);
  static const Color red = Color(0xFFEF5350);
  static const Color cyan = Color(0xFF26C6DA);
  static const Color blueGrey = Color(0xFF78909C);
  static const Color green = Color(0xFF43A047);

  /// اللون المميز لنوع البطاقة
  static Color of(HomeDashboardCardType type) {
    switch (type) {
      case HomeDashboardCardType.clients:
        return indigo;
      case HomeDashboardCardType.leads:
        return amber;
      case HomeDashboardCardType.opportunities:
        return purple;
      case HomeDashboardCardType.crm:
        return indigo;
      case HomeDashboardCardType.pipeline:
        return teal;
      case HomeDashboardCardType.inventory:
        return orange;
      case HomeDashboardCardType.priceRequests:
        return pink;
      case HomeDashboardCardType.expenses:
        return red;
      case HomeDashboardCardType.employees:
        return purple;
      case HomeDashboardCardType.tasks:
        return cyan;
    }
  }

  /// لون خلفية البطاقة مع تدرج خفيف من اللون المميز
  static Color tintedSurface(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    return Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      theme.colorScheme.surface,
    );
  }

  /// لون خلفية أيقونة (تدرج أقوى)
  static Color tintedContainer(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    return Color.alphaBlend(
      accent.withValues(alpha: 0.16),
      theme.colorScheme.surface,
    );
  }

  /// لون إطار البطاقة
  static Color border(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return accent.withValues(alpha: isDark ? 0.35 : 0.22);
  }

  /// تدرج ثنائي (للأيقونات) — من اللون إلى درجة أغمق
  static List<Color> gradient(Color accent) {
    return [accent, Color.lerp(accent, Colors.black, 0.22)!];
  }

  /// اللون المميز الحالي — بيتبع اختيار المستخدم من زر 🎨
  static Color get accent => ThemeService().accentColor;
}
