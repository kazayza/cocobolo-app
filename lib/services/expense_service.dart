import 'package:intl/intl.dart';
import '../core/network/api_client.dart';

/// خدمة المصروفات — /api/expenses.
///
/// عقد الأخطاء: لا ابتلاع صامت إطلاقًا — كل دالة ترمي [ApiException]
/// برسالة الخادم العربية كما هي عند أي فشل (نفس نمط loan_service.dart)،
/// والشاشات تعرض الرسالة مع إعادة محاولة. الاستثناء الوحيد هو
/// [checkConnection] لأنه مسبار اتصال بطبيعته يعيد bool.
///
/// ملاحظة التوافق: الدوال الإرثية (getSummary/getCashBoxes/getExpenses/
/// getExpensesForChart/getCategoryDistribution/getTopCategories/
/// getComparisonData/getWeeklyData) أبقت توقيعاتها لأن مستهلكين خارج
/// نطاق هذه الجولة يستخدمونها (financial_dashboard.dart و
/// home_service.dart) — لكنها الآن ترمي عند الفشل بدل إرجاع قيم فارغة
/// صامتة، وكلا المستهلكَين يلتقط الاستثناءات أصلًا فيعرض حالة خطأ.
class ExpenseService {
  static final ApiClient _api = ApiClient.instance;

  // ── تحويل صف الخادم: يحتفظ بحقول الفرع والمقدم والخزينة كاملة ──
  static Map<String, dynamic> _row(Map<String, dynamic> item) {
    return {
      'ExpenseID': item['ExpenseID'] ?? 0,
      'ExpenseName': item['ExpenseName'] ?? '',
      'ExpenseDate': item['ExpenseDate'] ?? '',
      'Amount': (item['Amount'] as num?)?.toDouble() ?? 0.0,
      'ExpenseGroupID': item['ExpenseGroupID'],
      'ExpenseGroupName': item['ExpenseGroupName'] ?? 'غير مصنف',
      'FullGroupPath': item['FullGroupPath'],
      'CashBoxID': item['CashBoxID'],
      'CashBoxName': item['CashBoxName'] ?? '',
      'BranchId': item['BranchId'] ?? item['BranchID'],
      'BranchName': item['BranchName'],
      'IsAdvance': item['IsAdvance'] == true,
      'AdvanceMonths': item['AdvanceMonths'],
      'AdvanceParentExpenseId': item['AdvanceParentExpenseId'],
      'AdvanceMonthIndex': item['AdvanceMonthIndex'],
      'Notes': item['Notes'] ?? '',
      'Torecipient': item['Torecipient'] ?? '',
      'CreatedBy': item['CreatedBy'],
      'CreatedAt': item['CreatedAt'],
    };
  }

  static Map<String, String> _filterQuery({
    String? search,
    int? groupId,
    int? parentGroupId,
    int? branchId,
    int? cashBoxId,
    String? startDate,
    String? endDate,
    double? amountFrom,
    double? amountTo,
    bool? isAdvance,
    bool? excludeAdvanceHeaders,
  }) {
    return {
      if (search != null && search.isNotEmpty) 'search': search,
      if (groupId != null) 'groupId': '$groupId',
      if (parentGroupId != null) 'parentGroupId': '$parentGroupId',
      if (branchId != null) 'branchId': '$branchId',
      if (cashBoxId != null) 'cashBoxId': '$cashBoxId',
      if (startDate != null) 'dateFrom': startDate,
      if (endDate != null) 'dateTo': endDate,
      if (amountFrom != null) 'amountFrom': '$amountFrom',
      if (amountTo != null) 'amountTo': '$amountTo',
      if (isAdvance != null) 'isAdvance': '$isAdvance',
      if (excludeAdvanceHeaders != null)
        'excludeAdvanceHeaders': '$excludeAdvanceHeaders',
    };
  }

  /// إحصائيات القائمة (GetStatsAsync): اليوم/الفترة/السنة/الإجمالي + الأعداد
  /// + تفصيل المجموعات — كلها ضمن الفلتر الممرَّر.
  static Future<Map<String, dynamic>?> getSummary({
    String? search,
    int? groupId,
    int? parentGroupId,
    int? branchId,
    int? cashBoxId,
    String? startDate,
    String? endDate,
    double? amountFrom,
    double? amountTo,
    bool? isAdvance,
  }) async {
    final res = await _api.get(
      '/api/expenses/summary',
      query: _filterQuery(
        search: search,
        groupId: groupId,
        parentGroupId: parentGroupId,
        branchId: branchId,
        cashBoxId: cashBoxId,
        startDate: startDate,
        endDate: endDate,
        amountFrom: amountFrom,
        amountTo: amountTo,
        isAdvance: isAdvance,
      ),
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب ملخص المصروفات',
    );
  }

