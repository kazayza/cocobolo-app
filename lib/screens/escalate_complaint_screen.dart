import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/complaints_service.dart';
import '../services/design_tokens.dart';
import '../widgets/design_kit.dart';
import '../services/employee_service.dart';
import '../models/employee_model.dart';
import '../services/permission_service.dart';
import '../widgets/loading_button.dart';

class EscalateComplaintScreen extends StatefulWidget {
  final int complaintId;

  const EscalateComplaintScreen({
    super.key,
    required this.complaintId,
  });

  @override
  State<EscalateComplaintScreen> createState() => _EscalateComplaintScreenState();
}

class _EscalateComplaintScreenState extends State<EscalateComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  
  int? _selectedEmployeeId;
  List<EmployeeModel> _managers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadManagers();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadManagers() async {
    try {
      final employeeService = EmployeeService();
      // جلب المدراء (الموظفين المناسبين للتصعيد)
      final employees = await employeeService.getActiveEmployees();
      
      setState(() {
        // فلترة: ناخد المديرين أو أي تصنيف مناسب
        _managers = employees.where((e) {
          // مثلاً: المديرين أو الـ CEOs
          return e.jobTitle?.contains('مدير') == true ||
                 e.jobTitle?.contains('CEO') == true ||
                 e.jobTitle?.contains('Chairman') == true;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل قائمة المدراء: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _escalate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار الموظف المراد التصعيد إليه'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ComplaintsService.escalateComplaint(
        complaintId: widget.complaintId,
        escalatedTo: _selectedEmployeeId!,
        reason: _reasonController.text,
      );

      if (mounted) {
        Navigator.pop(context, true); // رجع بنجاح
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصعيد الشكوى بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصعيد الشكوى: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissionService = PermissionService();
    
    // التحقق من الصلاحية
    if (!permissionService.canEscalateComplaint) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تصعيد شكوى'),
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text('لا تملك صلاحية التصعيد'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تصعيد شكوى'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const AppLoading()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // اختيار الموظف المراد التصعيد إليه
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(title: 'التصعيد إلى'),
                        const SizedBox(height: AppSpacing.md),
                          DropdownButtonFormField<int>(
                            value: _selectedEmployeeId,
                            hint: const Text('اختر الموظف'),
                            items: _managers.map((emp) {
                              return DropdownMenuItem(
                                value: emp.employeeId,
                                child: Text(emp.fullName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedEmployeeId = value);
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null) {
                                return 'يجب اختيار الموظف';
                              }
                              return null;
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // سبب التصعيد
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeader(title: 'سبب التصعيد'),
                        const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _reasonController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'اكتب سبب التصعيد بالتفصيل...',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'سبب التصعيد مطلوب';
                              }
                              return null;
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // تنبيه مهم
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: AppStatus.overdue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'بعد التصعيد، ستكون الشكوى في حالة "مصعدة" ولن يتمكن الموظف الحالي من تعديلها.',
                            style: TextStyle(color: AppStatus.overdue),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // زر التصعيد
                  LoadingButton(
                    onPressed: _escalate,
                    isLoading: _isSaving,
                    text: 'تصعيد الشكوى',
                    color: AppStatus.editPending,
                  ),
                ],
              ),
            ),
    );
  }
}