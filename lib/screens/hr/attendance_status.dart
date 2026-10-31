import 'package:flutter/material.dart';

import '../../services/app_colors.dart';
import '../../services/design_tokens.dart';

/// تعريف واحد لحالة الحضور اليومي في شاشات الحضور الإدارية (سجلات
/// البصمة الخام والحضور اليدوي اليومي) — مرآة قيم نموذج بلازور
/// ManualDailyAttendancePage حرفيًا: القيمة المخزنة والتسمية المعروضة
/// ولون الشارة من هنا فقط، وأي حالة جديدة تُمدَّد هنا لا داخل شاشة.
/// (شاشة تقرير الحضور القديمة لها اشتقاقها الخاص ولا تُمسّ.)

/// حالة حضور: القيمة المخزنة في قاعدة البيانات + تسميتها المعروضة.
class AttendanceStatusDef {
  final String value;
  final String label;
  const AttendanceStatusDef(this.value, this.label);
}

/// الحالات الثماني بترتيب بلازور — «خروج مبكر» تُعرض «انصراف مبكر»
/// و«إجازة» تُعرض «إجازة رسمية»، والقيم المخزنة كما هي.
const List<AttendanceStatusDef> attendanceStatuses = [
  AttendanceStatusDef('حاضر', 'حاضر'),
  AttendanceStatusDef('متأخر', 'متأخر'),
  AttendanceStatusDef('غائب', 'غائب'),
  AttendanceStatusDef('إذن', 'إذن'),
  AttendanceStatusDef('مأمورية', 'مأمورية'),
  AttendanceStatusDef('خروج مبكر', 'انصراف مبكر'),
  AttendanceStatusDef('إجازة', 'إجازة رسمية'),
  AttendanceStatusDef('راحة', 'راحة'),
];

/// حالات لا تحتاج وقت حضور/انصراف إطلاقًا — حقول الوقت تُعطَّل معها
/// في نموذج بلازور، و«عطلة أسبوعية» ليست من خيارات الإدخال لكنها قد
/// تصل قيمةً مخزنة في سجل قائم فتُعرَّف هنا للعرض والتعطيل معًا.
const Set<String> attendanceNoTimeStatuses = {
  'غائب',
  'إجازة',
  'راحة',
  'عطلة أسبوعية',
};

bool attendanceStatusNeedsTime(String? status) =>
    !attendanceNoTimeStatuses.contains((status ?? '').trim());

/// تسمية العرض لقيمة مخزنة — قيمة غير معروفة تُعرض كما هي.
String attendanceStatusLabel(String? status) {
  final v = (status ?? '').trim();
  for (final def in attendanceStatuses) {
    if (def.value == v) return def.label;
  }
  if (v == 'عطلة أسبوعية') return 'عطلة أسبوعية';
  return v.isEmpty ? '—' : v;
}

/// لون شارة الحالة — الدرجة الفاتحة في الوضع الليلي والقاعدية في
/// النهاري (قانون الشارات: لون الحالة فوق ظلّ منه، لا نص عارٍ).
Color attendanceStatusColor(String? status, bool isDark) {
  switch ((status ?? '').trim()) {
    case 'حاضر':
      return isDark ? AppColors.successLight : AppColors.success;
    case 'متأخر':
      return isDark ? AppColors.warningLight : AppColors.warning;
    case 'غائب':
      return isDark ? AppColors.errorLight : AppColors.error;
    case 'إذن':
      return isDark ? AppColors.infoLight : AppColors.info;
    case 'مأمورية':
      return isDark ? AppColors.goldLight : AppColors.navyLight;
    case 'خروج مبكر':
      return isDark ? AppColors.warningLight : AppStatus.overdue;
    case 'إجازة':
      return isDark ? AppColors.gold : AppColors.goldDark;
    case 'راحة':
    case 'عطلة أسبوعية':
      return isDark ? AppColors.neutralLight : AppColors.neutral;
    default:
      return isDark ? AppColors.neutralLight : AppColors.neutral;
  }
}

IconData attendanceStatusIcon(String? status) {
  switch ((status ?? '').trim()) {
    case 'حاضر':
      return Icons.check_circle_rounded;
    case 'متأخر':
      return Icons.schedule_rounded;
    case 'غائب':
      return Icons.person_off_rounded;
    case 'إذن':
      return Icons.event_note_rounded;
    case 'مأمورية':
      return Icons.work_rounded;
    case 'خروج مبكر':
      return Icons.logout_rounded;
    case 'إجازة':
      return Icons.beach_access_rounded;
    case 'راحة':
      return Icons.bedtime_rounded;
    case 'عطلة أسبوعية':
      return Icons.weekend_rounded;
    default:
      return Icons.help_rounded;
  }
}

/// تحليل وقت بصيغ الخادم المختلفة ('HH:mm' أو 'HH:mm:ss' أو
/// 'hh:mm tt') إلى دقائق منذ منتصف الليل — فشل التحليل يرجع null
/// ولا يخترع وقتًا.
int? attendanceParseMinutes(dynamic raw) {
  if (raw == null) return null;
  var s = raw.toString().trim();
  if (s.isEmpty) return null;
  final isPm = s.contains('PM') || s.contains('م');
  final isAm = s.contains('AM') || s.contains('ص');
  s = s.replaceAll(RegExp(r'[^0-9:]'), ' ');
  final parts =
      s.split(RegExp(r'[:\s]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  final hourRaw = int.tryParse(parts[0]);
  if (hourRaw == null) return null;
  final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  var hour = hourRaw;
  if (isPm && hour < 12) hour += 12;
  if (isAm && hour == 12) hour = 0;
  return (hour % 24) * 60 + (minute % 60);
}

/// تنسيق دقائق منذ منتصف الليل إلى 'HH:mm' بعرض ثابت.
String attendanceFormatMinutes(int minutes) {
  final m = ((minutes % 1440) + 1440) % 1440;
  final h = (m ~/ 60).toString().padLeft(2, '0');
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$h:$mm';
}

/// تنسيق قيمة وقت واردة من الخادم إلى 'HH:mm' أو null عند غيابها.
String? attendanceNormalizeTime(dynamic raw) {
  final minutes = attendanceParseMinutes(raw);
  return minutes == null ? null : attendanceFormatMinutes(minutes);
}
