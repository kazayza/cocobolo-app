import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class LeadsService {
  // جلب كل الـ Leads (مع فلاتر اختيارية)
  static Future<List<dynamic>> getLeads({String? status, String? search}) async {
    try {
      String url = '$baseUrl/api/leads';
      List<String> queryParams = [];
      if (status != null && status != 'الكل') queryParams.add('status=$status');
      if (search != null && search.isNotEmpty) queryParams.add('search=$search');
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب الـ Leads: $e');
    }
    return [];
  }

  // جلب تفاصيل Lead معين
  static Future<Map<String, dynamic>?> getLeadById(int leadId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/leads/$leadId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب تفاصيل الـ Lead: $e');
    }
    return null;
  }

  // تحديث حالة أو بيانات الـ Lead
  static Future<bool> updateLead(int leadId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/leads/$leadId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      final resData = jsonDecode(response.body);
      return resData['success'] == true;
    } catch (e) {
      print('❌ خطأ في تحديث الـ Lead: $e');
      return false;
    }
  }

  // تحويل الـ Lead إلى عميل رسمي
  static Future<Map<String, dynamic>> convertLeadToClient(int leadId, Map<String, dynamic> dto) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/leads/$leadId/convert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(dto),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ خطأ في تحويل الـ Lead: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // جلب تفاعلات الـ Lead
  static Future<List<dynamic>> getInteractions(int leadId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/leads/$leadId/interactions'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('❌ خطأ في جلب التفاعلات: $e');
    }
    return [];
  }

  // إضافة تفاعل جديد
  static Future<bool> addInteraction(int leadId, String notes, String userName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/leads/$leadId/interactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'notes': notes, 'userName': userName}),
      );
      final resData = jsonDecode(response.body);
      return resData['success'] == true;
    } catch (e) {
      print('❌ خطأ في إضافة التفاعل: $e');
      return false;
    }
  }
}