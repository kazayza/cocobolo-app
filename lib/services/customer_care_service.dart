import '../core/network/api_client.dart';

class CustomerCareService {
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

  Future<Map<String, dynamic>> getDashboard({
    int daysBack = 30,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool includeContacted = false,
  }) async {
    final response = await _api.get(
      '/api/customer-care/dashboard',
      forceRefresh: true,
      query: {
        'daysBack': daysBack,
        'dateFrom': dateFrom?.toIso8601String(),
        'dateTo': dateTo?.toIso8601String(),
        'includeContacted': includeContacted,
      },
    );
    final data = _map(_map(_api.decode(response))['data']);
    for (final key in <String>[
      'visits',
      'deliveries',
      'salesInvoices',
      'complaints',
      'callbacks',
    ]) {
      data[key] = _list(data[key]);
    }
    return data;
  }

  Future<Map<String, dynamic>> logOutcome(Map<String, dynamic> body) async {
    final response = await _api.post('/api/customer-care/log', body: body);
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> getHistory({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? kind,
    String? status,
    String? search,
    int? feedbackId,
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _api.get(
      '/api/customer-care/history',
      forceRefresh: true,
      query: {
        'dateFrom': dateFrom?.toIso8601String(),
        'dateTo': dateTo?.toIso8601String(),
        'kind': kind,
        'status': status,
        'search': search,
        'feedbackId': feedbackId,
        'page': page,
        'limit': limit,
      },
    );
    final data = _map(_map(_api.decode(response))['data']);
    data['rows'] = _list(data['rows']);
    data['outcomeStats'] = _list(data['outcomeStats']);
    return data;
  }

  Future<Map<String, dynamic>> hide(int id) async {
    final response = await _api.delete('/api/customer-care/$id');
    return _map(_api.decode(response));
  }

  Future<List<Map<String, dynamic>>> getExportRows({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? kind,
    String? status,
    String? search,
  }) async {
    final response = await _api.get(
      '/api/customer-care/export',
      forceRefresh: true,
      query: {
        'dateFrom': dateFrom?.toIso8601String(),
        'dateTo': dateTo?.toIso8601String(),
        'kind': kind,
        'status': status,
        'search': search,
      },
    );
    final data = _map(_map(_api.decode(response))['data']);
    return _list(data['rows']);
  }
}
