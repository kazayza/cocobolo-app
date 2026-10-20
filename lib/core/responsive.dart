import 'package:flutter/material.dart';

/// تصنيف أبعاد الشاشة للتصميم المتجاوب.
enum ScreenSize { mobile, tablet, desktop }

/// أداة مساعدة لتحديد حجم الشاشة وتعديل القيم حسب الحجم.
class Responsive {
  Responsive._();

  static ScreenSize of(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return ScreenSize.desktop;
    if (width >= 600) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  /// يعيد قيمة متفاوتة حسب حجم الشاشة.
  static T when<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final size = of(context);
    if (size == ScreenSize.tablet && tablet != null) return tablet;
    if (size == ScreenSize.desktop && desktop != null) return desktop;
    return mobile;
  }

  /// Padding جانبي للشاشة حسب الحجم.
  static double horizontalPadding(BuildContext context) {
    return when(
      context,
      mobile: 16,
      tablet: 24,
      desktop: 32,
    );
  }

  /// مسافة بين الأقسام حسب الحجم.
  static double sectionSpacing(BuildContext context) {
    return when(
      context,
      mobile: 24,
      tablet: 32,
      desktop: 40,
    );
  }

  /// عدد أعمدة الشبكة (grid) حسب الحجم.
  static int gridColumns(BuildContext context) {
    return when(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 4,
    );
  }

  /// عرض بطاقة KPI حسب الحجم.
  static double kpiCardWidth(BuildContext context) {
    return when(
      context,
      mobile: 110,
      tablet: 140,
      desktop: 160,
    );
  }
}
