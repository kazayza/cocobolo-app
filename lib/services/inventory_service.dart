import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../core/auth/session_service.dart';

class InventoryApiException implements Exception {
  final String message;
  final int? statusCode;

  const InventoryApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// خدمة موحدة لقراءة بيانات المخازن والحركات.
class InventoryService {
  static List<dynamic> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'فشل تحميل البيانات (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          message = body['message'].toString();
        }
      } catch (_) {}
      throw InventoryApiException(message, statusCode: response.statusCode);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
    if (decoded is Map) {
      final value = decoded['data'] ?? decoded['items'] ?? decoded['rows'];
      if (value is List) return value;
    }
    return const [];
  }

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null) return uri;
    final clean = <String, String>{};
    query.forEach((key, value) {
      if (value != null && value.toString().trim().isNotEmpty) {
        clean[key] = value.toString();
      }
    });
    return uri.replace(queryParameters: clean);
  }

  static Future<List<dynamic>> getBranches() async {
    final response = await http.get(_uri('/api/inventory/branches'), headers: SessionService.instance.authHeaders);
    return _decodeList(response);
  }

  static Future<List<dynamic>> getWarehouses({int? branchId}) async {
    final response = await http.get(
      _uri('/api/inventory/warehouses/active', {'branchId': branchId}),
     headers: SessionService.instance.authHeaders,);
    return _decodeList(response);
  }

  static Future<List<dynamic>> getAllWarehouses() async {
    final response = await http.get(_uri('/api/inventory/warehouses'), headers: SessionService.instance.authHeaders);
    return _decodeList(response);
  }

  static Future<List<dynamic>> getStockLevels({
    int? warehouseId,
    int? branchId,
    String? search,
  }) async {
    final response = await http.get(
      _uri('/api/inventory/stock', {
        'warehouseId': warehouseId,
        'branchId': branchId,
        'search': search,
      }),
     headers: SessionService.instance.authHeaders,);
    return _decodeList(response);
  }

  static Future<List<dynamic>> getTransactions({
    int? productId,
    int? warehouseId,
    int? branchId,
    String? referenceType,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    final response = await http.get(
      _uri('/api/inventory/transactions', {
        'productId': productId,
        'warehouseId': warehouseId,
        'branchId': branchId,
        'referenceType': referenceType,
        'search': search,
        'startDate': startDate,
        'endDate': endDate,
      }),
     headers: SessionService.instance.authHeaders,);
    return _decodeList(response);
  }

  static Future<List<dynamic>> getProductStock(int productId) async {
    final response = await http.get(
      _uri('/api/inventory/stock/product/$productId'),
     headers: SessionService.instance.authHeaders,);
    return _decodeList(response);
  }

  static Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'فشل تنفيذ الطلب (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          message = body['message'].toString();
        }
      } catch (_) {}
      throw InventoryApiException(message, statusCode: response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      return decoded;
    }
    throw const InventoryApiException('استجابة غير متوقعة من الخادم');
  }

  /// مساحة عمل الجرد: بنود المخزن الحالية (أو بنود مستند قائم).
  static Future<Map<String, dynamic>> getStockCountWorkspace({
    int? warehouseId,
    int? stockCountId,
  }) async {
    final response = await http.get(
      _uri('/api/inventory/stock-counts/workspace', {
        'warehouseId': warehouseId,
        'stockCountId': stockCountId,
      }),
      headers: SessionService.instance.authHeaders,
    );
    return _decodeMap(response);
  }

  /// قائمة مستندات الجرد السابقة.
  static Future<List<dynamic>> getStockCounts({
    int? branchId,
    int? warehouseId,
  }) async {
    final response = await http.get(
      _uri('/api/inventory/stock-counts', {
        'branchId': branchId,
        'warehouseId': warehouseId,
      }),
      headers: SessionService.instance.authHeaders,
    );
    return _decodeList(response);
  }

  /// حفظ مسودة جرد (إنشاء أو تحديث) — يرجع رقم مستند الجرد.
  static Future<int> saveStockCountDraft({
    int? stockCountId,
    required int branchId,
    required int warehouseId,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final response = await http.post(
      _uri('/api/inventory/stock-counts'),
      headers: {
        ...SessionService.instance.authHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'stockCountId': stockCountId,
        'branchId': branchId,
        'warehouseId': warehouseId,
        'notes': notes,
        'lines': lines,
      }),
    );
    final decoded = _decodeMap(response);
    final id = decoded['stockCountId'] ?? decoded['StockCountId'];
    final parsed = id is int ? id : int.tryParse('$id');
    if (parsed == null) {
      throw const InventoryApiException('لم يرجع الخادم رقم مستند الجرد');
    }
    return parsed;
  }

  /// اعتماد جرد وتنفيذ فروقه ذرّيًا في الخادم.
  static Future<void> finalizeStockCount(int stockCountId) async {
    final response = await http.post(
      _uri('/api/inventory/stock-counts/$stockCountId/finalize'),
      headers: SessionService.instance.authHeaders,
    );
    _decodeMap(response);
  }

  /// قيمة المخزون من الخادم (تكلفة وبيع حسب باقة السعر + ملخص).
  static Future<Map<String, dynamic>> getStockValue({
    int? branchId,
    int? warehouseId,
    String? priceTier,
  }) async {
    final response = await http.get(
      _uri('/api/inventory/stock-value', {
        'branchId': branchId,
        'warehouseId': warehouseId,
        'priceTier': priceTier,
      }),
      headers: SessionService.instance.authHeaders,
    );
    return _decodeMap(response);
  }

  static Future<int> getCurrentStock({
    required int productId,
    required int warehouseId,
  }) async {
    final response = await http.get(
      _uri('/api/inventory/current-stock', {
        'productId': productId,
        'warehouseId': warehouseId,
      }),
     headers: SessionService.instance.authHeaders,);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw InventoryApiException(
        'فشل تحميل الرصيد الحالي',
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body);
    return int.tryParse('${body['quantity'] ?? 0}') ?? 0;
  }
}
