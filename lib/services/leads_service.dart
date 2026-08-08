import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

/// CRM Leads API — parity with Blazor LeadsCrmService
class LeadsService {
  // ── Statuses (exact DB strings) ──────────────────────────
  static const statusAll = 'الكل';
  static const statusNew = 'جديد';
  static const statusAssigned = 'تم الإسناد';
  static const statusContacted = 'تم التواصل';
  static const statusConverted = 'محول';
  static const statusRejected = 'مرفوض';

  static const List<String> allStatuses = [
    statusNew,
    statusAssigned,
    statusContacted,
    statusConverted,
    statusRejected,
  ];

  // ── Interaction types ────────────────────────────────────
  static const typeAssigned = 'إسناد';
  static const typeCall = 'اتصال';
  static const typeWhatsApp = 'واتساب';
  static const typeNote = 'ملاحظة';
  static const typeFollowUp = 'متابعة';
  static const typeConverted = 'تحويل';
  static const typeRejected = 'رفض';

  static const List<String> interactionTypes = [
    typeCall,
    typeWhatsApp,
    typeNote,
    typeFollowUp,
    typeAssigned,
    typeRejected,
  ];

  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  static Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ═════════════════════════════════════════════════════════
  // LIST
  // ═════════════════════════════════════════════════════════
  static Future<LeadsListResult> getLeads({
    String? status,
    String? search,
    int? employeeId,
    String? city,
    String? projectType,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final q = <String, String>{
        'page': '$page',
        'limit': '$limit',
      };
      if (status != null && status.isNotEmpty && status != statusAll) {
        q['status'] = status;
      }
      if (search != null && search.trim().isNotEmpty) {
        q['search'] = search.trim();
      }
      if (employeeId != null && employeeId > 0) {
        q['employeeId'] = '$employeeId';
      }
      if (city != null && city.isNotEmpty && city != statusAll) {
        q['city'] = city;
      }
      if (projectType != null &&
          projectType.isNotEmpty &&
          projectType != statusAll) {
        q['projectType'] = projectType;
      }
      if (dateFrom != null) q['dateFrom'] = dateFrom;
      if (dateTo != null) q['dateTo'] = dateTo;

      final response = await http.get(_uri('/api/leads', q));
      if (response.statusCode != 200) {
        return LeadsListResult.empty();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return LeadsListResult(
          items: decoded.cast<dynamic>(),
          total: decoded.length,
          page: page,
          limit: limit,
        );
      }
      if (decoded is Map<String, dynamic>) {
        final items = (decoded['items'] as List?) ?? [];
        return LeadsListResult(
          items: items,
          total: decoded['total'] is int
              ? decoded['total'] as int
              : int.tryParse('${decoded['total']}') ?? items.length,
          page: decoded['page'] is int ? decoded['page'] as int : page,
          limit: decoded['limit'] is int ? decoded['limit'] as int : limit,
          totalPages: decoded['totalPages'] is int
              ? decoded['totalPages'] as int
              : 1,
        );
      }
    } catch (e) {
      print('❌ LeadsService.getLeads: $e');
    }
    return LeadsListResult.empty();
  }

