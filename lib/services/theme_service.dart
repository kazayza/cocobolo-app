import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

/// خيار لون (Accent) — المستخدم يختار منه
class ThemeAccentOption {
  final String name;
  final Color color;

  const ThemeAccentOption({required this.name, required this.color});
}

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeKey = 'isDarkMode';
  static const String _accentKey = 'accentIndex';

  // ── الألوان المتاحة ─────────────────────────────────────
  static const List<ThemeAccentOption> accentOptions = [
    ThemeAccentOption(name: 'ذهبي', color: Color(0xFFDBBF74)),
    ThemeAccentOption(name: 'كحلي', color: Color(0xFF1E3A5F)),
    ThemeAccentOption(name: 'تركوازي', color: Color(0xFF26A69A)),
    ThemeAccentOption(name: 'نيلي', color: Color(0xFF5C6BC0)),
    ThemeAccentOption(name: 'زمردي', color: Color(0xFF43A047)),
    ThemeAccentOption(name: 'وردي', color: Color(0xFFEC407A)),
  ];

  bool _isDarkMode = true;
  int _accentIndex = 0;

  bool get isDarkMode => _isDarkMode;

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

  ThemeData get themeData {
    return _isDarkMode ? darkTheme : lightTheme;
  }

  /// الثيم النهاري (يُبنى ديناميكياً حسب اللون المختار)
  ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
      surface: AppColors.lightSurface,
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
    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
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
