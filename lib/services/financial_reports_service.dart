import '../core/network/api_client.dart';

/// خدمة التقارير المالية — تقابل في بلازور:
/// FinancialReportsService (قائمة الدخل/الميزانية)، CashFlowService (التدفقات)،
/// FinancialDashboardService (اللوحة المالية). الخادم يفرض بوابة
/// reports.canViewFinancialStatements على كل المسارات.
class FinancialReportsService {
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

  Map<String, dynamic> _query(DateTime from, DateTime to, int? branchId,
      {int? cashBoxId}) {
    return {
      'from': _date(from),
      'to': _date(to),
      if (branchId != null) 'branchId': branchId,
      if (cashBoxId != null) 'cashBoxId': cashBoxId,
    };
  }

  Future<Map<String, dynamic>> _get(
      String path, Map<String, dynamic> query) async {
    final response = await _api.get(path, forceRefresh: true, query: query);
    return _map(_map(_api.decode(response))['data']);
  }

  Future<Map<String, dynamic>> getDashboard(
      DateTime from, DateTime to, int? branchId) async {
    final data = await _get(
        '/api/reports/financial-dashboard', _query(from, to, branchId));
    data['MainKpis'] = _list(data['MainKpis']);
    data['Last12Months'] = _list(data['Last12Months']);
    data['TopProducts'] = _list(data['TopProducts']);
    data['TopCustomers'] = _list(data['TopCustomers']);
    data['TopExpenseCategories'] = _list(data['TopExpenseCategories']);
    data['Alerts'] = _list(data['Alerts']);
    data['StrategicRecommendations'] =
        _list(data['StrategicRecommendations']);
    final health = _map(data['HealthScore']);
    health['Factors'] = _list(health['Factors']);
    data['HealthScore'] = health;
    return data;
  }

  Future<Map<String, dynamic>> getIncomeStatement(
      DateTime from, DateTime to, int? branchId) async {
    final data = await _get(
        '/api/reports/income-statement', _query(from, to, branchId));
    data['ExpensesByGroup'] = _list(data['ExpensesByGroup']);
    data['OtherRevenueByType'] = _list(data['OtherRevenueByType']);
    data['TopExpenses'] = _list(data['TopExpenses']);
    data['MonthlyTrend'] = _list(data['MonthlyTrend']);
    data['Recommendations'] = _list(data['Recommendations']);
    return data;
  }

  Future<Map<String, dynamic>> getBalanceSheet(
      DateTime from, DateTime to, int? branchId) {
    return _get('/api/reports/balance-sheet', _query(from, to, branchId));
  }

  Future<Map<String, dynamic>> getCashFlow(DateTime from, DateTime to,
      int? branchId, {int? cashBoxId}) async {
    final data = await _get('/api/reports/cash-flow',
        _query(from, to, branchId, cashBoxId: cashBoxId));
    data['Inflows'] = _list(data['Inflows']);
    data['Outflows'] = _list(data['Outflows']);
    data['ByCashBox'] = _list(data['ByCashBox']);
    data['MonthlyTrend'] = _list(data['MonthlyTrend']);
    data['DailyTrend'] = _list(data['DailyTrend']);
    data['TopInflows'] = _list(data['TopInflows']);
    data['TopOutflows'] = _list(data['TopOutflows']);
    data['Alerts'] = _list(data['Alerts']);
    return data;
  }

  /// الفروع من GET /api/inventory/branches (قائمة مباشرة بلا غلاف data)
  Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final response = await _api.get('/api/inventory/branches');
      final decoded = _api.decode(response);
      final list = decoded is List ? decoded : _list(_map(decoded)['data']);
      return list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
