import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../services/design_tokens.dart';
import '../widgets/design_kit.dart';
import '../core/auth/session_service.dart';

class AddClientScreen extends StatefulWidget {
  final String username;
  final Map<String, dynamic>? existingClient;

  const AddClientScreen({
    Key? key,
    required this.username,
    this.existingClient,
  }) : super(key: key);

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _isCheckingPhone = false;

  // Controllers
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _floorNumberController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _notesController = TextEditingController();
  final _clientSearchController = TextEditingController();
  final _parentSearchController = TextEditingController();

  //   القوائم المنسدلة — من جداول بلازور نفسها عبر وحدة العملاء
  List<dynamic> referralSources = [];
  List<dynamic> partyTypes = [];
  List<dynamic> salesStages = [];
  List<dynamic> contactSources = [];
  List<dynamic> clientsList = [];
  List<dynamic> filteredClientsList = [];
  List<dynamic> parentResults = [];

  int? selectedReferralSourceId;
  int? selectedReferralClientId;
  String? selectedReferralClientName;
  int selectedPartyType = 1;
  int? selectedStageId;
  int? selectedContactSourceId;
  int? selectedParentPartyId;
  String? selectedParentPartyName;
  // نوع الرصيد الافتتاحي كما في بلازور: D = مدين / C = دائن
  String _balanceType = 'D';

  // جهات الاتصال (PartyContacts) — مرآة قسم بلازور الرابع
  final List<_PartyContactRow> _contacts = [];

  // رسائل التحقق من الهاتف
  String? phoneError;
  String? phone2Error;

