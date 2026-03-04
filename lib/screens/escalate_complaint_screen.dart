import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/complaint_service.dart';
import '../services/employee_service.dart';
import '../models/employee_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_button.dart';
import '../utils/permission_service.dart';

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
            backgroundColor: Colors.red,
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
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final complaintService = ComplaintService();
      await complaintService.escalateComplaint(
        widget.complaintId,
        _selectedEmployeeId!,
        _reasonController.text,
      );

      if (mounted) {
        Navigator.pop(context, true); // رجع بنجاح
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصعيد الشكوى بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصعيد الشكوى: $e'),
            backgroundColor: Colors.red,
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
    if (!(permissionService.isSalesManager || permissionService.isAccountManager)) {
      return Scaffold(
        appBar: AppBar(title: const Text('تصعيد شكوى')),
        body: const Center(
          child: Text('لا تملك صلاحية التصعيد'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تصعيد شكوى'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // اختيار الموظف المراد التصعيد إليه
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'التصعيد إلى',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                  ),

                  const SizedBox(height: 16),

                  // سبب التصعيد
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'سبب التصعيد',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                  ),

                  const SizedBox(height: 24),

                  // تنبيه مهم
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.amber[800]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'بعد التصعيد، ستكون الشكوى في حالة "مصعدة" ولن يتمكن الموظف الحالي من تعديلها.',
                            style: TextStyle(color: Colors.amber[800]),
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
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
    );
  }
}