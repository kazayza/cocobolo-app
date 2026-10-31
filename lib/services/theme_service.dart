import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'design_tokens.dart';

/// خيار لون (Accent) — المستخدم يختار منه
class ThemeAccentOption {
  final String name;
  final Color color;

  const ThemeAccentOption({required this.name, required this.color});
}

/// خيار عائلة خط — [family] هو اسم Google Fonts الرسمي (مفتاح الحفظ)
class ThemeFontOption {
  final String family;
  final String name;

  const ThemeFontOption({required this.family, required this.name});
}

/// خيار حجم خط — معامل قياس يُطبق على التطبيق كله
class ThemeFontScaleOption {
  final double factor;
  final String name;

  const ThemeFontScaleOption({required this.factor, required this.name});
}

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeKey = 'isDarkMode';
  static const String _accentKey = 'accentIndex';
  static const String _fontFamilyKey = 'fontFamily';
  static const String _fontScaleKey = 'fontScaleIndex';

  // ── عائلات الخط المتاحة (عربية من Google Fonts) ─────────
  static const List<ThemeFontOption> fontOptions = [
    ThemeFontOption(family: AppTextTheme.familyCairo, name: 'Cairo — كايرو'),
    ThemeFontOption(family: AppTextTheme.familyTajawal, name: 'Tajawal — تجوّل'),
    ThemeFontOption(family: AppTextTheme.familyAlmarai, name: 'Almarai — المراعي'),
    ThemeFontOption(family: AppTextTheme.familyRubik, name: 'Rubik — روبيك'),
    ThemeFontOption(
      family: AppTextTheme.familyIbmPlexSansArabic,
      name: 'IBM Plex Sans Arabic',
    ),
    ThemeFontOption(family: AppTextTheme.familyAmiri, name: 'Amiri — أميري'),
    ThemeFontOption(
      family: AppTextTheme.familyReadexPro,
      name: 'Readex Pro — ريدكس برو',
    ),
    ThemeFontOption(family: AppTextTheme.familyRoboto, name: 'Roboto — روبوتو'),
    ThemeFontOption(
      family: AppTextTheme.familySystem,
      name: 'خط النظام — System',
    ),
  ];

  // ── درجات حجم الخط (معامل قياس نصي) ─────────────────────
  static const List<ThemeFontScaleOption> fontScaleOptions = [
    ThemeFontScaleOption(factor: 0.9, name: 'صغير'),
    ThemeFontScaleOption(factor: 1.0, name: 'متوسط'),
    ThemeFontScaleOption(factor: 1.15, name: 'كبير'),
  ];

  // ── الألوان المتاحة ─────────────────────────────────────
  static const List<ThemeAccentOption> accentOptions = [
    ThemeAccentOption(name: 'ذهبي', color: Color(0xFFD4A853)),
    ThemeAccentOption(name: 'كحلي', color: Color(0xFF1B2A4A)),
    ThemeAccentOption(name: 'تركوازي', color: Color(0xFF26A69A)),
    ThemeAccentOption(name: 'نيلي', color: Color(0xFF5C6BC0)),
    ThemeAccentOption(name: 'زمردي', color: Color(0xFF43A047)),
    ThemeAccentOption(name: 'وردي', color: Color(0xFFEC407A)),
  ];

  bool _isDarkMode = true;
  int _accentIndex = 0;
  String _fontFamily = AppTextTheme.familyCairo;
  int _fontScaleIndex = 1;

  bool get isDarkMode => _isDarkMode;

  /// عائلة الخط المختارة (اسم Google Fonts)
  String get fontFamily => _fontFamily;

  /// موضع عائلة الخط داخل [fontOptions]
  int get fontFamilyIndex =>
      fontOptions.indexWhere((o) => o.family == _fontFamily);

  /// معامل حجم الخط المختار (يُضرب في قياس النص على مستوى التطبيق)
  double get fontScale => fontScaleOptions[_fontScaleIndex].factor;

  int get fontScaleIndex => _fontScaleIndex;

  /// اللون المختار
  Color get accentColor => accentOptions[_accentIndex].color;

  int get accentIndex => _accentIndex;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? true;
    _accentIndex = (prefs.getInt(_accentKey) ?? 0).clamp(
      0,
      accentOptions.length - 1,
    );
    final savedFamily = prefs.getString(_fontFamilyKey);
    if (savedFamily != null &&
        fontOptions.any((o) => o.family == savedFamily)) {
      _fontFamily = savedFamily;
    }
    _fontScaleIndex = (prefs.getInt(_fontScaleKey) ?? 1).clamp(
      0,
      fontScaleOptions.length - 1,
    );
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
    notifyListeners();
  }

  /// تغيير اللون الأساسي (المختار)
  Future<void> setAccent(int index) async {
    if (index < 0 || index >= accentOptions.length) return;
    _accentIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, index);
    notifyListeners();
  }

  /// تغيير عائلة الخط (تُحفظ باسم العائلة نفسه)
  Future<void> setFontFamily(String family) async {
    if (!fontOptions.any((o) => o.family == family)) return;
    _fontFamily = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, family);
    notifyListeners();
  }

  /// تغيير درجة حجم الخط
  Future<void> setFontScaleIndex(int index) async {
    if (index < 0 || index >= fontScaleOptions.length) return;
    _fontScaleIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fontScaleKey, index);
    notifyListeners();
  }

  ThemeData get themeData {
    return _isDarkMode ? darkTheme : lightTheme;
  }

  /// الثيم النهاري (يُبنى ديناميكياً حسب اللون المختار)
  ThemeData get lightTheme {
    // أدوار surfaceContainer تُجاوَز بقيم العائلة المعتمدة: fromSeed بلون ذهبي
    // يولّد أسطحًا كريمية دافئة (#FDF2E5) تناقض الهوية (بطاقات بيضاء على رمادي).
    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
      surface: AppColors.lightSurface,
    ).copyWith(
      surfaceContainerLowest: AppColors.lightSurface,
      surfaceContainerLow: const Color(0xFFF8FAFC),
      surfaceContainer: AppColors.lightInputFill,
      surfaceContainerHigh: AppColors.lightDivider,
      surfaceContainerHighest: AppColors.lightDivider,
      primaryContainer: AppColors.goldLight,
      secondaryContainer: const Color(0xFFE8ECF4),
    );

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      cardColor: AppColors.lightCard,
      dividerColor: AppColors.lightDivider,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
    );
  }

  /// الثيم الليلي (يُبنى ديناميكياً حسب اللون المختار)
  ThemeData get darkTheme {
    // أدوار surfaceContainer تُجاوَز بقيم عائلة الكحلي: fromSeed بلون ذهبي
    // يولّد أسطحًا بنية دافئة (#201B13 — شكوى «البني» الأصلية) في الوضع الليلي.
    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
    ).copyWith(
      surfaceContainerLowest: AppColors.darkBackground,
      surfaceContainerLow: AppColors.darkSurface,
      surfaceContainer: AppColors.darkCard,
      surfaceContainerHigh: AppColors.darkCard,
      surfaceContainerHighest: AppColors.darkCard,
      primaryContainer: AppColors.goldDark,
      secondaryContainer: AppColors.darkCard,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkCard,
      dividerColor: AppColors.darkDivider,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
