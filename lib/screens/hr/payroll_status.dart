import 'package:flutter/material.dart';

import '../../services/app_colors.dart';

/// تعريف واحد لحالة الراتب في كل شاشات الرواتب (قائمة الرواتب،
/// «قسيمتي»، قسيمة الراتب): مفتاح الحالة الإنجليزي، ونصها العربي،
/// ولون شارتها — الدرجة الفاتحة في الوضع الليلي والقاعدية في النهاري
/// (قانون الشارات: لون الحالة فوق ظلّ منه، لا نص ملوّن عارٍ).
///
/// مصدر الحقيقة في الصفوف هو `PaymentStatus` العربي المخزّن
/// (قيد المراجعة/معتمد/مدفوع/غير مدفوع/مرفوض/ملغي)؛ الحقل الإنجليزي
/// `Status` احتياطي فقط للصفوف القديمة.

/// مفتاح الحالة: paid | approved | pending | unpaid | rejected | other
String payrollStatusKey(Map<dynamic, dynamic> row) {
  final payment = '${row['PaymentStatus'] ?? ''}';
  final key = _keyFromText(payment);
  if (key != 'other') return key;
  return _keyFromText('${row['Status'] ?? row['PayrollStatus'] ?? ''}');
}

String _keyFromText(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return 'other';
  if (s.contains('غير مدفوع')) return 'unpaid';
  if (s.contains('مدفوع')) return 'paid';
  if (s.contains('معتمد')) return 'approved';
  if (s.contains('مراجعة') || s.contains('انتظار')) return 'pending';
  if (s.contains('مرفوض') || s.contains('ملغي') || s.contains('ملغى')) {
    return 'rejected';
  }
  switch (s.toLowerCase()) {
    case 'paid':
      return 'paid';
    case 'approved':
      return 'approved';
    case 'pending':
    case 'pending_review':
    case 'pendingreview':
    case 'review':
      return 'pending';
    case 'unpaid':
    case 'not_paid':
      return 'unpaid';
    case 'rejected':
    case 'cancelled':
    case 'canceled':
      return 'rejected';
    default:
      return 'other';
  }
}

String payrollStatusLabel(String key, {String? raw}) {
  switch (key) {
    case 'paid':
      return 'مدفوع';
    case 'approved':
      return 'معتمد';
    case 'pending':
      return 'قيد المراجعة';
    case 'unpaid':
      return 'غير مدفوع';
    case 'rejected':
      return (raw ?? '').contains('ملغ') ? 'ملغي' : 'مرفوض';
    default:
      return (raw ?? '').isNotEmpty ? raw! : '—';
  }
}

Color payrollStatusColor(String key, bool isDark) {
  switch (key) {
    case 'paid':
      return isDark ? AppColors.successLight : AppColors.success;
    case 'approved':
      // «معتمد» ذهبي في خريطة حالات الرواتب؛ الذهبي الداكن نهارًا
      // حتى لا ينهار التباين فوق الظل الفاتح للشارة
      return isDark ? AppColors.gold : AppColors.goldDark;
    case 'pending':
      return isDark ? AppColors.infoLight : AppColors.info;
    case 'unpaid':
      return isDark ? AppColors.warningLight : AppColors.warning;
    case 'rejected':
      return isDark ? AppColors.errorLight : AppColors.error;
    default:
      return isDark ? AppColors.neutralLight : AppColors.neutral;
  }
}
