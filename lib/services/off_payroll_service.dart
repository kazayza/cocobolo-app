import '../core/network/api_client.dart';

/// خدمة دفعات خارج الراتب — /api/off-payroll.
/// عقد الأخطاء الموحّد: كل دالة ترمي [ApiException] برسالة الخادم
/// العربية كما هي؛ لا مسار http احتياطيًّا صامتًا ولا رجوع إلى فراغ
/// عند الفشل (كان الفشل يُعرض «لا توجد دفعات» كذبًا).
class OffPayrollService {
  final ApiClient _api = ApiClient.instance;

  Map<String, dynamic> _envelopeData(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// القائمة + الإحصاءات (مرشح الشهر/الحالة/النوع/البحث كما في بلازور).
  Future<Map<String, dynamic>> getAll({
    String? month,
    String? status,
    String? paymentType,
    String? search,
    int pageSize = 100,
  }) async {
    final res = await _api.get(
      '/api/off-payroll',
      query: {
        'month': month,
        'status': status,
        'paymentType': paymentType,
        'search': search,
        'pageSize': pageSize,
      },
      forceRefresh: true,
    );
    return _envelopeData(_api.decode(res));
  }

  /// إنشاء طلب دفعة — الوصف إلزامي، والشهر المرجعي (شهر الاستحقاق)
  /// مستقل عن شهر الدفعة كما في بلازور (EffectiveMonth).
  Future<Map<String, dynamic>> create({
    required int employeeId,
    required double amount,
    required String paymentType,
    required String paymentMonth,
    String? referenceMonth,
    required String description,
    String? reason,
  }) async {
    final res = await _api.post('/api/off-payroll', body: {
      'employeeId': employeeId,
      'amount': amount,
      'paymentType': paymentType,
      'paymentMonth': paymentMonth,
      'referenceMonth': referenceMonth,
      'description': description,
      'reason': reason,
    });
    final data = _api.decode(res);
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw ApiException(
        statusCode: res.statusCode,
        message: data is Map
            ? '${data['message'] ?? 'فشل إنشاء الدفعة'}'
            : 'فشل إنشاء الدفعة',
      );
    }
    return _envelopeData(data);
  }

  Future<void> _action(String path, {Object? body}) async {
    final res = await _api.post(path, body: body);
    final data = _api.decode(res);
    if (res.statusCode != 200 || (data is Map && data['success'] != true)) {
      throw ApiException(
        statusCode: res.statusCode,
        message: data is Map
            ? '${data['message'] ?? 'فشل تنفيذ الإجراء'}'
            : 'فشل تنفيذ الإجراء',
      );
    }
  }

  Future<void> approve(int id) => _action('/api/off-payroll/$id/approve');

  Future<void> reject(int id, {String? reason}) =>
      _action('/api/off-payroll/$id/reject', body: {'reason': reason});

  Future<void> cancel(int id) => _action('/api/off-payroll/$id/cancel');

  /// الصرف — بمخصصات أقساط سلف اختيارية (مقاصة): كل عنصر
  /// {installmentId, amount}؛ الخادم يصرف النقدي فقط ويعلّم الأقساط
  /// PaidExternal كما في بلازور PayOneWithLoanAllocationAsync.
  Future<void> pay(
    int id,
    int cashBoxId, {
    List<Map<String, dynamic>> allocations = const [],
  }) =>
      _action('/api/off-payroll/$id/pay', body: {
        'cashBoxId': cashBoxId,
        if (allocations.isNotEmpty) 'allocations': allocations,
      });

  /// أقساط الموظف المعلّقة على سلف نشطة — وقود حوار المقاصة.
  Future<List<dynamic>> getPendingInstallments(int employeeId) async {
    final res = await _api.get(
      '/api/off-payroll/pending-installments/$employeeId',
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is Map && data['data'] is List) return data['data'] as List;
    if (data is List) return data;
    return const [];
  }
}
