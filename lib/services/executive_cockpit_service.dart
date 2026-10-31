import '../core/network/api_client.dart';

/// خدمة لوحة القيادة التنفيذية — تقابل ExecutiveCockpitService في بلازور.
/// الفترة المخصصة والفرع يُمرَّران كما يدعمهما الخادم (ComputeRanges/BranchScope)،
/// واللقطات من dbo.ExecutiveCockpitSnapshots (Available=false حتى يُشغَّل سكربت الجدول).
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

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    data['Trend'] = _list(data['Trend']);
    data['Employees'] = _list(data['Employees']);
    data['BranchSales'] = _list(data['BranchSales']);
    data['BranchIgnoredSections'] =
        (data['BranchIgnoredSections'] is List)
            ? (data['BranchIgnoredSections'] as List).map((e) => '$e').toList()
            : <String>[];
    data['FailedSections'] = (data['FailedSections'] is List)
        ? (data['FailedSections'] as List).map((e) => '$e').toList()
        : <String>[];
    final gm = _map(data['Gm']);
    gm['Recent'] = _list(gm['Recent']);
    data['Gm'] = gm;
    final aging = _map(data['Aging']);
    aging['Receivables'] = _list(aging['Receivables']);
    aging['Payables'] = _list(aging['Payables']);
    aging['TopDebtors'] = _list(aging['TopDebtors']);
    data['Aging'] = aging;
    data['MiniPl'] = _map(data['MiniPl']);
    final quotations = _map(data['Quotations']);
    quotations['ByStatus'] = _list(quotations['ByStatus']);
    data['Quotations'] = quotations;
    final inventory = _map(data['Inventory']);
    inventory['TopValueProducts'] = _list(inventory['TopValueProducts']);
    inventory['Warehouses'] = _list(inventory['Warehouses']);
    data['Inventory'] = inventory;
    data['JobOrders'] = _map(data['JobOrders']);
    data['Deliveries'] = _map(data['Deliveries']);
    data['Marketing'] = _map(data['Marketing']);
    data['B2bBlock'] = _map(data['B2bBlock']);
    data['Hr'] = _map(data['Hr']);
    return data;
  }

  Future<Map<String, dynamic>> getCockpit({
    String period = 'month',
    int? branchId,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _api.get(
      '/api/executive-cockpit',
      forceRefresh: true,
      query: {
        'period': period,
        if (branchId != null) 'branchId': branchId,
        if (period == 'custom' && from != null) 'from': _date(from),
        if (period == 'custom' && to != null) 'to': _date(to),
      },
    );
    return _normalize(_map(_map(_api.decode(response))['data']));
  }

  /// الفروع من GET /api/inventory/branches (قائمة مباشرة بلا غلاف data)
  Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final response = await _api.get('/api/inventory/branches');
      final decoded = _api.decode(response);
      final list = decoded is List
          ? decoded
          : _list(_map(decoded)['data']);
      return list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> getEmployeeTimeline(int employeeId) async {
    final response = await _api.get(
      '/api/executive-cockpit/employees/$employeeId/timeline',
      forceRefresh: true,
    );
    final data = _map(_map(_api.decode(response))['data']);
    return _list(data['rows']);
  }

  /// قائمة اللقطات — Available=false عندما لم يُنشأ جدول اللقطات بعد
  Future<Map<String, dynamic>> listSnapshots() async {
    final response = await _api.get(
      '/api/executive-cockpit/snapshots',
      forceRefresh: true,
    );
    final data = _map(_map(_api.decode(response))['data']);
    data['Items'] = _list(data['Items']);
    return data;
  }

  Future<Map<String, dynamic>> getSnapshot(int snapshotId) async {
    final response = await _api.get(
      '/api/executive-cockpit/snapshots/$snapshotId',
      forceRefresh: true,
    );
    final data = _map(_map(_api.decode(response))['data']);
    final meta = _map(data['Meta']);
    final payload = _normalize(_map(data['Data']));
    return {'Meta': meta, 'Data': payload};
  }

  /// حفظ لقطة بالإعدادات الحالية (فترة/فرع) — يرمي خطأ 409 عند غياب الجدول
  Future<void> saveSnapshot({
    required String period,
    int? branchId,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _api.post(
      '/api/executive-cockpit/snapshots',
      body: {
        'period': period,
        if (branchId != null) 'branchId': branchId,
        if (period == 'custom' && from != null) 'from': _date(from),
        if (period == 'custom' && to != null) 'to': _date(to),
      },
    );
    _api.decode(response);
  }
}
