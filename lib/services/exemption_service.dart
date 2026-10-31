import '../core/network/api_client.dart';

/// خدمة الاستثناءات اليومية — /api/attendance/exemptions*.
/// عقد الأخطاء الموحّد: كل دالة ترمي [ApiException] برسالة الخادم عند
/// الفشل، والشاشات تعرضها مع إعادة محاولة — لا ابتلاع صامت.
class ExemptionService {
  final ApiClient _api = ApiClient.instance;

  /// قائمة الاستثناءات — الخادم يقيّد غير المديرين بسجلاتهم هم.
  /// [status] إحدى: Pending / Approved / Rejected.
  Future<List<dynamic>> getList({
    String? status,
    String? employeeName,
    String? date,
    String? dateFrom,
    String? dateTo,
    bool? isDeducted,
  }) async {
    final res = await _api.get(
      '/api/attendance/exemptions-list',
      query: {
        'status': status,
        'employeeName': employeeName,
        'date': date,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'isDeducted': isDeducted?.toString(),
      },
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب الاستثناءات',
    );
  }

  /// إنشاء استثناء. للمدير: [employeeId] هو المستهدف ويحلّ الخادم
  /// بصمته منه؛ لغير المدير يتجاهل الخادم أي استهداف ويفرض موظفه.
  /// [isDeducted] null = الافتراضي بحسب نوع السبب عند الخادم.
  Future<Map<String, dynamic>> create({
    int? employeeId,
    required String exemptionDate,
    required String reasonCode,
    String? description,
    required bool isFullDay,
    double? hours,
    bool? isDeducted,
    String? notes,
  }) async {
    final res = await _api.post('/api/attendance/exemptions', body: {
      'employeeId': employeeId,
      'exemptionDate': exemptionDate,
      'reasonCode': reasonCode,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'isFullDay': isFullDay,
      if (!isFullDay && hours != null) 'hours': hours,
      if (isDeducted != null) 'isDeducted': isDeducted,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    final data = _api.decode(res);
    if (data is Map && data['success'] == true) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند إنشاء الاستثناء',
    );
  }

  Future<void> approve(int id) async {
    final res = await _api.post('/api/attendance/exemptions/$id/approve');
    final data = _api.decode(res);
    if (data is Map && data['success'] == true) return;
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند الاعتماد',
    );
  }

  Future<void> reject(int id, {String? reason}) async {
    final res = await _api.post(
      '/api/attendance/exemptions/$id/reject',
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final data = _api.decode(res);
    if (data is Map && data['success'] == true) return;
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند الرفض',
    );
  }

  Future<void> delete(int id) async {
    final res = await _api.delete('/api/attendance/exemptions/$id');
    final data = _api.decode(res);
    if (data is Map && data['success'] == true) return;
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند الحذف',
    );
  }
}
