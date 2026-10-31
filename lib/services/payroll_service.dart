import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../core/network/api_client.dart';
import '../core/auth/session_service.dart';

class PayrollService {
  final ApiClient _api = ApiClient.instance;

  Future<List<dynamic>> getByMonth(String? month) async {
    try {
      final res = await _api.get('/api/payroll', query: month != null ? {'month': month} : null);
      if (res.statusCode == 200) {
        final data = _api.decode(res);
        if (data is List) return data;
        if (data is Map && data['data'] is List) return data['data'];
        if (data is Map && data['items'] is List) return data['items'];
        return [];
      }
    } catch (_) {}
    try {
      final url = month != null ? '$baseUrl/api/payroll?month=$month' : '$baseUrl/api/payroll';
      final res = await http.get(Uri.parse(url), headers: SessionService.instance.authHeaders);
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

  /// مرتبات موظف واحد — GET /api/payroll/employee/:id
  /// الخادم يرتّبها بالأحدث أولًا (PayrollMonth DESC) ونحافظ على ترتيبه.
  /// الأخطاء لا تُبتلع هنا: قسيمة الموظف يجب أن تُظهر الخطأ مع إعادة
  /// المحاولة لا فراغًا صامتًا.
  Future<List<dynamic>> getByEmployee(int employeeId) async {
    final res = await _api.get('/api/payroll/employee/$employeeId');
    final data = _api.decode(res);
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'];
    return [];
  }

  /// حلّ رابط مستخدم ↔ موظف — GET /api/users/:userId/employee
  /// الرد مغلّف بـ successResponse: ‏{success, data: {employeeID, FullName}}‏
  /// فيُفكّ التغليف من `data` الداخلية عبر ApiClient.decode ثم قراءة
  /// الحقل منها. (‏UserService.getEmployeeId يقرأ الجسم الخام فيرجع
  /// null فعليًا — لا يُعتمد عليه هنا.)
  Future<int?> getLinkedEmployee(int userId) async {
    final res = await _api.get('/api/users/$userId/employee');
    final data = _api.decode(res);
    Map<dynamic, dynamic>? payload;
    if (data is Map && data['data'] is Map) {
      payload = data['data'] as Map;
    } else if (data is Map) {
      payload = data;
    }
    final v = payload?['employeeID'] ??
        payload?['EmployeeID'] ??
        payload?['employeeId'];
    return (v as num?)?.toInt();
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

  /// حساب جماعي لشهر بلا حفظ — POST /api/payroll/calculate
  Future<List<dynamic>> calculate(String month) async {
    final res = await _api.post('/api/payroll/calculate', body: {'month': month});
    if (res.statusCode == 200) {
      final data = _api.decode(res);
      if (data is Map && data['data'] is List) return data['data'];
      if (data is List) return data;
    }
    throw Exception('فشل حساب الرواتب (${res.statusCode})');
  }

  /// حساب + حفظ تشغيل رواتب للمراجعة — POST /api/payroll/runs
  Future<Map<String, dynamic>> createRun(String month) async {
    final res = await _api.post('/api/payroll/runs', body: {'month': month});
    final data = _api.decode(res);
    if ((res.statusCode == 200 || res.statusCode == 201) && data is Map && data['success'] == true) {
      return Map<String, dynamic>.from(data['data'] as Map? ?? {});
    }
    throw Exception(data is Map ? (data['message'] ?? 'فشل حفظ كشف الرواتب') : 'فشل حفظ كشف الرواتب');
  }

  /// تشغيلات الرواتب — GET /api/payroll/runs
  Future<List<dynamic>> getRuns({String? month}) async {
    try {
      final res = await _api.get('/api/payroll/runs', query: month != null ? {'month': month} : null);
      if (res.statusCode == 200) {
        final data = _api.decode(res);
        if (data is Map && data['data'] is List) return data['data'];
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }

  /// اعتماد مرتب — POST /api/payroll/:id/approve
  Future<void> approve(int payrollId) async {
    final res = await _api.post('/api/payroll/$payrollId/approve');
    final data = _api.decode(res);
    if (res.statusCode != 200 || (data is Map && data['success'] != true)) {
      throw Exception(data is Map ? (data['message'] ?? 'فشل الاعتماد') : 'فشل الاعتماد');
    }
  }

  /// صرف مرتب من خزينة — POST /api/payroll/:id/pay
  Future<void> pay(int payrollId, int cashBoxId) async {
    final res = await _api.post('/api/payroll/$payrollId/pay', body: {'cashBoxId': cashBoxId});
    final data = _api.decode(res);
    if (res.statusCode != 200 || (data is Map && data['success'] != true)) {
      throw Exception(data is Map ? (data['message'] ?? 'فشل الصرف') : 'فشل الصرف');
    }
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
