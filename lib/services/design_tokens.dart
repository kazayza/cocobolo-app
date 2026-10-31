import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// ═══════════════════════════════════════════════════════════
///  نظام التصميم الموحد — COCOBOLO Design Tokens
///  المصدر الوحيد لقيم التصميم: مسافات، أنصاف أقطار، ألوان حالات،
///  وتدرجات الهوية. قيم الألوان الأساسية نفسها تعيش في
///  [AppColors] (الهوية الرسمية: كحلي #1B2A4A × ذهبي #D4A853)
///  وهذا الملف يبني فوقها دون تكرار أي قيمة.
/// ═══════════════════════════════════════════════════════════

/// مسافات موحدة — سلم 4/8/12/16/24/32
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// الحشوة الأفقية القياسية لصفحات التطبيق
  static const double page = lg;
}

/// أنصاف أقطار موحدة — كل قيم التطبيق الحالية تقع على هذا السلم
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 18;
  static const double xxl = 22;
  static const double xxxl = 24;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
  static BorderRadius get card => BorderRadius.circular(xl);
  static BorderRadius get chip => BorderRadius.circular(pill);
}

/// ألوان الحالات الدلالية — تعريف واحد لكل حالة في التطبيق كله.
/// القيم الأساسية من [AppColors] بعد توحيدها على قيم الشاشات السائدة.
class AppStatus {
  AppStatus._();

  // حالات الفواتير
  static const Color paid = AppColors.success; // مدفوعة — أخضر
  static const Color partiallyPaid = AppColors.warning; // جزئياً — برتقالي
  static const Color cancelled = AppColors.error; // ملغاة — أحمر
  static const Color open = AppColors.info; // مفتوحة — أزرق

  /// متأخرة — برتقالي عميق (للنصوص والتنبيهات فوق الخلفيات الفاتحة)
  static const Color overdue = Color(0xFFF57C00);

  /// طلبات التعديل — بنفسجي (هوية مميزة لطلبات التعديل في القائمة والتفاصيل)
  static const Color editPending = Color(0xFF9C27B0);

  /// الربح — زمردي عميق (مميز عن أخضر «مدفوعة» لأنه رقم تحليلي)
  static const Color profit = Color(0xFF059669);

  /// معلومات حالة فاتورة: (اللون، النص العربي، الأيقونة)
  static (Color, String, IconData) invoiceInfo(String? status) {
    switch (status) {
      case 'Paid':
        return (paid, 'مدفوعة', Icons.check_circle_rounded);
      case 'PartiallyPaid':
        return (partiallyPaid, 'مدفوعة جزئياً', Icons.payment_rounded);
      case 'Cancelled':
        return (cancelled, 'ملغاة', Icons.cancel_rounded);
      default:
        return (open, 'مفتوحة', Icons.lock_open_rounded);
    }
  }
}

/// تدرجات الهوية الرسمية
class AppGradients {
  AppGradients._();

  /// تدرج الترويسات: كحلي عميق ← كحلي ← فولاذي
  static const List<Color> identityHeader = [
    AppColors.navyDark,
    AppColors.navy,
    AppColors.navyLight,
  ];

  /// تدرج هيدر تفاصيل الفاتورة (نهاري): كحلي ← فولاذي
  static const List<Color> identityCard = [
    AppColors.navy,
    AppColors.navyLight,
  ];
}

/// ثيم نصي عربي موحد بمقاسات [AppTextStyles] — العائلة قابلة للاختيار
/// من إعدادات التطبيق (الافتراضية Cairo — خط التطبيق السائد)، وكل أنماط
/// النظام/الكيت تُبنى عبر هذا الملف حتى تتبع اختيار المستخدم دائمًا.
class AppTextTheme {
  AppTextTheme._();

  /// مفاتيح العائلات المدعومة (أسماء Google Fonts الرسمية)
  static const String familyCairo = 'Cairo';
  static const String familyTajawal = 'Tajawal';
  static const String familyAlmarai = 'Almarai';
  static const String familyRubik = 'Rubik';
  static const String familyIbmPlexSansArabic = 'IBM Plex Sans Arabic';
  static const String familyAmiri = 'Amiri';
  static const String familyReadexPro = 'Readex Pro';
  static const String familyRoboto = 'Roboto';

  /// خط نظام الجهاز (SF على iPhone وRoboto على Android) — بلا عائلة
  /// خط مُسمّاة: يُترك الحقل فارغًا فيأخذ المنصة خطها الافتراضي.
  static const String familySystem = 'System';

