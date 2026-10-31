import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../core/auth/session_service.dart';
import '../core/network/api_client.dart';

/// عقد الأخطاء: الدوال التي تستخدمها شاشات الخزينة لا تبتلع الأخطاء
/// ولا تعيد قيمًا وهمية (0/[]/null) — ترمي [ApiException] برسالة الخادم
/// كما هي، والشاشات تعرضها مع إعادة المحاولة (نمط loan_service).
class CashboxService {
  static String _serverMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {}
    return fallback;
  }

  static Never _throwFor(http.Response response, String fallback) {
    throw ApiException(
      statusCode: response.statusCode,
      message: _serverMessage(response, fallback),
    );
  }

  // جلب كل الخزائن — ترمي ApiException عند الفشل
  static Future<List<Map<String, dynamic>>> getAllCashboxes() async {
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl/api/cashbox'),
        headers: SessionService.instance.authHeaders,
      );
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    _throwFor(response, 'فشل تحميل الخزائن');
  }

  // جلب الخزائن النشطة فقط (نقطة /active) — لقوائم الاختيار كما في بلازور
  static Future<List<Map<String, dynamic>>> getActiveCashboxes() async {
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl/api/cashbox/active'),
        headers: SessionService.instance.authHeaders,
      );
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    _throwFor(response, 'فشل تحميل الخزائن النشطة');
  }

  // حذف خزينة — يرفضها الخادم برسالة بلازور عند وجود حركات
  static Future<Map<String, dynamic>> deleteCashbox(int cashboxId) async {
    final http.Response response;
    try {
      response = await http.delete(
        Uri.parse('$baseUrl/api/cashbox/$cashboxId'),
        headers: SessionService.instance.authHeaders,
      );
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map) return Map<String, dynamic>.from(body);
      return {'success': true};
    }
    _throwFor(response, 'فشل حذف الخزينة');
  }

  // جلب ملخص الخزينة — مع معالجة فترة اختيارية؛ ترمي ApiException عند الفشل
  static Future<Map<String, dynamic>> getSummary({
    int? cashboxId,
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, String>{};
    if (cashboxId != null) params['cashboxId'] = cashboxId.toString();
    if (from != null) {
      params['from'] = from.toIso8601String().substring(0, 10);
    }
    if (to != null) {
      params['to'] = to.toIso8601String().substring(0, 10);
    }
    String url = '$baseUrl/api/cashbox/summary';
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    final http.Response response;
    try {
      response = await http.get(Uri.parse(url), headers: SessionService.instance.authHeaders);
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }
    _throwFor(response, 'فشل تحميل ملخص الخزن');
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
      
      final response = await http.get(uri, headers: SessionService.instance.authHeaders);
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // لو الرد الجديد (data/stats) → نرجع data
        if (body is Map && body['data'] is List) {
          return (body['data'] as List).cast<Map<String, dynamic>>();
        }
        // لو الرد القديم (قائمة مباشرة)
        if (body is List) {
          return body.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      print('❌ Error getting transactions: $e');
      return [];
    }
  }

  /// جلب حركات الخزينة بنسخة كاملة: بحث + ترقيم صفحات + إحصائيات + مصادر
  /// + فلترا مبلغ واتجاه فرز (Item 10). ترمي [ApiException] عند الفشل —
  /// لا نتيجة وهمية فارغة.
  static Future<CashboxTransactionsResult> getTransactionsPaged({
    int? cashboxId,
    String? startDate,
    String? endDate,
    String? transactionType,
    String? referenceType,
    String? search,
    double? amountFrom,
    double? amountTo,
    String? sort,
    int page = 1,
    int limit = 25,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (cashboxId != null) queryParams['cashboxId'] = cashboxId.toString();
    if (startDate != null && startDate.isNotEmpty) queryParams['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParams['endDate'] = endDate;
    if (transactionType != null && transactionType.isNotEmpty && transactionType != 'الكل') {
      queryParams['transactionType'] = transactionType;
    }
    if (referenceType != null && referenceType.isNotEmpty && referenceType != 'الكل') {
      queryParams['referenceType'] = referenceType;
    }
    if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();
    if (amountFrom != null) queryParams['amountFrom'] = amountFrom.toString();
    if (amountTo != null) queryParams['amountTo'] = amountTo.toString();
    if (sort != null && sort.isNotEmpty) queryParams['sort'] = sort;

    final uri = Uri.parse('$baseUrl/api/cashbox/transactions')
        .replace(queryParameters: queryParams);

    final http.Response response;
    try {
      response = await http.get(uri, headers: SessionService.instance.authHeaders);
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode != 200) {
      _throwFor(response, 'فشل تحميل الحركات');
    }
    final body = jsonDecode(response.body);
    if (body is Map) {
      final data = (body['data'] as List? ?? []).cast<Map<String, dynamic>>();
      final stats = body['stats'] is Map
          ? Map<String, dynamic>.from(body['stats'] as Map)
          : <String, dynamic>{};
      return CashboxTransactionsResult(
        data: data,
        stats: stats,
        total: (body['total'] as num?)?.toInt() ?? data.length,
        totalPages: (body['totalPages'] as num?)?.toInt() ?? 1,
        page: (body['page'] as num?)?.toInt() ?? page,
      );
    }
    if (body is List) {
      final list = body.cast<Map<String, dynamic>>();
      double tin = 0, tout = 0;
      for (final t in list) {
        final amt = (t['Amount'] ?? 0).toDouble();
        if (t['TransactionType'] == 'قبض') tin += amt; else tout += amt;
      }
      return CashboxTransactionsResult(
        data: list,
        stats: {'TotalIn': tin, 'TotalOut': tout, 'Net': tin - tout},
        total: list.length,
        totalPages: 1,
        page: 1,
      );
    }
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب الحركات',
    );
  }

  // جلب رصيد خزينة معينة — ترمي ApiException عند الفشل (لا صفر وهمي)
  static Future<double> getCashboxBalance(int cashboxId) async {
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl/api/cashbox/$cashboxId'),
        headers: SessionService.instance.authHeaders,
      );
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['CurrentBalance'] ?? 0).toDouble();
    }
    _throwFor(response, 'فشل تحميل رصيد الخزينة');
  }
  // ══════════════════════════════════════════
