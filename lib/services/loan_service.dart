import '../core/network/api_client.dart';

/// خدمة السلف والأقساط — /api/loans.
/// عقد الأخطاء الموحّد في هذا الـAPI: فشل HTTP مع JSON ‏{message} عربي،
/// و[ApiClient.decode] يرمي [ApiException] تحمل رسالة الخادم كما هي.
/// لا ابتلاع صامت هنا إطلاقًا: كل دالة ترمي عند الفشل، والشاشات تعرض
/// الرسالة للمستخدم مع زر إعادة محاولة حيث يلزم.
class LoanService {
  final ApiClient _api = ApiClient.instance;

  List<dynamic> _rows(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return const [];
  }

  Map<String, dynamic> _envelopeData(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// قائمة السلف — ترمي [ApiException] برسالة الخادم عند أي فشل.
  Future<Map<String, dynamic>> getLoans({
    String? search,
    String? status,
    String? month,
    int page = 1,
    int pageSize = 15,
  }) async {
    final res = await _api.get(
      '/api/loans',
      query: {
        'search': search,
        'status': status,
        'month': month,
        'page': page,
        'pageSize': pageSize,
      },
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) return {'items': data, 'totalCount': data.length};
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب السلف',
    );
  }

  /// إحصاءات السلف — ترمي برسالة الخادم عند الفشل (لا رجوع صامتًا إلى
  /// خريطة فارغة كما كان يحدث سابقًا عبر مسار http الاحتياطي).
  Future<Map<String, dynamic>> getStats() async {
    final res = await _api.get('/api/loans/stats', forceRefresh: true);
    final data = _api.decode(res);
    return _envelopeData(data);
  }

  /// أقساط شهر معيّن — ترمي برسالة الخادم عند الفشل.
  Future<List<dynamic>> getMonthInstallments(String month) async {
    final res = await _api.get(
      '/api/loans/installments',
      query: {'month': month},
      forceRefresh: true,
    );
    return _rows(_api.decode(res));
  }

  /// كشف حساب موظف (يشمل قائمة سلفه في Loans) — ترمي برسالة الخادم
  /// عند الفشل، و404 تحمل «السلفة غير موجودة»/رسالة الخادم كما هي.
  Future<Map<String, dynamic>> getStatement(int employeeId) async {
    final res = await _api.get(
      '/api/loans/statement/$employeeId',
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب كشف الموظف',
    );
  }

  /// بحث الموظفين لنقطة السلف المخصصة — ترمي برسالة الخادم عند الفشل.
  Future<List<dynamic>> searchEmployees(String? query) async {
    final res = await _api.get(
      '/api/loans/employees-lookup',
      query: query != null ? {'search': query} : null,
      forceRefresh: true,
    );
    return _rows(_api.decode(res));
  }

  /// تفاصيل سلفة واحدة مع أقساطها — GET /api/loans/:id يعيد
  /// { Loan: {...}, Installments: [...] } داخل data.
  Future<Map<String, dynamic>> getLoanDetail(int loanId) async {
    final res = await _api.get('/api/loans/$loanId', forceRefresh: true);
    return _envelopeData(_api.decode(res));
  }

  /// إنشاء سلفة — POST /api/loans. الخزينة إلزامية الآن: الخادم يرفض
  /// غيابها بـ400 «يرجى اختيار الخزينة»، ويرفض تجاوز الرصيد برسالة
  /// الرصيد؛ كلتاهما تصل عبر [ApiException] كما هي.
  Future<Map<String, dynamic>> createLoan({
    required int employeeId,
    required double amount,
    required int totalInstallments,
    required String startMonth,
    required int cashBoxId,
    String? purpose,
  }) async {
    final res = await _api.post('/api/loans', body: {
      'employeeId': employeeId,
      'amount': amount,
      'totalInstallments': totalInstallments,
      'startMonth': startMonth,
      'cashBoxId': cashBoxId,
      if (purpose != null && purpose.trim().isNotEmpty)
        'purpose': purpose.trim(),
    });
    final data = _api.decode(res);
    if (data is Map && data['success'] == true) return _envelopeData(data);
    throw ApiException(
      statusCode: res.statusCode,
      message: data is Map
          ? (data['message'] ?? 'فشل إنشاء السلفة').toString()
          : 'فشل إنشاء السلفة',
    );
  }

  /// إلغاء سلفة — ترمي برسالة الخادم العربية كما هي (بما فيها حالات
  /// التعارض) بدل إرجاع false صامت كما كان سابقًا.
  Future<Map<String, dynamic>> cancelLoan(int loanId, String currentUser) async {
    final res = await _api.post(
      '/api/loans/$loanId/cancel',
      body: {'currentUser': currentUser},
    );
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// تخطي/تأجيل قسط إلى شهر لاحق — الشهر الهدف اختياري (فارغ = افتراضي
  /// الخادم). رسالة النجاح من الخادم: «تم تأجيل القسط إلى شهر X».
  Future<Map<String, dynamic>> skipInstallment(
    int installmentId, {
    String? reason,
    String? targetMonth,
  }) async {
    final res = await _api.post('/api/loans/installments/$installmentId/skip',
        body: {
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
          if (targetMonth != null && targetMonth.trim().isNotEmpty)
            'targetMonth': targetMonth.trim(),
        });
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// تقسيم قسط: إبقاء [amountToKeep] في شهره ونقل الباقي لشهر لاحق.
  Future<Map<String, dynamic>> splitInstallment(
    int installmentId, {
    required double amountToKeep,
    String? reason,
    String? targetMonth,
  }) async {
    final res = await _api.post('/api/loans/installments/$installmentId/split',
        body: {
          'amountToKeep': amountToKeep,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
          if (targetMonth != null && targetMonth.trim().isNotEmpty)
            'targetMonth': targetMonth.trim(),
        });
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// تعديل قسط: مبلغ جديد و/أو شهر جديد و/أو ملاحظات.
  Future<Map<String, dynamic>> updateInstallment(
    int installmentId, {
    double? newAmount,
    String? newMonth,
    String? notes,
  }) async {
    final res = await _api.post('/api/loans/installments/$installmentId/update',
        body: {
          if (newAmount != null) 'newAmount': newAmount,
          if (newMonth != null && newMonth.trim().isNotEmpty)
            'newMonth': newMonth.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        });
    final data = _api.decode(res);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}
