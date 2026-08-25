import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/home/widgets/home_accent.dart';
import '../features/home/widgets/profile_avatar.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/profile_avatar_service.dart';
import '../services/theme_service.dart';
import '../services/update_service.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

/// ─────────────────────────────────────────────────────────────
///  الإعدادات — إعادة تصميم بهوية COCOBOLO (Navy × Gold)
///  - Theme-aware بالكامل (نهاري / ليلي)
///  - ترويسة متدرجة + بطاقة ملف شخصي + أقسام ملونة
/// ─────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String? fullName;

  const SettingsScreen({
    Key? key,
    required this.userId,
    required this.username,
    this.fullName,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  late bool _darkMode = ThemeService().isDarkMode;
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    // تحميل الصورة الشخصية المحفوظة عند فتح الإعدادات
    ProfileAvatarService().load();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      debugPrint('Error loading app version: $e');
    }
  }

  String _getInitials() {
    final name = widget.fullName ?? widget.username;
    if (name.isEmpty) return 'م';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getRoleTitle() {
    final role = PermissionService().role?.toLowerCase();
    switch (role) {
      case 'admin':
        return 'المدير العام';
      case 'salesmanager':
        return 'مدير المبيعات';
      case 'sales':
        return 'موظف مبيعات';
      case 'accountmanager':
        return 'مدير الحسابات';
      case 'account':
        return 'موظف حسابات';
      case 'warehouse':
        return 'أمين المخزن';
      case 'cashier':
        return 'أمين الخزينة';
      default:
        return 'مستخدم';
    }
  }

  Color _getRoleColor() {
    final role = PermissionService().role?.toLowerCase();
    switch (role) {
      case 'admin':
        return HomeAccent.gold;
      case 'salesmanager':
        return const Color(0xFF4CAF50);
      case 'sales':
        return const Color(0xFF2196F3);
      case 'accountmanager':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }

  void _showLogoutDialog() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد تسجيل الخروج من التطبيق؟',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'خروج',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    PermissionService().clear();
    NotificationService().stopPolling();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('fullName');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── الترويسة المتدرجة ──────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
            foregroundColor: isDark ? Colors.white : HomeAccent.navy,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: isDark
                        ? const [
                            HomeAccent.navyDark,
                            HomeAccent.navy,
                            HomeAccent.navyLight,
                          ]
                        : const [
                            HomeAccent.navy,
                            HomeAccent.navyLight,
                            Color(0xFF2C4E77),
                          ],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'الإعدادات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── بطاقة الملف الشخصي ──────────────────
                  _buildProfileCard(),

                  const SizedBox(height: 20),

                  // ── إعدادات التطبيق ─────────────────────
                  _buildSection(
                    title: 'إعدادات التطبيق',
                    icon: Icons.settings_rounded,
                    color: HomeAccent.indigo,
                    children: [
                      _buildNavigationTile(
                        icon: Icons.person_rounded,
                        title: 'الصورة الشخصية',
                        color: HomeAccent.indigo,
                        onTap: _showAvatarSheet,
                      ),
                      _buildSwitchTile(
                        icon: Icons.notifications_rounded,
                        title: 'الإشعارات',
                        subtitle: 'تفعيل/إيقاف الإشعارات',
                        value: _notificationsEnabled,
                        color: HomeAccent.cyan,
                        onChanged: (value) =>
                            setState(() => _notificationsEnabled = value),
                      ),
                      _buildSwitchTile(
                        icon: Icons.dark_mode_rounded,
                        title: 'الوضع الليلي',
                        subtitle: 'تبديل بين الوضع الليلي والنهاري',
                        value: _darkMode,
                        color: HomeAccent.purple,
                        onChanged: (value) {
                          setState(() => _darkMode = value);
                          ThemeService().setDarkMode(value);
                        },
                      ),
                      _buildNavigationTile(
                        icon: Icons.lock_rounded,
                        title: 'تغيير كلمة المرور',
                        color: HomeAccent.amber,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChangePasswordScreen(
                                userId: widget.userId,
                                username: widget.username,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── معلومات ─────────────────────────────
                  _buildSection(
                    title: 'معلومات',
                    icon: Icons.info_rounded,
                    color: HomeAccent.teal,
                    children: [
                      _buildNavigationTile(
                        icon: Icons.description_rounded,
                        title: 'سياسة الخصوصية',
                        color: HomeAccent.blueGrey,
                        onTap: () => _showPrivacyPolicyDialog(),
                      ),
                      _buildNavigationTile(
                        icon: Icons.help_rounded,
                        title: 'المساعدة والدعم',
                        color: HomeAccent.cyan,
                        onTap: () => _showHelpDialog(),
                      ),
                      _buildNavigationTile(
                        icon: Icons.info_rounded,
                        title: 'عن التطبيق',
                        color: const Color(0xFF43A047),
                        onTap: () => _showAboutDialog(),
                      ),
                      _buildNavigationTile(
                        icon: Icons.system_update_rounded,
                        title: 'التحقق من التحديثات',
                        color: const Color(0xFF3B82F6),
                        onTap: _checkForUpdates,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── الصلاحيات ───────────────────────────
                  _buildSection(
                    title: 'الصلاحيات',
                    icon: Icons.security_rounded,
                    color: HomeAccent.pink,
                    children: [
                      _buildNavigationTile(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'عرض الصلاحيات',
                        color: HomeAccent.pink,
                        onTap: () => _showPermissionsDialog(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── زر تسجيل الخروج ─────────────────────
                  _buildLogoutButton(),

                  const SizedBox(height: 28),

                  // ── معلومات الإصدار ─────────────────────
                  _buildVersionInfo(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // بطاقة الملف الشخصي
  // ═══════════════════════════════════════════════════════════

  Widget _buildProfileCard() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColor = _getRoleColor();
    final displayName = widget.fullName ?? widget.username;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: HomeAccent.gold.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: HomeAccent.gold.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // أفاتار (صورة المستخدم أو الحرف) بحلقة ذهبية
          ProfileAvatar(initial: _getInitials(), size: 56, goldRing: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isEmpty ? 'المستخدم' : displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: roleColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: roleColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getRoleTitle(),
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // ═══════════════════════════════════════════════════════════
  // القسم
  // ═══════════════════════════════════════════════════════════

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ترويسة القسم
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.4)],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // البطاقات
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 60,
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // البلاطات
  // ═══════════════════════════════════════════════════════════

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeTrackColor: color.withValues(alpha: 0.6),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Icon(
        Directionality.of(context) == TextDirection.rtl
            ? Icons.chevron_left_rounded
            : Icons.chevron_right_rounded,
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // زر الخروج + معلومات الإصدار
  // ═══════════════════════════════════════════════════════════

  Widget _buildLogoutButton() {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.red.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _showLogoutDialog,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.30)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          'COCOBOLO',
          style: TextStyle(
            color: HomeAccent.gold,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _appVersion.isNotEmpty
              ? 'الإصدار $_appVersion${_buildNumber.isNotEmpty ? ' ($_buildNumber)' : ''}'
              : 'جاري تحميل الإصدار...',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          '© ${DateTime.now().year} COCOBOLO - جميع الحقوق محفوظة',
          style: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),
        // توقيع المصمم
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: HomeAccent.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomeAccent.gold.withValues(alpha: 0.2)),
          ),
          child: Text(
            'تصميم وتطوير: أحمد الرفاعى',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // الصورة الشخصية
  // ═══════════════════════════════════════════════════════════

  void _showAvatarSheet() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarService = ProfileAvatarService();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'الصورة الشخصية',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'تظهر في الشاشة الرئيسية والقائمة الجانبية',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // معاينة
                  ProfileAvatar(
                    initial: _getInitials(),
                    size: 64,
                    goldRing: true,
                  ),
                  const SizedBox(width: 16),
                  // المعرض
                  Expanded(
                    child: _AvatarAction(
                      icon: Icons.photo_library_rounded,
                      label: 'من المعرض',
                      color: HomeAccent.indigo,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSave(avatarService, ImageSource.gallery);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // الكاميرا
                  Expanded(
                    child: _AvatarAction(
                      icon: Icons.photo_camera_rounded,
                      label: 'كاميرا',
                      color: HomeAccent.teal,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndSave(avatarService, ImageSource.camera);
                      },
                    ),
                  ),
                ],
              ),
              if (avatarService.imagePath != null) ...[
                const SizedBox(height: 12),
                // إزالة
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      avatarService.remove();
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    label: const Text(
                      'إزالة الصورة',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// اختيار الصورة + حفظها + رسالة تأكيد
  Future<void> _pickAndSave(
    ProfileAvatarService avatarService,
    ImageSource source,
  ) async {
    final path = await avatarService.pickAndSave(source);
    if (!mounted) return;

    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ الصورة الشخصية'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          margin: EdgeInsets.all(16),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // سياسة الخصوصية
  // ═══════════════════════════════════════════════════════════

  void _showPrivacyPolicyDialog() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HomeAccent.blueGrey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.privacy_tip_rounded,
                color: HomeAccent.blueGrey,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'سياسة الخصوصية',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: ListView(
            children: [
              _PrivacySection(
                title: '1. البيانات التي نجمعها',
                body:
                    'يقوم تطبيق COCOBOLO بجمع البيانات اللازمة فقط لتشغيل النظام: '
                    'بيانات الحساب (الاسم، اسم المستخدم، البريد الإلكتروني)، '
                    'بيانات العملاء والمبيعات والمصروفات المرتبطة بدورك الوظيفي، '
                    'وتسجيلات الحضور والانصراف الخاصة بك.',
                scheme: scheme,
              ),
              _PrivacySection(
                title: '2. كيفية استخدام البيانات',
                body:
                    'تُستخدم البيانات حصراً لأغراض تشغيل النظام وتقديم الخدمة: '
                    'إدارة علاقات العملاء (CRM)، متابعة المبيعات، إعداد التقارير، '
                    'وإشعارات العمل. لا تُستخدم بياناتك لأي غرض تسويقي خارجي.',
                scheme: scheme,
              ),
              _PrivacySection(
                title: '3. حماية البيانات',
                body:
                    'نستخدم إجراءات أمنية متوافقة مع المعايير لحماية بياناتك: '
                    'تشفير كلمات المرور (bcrypt)، وضوابط وصول صارمة حسب الصلاحيات، '
                    'وتسجيل نشاط النظام للمراجعة. يبقى وصولك للبيانات محدوداً '
                    'بصلاحياتك المعتمدة من الإدارة.',
                scheme: scheme,
              ),
              _PrivacySection(
                title: '4. مشاركة البيانات',
                body:
                    'لا نبيع بياناتك ولا نشاركها مع أي طرف خارجي. تبقى بياناتك '
                    'داخل نظام الشركة فقط، وتظهر للمستخدمين الآخرين وفق صلاحياتهم '
                    'المحددة من إدارة النظام.',
                scheme: scheme,
              ),
              _PrivacySection(
                title: '5. التعديلات على السياسة',
                body:
                    'قد نقوم بتحديث سياسة الخصوصية من وقت لآخر. أي تغييرات '
                    'تُنشر داخل التطبيق، واستمرار استخدامك للنظام يعني موافقتك '
                    'على السياسة المحدثة.',
                scheme: scheme,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إغلاق',
              style: TextStyle(
                color: HomeAccent.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // المساعدة والدعم
  // ═══════════════════════════════════════════════════════════

  void _showHelpDialog() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HomeAccent.cyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: HomeAccent.cyan,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'المساعدة والدعم',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'كيف يمكننا مساعدتك؟',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            // الأسئلة الشائعة
            _HelpItem(
              icon: Icons.help_outline_rounded,
              title: 'الأسئلة الشائعة',
              subtitle: 'إجابات سريعة لأكثر الأسئلة تكراراً',
              color: HomeAccent.indigo,
              onTap: () {
                Navigator.pop(context);
                _showFaqDialog();
              },
            ),
            const SizedBox(height: 10),
            // تواصل مع الدعم
            _HelpItem(
              icon: Icons.headset_mic_rounded,
              title: 'تواصل مع الدعم الفني',
              subtitle: 'أرسل استفسارك وسنرد عليك في أقرب وقت',
              color: HomeAccent.teal,
              onTap: () {
                Navigator.pop(context);
                _showContactSupportDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إغلاق',
              style: TextStyle(
                color: HomeAccent.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFaqDialog() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'الأسئلة الشائعة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: ListView(
            children: [
              _FaqItem(
                q: 'نسيت كلمة المرور، ماذا أفعل؟',
                a: 'تواصل مع مدير النظام أو مسؤول الصلاحيات لإعادة تعيين كلمة المرور الخاصة بك.',
                scheme: scheme,
              ),
              _FaqItem(
                q: 'لا أرى بعض الشاشات في القائمة؟',
                a: 'ظهور الشاشات يعتمد على الصلاحيات الممنوحة لحسابك. تواصل مع الإدارة إذا كنت تحتاج صلاحية إضافية.',
                scheme: scheme,
              ),
              _FaqItem(
                q: 'كيف أغير كلمة المرور؟',
                a: 'من الإعدادات ← تغيير كلمة المرور، وأدخل كلمة المرور الحالية ثم الجديدة (8 أحرف على الأقل).',
                scheme: scheme,
              ),
              _FaqItem(
                q: 'التطبيق لا يعمل بالشكل المطلوب؟',
                a: 'تأكد من اتصال الإنترنت، وحاول إعادة تشغيل التطبيق. إذا استمرت المشكلة تواصل مع الدعم الفني.',
                scheme: scheme,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إغلاق',
              style: TextStyle(
                color: HomeAccent.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'تواصل مع الدعم الفني',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'فريق الدعم الفني جاهز لمساعدتك',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            _ContactRow(
              icon: Icons.email_rounded,
              label: 'البريد الإلكتروني',
              value: 'support@cocobolo.com',
              color: HomeAccent.indigo,
            ),
            const SizedBox(height: 12),
            _ContactRow(
              icon: Icons.phone_rounded,
              label: 'الهاتف',
              value: '02-12345678',
              color: HomeAccent.teal,
            ),
            const SizedBox(height: 12),
            _ContactRow(
              icon: Icons.access_time_rounded,
              label: 'ساعات العمل',
              value: 'الأحد - الخميس، 9ص - 5م',
              color: HomeAccent.amber,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إغلاق',
              style: TextStyle(
                color: HomeAccent.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.construction_rounded,
              color: Colors.amber,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text('$feature - قريباً! 🚀'),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showAboutDialog() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            // لوجو التطبيق
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HomeAccent.navyDark, HomeAccent.navyLight],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: HomeAccent.gold.withValues(alpha: 0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.diamond_rounded,
                    color: HomeAccent.gold,
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'COCOBOLO',
              style: TextStyle(
                color: HomeAccent.gold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نظام إدارة متكامل للمبيعات والعملاء',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildAboutRow(
              'الإصدار',
              _appVersion.isNotEmpty ? _appVersion : '...',
            ),
            _buildAboutRow(
              'البناء',
              _buildNumber.isNotEmpty ? _buildNumber : '...',
            ),
            _buildAboutRow('المطور', 'احمد الرفاعى'),
            _buildAboutRow('السنة', '${DateTime.now().year}'),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: HomeAccent.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'تصميم وتطوير: أحمد الرفاعى',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إغلاق',
              style: TextStyle(
                color: HomeAccent.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // التحقق من التحديثات
  // ═══════════════════════════════════════════════════════════

  bool _checkingUpdate = false;

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;

      if (info != null && info['hasUpdate'] == true) {
        // فيه تحديث → نفس ديالوج التحديث مع التحميل والتثبيت
        await UpdateService.showUpdateDialog(context: context, updateInfo: info);
      } else if (info != null) {
        // مفيش تحديث → ديالوج مطمئن
        await _showNoUpdateDialog(info);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر الاتصال بخادم التحديثات، تحقق من الإنترنت'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التحقق من التحديثات: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _showNoUpdateDialog(Map<String, dynamic> info) async {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentVersion = info['currentVersion']?.toString() ?? _appVersion;
    final latestVersion = info['latestVersion']?.toString() ?? _appVersion;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF43A047),
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'لا توجد تحديثات',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'أنت على أحدث إصدار',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HomeAccent.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HomeAccent.gold.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'نسختك الحالية',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentVersion,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: HomeAccent.gold,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.grey),
                  Column(
                    children: [
                      Text(
                        'أحدث نسخة',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latestVersion,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF43A047),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'حسناً',
              style: TextStyle(
                color: HomeAccent.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionsDialog() {
    final permissions = PermissionService().allPermissions;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13273F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HomeAccent.pink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.security_rounded,
                color: HomeAccent.pink,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'الصلاحيات',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: HomeAccent.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${permissions.length}',
                style: const TextStyle(
                  color: HomeAccent.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: permissions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 48,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد صلاحيات',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: permissions.length,
                  itemBuilder: (context, index) {
                    final entry = permissions.entries.elementAt(index);
                    final perm = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            perm.permissionName,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildPermBadge(
                                'عرض',
                                perm.canView,
                                const Color(0xFF2196F3),
                              ),
                              _buildPermBadge(
                                'إضافة',
                                perm.canAdd,
                                const Color(0xFF4CAF50),
                              ),
                              _buildPermBadge(
                                'تعديل',
                                perm.canEdit,
                                const Color(0xFFFF9800),
                              ),
                              _buildPermBadge(
                                'حذف',
                                perm.canDelete,
                                const Color(0xFFE91E63),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إغلاق',
              style: TextStyle(
                color: HomeAccent.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermBadge(String label, bool enabled, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? color.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled
              ? color.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: enabled ? color : Colors.grey.shade600,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// زر إجراء في شيت الصورة الشخصية (معرض / كاميرا)
class _AvatarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AvatarAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Widgets مساعدة لشاشة الإعدادات
// ═══════════════════════════════════════════════════════════

/// قسم في سياسة الخصوصية
class _PrivacySection extends StatelessWidget {
  final String title;
  final String body;
  final ColorScheme scheme;

  const _PrivacySection({
    required this.title,
    required this.body,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// بند في قائمة المساعدة
class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// سؤال وجواب في الأسئلة الشائعة
class _FaqItem extends StatelessWidget {
  final String q;
  final String a;
  final ColorScheme scheme;

  const _FaqItem({required this.q, required this.a, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help_rounded, size: 16, color: HomeAccent.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  q,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            a,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// صف تواصل (بريد / هاتف / ساعات)
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