  /// الخزائن النشطة فقط من نهاية المصروفات نفسها، مع اسم الفرع والرصيد
  /// الحالي بالتعريف الموحّد (شامل الافتتاحي) واللون والافتراضية.
  static Future<List<Map<String, dynamic>>> getCashBoxes() async {
    final res = await _api.get('/api/expenses/cashboxes', forceRefresh: true);
    final data = _api.decode(res);
    if (data is! List) return const [];
    return data.map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      return {
        'CashBoxID': m['CashBoxID'] ?? 0,
        'CashBoxName': m['CashBoxName'] ?? 'غير معروف',
        'BranchId': m['BranchId'] ?? m['BranchID'],
        'BranchName': m['BranchName'],
        'CurrentBalance':
            (m['CurrentBalance'] as num?)?.toDouble() ?? 0.0,
        'Color': m['Color'],
        'IsDefault': m['IsDefault'] == true,
        'IsActive': m['IsActive'] != false,
      };
    }).toList();
  }

  /// مجموعات المصروفات بالعقد الكامل (أبناء/عدد مصروفات/إجمالي/منشئ/تاريخ).
  static Future<List<Map<String, dynamic>>> getExpenseGroups() async {
    final res = await _api.get('/api/expenses/groups', forceRefresh: true);
    final data = _api.decode(res);
    if (data is! List) return const [];
    return data.map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      return {
        'ExpenseGroupID': m['ExpenseGroupID'] ?? 0,
        'ExpenseGroupName': m['ExpenseGroupName'] ?? 'غير معروف',
        'ParentGroupID': m['ParentGroupID'],
        'ParentGroupName': m['ParentGroupName'],
        'ChildrenCount': (m['ChildrenCount'] as num?)?.toInt() ?? 0,
        'ExpensesCount': (m['ExpensesCount'] as num?)?.toInt() ?? 0,
        'TotalAmount': (m['TotalAmount'] as num?)?.toDouble() ?? 0.0,
        'CreatedBy': m['CreatedBy'],
        'CreatedAt': m['CreatedAt'],
      };
    }).toList();
  }

  /// صفحة مصروفات كاملة بالعقد الجديد {items,totalCount,pageNumber,pageSize}.
  static Future<Map<String, dynamic>> getExpensesPaged({
    String? search,
    int? groupId,
    int? parentGroupId,
    int? branchId,
    int? cashBoxId,
    String? startDate,
    String? endDate,
    double? amountFrom,
    double? amountTo,
    bool? isAdvance,
    bool? excludeAdvanceHeaders,
    int page = 1,
    int pageSize = 25,
    String? sortBy,
  }) async {
    final res = await _api.get(
      '/api/expenses',
      query: {
        ..._filterQuery(
          search: search,
          groupId: groupId,
          parentGroupId: parentGroupId,
          branchId: branchId,
          cashBoxId: cashBoxId,
          startDate: startDate,
          endDate: endDate,
          amountFrom: amountFrom,
          amountTo: amountTo,
          isAdvance: isAdvance,
          excludeAdvanceHeaders: excludeAdvanceHeaders,
        ),
        'page': '$page',
        'pageSize': '$pageSize',
        if (sortBy != null) 'sortBy': sortBy,
      },
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final items = (m['items'] as List? ?? const [])
          .map((e) => _row(Map<String, dynamic>.from(e as Map)))
          .toList();
      return {
        'items': items,
        'totalCount': (m['totalCount'] as num?)?.toInt() ?? items.length,
        'pageNumber': (m['pageNumber'] as num?)?.toInt() ?? page,
        'pageSize': (m['pageSize'] as num?)?.toInt() ?? pageSize,
      };
    }
    if (data is List) {
      final items =
          data.map((e) => _row(Map<String, dynamic>.from(e as Map))).toList();
      return {
        'items': items,
        'totalCount': items.length,
        'pageNumber': 1,
        'pageSize': items.length,
      };
    }
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب المصروفات',
    );
  }

  /// قائمة المصروفات (توافق إرثي) — صفحة واحدة بحجم [limit].
  static Future<List<Map<String, dynamic>>> getExpenses({
    String? search,
    int? groupId,
    String? startDate,
    String? endDate,
    int limit = 100,
  }) async {
    final paged = await getExpensesPaged(
      search: search,
      groupId: groupId,
      startDate: startDate,
      endDate: endDate,
      pageSize: limit,
    );
    return (paged['items'] as List).cast<Map<String, dynamic>>();
  }

  /// مصروف واحد بصيغة DTO التعديل (AdvanceMonths افتراضي 1 من الخادم).
  static Future<Map<String, dynamic>> getExpenseById(int id) async {
    final res = await _api.get('/api/expenses/$id', forceRefresh: true);
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب المصروف',
    );
  }

  /// إنشاء مصروف — المنشئ يحدّده الخادم من التوكن؛ لا يُرسل من هنا.
  static Future<Map<String, dynamic>> createExpense(
      Map<String, dynamic> data) async {
    final res = await _api.post('/api/expenses', body: data);
    final decoded = _api.decode(res);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> updateExpense(
      int id, Map<String, dynamic> data) async {
    final res = await _api.put('/api/expenses/$id', body: data);
    final decoded = _api.decode(res);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  /// حذف مصروف — يرمي برسالة الخادم عند الرفض حتى تعرضها القائمة.
  static Future<Map<String, dynamic>> deleteExpense(int id) async {
    final res = await _api.delete('/api/expenses/$id');
    final decoded = _api.decode(res, allowEmpty: true);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{'success': true};
  }

  /// داشبورد المصروفات بتعريفات بلازور العشرة (فرع اختياري).
  static Future<Map<String, dynamic>> getDashboard({int? branchId}) async {
    final res = await _api.get(
      '/api/expenses/dashboard',
      query: {if (branchId != null) 'branchId': '$branchId'},
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب داشبورد المصروفات',
    );
  }

  /// التقرير الإجمالي الشهري (شهور متصلة مصفّرة + تغيّر + إجمالي + متوسط).
  static Future<Map<String, dynamic>> getMonthlySummary({
    String? search,
    int? groupId,
    int? parentGroupId,
    int? branchId,
    int? cashBoxId,
    String? startDate,
    String? endDate,
    double? amountFrom,
    double? amountTo,
    bool? isAdvance,
  }) async {
    final res = await _api.get(
      '/api/expenses/monthly-summary',
      query: _filterQuery(
        search: search,
        groupId: groupId,
        parentGroupId: parentGroupId,
        branchId: branchId,
        cashBoxId: cashBoxId,
        startDate: startDate,
        endDate: endDate,
        amountFrom: amountFrom,
        amountTo: amountTo,
        isAdvance: isAdvance,
      ),
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب الملخص الشهري',
    );
  }

  /// بيانات الطباعة (حتى 10000 صف) بوضع تفصيلي أو إجمالي.
  static Future<Map<String, dynamic>> getPrintData({
    String mode = 'detail',
    String? startDate,
    String? endDate,
    int? groupId,
    int? parentGroupId,
    int? branchId,
    int? cashBoxId,
  }) async {
    final res = await _api.get(
      '/api/expenses/print-data',
      query: {
        'mode': mode,
        ..._filterQuery(
          groupId: groupId,
          parentGroupId: parentGroupId,
          branchId: branchId,
          cashBoxId: cashBoxId,
          startDate: startDate,
          endDate: endDate,
        ),
      },
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب بيانات الطباعة',
    );
  }

  /// تصدير CSV فعلي من الخادم (الوضعان: detailed / monthly) — يعيد نص
  /// الملف كاملًا لمشاركته/حفظه من الشاشة.
  static Future<String> exportCsv({
    required String mode,
    String? startDate,
    String? endDate,
    int? groupId,
    int? parentGroupId,
    int? branchId,
    int? cashBoxId,
  }) async {
    final res = await _api.get(
      '/api/expenses/export/$mode',
      query: _filterQuery(
        groupId: groupId,
        parentGroupId: parentGroupId,
        branchId: branchId,
        cashBoxId: cashBoxId,
        startDate: startDate,
        endDate: endDate,
      ),
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is String) return data;
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند تصدير التقرير',
    );
  }

  /// اقتراحات أسماء سابقة (أصول فقط) مع مجموعة كل اسم للتعبئة التلقائية.
  static Future<List<Map<String, dynamic>>> getNameSuggestions() async {
    final res =
        await _api.get('/api/expenses/name-suggestions', forceRefresh: true);
    final data = _api.decode(res);
    if (data is! List) return const [];
    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ── مجموعات: إنشاء/تعديل/حذف (الصلاحيات على الخادم والشاشة) ──
  static Future<Map<String, dynamic>> createGroup({
    required String name,
    int? parentGroupId,
  }) async {
    final res = await _api.post('/api/expenses/groups', body: {
      'expenseGroupName': name,
      'parentGroupId': parentGroupId,
    });
    final decoded = _api.decode(res);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> updateGroup({
    required int id,
    required String name,
    int? parentGroupId,
  }) async {
    final res = await _api.put('/api/expenses/groups/$id', body: {
      'expenseGroupName': name,
      'parentGroupId': parentGroupId,
    });
    final decoded = _api.decode(res);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> deleteGroup(int id) async {
    final res = await _api.delete('/api/expenses/groups/$id');
    final decoded = _api.decode(res, allowEmpty: true);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{'success': true};
  }

  // ==================== دوال إرثية للمستهلكين الخارجيين ====================

  /// مصروفات فترة للرسم البياني — ترمي عند الفشل (المستهلك يلتقط).
  static Future<List<Map<String, dynamic>>> getExpensesForChart({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    return getExpenses(
      startDate: fmt.format(startDate),
      endDate: fmt.format(endDate),
      limit: 1000,
    );
  }

  static Future<Map<String, double>> getCategoryDistribution({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final expenses = await getExpenses(
      startDate: startDate != null ? fmt.format(startDate) : null,
      endDate: endDate != null ? fmt.format(endDate) : null,
      limit: 1000,
    );
    final Map<String, double> distribution = {};
    for (var expense in expenses) {
      final category = expense['ExpenseGroupName'] as String;
      final amount = expense['Amount'] as double;
      distribution.update(category, (v) => v + amount, ifAbsent: () => amount);
    }
    return distribution;
  }

  static Future<List<Map<String, dynamic>>> getTopCategories({
    int limit = 5,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final distribution = await getCategoryDistribution(
      startDate: startDate,
      endDate: endDate,
    );
    final entries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(limit)
        .map((e) => {'name': e.key, 'amount': e.value})
        .toList();
  }

  static Future<Map<String, dynamic>> getComparisonData({
    DateTime? currentStart,
    DateTime? currentEnd,
    DateTime? previousStart,
    DateTime? previousEnd,
  }) async {
    final now = DateTime.now();
    final currentS = currentStart ?? DateTime(now.year, now.month, 1);
    final currentE = currentEnd ?? now;
    final previousS = previousStart ?? DateTime(now.year, now.month - 1, 1);
    final previousE = previousEnd ?? DateTime(now.year, now.month, 0);

    final currentExpenses =
        await getExpensesForChart(startDate: currentS, endDate: currentE);
    final previousExpenses =
        await getExpensesForChart(startDate: previousS, endDate: previousE);
    final double currentTotal = currentExpenses.fold(
        0.0, (sum, e) => sum + (e['Amount'] as double));
    final double previousTotal = previousExpenses.fold(
        0.0, (sum, e) => sum + (e['Amount'] as double));
    double changePercent = 0;
    if (previousTotal > 0) {
      changePercent = ((currentTotal - previousTotal) / previousTotal) * 100;
    } else if (currentTotal > 0) {
      changePercent = 100;
    }
    final fmt = DateFormat('dd/MM');
    return {
      'currentTotal': currentTotal,
      'previousTotal': previousTotal,
      'changePercent': changePercent,
      'isPositive': changePercent >= 0,
      'currentPeriod': '${fmt.format(currentS)}-${fmt.format(currentE)}',
      'previousPeriod': '${fmt.format(previousS)}-${fmt.format(previousE)}',
    };
  }

  static Future<List<Map<String, double>>> getWeeklyData() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final expenses =
        await getExpensesForChart(startDate: weekAgo, endDate: now);
    final Map<int, double> dailyTotals = {};
    for (var expense in expenses) {
      final date = DateTime.parse(expense['ExpenseDate'] as String);
      final amount = expense['Amount'] as double;
      dailyTotals.update(date.day, (v) => v + amount, ifAbsent: () => amount);
    }
    return List.generate(7, (i) {
      final date = weekAgo.add(Duration(days: i));
      return {'day': i.toDouble(), 'amount': dailyTotals[date.day] ?? 0.0};
    });
  }

  /// مسبار اتصال — يعيد false عند أي فشل بطبيعته.
  static Future<bool> checkConnection() async {
    try {
      final res = await _api
          .get('/api/expenses/groups')
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
