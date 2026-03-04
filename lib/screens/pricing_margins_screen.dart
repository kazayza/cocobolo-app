import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../services/permission_service.dart';

class PricingMarginsScreen extends StatefulWidget {
  final String username;

  const PricingMarginsScreen({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  State<PricingMarginsScreen> createState() => _PricingMarginsScreenState();
}

class _PricingMarginsScreenState extends State<PricingMarginsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // النسب الحالية
  Map<String, dynamic>? currentMargins;
  List<dynamic> marginsHistory = [];

  // Controllers
  final _premiumController = TextEditingController();
  final _eliteController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _premiumController.dispose();
    _eliteController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // =====================
  // 📡 API Calls
  // =====================

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // جلب النسب الحالية
      final marginsRes = await http.get(
        Uri.parse('$baseUrl/api/pricing/margins'),
      );

      // جلب السجل
      final historyRes = await http.get(
        Uri.parse('$baseUrl/api/pricing/margins/history'),
      );

      if (marginsRes.statusCode == 200 && historyRes.statusCode == 200) {
        final margins = jsonDecode(marginsRes.body);
        final history = jsonDecode(historyRes.body);

        setState(() {
          currentMargins = margins;
          marginsHistory = history;
          _premiumController.text = (margins?['PremiumMargin'] ?? 60).toString();
          _eliteController.text = (margins?['EliteMargin'] ?? 65).toString();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showError('فشل تحميل البيانات');
      }
    } catch (e) {
      print('Error fetching margins: $e');
      setState(() => _isLoading = false);
      _showError('فشل الاتصال بالسيرفر');
    }
  }

  Future<void> _saveMargins() async {
    final premium = double.tryParse(_premiumController.text);
    final elite = double.tryParse(_eliteController.text);

    if (premium == null || elite == null) {
      _showError('يرجى إدخال نسب صحيحة');
      return;
    }
    if (premium <= 0 || elite <= 0) {
      _showError('النسب يجب أن تكون أكبر من صفر');
      return;
    }

    // تأكيد التعديل
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFFFFD700), size: 28),
            const SizedBox(width: 10),
            Text(
              'تأكيد التعديل',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل تريد تحديث نسب الربح؟',
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildConfirmRow('Premium', '${currentMargins?['PremiumMargin'] ?? 0}%', '$premium%'),
                  const SizedBox(height: 8),
                  _buildConfirmRow('Elite', '${currentMargins?['EliteMargin'] ?? 0}%', '$elite%'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ النسب الجديدة هتتطبق على المنتجات الجديدة فقط',
              style: GoogleFonts.cairo(color: Colors.orangeAccent, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8B923),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('تأكيد', style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/pricing/margins'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'premiumMargin': premium,
          'eliteMargin': elite,
          'reason': _reasonController.text.isNotEmpty ? _reasonController.text : null,
          'createdBy': widget.username,
          'clientTime': DateTime.now().toIso8601String(),
        }),
      );

      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        _showSuccess('تم تحديث النسب بنجاح');
        _reasonController.clear();
        _fetchData(); // إعادة تحميل البيانات
      } else {
        _showError(result['message'] ?? 'فشل تحديث النسب');
      }
    } catch (e) {
      print('Error saving margins: $e');
      _showError('فشل حفظ النسب');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // =====================
  // 🎨 UI
  // =====================

  @override
  Widget build(BuildContext context) {
    // التحقق من الصلاحية
    if (!PermissionService().canEditPricingMargins) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          title: Text('نسب الربح', style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFFE8B923),
          iconTheme: const IconThemeData(color: Colors.black),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              Text('ليس لديك صلاحية لعرض هذه الشاشة', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          'إعدادات نسب الربح',
          style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE8B923),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // النسب الحالية
                  _buildCurrentMarginsCard(),
                  const SizedBox(height: 24),

                  // تعديل النسب
                  _buildEditSection(),
                  const SizedBox(height: 24),

                  // سجل التغييرات
                  _buildHistorySection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentMarginsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withOpacity(0.15),
            const Color(0xFFFFD700).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.percent, color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 10),
              Text(
                'النسب الحالية',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Premium
              Expanded(
                child: _buildMarginDisplay(
                  'Premium',
                  '${currentMargins?['PremiumMargin'] ?? 0}%',
                  const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 16),
              // Elite
              Expanded(
                child: _buildMarginDisplay(
                  'Elite',
                  '${currentMargins?['EliteMargin'] ?? 0}%',
                  Colors.greenAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (currentMargins?['ChangedBy'] != null)
            Text(
              'آخر تعديل بواسطة: ${currentMargins!['ChangedBy']} - ${currentMargins!['ChangedAt'] ?? ''}',
              style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildMarginDisplay(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEditSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit, color: Color(0xFFFFD700), size: 22),
              const SizedBox(width: 10),
              Text(
                'تعديل النسب',
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // نسبة Premium
          Row(
            children: [
              Expanded(
                child: _buildMarginInput(
                  controller: _premiumController,
                  label: 'نسبة ربح Premium %',
                  color: const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMarginInput(
                  controller: _eliteController,
                  label: 'نسبة ربح Elite %',
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // سبب التغيير
          TextFormField(
            controller: _reasonController,
            style: GoogleFonts.cairo(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'سبب التغيير (اختياري)',
              labelStyle: GoogleFonts.cairo(color: Colors.grey),
              prefixIcon: const Icon(Icons.note, color: Color(0xFFFFD700)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFD700)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),

          const SizedBox(height: 20),

          // زر الحفظ
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveMargins,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8B923),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.save, color: Colors.black),
                        const SizedBox(width: 10),
                        Text(
                          'حفظ النسب',
                          style: GoogleFonts.cairo(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildMarginInput({
    required TextEditingController controller,
    required String label,
    required Color color,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.cairo(color: Colors.white, fontSize: 18),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: Colors.grey, fontSize: 12),
        suffixText: '%',
        suffixStyle: GoogleFonts.cairo(color: color, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: Color(0xFFFFD700), size: 22),
            const SizedBox(width: 10),
            Text(
              'سجل التغييرات',
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (marginsHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'لا يوجد سجل تغييرات',
                style: GoogleFonts.cairo(color: Colors.grey),
              ),
            ),
          )
        else
          ...marginsHistory.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            return _buildHistoryCard(record, index);
          }),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHistoryCard(Map<String, dynamic> record, int index) {
    final isFirst = index == 0; // أحدث تغيير

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFirst
            ? const Color(0xFFFFD700).withOpacity(0.08)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFirst
              ? const Color(0xFFFFD700).withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // التاريخ والمستخدم
          Row(
            children: [
              Icon(
                isFirst ? Icons.fiber_new : Icons.history,
                color: isFirst ? const Color(0xFFFFD700) : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record['ChangedBy'] ?? '',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                record['ChangedAt'] ?? '',
                style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // النسب
          Row(
            children: [
              // Premium
              Expanded(
                child: _buildHistoryMargin(
                  'Premium',
                  record['PreviousPremium'],
                  record['PremiumMargin'],
                  const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 12),
              // Elite
              Expanded(
                child: _buildHistoryMargin(
                  'Elite',
                  record['PreviousElite'],
                  record['EliteMargin'],
                  Colors.greenAccent,
                ),
              ),
            ],
          ),

          // السبب
          if (record['ChangeReason'] != null &&
              record['ChangeReason'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record['ChangeReason'],
                      style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryMargin(String title, dynamic oldValue, dynamic newValue, Color color) {
    final old = oldValue ?? 0;
    final current = newValue ?? 0;
    final changed = old != current && old != 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (changed)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$old%',
                  style: GoogleFonts.cairo(
                    color: Colors.grey,
                    fontSize: 13,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward, color: Colors.grey, size: 14),
                const SizedBox(width: 6),
                Text(
                  '$current%',
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            )
          else
            Text(
              '$current%',
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String oldVal, String newVal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13)),
        Row(
          children: [
            Text(oldVal, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13, decoration: TextDecoration.lineThrough)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: Color(0xFFFFD700), size: 16),
            const SizedBox(width: 8),
            Text(newVal, style: GoogleFonts.cairo(color: const Color(0xFFFFD700), fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  // =====================
  // 🔔 Messages
  // =====================

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text(message, style: GoogleFonts.cairo()),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 10),
            Text(message, style: GoogleFonts.cairo()),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}