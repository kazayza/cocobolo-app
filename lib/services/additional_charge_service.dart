import '../core/network/api_client.dart';

class AdditionalChargeService {
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

  Future<Map<String, dynamic>> getCharges({
    String? search,
    String? type,
    bool advanceLike = false,
    String? status,
    int? partyId,
    bool unappliedOnly = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 25,
  }) async {
    final response =
        await _api.get('/api/additional-charges', forceRefresh: true, query: {
      'search': search,
      'type': type,
      'advanceLike': advanceLike ? true : null,
      'status': status,
      'partyId': partyId,
      'unappliedOnly': unappliedOnly ? true : null,
      'dateFrom': dateFrom?.toIso8601String(),
      'dateTo': dateTo?.toIso8601String(),
      'page': page,
      'limit': limit,
    });
    final data = _map(_map(_api.decode(response))['data']);
    data['rows'] = _list(data['rows']);
    return data;
  }

  Future<Map<String, dynamic>> getCharge(int id) async {
    final response =
        await _api.get('/api/additional-charges/$id', forceRefresh: true);
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> getReceipt(int id) async {
    final response = await _api.get('/api/additional-charges/$id/receipt',
        forceRefresh: true);
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> getLookups({
    String search = '',
    int? partyId,
    String invoiceSearch = '',
  }) async {
    final response = await _api.get('/api/additional-charges/lookups/form',
        forceRefresh: true,
        query: {
          'search': search,
          'partyId': partyId,
          'invoiceSearch': invoiceSearch,
        });
    final data = _map(_map(_api.decode(response))['data']);
    data['parties'] = _list(data['parties']);
    data['cashboxes'] = _list(data['cashboxes']);
    data['invoices'] = _list(data['invoices']);
    return data;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _api.post('/api/additional-charges', body: body);
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> update(
    int id,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.put('/api/additional-charges/$id', body: body);
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> delete(int id) async {
    final response = await _api.delete('/api/additional-charges/$id');
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> applyToInvoice({
    required int id,
    required int transactionId,
  }) async {
    final response = await _api.post(
      '/api/additional-charges/$id/apply',
      body: {'transactionId': transactionId},
    );
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> markNonRefundable({
    required int id,
    required String reason,
  }) async {
    final response = await _api.post(
      '/api/additional-charges/$id/non-refundable',
      body: {'reason': reason},
    );
    return _map(_api.decode(response));
  }
}
