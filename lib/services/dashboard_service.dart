import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class DashboardService {
  Future<Map<String, dynamic>> getDashboardData({
    String? dateFrom,
    String? dateTo,
    int? employeeId,
  }) async {
    try {
      String url = '$baseUrl/api/reports/dashboard?';
      if (dateFrom != null) url += 'dateFrom=$dateFrom&';
      if (dateTo != null) url += 'dateTo=$dateTo&';
      if (employeeId != null) url += 'employeeId=$employeeId';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return json['data'];
        }
      }
      throw Exception('فشل تحميل البيانات');
    } catch (e) {
      throw Exception('خطأ في الاتصال: $e');
    }
  }
}