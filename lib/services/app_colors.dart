import 'package:flutter/material.dart';

class AppColors {
  // ===================================
  // 🎨 ألوان اللوجو (الأساسية)
  // ===================================
  static const Color gold = Color(0xFFD4A853);
  static const Color goldLight = Color(0xFFF0DBA8);
  static const Color goldDark = Color(0xFFB8912A);
  static const Color navy = Color(0xFF1B2A4A);
  static const Color navyLight = Color(0xFF2D4A7A);
  static const Color navyDark = Color(0xFF0F1D36);

  // ===================================
  // 🌙 Dark Theme Colors
  // ===================================
  static const Color darkBackground = Color(0xFF0F1D36);
  static const Color darkSurface = Color(0xFF1B2A4A);
  static const Color darkCard = Color(0xFF2D4A7A);
  static const Color darkText = Colors.white;
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextHint = Color(0xFF707070);
  static const Color darkDivider = Color(0xFF2D4A7A);
  static const Color darkInputFill = Color(0xFF1B2A4A);

  // ===================================
  // ☀️ Light Theme Colors
  // ===================================
  static const Color lightBackground = Color(0xFFF1F5F9);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightText = Color(0xFF1B2A4A);
  static const Color lightTextSecondary = Color(0xFF4A5568);
  static const Color lightTextHint = Color(0xFF8A94A6);
  static const Color lightDivider = Color(0xFFE2E8F0);
  static const Color lightInputFill = Color(0xFFF0F4F8);

  // ===================================
  // 🎯 Helper Methods
  // ===================================
  static Color background(bool isDark) =>
      isDark ? darkBackground : lightBackground;

  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;

  static Color card(bool isDark) => isDark ? darkCard : lightCard;

  static Color text(bool isDark) => isDark ? darkText : lightText;

  static Color textSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;

  static Color textHint(bool isDark) => isDark ? darkTextHint : lightTextHint;

  static Color divider(bool isDark) => isDark ? darkDivider : lightDivider;

  static Color inputFill(bool isDark) =>
      isDark ? darkInputFill : lightInputFill;

  // ===================================
  // 🚦 ألوان الحالات (Semantic Status Colors)
  // ===================================
  static const Color success = Color(0xFF43A047);
  static const Color successLight = Color(0xFF66BB6A);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFA726);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFF42A5F5);
  static const Color neutral = Color(0xFF64748B);
  static const Color neutralLight = Color(0xFF94A3B8);

  // ===================================
  // 💬 ألوان العلامات الخارجية (Brand)
  // ===================================
  /// أخضر واتساب الرسمي — لون علامة خارجية لا لون حالة،
  /// يُستخدم حصرًا مع شعار واتساب (FontAwesomeIcons.whatsapp)
  static const Color whatsapp = Color(0xFF25D366);

  // ===================================
  // 🌟 Premium Dark/Light Layer
  // ===================================
  static const Color premiumBackgroundDark = Color(0xFF0F1D36);
  static const Color premiumBackgroundLight = Color(0xFFF1F5F9);
  static const Color premiumSurfaceDark = Color(0xFF1B2A4A);
  static const Color premiumSurfaceLight = Color(0xFFFFFFFF);
  static const Color premiumStrokeDark = Color(0xFF2D4A7A);
  static const Color premiumStrokeLight = Color(0xFFE8ECF4);
  static const Color premiumGlow = Color(0x1AD4A853);

  static Color primary(bool isDark) => gold;
  
  static Color primaryDark(bool isDark) => isDark ? gold : navy;
  
  // Helper methods for premium colors
  
  static Color premiumBackground(bool isDark) => isDark ? premiumBackgroundDark : premiumBackgroundLight;
  
  static Color premiumSurface(bool isDark) => isDark ? premiumSurfaceDark : premiumSurfaceLight;
  
  static Color premiumStroke(bool isDark) => isDark ? premiumStrokeDark : premiumStrokeLight;

  // ===================================
  // 🎨 Gradient للـ Login
  // ===================================
  static List<Color> loginGradient(bool isDark) {
    if (isDark) {
      return [
        navyDark,
        navy,
        navyDark,
      ];
    } else {
      return [
        navy.withValues(alpha: 0.06),
        navy.withValues(alpha: 0.03),
        navy.withValues(alpha: 0.06),
      ];
    }
  }

  // ===================================
  // 🎨 Gradient للزرار
  // ===================================
  static List<Color> buttonGradient(bool isDark) {
    if (isDark) {
      return [gold, goldLight];
    } else {
      return [navy, navyLight];
    }
  }
}