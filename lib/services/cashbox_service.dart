import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class CashboxService {
  
  // جلب كل الخزائن
  static Future<List<Map<String, dynamic>>> getAllCashboxes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/cashbox'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Error getting cashboxes: $e');
      return [];
    }
  }

  // جلب ملخص الخزينة
  static Future<Map<String, dynamic>?> getSummary({int? cashboxId}) async {
    try {
      String url = '$baseUrl/api/cashbox/summary';
      if (cashboxId != null) {
        url += '?cashboxId=$cashboxId';
      }
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error getting summary: $e');
      return null;
    }
  }

  // جلب حركات الخزينة
  static Future<List<Map<String, dynamic>>> getTransactions({
    int? cashboxId,
    String? startDate,
    String? endDate,
    String? transactionType,
    String? referenceType,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      if (cashboxId != null) {
        queryParams['cashboxId'] = cashboxId.toString();
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }
      if (transactionType != null && transactionType.isNotEmpty && transactionType != 'الكل') {
        queryParams['transactionType'] = transactionType;
      }
      if (referenceType != null && referenceType.isNotEmpty && referenceType != 'الكل') {
        queryParams['referenceType'] = referenceType;
      }
      
      final uri = Uri.parse('$baseUrl/api/cashbox/transactions')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      
      print('🔍 Fetching transactions: $uri');
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Error getting transactions: $e');
      return [];
    }
  }

  // إضافة حركة جديدة (قبض / صرف)
  static Future<Map<String, dynamic>> createTransaction({
    required int cashBoxId,
    required String transactionType,
    required double amount,
    String? notes,
    required String createdBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/cashbox/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cashBoxId': cashBoxId,
          'transactionType': transactionType,
          'amount': amount,
          'referenceType': 'Manual',
          'notes': notes ?? '',
          'createdBy': createdBy,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'فشل إضافة الحركة'};
    } catch (e) {
      print('❌ Error creating transaction: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // تحويل بين خزينتين
  static Future<Map<String, dynamic>> transfer({
    required int cashBoxIdFrom,
    required int cashBoxIdTo,
    required String cashBoxFromName,
    required String cashBoxToName,
    required double amount,
    String? notes,
    required String createdBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/cashbox/transfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cashBoxIdFrom': cashBoxIdFrom,
          'cashBoxIdTo': cashBoxIdTo,
          'cashBoxFromName': cashBoxFromName,
          'cashBoxToName': cashBoxToName,
          'amount': amount,
          'notes': notes ?? '',
          'createdBy': createdBy,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'فشل التحويل'};
    } catch (e) {
      print('❌ Error transferring: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // جلب رصيد خزينة معينة
  static Future<double> getCashboxBalance(int cashboxId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/cashbox/$cashboxId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['CurrentBalance'] ?? 0).toDouble();
      }
      return 0;
    } catch (e) {
      print('❌ Error getting balance: $e');
      return 0;
    }
  }
  // ══════════════════════════════════════════
// ✅ دوال داشبورد الخزينة
// ══════════════════════════════════════════

// إحصائيات عامة
static Future<Map<String, dynamic>?> getDashboardStats({String period = 'month'}) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/cashbox/dashboard/stats?period=$period'),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  } catch (e) {
    print('❌ Error getting dashboard stats: $e');
    return null;
  }
}

// بيانات الرسم البياني
static Future<List<Map<String, dynamic>>> getChartData({int days = 7}) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/cashbox/dashboard/chart?days=$days'),
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  } catch (e) {
    print('❌ Error getting chart data: $e');
    return [];
  }
}

// توزيع المصروفات
static Future<List<Map<String, dynamic>>> getDistribution({String period = 'month'}) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/cashbox/dashboard/distribution?period=$period'),
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  } catch (e) {
    print('❌ Error getting distribution: $e');
    return [];
  }
}

// أرصدة الخزائن
static Future<List<Map<String, dynamic>>> getCashboxBalances() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/cashbox/dashboard/balances'),
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  } catch (e) {
    print('❌ Error getting balances: $e');
    return [];
  }
}

// آخر الحركات
static Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 5}) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/cashbox/dashboard/recent?limit=$limit'),
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  } catch (e) {
    print('❌ Error getting recent transactions: $e');
    return [];
  }
}

// مقارنة شهرية
static Future<Map<String, dynamic>?> getMonthlyComparison() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/cashbox/dashboard/comparison'),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  } catch (e) {
    print('❌ Error getting comparison: $e');
    return null;
  }
}
}