import 'package:flutter/material.dart';

import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';

/// منتقي شهر تقويمي قابل لإعادة الاستخدام: حوار بشريط سنة وشبكة
/// اثني عشر شهرًا بأسمائها العربية — اختيار الشهر نقرة واحدة تُرجع
/// القيمة فورًا بصيغة «yyyy-MM»، ولا اختيار أيام إطلاقًا.
/// يُستخدم في كل مواضع اختيار الشهور (نموذج السلفة، حوارات الأقساط،
/// فلتر أقساط الشهر) بدل حقول النص ذات الصيغة اليدوية.

const List<String> arabicMonthNames = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// «2026-10» من (السنة، الشهر)
String formatMonthValue(int year, int month) =>
    '$year-${month.toString().padLeft(2, '0')}';

/// تحليل «yyyy-MM» — يرجع null عند أي صيغة غير سليمة
({int year, int month})? parseMonthValue(String? value) {
  final m = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(value ?? '');
  if (m == null) return null;
  return (year: int.parse(m.group(1)!), month: int.parse(m.group(2)!));
}

/// «أكتوبر 2026» من «2026-10»
String monthLabel(String? value, {String fallback = '—'}) {
  final p = parseMonthValue(value);
  if (p == null) return fallback;
  return '${arabicMonthNames[p.month - 1]} ${p.year}';
}

/// يفتح منتقي الشهر ويُرجع «yyyy-MM» عند الاختيار أو null عند التراجع
Future<String?> showMonthPicker({
  required BuildContext context,
  String? initial,
  int minYear = 2020,
  int maxYear = 2035,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _MonthPickerDialog(
      initial: initial,
      minYear: minYear,
      maxYear: maxYear,
    ),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  final String? initial;
  final int minYear;
  final int maxYear;

  const _MonthPickerDialog({
    required this.initial,
    required this.minYear,
    required this.maxYear,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late final ({int year, int month})? _selected;

  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    final parsed = parseMonthValue(widget.initial);
    _selected = parsed;
    final now = DateTime.now();
    _year = (parsed?.year ?? now.year)
        .clamp(widget.minYear, widget.maxYear);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    return Dialog(
      backgroundColor: AppColors.surface(_isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppGradients.identityHeader,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'اختيار الشهر',
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'السنة السابقة',
                        onPressed: _year > widget.minYear
                            ? () => setState(() => _year--)
                            : null,
                        icon: Icon(
                          Icons.remove_rounded,
                          color: _year > widget.minYear
                              ? AppColors.text(_isDark)
                              : AppColors.textHint(_isDark),
                        ),
                      ),
                      Text(
                        '$_year',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.text(_isDark),
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                      ),
                      IconButton(
                        tooltip: 'السنة التالية',
                        onPressed: _year < widget.maxYear
                            ? () => setState(() => _year++)
                            : null,
                        icon: Icon(
                          Icons.add_rounded,
                          color: _year < widget.maxYear
                              ? AppColors.text(_isDark)
                              : AppColors.textHint(_isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.1,
                    ),
                    itemCount: 12,
                    itemBuilder: (_, i) {
                      final month = i + 1;
                      final sel = _selected;
                      final isSelected = sel != null &&
                          sel.year == _year &&
                          sel.month == month;
                      final isCurrent =
                          now.year == _year && now.month == month;
                      final bg = isSelected
                          ? (_isDark ? AppColors.gold : AppColors.navy)
                          : (_isDark
                              ? AppColors.card(_isDark)
                              : AppColors.inputFill(_isDark));
                      final fg = isSelected
                          ? (_isDark ? AppColors.navy : Colors.white)
                          : AppColors.text(_isDark);
                      return Material(
                        color: bg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: () => Navigator.pop(
                            context,
                            formatMonthValue(_year, month),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                              border: isCurrent && !isSelected
                                  ? Border.all(
                                      color: ThemeService().accentColor,
                                      width: 1.2,
                                    )
                                  : null,
                            ),
                            child: Text(
                              arabicMonthNames[i],
                              style: textTheme.bodyMedium?.copyWith(
                                color: fg,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'تراجع',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary(_isDark),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حقل شهر قابل للنقر يفتح [showMonthPicker] — يعرض اسم الشهر العربي
/// بدل الصيغة الرقمية، وزر مسح اختياري حين تكون القيمة قابلة للإفراغ.
class MonthField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final bool isRequired;
  final bool clearable;
  final String? error;
  final ValueChanged<String?> onChanged;

  const MonthField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = 'اختر الشهر',
    this.isRequired = false,
    this.clearable = false,
    this.error,
  });

  bool get _hasValue => parseMonthValue(value) != null;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary(isDark),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: textTheme.labelLarge?.copyWith(
                  color: isDark ? AppColors.errorLight : AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Material(
          color: isDark ? AppColors.card(isDark) : AppColors.inputFill(isDark),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () async {
              final picked = await showMonthPicker(
                context: context,
                initial: value,
              );
              if (picked != null) onChanged(picked);
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 19,
                    color: AppColors.textSecondary(isDark),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _hasValue ? monthLabel(value) : hint,
                      style: textTheme.bodyLarge?.copyWith(
                        color: _hasValue
                            ? AppColors.text(isDark)
                            : AppColors.textHint(isDark),
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  if (clearable && _hasValue)
                    IconButton(
                      tooltip: 'مسح الشهر',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onChanged(null),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 18,
                    color: AppColors.textHint(isDark),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.errorLight : AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
