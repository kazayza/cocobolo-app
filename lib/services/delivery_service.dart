import '../core/network/api_client.dart';

class DeliveryService {
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

  Future<Map<String, dynamic>> getDeliveries({
    String status = 'all',
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    String dateFilterType = 'due',
    String debt = 'all',
    int page = 1,
    int limit = 30,
  }) async {
    final listResponse =
        await _api.get('/api/delivery/list', forceRefresh: true, query: {
      'status': status,
      'search': search,
      'dateFrom': dateFrom?.toIso8601String(),
      'dateTo': dateTo?.toIso8601String(),
      'dateFilterType': dateFilterType,
      'debt': debt,
      'page': page,
      'limit': limit,
    });
    final statsResponse =
        await _api.get('/api/delivery/stats', forceRefresh: true, query: {
      'search': search,
      'dateFrom': dateFrom?.toIso8601String(),
      'dateTo': dateTo?.toIso8601String(),
      'dateFilterType': dateFilterType,
      'debt': debt,
    });
    final listData = _map(_map(_api.decode(listResponse))['data']);
    final statsData = _map(_map(_api.decode(statsResponse))['data']);
    return {
      ...listData,
      'rows': _list(listData['rows']),
      'stats': _map(statsData['stats']),
      'capabilities': _map(
        listData['capabilities'] ?? statsData['capabilities'],
      ),
    };
  }

  Future<Map<String, dynamic>> getDelivery(int id) async {
    final response = await _api.get('/api/delivery/$id', forceRefresh: true);
    return _map(_map(_api.decode(response))['data']);
  }

  Future<List<Map<String, dynamic>>> getEmployees() async {
    final response =
        await _api.get('/api/delivery/employees', forceRefresh: true);
    return _list(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> confirmDelivery({
    required int id,
    int? deliveryEmployeeId,
    String? deliveryEmployeeName,
    String? notes,
  }) async {
    final response = await _api.put('/api/delivery/$id/deliver', body: {
      'deliveryEmployeeId': deliveryEmployeeId,
      'deliveryEmployeeName': deliveryEmployeeName,
      'deliveredNotes': notes,
    });
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> updateDelivery({
    required int id,
    required String status,
    int? deliveryEmployeeId,
    String? deliveryEmployeeName,
    String? notes,
  }) async {
    final response = await _api.put('/api/delivery/$id', body: {
      'status': status,
      'deliveryEmployeeId': deliveryEmployeeId,
      'deliveryEmployeeName': deliveryEmployeeName,
      'notes': notes,
    });
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> requestPermission(int id) async {
    final response = await _api.post('/api/delivery/$id/request-permission');
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> grantPermission(int id) async {
    final response = await _api.post('/api/delivery/$id/grant-permission');
    return _map(_api.decode(response));
  }

  Future<List<Map<String, dynamic>>> getDailySheet({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
  }) async {
    final response =
        await _api.get('/api/delivery/daily-sheet', forceRefresh: true, query: {
      'dateFrom': dateFrom?.toIso8601String(),
      'dateTo': dateTo?.toIso8601String(),
      'search': search,
    });
    return _list(_map(_api.decode(response))['data']);
  }
}
