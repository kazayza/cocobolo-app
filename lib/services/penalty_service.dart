import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import 'app_colors.dart';
import 'permission_service.dart';

/// خدمة الجزاءات — /api/employee-penalties (عقد الخادم: صفوف بلا غلاف
/// {success/data}؛ الأخطاء {message} عربية وتُرمى ApiException من
/// ApiClient.decode فتصل رسالتها إلى الشاشة كما هي — لا ابتلاع صامت).
class PenaltyService {
  final ApiClient _api = ApiClient.instance;

  static const String basePath = '/api/employee-penalties';

  List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _row(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// القائمة العامة — الخادم يحدّد النطاق بحسب المستخدم (جزاءاته /
  /// مرؤوسيه / الكل للإدارة). المرشحات تُمرَّر كما هي عند توفرها.
  Future<List<Map<String, dynamic>>> list({
    String? status,
    String? month,
    int? employeeId,
  }) async {
    final res = await _api.get(
      basePath,
      query: {
        if (status != null) 'status': status,
        if (month != null) 'month': month,
        if (employeeId != null) 'employeeId': employeeId,
      },
      forceRefresh: true,
    );
    return _rows(_api.decode(res));
  }

  /// قائمة الاعتماد القابلة للتنفيذ للمستخدم الحالي.
  Future<List<Map<String, dynamic>>> pending() async {
    final res = await _api.get('$basePath/pending', forceRefresh: true);
    return _rows(_api.decode(res));
  }

  /// جزاءات موظف واحد (قسم ملف الموظف).
  Future<List<Map<String, dynamic>>> forEmployee(int employeeId) async {
    final res = await _api.get(
      '$basePath/employee/$employeeId',
      forceRefresh: true,
    );
    return _rows(_api.decode(res));
  }

  /// إنشاء جزاء — الحالة عند الولادة (Approved/Pending) قرار الخادم
  /// بحسب كون المنشئ صاحب توقيع مباشر على الموظف.
  Future<Map<String, dynamic>> create({
    required int employeeId,
    required String type,
    double? daysCount,
    double? fixedAmount,
    required String reason,
    String? targetMonth,
  }) async {
    final res = await _api.post(basePath, body: {
      'employeeId': employeeId,
      'type': type,
      if (type == 'Days') 'daysCount': daysCount,
      if (type == 'Amount') 'fixedAmount': fixedAmount,
      'reason': reason,
      if (targetMonth != null) 'targetMonth': targetMonth,
    });
    return _row(_api.decode(res));
  }

  Future<Map<String, dynamic>> approve(int id) async {
    final res = await _api.post('$basePath/$id/approve');
    return _row(_api.decode(res, allowEmpty: true));
  }

  Future<Map<String, dynamic>> reject(int id) async {
    final res = await _api.post('$basePath/$id/reject');
    return _row(_api.decode(res, allowEmpty: true));
  }

  Future<Map<String, dynamic>> cancel(int id) async {
    final res = await _api.post('$basePath/$id/cancel');
    return _row(_api.decode(res, allowEmpty: true));
  }

  /// محاكاة قيمة خصم الأيام — فشلها صامت بالتصميم (تُخفى المعاينة
  /// ولا تمنع الحفظ أبدًا).
  Future<Map<String, dynamic>?> preview({
    required int employeeId,
    required String month,
    required double days,
  }) async {
    try {
      final res = await _api.get('$basePath/preview', query: {
        'employeeId': employeeId,
        'month': month,
        'days': days,
      });
      final data = _api.decode(res);
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }
}

// ── مفردات الحالة المشتركة بين قائمة الجزاءات وملف الموظف ─────────

String penaltyStatusLabel(String? status) {
  switch (status) {
    case 'Pending':
      return 'بانتظار الاعتماد';
    case 'Approved':
      return 'معتمدة';
    case 'Rejected':
      return 'مرفوضة';
    case 'Applied':
      return 'مطبقة';
    case 'Cancelled':
      return 'ملغية';
    default:
      return status ?? '—';
  }
}

/// لون شارة الحالة بدرجة الوضع (قانون الشارات: الدرجة الفاتحة ليليًا
/// والقاعدية نهاريًا؛ «معتمدة» ذهبية كحالة «معتمد» في الرواتب).
Color penaltyStatusColor(String? status, bool isDark) {
  switch (status) {
    case 'Pending':
      return isDark ? AppColors.warningLight : AppColors.warning;
    case 'Approved':
      return isDark ? AppColors.gold : AppColors.goldDark;
    case 'Applied':
      return isDark ? AppColors.successLight : AppColors.success;
    case 'Rejected':
      return isDark ? AppColors.errorLight : AppColors.error;
    case 'Cancelled':
      return isDark ? AppColors.neutralLight : AppColors.neutral;
    default:
      return isDark ? AppColors.neutralLight : AppColors.neutral;
  }
}

/// صياغة عدد الأيام: كسور الجزاء مسموحة (0.5) والأعداد الصحيحة بلا كسر.
String formatPenaltyDays(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

/// سطر نوع الجزاء: «خصم أيام: ٢ يوم» أو «مبلغ مقطوع».
String penaltyTypeLine(Map<String, dynamic> row) {
  if (row['penaltyType']?.toString() == 'Amount') return 'مبلغ مقطوع';
  return 'خصم أيام: ${formatPenaltyDays(row['daysCount'])} يوم';
}

/// هل أنشأ المستخدم الحالي هذا الصف؟ المعرف الرقمي عند توفره، وإلا
/// مطابقة اسم المنشئ باسم المستخدم الكامل (العقد يضمن الاسم دائمًا).
bool penaltyCreatedByMe(Map<String, dynamic> row) {
  final perms = PermissionService();
  final createdBy = row['createdBy'];
  if (createdBy is num && perms.userId != null) {
    return createdBy.toInt() == perms.userId;
  }
  final name = row['createdByName']?.toString().trim() ?? '';
  if (name.isEmpty) return false;
  return name == (perms.fullName ?? '').trim() ||
      name == (perms.username ?? '').trim();
}
