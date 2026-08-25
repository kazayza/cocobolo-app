import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────────
///  خدمة الصورة الشخصية — حفظ محلي على الجهاز
///  - الصورة تُنسخ لمجلد التطبيق (وليس Base64 في الإعدادات)
///  - المسار يُحفظ في shared_preferences فيبقى بعد إغلاق التطبيق
///  - ChangeNotifier → أي تغيير يظهر فوراً في كل الأماكن
///    (ترويسة الهوم • القائمة الجانبية • الإعدادات)
/// ─────────────────────────────────────────────────────────────
class ProfileAvatarService extends ChangeNotifier {
  static final ProfileAvatarService _instance = ProfileAvatarService._();
  factory ProfileAvatarService() => _instance;
  ProfileAvatarService._();

  static const String _pathKey = 'profile_image_path';

  String? _imagePath;
  String? get imagePath => _imagePath;

  /// تحميل المسار المحفوظ عند بدء التشغيل
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_pathKey);
      if (saved != null && File(saved).existsSync()) {
        _imagePath = saved;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ ProfileAvatarService.load: $e');
    }
  }

  /// اختيار صورة من المعرض أو الكاميرا وحفظها محلياً
  Future<String?> pickAndSave(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return null; // المستخدم ألغى

      final dir = await getApplicationDocumentsDirectory();
      final savedFile = await File(
        picked.path,
      ).copy('${dir.path}/profile_avatar.jpg');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pathKey, savedFile.path);

      _imagePath = savedFile.path;
      notifyListeners();
      return savedFile.path;
    } catch (e) {
      debugPrint('⚠️ ProfileAvatarService.pickAndSave: $e');
      return null;
    }
  }

  /// حذف الصورة والعودة للحرف
  Future<void> remove() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pathKey);
      _imagePath = null;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ ProfileAvatarService.remove: $e');
    }
  }
}
