import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/app_colors.dart';

class CrmPeriodChips extends StatelessWidget {
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onCustomDatePick;
  final String? dateFrom;
  final String? dateTo;
  final bool isDark;

  const CrmPeriodChips({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.onCustomDatePick,
    this.dateFrom,
    this.dateTo,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // === شريط الفترات ===
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildChip('اليوم', 'today', Icons.today),
                _buildChip('الأسبوع', 'week', Icons.date_range),
                _buildChip('الشهر', 'month', Icons.calendar_month),
                _buildChip('3 شهور', '3months', Icons.calendar_today),
                _buildChip('6 شهور', '6months', Icons.calendar_view_month),
                _buildChip('سنة', 'year', Icons.calendar_today_outlined),
                _buildCustomChip(),
              ],
            ),
          ),
        ),

        // === عرض الفترة المختارة ===
        if (dateFrom != null && dateTo != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.gold.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.date_range,
                    color: AppColors.gold,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatDisplayDate(dateFrom!)} → ${_formatDisplayDate(dateTo!)}',
                    style: GoogleFonts.cairo(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${_calculateDays()} يوم)',
                    style: GoogleFonts.cairo(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),

        const SizedBox(height: 8),
      ],
    );
  }

  // === Chip عادي ===
  Widget _buildChip(String label, String period, IconData icon) {
    final isSelected = selectedPeriod == period;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () => onPeriodChanged(period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.gold
                : isDark
                    ? AppColors.darkCard
                    : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.gold
                  : AppColors.divider(isDark),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.black
                    : AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: isSelected
                      ? Colors.black
                      : AppColors.textSecondary(isDark),
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === Chip مخصص ===
  Widget _buildCustomChip() {
    final isSelected = selectedPeriod == 'custom';

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: onCustomDatePick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.gold
                : isDark
                    ? AppColors.darkCard
                    : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.gold
                  : AppColors.divider(isDark),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_calendar,
                size: 14,
                color: isSelected
                    ? Colors.black
                    : AppColors.textSecondary(isDark),
              ),
              const SizedBox(width: 6),
              Text(
                'مخصص',
                style: GoogleFonts.cairo(
                  color: isSelected
                      ? Colors.black
                      : AppColors.textSecondary(isDark),
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === تنسيق التاريخ للعرض ===
  String _formatDisplayDate(String date) {
    try {
      final d = DateTime.parse(date);
      const months = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      return '${d.day} ${months[d.month - 1]}';
    } catch (e) {
      return date;
    }
  }

  // === حساب عدد الأيام ===
  String _calculateDays() {
    try {
      final from = DateTime.parse(dateFrom!);
      final to = DateTime.parse(dateTo!);
      final diff = to.difference(from).inDays + 1;
      return '$diff';
    } catch (e) {
      return '0';
    }
  }
}