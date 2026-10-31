import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// ─────────────────────────────────────────────────────────────
///  خدمة صور الموظفين — حفظ محلي على الجهاز فقط
///  - لكل موظف ملف داخل مجلد مستندات التطبيق:
///    `employee_photos/<employeeId>.jpg`
///  - الصور لا تُرسل إلى الباك إند ولا تُحفظ في قاعدة البيانات
///    إطلاقًا (قرار المالك) — هي زينة محلية على هذا الجهاز
///  - ذاكرة مؤقتة بالبايتات تتيح الرسم المتزامن بعد التحميل،
///    وChangeNotifier على نمط ProfileAvatarService
/// ─────────────────────────────────────────────────────────────
class EmployeePhotoService extends ChangeNotifier {
  static final EmployeePhotoService _instance = EmployeePhotoService._();
  factory EmployeePhotoService() => _instance;
  EmployeePhotoService._();

  /// بايتات كل موظف بعد تحميله (null = لا صورة محلية له)
  final Map<int, Uint8List?> _cache = {};

  Future<File> _fileFor(int employeeId) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/employee_photos');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    return File('${folder.path}/$employeeId.jpg');
  }

  /// المسار الكامل لملف صورة الموظف على الجهاز
  Future<String> pathFor(int employeeId) async =>
      (await _fileFor(employeeId)).path;

  /// البايتات الجاهزة للرسم الآن (بعد تحميل سابق)، وإلا null
  Uint8List? bytesFor(int? employeeId) =>
      employeeId == null ? null : _cache[employeeId];

  /// تحميل صورة الموظف من التخزين المحلي إلى الذاكرة المؤقتة
  Future<Uint8List?> loadFor(int employeeId) async {
    if (_cache.containsKey(employeeId)) return _cache[employeeId];
    try {
      final file = await _fileFor(employeeId);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        _cache[employeeId] = bytes;
        return bytes;
      }
    } catch (e) {
      debugPrint('⚠️ EmployeePhotoService.loadFor: $e');
    }
    _cache[employeeId] = null;
    return null;
  }

  /// حفظ صورة الموظف محليًا (الذاكرة أولًا فيظهر الرسم فورًا)
  Future<void> saveFor(int employeeId, Uint8List bytes) async {
    _cache[employeeId] = bytes;
    notifyListeners();
    try {
      final file = await _fileFor(employeeId);
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint('⚠️ EmployeePhotoService.saveFor: $e');
    }
  }

  /// حذف صورة الموظف المحلية نهائيًا من الجهاز
  Future<void> deleteFor(int employeeId) async {
    _cache[employeeId] = null;
    notifyListeners();
    try {
      final file = await _fileFor(employeeId);
      if (file.existsSync()) await file.delete();
    } catch (e) {
      debugPrint('⚠️ EmployeePhotoService.deleteFor: $e');
    }
  }
}
