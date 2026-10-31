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

  /// مواعيد قسم «التسليمات القادمة — 10 أيام» في الرئيسية:
  /// { appointments (بسقف 12), total, windowDays } — التواريخ بصيغة
  /// عرض المستخدم الحالي (حقيقية أو مقنّعة) من الخادم نفسه.
  Future<Map<String, dynamic>> getHomeUpcoming() async {
    final response =
        await _api.get('/api/delivery/home-upcoming', forceRefresh: true);
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

  // Item 1/3 (Pkg1): record delivery event with per-line dispositions.
  // POST /api/delivery/:id/events — each item mirrors API normalizeRecordItem:
  // transactionDetailId, quantity (batch qty), acceptedQty,
  // returnedManufacturingQty, returnedHandlingQty, returnedModificationQty,
  // dispositionNotes, agreedModificationPrice, maintenanceId.
  Future<Map<String, dynamic>> recordEvent({
    required int id,
    required List<Map<String, dynamic>> items,
    int? deliveryEmployeeId,
    String? deliveryEmployeeName,
    String? notes,
    DateTime? deliveryDate,
    String? eventGuid,
  }) async {
    final response = await _api.post('/api/delivery/$id/events', body: {
      'items': items,
      'deliveryEmployeeId': deliveryEmployeeId,
      'deliveryEmployeeName': deliveryEmployeeName,
      'notes': notes,
      'deliveryDate': deliveryDate?.toIso8601String(),
      'eventGuid': eventGuid,
    });
    return _map(_api.decode(response));
  }

  // Item 3 (Pkg1): batch coverage preview.
  // POST /api/delivery/:id/events/coverage — figures are null from the
  // server for users without amount permission.
  Future<Map<String, dynamic>> getCoverage({
    required int id,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _api.post('/api/delivery/$id/events/coverage',
        body: {'items': items});
    return _map(_map(_api.decode(response))['data']);
  }

  // Item 2 (Pkg1): void a delivery event (Admin/AccountManager only,
  // mandatory reason) — POST /api/delivery/:id/events/:deliveryId/void
  Future<Map<String, dynamic>> voidEvent({
    required int id,
    required int deliveryId,
    required String reason,
  }) async {
    final response = await _api.post(
        '/api/delivery/$id/events/$deliveryId/void',
        body: {'reason': reason});
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> getEvents(int id) async {
    final response =
        await _api.get('/api/delivery/$id/events', forceRefresh: true);
    return _map(_map(_api.decode(response))['data']);
  }

  // Item 5 (Pkg2): delivery maintenance queue + transitions.
  Future<Map<String, dynamic>> getMaintenanceQueue({
    String? status,
    String? reasonClass,
    String? search,
    bool includeTerminal = false,
  }) async {
    final response = await _api.get('/api/delivery/maintenance/queue',
        forceRefresh: true,
        query: {
          'status': status,
          'reasonClass': reasonClass,
          'search': search,
          'includeTerminal': includeTerminal,
        });
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> maintenanceAction(
      int maintenanceId, String action,
      {Map<String, dynamic> body = const {}}) async {
    final response = await _api
        .post('/api/delivery/maintenance/$maintenanceId/$action', body: body);
    return _map(_api.decode(response));
  }

  // Item 6 (Pkg2): schedule-change requests.
  Future<Map<String, dynamic>> getScheduleRequests(int id) async {
    final response = await _api.get('/api/delivery/$id/schedule-change-requests',
        forceRefresh: true);
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> createScheduleRequest({
    required int id,
    required String reason,
    DateTime? proposedDueDate,
    List<Map<String, dynamic>> lines = const [],
  }) async {
    final response =
        await _api.post('/api/delivery/$id/schedule-change-requests', body: {
      'reason': reason,
      'proposedDueDate': proposedDueDate?.toIso8601String(),
      'lines': lines,
    });
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> withdrawScheduleRequest(int requestId) async {
    final response = await _api
        .post('/api/delivery/schedule-change-requests/$requestId/withdraw');
    return _map(_api.decode(response));
  }

  Future<Map<String, dynamic>> getScheduleApproval(int requestId) async {
    final response = await _api.get(
        '/api/delivery/schedule-change-requests/$requestId/approval',
        forceRefresh: true);
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> decideScheduleRequest({
    required int requestId,
    required bool approve,
    DateTime? finalDueDate,
    List<Map<String, dynamic>> finalLines = const [],
    String? note,
  }) async {
    final response = await _api.post(
        '/api/delivery/schedule-change-requests/$requestId/decide',
        body: {
          'approve': approve,
          'finalDueDate': finalDueDate?.toIso8601String(),
          'finalLines': finalLines,
          'note': note,
        });
    return _map(_api.decode(response));
  }
}
