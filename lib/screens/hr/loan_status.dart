import 'package:flutter/material.dart';

import '../../services/app_colors.dart';

/// تعريف واحد لحالات السلفة والقسط في كل شاشات السلف (قائمة السلف،
/// تفاصيل السلفة، كشف الموظف داخل شاشة السلف): النص العربي ولون الشارة
/// من هنا فقط — الدرجة الفاتحة في الوضع الليلي والقاعدية في النهاري
/// (قانون الشارات: لون الحالة فوق ظلّ منه، لا نص ملوّن عارٍ).
/// أي حالة جديدة تُمدَّد هنا، ولا تُعرَّف داخل شاشة.

String loanStatusLabel(String? status) {
  switch (status) {
    case 'Active':
      return 'نشطة';
    case 'Completed':
      return 'منتهية';
    case 'Cancelled':
      return 'ملغية';
    default:
      return status ?? '—';
  }
}

Color loanStatusColor(String? status, bool isDark) {
  switch (status) {
    case 'Active':
      return isDark ? AppColors.successLight : AppColors.success;
    case 'Completed':
      return isDark ? AppColors.infoLight : AppColors.info;
    case 'Cancelled':
      return isDark ? AppColors.errorLight : AppColors.error;
    default:
      return isDark ? AppColors.neutralLight : AppColors.neutral;
  }
}

IconData loanStatusIcon(String? status) {
  switch (status) {
    case 'Active':
      return Icons.play_circle_rounded;
    case 'Completed':
      return Icons.task_alt_rounded;
    case 'Cancelled':
      return Icons.cancel_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

String installmentStatusLabel(String? status) {
  switch (status) {
    case 'Pending':
      return 'معلّق';
    case 'Deducted':
      return 'مخصوم';
    case 'Skipped':
      return 'مؤجل';
    default:
      return status ?? '—';
  }
}

Color installmentStatusColor(String? status, bool isDark) {
  switch (status) {
    case 'Pending':
      return isDark ? AppColors.warningLight : AppColors.warning;
    case 'Deducted':
      return isDark ? AppColors.successLight : AppColors.success;
    case 'Skipped':
      return isDark ? AppColors.neutralLight : AppColors.neutral;
    default:
      return isDark ? AppColors.neutralLight : AppColors.neutral;
  }
}

IconData installmentStatusIcon(String? status) {
  switch (status) {
    case 'Pending':
      return Icons.hourglass_top_rounded;
    case 'Deducted':
      return Icons.check_circle_rounded;
    case 'Skipped':
      return Icons.schedule_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}
