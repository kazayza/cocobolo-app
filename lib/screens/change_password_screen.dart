import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../widgets/design_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart'; // تأكد إن baseUrl هنا
import '../core/auth/session_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ChangePasswordScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _currentPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/change-password'),
        headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'currentPassword': _currentPassController.text,
          'newPassword': _newPassController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showMessage('تم تغيير كلمة المرور بنجاح ✅', AppColors.success);
        Navigator.pop(context); // الرجوع للخلف
      } else {
        _showMessage(data['message'] ?? 'فشل تغيير كلمة المرور', AppColors.error);
      }
    } catch (e) {
      _showMessage('خطأ في الاتصال بالسيرفر', AppColors.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Text('تغيير كلمة المرور', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // صورة تعبيرية
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset, size: 60, color: AppColors.info),
              ),
              const SizedBox(height: 30),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionHeader(
                      title: 'بيانات كلمة المرور',
                      icon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 20),

              // كلمة المرور الحالية
              _buildPasswordField(
                controller: _currentPassController,
                label: 'كلمة المرور الحالية',
                isObscure: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                validator: (val) => val!.isEmpty ? 'مطلوب' : null,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // كلمة المرور الجديدة
              _buildPasswordField(
                controller: _newPassController,
                label: 'كلمة المرور الجديدة',
                isObscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (val) {
                  if (val!.isEmpty) return 'مطلوب';
                  if (val.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
                  return null;
                },
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // تأكيد كلمة المرور
              _buildPasswordField(
                controller: _confirmPassController,
                label: 'تأكيد كلمة المرور الجديدة',
                isObscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (val) {
                  if (val != _newPassController.text) return 'كلمات المرور غير متطابقة';
                  return null;
                },
                isDark: isDark,
              ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.sm)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'حفظ التغييرات',
                          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
      controller: controller,
      obscureText: isObscure,
      validator: validator,
      style: GoogleFonts.cairo(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : Colors.white,
        border: OutlineInputBorder(
          borderRadius: AppRadius.all(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.all(AppRadius.sm),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.all(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.info, width: 2),
        ),
        errorStyle: GoogleFonts.cairo(color: AppColors.error),
      ),
        ),
      ],
    );
  }
}