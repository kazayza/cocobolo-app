import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/offline_cache_service.dart';

/// المصدر الوحيد لتوكن الجلسة على الجهاز.
/// التوكن يُحفظ في Secure Storage، والبيانات غير الحساسة فقط في SharedPreferences.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _tokenKey = 'cocobolo_access_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  String? _accessToken;
  String? get accessToken => _accessToken;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  int? _userId;
  int? get userId => _userId;

  /// ترويسات المصادقة الموحّدة لكل نداءات الـ API في التطبيق.
  /// أي نداء للـ API يجب أن يمر من هنا بدل بناء الترويسة يدويًا.
  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (hasToken) 'Authorization': 'Bearer $_accessToken',
      };

  Future<void> initialize() async {
    _accessToken = await _storage.read(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId');
  }

  Future<void> saveToken(String token) async {
    _accessToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> saveUserMetadata({
    required int userId,
    required String username,
    required String fullName,
    required bool rememberMe,
  }) async {
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('remember_me', rememberMe);
    await prefs.setInt('userId', userId);
    await prefs.setString('username', username);
    await prefs.setString('fullName', fullName);
    // لا نخزن كلمة المرور نهائياً.
    await prefs.remove('saved_password');
  }

  Future<void> clear() async {
    _accessToken = null;
    _userId = null;
    await _storage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('saved_password');
    await prefs.remove('userId');
    // إنهاء الجلسة = مسح كاش الأوفلاين كاملًا (كل النطاقات + المفاتيح القديمة)،
    // حتى لا يرى مستخدم لاحق على نفس الجهاز بيانات مستخدم سابق.
    await OfflineCacheService.instance.clearAll();
  }
}