  bool get isEditing => widget.existingClient != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _jobTitleController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _nationalIdController.dispose();
    _floorNumberController.dispose();
    _taxNumberController.dispose();
    _openingBalanceController.dispose();
    _notesController.dispose();
    _clientSearchController.dispose();
    _parentSearchController.dispose();
    for (final c in _contacts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // جلب مصادر الإحالة
      final sourcesRes = await http.get(
        Uri.parse('$baseUrl/api/clients/referral-sources'),
       headers: SessionService.instance.authHeaders,);
      if (sourcesRes.statusCode == 200) {
        referralSources = jsonDecode(sourcesRes.body);
        print('✅ Loaded ${referralSources.length} referral sources');
      }

      // جلب قائمة العملاء
      final clientsRes = await http.get(
        Uri.parse('$baseUrl/api/clients/list'),
       headers: SessionService.instance.authHeaders,);
      if (clientsRes.statusCode == 200) {
        clientsList = jsonDecode(clientsRes.body);
        filteredClientsList = clientsList;
      }

      // القوائم المرجعية لنموذج بلازور (أنواع الطرف/المراحل/مصادر التواصل)
      final typesRes = await http.get(
        Uri.parse('$baseUrl/api/clients/party-types'),
       headers: SessionService.instance.authHeaders,);
      if (typesRes.statusCode == 200) {
        partyTypes = jsonDecode(typesRes.body);
      }
      final stagesRes = await http.get(
        Uri.parse('$baseUrl/api/clients/sales-stages'),
       headers: SessionService.instance.authHeaders,);
      if (stagesRes.statusCode == 200) {
        salesStages = jsonDecode(stagesRes.body);
      }
      final contactSourcesRes = await http.get(
        Uri.parse('$baseUrl/api/clients/contact-sources'),
       headers: SessionService.instance.authHeaders,);
      if (contactSourcesRes.statusCode == 200) {
        contactSources = jsonDecode(contactSourcesRes.body);
      }

      // تعبئة البيانات لو في وضع التعديل — من قراءة التفاصيل الكاملة
      // (مع جهات الاتصال) لا من صف القائمة
      if (isEditing) {
        await _loadEditDetail();
      }

      setState(() => _isLoadingData = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoadingData = false);
      _showErrorSnackBar('فشل في تحميل البيانات');
    }
  }

  Future<void> _loadEditDetail() async {
    final partyId = widget.existingClient!['PartyID'];
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/clients/$partyId'),
        headers: SessionService.instance.authHeaders,
      );
      if (res.statusCode == 200) {
        final detail = jsonDecode(res.body);
        if (detail is Map<String, dynamic> && detail['PartyID'] != null) {
          _fillExistingData(detail);
          return;
        }
      }
    } catch (e) {
      print('Error loading client detail: $e');
    }
    // احتياطي: صف القائمة كما كان
    _fillExistingData(widget.existingClient!);
  }

  void _fillExistingData(Map<String, dynamic> client) {
    _nameController.text = client['PartyName'] ?? '';
    _contactPersonController.text = client['ContactPerson'] ?? '';
    _jobTitleController.text = client['JobTitle'] ?? '';
    _phoneController.text = client['Phone'] ?? '';
    _phone2Controller.text = client['Phone2'] ?? '';
    _emailController.text = client['Email'] ?? '';
    _addressController.text = client['Address'] ?? '';
    _cityController.text = client['City'] ?? '';
    _areaController.text = client['Area'] ?? '';
    _nationalIdController.text = client['NationalID']?.toString() ?? '';
    _floorNumberController.text = client['FloorNumber']?.toString() ?? '';
    _taxNumberController.text = client['TaxNumber'] ?? '';
    _notesController.text = client['Notes'] ?? '';
    final opening = client['OpeningBalance'];
    if (opening != null && num.tryParse(opening.toString()) != null && num.parse(opening.toString()) != 0) {
      _openingBalanceController.text = opening.toString();
    }
    _balanceType = client['BalanceType']?.toString() == 'C' ? 'C' : 'D';
    if (client['PartyType'] != null) {
      selectedPartyType = int.tryParse(client['PartyType'].toString()) ?? 1;
    }
    selectedStageId = client['StageId'] != null ? int.tryParse(client['StageId'].toString()) : null;
    selectedContactSourceId = client['ContactSourceId'] != null ? int.tryParse(client['ContactSourceId'].toString()) : null;
    selectedParentPartyId = client['ParentPartyId'] != null ? int.tryParse(client['ParentPartyId'].toString()) : null;
    selectedParentPartyName = client['ParentPartyName']?.toString();

    // جهات الاتصال من قراءة التفاصيل
    _contacts.clear();
    final contacts = client['Contacts'];
    if (contacts is List) {
      for (final c in contacts) {
        if (c is Map) {
          _contacts.add(_PartyContactRow.fromJson(Map<String, dynamic>.from(c)));
        }
      }
    }

    // ✅ إصلاح مصدر الإحالة
    if (client['ReferralSourceID'] != null) {
      selectedReferralSourceId = int.tryParse(client['ReferralSourceID'].toString());
      print('✅ ReferralSourceID loaded: $selectedReferralSourceId');
    }

    // ✅ إصلاح العميل المُحيل
    if (client['ReferralSourceClient'] != null) {
      selectedReferralClientId = int.tryParse(client['ReferralSourceClient'].toString());
      final referralClient = clientsList.firstWhere(
        (c) => c['PartyID'] == client['ReferralSourceClient'],
        orElse: () => <String, dynamic>{},
      );
      if (referralClient.isNotEmpty) {
        selectedReferralClientName = referralClient['PartyName'];
      }
    }
  }

  // التحقق من تكرار رقم الهاتف
  Future<void> _checkPhoneExists(String phone, {bool isPhone2 = false}) async {
    if (phone.isEmpty || phone.length < 11) {
      setState(() {
        if (isPhone2) {
          phone2Error = null;
        } else {
          phoneError = null;
        }
      });
      return;
    }

    setState(() => _isCheckingPhone = true);

    try {
      String url = '$baseUrl/api/clients/check-phone?';
      if (isPhone2) {
        url += 'phone2=$phone';
      } else {
        url += 'phone=$phone';
      }

      if (isEditing) {
        url += '&excludeId=${widget.existingClient!['PartyID']}';
      }

      final res = await http.get(Uri.parse(url), headers: SessionService.instance.authHeaders);
      final result = jsonDecode(res.body);

      setState(() {
        if (result['exists'] == true) {
          final clientName = result['client']['PartyName'];
          if (isPhone2) {
            phone2Error = 'الرقم مسجل للعميل: $clientName';
          } else {
            phoneError = 'الرقم مسجل للعميل: $clientName';
          }
        } else {
          if (isPhone2) {
            phone2Error = null;
          } else {
            phoneError = null;
          }
        }
      });
    } catch (e) {
      print('Error checking phone: $e');
    } finally {
      setState(() => _isCheckingPhone = false);
    }
  }

  // البحث في قائمة العملاء
  void _filterClients(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredClientsList = clientsList;
      } else {
        filteredClientsList = clientsList.where((client) {
          final name = client['PartyName']?.toString().toLowerCase() ?? '';
          final phone = client['Phone']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) ||
              phone.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    if (phoneError != null || phone2Error != null) {
      _showErrorSnackBar('يرجى تصحيح أرقام الهاتف المكررة');
      return;
    }

    setState(() => _isLoading = true);

    // حارس بلازور: جهة اتصال أساسية واحدة فقط
    if (_contacts.where((c) => c.isPrimary).length > 1) {
      _showErrorSnackBar('لا يمكن تحديد أكثر من جهة اتصال أساسية واحدة');
      return;
    }

    try {
      final body = {
        'partyName': _nameController.text.trim(),
        'partyType': selectedPartyType,
        'stageId': selectedStageId,
        'contactSourceId': selectedContactSourceId,
        'parentPartyId': selectedParentPartyId,
        'jobTitle': _jobTitleController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phone2': _phone2Controller.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'area': _areaController.text.trim(),
        'nationalId': _nationalIdController.text.trim(),
        'floorNumber': _floorNumberController.text.trim(),
        'taxNumber': _taxNumberController.text.trim(),
        'openingBalance': double.tryParse(_openingBalanceController.text.trim()) ?? 0,
        'balanceType': _balanceType,
        'notes': _notesController.text.trim(),
        'referralSourceId': selectedReferralSourceId,
        'referralSourceClient': selectedReferralClientId,
        'createdBy': widget.username,
        'contacts': _contacts
            .where((c) => c.nameController.text.trim().isNotEmpty)
            .map((c) => c.toJson())
            .toList(),
      };

      http.Response res;
      if (isEditing) {
        res = await http.put(
          Uri.parse('$baseUrl/api/clients/${widget.existingClient!['PartyID']}'),
          headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else {
        res = await http.post(
          Uri.parse('$baseUrl/api/clients'),
          headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      }

      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        _showSuccessDialog();
      } else {
        _showErrorSnackBar(result['message'] ?? 'فشل في الحفظ');
      }
    } catch (e) {
      print('Error saving client: $e');
      _showErrorSnackBar('فشل في الاتصال بالسيرفر');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.xxxl)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: AppColors.success, size: 60),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: AppSpacing.xl),
              Text(
                isEditing ? 'تم التعديل بنجاح!' : 'تم الإضافة بنجاح!',
                style: GoogleFonts.cairo(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isEditing ? 'تم تحديث بيانات العميل' : 'تم إضافة العميل الجديد',
                style: GoogleFonts.cairo(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      Navigator.pop(context);
      Navigator.pop(context, true);
    });
  }

    void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.cairo())),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.sm)),
        margin: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
  }

  void _showClientPicker() {
    _clientSearchController.clear();
    filteredClientsList = clientsList;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxxl)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: AppRadius.all(AppRadius.sm),
                      ),
                      child: const Icon(Icons.person_search, color: AppColors.gold),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'اختر العميل المُحيل',
                      style: GoogleFonts.cairo(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _clientSearchController,
                  style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الهاتف...',
                    hintStyle: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                    filled: true,
                    fillColor: AppColors.inputFill(Theme.of(context).brightness == Brightness.dark),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.all(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.all(AppRadius.lg),
                      borderSide: BorderSide(color: AppColors.gold, width: 1),
                    ),
                  ),
                  onChanged: (value) {
                    _filterClients(value);
                    setModalState(() {});
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Remove Selection Button
              if (selectedReferralClientId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedReferralClientId = null;
                        selectedReferralClientName = null;
                      });
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: AppRadius.all(AppRadius.sm),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.close, color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'إزالة الاختيار',
                            style: GoogleFonts.cairo(color: AppColors.error, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Clients List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredClientsList.length,
                  itemBuilder: (context, index) {
                    final client = filteredClientsList[index];
                    final isSelected = client['PartyID'] == selectedReferralClientId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.gold.withValues(alpha: 0.12)
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: AppRadius.all(AppRadius.lg),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.gold
                              : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.success.withValues(alpha: 0.1),
                          child: Text(
                            (client['PartyName'] ?? 'ع')[0],
                            style: GoogleFonts.cairo(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          client['PartyName'] ?? '',
                          style: GoogleFonts.cairo(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          client['Phone'] ?? '',
                          style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                        trailing: isSelected
                            ? Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check, color: AppColors.navy, size: 16),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            selectedReferralClientId = client['PartyID'];
                            selectedReferralClientName = client['PartyName'];
                          });
                          Navigator.pop(context);
                        },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoadingData
          ? const AppLoading()
          : CustomScrollView(
              slivers: [
                // App Bar
                _buildSliverAppBar(),

                // Content
                SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // بيانات المُدخل (في وضع التعديل)
                        if (isEditing) _buildCreatedByCard(),

                        // ١ — البيانات الأساسية (ترتيب بلازور Form.razor)
                        _buildSection(
                          icon: Icons.person_outline,
                          title: 'البيانات الأساسية',
                          iconColor: AppColors.success,
                          children: [
                            _buildModernTextField(
                              controller: _nameController,
                              label: 'اسم العميل',
                              hint: 'أدخل اسم العميل',
                              icon: Icons.person,
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'اسم العميل مطلوب';
                                }
                                return null;
                              },
                            ),
                            _buildLookupDropdown(
                              label: 'نوع الطرف',
                              isRequired: true,
                              value: selectedPartyType,
                              items: partyTypes
                                  .map((t) => DropdownMenuItem<int?>(
                                        value: t['PartyTypeID'] as int?,
                                        child: Text(t['PartyTypeName'] ?? '', style: GoogleFonts.cairo()),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => selectedPartyType = v ?? 1),
                            ),
                            _buildLookupDropdown(
                              label: 'مرحلة المبيعات',
                              value: selectedStageId,
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('بدون تحديد', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ),
                                ...salesStages.map((s) => DropdownMenuItem<int?>(
                                      value: s['StageID'] as int?,
                                      child: Text(s['StageNameAr'] ?? s['StageName'] ?? '', style: GoogleFonts.cairo()),
                                    )),
                              ],
                              onChanged: (v) => setState(() => selectedStageId = v),
                            ),
                            _buildLookupDropdown(
                              label: 'مصدر التواصل',
                              value: selectedContactSourceId,
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('بدون تحديد', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ),
                                ...contactSources.map((s) => DropdownMenuItem<int?>(
                                      value: s['SourceID'] as int?,
                                      child: Text(s['SourceNameAr'] ?? s['SourceName'] ?? '', style: GoogleFonts.cairo()),
                                    )),
                              ],
                              onChanged: (v) => setState(() => selectedContactSourceId = v),
                            ),
                            _buildReferralSourceDropdown(),
                            if (selectedReferralSourceId == 1) ...[
                              const SizedBox(height: 16),
                              _buildReferralClientSelector(),
                            ],
                            const SizedBox(height: 16),
                            _buildParentPartyPicker(),
                          ],
                        ),

                        // ٢ — التواصل والعنوان
                        _buildSection(
                          icon: Icons.phone_outlined,
                          title: 'التواصل والعنوان',
                          iconColor: AppColors.info,
                          children: [
                            _buildModernTextField(
                              controller: _contactPersonController,
                              label: 'جهة الاتصال',
                              hint: 'اسم الشخص المسؤول',
                              icon: Icons.contact_phone_outlined,
                            ),
                            _buildModernTextField(
                              controller: _jobTitleController,
                              label: 'الوظيفة',
                              hint: 'وظيفة جهة الاتصال',
                              icon: Icons.work_outline,
                            ),
                            _buildPhoneField(
                              controller: _phoneController,
                              label: 'رقم الهاتف',
                              hint: '01xxxxxxxxx',
                              error: phoneError,
                              onChanged: (value) {
                                if (value.length >= 11) {
                                  _checkPhoneExists(value);
                                } else {
                                  setState(() => phoneError = null);
                                }
                              },
                            ),
                            _buildPhoneField(
                              controller: _phone2Controller,
                              label: 'هاتف آخر (اختياري)',
                              hint: '01xxxxxxxxx',
                              error: phone2Error,
                              onChanged: (value) {
                                if (value.length >= 11) {
                                  _checkPhoneExists(value, isPhone2: true);
                                } else {
                                  setState(() => phone2Error = null);
                                }
                              },
                            ),
                            _buildModernTextField(
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              hint: 'example@email.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _buildModernTextField(
                              controller: _nationalIdController,
                              label: 'الرقم القومي',
                              hint: '00000000000000',
                              icon: Icons.badge_outlined,
                              keyboardType: TextInputType.number,
                              maxLength: 14,
                            ),
                            // المحافظة في نموذج بلازور هي City وتُعرض «المدينة» — لا عمود Governorate
                            _buildModernTextField(
                              controller: _cityController,
                              label: 'المدينة',
                              hint: 'المحافظة / المدينة',
                              icon: Icons.location_city_outlined,
                            ),
                            _buildModernTextField(
                              controller: _areaController,
                              label: 'المنطقة',
                              hint: 'المنطقة / الحي',
                              icon: Icons.place_outlined,
                            ),
                            _buildModernTextField(
                              controller: _addressController,
                              label: 'العنوان التفصيلي',
                              hint: 'الشارع والمبنى بالتفصيل',
                              icon: Icons.home_outlined,
                              maxLines: 2,
                            ),
                            _buildModernTextField(
                              controller: _floorNumberController,
                              label: 'رقم الدور',
                              hint: 'مثال: الدور 3 شقة 5',
                              icon: Icons.apartment_outlined,
                            ),
                          ],
                        ),

                        // ٣ — البيانات المالية
                        _buildSection(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'البيانات المالية',
                          iconColor: AppColors.warning,
                          children: [
                            _buildBalanceTypeToggle(),
                            const SizedBox(height: 16),
                            _buildModernTextField(
                              controller: _openingBalanceController,
                              label: 'الرصيد الافتتاحي',
                              hint: '0',
                              icon: Icons.payments_outlined,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                            _buildModernTextField(
                              controller: _taxNumberController,
                              label: 'الرقم الضريبي',
                              hint: 'الرقم الضريبي للعميل',
                              icon: Icons.receipt_long_outlined,
                            ),
                          ],
                        ),

                        // ٤ — جهات الاتصال
                        _buildSection(
                          icon: Icons.contacts_outlined,
                          title: 'جهات الاتصال',
                          iconColor: AppStatus.editPending,
                          children: [
                            _buildContactsRepeater(),
                          ],
                        ),

                        // ٥ — ملاحظات
                        _buildSection(
                          icon: Icons.notes_outlined,
                          title: 'ملاحظات',
                          iconColor: AppColors.neutral,
                          children: [
                            _buildModernTextField(
                              controller: _notesController,
                              label: 'ملاحظات إضافية',
                              hint: 'أي ملاحظات عن العميل...',
                              icon: Icons.edit_note,
                              maxLines: 3,
                            ),
                          ],
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: AppRadius.all(AppRadius.sm),
          ),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEditing ? Icons.edit : Icons.person_add,
                color: AppColors.gold,
                size: 16,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isEditing ? 'تعديل العميل' : 'عميل جديد',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppGradients.identityHeader,
            ),
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: Icon(
                isEditing ? Icons.edit : Icons.person_add,
                color: AppColors.gold,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }

    Widget _buildCreatedByCard() {
    final client = widget.existingClient!;
    final createdBy = client['CreatedBy'] ?? 'غير معروف';
    final createdAt = client['CreatedAt'] ?? '';

    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt);
        formattedDate = '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        formattedDate = createdAt;
      }
    }

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: AppCard(
        radius: AppRadius.lg,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: AppRadius.all(AppRadius.sm),
              ),
              child: Icon(Icons.info_outline, color: AppColors.gold, size: 24),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'أضافه: $createdBy',
                        style: GoogleFonts.cairo(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (formattedDate.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          formattedDate,
                          style: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

    Widget _buildSection({
    required IconData icon,
    required String title,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: AppCard(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(title: title, icon: icon, accent: iconColor),
            const SizedBox(height: AppSpacing.lg),
            Column(children: children),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

    Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: GoogleFonts.cairo(color: AppColors.error, fontSize: 14),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            style: GoogleFonts.cairo(color: theme.colorScheme.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 14),
              prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 22),
              filled: true,
              fillColor: AppColors.inputFill(isDark),
              counterStyle: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
                borderSide: BorderSide(color: AppColors.gold, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
                borderSide: BorderSide(color: AppColors.error, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
                borderSide: BorderSide(color: AppColors.error, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }

    Widget _buildPhoneField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? error,
    required Function(String) onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.cairo(color: theme.colorScheme.onSurface, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 14),
              prefixIcon: Icon(Icons.phone_outlined, color: theme.colorScheme.onSurfaceVariant, size: 22),
              suffixIcon: _isCheckingPhone
                  ? Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold,
                      ),
                    )
                  : error != null
                      ? Icon(Icons.error_outline, color: AppColors.error)
                      : controller.text.length >= 11
                          ? Icon(Icons.check_circle_outline, color: AppColors.success)
                          : null,
              filled: true,
              fillColor: AppColors.inputFill(isDark),
              border: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
                borderSide: BorderSide(
                  color: error != null ? AppColors.error : AppColors.gold,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
                borderSide: BorderSide(
                  color: error != null ? AppColors.error.withValues(alpha: 0.5) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            ),
            onChanged: onChanged,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, right: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error,
                      style: GoogleFonts.cairo(color: AppColors.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

    // قائمة منسدلة بنفس نمط الحقول (عنوان فوق الحقل)
    Widget _buildLookupDropdown({
    required String label,
    required int? value,
    required List<DropdownMenuItem<int?>> items,
    required ValueChanged<int?> onChanged,
    bool isRequired = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: GoogleFonts.cairo(color: AppColors.error, fontSize: 14),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.inputFill(isDark),
              borderRadius: AppRadius.all(AppRadius.md),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: value,
                isExpanded: true,
                hint: Text(
                  'اختر',
                  style: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                ),
                dropdownColor: theme.colorScheme.surface,
                icon: Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.onSurfaceVariant),
                style: GoogleFonts.cairo(color: theme.colorScheme.onSurface, fontSize: 15),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // الشركة الأم (ParentPartyId) — بحث بالاسم/الهاتف عبر /api/clients/search
  Widget _buildParentPartyPicker() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الشركة الأم (اختياري)',
          style: GoogleFonts.cairo(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (selectedParentPartyId != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: AppRadius.all(AppRadius.md),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_outlined, color: AppColors.gold, size: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    selectedParentPartyName ?? 'طرف #$selectedParentPartyId',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    selectedParentPartyId = null;
                    selectedParentPartyName = null;
                  }),
                ),
              ],
            ),
          )
        else
          TextField(
            controller: _parentSearchController,
            style: GoogleFonts.cairo(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الهاتف...',
              hintStyle: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: AppColors.inputFill(theme.brightness == Brightness.dark),
              border: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (q) async {
              if (q.trim().length < 2) {
                setState(() => parentResults = []);
                return;
              }
              try {
                final res = await http.get(
                  Uri.parse('$baseUrl/api/clients/search?q=${Uri.encodeQueryComponent(q.trim())}'),
                  headers: SessionService.instance.authHeaders,
                );
                if (res.statusCode == 200 && mounted) {
                  setState(() => parentResults = jsonDecode(res.body));
                }
              } catch (_) {}
            },
          ),
        ...parentResults.take(5).map((c) => ListTile(
              dense: true,
              leading: const Icon(Icons.business_outlined, size: 18),
              title: Text(c['PartyName'] ?? '', style: GoogleFonts.cairo(fontSize: 13)),
              subtitle: Text('${c['Phone'] ?? ''}', style: GoogleFonts.cairo(fontSize: 11)),
              onTap: () => setState(() {
                selectedParentPartyId = c['PartyID'];
                selectedParentPartyName = c['PartyName'];
                parentResults = [];
                _parentSearchController.clear();
              }),
            )),
      ],
    );
  }

  // مفتاح نوع الرصيد كما في بلازور: مدين (D) / دائن (C)
  Widget _buildBalanceTypeToggle() {
    final theme = Theme.of(context);
    Widget option(String value, String label, IconData icon) {
      final selected = _balanceType == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _balanceType = value),
          borderRadius: AppRadius.all(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? AppColors.gold.withValues(alpha: 0.15) : AppColors.inputFill(theme.brightness == Brightness.dark),
              borderRadius: AppRadius.all(AppRadius.md),
              border: Border.all(color: selected ? AppColors.gold : theme.colorScheme.outlineVariant.withValues(alpha: 0.5), width: selected ? 2 : 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? AppColors.gold : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: selected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع الرصيد الافتتاحي',
          style: GoogleFonts.cairo(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            option('D', 'مدين', Icons.arrow_upward_rounded),
            const SizedBox(width: AppSpacing.md),
            option('C', 'دائن', Icons.arrow_downward_rounded),
          ],
        ),
      ],
    );
  }

  // مكرّر جهات الاتصال: اسم/هاتف/بريد/وظيفة/أساسية + إضافة وحذف —
  // تحديد أساسيتين معًا يُرفض عند الحفظ (حارس في _saveClient)
  Widget _buildContactsRepeater() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._contacts.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: AppRadius.all(AppRadius.md),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('جهة اتصال ${index + 1}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                    if (row.isPrimary)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text('أساسية', style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      onPressed: () => setState(() {
                        row.dispose();
                        _contacts.removeAt(index);
                      }),
                    ),
                  ],
                ),
                _buildModernTextField(controller: row.nameController, label: 'الاسم', hint: 'اسم جهة الاتصال', icon: Icons.person_outline),
                _buildModernTextField(controller: row.phoneController, label: 'الهاتف', hint: '01xxxxxxxxx', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                _buildModernTextField(controller: row.emailController, label: 'البريد الإلكتروني', hint: 'example@email.com', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                _buildModernTextField(controller: row.jobTitleController, label: 'الوظيفة', hint: 'وظيفة جهة الاتصال', icon: Icons.work_outline),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('جهة اتصال أساسية', style: GoogleFonts.cairo(fontSize: 13)),
                  value: row.isPrimary,
                  activeColor: AppColors.gold,
                  onChanged: (v) => setState(() => row.isPrimary = v),
                ),
              ],
            ),
          );
        }),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _contacts.add(_PartyContactRow())),
            icon: const Icon(Icons.add, size: 18),
            label: Text('إضافة جهة اتصال', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.md)),
            ),
          ),
        ),
      ],
    );
  }

    Widget _buildReferralSourceDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مصدر الإحالة',
          style: GoogleFonts.cairo(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.inputFill(isDark),
            borderRadius: AppRadius.all(AppRadius.md),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedReferralSourceId,
              isExpanded: true,
              hint: Text(
                'اختر مصدر الإحالة',
                style: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
              ),
              dropdownColor: theme.colorScheme.surface,
              icon: Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.onSurfaceVariant),
              style: GoogleFonts.cairo(color: theme.colorScheme.onSurface, fontSize: 15),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('بدون تحديد', style: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant)),
                ),
                ...referralSources.map((source) => DropdownMenuItem<int?>(
                      value: source['ReferralSourceID'],
                      child: Text(source['SourceName'], style: GoogleFonts.cairo()),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  selectedReferralSourceId = value;
                  if (value != 1) {
                    selectedReferralClientId = null;
                    selectedReferralClientName = null;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

    Widget _buildReferralClientSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'العميل المُحيل',
          style: GoogleFonts.cairo(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: _showClientPicker,
          borderRadius: AppRadius.all(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.inputFill(isDark),
              borderRadius: AppRadius.all(AppRadius.md),
              border: Border.all(
                color: selectedReferralClientId != null
                    ? AppColors.gold.withValues(alpha: 0.6)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_search_outlined,
                  color: selectedReferralClientId != null
                      ? AppColors.gold
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    selectedReferralClientName ?? 'اضغط لاختيار العميل',
                    style: GoogleFonts.cairo(
                      color: selectedReferralClientName != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  selectedReferralClientId != null
                      ? Icons.check_circle
                      : Icons.arrow_forward_ios,
                  color: selectedReferralClientId != null
                      ? AppColors.gold
                      : theme.colorScheme.onSurfaceVariant,
                  size: selectedReferralClientId != null ? 22 : 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, MediaQuery.of(context).padding.bottom + AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: _isLoading
            ? SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2.5),
                  ),
                ),
              )
            : GoldButton(
                label: isEditing ? 'حفظ التعديلات' : 'إضافة العميل',
                icon: isEditing ? Icons.save_outlined : Icons.person_add_outlined,
                onPressed: _saveClient,
              ),
      ),
    );
  }
}

// صف جهة اتصال واحدة في مكرّر جهات الاتصال (PartyContacts في بلازور)
class _PartyContactRow {
  int? contactId;
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final jobTitleController = TextEditingController();
  bool isPrimary = false;

  _PartyContactRow();

  factory _PartyContactRow.fromJson(Map<String, dynamic> json) {
    final row = _PartyContactRow();
    row.contactId = json['ContactId'] != null ? int.tryParse(json['ContactId'].toString()) : null;
    row.nameController.text = json['ContactName']?.toString() ?? '';
    row.phoneController.text = json['Phone']?.toString() ?? '';
    row.emailController.text = json['Email']?.toString() ?? '';
    row.jobTitleController.text = json['JobTitle']?.toString() ?? '';
    row.isPrimary = json['IsPrimary'] == true || json['IsPrimary'] == 1;
    return row;
  }

  Map<String, dynamic> toJson() => {
        'contactId': contactId,
        'contactName': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'jobTitle': jobTitleController.text.trim(),
        'isPrimary': isPrimary,
        'isActive': true,
      };

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    jobTitleController.dispose();
  }
}
