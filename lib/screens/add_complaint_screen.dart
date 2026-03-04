import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/complaint_model.dart';
import '../services/complaints_service.dart';
import '../services/theme_service.dart';
import '../services/app_colors.dart';

class AddComplaintScreen extends StatefulWidget {
  final int userId;
  final String username;
  final ComplaintModel? complaint; // لو موجود يبقى تعديل

  const AddComplaintScreen({
    super.key,
    required this.userId,
    required this.username,
    this.complaint,
  });

  @override
  State<AddComplaintScreen> createState() => _AddComplaintScreenState();
}

class _AddComplaintScreenState extends State<AddComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingTypes = true;

  // Controllers
  final _subjectController = TextEditingController();
  final _detailsController = TextEditingController();
  final _clientSearchController = TextEditingController();

  // القيم المختارة
  int? _selectedPartyId;
  String? _selectedPartyName;
  int? _selectedTypeId;
  int _selectedPriority = 3; // متوسطة افتراضي
  int _selectedStatus = 1; // جديدة افتراضي
  DateTime _complaintDate = DateTime.now();

  // البيانات
  List<ComplaintTypeModel> _complaintTypes = [];

  // هل هو تعديل؟
  bool get _isEditing => widget.complaint != null;

  @override
  void initState() {
    super.initState();
    _loadComplaintTypes();

    // لو تعديل، نملأ البيانات
    if (_isEditing) {
      _fillEditData();
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _detailsController.dispose();
    _clientSearchController.dispose();
    super.dispose();
  }

  // ===================================
  // ملء بيانات التعديل
  // ===================================
  void _fillEditData() {
    final c = widget.complaint!;
    _selectedPartyId = c.partyId;
    _selectedPartyName = c.clientName;
    _selectedTypeId = c.typeId;
    _selectedPriority = c.priority;
    _selectedStatus = c.status;
    _subjectController.text = c.subject;
    _detailsController.text = c.details;
    if (c.complaintDate != null) {
      _complaintDate = c.complaintDate!;
    }
  }

  // ===================================
  // تحميل أنواع الشكاوى
  // ===================================
  Future<void> _loadComplaintTypes() async {
    try {
      final types = await ComplaintsService.getComplaintTypes();
      setState(() {
        _complaintTypes = types;
        _isLoadingTypes = false;
      });
    } catch (e) {
      setState(() => _isLoadingTypes = false);
      _showError('فشل في تحميل أنواع الشكاوى');
    }
  }

  // ===================================
  // حفظ الشكوى
  // ===================================
  Future<void> _saveComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPartyId == null) {
      _showError('يرجى اختيار العميل');
      return;
    }

    if (_selectedTypeId == null) {
      _showError('يرجى اختيار نوع الشكوى');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        // تعديل
        await ComplaintsService.updateComplaint(
          widget.complaint!.complaintId,
          {
            'typeId': _selectedTypeId,
            'subject': _subjectController.text.trim(),
            'details': _detailsController.text.trim(),
            'priority': _selectedPriority,
            'status': _selectedStatus,
            'complaintDate': _complaintDate.toIso8601String(),
          },
        );
        _showSuccess('تم تعديل الشكوى بنجاح');
      } else {
        // إضافة
        await ComplaintsService.createComplaint(
          partyId: _selectedPartyId!,
          typeId: _selectedTypeId!,
          subject: _subjectController.text.trim(),
          details: _detailsController.text.trim(),
          priority: _selectedPriority,
          status: _selectedStatus,
          complaintDate: _complaintDate,
          createdBy: widget.username,
        );
        _showSuccess('تم إضافة الشكوى بنجاح');
      }

      Navigator.pop(context, true);
    } catch (e) {
      _showError(_isEditing ? 'فشل في تعديل الشكوى' : 'فشل في إضافة الشكوى');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: _buildAppBar(isDark),
      body: _isLoadingTypes
          ? _buildLoading(isDark)
          : _buildBody(isDark),
    );
  }

  // ===================================
  // AppBar
  // ===================================
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.navy : Colors.white,
      elevation: 0,
      title: Text(
        _isEditing ? 'تعديل الشكوى' : 'شكوى جديدة',
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.navy,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.close,
          color: isDark ? Colors.white : AppColors.navy,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _saveComplaint,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                )
              : Text(
                  'حفظ',
                  style: GoogleFonts.cairo(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ],
    );
  }

  // ===================================
  // Loading
  // ===================================
  Widget _buildLoading(bool isDark) {
    return Center(
      child: CircularProgressIndicator(color: AppColors.gold),
    );
  }

  // ===================================
  // Body
  // ===================================
  Widget _buildBody(bool isDark) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اختيار العميل
            _buildClientSelector(isDark),
            const SizedBox(height: 20),

            // نوع الشكوى
            _buildTypeSelector(isDark),
            const SizedBox(height: 20),

            // عنوان الشكوى
            _buildSubjectField(isDark),
            const SizedBox(height: 20),

            // التفاصيل
            _buildDetailsField(isDark),
            const SizedBox(height: 20),

            // الأولوية والتاريخ
            Row(
              children: [
                Expanded(child: _buildPrioritySelector(isDark)),
                const SizedBox(width: 16),
                Expanded(child: _buildDateSelector(isDark)),
              ],
            ),
            const SizedBox(height: 20),

            // الحالة (فقط في التعديل)
            if (_isEditing) ...[
              _buildStatusSelector(isDark),
              const SizedBox(height: 20),
            ],

            // زر الحفظ
            _buildSaveButton(isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ===================================
  // اختيار العميل
  // ===================================
  Widget _buildClientSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('العميل *', isDark),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isEditing ? null : _showClientSearchSheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isEditing
                  ? AppColors.inputFill(isDark).withOpacity(0.5)
                  : AppColors.inputFill(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPartyId == null
                    ? Colors.transparent
                    : AppColors.gold.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: _selectedPartyId != null
                      ? AppColors.gold
                      : AppColors.textHint(isDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedPartyName ?? 'اختر العميل...',
                    style: GoogleFonts.cairo(
                      color: _selectedPartyId != null
                          ? AppColors.text(isDark)
                          : AppColors.textHint(isDark),
                      fontSize: 15,
                    ),
                  ),
                ),
                if (!_isEditing)
                  Icon(
                    Icons.search,
                    color: AppColors.textHint(isDark),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===================================
  // البحث عن عميل - Bottom Sheet
  // ===================================
  void _showClientSearchSheet() {
    final isDark = ThemeService().isDarkMode;
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // العنوان
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'بحث عن عميل',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(isDark),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // حقل البحث
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _clientSearchController,
                  autofocus: true,
                  style: GoogleFonts.cairo(color: AppColors.text(isDark)),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو رقم الهاتف...',
                    hintStyle: GoogleFonts.cairo(color: AppColors.textHint(isDark)),
                    prefixIcon: Icon(Icons.search, color: AppColors.textHint(isDark)),
                    suffixIcon: isSearching
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.gold,
                              ),
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.inputFill(isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) async {
                    if (value.length < 2) {
                      setSheetState(() => searchResults = []);
                      return;
                    }

                    setSheetState(() => isSearching = true);

                    // ✅ واستبدله بـ:
final results = await ComplaintsService.searchClients(value);
setSheetState(() {
  searchResults = results;
  isSearching = false;
});
                  },
                ),
              ),
              const SizedBox(height: 16),

              // نتائج البحث
              Expanded(
                child: searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 64,
                              color: AppColors.textHint(isDark),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'ابحث عن العميل',
                              style: GoogleFonts.cairo(
                                color: AppColors.textHint(isDark),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final client = searchResults[index];
                          return ListTile(
                            onTap: () {
                              setState(() {
                                _selectedPartyId = client['PartyID'];
                                _selectedPartyName = client['PartyName'];
                              });
                              _clientSearchController.clear();
                              Navigator.pop(context);
                            },
                            leading: CircleAvatar(
                              backgroundColor: AppColors.gold.withOpacity(0.2),
                              child: Icon(
                                Icons.person,
                                color: AppColors.gold,
                              ),
                            ),
                            title: Text(
                              client['PartyName'],
                              style: GoogleFonts.cairo(
                                color: AppColors.text(isDark),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              client['Phone'],
                              style: GoogleFonts.cairo(
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppColors.textHint(isDark),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================================
  // نوع الشكوى
  // ===================================
  Widget _buildTypeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('نوع الشكوى *', isDark),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.inputFill(isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedTypeId,
              isExpanded: true,
              hint: Text(
                'اختر نوع الشكوى',
                style: GoogleFonts.cairo(color: AppColors.textHint(isDark)),
              ),
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textHint(isDark)),
              dropdownColor: AppColors.card(isDark),
              style: GoogleFonts.cairo(
                color: AppColors.text(isDark),
                fontSize: 15,
              ),
              items: _complaintTypes.map((type) {
                return DropdownMenuItem<int>(
                  value: type.typeId,
                  child: Text(type.typeNameAr ?? type.typeName ?? ''),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedTypeId = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ===================================
  // عنوان الشكوى
  // ===================================
  Widget _buildSubjectField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('عنوان الشكوى *', isDark),
        const SizedBox(height: 8),
        TextFormField(
          controller: _subjectController,
          style: GoogleFonts.cairo(color: AppColors.text(isDark)),
          decoration: InputDecoration(
            hintText: 'أدخل عنوان الشكوى',
            hintStyle: GoogleFonts.cairo(color: AppColors.textHint(isDark)),
            filled: true,
            fillColor: AppColors.inputFill(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: Icon(
              Icons.title,
              color: AppColors.textHint(isDark),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'عنوان الشكوى مطلوب';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ===================================
  // التفاصيل
  // ===================================
  Widget _buildDetailsField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('تفاصيل الشكوى *', isDark),
        const SizedBox(height: 8),
        TextFormField(
          controller: _detailsController,
          maxLines: 5,
          style: GoogleFonts.cairo(color: AppColors.text(isDark)),
          decoration: InputDecoration(
            hintText: 'اكتب تفاصيل الشكوى هنا...',
            hintStyle: GoogleFonts.cairo(color: AppColors.textHint(isDark)),
            filled: true,
            fillColor: AppColors.inputFill(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'تفاصيل الشكوى مطلوبة';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ===================================
  // الأولوية
  // ===================================
  Widget _buildPrioritySelector(bool isDark) {
    final priorities = [
      {'id': 1, 'name': 'عالية جداً', 'color': Colors.red.shade700},
      {'id': 2, 'name': 'عالية', 'color': Colors.orange},
      {'id': 3, 'name': 'متوسطة', 'color': Colors.amber.shade700},
      {'id': 4, 'name': 'منخفضة', 'color': Colors.green},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('الأولوية', isDark),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.inputFill(isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedPriority,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textHint(isDark)),
              dropdownColor: AppColors.card(isDark),
              items: priorities.map((p) {
                return DropdownMenuItem<int>(
                  value: p['id'] as int,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: p['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        p['name'] as String,
                        style: GoogleFonts.cairo(
                          color: AppColors.text(isDark),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPriority = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // ===================================
  // التاريخ
  // ===================================
  Widget _buildDateSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('التاريخ', isDark),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _complaintDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: AppColors.gold,
                      surface: AppColors.card(isDark),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _complaintDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.inputFill(isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppColors.textHint(isDark),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_complaintDate.day}/${_complaintDate.month}/${_complaintDate.year}',
                  style: GoogleFonts.cairo(
                    color: AppColors.text(isDark),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===================================
  // الحالة (للتعديل فقط)
  // ===================================
  Widget _buildStatusSelector(bool isDark) {
    final statuses = [
      {'id': 1, 'name': 'جديدة', 'color': Colors.blue},
      {'id': 2, 'name': 'قيد الحل', 'color': Colors.orange},
      {'id': 3, 'name': 'انتظار', 'color': Colors.amber},
      {'id': 4, 'name': 'محلولة', 'color': Colors.green},
      {'id': 5, 'name': 'مرفوضة', 'color': Colors.red},
      {'id': 6, 'name': 'مصعدة', 'color': Colors.purple},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('الحالة', isDark),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.inputFill(isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedStatus,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textHint(isDark)),
              dropdownColor: AppColors.card(isDark),
              items: statuses.map((s) {
                return DropdownMenuItem<int>(
                  value: s['id'] as int,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: s['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        s['name'] as String,
                        style: GoogleFonts.cairo(
                          color: AppColors.text(isDark),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // ===================================
  // زر الحفظ
  // ===================================
  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveComplaint,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navy,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.navy,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isEditing ? Icons.save : Icons.add,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing ? 'حفظ التعديلات' : 'إضافة الشكوى',
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

  // ===================================
  // Label Helper
  // ===================================
  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.text(isDark),
      ),
    );
  }

  // ===================================
  // Messages
  // ===================================
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}