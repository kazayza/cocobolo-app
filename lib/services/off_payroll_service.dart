import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../core/network/api_client.dart';

class OffPayrollService {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> getAll({String? month, String? status, String? search}) async {
    try {
      final res = await _api.get('/api/off-payroll', query: {'month': month, 'status': status, 'search': search});
      if (res.statusCode == 200) return Map<String, dynamic>.from(_api.decode(res)['data'] as Map? ?? {});
    } catch (_) {}
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/off-payroll?month=${month ?? ''}'));
      if (res.statusCode == 200) return jsonDecode(res.body)['data'] as Map<String, dynamic>;
    } catch (_) {}
    return {'items': [], 'totalCount': 0, 'stats': {}};
  }

  Future<bool> create({required int employeeId, required double amount, required String paymentType, required String paymentMonth, String? description}) async {
    try {
      final res = await _api.post('/api/off-payroll', body: {'employeeId': employeeId, 'amount': amount, 'paymentType': paymentType, 'paymentMonth': paymentMonth, 'description': description});
      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<bool> approve(int id) async {
    try { final r = await _api.post('/api/off-payroll/$id/approve'); return r.statusCode == 200; } catch (_) { return false; }
  }

  Future<bool> pay(int id, int cashBoxId) async {
    try { final r = await _api.post('/api/off-payroll/$id/pay', body: {'cashBoxId': cashBoxId}); return r.statusCode == 200; } catch (_) { return false; }
  }
}
