import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'login_screen.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import 'change_password_screen.dart';

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
  bool _darkMode = true;
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
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
      case 'admin': return 'المدير العام';
      case 'salesmanager': return 'مدير المبيعات';
      case 'sales': return 'موظف مبيعات';
      case 'accountmanager': return 'مدير الحسابات';
      case 'account': return 'موظف حسابات';
      case 'warehouse': return 'أمين المخزن';
      case 'cashier': return 'أمين الخزينة';
      default: return 'مستخدم';
    }
  }

  Color _getRoleColor() {
    final role = PermissionService().role?.toLowerCase();
    switch (role) {
      case 'admin': return const Color(0xFFFFD700);
      case 'salesmanager': return const Color(0xFF4CAF50);
      case 'sales': return const Color(0xFF2196F3);
      case 'accountmanager': return const Color(0xFF9C27B0);
      default: return const Color(0xFF607D8B);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'هل تريد تسجيل الخروج من التطبيق؟',
          style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('خروج', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          // App Bar
          _buildSliverAppBar(),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // بطاقة الملف الشخصي
                  _buildProfileCard(),
                  
                  const SizedBox(height: 24),
                  
                  // إعدادات التطبيق
                  _buildSection(
                    title: 'إعدادات التطبيق',
                    icon: Icons.settings_rounded,
                    color: const Color(0xFF2196F3),
                    children: [
                      _buildSwitchTile(
                        icon: Icons.notifications_rounded,
                        title: 'الإشعارات',
                        subtitle: 'تفعيل/إيقاف الإشعارات',
                        value: _notificationsEnabled,
                        onChanged: (value) => setState(() => _notificationsEnabled = value),
                      ),
                      _buildSwitchTile(
                        icon: Icons.dark_mode_rounded,
                        title: 'الوضع الليلي',
                        subtitle: 'مفعّل دائماً',
                        value: _darkMode,
                        onChanged: null,
                      ),
                      _buildNavigationTile(
                        icon: Icons.lock_rounded,
                        title: 'تغيير كلمة المرور',
                        color: const Color(0xFFFF9800),
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
                  
                  // معلومات
                  _buildSection(
                    title: 'معلومات',
                    icon: Icons.info_rounded,
                    color: const Color(0xFF9C27B0),
                    children: [
                      _buildNavigationTile(
                        icon: Icons.description_rounded,
                        title: 'سياسة الخصوصية',
                        color: const Color(0xFF607D8B),
                        onTap: () => _showComingSoon('سياسة الخصوصية'),
                      ),
                      _buildNavigationTile(
                        icon: Icons.help_rounded,
                        title: 'المساعدة والدعم',
                        color: const Color(0xFF00BCD4),
                        onTap: () => _showComingSoon('المساعدة'),
                      ),
                      _buildNavigationTile(
                        icon: Icons.info_rounded,
                        title: 'عن التطبيق',
                        color: const Color(0xFF4CAF50),
                        onTap: () => _showAboutDialog(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // الصلاحيات
                  _buildSection(
                    title: 'الصلاحيات',
                    icon: Icons.security_rounded,
                    color: const Color(0xFFE91E63),
                    children: [
                      _buildNavigationTile(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'عرض الصلاحيات',
                        color: const Color(0xFFE91E63),
                        onTap: () => _showPermissionsDialog(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // زر تسجيل الخروج
                  _buildLogoutButton(),
                  
                  const SizedBox(height: 32),
                  
                  // معلومات الإصدار
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'الإعدادات',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFE8B923).withOpacity(0.3),
                const Color(0xFF1A1A1A),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getRoleColor().withOpacity(0.15),
            _getRoleColor().withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getRoleColor().withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // صورة المستخدم
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_getRoleColor(), _getRoleColor().withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _getRoleColor().withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitials(),
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // معلومات المستخدم
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fullName ?? widget.username,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '@${widget.username}',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRoleColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getRoleTitle(),
                        style: GoogleFonts.cairo(
                          color: _getRoleColor(),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'متصل',
                      style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // أيقونة التعديل
          IconButton(
            onPressed: () => _showComingSoon('تعديل الملف الشخصي'),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit_rounded, color: _getRoleColor(), size: 20),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          // Content
          ...children,
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8B923).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFE8B923), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFE8B923),
            inactiveThumbColor: Colors.grey[600],
            inactiveTrackColor: Colors.grey[800],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[700], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: _showLogoutDialog,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.withOpacity(0.15),
              Colors.red.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red[400], size: 22),
            const SizedBox(width: 10),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.cairo(
                color: Colors.red[400],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildVersionInfo() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code_rounded, size: 14, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Text(
              _appVersion.isNotEmpty ? 'الإصدار $_appVersion' : 'جاري التحميل...',
              style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 12),
            ),
            if (_buildNumber.isNotEmpty) ...[
              Text(
                ' ($_buildNumber)',
                style: GoogleFonts.cairo(color: Colors.grey[700], fontSize: 11),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '© ${DateTime.now().year} COCOBOLO - جميع الحقوق محفوظة',
          style: GoogleFonts.cairo(color: Colors.grey[700], fontSize: 11),
        ),
      ],
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.construction_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Text('$feature - قريباً! 🚀', style: GoogleFonts.cairo()),
          ],
        ),
        backgroundColor: const Color(0xFF2A2A2A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFE8B923)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.diamond_rounded, color: Colors.black, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'COCOBOLO',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFFFFD700),
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
              style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildAboutRow('الإصدار', _appVersion.isNotEmpty ? _appVersion : '...'),
            _buildAboutRow('البناء', _buildNumber.isNotEmpty ? _buildNumber : '...'),
            _buildAboutRow('المطور', 'احمد الرفاعى'),
            _buildAboutRow('السنة', '${DateTime.now().year}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إغلاق',
              style: GoogleFonts.cairo(color: const Color(0xFFE8B923), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 13)),
          Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showPermissionsDialog() {
    final permissions = PermissionService().allPermissions;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.security_rounded, color: Color(0xFFE91E63), size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'الصلاحيات',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B923).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${permissions.length}',
                style: GoogleFonts.cairo(color: const Color(0xFFE8B923), fontSize: 12, fontWeight: FontWeight.bold),
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
                      Icon(Icons.lock_outline, size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد صلاحيات',
                        style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
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
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            perm.permissionName,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildPermBadge('عرض', perm.canView, const Color(0xFF2196F3)),
                              _buildPermBadge('إضافة', perm.canAdd, const Color(0xFF4CAF50)),
                              _buildPermBadge('تعديل', perm.canEdit, const Color(0xFFFF9800)),
                              _buildPermBadge('حذف', perm.canDelete, const Color(0xFFE91E63)),
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
            child: Text(
              'إغلاق',
              style: GoogleFonts.cairo(color: const Color(0xFFE8B923), fontWeight: FontWeight.bold),
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
        color: enabled ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: enabled ? color : Colors.grey[600],
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}