import '../core/network/api_client.dart';

class PurchaseReceiptService {
  final ApiClient _api = ApiClient.instance;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> getReceipts({
    String? search,
    String status = 'all',
    DateTime? dateFrom,
    DateTime? dateTo,
    String dateFilterType = 'DueDate',
    int page = 1,
    int limit = 30,
  }) async {
    final response =
        await _api.get('/api/purchase-receipts', forceRefresh: true, query: {
      'search': search,
      'status': status == 'all' ? null : status,
      'dateFrom': dateFrom?.toIso8601String(),
      'dateTo': dateTo?.toIso8601String(),
      'dateFilterType': dateFilterType,
      'page': page,
      'limit': limit,
    });
    final data = _map(_map(_api.decode(response))['data']);
    data['rows'] = _list(data['rows']);
    return data;
  }

  Future<Map<String, dynamic>> getReceipt(int id) async {
    final response =
        await _api.get('/api/purchase-receipts/$id', forceRefresh: true);
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> confirmReceipt({
    required int id,
    String? notes,
  }) async {
    final response = await _api.post(
      '/api/purchase-receipts/$id/receive',
      body: {'notes': notes},
    );
    return _map(_api.decode(response));
  }
}
