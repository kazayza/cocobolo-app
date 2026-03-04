import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/permission_service.dart';
import 'lookup_manage_screen.dart';

class CrmSettingsScreen extends StatelessWidget {
  final int userId;
  final String username;

  const CrmSettingsScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  bool get _isDark => ThemeService().isDarkMode;

  @override
  Widget build(BuildContext context) {
    final permissions = PermissionService();

    // تعريف الأقسام والعناصر
    final sections = <_SettingsSection>[
  // 📢 قسم التسويق
  _SettingsSection(
    title: 'التسويق',
    icon: Icons.campaign_rounded,
    color: const Color(0xFFE91E63),
    items: [
      if (permissions.canView(FormNames.adCampaigns))
        _SettingsItem(
          title: 'الحملات الإعلانية',
          subtitle: 'إدارة أنواع الإعلانات والحملات',
          icon: Icons.campaign_rounded,
          color: const Color(0xFFE91E63),
          formName: FormNames.adCampaigns,
          lookupConfig: LookupConfig(
            title: 'الحملات الإعلانية',
            apiPath: 'ad-types',
            icon: Icons.campaign_rounded,
            color: const Color(0xFFE91E63),
            formName: FormNames.adCampaigns,
            hasIcon: false,
            hasColor: false,
          ),
        ),
    ],
  ),

  // 📞 قسم التواصل
  _SettingsSection(
    title: 'المصادر',
    icon: Icons.phone_in_talk_rounded,
    color: const Color(0xFF2196F3),
    items: [
      if (permissions.canView(FormNames.contactSources))
        _SettingsItem(
          title: 'مصادر العملاء',
          subtitle: 'إدارة مصادر العملاء',
          icon: Icons.source_rounded,
          color: const Color(0xFF2196F3),
          formName: FormNames.contactSources,
          lookupConfig: LookupConfig(
            title: 'مصادر العملاء',
            apiPath: 'sources',
            icon: Icons.source_rounded,
            color: const Color(0xFF2196F3),
            formName: FormNames.contactSources,
            hasIcon: true,
            hasColor: false,
          ),
        ),
      if (permissions.canView(FormNames.contactStatuses))
        _SettingsItem(
          title: 'حالات التواصل',
          subtitle: 'إدارة حالات التواصل مع العملاء',
          icon: Icons.info_outline_rounded,
          color: const Color(0xFF00BCD4),
          formName: FormNames.contactStatuses,
          lookupConfig: LookupConfig(
            title: 'حالات التواصل',
            apiPath: 'statuses',
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF00BCD4),
            formName: FormNames.contactStatuses,
            hasIcon: false,
            hasColor: false,
          ),
        ),
    ],
  ),

  // 📊 قسم البيع
  _SettingsSection(
    title: 'البيع',
    icon: Icons.trending_up_rounded,
    color: const Color(0xFF4CAF50),
    items: [
      if (permissions.canView(FormNames.salesStages))
        _SettingsItem(
          title: 'مراحل البيع',
          subtitle: 'إدارة مراحل عملية البيع',
          icon: Icons.stairs_rounded,
          color: const Color(0xFF4CAF50),
          formName: FormNames.salesStages,
          lookupConfig: LookupConfig(
            title: 'مراحل البيع',
            apiPath: 'stages',
            icon: Icons.stairs_rounded,
            color: const Color(0xFF4CAF50),
            formName: FormNames.salesStages,
            hasIcon: false,
            hasColor: true,
          ),
        ),
      if (permissions.canView(FormNames.interestCategories))
        _SettingsItem(
          title: 'فئات الاهتمام',
          subtitle: 'إدارة فئات اهتمام العملاء',
          icon: Icons.category_rounded,
          color: const Color(0xFFFF9800),
          formName: FormNames.interestCategories,
          lookupConfig: LookupConfig(
            title: 'فئات الاهتمام',
            apiPath: 'categories',
            icon: Icons.category_rounded,
            color: const Color(0xFFFF9800),
            formName: FormNames.interestCategories,
            hasIcon: false,
            hasColor: false,
          ),
        ),
      if (permissions.canView(FormNames.lostReasons))
        _SettingsItem(
          title: 'أسباب الخسارة',
          subtitle: 'إدارة أسباب خسارة الفرص',
          icon: Icons.thumb_down_rounded,
          color: const Color(0xFFF44336),
          formName: FormNames.lostReasons,
          lookupConfig: LookupConfig(
            title: 'أسباب الخسارة',
            apiPath: 'lost-reasons',
            icon: Icons.thumb_down_rounded,
            color: const Color(0xFFF44336),
            formName: FormNames.lostReasons,
            hasIcon: false,
            hasColor: false,
          ),
        ),
    ],
  ),

  // ✅ قسم المهام
  _SettingsSection(
    title: 'المهام',
    icon: Icons.task_alt_rounded,
    color: const Color(0xFF9C27B0),
    items: [
      if (permissions.canView(FormNames.taskTypes))
        _SettingsItem(
          title: 'أنواع المهام',
          subtitle: 'إدارة أنواع المهام والمتابعات',
          icon: Icons.checklist_rounded,
          color: const Color(0xFF9C27B0),
          formName: FormNames.taskTypes,
          lookupConfig: LookupConfig(
            title: 'أنواع المهام',
            apiPath: 'task-types',
            icon: Icons.checklist_rounded,
            color: const Color(0xFF9C27B0),
            formName: FormNames.taskTypes,
            hasIcon: false,
            hasColor: false,
          ),
        ),
    ],
  ),
];

