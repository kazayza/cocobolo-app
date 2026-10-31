import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../core/auth/session_service.dart';

/// نموذج إضافة / تعديل شيفت موظف — مرآة نموذج بلازور
/// (ShiftForm.razor + EmployeeShiftDto.cs):
/// الأنواع الثلاثة كما تُخزَّن نصًا: صباحى / مسائى / عمل يومى،
/// والأوقات الافتراضية عند اختيار النوع قابلة للتعديل، ويوما راحة
/// أسبوعية اختياريان بأرقام .NET DayOfWeek (0=الأحد .. 6=السبت).
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

class _AddShiftScreenState extends State<AddShiftScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // الأنواع كما في Blazor ShiftTypes حرفيًا — تُحفظ وتُرسل كما هي
  static const List<String> _shiftTypes = ['صباحى', 'مسائى', 'عمل يومى'];

  // الأوقات الافتراضية عند اختيار النوع (EmployeeShiftDto.cs:19-32)
  static const Map<String, TimeOfDay> _defaultStart = {
    'صباحى': TimeOfDay(hour: 10, minute: 0),
    'مسائى': TimeOfDay(hour: 14, minute: 0),
    'عمل يومى': TimeOfDay(hour: 9, minute: 0),
  };
  static const Map<String, TimeOfDay> _defaultEnd = {
    'صباحى': TimeOfDay(hour: 18, minute: 0),
    'مسائى': TimeOfDay(hour: 22, minute: 0),
    'عمل يومى': TimeOfDay(hour: 17, minute: 0),
  };

  // أسماء أيام الأسبوع بأرقام .NET DayOfWeek: 0=الأحد .. 6=السبت
  static const List<String> _weekdayNames = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];

  String selectedShiftType = 'صباحى';
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  DateTime effectiveFrom = DateTime.now();
  DateTime? effectiveTo;
  int? offDay1;
  int? offDay2;

  // مسح صريح من المستخدم لأحد المنتقيين أثناء هذه الجلسة: في التعديل
  // يُرسَل −1 للخادم فيُفرّغ القيمة المخزنة فعلًا (غياب القيمة وحده
  // يُبقيها كما هي بسلوك ISNULL)؛ منتقٍ لم يُلمس يبقى على قيمته المحمّلة
  bool _offDay1Cleared = false;
  bool _offDay2Cleared = false;

  bool get _isDark => ThemeService().isDarkMode;
  bool get isEdit => widget.currentShift != null;

  /// لون نوع الشيفت — تعريف واحد من ألوان بلازور (DTO Colors):
  /// صباحى أخضر، مسائى برتقالي، عمل يومى أزرق — بالدرجة المناسبة للوضع
  Color shiftTypeColor(String? type) {
    switch (type) {
      case 'صباحى':
        return _isDark ? AppColors.successLight : AppColors.success;
      case 'مسائى':
        return _isDark ? AppColors.warningLight : AppColors.warning;
      case 'عمل يومى':
        return _isDark ? AppColors.infoLight : AppColors.info;
      default:
        return _isDark ? AppColors.neutralLight : AppColors.neutral;
    }
  }

  IconData shiftTypeIcon(String? type) {
    switch (type) {
      case 'صباحى':
        return Icons.wb_sunny_rounded;
      case 'مسائى':
        return Icons.nights_stay_rounded;
      case 'عمل يومى':
        return Icons.work_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.currentShift != null) {
      _loadShiftData();
      _loadOffDaysFromHistory();
    } else {
      // وضع الإضافة: تُملأ الأوقات الافتراضية للنوع الافتراضي (صباحى)
      startTime = _defaultStart[selectedShiftType];
      endTime = _defaultEnd[selectedShiftType];
    }
  }

  void _loadShiftData() {
    final shift = widget.currentShift!;

    // النوع يُحفظ كما ورد نصًا تمامًا — لا تحويل ثنائيًا (كان أي نوع
    // لا يحمل «صباح» يتحول «مسائى» فيُفسد «عمل يومى» عند الحفظ)
    final rawType = shift['ShiftType']?.toString().trim() ?? '';
    if (rawType.isNotEmpty) selectedShiftType = rawType;

    if (shift['StartTime'] != null) {
      startTime = _parseTimeString(shift['StartTime'].toString());
    }
    if (shift['EndTime'] != null) {
      endTime = _parseTimeString(shift['EndTime'].toString());
    }

    final fromDate = shift['EffectiveFrom'];
    if (fromDate != null && fromDate.toString().isNotEmpty) {
      try {
        effectiveFrom = DateTime.parse(fromDate.toString());
      } catch (e) {
        effectiveFrom = DateTime.now();
      }
    }

    final toDate = shift['EffectiveTo'];
    if (toDate != null &&
        toDate.toString().isNotEmpty &&
        toDate.toString().toLowerCase() != 'null') {
      try {
        effectiveTo = DateTime.parse(toDate.toString());
      } catch (e) {
        effectiveTo = null;
      }
    } else {
      effectiveTo = null;
    }

    offDay1 = _readOffDay(shift, 'OffDay1', 'offDay1');
    offDay2 = _readOffDay(shift, 'OffDay2', 'offDay2');
  }

  /// قراءة يوم راحة من سجل: رقم أو نص رقمي بين 0 و6، وغيره يُهمَل
  static int? _readOffDay(Map<dynamic, dynamic> map, String key1, String key2) {
    for (final key in [key1, key2]) {
      final v = map[key];
      if (v is num) {
        final i = v.toInt();
        if (i >= 0 && i <= 6) return i;
      } else if (v != null) {
        final i = int.tryParse(v.toString().trim());
        if (i != null && i >= 0 && i <= 6) return i;
      }
    }
    return null;
  }

  /// سجل الحالة قد لا يحمل يومي الراحة — تُستكمل القراءة من نهاية
  /// شيفتات الموظف التي يستخدمها ملف الموظف، وتُهمَل بصمت عند غيابها
  Future<void> _loadOffDaysFromHistory() async {
    if (offDay1 != null || offDay2 != null) return;
    final shiftId = (widget.currentShift?['EmployeeShiftID'] as num?)?.toInt();
    if (shiftId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/shifts/employee/${widget.employeeId}'),
        headers: SessionService.instance.authHeaders,
      );
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      if (data is! List) return;
      for (final row in data) {
        if (row is Map &&
            (row['EmployeeShiftID'] as num?)?.toInt() == shiftId) {
          final d1 = _readOffDay(row, 'OffDay1', 'offDay1');
          final d2 = _readOffDay(row, 'OffDay2', 'offDay2');
          if (mounted && (d1 != null || d2 != null)) {
            setState(() {
              offDay1 = d1;
              offDay2 = d2;
              // قيم محمّلة للتو = خط الأساس «غير الملموس» لأعلام المسح
              _offDay1Cleared = false;
              _offDay2Cleared = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      // أيام الراحة استكمال اختياري — فشل جلبها لا يمنع تعديل الشيفت
    }
  }

  /// تحليل وقت قادم من الـ API بصيغه الواقعية كلها: «09:00 AM» و
  /// «05:00 PM» (FORMAT في الخادم) و«17:00:00» و«9:00 ص». المحلّل
  /// السابق (DateFormat.jm بلغة الجهاز) كان يفشل مع «AM/PM» تحت
  /// لغة عربية فيرجع وقت «الآن» صامتًا لكلا الوقتين.
  TimeOfDay _parseTimeString(String timeStr) {
    final raw = timeStr.trim();
    // 1) محاولات بأنماط صريحة أولًا
    for (final pattern in ['hh:mm a', 'h:mm a', 'HH:mm:ss', 'HH:mm']) {
      try {
        final dt = DateFormat(pattern, 'en_US').parse(raw);
        return TimeOfDay.fromDateTime(dt);
      } catch (e) {
        // جرّب النمط التالي
      }
    }
    // 2) تحليل يدوي حتمي: استخراج مؤشر صباح/مساء ثم الأرقام
    try {
      var s = raw.toUpperCase();
      final isPm = s.contains('PM') || s.contains('م');
      final isAm = s.contains('AM') || s.contains('ص');
      s = s.replaceAll(RegExp(r'[^0-9:]'), ' ');
      final nums = s
          .split(RegExp(r'[:\s]+'))
          .where((p) => p.isNotEmpty)
          .map(int.parse)
          .toList();
      var hour = nums[0];
      final minute = nums.length > 1 ? nums[1] : 0;
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour % 24, minute: minute % 60);
    } catch (e) {
      return TimeOfDay.now();
    }
  }

  /// اختيار النوع من المستخدم: يُملأ الوقت الافتراضي للنوع كما في
  /// بلازور (OnShiftTypeChanged) — ويبقى الوقت قابلًا للتعديل بعده
  void _onTypeSelected(String type) {
    setState(() {
      selectedShiftType = type;
      startTime = _defaultStart[type] ?? startTime;
      endTime = _defaultEnd[type] ?? endTime;
    });
  }

  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate()) return;
    if (startTime == null || endTime == null) {
      _showErrorSnackBar('يرجى تحديد وقت البداية والنهاية');
      return;
    }
    // دلالة بلازور للأوقات الليلية: النهاية الأسبق من البداية تعني
    // عبور منتصف الليل (DurationDisplay يضيف 24 ساعة) — تُقبل،
    // ويُرفض فقط التساوي (شيفت بلا مدة)
    if (startTime == endTime) {
      _showErrorSnackBar('لا يمكن أن يتساوى وقت بداية الشيفت ووقت نهايته');
      return;
    }
    if (effectiveTo != null) {
      final fromDay =
          DateTime(effectiveFrom.year, effectiveFrom.month, effectiveFrom.day);
      final toDay =
          DateTime(effectiveTo!.year, effectiveTo!.month, effectiveTo!.day);
      if (toDay.isBefore(fromDay)) {
        _showErrorSnackBar(
            'تاريخ نهاية السريان يجب أن يكون مساويًا لتاريخ بدايته أو لاحقًا له');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // الهوية تأتي من التوكن على الخادم — لا تُرسل createdBy من العميل
      final body = {
        'employeeId': widget.employeeId,
        'shiftType': selectedShiftType,
        'startTime': _formatTime(startTime!),
        'endTime': _formatTime(endTime!),
        'effectiveFrom': effectiveFrom.toIso8601String(),
        'effectiveTo': effectiveTo?.toIso8601String(),
        // تعديل + منتقٍ مسحه المستخدم صراحة ← −1 (إشارة مسح الخادم)؛
        // غير ذلك تُرسل القيمة الحالية كما هي (وفي الإنشاء يبقى
        // الإرسال null/قيمة كما كان، و−1 لا يصدر أصلًا)
        'offDay1': (isEdit && _offDay1Cleared && offDay1 == null) ? -1 : offDay1,
        'offDay2': (isEdit && _offDay2Cleared && offDay2 == null) ? -1 : offDay2,
      };

      // تعديل شيفت قائم = PUT على المعرف نفسه (تحديث في المكان)،
      // وإلا كان الحفظ يكرّر الشيفت بصف جديد بدل تعديله
      final existingShiftId =
          (widget.currentShift?['EmployeeShiftID'] as num?)?.toInt();
      final headers = {
        ...SessionService.instance.authHeaders,
        'Content-Type': 'application/json'
      };
      final http.Response res;
      if (existingShiftId != null && existingShiftId > 0) {
        res = await http.put(
          Uri.parse('$baseUrl/api/shifts/$existingShiftId'),
          headers: headers,
          body: jsonEncode(body),
        );
      } else {
        res = await http.post(
          Uri.parse('$baseUrl/api/shifts'),
          headers: headers,
          body: jsonEncode(body),
        );
      }

      if (res.statusCode == 200) {
        final result = jsonDecode(res.body);
        if (result['success'] == true) {
          if (mounted) {
            Navigator.pop(context);
            _showSuccessDialog();
          }
        } else {
          _showErrorSnackBar(result['message'] ?? 'فشل الحفظ');
        }
      } else {
        final result = jsonDecode(res.body);
        _showErrorSnackBar(result['message'] ?? 'خطأ من السيرفر');
      }
    } catch (e) {
      _showErrorSnackBar('فشل الاتصال بالسيرفر: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      initialTime: isStart
          ? (startTime ?? TimeOfDay.now())
          : (endTime ?? TimeOfDay.now()),
      builder: (context, child) {
        // منتقي الوقت يتبع ثيم الشاشة الحالي في الوضعين — لا فرض داكن
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: ThemeService().accentColor,
                  surface: AppColors.surface(_isDark),
                  onSurface: AppColors.text(_isDark),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? effectiveFrom
          : (effectiveTo ?? DateTime.now().add(const Duration(days: 30))),
      // نطاق جدولة واقعي — كان محصورًا ±365 يومًا فمنع الجدولة البعيدة
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: ThemeService().accentColor,
                  surface: AppColors.surface(_isDark),
                  onSurface: AppColors.text(_isDark),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          effectiveFrom = picked;
        } else {
          effectiveTo = picked;
        }
      });
    }
  }

  /// منتقي يوم راحة: قائمة سفلية بالأيام السبعة + «غير محدد»
  /// (قيمة الرجوع -1 تعني «غير محدد» صراحة، و null تعني إغلاقًا بلا اختيار)
  Future<void> _pickOffDay(bool isFirst) async {
    final current = isFirst ? offDay1 : offDay2;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface(_isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    isFirst ? 'يوم الراحة الأول' : 'يوم الراحة الثاني',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.clear_rounded,
                    color: AppColors.textSecondary(_isDark)),
                title: Text('غير محدد',
                    style: textTheme.bodyLarge
                        ?.copyWith(color: AppColors.text(_isDark))),
                trailing: current == null
                    ? Icon(Icons.check_rounded,
                        color: ThemeService().accentColor)
                    : null,
                onTap: () => Navigator.pop(sheetContext, -1),
              ),
              for (var d = 0; d < 7; d++)
                ListTile(
                  leading: Icon(Icons.event_rounded,
                      color: AppColors.textSecondary(_isDark)),
                  title: Text(_weekdayNames[d],
                      style: textTheme.bodyLarge
                          ?.copyWith(color: AppColors.text(_isDark))),
                  trailing: current == d
                      ? Icon(Icons.check_rounded,
                          color: ThemeService().accentColor)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, d),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    final value = picked < 0 ? null : picked;
    setState(() {
      if (isFirst) {
        offDay1 = value;
        _offDay1Cleared = picked < 0;
        if (offDay2 != null && offDay2 == offDay1) {
          // أُزيح اليوم الثاني لاختيار الأول مكانه — شكله الظاهر
          // «غير محدد» فيجب أن يطابق المخزَّن عند الحفظ أيضًا
          offDay2 = null;
          _offDay2Cleared = true;
        }
      } else {
        offDay2 = value;
        _offDay2Cleared = picked < 0;
        if (offDay1 != null && offDay1 == offDay2) {
          offDay1 = null;
          _offDay1Cleared = true;
        }
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface(_isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    (_isDark ? AppColors.successLight : AppColors.success)
                        .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: _isDark ? AppColors.successLight : AppColors.success,
                  size: 44),
            ),
            const SizedBox(height: 16),
            Text(
              widget.currentShift == null
                  ? 'تم إضافة الشيفت'
                  : 'تم تحديث الشيفت',
              style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                    color: AppColors.text(_isDark),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'للموظف: ${widget.employeeName}',
              style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _isDark ? AppColors.gold : AppColors.navy,
                  foregroundColor: _isDark ? AppColors.navy : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('تم',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                  isEdit
                      ? Icons.edit_calendar_rounded
                      : Icons.add_circle_rounded,
                  color: AppColors.gold,
                  size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              isEdit ? 'تعديل الشيفت' : 'إضافة شيفت جديد',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
            ),
          ],
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: _buildSaveBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmployeeHeader(),
              const SizedBox(height: 16),
              AppCard(
                color: AppColors.surface(_isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionHeader(
                        title: 'نوع الشيفت',
                        icon: Icons.work_history_rounded,
                        accent: ThemeService().accentColor),
                    const SizedBox(height: 14),
                    _buildShiftTypeSelector(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                color: AppColors.surface(_isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionHeader(
                        title: 'مواعيد العمل',
                        icon: Icons.access_time_rounded,
                        accent: ThemeService().accentColor),
                    const SizedBox(height: 14),
                    _buildTimePickers(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                color: AppColors.surface(_isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionHeader(
                        title: 'أيام الراحة الأسبوعية',
                        icon: Icons.weekend_rounded,
                        accent: ThemeService().accentColor),
                    const SizedBox(height: 14),
                    _buildOffDayPicker('يوم الراحة الأول', offDay1, true),
                    const SizedBox(height: 10),
                    _buildOffDayPicker('يوم الراحة الثاني', offDay2, false),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                color: AppColors.surface(_isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionHeader(
                        title: 'تاريخ السريان',
                        icon: Icons.calendar_month_rounded,
                        accent: ThemeService().accentColor),
                    const SizedBox(height: 14),
                    _buildDatePickers(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (startTime != null && endTime != null) _buildShiftSummary(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// بطاقة مرساة كحلية بهوية الشاشة في الوضعين: الحرف الأول ذهبيًا
  /// والاسم أبيض ورقاقة رقم الموظف ذهبية بنص كحلي
  Widget _buildEmployeeHeader() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyDark.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
            ),
            child: Center(
              child: Text(
                widget.employeeName.isNotEmpty
                    ? widget.employeeName[0].toUpperCase()
                    : '؟',
                style: textTheme.headlineSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'تعديل الشيفت' : 'إضافة شيفت جديد',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.goldLight,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.employeeName,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'رقم الموظف: #${widget.employeeId}',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEdit ? Icons.edit_rounded : Icons.add_rounded,
              color: AppColors.gold,
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
        for (var i = 0; i < _shiftTypes.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _buildShiftTypeCard(_shiftTypes[i])),
        ],
      ],
    );
  }

  Widget _buildShiftTypeCard(String type) {
    final isSelected = selectedShiftType == type;
    final color = shiftTypeColor(type);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTypeSelected(type),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: _isDark ? 0.18 : 0.10)
                : AppColors.inputFill(_isDark),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected
                  ? color
                  : AppColors.divider(_isDark),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(shiftTypeIcon(type),
                  color: isSelected
                      ? color
                      : AppColors.textSecondary(_isDark),
                  size: 26),
              const SizedBox(height: 7),
              Text(
                type,
                style: textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? AppColors.text(_isDark)
                      : AppColors.textSecondary(_isDark),
                  fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              if (_defaultStart[type] != null) ...[
                const SizedBox(height: 3),
                Text(
                  '${_defaultStart[type]!.format(context)} – ${_defaultEnd[type]!.format(context)}',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickers() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withValues(alpha: 0.03)
            : AppColors.inputFill(_isDark),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider(_isDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTimePickerCard(
              'بداية',
              startTime,
              Icons.login_rounded,
              _isDark ? AppColors.successLight : AppColors.success,
              () => _selectTime(context, true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded,
                color: ThemeService().accentColor, size: 18),
          ),
          Expanded(
            child: _buildTimePickerCard(
              'نهاية',
              endTime,
              Icons.logout_rounded,
              _isDark ? AppColors.warningLight : AppColors.warning,
              () => _selectTime(context, false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerCard(String label, TimeOfDay? time, IconData icon,
      Color color, VoidCallback onTap) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: time != null
                ? color.withValues(alpha: 0.45)
                : AppColors.divider(_isDark),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: time != null
                        ? color
                        : AppColors.textSecondary(_isDark),
                    size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: time != null
                        ? color
                        : AppColors.textSecondary(_isDark),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              time != null ? time.format(context) : '--:--',
              style: textTheme.titleLarge?.copyWith(
                color: time != null
                    ? AppColors.text(_isDark)
                    : AppColors.textHint(_isDark),
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffDayPicker(String label, int? value, bool isFirst) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _pickOffDay(isFirst),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: value != null
                ? ThemeService().accentColor.withValues(alpha: 0.5)
                : AppColors.divider(_isDark),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.weekend_rounded,
                color: value != null
                    ? ThemeService().accentColor
                    : AppColors.textSecondary(_isDark),
                size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value != null ? _weekdayNames[value] : 'غير محدد',
                    style: textTheme.titleSmall?.copyWith(
                      color: value != null
                          ? AppColors.text(_isDark)
                          : AppColors.textHint(_isDark),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: _isDark ? AppColors.errorLight : AppColors.error,
                    size: 18),
                onPressed: () => setState(() {
                  if (isFirst) {
                    offDay1 = null;
                    _offDay1Cleared = true;
                  } else {
                    offDay2 = null;
                    _offDay2Cleared = true;
                  }
                }),
                tooltip: 'مسح',
              )
            else
              Icon(Icons.expand_more_rounded,
                  color: AppColors.textSecondary(_isDark), size: 20),
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
          Icons.play_circle_rounded,
          _isDark ? AppColors.successLight : AppColors.success,
          () => _selectDate(context, true),
        ),
        const SizedBox(height: 10),
        _buildDatePickerCard(
          'نهاية السريان (اختياري)',
          effectiveTo,
          Icons.stop_circle_rounded,
          _isDark ? AppColors.warningLight : AppColors.warning,
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
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.inputFill(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: date != null
                ? color.withValues(alpha: 0.45)
                : AppColors.divider(_isDark),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: _isDark ? 0.18 : 0.10),
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
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date != null
                        ? DateFormat('yyyy-MM-dd').format(date)
                        : (isOptional ? 'غير محدد (مفتوح)' : 'اختر التاريخ'),
                    style: textTheme.titleSmall?.copyWith(
                      color: date != null
                          ? AppColors.text(_isDark)
                          : AppColors.textHint(_isDark),
                      fontWeight:
                          date != null ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isOptional && date != null && onClear != null)
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: _isDark ? AppColors.errorLight : AppColors.error,
                    size: 18),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }

  /// مدة الشيفت بدلالة بلازور: نهاية أسبق من البداية تعني عبور
  /// منتصف الليل فتُضاف 24 ساعة (DurationDisplay في الـ DTO)
  String _durationLabel() {
    if (startTime == null || endTime == null) return 'غير محدد';
    var start = startTime!.hour * 60 + startTime!.minute;
    var end = endTime!.hour * 60 + endTime!.minute;
    if (end <= start) end += 24 * 60;
    final dur = end - start;
    final h = dur ~/ 60;
    final m = dur % 60;
    final base = m > 0 ? '$h ساعة و $m دقيقة' : '$h ساعة';
    final overnight = (endTime!.hour * 60 + endTime!.minute) <=
        (startTime!.hour * 60 + startTime!.minute);
    return overnight ? '$base (ليلي)' : base;
  }

  String get _offDaysLabel {
    final days = <String>[
      if (offDay1 != null) _weekdayNames[offDay1!],
      if (offDay2 != null) _weekdayNames[offDay2!],
    ];
    return days.isEmpty ? 'غير محدد' : days.join(' و ');
  }

  Widget _buildShiftSummary() {
    final textTheme = Theme.of(context).textTheme;
    final typeColor = shiftTypeColor(selectedShiftType);
    return AppCard(
      color: AppColors.surface(_isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_rounded,
                  color: ThemeService().accentColor, size: 17),
              const SizedBox(width: 8),
              Text(
                'ملخص الشيفت',
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.text(_isDark),
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : AppColors.inputFill(_isDark),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.divider(_isDark)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        'النوع',
                        selectedShiftType,
                        shiftTypeIcon(selectedShiftType),
                        typeColor,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        'الوقت',
                        '${startTime!.format(context)} - ${endTime!.format(context)}',
                        Icons.access_time_rounded,
                        ThemeService().accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        'المدة',
                        _durationLabel(),
                        Icons.timelapse_rounded,
                        ThemeService().accentColor,
                      ),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        'الراحة',
                        _offDaysLabel,
                        Icons.weekend_rounded,
                        _isDark ? AppColors.infoLight : AppColors.info,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    final textTheme = Theme.of(context).textTheme;
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
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.text(_isDark),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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

  /// شريط حفظ لاصق كحلي في الوضعين وزر ذهبي ممتلئ بنص كحلي —
  /// لغة شاشة الفاتورة المعتمدة
  Widget _buildSaveBar() {
    return Container(
      color: AppColors.navy,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _isLoading ? null : _saveShift,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navy,
                disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: AppColors.navy, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isEdit ? Icons.update_rounded : Icons.save_rounded,
                            size: 19),
                        const SizedBox(width: 9),
                        Text(
                          isEdit ? 'تحديث الشيفت' : 'حفظ الشيفت',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
