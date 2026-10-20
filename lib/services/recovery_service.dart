import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

/// خدمة استرداد الفرص الخاسرة - مطابقة 100% لبلازور RecoveryService.cs
/// تتعامل مع الفرص اللي وصلت مرحلة خسارة (4) / غير مهتم (5) وتسندها لخدمة العملاء
class RecoveryService {
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recovery/stats'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'LostCount': 0,
      'LostValue': 0,
      'UnassignedCount': 0,
      'RevivedThisMonth': 0,
      'UncontactedCount': 0,
    };
  }

  static Future<Map<String, dynamic>> getQueue({
    String? search,
    String kind = 'all',
    bool candidateOnly = false,
    bool mineOnly = false,
    bool lateOnly = false,
    bool unassignedOnly = false,
    bool uncontactedOnly = false,
    String sortBy = 'value',
    double? minValue,
    String? closedFrom,
    String? closedTo,
    int pageIndex = 1,
    int pageSize = 12,
    String? username,
  }) async {
    try {
      final params = <String, String>{
        'kind': kind,
        'sortBy': sortBy,
        'pageIndex': pageIndex.toString(),
        'pageSize': pageSize.toString(),
      };
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (candidateOnly) params['candidateOnly'] = 'true';
      if (mineOnly) params['mineOnly'] = 'true';
      if (lateOnly) params['lateOnly'] = 'true';
      if (unassignedOnly) params['unassignedOnly'] = 'true';
      if (uncontactedOnly) params['uncontactedOnly'] = 'true';
      if (minValue != null) params['minValue'] = minValue.toString();
      if (closedFrom != null) params['closedFrom'] = closedFrom;
      if (closedTo != null) params['closedTo'] = closedTo;
      if (username != null) params['username'] = username;

      final uri = Uri.parse('$baseUrl/api/recovery/queue').replace(queryParameters: params);
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      print('Recovery queue error: $e');
    }
    return {
      'Items': <dynamic>[],
      'TotalCount': 0,
      'PageIndex': pageIndex,
      'PageSize': pageSize,
      'HasMore': false,
    };
  }

  static Future<int> getLateCount() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recovery/late-count'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['count'] is int ? data['count'] : int.tryParse('${data['count']}') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  static Future<int> getUnprocessedCount() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recovery/unprocessed-count'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['count'] is int ? data['count'] : int.tryParse('${data['count']}') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  static Future<Map<String, dynamic>> runMaintenance() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/recovery/maintenance'));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {'success': false};
  }

  static Future<Map<String, dynamic>> logContact({
    required int opportunityId,
    required int partyId,
    required String channel,
    required String outcome,
    required String summary,
    DateTime? nextFollowUpDate,
    required String userName,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/recovery/contact'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'OpportunityId': opportunityId,
          'PartyId': partyId,
          'Channel': channel,
          'Outcome': outcome,
          'Summary': summary,
          'NextFollowUpDate': nextFollowUpDate?.toIso8601String(),
          'userName': userName,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getHistory(int opportunityId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recovery/history/$opportunityId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> revive({
    required int opportunityId,
    required bool sameOpportunity,
    required int newStageId,
    double? expectedValue,
    DateTime? nextFollowUpDate,
    String? newInterestedProduct,
    String? notes,
    required String userName,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/recovery/revive'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'OpportunityId': opportunityId,
          'SameOpportunity': sameOpportunity,
          'NewStageId': newStageId,
          'ExpectedValue': expectedValue,
          'NextFollowUpDate': nextFollowUpDate?.toIso8601String() ?? DateTime.now().add(const Duration(days: 3)).toIso8601String(),
          'NewInterestedProduct': newInterestedProduct,
          'Notes': notes,
          'userName': userName,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getStages() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recovery/stages'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<dynamic>> getCsEmployees() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recovery/cs-employees'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }

  static Future<int> getCurrentEmployeeId(String username) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recovery/employee/$username'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['employeeId'] is int ? data['employeeId'] : int.tryParse('${data['employeeId']}') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  // 📊 Report - مطابق LostRecoveryReport.razor
  static Future<Map<String, dynamic>> getReport({
    String? from,
    String? to,
    String status = 'all',
    int? employeeId,
    String? search,
    int pageIndex = 1,
    int pageSize = 50,
  }) async {
    try {
      final params = <String, String>{
        'status': status,
        'pageIndex': pageIndex.toString(),
        'pageSize': pageSize.toString(),
      };
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      if (employeeId != null) params['emp'] = employeeId.toString();
      if (search != null && search.trim().isNotEmpty) params['q'] = search.trim();

      final uri = Uri.parse('$baseUrl/api/recovery/report').replace(queryParameters: params);
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Report error: $e');
    }
    return {
      'Rows': <dynamic>[],
      'RowCount': 0,
      'TotalValue': 0,
      'UncontactedCount': 0,
      'ContactedCount': 0,
      'RejectedCount': 0,
      'RevivedCount': 0,
      'PageIndex': pageIndex,
      'PageSize': pageSize,
      'TotalPages': 1,
      'HasMore': false,
    };
  }

  static Future<List<dynamic>> getTrend({int months = 12}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recovery/trend?months=$months'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<dynamic>> getStaffPerformance() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recovery/staff-performance'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<dynamic>> getReasonsAnalysis() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/recovery/reasons-analysis'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }
}
