import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة تخزين مؤقت للبيانات باستخدام shared_preensions.
/// تدعم الحفظ والاسترجاع مع انتهاء الصلاحية (TTL).
class OfflineCacheService {
  OfflineCacheService._();
  static final OfflineCacheService instance = OfflineCacheService._();

  static const String _prefix = 'cache_';
  static const Duration defaultTtl = Duration(hours: 24);

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// مفتاح الكاش منسوبًا للمستخدم الحالي: cache_u<userId>_<cacheKey>
  /// النسبة تمنع قراءة مستخدمٍ كاشَ مستخدمٍ آخر على نفس الجهاز.
  /// مفاتيح ما قبل هذا التعديل (بدون النسبة) تصبح غير قابلة للوصول تلقائيًا،
  /// ويحذفها clearAll() عند أول تسجيل خروج (تطابق البادئة cache_).
  /// ملاحظة للترحيل المستقبلي: مقطع النسبة u<userId>_ يقع بين البادئة العامة
  /// والمفتاح الخام، فيسهل تحليله/نزعه عند نقل التخزين لمحرك آخر.
  String _key(String cacheKey) {
    final uid = _prefs?.getInt('userId') ?? 0;
    return '${_prefix}u${uid}_$cacheKey';
  }

  /// حفظ بيانات مؤقتة مع مدة صلاحية.
  Future<void> set(String cacheKey, dynamic data,
      {Duration? ttl}) async {
    final prefs = await _getPrefs();
    final entry = {
      'data': data,
      'expiresAt': DateTime.now().add(ttl ?? defaultTtl).toIso8601String(),
    };
    await prefs.setString(_key(cacheKey), jsonEncode(entry));
  }

  /// استرجاع البيانات المؤقتة إذا لم تنته صلاحيتها.
  T? get<T>(String cacheKey) {
    try {
      final prefs = _prefs;
      if (prefs == null) return null;
      final raw = prefs.getString(_key(cacheKey));
      if (raw == null) return null;

      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(entry['expiresAt']);
      if (DateTime.now().isAfter(expiresAt)) {
        prefs.remove(_key(cacheKey));
        return null;
      }

      return entry['data'] as T?;
    } catch (_) {
      return null;
    }
  }

  /// حذف مفتاح مؤقت.
  Future<void> remove(String cacheKey) async {
    final prefs = await _getPrefs();
    await prefs.remove(_key(cacheKey));
  }

  /// مسح كل ذاكرة التخزين المؤقت.
  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// التحقق من وجود بيانات مؤقتة غير منتهية لمفتاح معين.
  bool has(String cacheKey) {
    try {
      final prefs = _prefs;
      if (prefs == null) return false;
      final raw = prefs.getString(_key(cacheKey));
      if (raw == null) return false;
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(entry['expiresAt']);
      return !DateTime.now().isAfter(expiresAt);
    } catch (_) {
      return false;
    }
  }
}
