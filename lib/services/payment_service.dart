import '../core/network/api_client.dart';

/// خدمة المدفوعات — /api/payments (وحدة بلازور PaymentService).
/// عقد الأخطاء الموحّد: [ApiClient.decode] يرمي [ApiException] برسالة
/// الخادم العربية كما هي؛ لا ابتلاع صامت في أي دالة هنا، والشاشات
/// تعرض الرسالة للمستخدم.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();
  final ApiClient _api = ApiClient.instance;

  /// طرق الدفع القابلة للاختيار يدويًا (PaymentMethods.Selectable) —
  /// «Advance» نظامية فقط ولا تظهر في أي منتقٍ.
  static const List<Map<String, String>> selectableMethods = [
    {'value': 'Cash', 'label': 'نقدى'},
    {'value': 'Bank', 'label': 'تحويل بنكى'},
    {'value': 'Visa', 'label': 'فيزا'},
    {'value': 'InstaPay', 'label': 'InstaPay'},
    {'value': 'Credit', 'label': 'آجل'},
    {'value': 'Other', 'label': 'أخرى'},
  ];

  static String methodLabel(String? value) {
    for (final m in selectableMethods) {
      if (m['value'] == value) return m['label']!;
    }
    if (value == 'Advance') return 'دفعة مقدمة';
    return value ?? '—';
  }

  Map<String, dynamic> _data(dynamic decoded) {
    if (decoded is Map && decoded['data'] is Map) {
      return Map<String, dynamic>.from(decoded['data'] as Map);
    }
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم',
    );
  }

  /// قائمة المدفوعات — type: Sale | Purchase، مع البحث والفلاتر
  /// والترقيم. تعيد { items, totalCount, page, pageSize }.
  Future<Map<String, dynamic>> getPayments({
    required String type,
    String? search,
    String? from,
    String? to,
    String? method,
    int? cashBoxId,
    int? partyId,
    int page = 1,
    int pageSize = 25,
  }) async {
    final res = await _api.get('/api/payments', query: {
      'type': type,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (method != null) 'method': method,
      if (cashBoxId != null) 'cashBoxId': cashBoxId,
      if (partyId != null) 'partyId': partyId,
      'page': page,
      'pageSize': pageSize,
    }, forceRefresh: true);
    return _data(_api.decode(res));
  }

  /// إحصائيات المدفوعات لنوع الفاتورة (إجمالي/يوم/شهر + خزينة/طريقة).
  Future<Map<String, dynamic>> getStats({required String type}) async {
    final res = await _api.get('/api/payments/stats',
        query: {'type': type}, forceRefresh: true);
    return _data(_api.decode(res));
  }

  /// إنشاء دفعة مستقلة لفاتورة — الخادم يفرض الخزينة وحد المتبقي
  /// وبوابة الإنشاء بحسب نوع الفاتورة.
  Future<Map<String, dynamic>> createPayment({
    required int transactionId,
    required double amount,
    required int cashBoxId,
    required String paymentMethod,
    String? paymentDate,
    String? notes,
  }) async {
    final res = await _api.post('/api/payments', body: {
      'transactionId': transactionId,
      'amount': amount,
      'cashBoxId': cashBoxId,
      'paymentMethod': paymentMethod,
      if (paymentDate != null) 'paymentDate': paymentDate,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return _data(_api.decode(res));
  }

  /// تعديل دفعة — حد الخادم: المتبقي الحالي + مبلغ الدفعة القديمة.
  Future<Map<String, dynamic>> updatePayment(
    int paymentId, {
    required double amount,
    required int cashBoxId,
    required String paymentMethod,
    String? notes,
  }) async {
    final res = await _api.put('/api/payments/$paymentId', body: {
      'amount': amount,
      'cashBoxId': cashBoxId,
      'paymentMethod': paymentMethod,
      'notes': notes,
    });
    return _data(_api.decode(res));
  }

  /// إلغاء دفعة — السبب إلزامي ويُحفظ في سجل التدقيق، والخادم يحذف
  /// الدفعة وحركتها ويعيد حساب الفاتورة (بوابة Delete حصرًا).
  Future<Map<String, dynamic>> deletePayment(int paymentId,
      {required String reason}) async {
    final res = await _api.delete('/api/payments/$paymentId',
        body: {'reason': reason});
    return _data(_api.decode(res));
  }

  /// سند قبض/صرف الدفعة — رقم السند والتفقيط يولّدهما الخادم.
  Future<Map<String, dynamic>> getReceipt(int paymentId) async {
    final res = await _api.get('/api/payments/$paymentId/receipt',
        forceRefresh: true);
    return _data(_api.decode(res));
  }

  /// تحليل شرائح السداد 70/20/10 لفاتورة، مع توزيع مبلغ مقترح.
  Future<Map<String, dynamic>> getAnalysis(int transactionId,
      {double? amount}) async {
    final res = await _api.get('/api/payments/analysis/$transactionId',
        query: {
          if (amount != null && amount > 0) 'amount': amount,
        },
        forceRefresh: true);
    return _data(_api.decode(res));
  }
}
