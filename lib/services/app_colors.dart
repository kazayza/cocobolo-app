import 'package:flutter/material.dart';

class AppColors {
  // ===================================
  // 🎨 ألوان اللوجو (الأساسية)
  // ===================================
  static const Color gold = Color(0xFFDBBF74);
  static const Color goldLight = Color(0xFFE8D49B);
  static const Color goldDark = Color(0xFFB8974A);
  static const Color navy = Color(0xFF13273F);
  static const Color navyLight = Color(0xFF1E3A5F);
  static const Color navyDark = Color(0xFF0D1A2A);

  // ===================================
  // 🌙 Dark Theme Colors
  // ===================================
  static const Color darkBackground = Color(0xFF0D1A2A);
  static const Color darkSurface = Color(0xFF13273F);
  static const Color darkCard = Color(0xFF1E3A5F);
  static const Color darkText = Colors.white;
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextHint = Color(0xFF707070);
  static const Color darkDivider = Color(0xFF2A4A6A);
  static const Color darkInputFill = Color(0xFF1A3050);

  // ===================================
  // ☀️ Light Theme Colors
  // ===================================
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightText = Color(0xFF13273F);
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

  static Color primary(bool isDark) => gold;
  
  static Color primaryDark(bool isDark) => isDark ? gold : navy;

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
        const Color(0xFFF5F7FA),
        Colors.white,
        const Color(0xFFF0F4F8),
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