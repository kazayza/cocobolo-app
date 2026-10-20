import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants.dart';
import '../auth/session_service.dart';
import '../../services/offline_cache_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final dynamic body;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.body,
  });

  @override
  String toString() => message;
}

/// HTTP client موحد للمسارات المحمية.
/// يضيف Bearer Token تلقائياً ويعطي رسائل API العربية بدل فشل صامت.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Map<String, String> _headers({Map<String, String>? extra}) {
    final token = SessionService.instance.accessToken;
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  Uri uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('$baseUrl$normalized');
    if (query == null || query.isEmpty) return base;
    final clean = <String, String>{};
    query.forEach((key, value) {
      if (value == null || value.toString().isEmpty) return;
      clean[key] = value.toString();
    });
    return base.replace(queryParameters: clean);
  }

  Future<http.Response> get(String path, {Map<String, dynamic>? query}) =>
      _getWithCache(path, query);

  Future<http.Response> _getWithCache(
      String path, Map<String, dynamic>? query) async {
    final cacheKey = '$path${query != null ? '?${query.entries.map((e) => '${e.key}=${e.value}').join('&')}' : ''}';

    // محاولة إرجاع البيانات المخزنة أولاً للوصول السريع
    final cached = OfflineCacheService.instance.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return _buildResponse(cached);
    }

    try {
      final response = await http.get(uri(path, query), headers: _headers());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // تخزين الاستجابة الناجحة للاستخدام أوفلاين لاحقاً
        try {
          final data = jsonDecode(response.body);
          OfflineCacheService.instance.set(cacheKey, data);
        } catch (_) {}
      }

      return response;
    } catch (e) {
      // عند فشل الاتصال، إرجاع البيانات المخزنة إذا وجدت
      final cached2 = OfflineCacheService.instance.get<Map<String, dynamic>>(cacheKey);
      if (cached2 != null) {
        return _buildResponse(cached2);
      }
      rethrow;
    }
  }

  http.Response _buildResponse(Map<String, dynamic> data) {
    return http.Response(
      jsonEncode(data),
      200,
      headers: {'content-type': 'application/json'},
      request: null,
    );
  }

  Future<http.Response> post(String path, {Object? body}) => http.post(
        uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      );

  Future<http.Response> put(String path, {Object? body}) => http.put(
        uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      );

  Future<http.Response> delete(String path, {Object? body}) => http.delete(
        uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      );

  dynamic decode(http.Response response, {bool allowEmpty = false}) {
    dynamic data;
    if (response.body.trim().isEmpty) {
      if (allowEmpty && response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      }
    } else {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = response.body;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map
          ? (data['message'] ?? data['error'] ?? 'فشل تنفيذ الطلب').toString()
          : 'فشل تنفيذ الطلب (${response.statusCode})';
      final code = data is Map ? data['code']?.toString() : null;
      throw ApiException(
        statusCode: response.statusCode,
        message: message,
        code: code,
        body: data,
      );
    }
    return data;
  }
}
