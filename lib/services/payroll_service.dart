import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../core/network/api_client.dart';

class PayrollService {
  final ApiClient _api = ApiClient.instance;

  Future<List<dynamic>> getByMonth(String month) async {
    try {
      final res = await _api.get('/api/payroll', query: {'month': month});
      if (res.statusCode == 200) {
        final data = _api.decode(res);
        if (data is List) return data;
        if (data is Map && data['data'] is List) return data['data'];
        return [];
      }
    } catch (_) {}
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/payroll?month=$month'));
      if (res.statusCode == 200) return jsonDecode(res.body) as List;
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> getMonths() async {
    try {
      final res = await _api.get('/api/payroll/months');
      if (res.statusCode == 200) {
        final data = _api.decode(res);
        if (data is List) return data;
        if (data is Map && data['data'] is List) return data['data'];
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    try {
      final res = await _api.get('/api/payroll/$id');
      if (res.statusCode == 200) {
        final data = _api.decode(res);
        if (data is Map<String, dynamic>) return data;
        if (data is Map && data['data'] is Map) return Map<String, dynamic>.from(data['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> getStats(String? month) async {
    try {
      final res = await _api.get('/api/payroll/stats', query: month != null ? {'month': month} : null);
      if (res.statusCode == 200) {
        final data = _api.decode(res);
        if (data is Map<String, dynamic>) return data;
        if (data is Map && data['data'] is Map) return Map<String, dynamic>.from(data['data'] as Map);
      }
    } catch (_) {}
    return {};
  }
}
