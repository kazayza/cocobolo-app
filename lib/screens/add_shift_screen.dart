import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

class AddShiftScreen extends StatefulWidget {
  final String username;
  final int employeeId;
  final String employeeName;
  final Map<String, dynamic>? currentShift;

  const AddShiftScreen({
    Key? key,
    required this.username,
    required this.employeeId,
    required this.employeeName,
    this.currentShift,
  }) : super(key: key);

  @override
  State<AddShiftScreen> createState() => _AddShiftScreenState();
}

class _AddShiftScreenState extends State<AddShiftScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // القيم المختارة
  String selectedShiftType = 'صباحى';
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  DateTime effectiveFrom = DateTime.now();
  DateTime? effectiveTo;

  // متحكمات الأنيميشن
  late AnimationController _shiftTypeController;
  late Animation<double> _shiftTypeAnimation;

  @override
  void initState() {
    super.initState();
    
    // تحضير الأنيميشن
    _shiftTypeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shiftTypeAnimation = CurvedAnimation(
      parent: _shiftTypeController,
      curve: Curves.elasticOut,
    );
    
    // قراءة البيانات إذا كان في شيفت موجود - داخل setState
    if (widget.currentShift != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadShiftData();
        }
      });
    }
  }

  void _loadShiftData() {
    final shift = widget.currentShift!;
    
    // 🔍 اطبع جميع البيانات المستقبلة لمعرفة ما يحدث
    print('═══════════════════════════════════');
    print('📥 Received Shift Data:');
    shift.forEach((key, value) {
      print('  $key: $value (type: ${value.runtimeType})');
    });
    print('═══════════════════════════════════');
    
    setState(() {
      // 1. قراءة نوع الشيفت بشكل صحيح
      String shiftType = shift['ShiftType'] ?? '';
      print('✅ Shift type from API: $shiftType');
      
      if (shiftType.contains('صباح') || 
          shiftType == 'صباحى' || 
          shiftType == 'صباحي' || 
          shiftType.toLowerCase().contains('morning')) {
        selectedShiftType = 'صباحى';
      } else if (shiftType.contains('مساء') || 
                 shiftType == 'مسائى' || 
                 shiftType == 'مسائي' || 
                 shiftType.toLowerCase().contains('evening') || 
                 shiftType.toLowerCase().contains('night')) {
        selectedShiftType = 'مسائى';
      }
      
      // 2. قراءة الأوقات
      if (shift['StartTime'] != null) {
        startTime = _parseTimeString(shift['StartTime']);
        print('✅ StartTime: $startTime');
      }
      if (shift['EndTime'] != null) {
        endTime = _parseTimeString(shift['EndTime']);
        print('✅ EndTime: $endTime');
      }
      
      // 3. قراءة التواريخ - جرب جميع الأسماء الممكنة
      // محاولة 1: StartDate / EndDate
      _loadDate('StartDate', 'effectiveFrom', true) ?? 
        _loadDate('EffectiveFrom', 'effectiveFrom', true);
        
      // ⭐ معالجة EndDate: إذا كان null، استخدم تاريخ بعد 30 يوم
      final dateLoaded = _loadDate('EndDate', 'effectiveTo', false) ?? 
        _loadDate('EffectiveTo', 'effectiveTo', false) ??
        _loadDate('ExpiredDate', 'effectiveTo', false) ??
        _loadDate('EndEffectiveDate', 'effectiveTo', false);
      
      // إذا لم يتم تحميل أي تاريخ نهاية، ابقِ effectiveTo = null
      if (dateLoaded == false || dateLoaded == null) {
        print('ℹ️ EndDate is null - keeping as null (no default value)');
        effectiveTo = null;
      }
    });
  }

  /// دالة مساعدة لتحميل التاريخ مع معالجة شاملة
  bool? _loadDate(String apiKey, String variableName, bool isStart) {
    final shift = widget.currentShift!;
    final value = shift[apiKey];
    
    print('  🔍 Checking "$apiKey": $value');
    
    if (value == null) {
      print('    ℹ️ "$apiKey" is null');
      return false;
    }
    
    final strValue = value.toString().trim();
    
    if (strValue.isEmpty || strValue.toLowerCase() == 'null') {
      print('    ℹ️ "$apiKey" is empty/null string');
      return false;
    }
    
    try {
      final parsed = DateTime.parse(strValue);
      
      if (isStart) {
        effectiveFrom = parsed;
        print('    ✅ effectiveFrom loaded from "$apiKey"');
      } else {
        effectiveTo = parsed;
        print('    ✅ effectiveTo loaded from "$apiKey"');
      }
      return true;
    } catch (e) {
      print('    ❌ Parse error on "$apiKey": $e');
      return false;
    }
  }

  @override
  void dispose() {
    _shiftTypeController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final format = DateFormat.jm();
      final dt = format.parse(timeStr);
      return TimeOfDay.fromDateTime(dt);
    } catch (e) {
      try {
        final parts = timeStr.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (e) {
        return TimeOfDay.now();
      }
    }
  }

  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate()) return;
    if (startTime == null || endTime == null) {
      _showErrorSnackBar('يرجى تحديد وقت البداية والنهاية');
      return;
    }

    // التحقق من أن وقت النهاية أكبر من وقت البداية
    if (endTime!.hour < startTime!.hour || 
        (endTime!.hour == startTime!.hour && endTime!.minute <= startTime!.minute)) {
      _showErrorSnackBar('وقت النهاية يجب أن يكون بعد وقت البداية');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final body = {
        'employeeId': widget.employeeId,
        'shiftType': selectedShiftType,
        'startTime': _formatTime(startTime!),
        'endTime': _formatTime(endTime!),
        'startDate': DateFormat('yyyy-MM-dd').format(effectiveFrom),
        'endDate': effectiveTo != null ? DateFormat('yyyy-MM-dd').format(effectiveTo!) : null,
        'createdBy': widget.username,
      };

      print('═══════════════════════════════════════');
      print('📤 Sending to API:');
      body.forEach((key, value) {
        print('  "$key": $value');
      });
      print('═══════════════════════════════════════');

      final res = await http.post(
        Uri.parse('$baseUrl/api/shifts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final result = jsonDecode(res.body);

      if (res.statusCode == 200 && result['success'] == true) {
        _showSuccessDialog();
      } else {
        _showErrorSnackBar(result['message'] ?? 'فشل الحفظ');
      }
    } catch (e) {
      _showErrorSnackBar('فشل الاتصال بالسيرفر');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm:ss').format(dt);
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (startTime ?? TimeOfDay.now()) : (endTime ?? TimeOfDay.now()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE8B923),
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFF1E1E1E),
              hourMinuteTextColor: Colors.white,
              dayPeriodTextColor: Colors.white,
              dialHandColor: const Color(0xFFE8B923),
              dialBackgroundColor: Colors.white.withOpacity(0.05),
              entryModeIconColor: const Color(0xFFE8B923),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) startTime = picked;
        else endTime = picked;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? effectiveFrom : (effectiveTo ?? DateTime.now().add(const Duration(days: 30))),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE8B923),
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
              onPrimary: Colors.black,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) effectiveFrom = picked;
        else effectiveTo = picked;
      });
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E1E1E),
                const Color(0xFF2A2A2A),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 50),
              ),
              const SizedBox(height: 20),
              Text(
                widget.currentShift == null ? 'تم إضافة الشيفت' : 'تم تحديث الشيفت',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'للموظف: ${widget.employeeName}',
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: GoogleFonts.cairo())),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.currentShift != null;
    
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
              child: Icon(isEdit ? Icons.edit_calendar : Icons.add_circle, color: const Color(0xFFE8B923), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              isEdit ? 'تعديل الشيفت' : 'إضافة شيفت جديد',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. بطاقة الموظف
              _buildEmployeeHeader(isEdit),
              
              const SizedBox(height: 25),

              // 2. عنوان القسم
              _buildSectionTitle('نوع الشيفت', Icons.work_history),
              const SizedBox(height: 15),
              
              // 3. نوع الشيفت
              _buildShiftTypeSelector(),
              
              const SizedBox(height: 25),

              // 4. عنوان القسم
              _buildSectionTitle('مواعيد العمل', Icons.access_time),
              const SizedBox(height: 15),
              
              // 5. الأوقات
              _buildTimePickers(),
              
              const SizedBox(height: 25),

              // 6. عنوان القسم
              _buildSectionTitle('تاريخ السريان', Icons.calendar_month),
              const SizedBox(height: 15),
              
              // 7. التواريخ
              _buildDatePickers(),
              
              const SizedBox(height: 30),

              // 8. ملخص الشيفت
              if (startTime != null || endTime != null || selectedShiftType.isNotEmpty)
                _buildShiftSummary(),
              
              const SizedBox(height: 20),

              // 9. زر الحفظ
              _buildSaveButton(isEdit),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8B923).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFE8B923), size: 16),
        ),
        const SizedBox(width: 10),
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

  Widget _buildEmployeeHeader(bool isEdit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A1A),
            const Color(0xFF222222),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE8B923).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // صورة الموظف
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE8B923).withOpacity(0.2),
                  const Color(0xFFE8B923).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE8B923).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                widget.employeeName.isNotEmpty ? widget.employeeName[0].toUpperCase() : '?',
                style: GoogleFonts.cairo(
                  fontSize: 32,
                  color: const Color(0xFFE8B923),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          
          // معلومات الموظف
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'تعديل الشيفت' : 'إضافة شيفت جديد',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.employeeName,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8B923).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'رقم الموظف: #${widget.employeeId}',
                    style: GoogleFonts.cairo(
                      color: const Color(0xFFE8B923),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // أيقونة الحالة
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isEdit ? const Color(0xFF4CAF50) : const Color(0xFFE8B923)).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEdit ? Icons.edit : Icons.add,
              color: isEdit ? const Color(0xFF4CAF50) : const Color(0xFFE8B923),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildShiftTypeCard('صباحى', Icons.wb_sunny, const Color(0xFFE8B923)),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildShiftTypeCard('مسائى', Icons.nights_stay, const Color(0xFF3F51B5)),
        ),
      ],
    );
  }

  Widget _buildShiftTypeCard(String type, IconData icon, Color color) {
  final isSelected = selectedShiftType == type;
  
  return GestureDetector(
    onTap: () {
      setState(() {
        selectedShiftType = type;
        _shiftTypeController.forward(from: 0);
      });
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.3), // خفيف
                  Colors.transparent, // شفاف خالص
                ],
              )
            : null,
        color: const Color(0xFF1A1A1A), // لون أساسي
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? color : Colors.white.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 30), // أبيض فوق كل حاجة
          const SizedBox(height: 8),
          Text(
            type,
            style: GoogleFonts.cairo(
              color: Colors.white, // أبيض فوق كل حاجة
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildTimePickers() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTimePickerCard(
              'بداية',
              startTime,
              Icons.login,
              const Color(0xFF4CAF50),
              () => _selectTime(context, true),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            child: const Icon(Icons.arrow_forward, color: Color(0xFFE8B923), size: 20),
          ),
          Expanded(
            child: _buildTimePickerCard(
              'نهاية',
              endTime,
              Icons.logout,
              const Color(0xFFE91E63),
              () => _selectTime(context, false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerCard(String label, TimeOfDay? time, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: time != null ? color.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: time != null ? color : Colors.grey, size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: time != null ? color : Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time != null ? time.format(context) : '--:--',
              style: GoogleFonts.cairo(
                color: time != null ? Colors.white : Colors.grey[600],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickers() {
    return Column(
      children: [
        _buildDatePickerCard(
          'بداية السريان',
          effectiveFrom,
          Icons.play_circle,
          const Color(0xFF4CAF50),
          () => _selectDate(context, true),
        ),
        const SizedBox(height: 10),
        _buildDatePickerCard(
          'نهاية السريان (اختياري)',
          effectiveTo,
          Icons.stop_circle,
          const Color(0xFFE91E63),
          () => _selectDate(context, false),
          isOptional: true,
          onClear: () => setState(() => effectiveTo = null),
        ),
      ],
    );
  }

  Widget _buildDatePickerCard(
    String label,
    DateTime? date,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isOptional = false,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: date != null ? color.withOpacity(0.3) : Colors.white.withOpacity(0.03),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null 
                        ? DateFormat('yyyy-MM-dd').format(date)
                        : (isOptional ? 'غير محدد (مفتوح)' : 'اختر التاريخ'),
                    style: GoogleFonts.cairo(
                      color: date != null ? Colors.white : Colors.grey[600],
                      fontSize: 14,
                      fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (isOptional && date != null && onClear != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 18),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE8B923).withOpacity(0.1),
            const Color(0xFF1A1A1A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8B923).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.summarize, color: Color(0xFFE8B923), size: 18),
              const SizedBox(width: 8),
              Text(
                'ملخص الشيفت',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'النوع',
                  selectedShiftType,
                  selectedShiftType == 'صباحى' ? Icons.wb_sunny : Icons.nights_stay,
                  selectedShiftType == 'صباحى' ? const Color(0xFFE8B923) : const Color(0xFF3F51B5),
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'الوقت',
                  startTime != null && endTime != null
                      ? '${startTime!.format(context)} - ${endTime!.format(context)}'
                      : 'غير محدد',
                  Icons.access_time,
                  const Color(0xFFE8B923),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: Colors.grey[500],
                  fontSize: 9,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isEdit) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveShift,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8B923),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isEdit ? Icons.update : Icons.save, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'تحديث الشيفت' : 'حفظ الشيفت',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}