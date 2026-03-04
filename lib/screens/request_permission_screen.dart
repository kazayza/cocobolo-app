import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

class RequestPermissionScreen extends StatefulWidget {
  final int userId;

  const RequestPermissionScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<RequestPermissionScreen> createState() => _RequestPermissionScreenState();
}

class _RequestPermissionScreenState extends State<RequestPermissionScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _destinationController = TextEditingController(); // للمأمورية
  
  bool isSubmitting = false;

  // القيم الافتراضية
  String selectedType = 'LateIn';
  DateTime selectedDate = DateTime.now();
  TimeOfDay fromTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay toTime = const TimeOfDay(hour: 11, minute: 0);

  AnimationController? _typeAnimationController;

  final List<Map<String, dynamic>> types = [
    {'value': 'LateIn', 'label': 'تأخير صباحي', 'icon': Icons.timer_off, 'color': Colors.orange},
    {'value': 'EarlyOut', 'label': 'انصراف مبكر', 'icon': Icons.exit_to_app, 'color': Colors.blue},
    {'value': 'Errands', 'label': 'مأمورية عمل', 'icon': Icons.work, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _typeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _destinationController.dispose();
    _typeAnimationController?.dispose();
    super.dispose();
  }

  int get durationInMinutes {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, fromTime.hour, fromTime.minute);
    final end = DateTime(now.year, now.month, now.day, toTime.hour, toTime.minute);
    return end.difference(start).inMinutes;
  }

  String get formattedDuration {
    final minutes = durationInMinutes;
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes / 60;
    if (hours == 24) return 'يوم كامل';
    if (hours % 1 == 0) return '${hours.toInt()} ساعة';
    return '${hours.toStringAsFixed(1)} ساعة';
  }

  bool get isValidDuration => durationInMinutes > 0;

  Future<void> submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isValidDuration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وقت النهاية يجب أن يكون بعد وقت البداية')),
      );
      return;
    }

    if (selectedType == 'Errands' && _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة وجهة المأمورية')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final body = {
        'userId': widget.userId,
        'permissionDate': DateFormat('yyyy-MM-dd').format(selectedDate),
        'type': selectedType,
        'fromTime': '${fromTime.hour.toString().padLeft(2, '0')}:${fromTime.minute.toString().padLeft(2, '0')}:00',
        'toTime': '${toTime.hour.toString().padLeft(2, '0')}:${toTime.minute.toString().padLeft(2, '0')}:00',
        'duration': durationInMinutes,
        'reason': _reasonController.text,
        if (selectedType == 'Errands') 'destination': _destinationController.text,
        'createdAt': DateTime.now().toIso8601String(),
      };

      final res = await http.post(
        Uri.parse('$baseUrl/api/permissions/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        _showSuccessDialog();
      } else {
        throw 'Error';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('فشل إرسال الطلب', style: GoogleFonts.cairo())),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 50),
              ),
              const SizedBox(height: 20),
              Text(
                'تم إرسال الطلب بنجاح',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'سيتم مراجعة طلبك من قبل المدير',
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: Text(
                  'تم',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE8B923),
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1E1E1E),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? fromTime : toTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE8B923),
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: const Color(0xFF1E1E1E),
            dialBackgroundColor: Colors.grey[800],
            hourMinuteTextColor: Colors.white,
            dayPeriodTextColor: Colors.white,
            entryModeIconColor: const Color(0xFFE8B923),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) fromTime = picked; else toTime = picked;
      });
    }
  }

  void _setQuickTime(int hours) {
    setState(() {
      fromTime = const TimeOfDay(hour: 9, minute: 0);
      toTime = TimeOfDay(hour: 9 + hours, minute: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedTypeData = types.firstWhere((t) => t['value'] == selectedType);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B923).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(selectedTypeData['icon'], color: const Color(0xFFE8B923), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'طلب إذن جديد',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. نوع الإذن
              _buildSectionTitle('نوع الإذن', Icons.category_rounded),
              const SizedBox(height: 12),
              _buildTypeSelector(),

              const SizedBox(height: 24),

              // 2. التاريخ
              _buildSectionTitle('تاريخ الإذن', Icons.calendar_month_rounded),
              const SizedBox(height: 12),
              _buildDateCard(),

              const SizedBox(height: 24),

              // 3. الوقت
              _buildSectionTitle('التوقيت', Icons.access_time_rounded),
              const SizedBox(height: 12),
              _buildTimeSelector(),

              const SizedBox(height: 16),

              // 4. اختصارات الوقت
              _buildQuickTimeButtons(),

              const SizedBox(height: 24),

              // 5. السبب
              _buildSectionTitle('السبب', Icons.message_rounded),
              const SizedBox(height: 12),
              _buildReasonField(),

              // 6. وجهة المأمورية (تظهر فقط لو اختار مأمورية)
              if (selectedType == 'Errands') ...[
                const SizedBox(height: 20),
                _buildSectionTitle('وجهة المأمورية', Icons.location_on_rounded),
                const SizedBox(height: 12),
                _buildDestinationField(),
              ],

              const SizedBox(height: 30),

              // 7. ملخص الطلب
              _buildSummaryCard(selectedTypeData),

              const SizedBox(height: 24),

              // 8. زر الإرسال
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE8B923), size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: types.map((type) {
          final isSelected = selectedType == type['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => selectedType = type['value']);
                _typeAnimationController?.forward(from: 0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? type['color'].withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? type['color'] : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: ScaleTransition(
                  scale: _typeAnimationController!.drive(
                    CurveTween(curve: Curves.elasticOut),
                  ),
                  child: Column(
                    children: [
                      Icon(type['icon'], color: isSelected ? type['color'] : Colors.grey, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        type['label'],
                        style: GoogleFonts.cairo(
                          color: isSelected ? Colors.white : Colors.grey,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateCard() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B923).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today, color: Color(0xFFE8B923), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'التاريخ المحدد',
                    style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy', 'ar').format(selectedDate),
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTimePicker('من', fromTime, true),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: const Icon(Icons.arrow_forward, color: Color(0xFFE8B923), size: 18),
          ),
          Expanded(
            child: _buildTimePicker('إلى', toTime, false),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, bool isFrom) {
    return GestureDetector(
      onTap: () => _pickTime(isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTimeButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickTimeChip('ساعة', 1),
          const SizedBox(width: 8),
          _buildQuickTimeChip('ساعتين', 2),
          const SizedBox(width: 8),
          _buildQuickTimeChip('4 ساعات', 4),
          const SizedBox(width: 8),
          _buildQuickTimeChip('نصف يوم', 4.5),
          const SizedBox(width: 8),
          _buildQuickTimeChip('يوم كامل', 8),
        ],
      ),
    );
  }

  Widget _buildQuickTimeChip(String label, double hours) {
    return GestureDetector(
      onTap: () => _setQuickTime(hours.toInt()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8B923).withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE8B923).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(color: const Color(0xFFE8B923), fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildReasonField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: _reasonController,
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'اكتب سبب الإذن هنا...',
          hintStyle: GoogleFonts.cairo(color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (val) => val!.isEmpty ? 'هذا الحقل مطلوب' : null,
      ),
    );
  }

  Widget _buildDestinationField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: _destinationController,
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'اكتب وجهة المأمورية...',
          hintStyle: GoogleFonts.cairo(color: Colors.grey[600]),
          prefixIcon: const Icon(Icons.location_on, color: Color(0xFFE8B923), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> typeData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            typeData['color'].withOpacity(0.15),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: typeData['color'].withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.summarize_rounded, color: typeData['color'], size: 18),
              const SizedBox(width: 8),
              Text(
                'ملخص الطلب',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('النوع', typeData['label'], typeData['color']),
              _buildSummaryItem('المدة', formattedDuration, typeData['color']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8B923),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'إرسال الطلب',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}