import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/app_colors.dart';
import '../../../models/dashboard_model.dart';

class CrmFilterBar extends StatelessWidget {
  final FilterLists filterLists;
  final int? selectedEmployeeId;
  final int? selectedSourceId;
  final int? selectedStageId;
  final int? selectedAdTypeId;
  final VoidCallback onClear;
  final bool isDark;

  const CrmFilterBar({
    super.key,
    required this.filterLists,
    this.selectedEmployeeId,
    this.selectedSourceId,
    this.selectedStageId,
    this.selectedAdTypeId,
    required this.onClear,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeFilters = _getActiveFilters();

    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCard.withOpacity(0.5)
              : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.gold.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.filter_alt_rounded,
              color: AppColors.gold,
              size: 16,
            ),
            const SizedBox(width: 8),

            // === الفلاتر النشطة ===
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: activeFilters
                      .map((filter) => _buildFilterChip(filter))
                      .toList(),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // === زرار مسح الكل ===
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.close,
                      color: Colors.red[400],
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'مسح',
                      style: GoogleFonts.cairo(
                        color: Colors.red[400],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0),
    );
  }

  // === بناء chip لكل فلتر نشط ===
  Widget _buildFilterChip(_ActiveFilter filter) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filter.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: filter.color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filter.icon,
            color: filter.color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            filter.label,
            style: GoogleFonts.cairo(
              color: filter.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // === جمع الفلاتر النشطة ===
  List<_ActiveFilter> _getActiveFilters() {
    final List<_ActiveFilter> filters = [];

    if (selectedEmployeeId != null) {
      final emp = filterLists.employees.firstWhere(
        (e) => e.employeeId == selectedEmployeeId,
        orElse: () => FilterEmployee(employeeId: 0, fullName: 'غير معروف'),
      );
      filters.add(_ActiveFilter(
        icon: Icons.person,
        label: emp.fullName,
        color: const Color(0xFF4CAF50),
      ));
    }

    if (selectedSourceId != null) {
      final src = filterLists.sources.firstWhere(
        (e) => e.sourceId == selectedSourceId,
        orElse: () => FilterSource(sourceId: 0, name: 'غير معروف'),
      );
      filters.add(_ActiveFilter(
        icon: Icons.source,
        label: src.name,
        color: const Color(0xFF2196F3),
      ));
    }

    if (selectedStageId != null) {
      final stg = filterLists.stages.firstWhere(
        (e) => e.stageId == selectedStageId,
        orElse: () => FilterStage(stageId: 0, name: 'غير معروف'),
      );
      filters.add(_ActiveFilter(
        icon: Icons.stairs,
        label: stg.name,
        color: const Color(0xFF9C27B0),
      ));
    }

    if (selectedAdTypeId != null) {
      final adt = filterLists.adTypes.firstWhere(
        (e) => e.adTypeId == selectedAdTypeId,
        orElse: () => FilterAdType(adTypeId: 0, name: 'غير معروف'),
      );
      filters.add(_ActiveFilter(
        icon: Icons.campaign,
        label: adt.name,
        color: const Color(0xFFFF9800),
      ));
    }

    return filters;
  }
}

// === Model داخلي للفلتر النشط ===
class _ActiveFilter {
  final IconData icon;
  final String label;
  final Color color;

  _ActiveFilter({
    required this.icon,
    required this.label,
    required this.color,
  });
}