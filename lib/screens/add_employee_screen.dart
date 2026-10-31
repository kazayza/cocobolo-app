import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' as intl;
import '../constants.dart';
import '../core/auth/session_service.dart';
import '../services/employee_photo_service.dart';
import '../widgets/employee_picker.dart';

class AddEmployeeScreen extends StatefulWidget {
  final int userId;
  final String username;
  final Map<String, dynamic>? existingEmployee;

  const AddEmployeeScreen({
    Key? key,
    required this.userId,
    required this.username,
    this.existingEmployee,
  }) : super(key: key);

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;

  // Controllers
  final _nameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _yearQualificationController = TextEditingController();
  final _salaryController = TextEditingController();
  final _salaryReasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _bioIdController = TextEditingController(); // ✅ كود البصمة

  // قائمة المؤهلات الافتراضية في نموذج بلازور (قابلة للإنشاء هناك)
  static const List<String> qualificationDefaults = [
    'بكالوريوس', 'ليسانس', 'ماجستير', 'دكتوراه', 'دبلوم فني',
    'دبلوم فوق المتوسط', 'ثانوية عامة', 'إعدادية', 'أمي',
  ];

  // محافظات الرقم القومي المصري — الخانتان الثامنة والتاسعة من الرقم
  // (المواضع 7 و8 بفهرسة الصفر)، وهي أكواد جهة الإصدار الرسمية.
  // تُشتق المحافظة وتُملأ في «العنوان» مطابقةً لاشتراط بلازور المسجل
  // (الرقم القومي يملأ تاريخ الميلاد والنوع والمحافظة في العنوان).
  static const Map<String, String> governorateByCode = {
    '01': 'القاهرة',
    '02': 'الإسكندرية',
    '03': 'بورسعيد',
    '04': 'السويس',
    '11': 'دمياط',
    '12': 'الدقهلية',
    '13': 'الشرقية',
    '14': 'القليوبية',
    '15': 'كفر الشيخ',
    '16': 'الغربية',
    '17': 'المنوفية',
    '18': 'البحيرة',
    '19': 'الإسماعيلية',
    '21': 'الجيزة',
    '22': 'بني سويف',
    '23': 'الفيوم',
    '24': 'المنيا',
    '25': 'أسيوط',
    '26': 'سوهاج',
    '27': 'قنا',
    '28': 'أسوان',
    '29': 'الأقصر',
    '31': 'البحر الأحمر',
    '32': 'الوادي الجديد',
    '33': 'مطروح',
    '34': 'شمال سيناء',
    '35': 'جنوب سيناء',
    '88': 'خارج الجمهورية',
  };

  // حارس اشتقاق المحافظة: آخر رقم قومي كامل اشتُقّت منه المحافظة،
  // ونص المحافظة الذي كتبته الاشتقاقة نفسها داخل العنوان — حتى لا
  // تُكتب فوق أي نص كتبه المستخدم بيده مع ضغطات مفاتيح لاحقة، ولا
  // تُعاد الاشتقاقة إلا إذا تغيّر الرقم نفسه إلى قيمة كاملة أخرى
  String? _lastGovernorateId;
  String? _derivedGovernorate;

  // Dropdowns Lists
  List<String> departments = [];
  List<String> jobTitles = [];
  List<Map<String, dynamic>> branches = [];

  // Selected Values
  String? selectedDepartment;
  String? selectedJobTitle;
  String? selectedGender;
  int? selectedBranchId;
  // المدير المباشر — اختياري وقابل للمسح، من الموظفين النشطين
  int? selectedDirectManagerId;
  String? selectedDirectManagerName;
  List<EmployeeOption> _managerOptions = [];
  String selectedStatus = 'نشط';
  bool isExemptFromAttendance = false; // ✅ الإعفاء من البصمة

  // تتبع تغيير المرتب في وضع التعديل (قاعدة بلازور: سبب إلزامي + سجل)
  double? _originalSalary;
  List<dynamic> _salaryHistory = [];
  bool _loadingHistory = false;

  // صورة الموظف — محلية على الجهاز فقط (EmployeePhotoService)، لا
  // تُرسل إلى الباك إند إطلاقًا: بايتات مختارة في هذا التحرير،
  // وبايتات محمّلة من التخزين المحلي عند التعديل، وعلم مسح صريح
  Uint8List? _pickedPhotoBytes;
  Uint8List? _existingPhotoBytes;
  bool _photoCleared = false;

  // عقدة تركيز حقل المؤهل (الإكمال التلقائي يحتاجها صراحة)
  final _qualificationFocus = FocusNode();

  bool get _salaryChanged {
    if (!isEditing || _originalSalary == null) return false;
    final current = double.tryParse(_salaryController.text) ?? 0;
    return current != _originalSalary;
  }
  
  // Dates
  DateTime? birthDate;
  DateTime? hireDate;
  DateTime? endDate;

  bool get isEditing => widget.existingEmployee != null;

  // أقسام النموذج القابلة للطي — الأول مفتوح افتراضيًا (كان ExpansionTile)
  final Set<int> _openSections = {0};

  // مفاتيح بطاقات الأقسام — لتمرير خطوات مسار الخطوات إلى قسمها عند النقر
  final List<GlobalKey> _sectionKeys = List.generate(5, (_) => GlobalKey());

  /// طيّ/فتح قسم — نفس مسار setState الذي تستخدمه ترويسات الأقسام
  void _toggleSection(int index) {
    setState(() {
      if (_openSections.contains(index)) {
        _openSections.remove(index);
      } else {
        _openSections.add(index);
      }
    });
  }

