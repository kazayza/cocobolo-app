import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

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
  final _phoneController = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _floorNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _clientSearchController = TextEditingController();

  // القوائم المنسدلة
  List<dynamic> referralSources = [];
  List<dynamic> clientsList = [];
  List<dynamic> filteredClientsList = [];

  int? selectedReferralSourceId;
  int? selectedReferralClientId;
  String? selectedReferralClientName;

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
    _phoneController.dispose();
    _phone2Controller.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _nationalIdController.dispose();
    _floorNumberController.dispose();
    _notesController.dispose();
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // جلب مصادر الإحالة
      final sourcesRes = await http.get(
        Uri.parse('$baseUrl/api/clients/referral-sources'),
      );
      if (sourcesRes.statusCode == 200) {
        referralSources = jsonDecode(sourcesRes.body);
        print('✅ Loaded ${referralSources.length} referral sources');
      }

      // جلب قائمة العملاء
      final clientsRes = await http.get(
        Uri.parse('$baseUrl/api/clients/list'),
      );
      if (clientsRes.statusCode == 200) {
        clientsList = jsonDecode(clientsRes.body);
        filteredClientsList = clientsList;
      }

      // تعبئة البيانات لو في وضع التعديل
      if (isEditing) {
        _fillExistingData();
      }

      setState(() => _isLoadingData = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoadingData = false);
      _showErrorSnackBar('فشل في تحميل البيانات');
    }
  }

  void _fillExistingData() {
    final client = widget.existingClient!;
    _nameController.text = client['PartyName'] ?? '';
    _contactPersonController.text = client['ContactPerson'] ?? '';
    _phoneController.text = client['Phone'] ?? '';
    _phone2Controller.text = client['Phone2'] ?? '';
    _emailController.text = client['Email'] ?? '';
    _addressController.text = client['Address'] ?? '';
    _nationalIdController.text = client['NationalID']?.toString() ?? '';
    _floorNumberController.text = client['FloorNumber']?.toString() ?? '';
    _notesController.text = client['Notes'] ?? '';

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

      final res = await http.get(Uri.parse(url));
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

    try {
      final body = {
        'partyName': _nameController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phone2': _phone2Controller.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'nationalId': _nationalIdController.text.trim(),
        'floorNumber': _floorNumberController.text.trim(),
        'notes': _notesController.text.trim(),
        'referralSourceId': selectedReferralSourceId,
        'referralSourceClient': selectedReferralClientId,
        'createdBy': widget.username,
      };

      http.Response res;
      if (isEditing) {
        res = await http.put(
          Uri.parse('$baseUrl/api/clients/${widget.existingClient!['PartyID']}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else {
        res = await http.post(
          Uri.parse('$baseUrl/api/clients'),
          headers: {'Content-Type': 'application/json'},
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 60),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              isEditing ? 'تم التعديل بنجاح!' : 'تم الإضافة بنجاح!',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isEditing ? 'تم تحديث بيانات العميل' : 'تم إضافة العميل الجديد',
              style: GoogleFonts.cairo(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
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
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: GoogleFonts.cairo())),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
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
                        color: const Color(0xFFE8B923).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_search, color: Color(0xFFE8B923)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'اختر العميل المُحيل',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
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
                  style: GoogleFonts.cairo(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الهاتف...',
                    hintStyle: GoogleFonts.cairo(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFE8B923)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE8B923), width: 1),
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
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.close, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'إزالة الاختيار',
                            style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold),
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
                            ? const Color(0xFFE8B923).withOpacity(0.1)
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFE8B923)
                              : Colors.white.withOpacity(0.05),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
                          child: Text(
                            (client['PartyName'] ?? 'ع')[0],
                            style: GoogleFonts.cairo(
                              color: const Color(0xFF4CAF50),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          client['PartyName'] ?? '',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          client['Phone'] ?? '',
                          style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 13),
                        ),
                        trailing: isSelected
                            ? Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8B923),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.black, size: 16),
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
      backgroundColor: const Color(0xFF121212),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE8B923)),
            )
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

                        // البيانات الأساسية
                        _buildSection(
                          icon: Icons.person_outline,
                          title: 'البيانات الأساسية',
                          iconColor: const Color(0xFF4CAF50),
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
                            _buildModernTextField(
                              controller: _contactPersonController,
                              label: 'جهة الاتصال',
                              hint: 'اسم الشخص المسؤول',
                              icon: Icons.contact_phone_outlined,
                            ),
                            _buildModernTextField(
                              controller: _nationalIdController,
                              label: 'الرقم القومي',
                              hint: '00000000000000',
                              icon: Icons.badge_outlined,
                              keyboardType: TextInputType.number,
                              maxLength: 14,
                            ),
                          ],
                        ),

                        // بيانات الاتصال
                        _buildSection(
                          icon: Icons.phone_outlined,
                          title: 'بيانات الاتصال',
                          iconColor: const Color(0xFF2196F3),
                          children: [
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
                          ],
                        ),

                        // العنوان
                        _buildSection(
                          icon: Icons.location_on_outlined,
                          title: 'العنوان',
                          iconColor: const Color(0xFFFF9800),
                          children: [
                            _buildModernTextField(
                              controller: _addressController,
                              label: 'العنوان بالتفصيل',
                              hint: 'المدينة - الحي - الشارع',
                              icon: Icons.home_outlined,
                              maxLines: 2,
                            ),
                            _buildModernTextField(
                              controller: _floorNumberController,
                              label: 'رقم الدور / الشقة',
                              hint: 'مثال: الدور 3 شقة 5',
                              icon: Icons.apartment_outlined,
                            ),
                          ],
                        ),

                        // مصدر الإحالة
                        _buildSection(
                          icon: Icons.share_outlined,
                          title: 'مصدر الإحالة',
                          iconColor: const Color(0xFF9C27B0),
                          children: [
                            _buildReferralSourceDropdown(),
                            if (selectedReferralSourceId == 1) ...[
                              const SizedBox(height: 16),
                              _buildReferralClientSelector(),
                            ],
                          ],
                        ),

                        // ملاحظات
                        _buildSection(
                          icon: Icons.notes_outlined,
                          title: 'ملاحظات',
                          iconColor: const Color(0xFF607D8B),
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
      backgroundColor: const Color(0xFF1E1E1E),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          isEditing ? 'تعديل العميل' : 'عميل جديد',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4CAF50).withOpacity(0.3),
                const Color(0xFF1E1E1E),
              ],
            ),
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEditing ? Icons.edit : Icons.person_add,
                color: const Color(0xFF4CAF50),
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE8B923).withOpacity(0.15),
            const Color(0xFFE8B923).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8B923).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8B923).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline, color: Color(0xFFE8B923), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      'أضافه: $createdBy',
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (formattedDate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: GoogleFonts.cairo(color: Colors.red, fontSize: 14),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey[500], size: 22),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              counterStyle: GoogleFonts.cairo(color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
              prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey[500], size: 22),
              suffixIcon: _isCheckingPhone
                  ? Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.all(14),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE8B923),
                      ),
                    )
                  : error != null
                      ? const Icon(Icons.error_outline, color: Colors.red)
                      : controller.text.length >= 11
                          ? const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50))
                          : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: error != null ? Colors.red : const Color(0xFF4CAF50),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: error != null ? Colors.red.withOpacity(0.5) : Colors.transparent,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: onChanged,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error,
                      style: GoogleFonts.cairo(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReferralSourceDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مصدر الإحالة',
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedReferralSourceId,
              isExpanded: true,
              hint: Text(
                'اختر مصدر الإحالة',
                style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
              ),
              dropdownColor: const Color(0xFF2A2A2A),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[500]),
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 15),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('بدون تحديد', style: GoogleFonts.cairo(color: Colors.grey[400])),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'العميل المُحيل',
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showClientPicker,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selectedReferralClientId != null
                    ? const Color(0xFF4CAF50).withOpacity(0.5)
                    : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_search_outlined,
                  color: selectedReferralClientId != null
                      ? const Color(0xFF4CAF50)
                      : Colors.grey[500],
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedReferralClientName ?? 'اضغط لاختيار العميل',
                    style: GoogleFonts.cairo(
                      color: selectedReferralClientName != null
                          ? Colors.white
                          : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  selectedReferralClientId != null
                      ? Icons.check_circle
                      : Icons.arrow_forward_ios,
                  color: selectedReferralClientId != null
                      ? const Color(0xFF4CAF50)
                      : Colors.grey[600],
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
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveClient,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          disabledBackgroundColor: const Color(0xFF4CAF50).withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isEditing ? Icons.save_outlined : Icons.person_add_outlined, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'حفظ التعديلات' : 'إضافة العميل',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}