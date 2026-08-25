import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants.dart';
import '../models/complaint_model.dart';

class ComplaintsService {
  // ===================================
  // جلب كل الشكاوى
  // ===================================
  static Future<List<ComplaintModel>> getAllComplaints({
    int? status,
    int? priority,
    int? typeId,
    int? assignedTo,
    bool? escalated,
    String? search,
    String? dateFrom,
    String? dateTo,
    bool? openOnly,
    int? partyId,
  }) async {
    try {
      // بناء الـ Query Parameters
      Map<String, String> queryParams = {};
      
      if (status != null) queryParams['status'] = status.toString();
      if (priority != null) queryParams['priority'] = priority.toString();
      if (typeId != null) queryParams['typeId'] = typeId.toString();
      if (assignedTo != null) queryParams['assignedTo'] = assignedTo.toString();
      if (escalated != null) queryParams['escalated'] = escalated.toString();
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['dateFrom'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['dateTo'] = dateTo;
      if (openOnly == true) queryParams['openOnly'] = 'true';
      if (partyId != null) queryParams['partyId'] = partyId.toString();

      String queryString = '';
      if (queryParams.isNotEmpty) {
        queryString = '?' + queryParams.entries
            .map((e) => '${e.key}=${e.value}')
            .join('&');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/complaints$queryString'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ComplaintModel.fromJson(json)).toList();
      } else {
        throw Exception('فشل في تحميل الشكاوى');
      }
    } catch (e) {
      print('❌ خطأ في جلب الشكاوى: $e');
      rethrow;
    }
  }

  // ===================================
  // جلب شكوى واحدة بالتفاصيل
  // ===================================
  static Future<ComplaintModel?> getComplaintById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/complaints/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ComplaintModel.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('فشل في تحميل بيانات الشكوى');
      }
    } catch (e) {
      print('❌ خطأ في جلب الشكوى: $e');
      rethrow;
    }
  }

  // ===================================
  // إنشاء شكوى جديدة
  // ===================================
  static Future<int?> createComplaint({
    required int partyId,
    int? opportunityId,
    required int typeId,
    required String subject,
    required String details,
    required int priority,
    int status = 1,
    int? assignedTo,
    DateTime? complaintDate,
    String? createdBy,
  }) async {
    try {
      final body = {
        'partyId': partyId,
        'opportunityId': opportunityId,
        'typeId': typeId,
        'subject': subject,
        'details': details,
        'priority': priority,
        'status': status,
        'assignedTo': assignedTo,
        'complaintDate': complaintDate?.toIso8601String(),
        'createdBy': createdBy,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/complaints'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['complaintId'];
        }
      }
      throw Exception('فشل في إضافة الشكوى');
    } catch (e) {
      print('❌ خطأ في إنشاء الشكوى: $e');
      rethrow;
    }
  }

  // ===================================
  // تعديل شكوى
  // ===================================
  static Future<bool> updateComplaint(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/complaints/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ خطأ في تعديل الشكوى: $e');
      rethrow;
    }
  }

  // ===================================
  // حذف شكوى
  // ===================================
  static Future<bool> deleteComplaint(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/complaints/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ خطأ في حذف الشكوى: $e');
      rethrow;
    }
  }

  // ===================================
  // جلب أنواع الشكاوى
  // ===================================
  static Future<List<ComplaintTypeModel>> getComplaintTypes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/complaints/types'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ComplaintTypeModel.fromJson(json)).toList();
      } else {
        throw Exception('فشل في تحميل أنواع الشكاوى');
      }
    } catch (e) {
      print('❌ خطأ في جلب أنواع الشكاوى: $e');
      rethrow;
    }
  }

  // ===================================
  // تصعيد شكوى
  // ===================================
  static Future<bool> escalateComplaint({
    required int complaintId,
    required int escalatedTo,
    required String reason,
  }) async {
    try {
      final body = {
        'escalatedTo': escalatedTo,
        'reason': reason,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/complaints/$complaintId/escalate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ خطأ في تصعيد الشكوى: $e');
      rethrow;
    }
  }

  // ===================================
  // جلب متابعات شكوى
  // ===================================
  static Future<List<FollowUpModel>> getFollowUps(int complaintId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/complaints/$complaintId/followups'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => FollowUpModel.fromJson(json)).toList();
      } else {
        throw Exception('فشل في تحميل المتابعات');
      }
    } catch (e) {
      print('❌ خطأ في جلب المتابعات: $e');
      rethrow;
    }
  }

  // ===================================
  // إضافة متابعة
  // ===================================
  static Future<int?> createFollowUp({
    required int complaintId,
    required int followUpBy,
    required String notes,
    String? actionTaken,
    DateTime? nextFollowUpDate,
  }) async {
    try {
      final body = {
        'followUpBy': followUpBy,
        'notes': notes,
        'actionTaken': actionTaken,
        'nextFollowUpDate': nextFollowUpDate?.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/complaints/$complaintId/followups'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['followUpId'];
        }
      }
      throw Exception('فشل في إضافة المتابعة');
    } catch (e) {
      print('❌ خطأ في إنشاء المتابعة: $e');
      rethrow;
    }
  }

  // ===================================
  // تعديل متابعة
  // ===================================
  static Future<bool> updateFollowUp(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/complaints/followups/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ خطأ في تعديل المتابعة: $e');
      rethrow;
    }
  }

  // ===================================
  // حذف متابعة
  // ===================================
  static Future<bool> deleteFollowUp(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/complaints/followups/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ خطأ في حذف المتابعة: $e');
      rethrow;
    }
  }
  // ===================================
