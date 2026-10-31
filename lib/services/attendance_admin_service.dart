import '../core/network/api_client.dart';

/// خدمة الحضور الإداري — سجلات البصمة الخام والحضور اليدوي اليومي
/// (/api/attendance/raw-logs و/api/attendance/manual-daily*).
/// عقد الأخطاء الموحّد (على نمط ExemptionService): كل دالة ترمي
/// [ApiException] برسالة الخادم العربية عند الفشل، والشاشات تعرضها
/// مع إعادة محاولة — لا ابتلاع صامت إطلاقًا.
class AttendanceAdminService {
  final ApiClient _api = ApiClient.instance;

  /// صفحة من بصمات الجهاز الخام كما سجّلها الجهاز، مع إحصاءاتها:
  /// {items, totalCount, pageNumber, pageSize, totalPages, todayCount,
  /// employeeCount} — employeeCount = الأكواد المميزة في الصفحة.
  Future<Map<String, dynamic>> getRawLogs({
    required String dateFrom,
    required String dateTo,
    String? searchText,
    String? biometricCode,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final res = await _api.get(
      '/api/attendance/raw-logs',
      query: {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'searchText': searchText,
        'biometricCode': biometricCode,
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      },
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map && data['items'] is List) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب سجلات البصمة',
    );
  }

  /// سجل موظف في يوم: {employee, record (قد يكون null), shift} —
  /// record null يعني «سجل جديد» في نموذج بلازور.
  Future<Map<String, dynamic>> getManualRecord(
    int employeeId,
    String date,
  ) async {
    final res = await _api.get(
      '/api/attendance/manual-daily/record',
      query: {'employeeId': employeeId, 'date': date},
      forceRefresh: true,
    );
    final data = _api.decode(res);
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند تحميل السجل',
    );
  }

  /// كل سجلات الحضور اليدوي في يوم واحد (قائمة أسفل النموذج).
  Future<List<Map<String, dynamic>>> getManualDay(String date) async {
    final res = await _api.get(
      '/api/attendance/manual-daily/day',
      query: {'date': date},
      forceRefresh: true,
    );
    final data = _api.decode(res);
    final list = data is Map ? data['data'] : data;
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    throw const ApiException(
      statusCode: 200,
      message: 'استجابة غير متوقعة من الخادم عند جلب سجلات اليوم',
    );
  }

  /// إنشاء سجل حضور يدوي — يرجع ردّ الخادم كاملًا {success, message,
  /// data:{attendanceId, record}} لتعرض الشاشة رسالته كما هي.
  Future<Map<String, dynamic>> createManual({
    required int employeeId,
    required String logDate,
    String? timeIn,
    String? timeOut,
    required String status,
    required String editReason,
  }) async {
    final res = await _api.post('/api/attendance/manual-daily', body: {
      'employeeId': employeeId,
      'logDate': logDate,
      'timeIn': timeIn,
      'timeOut': timeOut,
      'status': status,
      'editReason': editReason,
    });
    return _successMap(res, 'إنشاء سجل الحضور');
  }

  /// تعديل سجل قائم بمعرّفه.
  Future<Map<String, dynamic>> updateManual(
    int id, {
    String? timeIn,
    String? timeOut,
    required String status,
    required String editReason,
  }) async {
    final res = await _api.put('/api/attendance/manual-daily/$id', body: {
      'timeIn': timeIn,
      'timeOut': timeOut,
      'status': status,
      'editReason': editReason,
    });
    return _successMap(res, 'تعديل سجل الحضور');
  }

  /// حذف سجل قائم — يرجع رسالة الخادم لعرضها.
  Future<String> deleteManual(int id) async {
    final res = await _api.delete('/api/attendance/manual-daily/$id');
    final data = _successMap(res, 'حذف سجل الحضور');
    return data['message']?.toString() ?? 'تم حذف السجل';
  }

  /// فكّ ردّ كتابة: نجاح صريح فقط، وإلا ApiException برسالة الخادم
  /// (الأخطاء تصل {success:false, message} فتُعرض حرفيًا).
  Map<String, dynamic> _successMap(dynamic res, String action) {
    final data = _api.decode(res);
    if (data is Map && data['success'] == true) {
      return Map<String, dynamic>.from(data);
    }
    final message = data is Map
        ? (data['message']?.toString() ?? 'فشل $action')
        : 'استجابة غير متوقعة من الخادم عند $action';
    throw ApiException(statusCode: 200, message: message);
  }
}
