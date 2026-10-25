import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../core/network/api_client.dart';

class LoanService {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> getLoans({String? search, String? status, String? month, int page = 1, int pageSize = 15}) async {
    try {
      final res = await _api.get('/api/loans', query: {
        'search': search,
        'status': status,
        'month': month,
        'page': page,
        'pageSize': pageSize,
      });
      if (res.statusCode == 200) {
        final data = _api.decode(res);
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return {'items': [], 'totalCount': 0};
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await _api.get('/api/loans/stats');
      if (res.statusCode == 200) return Map<String, dynamic>.from(_api.decode(res) as Map);
    } catch (_) {}
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/loans/stats'));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  Future<List<dynamic>> getMonthInstallments(String month) async {
    try {
      final res = await _api.get('/api/loans/installments', query: {'month': month});
      if (res.statusCode == 200) {
        final data = _api.decode(res);
        if (data is List) return data;
        if (data is Map && data['data'] is List) return data['data'];
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getStatement(int employeeId) async {
    try {
      final res = await _api.get('/api/loans/statement/$employeeId');
      if (res.statusCode == 200) return Map<String, dynamic>.from(_api.decode(res) as Map);
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> searchEmployees(String? query) async {
    try {
      final res = await _api.get('/api/employees/lookup', query: query != null ? {'search': query} : null);
      if (res.statusCode == 200) {
        final data = _api.decode(res);
        if (data is List) return data;
        if (data is Map && data['data'] is List) return data['data'];
      }
    } catch (_) {}
    return [];
  }

  Future<bool> cancelLoan(int loanId, String currentUser) async {
    try {
      final res = await _api.post('/api/loans/$loanId/cancel', body: {'currentUser': currentUser});
      return res.statusCode == 200;
    } catch (_) { return false; }
  }
}
