import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../core/auth/session_service.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';

/// خيار موظف في منتقيات البحث — من قائمة الموظفين النشطين
/// (/api/employees/active، نفس مصدر شاشات الشيفتات والاستثناءات).
class EmployeeOption {
  final int id;
  final String name;
  final String jobTitle;
  final String department;

  const EmployeeOption({
    required this.id,
    required this.name,
    this.jobTitle = '',
    this.department = '',
  });

  String get subtitle =>
      [jobTitle, department].where((s) => s.isNotEmpty).join(' • ');

  factory EmployeeOption.fromJson(Map<String, dynamic> json) {
    return EmployeeOption(
      id: (json['EmployeeID'] as num?)?.toInt() ??
          (json['EmployeeId'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      name: json['FullName']?.toString() ??
          json['fullName']?.toString() ??
          json['employeeName']?.toString() ??
          '',
      jobTitle: json['JobTitle']?.toString() ?? '',
      department: json['Department']?.toString() ?? '',
    );
  }
}

/// جلب الموظفين النشطين لمنتقي — [excludeId] يُستبعد من القائمة
/// (موظف لا يكون مديرًا مباشرًا لنفسه في وضع التعديل).
Future<List<EmployeeOption>> fetchActiveEmployeeOptions({
  int? excludeId,
}) async {
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/api/employees/active'),
      headers: SessionService.instance.authHeaders,
    );
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => EmployeeOption.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id > 0 && e.id != excludeId)
        .toList();
  } catch (_) {
    return [];
  }
}

/// ورقة اختيار موظف قابلة للبحث: حقل بحث يرشّح محليًا فوق القائمة
/// المحمّلة، وصفوف باسم الموظف ومسماه وقسمه.
Future<EmployeeOption?> showEmployeePickerSheet(
  BuildContext context, {
  required List<EmployeeOption> employees,
  String title = 'اختر الموظف',
}) {
  final isDark = ThemeService().isDarkMode;
  return showModalBottomSheet<EmployeeOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      var query = '';
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = query.trim().isEmpty
              ? employees
              : employees
                  .where((e) =>
                      e.name.contains(query.trim()) ||
                      e.jobTitle.contains(query.trim()) ||
                      e.department.contains(query.trim()))
                  .toList();
          final textTheme = Theme.of(context).textTheme;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.text(isDark),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setSheetState(() => query = v),
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.text(isDark),
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو المسمى أو القسم...',
                        hintStyle: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textHint(isDark),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondary(isDark),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.card(isDark)
                            : AppColors.inputFill(isDark),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: ThemeService().accentColor),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد نتائج مطابقة',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final emp = filtered[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.gold
                                      .withValues(alpha: isDark ? 0.18 : 0.15),
                                  child: Text(
                                    emp.name.isNotEmpty
                                        ? emp.name[0].toUpperCase()
                                        : '؟',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: isDark
                                          ? AppColors.gold
                                          : AppColors.navy,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  emp.name,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: AppColors.text(isDark),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: emp.subtitle.isEmpty
                                    ? null
                                    : Text(
                                        emp.subtitle,
                                        style: textTheme.bodySmall?.copyWith(
                                          color:
                                              AppColors.textSecondary(isDark),
                                        ),
                                      ),
                                onTap: () => Navigator.pop(context, emp),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// حقل منتقي موظف بعرض النموذج: تسمية فوق صندوق ممتلئ يعرض الاسم
/// المختار أو تلميحًا، مع زر مسح عند الإتاحة (اختياري/قابل للمسح)،
/// وحالة مقفلة (موظف مثبّت من سياق الشاشة الأم) بلا تفاعل.
class EmployeePickerField extends StatelessWidget {
  final String label;
  final EmployeeOption? selected;
  final String hint;
  final bool locked;
  final bool clearable;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const EmployeePickerField({
    super.key,
    required this.label,
    required this.selected,
    this.hint = 'اختر الموظف...',
    this.locked = false,
    this.clearable = false,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;
    final textTheme = Theme.of(context).textTheme;
    final fill =
        isDark ? AppColors.card(isDark) : AppColors.inputFill(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: AppColors.textSecondary(isDark),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_search_rounded,
                  size: 19,
                  color: AppColors.textSecondary(isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected?.name ?? hint,
                        style: textTheme.bodyLarge?.copyWith(
                          color: selected == null
                              ? AppColors.textHint(isDark)
                              : AppColors.text(isDark),
                          fontSize: 14,
                        ),
                      ),
                      if (selected != null && selected!.subtitle.isNotEmpty)
                        Text(
                          selected!.subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary(isDark),
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
                if (clearable && selected != null && !locked)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary(isDark),
                    ),
                    onPressed: onClear,
                    visualDensity: VisualDensity.compact,
                  )
                else if (!locked)
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary(isDark),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
