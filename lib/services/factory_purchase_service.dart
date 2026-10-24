import '../core/network/api_client.dart';

class FactoryPurchaseService {
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
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getPurchases({
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    String receipt = 'all',
    bool overdue = false,
    int page = 1,
    int limit = 25,
  }) async {
    final response = await _api.get(
      '/api/factory-purchases',
      forceRefresh: true,
      query: {
        'search': search,
        'dateFrom': dateFrom?.toIso8601String(),
        'dateTo': dateTo?.toIso8601String(),
        'status': status,
        'receipt': receipt == 'all' ? null : receipt,
        'overdue': overdue ? true : null,
        'page': page,
        'limit': limit,
      },
    );
    final data = _map(_map(_api.decode(response))['data']);
    data['rows'] = _list(data['rows']);
    return data;
  }

  Future<Map<String, dynamic>> getLookups() async {
    final response = await _api.get(
      '/api/factory-purchases/lookups',
      forceRefresh: true,
    );
    final data = _map(_map(_api.decode(response))['data']);
    data['warehouses'] = _list(data['warehouses']);
    data['cashboxes'] = _list(data['cashboxes']);
    return data;
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String search) async {
    final response = await _api.get(
      '/api/factory-purchases/customers',
      forceRefresh: true,
      query: {'search': search},
    );
    return _list(_map(_api.decode(response))['data']);
  }

  Future<List<Map<String, dynamic>>> searchProducts(String search) async {
    final response = await _api.get(
      '/api/factory-purchases/products',
      forceRefresh: true,
      query: {'search': search, 'limit': 60},
    );
    return _list(_map(_api.decode(response))['data']);
  }

  Future<List<Map<String, dynamic>>> getAlternatives(int productId) async {
    final response = await _api.get(
      '/api/factory-purchases/products/$productId/alternatives',
      forceRefresh: true,
    );
    return _list(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _api.post('/api/factory-purchases', body: body);
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> receive(int id, {String? notes}) async {
    final response = await _api.post(
      '/api/factory-purchases/$id/receive',
      body: {'notes': notes},
    );
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> cancel(int id, {required String reason}) async {
    final response = await _api.post(
      '/api/factory-purchases/$id/cancel',
      body: {'reason': reason},
    );
    return _map(_api.decode(response));
  }
}
