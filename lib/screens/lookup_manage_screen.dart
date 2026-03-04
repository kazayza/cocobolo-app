import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/permission_service.dart';

// ===================================
// 📦 Config Model
// ===================================
class LookupConfig {
  final String title;
  final String apiPath;
  final IconData icon;
  final Color color;
  final String formName;
  final bool hasIcon;
  final bool hasColor;

  LookupConfig({
    required this.title,
    required this.apiPath,
    required this.icon,
    required this.color,
    required this.formName,
    this.hasIcon = false,
    this.hasColor = false,
  });
}

// ===================================
// 🎨 الشاشة
// ===================================
class LookupManageScreen extends StatefulWidget {
  final int userId;
  final String username;
  final LookupConfig config;

  const LookupManageScreen({
    Key? key,
    required this.userId,
    required this.username,
    required this.config,
  }) : super(key: key);

  @override
  State<LookupManageScreen> createState() => _LookupManageScreenState();
}

class _LookupManageScreenState extends State<LookupManageScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  bool get _isDark => ThemeService().isDarkMode;
  final _permissions = PermissionService();

  final List<Color> _predefinedColors = [
    const Color(0xFF3498DB), // أزرق
    const Color(0xFF2ECC71), // أخضر
    const Color(0xFFF1C40F), // أصفر
    const Color(0xFFE67E22), // برتقالي
    const Color(0xFFE74C3C), // أحمر
    const Color(0xFF9B59B6), // بنفسجي
    const Color(0xFF1ABC9C), // تركواز
    const Color(0xFF34495E), // كحلي
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ===================================
  // 📡 جلب البيانات
  // ===================================
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/lookups/${widget.config.apiPath}'),
      );
      if (res.statusCode == 200) {
        setState(() {
          _items = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ خطأ: $e');
      setState(() => _isLoading = false);
    }
  }

  // ===================================
  // ➕ إضافة
  // ===================================
  Future<void> _addItem(String nameAr, String nameEn, String? icon, String? color) async {
    try {
      final body = {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'createdBy': widget.username,
      };
      if (icon != null) body['icon'] = icon;
      if (color != null) body['color'] = color;

      final res = await http.post(
        Uri.parse('$baseUrl/api/lookups/${widget.config.apiPath}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _showSuccess('تم الإضافة بنجاح');
        _loadData();
      } else {
        _showError(data['message'] ?? 'فشل الإضافة');
      }
    } catch (e) {
      _showError('خطأ: $e');
    }
  }

  // ===================================
  // ✏️ تعديل
  // ===================================
  Future<void> _updateItem(int id, String nameAr, String nameEn, String? icon, String? color) async {
    try {
      final body = {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'updatedBy': widget.username,
      };
      if (icon != null) body['icon'] = icon;
      if (color != null) body['color'] = color;

      final res = await http.put(
        Uri.parse('$baseUrl/api/lookups/${widget.config.apiPath}/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _showSuccess('تم التعديل بنجاح');
        _loadData();
      } else {
        _showError(data['message'] ?? 'فشل التعديل');
      }
    } catch (e) {
      _showError('خطأ: $e');
    }
  }

  // ===================================
  // 🗑️ حذف
  // ===================================
  Future<void> _deleteItem(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.card(_isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Text('تأكيد الحذف', style: GoogleFonts.cairo(color: AppColors.text(_isDark))),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف "$name"؟',
            style: GoogleFonts.cairo(color: AppColors.textSecondary(_isDark)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary(_isDark))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/lookups/${widget.config.apiPath}/$id'),
      );

      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _showSuccess('تم الحذف بنجاح');
        _loadData();
      } else {
        _showError(data['message'] ?? 'فشل الحذف');
      }
    } catch (e) {
      _showError('خطأ: $e');
    }
  }

  // ===================================
  // 📝 Dialog إضافة/تعديل
  // ===================================
  void _showFormDialog({Map<String, dynamic>? item}) {
    final isEdit = item != null;
    final nameArController = TextEditingController(text: item?['nameAr'] ?? '');
    final nameEnController = TextEditingController(text: item?['nameEn'] ?? '');
    final iconController = TextEditingController(text: item?['icon'] ?? '');
    Color selectedColor = item?['color'] != null 
        ? _hexToColor(item!['color']) 
        : const Color(0xFF3498DB); 

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.card(_isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_rounded : Icons.add_rounded,
                color: widget.config.color,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isEdit ? 'تعديل' : 'إضافة جديد',
                style: GoogleFonts.cairo(
                  color: AppColors.text(_isDark),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // الاسم العربي
                TextField(
                  controller: nameArController,
                  textDirection: ui.TextDirection.rtl,
                  style: GoogleFonts.cairo(color: AppColors.text(_isDark)),
                  decoration: _inputDecoration('الاسم بالعربي *'),
                ),
                const SizedBox(height: 12),

                // الاسم الإنجليزي
                TextField(
                  controller: nameEnController,
                  textDirection: ui.TextDirection.ltr,
                  style: GoogleFonts.cairo(color: AppColors.text(_isDark)),
                  decoration: _inputDecoration('الاسم بالإنجليزي'),
                ),

                // الأيقونة (لو الجدول فيه icon)
                if (widget.config.hasIcon) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: iconController,
                    style: const TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                    decoration: _inputDecoration('الأيقونة (Emoji)'),
                  ),
                ],

                // اختيار اللون (لو الجدول فيه color)
                if (widget.config.hasColor) ...[
                  const SizedBox(height: 16),
                  StatefulBuilder(
                    builder: (context, setStateColor) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'لون المرحلة',
                            style: GoogleFonts.cairo(
                              color: AppColors.textSecondary(_isDark),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var color in _predefinedColors)
                                GestureDetector(
                                  onTap: () => setStateColor(() => selectedColor = color),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selectedColor == color
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        if (selectedColor == color)
                                          BoxShadow(
                                            color: color.withOpacity(0.4),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                      ],
                                    ),
                                    child: selectedColor == color
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(color: AppColors.textSecondary(_isDark)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final nameAr = nameArController.text.trim();
                if (nameAr.isEmpty) {
                  _showError('الاسم العربي مطلوب');
                  return;
                }

                Navigator.pop(context);

                final nameEn = nameEnController.text.trim();
                final icon = iconController.text.trim();
                final colorHex = widget.config.hasColor ? _colorToHex(selectedColor) : null;

                if (isEdit) {
                  _updateItem(
                    item!['id'],
                    nameAr,
                    nameEn,
                    widget.config.hasIcon ? icon : null,
                    colorHex,
                  );
                } else {
                  _addItem(
                    nameAr,
                    nameEn,
                    widget.config.hasIcon ? icon : null,
                    colorHex,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.config.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                isEdit ? 'تعديل' : 'إضافة',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary(_isDark)),
      filled: true,
      fillColor: AppColors.inputFill(_isDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.divider(_isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.divider(_isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: widget.config.color, width: 2),
      ),
    );
  }

  // ===================================
  // 🎨 واجهة المستخدم
  // ===================================
  @override
  Widget build(BuildContext context) {
    final canAdd = _permissions.canAdd(widget.config.formName);
    final canEdit = _permissions.canEdit(widget.config.formName);
    final canDelete = _permissions.canDelete(widget.config.formName);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background(_isDark),
        appBar: AppBar(
          backgroundColor: _isDark ? AppColors.navy : Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(
            color: _isDark ? Colors.white : AppColors.navy,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.config.icon, color: widget.config.color, size: 22),
              const SizedBox(width: 8),
              Text(
                widget.config.title,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: _isDark ? Colors.white : AppColors.navy,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  color: _isDark ? Colors.white : AppColors.navy),
              onPressed: _loadData,
            ),
          ],
        ),
        floatingActionButton: canAdd
            ? FloatingActionButton.extended(
                onPressed: () => _showFormDialog(),
                backgroundColor: widget.config.color,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  'إضافة',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).scale()
            : null,
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: widget.config.color))
            : _items.isEmpty
                ? _buildEmptyView()
                : RefreshIndicator(
                    color: widget.config.color,
                    onRefresh: _loadData,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _buildItemCard(item, index, canEdit, canDelete)
                            .animate()
                            .fadeIn(
                              duration: 300.ms,
                              delay: Duration(milliseconds: index * 50),
                            )
                            .slideX(begin: 0.1, end: 0);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildItemCard(
    Map<String, dynamic> item,
    int index,
    bool canEdit,
    bool canDelete,
  ) {
    final nameAr = item['nameAr'] ?? '';
    final nameEn = item['nameEn'] ?? '';
    final icon = item['icon'];
    final itemColor = item['color'] != null 
        ? _hexToColor(item['color']) 
        : widget.config.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(_isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: itemColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // الرقم أو الأيقونة
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: itemColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: icon != null && icon.toString().isNotEmpty
                  ? Text(icon, style: const TextStyle(fontSize: 22))
                  : Text(
                      '${index + 1}',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: itemColor,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // الاسم
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameAr,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(_isDark),
                  ),
                ),
                if (nameEn.isNotEmpty)
                  Text(
                    nameEn,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary(_isDark),
                    ),
                  ),
              ],
            ),
          ),

          // أزرار الأكشن
          if (canEdit)
            IconButton(
              icon: Icon(Icons.edit_rounded,
                  color: widget.config.color, size: 20),
              onPressed: () => _showFormDialog(item: item),
              tooltip: 'تعديل',
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_rounded,
                  color: Colors.red, size: 20),
              onPressed: () => _deleteItem(item['id'], nameAr),
              tooltip: 'حذف',
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.config.icon,
              size: 80,
              color: widget.config.color.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'لا توجد بيانات',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: AppColors.textSecondary(_isDark),
            ),
          ),
          if (_permissions.canAdd(widget.config.formName)) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showFormDialog(),
              icon: Icon(Icons.add_rounded, color: widget.config.color),
              label: Text(
                'أضف الأول',
                style: GoogleFonts.cairo(color: widget.config.color),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: widget.config.color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(message, style: GoogleFonts.cairo()),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: GoogleFonts.cairo())),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }
}