  static Future<Map<String, dynamic>> getFilterOptions() async {
    try {
      final response = await http.get(_uri('/api/leads/filter-options'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      print('❌ LeadsService.getFilterOptions: $e');
    }
    return {'cities': <dynamic>[], 'projectTypes': <dynamic>[]};
  }

  static Future<Map<String, dynamic>> getStats({
    int? employeeId,
    String? city,
    String? projectType,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final q = <String, String>{};
      if (employeeId != null) q['employeeId'] = '$employeeId';
      if (city != null && city.isNotEmpty && city != statusAll) {
        q['city'] = city;
      }
      if (projectType != null &&
          projectType.isNotEmpty &&
          projectType != statusAll) {
        q['projectType'] = projectType;
      }
      if (dateFrom != null) q['dateFrom'] = dateFrom;
      if (dateTo != null) q['dateTo'] = dateTo;

      final response =
          await http.get(_uri('/api/leads/stats', q.isEmpty ? null : q));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      print('❌ LeadsService.getStats: $e');
    }
    return {};
  }

  static Future<List<dynamic>> getEmployees() async {
    try {
      final response = await http.get(_uri('/api/leads/employees'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
      }
    } catch (e) {
      print('❌ LeadsService.getEmployees: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getLeadById(int leadId) async {
    try {
      final response = await http.get(_uri('/api/leads/$leadId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      print('❌ LeadsService.getLeadById: $e');
    }
    return null;
  }

  /// Update status / assignment / notes
  static Future<Map<String, dynamic>> updateLead({
    required int leadId,
    required String userName,
    String? leadStatus,
    int? assignedEmployeeId,
    bool clearAssignment = false,
    String? notes,
    String? feedback,
    String? rejectedReason,
    String? actorRole,
  }) async {
    try {
      final body = <String, dynamic>{
        'userName': userName,
      };
      if (leadStatus != null) body['leadStatus'] = leadStatus;
      if (clearAssignment) {
        body['assignedEmployeeId'] = null;
      } else if (assignedEmployeeId != null) {
        body['assignedEmployeeId'] = assignedEmployeeId;
      }
      if (notes != null) body['notes'] = notes;
      if (feedback != null) body['feedback'] = feedback;
      if (rejectedReason != null) body['rejectedReason'] = rejectedReason;
      if (actorRole != null) body['actorRole'] = actorRole;

      final response = await http.put(
        _uri('/api/leads/$leadId'),
        headers: {
          ..._jsonHeaders,
          if (actorRole != null) 'x-user-role': actorRole,
        },
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': response.statusCode == 200};
    } catch (e) {
      print('❌ LeadsService.updateLead: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> convertLeadToClient({
    required int leadId,
    required String userName,
    required int employeeId,
    double expectedValue = 0,
    String? notes,
    int? sourceId,
    int? adTypeId,
    int? categoryId,
    int? taskTypeId,
  }) async {
    try {
      final response = await http.post(
        _uri('/api/leads/$leadId/convert'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'userName': userName,
          'employeeId': employeeId,
          'expectedValue': expectedValue,
          'notes': notes,
          'sourceId': sourceId,
          'adTypeId': adTypeId,
          'categoryId': categoryId,
          'taskTypeId': taskTypeId,
        }),
      );
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (data['data'] is Map) {
          return {
            ...data,
            ...Map<String, dynamic>.from(data['data'] as Map),
          };
        }
        return data;
      }
      return {'success': false, 'message': 'استجابة غير متوقعة'};
    } catch (e) {
      print('❌ LeadsService.convert: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<dynamic>> getInteractions(int leadId) async {
    try {
      final response = await http.get(_uri('/api/leads/$leadId/interactions'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
      }
    } catch (e) {
      print('❌ LeadsService.getInteractions: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> addInteraction({
    required int leadId,
    required String userName,
    required String interactionType,
    String? summary,
    String? notes,
    String? newLeadStatus,
    String? rejectedReason,
    DateTime? nextFollowUpDate,
    int? employeeId,
    String? actorRole,
  }) async {
    try {
      final body = <String, dynamic>{
        'userName': userName,
        'interactionType': interactionType,
        if (summary != null) 'summary': summary,
        if (notes != null) 'notes': notes,
        if (newLeadStatus != null) 'newLeadStatus': newLeadStatus,
        if (rejectedReason != null) 'rejectedReason': rejectedReason,
        if (nextFollowUpDate != null)
          'nextFollowUpDate': nextFollowUpDate.toIso8601String(),
        if (employeeId != null) 'employeeId': employeeId,
        if (actorRole != null) 'actorRole': actorRole,
      };

      final response = await http.post(
        _uri('/api/leads/$leadId/interactions'),
        headers: {
          ..._jsonHeaders,
          if (actorRole != null) 'x-user-role': actorRole,
        },
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': response.statusCode == 200};
    } catch (e) {
      print('❌ LeadsService.addInteraction: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ═════════════════════════════════════════════════════════
  // REJECT APPROVAL FLOW (GeneralManager)
  // ═════════════════════════════════════════════════════════

  /// Employee requests reject — needs GeneralManager approval
  static Future<Map<String, dynamic>> requestReject({
    required int leadId,
    required String userName,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        _uri('/api/leads/$leadId/reject-request'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'userName': userName,
          'reason': reason,
        }),
      );
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': response.statusCode == 200};
    } catch (e) {
      print('❌ LeadsService.requestReject: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Pending reject request for one lead (or null)
  static Future<Map<String, dynamic>?> getPendingReject(int leadId) async {
    try {
      final response =
          await http.get(_uri('/api/leads/$leadId/reject-request'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null) return null;
        if (data is Map<String, dynamic>) return data;
      }
    } catch (e) {
      print('❌ LeadsService.getPendingReject: $e');
    }
    return null;
  }

  /// All pending reject requests (for GM list later)
  static Future<List<dynamic>> getPendingRejectRequests() async {
    try {
      final response =
          await http.get(_uri('/api/leads/reject-requests/pending'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
      }
    } catch (e) {
      print('❌ LeadsService.getPendingRejectRequests: $e');
    }
    return [];
  }

  /// GM approve / deny reject request
  static Future<Map<String, dynamic>> decideRejectRequest({
    required int requestId,
    required bool approve,
    required String userName,
    String? actorRole,
    String? decisionNotes,
  }) async {
    try {
      final response = await http.post(
        _uri('/api/leads/reject-requests/$requestId/decide'),
        headers: {
          ..._jsonHeaders,
          if (actorRole != null) 'x-user-role': actorRole,
        },
        body: jsonEncode({
          'approve': approve,
          'userName': userName,
          'actorRole': actorRole,
          'decisionNotes': decisionNotes,
        }),
      );
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'success': response.statusCode == 200};
    } catch (e) {
      print('❌ LeadsService.decideRejectRequest: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── UI helpers ───────────────────────────────────────────
  static bool canConvert(Map<String, dynamic>? lead) {
    if (lead == null) return false;
    if (lead['CanConvert'] == true) return true;
    final converted = lead['IsConverted'] == true || lead['IsConverted'] == 1;
    if (converted) return false;
    final status = '${lead['LeadStatus'] ?? ''}';
    if (status == statusConverted || status == statusRejected) return false;
    if (status == statusContacted) return true;
    return lead['LastContactDate'] != null;
  }

  static bool isLocked(Map<String, dynamic>? lead) {
    if (lead == null) return true;
    final status = '${lead['LeadStatus'] ?? ''}';
    return lead['IsConverted'] == true ||
        lead['IsConverted'] == 1 ||
        status == statusConverted ||
        status == statusRejected;
  }
}

class LeadsListResult {
  final List<dynamic> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  LeadsListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    this.totalPages = 1,
  });

  factory LeadsListResult.empty() => LeadsListResult(
        items: const [],
        total: 0,
        page: 1,
        limit: 50,
      );
}
