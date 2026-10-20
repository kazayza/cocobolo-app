import '../core/network/api_client.dart';

class PriceListService {
  final ApiClient _api = ApiClient.instance;

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return List<dynamic>.from(value);
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> getPriceList({int? branchId}) async {
    final response = await _api.get(
      '/api/pricing/price-list',
      query: <String, dynamic>{'branchId': branchId},
    );
    final decoded = _asMap(_api.decode(response));
    return _asMap(decoded['data']);
  }

  Future<List<dynamic>> getHistory(int productId, {int take = 15}) async {
    final response = await _api.get(
      '/api/pricing/price-list/$productId/history',
      query: <String, dynamic>{'take': take},
    );
    final decoded = _asMap(_api.decode(response));
    return _asList(decoded['data']);
  }

  Future<List<int>> getImageIds(int productId) async {
    final response = await _api.get(
      '/api/pricing/price-list/$productId/images',
    );
    final decoded = _asMap(_api.decode(response));
    return _asList(decoded['data'])
        .map((dynamic value) =>
            value is int ? value : int.tryParse(value.toString()) ?? 0)
        .where((int value) => value > 0)
        .toList();
  }

  Future<Map<String, dynamic>> updateSalePrice({
    required int productId,
    required String tier,
    required double newPrice,
    required String reason,
  }) async {
    final response = await _api.put(
      '/api/pricing/price-list/$productId/price',
      body: <String, dynamic>{
        'tier': tier,
        'newPrice': newPrice,
        'reason': reason,
      },
    );
    return _asMap(_api.decode(response));
  }

  Future<Map<String, dynamic>> updateCost({
    required int productId,
    required String tier,
    required double newCost,
    required String reason,
  }) async {
    final response = await _api.put(
      '/api/pricing/price-list/$productId/cost',
      body: <String, dynamic>{
        'tier': tier,
        'newCost': newCost,
        'reason': reason,
      },
    );
    return _asMap(_api.decode(response));
  }

  Future<Map<String, dynamic>> requestPriceChange({
    required int productId,
    required String tier,
    required double requestedPrice,
    required String reason,
  }) async {
    final response = await _api.post(
      '/api/pricing/price-list/$productId/request',
      body: <String, dynamic>{
        'tier': tier,
        'requestedPrice': requestedPrice,
        'reason': reason,
      },
    );
    return _asMap(_api.decode(response));
  }
}
