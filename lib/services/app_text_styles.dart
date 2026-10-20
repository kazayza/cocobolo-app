import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// مقياس طباعة موحد للتطبيق باستخدام خط Cairo.
/// كل الشاشات يجب أن تستخدم هذه الأنماط بدلاً من TextStyle مباشرة.
class AppTextStyles {
  AppTextStyles._();

  // ── عناوين الصفحات (Page Titles) ──
  static TextStyle displayLarge(bool isDark) => GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: AppColors.text(isDark),
        height: 1.2,
      );

  static TextStyle displayMedium(bool isDark) => GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppColors.text(isDark),
        height: 1.25,
      );

  // ── عناوين الأقسام (Section Titles) ──
  static TextStyle headlineLarge(bool isDark) => GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.text(isDark),
        height: 1.3,
      );

  static TextStyle headlineMedium(bool isDark) => GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.text(isDark),
        height: 1.3,
      );

  static TextStyle headlineSmall(bool isDark) => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.text(isDark),
        height: 1.3,
      );

  // ── عناوين البطاقات (Card Titles) ──
  static TextStyle titleLarge(bool isDark) => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.text(isDark),
        height: 1.3,
      );

  static TextStyle titleMedium(bool isDark) => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.text(isDark),
        height: 1.3,
      );

  static TextStyle titleSmall(bool isDark) => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary(isDark),
        height: 1.3,
      );

  // ── النص الأساسي (Body) ──
  static TextStyle bodyLarge(bool isDark) => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.text(isDark),
        height: 1.5,
      );

  static TextStyle bodyMedium(bool isDark) => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.text(isDark),
        height: 1.5,
      );

  static TextStyle bodySmall(bool isDark) => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary(isDark),
        height: 1.4,
      );

  // ── تسميات الأزرار والحقول (Labels) ──
  static TextStyle labelLarge(bool isDark) => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.text(isDark),
        height: 1.3,
      );

  static TextStyle labelMedium(bool isDark) => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary(isDark),
        height: 1.3,
      );

  static TextStyle labelSmall(bool isDark) => GoogleFonts.cairo(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary(isDark),
        height: 1.3,
      );

  // ── تلميحات ونص ثانوي (Hints & Captions) ──
  static TextStyle hintLarge(bool isDark) => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textHint(isDark),
        height: 1.4,
      );

  static TextStyle hintMedium(bool isDark) => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textHint(isDark),
        height: 1.4,
      );

  static TextStyle hintSmall(bool isDark) => GoogleFonts.cairo(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.textHint(isDark),
        height: 1.4,
      );

  // ── نص الحالات (Status Text) ──
  static TextStyle statusSuccess(bool isDark) => GoogleFonts.cairo(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.success,
        height: 1.3,
      );

  static TextStyle statusError(bool isDark) => GoogleFonts.cairo(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.error,
        height: 1.3,
      );

  static TextStyle statusWarning(bool isDark) => GoogleFonts.cairo(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.warning,
        height: 1.3,
      );

  static TextStyle statusInfo(bool isDark) => GoogleFonts.cairo(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.info,
        height: 1.3,
      );
}
