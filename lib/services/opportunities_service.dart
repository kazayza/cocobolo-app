import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class OpportunitiesService {

  // ══════════════════════════════════════
  //  📋 Lookups
  // ══════════════════════════════════════

  /// جلب مراحل البيع
  Future<List<dynamic>> getStages() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/stages'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في جلب المراحل: $e');
    }
  }

  /// جلب مصادر التواصل
  Future<List<dynamic>> getSources() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/sources'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في جلب المصادر: $e');
    }
  }

  /// جلب حالات التواصل
  Future<List<dynamic>> getStatuses() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/statuses'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في جلب الحالات: $e');
    }
  }

  /// جلب أنواع الإعلانات
  Future<List<dynamic>> getAdTypes() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/ad-types'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في جلب أنواع الإعلانات: $e');
    }
  }

  /// جلب فئات الاهتمام
  Future<List<dynamic>> getCategories() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/categories'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في جلب الفئات: $e');
    }
  }

  /// جلب أسباب الخسارة
  Future<List<dynamic>> getLostReasons() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/lost-reasons'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في جلب أسباب الخسارة: $e');
    }
  }

  /// جلب أنواع المهام
  Future<List<dynamic>> getTaskTypes() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/task-types'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في جلب أنواع المهام: $e');
    }
  }

  /// جلب الموظفين
  Future<List<dynamic>> getEmployees() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/employees'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في جلب الموظفين: $e');
    }
  }

  // ══════════════════════════════════════
  //  🎯 الفرص - CRUD
  // ══════════════════════════════════════

  /// جلب كل الفرص مع فلاتر
  Future<List<dynamic>> getAll({
    String? search,
    int? stageId,
    int? sourceId,
    int? employeeId,
    String? followUpStatus,
  }) async {
    try {
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (stageId != null) params['stageId'] = stageId.toString();
      if (sourceId != null) params['sourceId'] = sourceId.toString();
      if (employeeId != null) params['employeeId'] = employeeId.toString();
      if (followUpStatus != null) params['followUpStatus'] = followUpStatus;

      final uri = Uri.parse('$baseUrl/api/opportunities')
          .replace(queryParameters: params.isNotEmpty ? params : null);

      final res = await http.get(uri);
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في جلب الفرص: $e');
    }
  }

  /// جلب فرصة بالـ ID
  Future<Map<String, dynamic>?> getOpportunityById(int opportunityId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/$opportunityId'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data != null) {
          return Map<String, dynamic>.from(data);
        }
      }
      return null;
    } catch (e) {
      throw Exception('خطأ في جلب الفرصة: $e');
    }
  }

  /// إنشاء فرصة جديدة
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/opportunities'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return jsonDecode(res.body);
    } catch (e) {
      throw Exception('خطأ في إنشاء الفرصة: $e');
    }
  }

  /// إنشاء فرصة مع عميل جديد أو موجود
  Future<Map<String, dynamic>> createWithClient(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/opportunities/create-with-client'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return jsonDecode(res.body);
    } catch (e) {
      throw Exception('خطأ في إنشاء الفرصة مع العميل: $e');
    }
  }

  /// تعديل فرصة
  Future<Map<String, dynamic>> update(int opportunityId, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/opportunities/$opportunityId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return jsonDecode(res.body);
    } catch (e) {
      throw Exception('خطأ في تعديل الفرصة: $e');
    }
  }

  /// تغيير مرحلة الفرصة
  Future<Map<String, dynamic>> updateStage(int opportunityId, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/opportunities/$opportunityId/stage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return jsonDecode(res.body);
    } catch (e) {
      throw Exception('خطأ في تغيير المرحلة: $e');
    }
  }

  /// حذف فرصة
  Future<Map<String, dynamic>> remove(int opportunityId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/opportunities/$opportunityId'),
      );
      return jsonDecode(res.body);
    } catch (e) {
      throw Exception('خطأ في حذف الفرصة: $e');
    }
  }

  // ══════════════════════════════════════
  //  🔍 البحث
  // ══════════════════════════════════════

  /// البحث عن عميل بالتليفون
  Future<Map<String, dynamic>> searchByPhone(String phone) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/search-by-phone?phone=$phone'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return {'found': false};
    } catch (e) {
      throw Exception('خطأ في البحث: $e');
    }
  }

  /// بحث عن عملاء
  Future<List<dynamic>> searchClients(String query) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/search-clients?q=$query'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في البحث عن العملاء: $e');
    }
  }

  /// التحقق من وجود فرصة مفتوحة للعميل
  Future<Map<String, dynamic>> checkOpenOpportunity(int partyId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/check-open/$partyId'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return {'hasOpen': false};
    } catch (e) {
      throw Exception('خطأ في التحقق: $e');
    }
  }

  // ══════════════════════════════════════
  //  📊 الإحصائيات
  // ══════════════════════════════════════

  /// ملخص الفرص
  Future<Map<String, dynamic>> getSummary() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/summary'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return {};
    } catch (e) {
      throw Exception('خطأ في جلب الملخص: $e');
    }
  }

  /// ملخص الـ Pipeline
  Future<dynamic> getPipelineSummary() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/pipeline-summary'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return {};
    } catch (e) {
      throw Exception('خطأ في جلب ملخص Pipeline: $e');
    }
  }

  // ══════════════════════════════════════
  //  💬 التايم لاين
  // ══════════════════════════════════════

  /// جلب سجل التواصل للفرصة
  Future<List<dynamic>> getOpportunityTimeline(int opportunityId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/interactions/opportunity/$opportunityId'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return [];
    } catch (e) {
      throw Exception('خطأ في جلب السجل: $e');
    }
  }

  // ══════════════════════════════════════
  // 🛑 طلبات موافقة إغلاق الفرص - مطابقة بلازور
  // ══════════════════════════════════════

  /// طلب موافقة إغلاق (خسارة/غير مهتم/تم البيع) - يبعت إشعار لـ GM و SalesManager
  Future<Map<String, dynamic>> requestClosureApproval({
    required int opportunityId,
    required int requestedStageId,
    int? lostReasonId,
    String? requestReasonNotes,
    required String userName,
    String requestSource = 'Flutter',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/opportunities/$opportunityId/request-closure'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestedStageId': requestedStageId,
          'lostReasonId': lostReasonId,
          'requestReasonNotes': requestReasonNotes,
          'userName': userName,
          'requestSource': requestSource,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// جلب طلب معلق لفرصة معينة
  Future<Map<String, dynamic>?> getPendingClosureRequest(int opportunityId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/$opportunityId/closure-request'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data == null) return null;
        if (data is Map<String, dynamic>) return data;
      }
    } catch (_) {}
    return null;
  }

  /// كل طلبات الإغلاق المعلقة (للمدير)
  Future<List<dynamic>> getPendingClosureRequests() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/closure-requests/pending'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
    } catch (_) {}
    return [];
  }

  /// كل طلبات الإغلاق مع فلتر حالة - للشاشة الجديدة
  Future<List<dynamic>> getClosureRequests({String? status}) async {
    try {
      final q = <String, String>{};
      if (status != null && status != 'all') q['status'] = status;
      final uri = Uri.parse('$baseUrl/api/opportunities/closure-requests').replace(queryParameters: q.isEmpty ? null : q);
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
      }
      // fallback للـ pending endpoint لو الـ all مش موجود
      if (status == null || status == 'Pending' || status == 'all') {
        return await getPendingClosureRequests();
      }
    } catch (_) {}
    return [];
  }

  /// اعتماد طلب إغلاق (GM/SalesManager)
  Future<Map<String, dynamic>> approveClosureRequest({required int requestId, required String userName, String? reviewNotes, String? actorRole}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/opportunities/closure-requests/$requestId/approve'),
        headers: {'Content-Type': 'application/json', if (actorRole != null) 'x-user-role': actorRole},
        body: jsonEncode({'userName': userName, 'actorRole': actorRole, 'reviewNotes': reviewNotes}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// رفض طلب إغلاق
  Future<Map<String, dynamic>> rejectClosureRequest({required int requestId, required String userName, String? reviewNotes, String? actorRole}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/opportunities/closure-requests/$requestId/reject'),
        headers: {'Content-Type': 'application/json', if (actorRole != null) 'x-user-role': actorRole},
        body: jsonEncode({'userName': userName, 'actorRole': actorRole, 'reviewNotes': reviewNotes}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// تنفيذ الإغلاق بعد الموافقة (المستخدم ينفذ بنفسه)
  Future<Map<String, dynamic>> executeClosure({required int opportunityId, required String userName}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/opportunities/$opportunityId/execute-closure'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userName': userName}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}