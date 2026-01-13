import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class UserService {
  // نخزن البيانات عشان ما نطلبش كل مرة
  static int? _cachedEmployeeId;
  static String? _cachedFullName;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 30); // صالحة نص ساعة

  static Future<int?> getEmployeeId(int userId) async {
    // لو عندنا بيانات حديثة، نرجعها فورًا
    if (_cachedEmployeeId != null && 
        _cacheTime != null && 
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedEmployeeId;
    }

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/employee'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _cachedEmployeeId = data['employeeID'];
        _cachedFullName = data['fullName'];
        _cacheTime = DateTime.now();
        return _cachedEmployeeId;
      }
    } catch (e) {
      print('Error fetching employee ID: $e');
    }

    return null;
  }

  static Future<String?> getFullName(int userId) async {
    await getEmployeeId(userId); // عشان نعبي الـ cache
    return _cachedFullName;
  }

  // لو عايز تنظف الـ cache (مثلاً لما يعمل logout)
  static void clearCache() {
    _cachedEmployeeId = null;
    _cachedFullName = null;
    _cacheTime = null;
  }
}