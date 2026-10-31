import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/employee_model.dart';
import '../constants.dart';
import '../core/auth/session_service.dart';

class EmployeeService {
  Future<String?> _getToken() async {
    // التوكن مصدره الوحيد SessionService (Secure Storage).
    return SessionService.instance.accessToken;
  }

  Future<List<EmployeeModel>> getActiveEmployees() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/employees/active'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => EmployeeModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('خطأ في جلب الموظفين: $e');
      return [];
    }
  }
}