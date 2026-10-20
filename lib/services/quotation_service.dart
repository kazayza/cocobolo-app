import '../core/network/api_client.dart';

class QuotationService {
  final ApiClient _api = ApiClient.instance;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _list(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> getQuotations({
    String? search,
    String? status,
    bool? converted,
    bool? pendingOnly,
    bool? expired,
    int? employeeId,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 25,
  }) async {
    final response = await _api.get(
      '/api/quotations',
      query: <String, dynamic>{
        'search': search,
        'status': status,
        'converted': converted,
        'pendingOnly': pendingOnly,
        'expired': expired,
        'employeeId': employeeId,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'page': page,
        'limit': limit,
      },
    );
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> getQuotation(int id) async {
    final response = await _api.get('/api/quotations/$id');
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> getLookups({
    int? partyId,
    String search = '',
  }) async {
    final response = await _api.get(
      '/api/quotations/lookups/form',
      query: <String, dynamic>{'partyId': partyId, 'search': search},
    );
    return _map(_map(_api.decode(response))['data']);
  }

  Future<List<dynamic>> getProducts({
    required int partyId,
    int? warehouseId,
    String search = '',
  }) async {
    final response = await _api.get(
      '/api/quotations/lookups/products',
      query: <String, dynamic>{
        'partyId': partyId,
        'warehouseId': warehouseId,
        'search': search,
      },
    );
    return _list(_map(_api.decode(response))['data']);
  }

  Future<List<dynamic>> getAlternatives(int productId) async {
    final response = await _api.get(
      '/api/quotations/products/$productId/alternatives',
    );
    return _list(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _api.post('/api/quotations', body: body);
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> update(
    int id,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.put('/api/quotations/$id', body: body);
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> changeStatus({
    required int id,
    required String status,
    String? reason,
  }) async {
    final response = await _api.put(
      '/api/quotations/$id/status',
      body: <String, dynamic>{'status': status, 'reason': reason},
    );
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> delete(int id) async {
    final response = await _api.delete('/api/quotations/$id');
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> saveCosts({
    required int id,
    required List<Map<String, dynamic>> updates,
  }) async {
    final response = await _api.put(
      '/api/quotations/$id/costs',
      body: <String, dynamic>{'updates': updates},
    );
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> requestPricing({
    required int id,
    String? note,
  }) async {
    final response = await _api.post(
      '/api/quotations/$id/request-pricing',
      body: <String, dynamic>{'note': note},
    );
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> requestDiscount({
    required int id,
    required double discountAmount,
    required String reason,
  }) async {
    final response = await _api.post(
      '/api/quotations/$id/request-discount',
      body: <String, dynamic>{
        'discountAmount': discountAmount,
        'reason': reason,
      },
    );
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> convertToInvoice({
    required int id,
    required DateTime invoiceDate,
    int? warehouseId,
    List<int> selectedAdvanceChargeIds = const <int>[],
  }) async {
    final response = await _api.post(
      '/api/quotations/$id/convert',
      body: <String, dynamic>{
        'invoiceDate': invoiceDate.toIso8601String(),
        'warehouseId': warehouseId,
        'selectedAdvanceChargeIds': selectedAdvanceChargeIds,
      },
    );
    return _map(_api.decode(response));
  }
}