// ✅ دوال داشبورد الخزينة
// ══════════════════════════════════════════

// إحصائيات عامة
static Future<Map<String, dynamic>?> getDashboardStats({String period = 'month'}) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/cashbox/dashboard/stats?period=$period'),
     headers: SessionService.instance.authHeaders,);
    
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
     headers: SessionService.instance.authHeaders,);
    
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
     headers: SessionService.instance.authHeaders,);
    
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
     headers: SessionService.instance.authHeaders,);
    
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
     headers: SessionService.instance.authHeaders,);
    
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
     headers: SessionService.instance.authHeaders,);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  } catch (e) {
    print('❌ Error getting comparison: $e');
    return null;
  }
}

  // ══════════════════════════════════════════
  // الحركات اليدوية بالأنواع الستة (Item 25)
  // ══════════════════════════════════════════
  static Future<Map<String, dynamic>> createManualOperation({
    required String operationType,
    required int cashBoxId,
    int? toCashBoxId,
    int? personalAccountId,
    required double amount,
    String? notes,
    String? recipient,
    DateTime? transactionDate,
    required String createdBy,
  }) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/api/cashbox/manual'),
        headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'operationType': operationType,
          'cashBoxId': cashBoxId,
          'toCashBoxId': toCashBoxId,
          'personalAccountId': personalAccountId,
          'amount': amount,
          'notes': notes ?? '',
          'recipient': recipient,
          'transactionDate': (transactionDate ?? DateTime.now()).toIso8601String(),
          'createdBy': createdBy,
        }),
      );
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map) return Map<String, dynamic>.from(body);
    }
    _throwFor(response, 'فشل تنفيذ العملية اليدوية');
  }

  // الحسابات الشخصية (لعمليات القروض اليدوية)
  static Future<List<Map<String, dynamic>>> getPersonalAccounts() async {
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl/api/personal-accounts?limit=200'),
        headers: SessionService.instance.authHeaders,
      );
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;
      final rows = data is Map ? data['data'] : null;
      if (rows is List) {
        return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }
    _throwFor(response, 'فشل تحميل الحسابات الشخصية');
  }

  // ══════════════════════════════════════════
  // مراجعة الخزينة (Item 27)
  // ══════════════════════════════════════════
  static Future<Map<String, dynamic>> getReview({
    required int cashboxId,
    required DateTime from,
    required DateTime to,
  }) async {
    final query = 'cashboxId=$cashboxId'
        '&from=${from.toIso8601String().substring(0, 10)}'
        '&to=${to.toIso8601String().substring(0, 10)}';
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl/api/cashbox/review?$query'),
        headers: SessionService.instance.authHeaders,
      );
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map && body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
    }
    _throwFor(response, 'فشل تحميل مراجعة الخزينة');
  }

  static Future<Map<String, dynamic>> stampReview({
    required int cashboxId,
    required DateTime from,
    required DateTime to,
    String? note,
  }) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/api/cashbox/review/stamp'),
        headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'cashboxId': cashboxId,
          'from': from.toIso8601String().substring(0, 10),
          'to': to.toIso8601String().substring(0, 10),
          'note': note,
        }),
      );
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map) return Map<String, dynamic>.from(body);
    }
    _throwFor(response, 'فشل حفظ ختم المراجعة');
  }

  static Future<List<Map<String, dynamic>>> getRecentStamps() async {
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl/api/cashbox/review/recent'),
        headers: SessionService.instance.authHeaders,
      );
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'فشل الاتصال بالخادم: $e');
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;
      final items = data is Map ? data['Items'] : null;
      if (items is List) {
        return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }
    _throwFor(response, 'فشل تحميل أختام المراجعة');
  }
}

/// نتيجة جلب حركات الخزينة (صفحة + إحصائيات)
class CashboxTransactionsResult {
  final List<Map<String, dynamic>> data;
  final Map<String, dynamic> stats;
  final int total;
  final int totalPages;
  final int page;

  const CashboxTransactionsResult({
    required this.data,
    required this.stats,
    required this.total,
    required this.totalPages,
    required this.page,
  });

  double get totalIn => (stats['TotalIn'] ?? 0).toDouble();
  double get totalOut => (stats['TotalOut'] ?? 0).toDouble();
  double get net => (stats['Net'] ?? totalIn - totalOut).toDouble();
}