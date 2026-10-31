import 'package:flutter/material.dart';

import '../../services/app_colors.dart';

/// تعريف واحد لحالة الاستثناء اليومي وتصنيف سببه في كل شاشات
/// الاستثناءات — مرآة ExemptionStatus وExemptionReasonCodes في بلازور
/// (DTOS/AttendanceDtos.cs وDTOS/ExemptionDtos.cs).
///
/// الحالة المخزنة إنجليزية (Pending/Approved/Rejected)؛ الصفوف القديمة
/// بلا حالة صريحة تُستنتج من وجود المعتمِد (InferStatus): حالة فارغة
/// بلا معتمِد = قيد الاعتماد، وبمعتمِد = معتمد.

/// مفتاح الحالة: pending | approved | rejected | other
String exemptionStatusKey(Map<dynamic, dynamic> row) {
  final raw = '${row['Status'] ?? ''}'.trim();
  if (raw.isNotEmpty && raw.toLowerCase() != 'approved') {
    return _keyFromRaw(raw);
  }
  if (raw.toLowerCase() == 'approved') {
    final approvedBy = '${row['ApprovedBy'] ?? ''}'.trim();
    // InferStatus حرفيًا: Approved الصريحة بلا معتمِد تُقرأ «قيد الاعتماد»
    return approvedBy.isNotEmpty ? 'approved' : 'pending';
  }
  final approvedBy = '${row['ApprovedBy'] ?? ''}'.trim();
  return approvedBy.isNotEmpty ? 'approved' : 'pending';
}

String _keyFromRaw(String raw) {
  switch (raw.toLowerCase()) {
    case 'pending':
      return 'pending';
    case 'approved':
      return 'approved';
    case 'rejected':
      return 'rejected';
    default:
      return 'other';
  }
}

String exemptionStatusLabel(String key) {
  switch (key) {
    case 'approved':
      return 'معتمد';
    case 'rejected':
      return 'مرفوض';
    case 'pending':
      return 'قيد الاعتماد';
    default:
      return 'غير معروف';
  }
}

Color exemptionStatusColor(String key, bool isDark) {
  switch (key) {
    case 'approved':
      return isDark ? AppColors.successLight : AppColors.success;
    case 'rejected':
      return isDark ? AppColors.errorLight : AppColors.error;
    case 'pending':
      return isDark ? AppColors.warningLight : AppColors.warning;
    default:
      return AppColors.neutral;
  }
}

IconData exemptionStatusIcon(String key) {
  switch (key) {
    case 'approved':
      return Icons.check_circle_rounded;
    case 'rejected':
      return Icons.cancel_rounded;
    case 'pending':
      return Icons.hourglass_top_rounded;
    default:
      return Icons.help_rounded;
  }
}

/// مقترحات السبب في بلازور (ExemptionReasonCodes.Suggestions) — قائمة
/// اختيار في طلب الموظف، واقتراحات إكمال حر في نموذج المدير.
const List<String> exemptionReasonSuggestions = [
  'إذن',
  'مأمورية',
  'مهمة رسمية',
  'انصراف مبكر',
];

/// تصنيف السبب بالكلمات المفتاحية — نفس قواعد بلازور الحرفية، وهو ما
/// يبني عليه الخادم أثر الحضور والخصم الافتراضي.
bool exemptionIsErrand(String? reason) {
  final t = (reason ?? '').trim();
  if (t.isEmpty) return false;
  return t.contains('مأمورية') ||
      t.contains('مهمة رسمية') ||
      t.contains('مهمة') ||
      t.contains('عمل');
}

bool exemptionIsEarlyLeave(String? reason) {
  final t = (reason ?? '').trim();
  if (t.isEmpty) return false;
  return t.contains('انصراف مبكر') || t.contains('خروج مبكر');
}

bool exemptionIsPermission(String? reason) {
  final t = (reason ?? '').trim();
  if (t.isEmpty) return false;
  return t.contains('إذن') || t.contains('اذن');
}

/// الخصم الافتراضي بحسب النوع: مأمورية وانصراف مبكر بلا خصم، وما
/// عداهما يُخصم (DefaultIsDeducted في بلازور).
bool exemptionDefaultIsDeducted(String? reason) {
  if (exemptionIsErrand(reason)) return false;
  if (exemptionIsEarlyLeave(reason)) return false;
  return true;
}

/// لون شارة نوع السبب (درجات بلازور: مأمورية سماوي، انصراف مبكر
/// برتقالي، إذن بنفسجي، غيره محايد) — تُستخدم لونًا للشارة لا نصًا عاريًا.
Color exemptionReasonColor(String? reason, bool isDark) {
  if (exemptionIsErrand(reason)) {
    return isDark ? const Color(0xFF4DD0E1) : const Color(0xFF00ACC1);
  }
  if (exemptionIsEarlyLeave(reason)) {
    return isDark ? AppColors.warningLight : AppColors.warning;
  }
  if (exemptionIsPermission(reason)) {
    return isDark ? const Color(0xFFCE93D8) : const Color(0xFF8E24AA);
  }
  return AppColors.neutral;
}

IconData exemptionReasonIcon(String? reason) {
  if (exemptionIsErrand(reason)) return Icons.work_outline_rounded;
  if (exemptionIsEarlyLeave(reason)) return Icons.exit_to_app_rounded;
  if (exemptionIsPermission(reason)) return Icons.event_note_rounded;
  return Icons.help_rounded;
}

/// نص أثر السبب كما يعرضه بلازور في نموذجي الإنشاء.
String exemptionReasonEffectText(String? reason) {
  if (exemptionIsErrand(reason)) {
    return 'مأمورية / مهمة رسمية — لا يُخصم من الراتب (يُعامل حضور)';
  }
  if (exemptionIsEarlyLeave(reason)) {
    return 'انصراف مبكر — لا يُخصم من الراتب (تسجيل فقط)';
  }
  return 'إذن شخصي — يُخصم من الراتب';
}
