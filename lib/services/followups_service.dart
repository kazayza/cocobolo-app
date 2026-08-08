import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

/// Unified follow-ups API (Blazor TaskService merge model)
class FollowUpsService {
  static Uri _uri(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  /// scope: overdue | today | tomorrow | upcoming | all
  /// source: all | lead | client | task | opportunity
  static Future<Map<String, dynamic>> getFollowUps({
    String scope = 'all',
    String source = 'all',
    int? employeeId,
    String? search,
    int limit = 150,
  }) async {
    try {
      final q = <String, String>{
        'scope': scope,
        'source': source,
        'limit': '$limit',
      };
      if (employeeId != null && employeeId > 0) {
        q['employeeId'] = '$employeeId';
      }
      if (search != null && search.trim().isNotEmpty) {
        q['search'] = search.trim();
      }
      final res = await http.get(_uri('/api/followups', q));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      print('❌ FollowUpsService.getFollowUps: $e');
    }
    return {
      'items': <dynamic>[],
      'summary': _emptySummary(),
    };
  }

  static Future<Map<String, dynamic>> getSummary({
    int? employeeId,
    String source = 'all',
  }) async {
    try {
      final q = <String, String>{'source': source};
      if (employeeId != null) q['employeeId'] = '$employeeId';
      final res =
          await http.get(_uri('/api/followups/summary', q));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      print('❌ FollowUpsService.getSummary: $e');
    }
    return _emptySummary();
  }

  static Future<bool> completeLeadFollowUp(
    int interactionId,
    String userName,
  ) async {
    try {
      final res = await http.post(
        _uri('/api/followups/leads/$interactionId/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userName': userName}),
      );
      final data = jsonDecode(res.body);
      return data is Map && data['success'] == true;
    } catch (e) {
      print('❌ completeLeadFollowUp: $e');
      return false;
    }
  }

  static Map<String, dynamic> _emptySummary() => {
        'total': 0,
        'overdue': 0,
        'today': 0,
        'tomorrow': 0,
        'upcoming': 0,
        'leads': 0,
        'clients': 0,
        'opportunities': 0,
        'tasks': 0,
      };
}
