import '../core/network/api_client.dart';

class ExecutiveCockpitService {
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

  Future<Map<String, dynamic>> getCockpit({String period = 'month'}) async {
    final response = await _api.get(
      '/api/executive-cockpit',
      forceRefresh: true,
      query: {'period': period},
    );
    final data = _map(_map(_api.decode(response))['data']);
    data['Trend'] = _list(data['Trend']);
    data['Employees'] = _list(data['Employees']);
    data['BranchSales'] = _list(data['BranchSales']);
    final gm = _map(data['Gm']);
    gm['Recent'] = _list(gm['Recent']);
    data['Gm'] = gm;
    return data;
  }

  Future<List<Map<String, dynamic>>> getEmployeeTimeline(int employeeId) async {
    final response = await _api.get(
      '/api/executive-cockpit/employees/$employeeId/timeline',
      forceRefresh: true,
    );
    final data = _map(_map(_api.decode(response))['data']);
    return _list(data['rows']);
  }
}