  /// باني نمط نصي لعائلة بعينها — نقطة التبديل الوحيدة بين العائلات
  static TextStyle Function({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) _styleFactory(String family) {
    switch (family) {
      case familyTajawal:
        return (
                {fontSize, fontWeight, color, height}) =>
            GoogleFonts.tajawal(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
      case familyAlmarai:
        return (
                {fontSize, fontWeight, color, height}) =>
            GoogleFonts.almarai(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
      case familyRubik:
        return (
                {fontSize, fontWeight, color, height}) =>
            GoogleFonts.rubik(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
      case familyIbmPlexSansArabic:
        return (
                {fontSize, fontWeight, color, height}) =>
            GoogleFonts.ibmPlexSansArabic(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
      case familyAmiri:
        return (
                {fontSize, fontWeight, color, height}) =>
            GoogleFonts.amiri(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
      case familyReadexPro:
        return (
                {fontSize, fontWeight, color, height}) =>
            GoogleFonts.readexPro(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
      case familyRoboto:
        return (
                {fontSize, fontWeight, color, height}) =>
            GoogleFonts.roboto(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
      case familySystem:
        // خط النظام: نمط خام بلا عائلة — الافتراضي للمنصة كما هو
        return (
                {fontSize, fontWeight, color, height}) =>
            TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
      case familyCairo:
      default:
        return (
                {fontSize, fontWeight, color, height}) =>
            GoogleFonts.cairo(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
            );
    }
  }

  /// نمط نصي واحد بعائلة مختارة (لمعاينات الإعدادات وأي نص مفرد)
  static TextStyle style(
    String family, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) =>
      _styleFactory(family)(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  /// تطبيق عائلة مختارة على ثيم نصي قائم (مسار main.dart — يحافظ على
  /// مقاسات Material الحالية ويبدّل العائلة فقط)
  static TextTheme textThemeFor(String family, TextTheme base) {
    switch (family) {
      case familyTajawal:
        return GoogleFonts.tajawalTextTheme(base);
      case familyAlmarai:
        return GoogleFonts.almaraiTextTheme(base);
      case familyRubik:
        return GoogleFonts.rubikTextTheme(base);
      case familyIbmPlexSansArabic:
        return GoogleFonts.ibmPlexSansArabicTextTheme(base);
      case familyAmiri:
        return GoogleFonts.amiriTextTheme(base);
      case familyReadexPro:
        return GoogleFonts.readexProTextTheme(base);
      case familyRoboto:
        return GoogleFonts.robotoTextTheme(base);
      case familySystem:
        return base;
      case familyCairo:
      default:
        return GoogleFonts.cairoTextTheme(base);
    }
  }

  /// ثيم نصي كامل بمقاسات النظام لعائلة مختارة
  static TextTheme of({
    required String family,
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    final factory = _styleFactory(family);

    TextStyle s(
      double size,
      FontWeight weight, {
      Color? color,
      double height = 1.3,
    }) =>
        factory(
          fontSize: size,
          fontWeight: weight,
          color: color ?? onSurface,
          height: height,
        );

    return TextTheme(
      displayLarge: s(28, FontWeight.w900, height: 1.2),
      displayMedium: s(24, FontWeight.w800, height: 1.25),
      headlineLarge: s(20, FontWeight.w800),
      headlineMedium: s(18, FontWeight.w700),
      headlineSmall: s(16, FontWeight.w700),
      titleLarge: s(16, FontWeight.w700),
      titleMedium: s(14, FontWeight.w600),
      titleSmall: s(12, FontWeight.w600, color: onSurfaceVariant),
      bodyLarge: s(16, FontWeight.w500, height: 1.5),
      bodyMedium: s(14, FontWeight.w500, height: 1.5),
      bodySmall: s(12, FontWeight.w500, color: onSurfaceVariant, height: 1.4),
      labelLarge: s(14, FontWeight.w600),
      labelMedium: s(12, FontWeight.w600, color: onSurfaceVariant),
      labelSmall: s(10, FontWeight.w600, color: onSurfaceVariant),
    );
  }

  /// توافق خلفي: الثيم النصي بعائلة Cairo
  static TextTheme cairo({
    required Color onSurface,
    required Color onSurfaceVariant,
  }) =>
      of(
        family: familyCairo,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
      );
}
