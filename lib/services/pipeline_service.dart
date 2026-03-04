import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class PipelineService {

  // ===================================
  // 📊 جلب ملخص مراحل البيع
  // ===================================
  static Future<Map<String, dynamic>?> getPipelineSummary({
    int? employeeId,
    int? sourceId,
    int? adTypeId,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      // بناء الـ Query Parameters
      final params = <String, String>{};
      if (employeeId != null && employeeId != 0) params['employeeId'] = employeeId.toString();
      if (sourceId != null && sourceId != 0) params['sourceId'] = sourceId.toString();
      if (adTypeId != null && adTypeId != 0) params['adTypeId'] = adTypeId.toString();
      if (dateFrom != null) params['dateFrom'] = dateFrom;
      if (dateTo != null) params['dateTo'] = dateTo;

      final uri = Uri.parse('$baseUrl/api/opportunities/pipeline-summary')
          .replace(queryParameters: params.isNotEmpty ? params : null);

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب Pipeline Summary: $e');
    }
    return null;
  }

  // ===================================
  // 📋 جلب فرص مرحلة معينة
  // ===================================
  static Future<Map<String, dynamic>?> getOpportunitiesByStage({
    required int stageId,
    String? search,
    int? employeeId,
    int? sourceId,         // ✅ جديد
    int? adTypeId, 
    String? followUpStatus,
    String? dateFrom,
    String? dateTo,
    String? sortBy,
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final params = <String, String>{
        'stageId': stageId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (search != null && search.isNotEmpty) params['search'] = search;
      if (employeeId != null && employeeId != 0) params['employeeId'] = employeeId.toString();
      if (sourceId != null && sourceId != 0) params['sourceId'] = sourceId.toString();
      if (adTypeId != null && adTypeId != 0) params['adTypeId'] = adTypeId.toString();
      if (followUpStatus != null && followUpStatus.isNotEmpty) params['followUpStatus'] = followUpStatus;
      if (dateFrom != null) params['dateFrom'] = dateFrom;
      if (dateTo != null) params['dateTo'] = dateTo;
      if (sortBy != null) params['sortBy'] = sortBy;

      final uri = Uri.parse('$baseUrl/api/opportunities')
          .replace(queryParameters: params);

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب فرص المرحلة: $e');
    }
    return null;
  }



  // ===================================
  // 💬 جلب سجل التواصل
  // ===================================
  static Future<List<dynamic>> getInteractions(int opportunityId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/interactions/opportunity/$opportunityId'),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب سجل التواصل: $e');
    }
    return [];
  }

  // ===================================
  // 🔄 تغيير مرحلة فرصة
  // ===================================
  static Future<bool> updateStage({
    required int opportunityId,
    required int stageId,
    required String updatedBy,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/opportunities/$opportunityId/stage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'stageId': stageId,
          'updatedBy': updatedBy,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('❌ خطأ في تغيير المرحلة: $e');
    }
    return false;
  }

  // ===================================
  // 👷 جلب الموظفين
  // ===================================
  static Future<List<dynamic>> getEmployees() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/employees'),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب الموظفين: $e');
    }
    return [];
  }

  // ===================================
  // 📱 جلب المصادر
  // ===================================
  static Future<List<dynamic>> getSources() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/sources'),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب المصادر: $e');
    }
    return [];
  }

  // ===================================
  // 📢 جلب أنواع الإعلانات
  // ===================================
  static Future<List<dynamic>> getAdTypes() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/ad-types'),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب أنواع الإعلانات: $e');
    }
    return [];
  }

  // ===================================
  // 📊 جلب المراحل
  // ===================================
  static Future<List<dynamic>> getStages() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/stages'),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب المراحل: $e');
    }
    return [];
  }

  // ===================================
// 🔍 بحث عن عملاء
// ===================================
static Future<List<dynamic>> searchClients(String query) async {
  try {
    if (query.length < 2) return [];

    final res = await http.get(
      Uri.parse('$baseUrl/api/opportunities/search-clients?q=${Uri.encodeComponent(query)}'),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
  } catch (e) {
    print('❌ خطأ في البحث عن العملاء: $e');
  }
  return [];
}

// ===================================
// 📅 جلب المتابعة القادمة
// ===================================
static Future<Map<String, dynamic>?> getNextTask(int partyId) async {
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/api/tasks?assignedTo=0&status=Pending&partyId=$partyId'),
    );

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body);
      if (list is List && list.isNotEmpty) {
        return list[0];
      }
    }
  } catch (e) {
    print('❌ خطأ في جلب المتابعة: $e');
  }
  return null;
}
  // ===================================
  // 📄 جلب تفاصيل فرصة (مع حماية)
  // ===================================
  static Future<Map<String, dynamic>?> getOpportunityById(int? id) async {
    // 🛑 لو الـ ID غلط نرجع null فوراً ومنبعتش للباك اند
    if (id == null || id <= 0) return null;

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/$id'),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب تفاصيل الفرصة: $e');
    }
    return null;
  }
}

