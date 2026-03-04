import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/dashboard_model.dart';

class DashboardService {
  Future<DashboardData> getDashboardData({
    String? dateFrom,
    String? dateTo,
    int? employeeId,
    int? sourceId,
    int? stageId,
    int? adTypeId,
  }) async {
    try {
      final params = <String, String>{};
      if (dateFrom != null) params['dateFrom'] = dateFrom;
      if (dateTo != null) params['dateTo'] = dateTo;
      if (employeeId != null) params['employeeId'] = employeeId.toString();
      if (sourceId != null) params['sourceId'] = sourceId.toString();
      if (stageId != null) params['stageId'] = stageId.toString();
      if (adTypeId != null) params['adTypeId'] = adTypeId.toString();

      final uri = Uri.parse('$baseUrl/api/reports/dashboard')
          .replace(queryParameters: params.isNotEmpty ? params : null);

      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return DashboardData.fromJson(json['data']);
        }
        throw Exception(json['message'] ?? 'فشل تحميل البيانات');
      }
      throw Exception('خطأ ${response.statusCode}');
    } catch (e) {
      throw Exception('$e');
    }
  }
}