import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart'; // تأكد إن ده المسار الصح لملف الثوابت

class OpportunitiesService {
  
  // ... دوالك القديمة هنا ...

  // 👇 ضيف الدالة دي
  Future<List<dynamic>> getOpportunityTimeline(int opportunityId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/interactions/opportunity/$opportunityId'),
      );
      
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        throw Exception('فشل تحميل السجل');
      }
    } catch (e) {
      throw Exception('خطأ في الاتصال: $e');
    }
  }
}