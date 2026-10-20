import '../core/network/api_client.dart';

class InvoiceService {
  InvoiceService._();
  static final InvoiceService instance = InvoiceService._();
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> getFull(int transactionId) async {
    final response = await _api.get('/api/transactions/$transactionId/full');
    final decoded = _api.decode(response);
    return Map<String, dynamic>.from((decoded['data'] ?? decoded) as Map);
  }

  Future<Map<String, dynamic>> getEditModel(int transactionId) async {
    final response = await _api.get('/api/transactions/$transactionId/edit-model');
    final decoded = _api.decode(response);
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  Future<Map<String, dynamic>> fullEdit(
    int transactionId,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.put(
      '/api/transactions/$transactionId/full-edit',
      body: body,
    );
    return Map<String, dynamic>.from(_api.decode(response) as Map);
  }

  Future<void> limitedEdit(
    int transactionId,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.put(
      '/api/transactions/$transactionId',
      body: body,
    );
    _api.decode(response);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _api.post('/api/transactions', body: body);
    return Map<String, dynamic>.from(_api.decode(response) as Map);
  }

  Future<Map<String, dynamic>> list({
    required String type,
    Map<String, dynamic>? filters,
  }) async {
    final response = await _api.get(
      '/api/transactions',
      query: {'type': type, ...?filters},
    );
    return Map<String, dynamic>.from(_api.decode(response) as Map);
  }

  Future<void> requestEdit(int transactionId, String reason) async {
    final response = await _api.post(
      '/api/transactions/$transactionId/request-edit',
      body: {'reason': reason},
    );
    _api.decode(response);
  }

  Future<void> approveEdit(
    int transactionId, {
    String? notes,
  }) async {
    final response = await _api.post(
      '/api/transactions/$transactionId/approve-edit',
      body: {'notes': notes},
    );
    _api.decode(response);
  }

  Future<void> rejectEdit(int transactionId, String reason) async {
    final response = await _api.post(
      '/api/transactions/$transactionId/reject-edit',
      body: {'reason': reason},
    );
    _api.decode(response);
  }

  Future<void> applyEdit(
    int transactionId,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.put(
      '/api/transactions/$transactionId/apply-edit',
      body: body,
    );
    _api.decode(response);
  }

  Future<void> updateDetailPrice(
    int transactionId,
    int detailId,
    double newUnitPrice, {
    required String reason,
  }) async {
    final response = await _api.put(
      '/api/transactions/$transactionId/details/$detailId/price',
      body: {
        'newUnitPrice': newUnitPrice,
        'changeReason': reason,
      },
    );
    _api.decode(response);
  }

  Future<Map<String, dynamic>> getEditHistory(int transactionId) async {
    final response = await _api.get(
      '/api/transactions/$transactionId/edit-history',
    );
    final decoded = _api.decode(response);
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  Future<void> restoreSnapshot(
    int transactionId,
    int auditId, {
    required String reason,
  }) async {
    final response = await _api.post(
      '/api/transactions/$transactionId/restore/$auditId',
      body: {'reason': reason},
    );
    _api.decode(response);
  }

  Future<void> syncMirror(int mirrorTransactionId) async {
    final response = await _api.post(
      '/api/transactions/mirror/$mirrorTransactionId/sync',
    );
    _api.decode(response);
  }
}