// البحث عن عملاء
// ===================================
  // ===================================
  // 📊 إحصائيات الشكاوى
  // ===================================
  static Future<Map<String, dynamic>> getComplaintStats({
    int? status,
    int? priority,
    int? typeId,
    int? assignedTo,
    String? search,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = '$status';
      if (priority != null) params['priority'] = '$priority';
      if (typeId != null) params['typeId'] = '$typeId';
      if (assignedTo != null) params['assignedTo'] = '$assignedTo';
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (dateFrom != null && dateFrom.isNotEmpty) params['dateFrom'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) params['dateTo'] = dateTo;

      final uri = Uri.parse('$baseUrl/api/complaints/stats')
          .replace(queryParameters: params.isEmpty ? null : params);
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is Map && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data'] as Map);
        }
      }
      return {};
    } catch (e) {
      print('❌ خطأ في جلب إحصائيات الشكاوى: $e');
      return {};
    }
  }

  // ===================================
  // 👤 إسناد شكوى لموظف
  // ===================================
  static Future<bool> assignComplaint({
    required int complaintId,
    int? assignedTo,
    String? updatedBy,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/complaints/$complaintId/assign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'assignedTo': assignedTo,
          'updatedBy': updatedBy,
        }),
      );
      final body = jsonDecode(res.body);
      return body is Map && body['success'] == true;
    } catch (e) {
      print('❌ خطأ في إسناد الشكوى: $e');
      return false;
    }
  }

  // ===================================
  // 🔄 تغيير حالة الشكوى (مع الحل)
  // ===================================
  static Future<bool> changeStatus({
    required int complaintId,
    required int newStatus,
    String? solution,
    String? updatedBy,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/complaints/$complaintId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'newStatus': newStatus,
          'solution': solution,
          'updatedBy': updatedBy,
        }),
      );
      final body = jsonDecode(res.body);
      return body is Map && body['success'] == true;
    } catch (e) {
      print('❌ خطأ في تغيير حالة الشكوى: $e');
      return false;
    }
  }

  // ===================================
  // ⭐ تقييم رضا العميل
  // ===================================
  static Future<bool> rateComplaint({
    required int complaintId,
    required int satisfactionLevel,
    String? updatedBy,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/complaints/$complaintId/rate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'satisfactionLevel': satisfactionLevel,
          'updatedBy': updatedBy,
        }),
      );
      final body = jsonDecode(res.body);
      return body is Map && body['success'] == true;
    } catch (e) {
      print('❌ خطأ في تسجيل التقييم: $e');
      return false;
    }
  }

static Future<List<Map<String, dynamic>>> searchClients(String query) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/clients/search?q=$query'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  } catch (e) {
    print('❌ خطأ في البحث عن العملاء: $e');
    return [];
  }
}

// ===================================
// جلب الموظفين النشطين
// ===================================
static Future<List<Map<String, dynamic>>> getActiveEmployees() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/employees/active'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  } catch (e) {
    print('❌ خطأ في جلب الموظفين: $e');
    return [];
  }
}

// ═══════════════════════════════════════════
// 📎 المرفقات (صور / مستندات)
// ═══════════════════════════════════════════

// رابط تشغيل/تحميل المرفق
static String attachmentUrl(int attachmentId) =>
    '$baseUrl/api/complaints/attachments/$attachmentId/file';

// جلب مرفقات شكوى
static Future<List<ComplaintAttachmentModel>> getAttachments(int complaintId) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/complaints/$complaintId/attachments'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => ComplaintAttachmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  } catch (e) {
    print('❌ خطأ في جلب المرفقات: $e');
    return [];
  }
}

// رفع مرفق (ملتيميبارت — نفس قيود بلازور: 10MB + الصيغ المسموحة)
static Future<int?> uploadAttachment(
  int complaintId, {
  required String fileName,
  required List<int> bytes,
  required String mimeType,
  int? uploadedByUserId,
}) async {
  try {
    if (bytes.length > 10 * 1024 * 1024) {
      throw Exception('الحجم يتجاوز 10 ميجا');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/complaints/$complaintId/attachments'),
    );
    request.files.add(http.MultipartFile.fromBytes('file', bytes,
        filename: fileName, contentType: MediaType.parse(mimeType)));
    if (uploadedByUserId != null) {
      request.fields['uploadedByUserId'] = uploadedByUserId.toString();
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['attachmentId'];
    } else {
      print('❌ فشل الرفع: ${response.body}');
      return null;
    }
  } catch (e) {
    print('❌ خطأ في رفع المرفق: $e');
    rethrow;
  }
}

// حذف مرفق
static Future<bool> deleteAttachment(int complaintId, int attachmentId) async {
  try {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/complaints/$complaintId/attachments/$attachmentId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return true;
    }
    return false;
  } catch (e) {
    print('❌ خطأ في حذف المرفق: $e');
    return false;
  }
}
}