import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'login_screen.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';

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

  String _getInitials() {
    final name = widget.fullName ?? widget.username;
    if (name.isEmpty) return 'م';
    return name[0].toUpperCase();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              'تسجيل الخروج',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'هل تريد تسجيل الخروج من التطبيق؟',
          style: GoogleFonts.cairo(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('خروج', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _logout() {
    // مسح الصلاحيات
    PermissionService().clear();
    
    // إيقاف الإشعارات
    NotificationService().stopPolling();
    
    // الانتقال لشاشة تسجيل الدخول
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          'الإعدادات',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: const Color(0xFFE8B923),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== بطاقة الملف الشخصي =====
            _buildProfileCard(),
            
            const SizedBox(height: 24),
            
            // ===== إعدادات التطبيق =====
            _buildSectionTitle('إعدادات التطبيق', Icons.settings),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'الإشعارات',
                subtitle: 'تفعيل/إيقاف الإشعارات',
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'الوضع الليلي',
                subtitle: 'مفعّل دائماً',
                value: _darkMode,
                onChanged: null, // مفعّل دائماً
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // ===== معلومات التطبيق =====
            _buildSectionTitle('معلومات', Icons.info_outline),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildNavigationTile(
                icon: Icons.description_outlined,
                title: 'سياسة الخصوصية',
                onTap: () => _showComingSoon('سياسة الخصوصية'),
              ),
              _buildDivider(),
              _buildNavigationTile(
                icon: Icons.help_outline,
                title: 'المساعدة والدعم',
                onTap: () => _showComingSoon('المساعدة'),
              ),
              _buildDivider(),
              _buildNavigationTile(
                icon: Icons.info_outline,
                title: 'عن التطبيق',
                onTap: () => _showAboutDialog(),
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // ===== الصلاحيات =====
            _buildSectionTitle('الصلاحيات', Icons.security),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildNavigationTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'عرض الصلاحيات',
                onTap: () => _showPermissionsDialog(),
              ),
            ]),
            
            const SizedBox(height: 32),
            
            // ===== زرار تسجيل الخروج =====
            _buildLogoutButton(),
            
            const SizedBox(height: 40),
            
            // ===== نسخة التطبيق =====
            Text(
              'الإصدار 1.0.0',
              style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 12),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withOpacity(0.2),
            const Color(0xFFFFD700).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // صورة المستخدم
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFE8B923)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitials(),
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontSize: 28,
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
                ),
                const SizedBox(height: 4),
                Text(
                  '@${widget.username}',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'مستخدم نشط',
                    style: GoogleFonts.cairo(
                      color: const Color(0xFF4CAF50),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // أيقونة التعديل
          IconButton(
            onPressed: () => _showComingSoon('تعديل الملف الشخصي'),
            icon: const Icon(Icons.edit_outlined, color: Color(0xFFFFD700)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFD700), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(children: children),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFFFFD700), size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFFFD700),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.grey.withOpacity(0.3),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFFFFD700), size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 15),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.white.withOpacity(0.1),
      height: 1,
      indent: 70,
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: _showLogoutDialog,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: Text(
          'تسجيل الخروج',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - قريباً! 🚀', style: GoogleFonts.cairo()),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.diamond, color: Color(0xFFFFD700)),
            ),
            const SizedBox(width: 12),
            Text(
              'COCOBOLO',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFFFFD700),
                fontSize: 20,
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
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildAboutRow('الإصدار', '1.0.0'),
            _buildAboutRow('المطور', 'فريق التطوير'),
            _buildAboutRow('تاريخ الإصدار', '2025'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo(color: const Color(0xFFFFD700))),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13)),
          Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 13)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFFFFD700)),
            const SizedBox(width: 10),
            Text(
              'الصلاحيات',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: permissions.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد صلاحيات',
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: permissions.length,
                  itemBuilder: (context, index) {
                    final entry = permissions.entries.elementAt(index);
                    final perm = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            perm.permissionName,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildPermBadge('عرض', perm.canView),
                              _buildPermBadge('إضافة', perm.canAdd),
                              _buildPermBadge('تعديل', perm.canEdit),
                              _buildPermBadge('حذف', perm.canDelete),
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
            child: Text('إغلاق', style: GoogleFonts.cairo(color: const Color(0xFFFFD700))),
          ),
        ],
      ),
    );
  }

  Widget _buildPermBadge(String label, bool enabled) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: enabled 
            ? const Color(0xFF4CAF50).withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: enabled ? const Color(0xFF4CAF50) : Colors.red,
          fontSize: 10,
        ),
      ),
    );
  }
}