    // فلترة الأقسام الفارغة
    final visibleSections = sections.where((s) => s.items.isNotEmpty).toList();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: _buildAppBar(context),
        body: visibleSections.isEmpty
            ? _buildNoPermissionView()
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: visibleSections.length,
                itemBuilder: (context, index) {
                  final section = visibleSections[index];
                  return _buildSection(context, section, index);
                },
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _isDark ? AppColors.navy : Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(
        color: _isDark ? Colors.white : AppColors.navy,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.settings_rounded, color: AppColors.gold, size: 24),
          const SizedBox(width: 8),
          Text(
            'إعدادات CRM',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: _isDark ? Colors.white : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, _SettingsSection section, int sectionIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان القسم
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: section.color.withOpacity(_isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(section.icon, color: section.color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                section.title,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(_isDark),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(
              duration: 300.ms,
              delay: Duration(milliseconds: sectionIndex * 100),
            ),

        // العناصر
        ...List.generate(section.items.length, (index) {
          final item = section.items[index];
          return _buildSettingsCard(context, item, sectionIndex, index);
        }),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    _SettingsItem item,
    int sectionIndex,
    int itemIndex,
  ) {
    final permissions = PermissionService();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LookupManageScreen(
                  userId: userId,
                  username: username,
                  config: item.lookupConfig,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.color.withOpacity(_isDark ? 0.3 : 0.1),
              ),
            ),
            child: Row(
              children: [
                // الأيقونة
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(_isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                const SizedBox(width: 14),

                // النص
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(_isDark),
                        ),
                      ),
                      Text(
                        item.subtitle,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.textSecondary(_isDark),
                        ),
                      ),
                    ],
                  ),
                ),

                // شارات الصلاحيات
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (permissions.canAdd(item.formName))
                      _buildPermBadge('إضافة', Colors.green),
                    if (permissions.canEdit(item.formName))
                      _buildPermBadge('تعديل', Colors.blue),
                    if (permissions.canDelete(item.formName))
                      _buildPermBadge('حذف', Colors.red),
                  ],
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.textHint(_isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
          duration: 300.ms,
          delay: Duration(milliseconds: (sectionIndex * 100) + (itemIndex * 50)),
        ).slideX(begin: 0.1, end: 0);
  }

  Widget _buildPermBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNoPermissionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_rounded, size: 80, color: AppColors.textHint(_isDark)),
          const SizedBox(height: 16),
          Text(
            'لا توجد صلاحيات',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: AppColors.textSecondary(_isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ليس لديك صلاحية للوصول لإعدادات CRM',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textHint(_isDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================
// 📦 Models
// ===================================

class _SettingsSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<_SettingsItem> items;

  _SettingsSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _SettingsItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String formName;
  final LookupConfig lookupConfig;

  _SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.formName,
    required this.lookupConfig,
  });
}