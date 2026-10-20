import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

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
    final response = await http.get(_uri('/api/inventory/branches'));
    return _decodeList(response);
  }

  static Future<List<dynamic>> getWarehouses({int? branchId}) async {
    final response = await http.get(
      _uri('/api/inventory/warehouses/active', {'branchId': branchId}),
    );
    return _decodeList(response);
  }

  static Future<List<dynamic>> getAllWarehouses() async {
    final response = await http.get(_uri('/api/inventory/warehouses'));
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
    );
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
    );
    return _decodeList(response);
  }

  static Future<List<dynamic>> getProductStock(int productId) async {
    final response = await http.get(
      _uri('/api/inventory/stock/product/$productId'),
    );
    return _decodeList(response);
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
    );
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