  /// نقر عقدة في مسار الخطوات: تبديل القسم ثم التمرير إليه في موضعه
  void _onStepTap(int index) {
    _toggleSection(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sectionKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.05,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// وضع الثيم الحالي — كل سطح ولون في هذه الشاشة يُشتق منه
  bool get _isDark => ThemeService().isDarkMode;

  /// نمط تسمية الحقول الموحّد: ثانوي، 13، شبه عريض — من ثيم النصوص
  TextStyle? get _labelStyle =>
      Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textSecondary(_isDark),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          );

  /// لون الخطأ بدرجة الوضع الحالي (نصوص ومؤشرات)
  Color get _errorColor => _isDark ? AppColors.errorLight : AppColors.error;

  /// تعبئة الحقول فوق بطاقات السطح: في الليلي درجة البطاقة الأخف حتى لا
  /// تذوب الحقول في لون البطاقة نفسه (inputFill الليلي = لون السطح)،
  /// وفي النهاري تعبئة الإدخال القياسية
  Color get _fieldFill =>
      _isDark ? AppColors.card(_isDark) : AppColors.inputFill(_isDark);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // خيارات المدير المباشر: الموظفون النشطون، مع استبعاد الموظف
    // نفسه في وضع التعديل (لا يكون مديرًا مباشرًا لنفسه)
    fetchActiveEmployeeOptions(
      excludeId: isEditing
          ? (widget.existingEmployee!['EmployeeID'] as num?)?.toInt()
          : null,
    ).then((options) {
      if (!mounted) return;
      setState(() {
        _managerOptions = options;
        // اسم المدير المحفوظ قد لا يأتي مع بيانات الموظف — يُستكمل
        // من قائمة النشطين عند غيابه
        if (selectedDirectManagerId != null &&
            (selectedDirectManagerName == null ||
                selectedDirectManagerName!.isEmpty)) {
          for (final o in options) {
            if (o.id == selectedDirectManagerId) {
              selectedDirectManagerName = o.name;
              break;
            }
          }
        }
      });
    });
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/employees/lookups'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          departments = List<String>.from(data['departments']);
          jobTitles = List<String>.from(data['jobTitles']);
          if (data['branches'] is List) {
            branches = (data['branches'] as List)
                .map((b) => Map<String, dynamic>.from(b as Map))
                .toList();
          }
        });
      }

      if (isEditing) {
        _fillExistingData();
        _loadSalaryHistory();
        _loadExistingPhoto();
      }

      setState(() => _isLoadingData = false);
    } catch (e) {
      setState(() => _isLoadingData = false);
      _showErrorSnackBar('فشل تحميل البيانات');
    }
  }

  /// تحميل الصورة المحلية المحفوظة لهذا الموظف على الجهاز (إن وُجدت)
  Future<void> _loadExistingPhoto() async {
    final id = (widget.existingEmployee!['EmployeeID'] as num?)?.toInt();
    if (id == null) return;
    await EmployeePhotoService().loadFor(id);
    if (!mounted) return;
    setState(
      () => _existingPhotoBytes = EmployeePhotoService().bytesFor(id),
    );
  }

  void _fillExistingData() {
    final emp = widget.existingEmployee!;
    _nameController.text = emp['FullName'] ?? '';
    _nationalIdController.text = emp['NationalID'] ?? '';
    _phoneController.text = emp['MobilePhone'] ?? '';
    _phone2Controller.text = emp['MobilePhone2'] ?? '';
    _emailController.text = emp['EmailAddress'] ?? '';
    _addressController.text = emp['Address'] ?? '';
    _qualificationController.text = emp['qualification'] ?? '';
    _yearQualificationController.text = emp['yearqualification']?.toString() ?? '';
    _salaryController.text = emp['CurrentSalaryBase']?.toString() ?? '';
    _originalSalary = _asDoubleOrNull(emp['CurrentSalaryBase']);
    _notesController.text = emp['Notes'] ?? '';
    _bioIdController.text = emp['BioEmployeeID']?.toString() ?? ''; // ✅
    selectedDepartment = emp['Department'];
    selectedJobTitle = emp['JobTitle'];
    selectedGender = emp['Gender'];
    selectedBranchId = (emp['BranchID'] as num?)?.toInt();
    selectedDirectManagerId = (emp['directManagerId'] as num?)?.toInt() ??
        (emp['DirectManagerID'] as num?)?.toInt() ??
        (emp['directManagerID'] as num?)?.toInt();
    selectedDirectManagerName =
        emp['directManagerName']?.toString() ?? emp['DirectManagerName']?.toString();
    selectedStatus = emp['Status'] ?? 'نشط';
    isExemptFromAttendance = emp['IsPermanentlyExempt'] ?? false; // ✅
    
    if (emp['BirthDate'] != null) birthDate = DateTime.parse(emp['BirthDate']);
    if (emp['HireDate'] != null) hireDate = DateTime.parse(emp['HireDate']);
    if (emp['EndDate'] != null) endDate = DateTime.parse(emp['EndDate']);

    // قيم قديمة قد لا توجد في قوائم الاختيار الحالية (مسمى/قسم أُلغي من
    // الاستخدام أو فرع حُذف): القائمة المنسدلة بقيمة غائبة عن عناصرها
    // تُسقط الشاشة كلها بخطأ أحمر. الحل الحافظ للبيانات: تُضاف قيمة
    // الموظف الحالية إلى قائمة المسمى/القسم (كما تفعل الإضافة السريعة)
    // فتبقى مختارة وتُحفظ كما هي، ويُفرَّغ ما لا قائمة مفتوحة له —
    // النوع قائمة مغلقة (ذكر/أنثى) والفرع اختياري قابل للمسح أصلًا.
    if (selectedDepartment != null &&
        selectedDepartment!.isNotEmpty &&
        !departments.contains(selectedDepartment)) {
      departments.add(selectedDepartment!);
    }
    if (selectedJobTitle != null &&
        selectedJobTitle!.isNotEmpty &&
        !jobTitles.contains(selectedJobTitle)) {
      jobTitles.add(selectedJobTitle!);
    }
    if (selectedGender != null &&
        selectedGender != 'ذكر' &&
        selectedGender != 'أنثى') {
      selectedGender = null;
    }
    if (selectedBranchId != null &&
        !branches.any(
            (b) => (b['id'] as num?)?.toInt() == selectedBranchId)) {
      selectedBranchId = null;
    }
  }

  /// تحويل متسامح لقيمة رقمية قادمة من الباك إند: المبالغ قد تصل
  /// أرقامًا أو نصوصًا («9500.00») بحسب نوع العمود والسائق — القراءة
  /// الآمنة بدل التحويل القسري الذي يُسقط البناء بخطأ نوع
  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double? _asDoubleOrNull(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  Future<void> _loadSalaryHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/employees/${widget.existingEmployee!['EmployeeID']}/salary-history'),
        headers: SessionService.instance.authHeaders,
      );
      if (res.statusCode == 200) {
        setState(() => _salaryHistory = jsonDecode(res.body) as List<dynamic>);
      }
    } catch (e) {
      // قسم السجل اختياري العرض — فشل تحميله لا يمنع تعديل الموظف
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  // إضافة قيمة جديدة إلى قائمة اختيار (قسم/مسمى) — مرآة Creatable في بلازور:
  // تُضاف محليًا وتُختار فورًا، وحفظها الفعلي ضمن حفظ الموظف.
  Future<void> _addLookupValue({
    required String title,
    required List<String> list,
    required void Function(String) onAdded,
  }) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface(_isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                color: AppColors.text(_isDark),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: Theme.of(dialogContext).textTheme.bodyLarge?.copyWith(
                color: AppColors.text(_isDark),
              ),
          decoration: InputDecoration(
            hintText: 'اكتب القيمة الجديدة',
            hintStyle: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textHint(_isDark),
                ),
            filled: true,
            fillColor: _fieldFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ThemeService().accentColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'إلغاء',
              style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                  ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: Text(
              'إضافة',
              style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(
                    color: _isDark ? AppColors.gold : AppColors.navy,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      setState(() {
        if (!list.contains(value)) list.add(value);
        onAdded(value);
      });
    }
  }

  void _analyzeNationalId(String id) {
    if (id.length != 14) return;
    try {
      int century = int.parse(id[0]);
      int year = int.parse(id.substring(1, 3));
      int month = int.parse(id.substring(3, 5));
      int day = int.parse(id.substring(5, 7));
      year += (century == 2 ? 1900 : 2000);

      int genderCode = int.parse(id.substring(12, 13));
      String gender = (genderCode % 2 != 0) ? 'ذكر' : 'أنثى';

      setState(() {
        birthDate = DateTime(year, month, day);
        selectedGender = gender;
        // المحافظة من خانتي جهة الإصدار (7، 8) تُملأ في العنوان كما
        // في بلازور — بشرطين: أن يكون الرقم قد تغيّر فعلًا عن آخر
        // اشتقاقة، وألا يحمل العنوان نصًا كتبه المستخدم بنفسه (يُملأ
        // فقط إن كان فارغًا أو كان هو نفسه نص المحافظة المشتقة سابقًا
        // ولم يُعدّله المستخدم)
        final governorate = governorateByCode[id.substring(7, 9)];
        if (governorate != null && id != _lastGovernorateId) {
          _lastGovernorateId = id;
          final currentAddress = _addressController.text.trim();
          if (currentAddress.isEmpty ||
              currentAddress == _derivedGovernorate) {
            _addressController.text = governorate;
            _derivedGovernorate = governorate;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم استخراج البيانات تلقائياً ✅'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('خطأ في تحليل الرقم القومي');
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    // حقول مطلوبة في بلازور خارج مدققات النموذج النصية
    if (selectedJobTitle == null || selectedJobTitle!.isEmpty) {
      _showErrorSnackBar('المسمى الوظيفي مطلوب');
      return;
    }
    if (hireDate == null) {
      _showErrorSnackBar('تاريخ التعيين مطلوب');
      return;
    }
    // قاعدة بلازور + الباك إند (المرحلة صفر): تغيير المرتب بلا سبب يُرفض
    if (_salaryChanged && _salaryReasonController.text.trim().isEmpty) {
      _showErrorSnackBar('يجب إدخال سبب تغيير المرتب');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final body = {
        'fullName': _nameController.text.trim(),
        'nationalId': _nationalIdController.text.trim(),
        'department': selectedDepartment,
        'jobTitle': selectedJobTitle,
        'gender': selectedGender,
        'mobilePhone': _phoneController.text.trim(),
        'mobilePhone2': _phone2Controller.text.trim(),
        'emailAddress': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'qualification': _qualificationController.text.trim(),
        'yearQualification': _yearQualificationController.text.trim().isEmpty
            ? null
            : _yearQualificationController.text.trim(),
        'branchId': selectedBranchId,
        // المدير المباشر: المفتاح يُرسل دائمًا في التعديل حتى يثبت
        // المسح (null)، وفي الإضافة عند الاختيار فقط
        if (isEditing || selectedDirectManagerId != null)
          'directManagerId': selectedDirectManagerId,
        'currentSalaryBase': double.tryParse(_salaryController.text) ?? 0,
        'bioEmployeeId': int.tryParse(_bioIdController.text), // ✅
        'isPermanentlyExempt': isExemptFromAttendance, // ✅
        'status': selectedStatus,
        'notes': _notesController.text.trim(),
        // الصورة لا تُرسل إطلاقًا: تُحفظ محليًا على الجهاز فقط
        // المنشئ لم يعد يُرسل: الباك إند يأخذه من التوكن (المرحلة صفر)
        if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
        if (hireDate != null) 'hireDate': hireDate!.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        if (_salaryChanged) 'salaryChangeReason': _salaryReasonController.text.trim(),
      };

      http.Response res;
      if (isEditing) {
        res = await http.put(
          Uri.parse('$baseUrl/api/employees/${widget.existingEmployee!['EmployeeID']}'),
          headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else {
        res = await http.post(
          Uri.parse('$baseUrl/api/employees'),
          headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      }

      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        await _persistPhotoLocally(result);
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

  /// حفظ الصورة محليًا على الجهاز بعد نجاح الحفظ — لا تُرسل إلى
  /// الباك إند إطلاقًا: عند التعديل تُحفظ الصورة الجديدة أو تُمسح
  /// القديمة عند «إزالة»، وعند الإضافة تُربط برقم الموظف الجديد
  /// القادم في رد الإنشاء (employeeId)
  Future<void> _persistPhotoLocally(dynamic result) async {
    final service = EmployeePhotoService();
    if (isEditing) {
      final id = (widget.existingEmployee!['EmployeeID'] as num?)?.toInt();
      if (id == null) return;
      if (_photoCleared) {
        await service.deleteFor(id);
      } else if (_pickedPhotoBytes != null) {
        await service.saveFor(id, _pickedPhotoBytes!);
      }
    } else if (_pickedPhotoBytes != null) {
      final newId = (result is Map)
          ? (result['employeeId'] as num?)?.toInt()
          : null;
      if (newId != null) {
        await service.saveFor(newId, _pickedPhotoBytes!);
      }
    }
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
            const Icon(Icons.check_circle, color: AppColors.success, size: 60)
                .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              isEditing ? 'تم التعديل بنجاح!' : 'تم الإضافة بنجاح!',
              style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                    color: AppColors.text(_isDark),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      Navigator.pop(context);
      Navigator.pop(context, true);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _selectDate(BuildContext context, int type) async {
    DateTime initial = DateTime.now();
    if (type == 1 && birthDate != null) initial = birthDate!;
    if (type == 2 && hireDate != null) initial = hireDate!;
    if (type == 3 && endDate != null) initial = endDate!;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.gold,
                surface: AppColors.surface(_isDark),
              ),
        ),
        child: child!,
      ),
    );
    
    if (picked != null) {
      setState(() {
        if (type == 1) birthDate = picked;
        if (type == 2) hireDate = picked;
        if (type == 3) endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(_isDark),
      // شريط سفلي لاصق كحلي بزر حفظ ذهبي — لغة شاشة الفاتورة المعتمدة
      bottomNavigationBar: _isLoadingData ? null : _buildSaveBar(),
      body: _isLoadingData
          ? const AppLoading()
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildAnchorHeader(),
                          const SizedBox(height: 12),
                          _buildStepTrack(),
                          const SizedBox(height: 12),
                          // 1. البيانات الشخصية
                          _buildExpansionSection(
                            index: 0,
                            title: 'البيانات الشخصية',
                            icon: Icons.person_outline,
                            children: [
                              _buildPhotoRow(),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _nameController,
                                label: 'الاسم الكامل',
                                icon: Icons.person_rounded,
                                isRequired: true,
                              ),
                              _buildTextField(
                                controller: _nationalIdController,
                                label: 'الرقم القومي (14 رقم)',
                                icon: Icons.badge_rounded,
                                keyboardType: TextInputType.number,
                                maxLength: 14,
                                isRequired: true,
                                onChanged: (val) {
                                  if (val.length == 14) {
                                    _analyzeNationalId(val);
                                  } else {
                                    // كسر اكتمال الرقم يُعيد تهيئة حارس
                                    // المحافظة، فتُشتق من جديد عند اكتماله
                                    _lastGovernorateId = null;
                                  }
                                },
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDropdown(
                                      label: 'النوع',
                                      value: selectedGender,
                                      items: ['ذكر', 'أنثى'],
                                      onChanged: (v) => setState(() => selectedGender = v),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDatePicker(
                                      label: 'تاريخ الميلاد',
                                      date: birthDate,
                                      onTap: () => _selectDate(context, 1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildQualificationField(),
                              _buildTextField(
                                controller: _yearQualificationController,
                                label: 'سنة التخرج',
                                icon: Icons.calendar_month_rounded,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                              ),
                              _buildTextField(
                                controller: _addressController,
                                label: 'العنوان',
                                icon: Icons.location_on_rounded,
                                maxLines: 2,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // 2. بيانات العمل — ترتيب بلازور: المسمى، القسم، الفرع،
                          // الحالة، التعيين، الانتهاء، المرتب، كود البصمة
                          _buildExpansionSection(
                            index: 1,
                            title: 'بيانات العمل',
                            icon: Icons.work_outline,
                            children: [
                              // المسمى والقسم بعرض كامل متكدّسين (كانا متجاورين
                              // ضيّقين) — وكلٌّ مع حبة إضافته السريعة كما هي
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildDropdown(
                                      label: 'المسمى الوظيفي *',
                                      value: selectedJobTitle,
                                      items: jobTitles,
                                      onChanged: (v) => setState(() => selectedJobTitle = v),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: _buildQuickAddPill(
                                      tooltip: 'مسمى جديد',
                                      onPressed: () => _addLookupValue(
                                        title: 'إضافة مسمى وظيفي',
                                        list: jobTitles,
                                        onAdded: (v) => selectedJobTitle = v,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildDropdown(
                                      label: 'القسم',
                                      value: selectedDepartment,
                                      items: departments,
                                      onChanged: (v) => setState(() => selectedDepartment = v),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: _buildQuickAddPill(
                                      tooltip: 'قسم جديد',
                                      onPressed: () => _addLookupValue(
                                        title: 'إضافة قسم',
                                        list: departments,
                                        onAdded: (v) => selectedDepartment = v,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // الفرع — من قوائم الباك إند (أضيفت في المرحلة صفر)
                              _buildBranchDropdown(),

                              const SizedBox(height: 12),

                              // المدير المباشر — منتقي بحث من الموظفين
                              // النشطين، اختياري وقابل للمسح
                              _buildDirectManagerField(),

                              const SizedBox(height: 12),
                              
                              // الحالة (الحالات الأربع كما في بلازور) — وحدها
                              // في حاويتها المظلّلة بعد نقل التاريخين خارجها
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedStatus == 'موقوف'
                                        ? AppColors.error.withValues(alpha: 0.3)
                                        : AppColors.success.withValues(alpha: 0.3)
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: selectedStatus == 'موقوف'
                                      ? AppColors.error.withValues(alpha: 0.05)
                                      : AppColors.success.withValues(alpha: 0.05),
                                ),
                                child: _buildStatusDropdown(),
                              ),

                              const SizedBox(height: 12),

                              // تاريخ التعيين ثم تاريخ الإنهاء — كلٌّ بعرض
                              // كامل وبتسمية صريحة ثابتة فوق الحقل (كانت
                              // تسمية التعيين تختفي بعد اختيار التاريخ)
                              _buildDatePicker(
                                label: 'تاريخ التعيين *',
                                date: hireDate,
                                onTap: () => _selectDate(context, 2),
                              ),

                              const SizedBox(height: 12),

                              _buildDatePicker(
                                label: 'تاريخ الإنهاء',
                                date: endDate,
                                onTap: () => _selectDate(context, 3),
                              ),

                              const SizedBox(height: 12),

                              // ✅ الراتب الأساسي — وحده في لوحته الفرعية
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : AppColors.inputFill(_isDark),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : AppColors.divider(_isDark),
                                  ),
                                ),
                                child: _buildTextField(
                                  controller: _salaryController,
                                  label: 'الراتب الأساسي',
                                  icon: Icons.payments_rounded,
                                  keyboardType: TextInputType.number,
                                  isSmall: true,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),

                              const SizedBox(height: 12),

                              _buildTextField(
                                controller: _bioIdController,
                                label: 'كود البصمة',
                                icon: Icons.fingerprint_rounded,
                                keyboardType: TextInputType.number,
                              ),

                              // تغيير المرتب في التعديل: لوحة فرعية مظلّلة داخل
                              // بطاقة القسم تحمل التنبيه وحقل السبب الإلزامي معًا
                              // (قاعدة بلازور) — تجميع «لوحة داخل لوحة»
                              if (_salaryChanged) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                                  decoration: BoxDecoration(
                                    color: (_isDark ? AppColors.infoLight : AppColors.info)
                                        .withValues(alpha: _isDark ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (_isDark ? AppColors.infoLight : AppColors.info)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            size: 18,
                                            color: _isDark ? AppColors.infoLight : AppColors.info,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'تنبيه: تم تغيير المرتب من ${_originalSalary!.toStringAsFixed(2)} إلى ${(double.tryParse(_salaryController.text) ?? 0).toStringAsFixed(2)} ج.م',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    color: _isDark ? AppColors.infoLight : AppColors.info,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTextField(
                                        controller: _salaryReasonController,
                                        label: 'سبب تغيير المرتب',
                                        icon: Icons.edit_note_rounded,
                                        isRequired: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // 3. بيانات الاتصال (أرقام تحت بعض)
                          _buildExpansionSection(
                            index: 2,
                            title: 'بيانات الاتصال',
                            icon: Icons.contact_phone_outlined,
                            children: [
                              _buildTextField(
                                controller: _phoneController,
                                label: 'رقم الهاتف 1 (أساسي)',
                                icon: Icons.call_rounded,
                                keyboardType: TextInputType.phone,
                              ),
                              _buildTextField(
                                controller: _phone2Controller,
                                label: 'رقم الهاتف 2 (اختياري)',
                                icon: Icons.call_rounded,
                                keyboardType: TextInputType.phone,
                              ),
                              _buildTextField(
                                controller: _emailController,
                                label: 'البريد الإلكتروني',
                                icon: Icons.mail_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 4. إعدادات إضافية — الإعفاء الدائم والملاحظات (تبويب بلازور الرابع).
                          // حقل الملاحظات كان له متحكم يُرسل دائمًا لكنه لم يُرسم قط.
                          _buildExpansionSection(
                            index: 3,
                            title: 'إعدادات إضافية',
                            icon: Icons.settings_outlined,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isExemptFromAttendance
                                      ? AppColors.warning.withValues(alpha: 0.1)
                                      : (_isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : AppColors.inputFill(_isDark)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isExemptFromAttendance
                                        ? AppColors.warning.withValues(alpha: 0.3)
                                        : Colors.transparent
                                  ),
                                ),
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    isExemptFromAttendance ? 'معفي من الحضور' : 'غير معفي من الحضور',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontSize: 13,
                                          // التحذير نصًا في الليلي فقط — النهاري نص الهوية عريض
                                          color: isExemptFromAttendance
                                              ? (_isDark ? AppColors.warning : AppColors.text(_isDark))
                                              : AppColors.textSecondary(_isDark),
                                          fontWeight: isExemptFromAttendance ? FontWeight.bold : FontWeight.normal,
                                        ),
                                  ),
                                  subtitle: Text(
                                    'إعفاء دائم من الحضور',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontSize: 11,
                                          color: AppColors.textSecondary(_isDark),
                                        ),
                                  ),
                                  value: isExemptFromAttendance,
                                  onChanged: (val) => setState(() => isExemptFromAttendance = val),
                                  activeColor: AppColors.warning,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _notesController,
                                label: 'ملاحظات',
                                icon: Icons.notes_rounded,
                                maxLines: 4,
                              ),
                            ],
                          ),

                          // 5. سجل المرتبات — وضع التعديل فقط (تبويب بلازور الخامس)
                          if (isEditing) ...[
                            const SizedBox(height: 12),
                            _buildExpansionSection(
                              index: 4,
                              title: 'سجل المرتبات',
                              icon: Icons.history_outlined,
                              children: [
                                if (_loadingHistory)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                                  )
                                else if (_salaryHistory.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      'لا يوجد سجل تغييرات — لم يتم تسجيل أي تغييرات على المرتب بعد.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppColors.textSecondary(_isDark),
                                            fontSize: 13,
                                          ),
                                    ),
                                  )
                                else
                                  _buildSalaryTimeline(_salaryHistory),
                              ],
                            ),
                          ],

                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// بطاقة مرساة كحلية في رأس النموذج — هوية الشاشة في الوضعين (لغة
  /// شاشة الفاتورة): رقاقة ذهبية (أيقونة إضافة / الحرف الأول عند التعديل)،
  /// والاسم عنوانًا مع المسمى والقسم سطرًا واقعيًا عند التعديل
  Widget _buildAnchorHeader() {
    final emp = widget.existingEmployee;
    final name = emp?['FullName']?.toString().trim() ?? '';
    final job = emp?['JobTitle']?.toString().trim() ?? '';
    final dept = emp?['Department']?.toString().trim() ?? '';
    final subtitle = [job, dept].where((s) => s.isNotEmpty).join(' • ');
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: isEditing
                    ? Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '؟',
                          style: textTheme.titleLarge?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_add_rounded,
                        color: AppColors.gold,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing
                          ? (name.isNotEmpty ? name : 'تعديل موظف')
                          : 'موظف جديد',
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    if (isEditing && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.goldLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!isEditing) ...[
            const SizedBox(height: 12),
            Container(
              height: 2,
              width: 52,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// مسار خطوات النموذج: عقد دائرية مرقّمة لأقسام النموذج تصلها خطوط
  /// شعرية — العقدة الذهبية لقسم مفتوح، ونقرها يبدّل قسمها ويمرّر إليه
  Widget _buildStepTrack() {
    final labels = <String>[
      'شخصية',
      'العمل',
      'اتصال',
      'إضافات',
      if (isEditing) 'المرتبات',
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  height: 2,
                  color: _openSections.contains(i - 1)
                      ? AppColors.gold
                      : AppColors.divider(_isDark),
                ),
              ),
            ),
          _buildStepNode(i, labels[i]),
        ],
      ],
    );
  }

  /// عقدة خطوة واحدة: دائرة 22px برقم القسم وتسمية 9.5 أسفلها
  Widget _buildStepNode(int index, String label) {
    final active = _openSections.contains(index);
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _onStepTap(index),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 44,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.gold : AppColors.surface(_isDark),
                border: active
                    ? null
                    : Border.all(color: AppColors.divider(_isDark)),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: textTheme.labelSmall?.copyWith(
                    color: active
                        ? AppColors.navy
                        : AppColors.textSecondary(_isDark),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: active
                    ? AppColors.text(_isDark)
                    : AppColors.textSecondary(_isDark),
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          isEditing ? 'تعديل موظف' : 'موظف جديد',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
        ),
      ),
    );
  }

  // قسم قابل للطي بترويسة مخصصة (InkWell) بدل ExpansionTile/ListTile:
  // شريط ذهبي + أيقونة داخل رقاقة مظلّلة بالذهبي + سهم — هوية واحدة لكل
  // الأقسام، وبلا تحذير ListTile فوق بطاقات الكيت
  Widget _buildExpansionSection({
    required int index,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isOpen = _openSections.contains(index);
    return AppCard(
      key: _sectionKeys[index],
      padding: EdgeInsets.zero,
      radius: AppRadius.lg,
      color: AppColors.surface(_isDark),
      child: Column(
        children: [
          // خط شعري ذهبي متدرج في أعلى البطاقة داخل نصف قطرها
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.gold.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => _toggleSection(index),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // بلاطة رقم القسم — تسلسل بصري للأقسام (1..5) قبل رقاقة
                  // الأيقونة، مظلّلة بالذهبي في الوضعين
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.gold
                          .withValues(alpha: _isDark ? 0.18 : 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: _isDark
                                      ? AppColors.gold
                                      : AppColors.goldDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.gold
                          .withValues(alpha: _isDark ? 0.18 : 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: _isDark ? AppColors.gold : AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.text(_isDark),
                              ),
                    ),
                  ),
                  Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary(_isDark),
                  ),
                ],
              ),
            ),
          ),
          // فتح/طي متحرك (~280ms easeOut) حول جسم القسم
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: isOpen
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(children: children),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  // زر إضافة سريعة لقوائم الاختيار: حبة ممتلئة صغيرة — كحلية بنص أبيض
  // نهاريًا، وذهبية بنص كحلي ليليًا فوق بطاقة السطح (ألوان الأزرار
  // الأساسية في الهوية)، بنفس معالجات الحوارات السابقة
  Widget _buildQuickAddPill({
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final dark = _isDark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark ? AppColors.gold : AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: dark ? AppColors.navy : Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'إضافة',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: dark ? AppColors.navy : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// تطبيع عربي لبحث الإكمال التلقائي: إزالة التشكيل والتطويل وتوحيد
  /// صور الألف والتاء المربوطة والألف المقصورة حتى يطابق البحث الكتابة
  /// بأي صورة إملائية
  static String _normalizeArabic(String s) {
    return s
        .replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640]'), '')
        .replaceAll(RegExp('[إأآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .trim()
        .toLowerCase();
  }

  /// زخرفة الإدخال الموحّدة لكل الحقول النصية: رقاقة أيقونة داخلية من
  /// عائلة الذهبي (30px)، وتعبئة بدرجة الوضع، وحدّ تركيز بلون التمييز
  InputDecoration _inputDecoration(
    IconData icon, {
    required EdgeInsetsGeometry contentPadding,
  }) {
    return InputDecoration(
      prefixIcon: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: _isDark ? 0.16 : 0.14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 17,
          color: _isDark ? AppColors.gold : AppColors.goldDark,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(
        minWidth: 44,
        minHeight: 34,
      ),
      filled: true,
      fillColor: _fieldFill,
      counterText: "",
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ThemeService().accentColor),
      ),
      contentPadding: contentPadding,
    );
  }

  /// حقل المؤهل العلمي: إكمال تلقائي فوق قائمة بلازور الافتراضية ببحث
  /// عربي مطبّع (يحتوي)، بنفس زخرفة الحقول الموحّدة — والنص الحر يبقى
  /// متاحًا، والقيمة المحفوظة هي نص المتحكم نفسه كما كانت
  Widget _buildQualificationField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المؤهل العلمي', style: _labelStyle),
          const SizedBox(height: 6),
          Autocomplete<String>(
            textEditingController: _qualificationController,
            focusNode: _qualificationFocus,
            optionsBuilder: (TextEditingValue value) {
              final q = _normalizeArabic(value.text);
              if (q.isEmpty) return qualificationDefaults;
              return qualificationDefaults
                  .where((o) => _normalizeArabic(o).contains(q));
            },
            onSelected: (String selection) {
              _qualificationController.text = selection;
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                onFieldSubmitted: (_) => onSubmitted(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.text(_isDark),
                    ),
                decoration: _inputDecoration(
                  Icons.school_rounded,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// البايتات المعروضة الآن: المسح الصريح يخفي الكل، ثم المختارة في
  /// هذا التحرير، ثم المحمّلة من التخزين المحلي عند فتح التعديل
  Uint8List? get _photoBytes =>
      _photoCleared ? null : (_pickedPhotoBytes ?? _existingPhotoBytes);

  bool get _hasPhoto => _photoBytes != null;

  /// اختيار صورة من المعرض: المنتقي نفسه يصغّرها (512) ويضغطها (85)،
  /// وتبقى بايتاتها في حالة الشاشة حتى نجاح الحفظ فتُخزّن محليًا
  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedPhotoBytes = bytes;
      _photoCleared = false;
    });
  }

  /// معاينة الصورة الافتراضية بحسب النوع المختار حاليًا في النموذج
  /// (selectedGender): «أنثى» للأنثى وما عداها للذكر — تتحدث فور
  /// تغيّر قائمة النوع لأن الصف يُبنى من الحالة، وهي ما يظهر عند
  /// غياب أي صورة مختارة أو محمّلة
  Widget _defaultPhotoPreview() {
    return ClipOval(
      child: Image.asset(
        selectedGender == 'أنثى'
            ? 'assets/images/default_avatar_female.png'
            : 'assets/images/default_avatar_male.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultPhotoGlyph(),
      ),
    );
  }

  /// رمز شخص على قرص متدرج كحلي — احتياطي أخير فقط عند فشل تحميل
  /// أصل الصورة الافتراضية المُجمّع داخل التطبيق
  Widget _defaultPhotoGlyph() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: AppGradients.identityHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.person_rounded, size: 34, color: AppColors.gold),
      ),
    );
  }

  /// صف الصورة في أعلى قسم البيانات الشخصية: معاينة دائرية 72px وحبة
  /// «اختيار صورة» ممتلئة، وزر «إزالة» عند وجود صورة (مسح صريح عند
  /// الحفظ من التخزين المحلي)
  Widget _buildPhotoRow() {
    final bytes = _photoBytes;
    final dark = _isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: dark
                      ? AppColors.gold.withValues(alpha: 0.55)
                      : AppColors.goldDark.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              child: bytes != null
                  ? Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: ClipOval(
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultPhotoPreview(),
                        ),
                      ),
                    )
                  : _defaultPhotoPreview(),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: dark ? AppColors.gold : AppColors.navy,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _pickPhoto,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image_rounded,
                            size: 16,
                            color: dark ? AppColors.navy : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'اختيار صورة',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: dark ? AppColors.navy : Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_hasPhoto)
                  TextButton(
                    onPressed: () => setState(() {
                      _pickedPhotoBytes = null;
                      _photoCleared = true;
                    }),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'إزالة',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _errorColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (_hasPhoto) ...[
          const SizedBox(height: 8),
          Text(
            'ستُحفظ الصورة على هذا الجهاز فقط',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 11,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    bool isRequired = false,
    bool isSmall = false,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: _labelStyle),
              if (isRequired)
                Text(
                  ' *',
                  style: _labelStyle?.copyWith(color: _errorColor),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            onChanged: onChanged,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.text(_isDark),
                ),
            decoration: _inputDecoration(
              icon,
              contentPadding: isSmall
                  ? const EdgeInsets.symmetric(vertical: 8, horizontal: 12)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            validator: isRequired
                ? (value) => value!.isEmpty ? 'هذا الحقل مطلوب' : null
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              // طبقة أمان أخيرة: قيمة غير موجودة في العناصر تُعرض كـ«لا
              // اختيار» بدل أن تُسقط الشاشة بخطأ القائمة المنسدلة
              value: (value != null && items.contains(value)) ? value : null,
              isExpanded: true,
              hint: Text(
                'اختر...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textHint(_isDark),
                      fontSize: 12,
                    ),
              ),
              dropdownColor: AppColors.surface(_isDark),
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary(_isDark)),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.text(_isDark),
                  ),
              items: items.map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('حالة الموظف', style: _labelStyle),
            Text(
              ' *',
              style: _labelStyle?.copyWith(color: _errorColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildStatusOption('نشط', _isDark ? AppColors.successLight : AppColors.success),
              _buildStatusOption('موقوف', _errorColor),
              _buildStatusOption('بالإجازة', _isDark ? AppColors.infoLight : AppColors.info),
              _buildStatusOption('مستقيل', AppColors.errorLight),
            ],
          ),
        ),
      ],
    );
  }

  // حقل المدير المباشر — منتقي بحث مشترك فوق الموظفين النشطين
  // (القائمة محمّلة عند فتح الشاشة وتستبعد الموظف نفسه عند التعديل)
  Widget _buildDirectManagerField() {
    return EmployeePickerField(
      label: 'المدير المباشر',
      hint: 'اختر المدير المباشر (اختياري)...',
      clearable: true,
      selected: selectedDirectManagerId == null
          ? null
          : EmployeeOption(
              id: selectedDirectManagerId!,
              name: selectedDirectManagerName ?? '',
            ),
      onClear: () => setState(() {
        selectedDirectManagerId = null;
        selectedDirectManagerName = null;
      }),
      onTap: () async {
        final picked = await showEmployeePickerSheet(
          context,
          employees: _managerOptions,
          title: 'اختر المدير المباشر',
        );
        if (!mounted || picked == null) return;
        setState(() {
          selectedDirectManagerId = picked.id;
          selectedDirectManagerName = picked.name;
        });
      },
    );
  }

  // قائمة الفرع — قيم رقمية من lookups.branches، قابلة للمسح (اختيارية)
  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الفرع', style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              // نفس طبقة الأمان: فرع غير موجود في القائمة = بلا اختيار
              value: (selectedBranchId != null &&
                      branches.any((b) =>
                          (b['id'] as num?)?.toInt() == selectedBranchId))
                  ? selectedBranchId
                  : null,
              isExpanded: true,
              hint: Text(
                'اختر الفرع...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textHint(_isDark),
                      fontSize: 12,
                    ),
              ),
              dropdownColor: AppColors.surface(_isDark),
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary(_isDark)),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.text(_isDark),
                  ),
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('— بدون فرع —')),
                ...branches.map((b) => DropdownMenuItem<int>(
                      value: (b['id'] as num).toInt(),
                      child: Text(b['name']?.toString() ?? ''),
                    )),
              ],
              onChanged: (v) => setState(() => selectedBranchId = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusOption(String status, Color color) {
    final isSelected = selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedStatus = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: color) : null,
          ),
          child: Center(
            child: Text(
              status,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? color : AppColors.textSecondary(_isDark),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool isSmall = false,
    bool isWarning = false,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isSmall) ...[
          Text(
            label,
            style: _labelStyle?.copyWith(
              color: isWarning ? _errorColor : AppColors.textSecondary(_isDark),
            ),
          ),
          const SizedBox(height: 6),
        ],
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isSmall ? Colors.transparent : _fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: isWarning ? Border.all(color: _errorColor.withValues(alpha: 0.3)) : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: iconColor ?? (isWarning ? _errorColor : AppColors.textSecondary(_isDark)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date != null ? intl.DateFormat('yyyy/MM/dd').format(date) : (isSmall ? label : '--/--/----'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.text(_isDark),
                          fontSize: 13,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// خط زمني لسجل المرتبات: خط عمودي متصل بلون الفاصل ونقاط ذهبية
  /// محاطة بحلقة، والإدخالات بترتيب تحميلها (الأحدث أولًا كما تصل)
  Widget _buildSalaryTimeline(List<dynamic> entries) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _buildSalaryTimelineEntry(
            entries[i],
            isFirst: i == 0,
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }

  Widget _buildSalaryTimelineEntry(
    dynamic h, {
    required bool isFirst,
    required bool isLast,
  }) {
    final oldS = _asDouble(h['OldSalary']);
    final newS = _asDouble(h['NewSalary']);
    final diff = newS - oldS;
    final d = DateTime.tryParse(h['ChangeDate']?.toString() ?? '');
    final textTheme = Theme.of(context).textTheme;
    final diffColor = diff > 0
        ? (_isDark ? AppColors.successLight : AppColors.success)
        : (diff < 0 ? _errorColor : AppColors.textSecondary(_isDark));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // سكة الخط: مقطع علوي قصير يصل بالعقدة السابقة، نقطة ذهبية
          // محاطة بحلقة بلون السطح، ثم خط ممتد حتى العقدة التالية
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst
                      ? Colors.transparent
                      : AppColors.divider(_isDark),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold,
                    border: Border.all(
                      color: AppColors.surface(_isDark),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : AppColors.divider(_isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        d == null
                            ? '—'
                            : intl.DateFormat('yyyy/MM/dd').format(d),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary(_isDark),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'من ${oldS.toStringAsFixed(2)} إلى ${newS.toStringAsFixed(2)} ج.م',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.text(_isDark),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(2)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: diffColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (h['Reason'] != null &&
                      h['Reason'].toString().isNotEmpty)
                    Text(
                      'السبب: ${h['Reason']}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 12,
                      ),
                    ),
                  if (h['CreatedBy'] != null &&
                      h['CreatedBy'].toString().isNotEmpty)
                    Text(
                      'بواسطة: ${h['CreatedBy']}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary(_isDark),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // الشريط السفلي اللاصق: كحلي في الوضعين ويحمل زر الحفظ — نفس لغة
  // الشريط اللاصق في شاشة إضافة الفاتورة المعتمدة، وبجانب الحبة سطر
  // سياق واقعي: المرتب الحالي عند التعديل (من حالة النموذج عند التحميل)
  Widget _buildSaveBar() {
    final contextText = isEditing
        ? (_originalSalary != null
            ? 'المرتب الحالي: ${intl.NumberFormat('#,##0.00').format(_originalSalary!)} جـ'
            : 'تعديل بيانات موظف')
        : 'بيانات موظف جديد';
    return Container(
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                contextText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.goldLight,
                      fontSize: 12,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _buildSaveButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    // زر الحفظ الأساسي داخل الشريط الكحلي: حبة ذهبية ممتلئة بنص كحلي
    // في الوضعين، وبنفس التسميات وبوابة التحميل السابقة تمامًا
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gold, AppColors.goldLight],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveEmployee,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: AppColors.navy)
            : Text(
                isEditing ? 'حفظ التعديلات' : 'إضافة الموظف',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
              ),
      ),
    );
  }
}