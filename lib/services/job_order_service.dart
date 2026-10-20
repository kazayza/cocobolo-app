import '../core/network/api_client.dart';

class JobOrderService {
  final ApiClient _api = ApiClient.instance;

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getJobOrders({
    String? search,
    String delivery = 'undelivered',
    String type = 'all',
    String due = 'all',
    DateTime? dueFrom,
    DateTime? dueTo,
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _api.get(
      '/api/job-orders',
      query: <String, dynamic>{
        'search': search,
        'delivery': delivery,
        'type': type,
        'due': due,
        'dueFrom': dueFrom?.toIso8601String(),
        'dueTo': dueTo?.toIso8601String(),
        'page': page,
        'limit': limit,
      },
    );
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> getJobOrder(int id) async {
    final response = await _api.get('/api/job-orders/$id');
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> updateDueDate({
    required int id,
    DateTime? dueDate,
    String? notes,
  }) async {
    final response = await _api.put(
      '/api/job-orders/$id/due-date',
      body: <String, dynamic>{
        'dueDate': dueDate?.toIso8601String(),
        'notes': notes,
      },
    );
    return _map(_api.decode(response));
  }
}
