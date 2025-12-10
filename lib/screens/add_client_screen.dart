import 'package:flutter/material.dart';
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

  // Controllers - تم إزالة الغير مطلوبين
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _floorNumberController = TextEditingController();
  final _notesController = TextEditingController();

  // القوائم المنسدلة
  List<dynamic> referralSources = [];
  List<dynamic> clientsList = [];

  int? selectedReferralSourceId;
  int? selectedReferralClientId;

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
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final sourcesRes = await http.get(Uri.parse('$baseUrl/api/referral-sources'));
      if (sourcesRes.statusCode == 200) {
        referralSources = jsonDecode(sourcesRes.body);
      }

      final clientsRes = await http.get(Uri.parse('$baseUrl/api/customers-list'));
      if (clientsRes.statusCode == 200) {
        clientsList = jsonDecode(clientsRes.body);
      }

      if (isEditing) {
        _fillExistingData();
      }

      setState(() => _isLoadingData = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoadingData = false);
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
    _nationalIdController.text = client['NationalID'] ?? '';
    _floorNumberController.text = client['FloorNumber'] ?? '';
    _notesController.text = client['Notes'] ?? '';
    selectedReferralSourceId = client['ReferralSourceID'];
    selectedReferralClientId = client['ReferralSourceClient'];
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

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
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 80)
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              isEditing ? 'تم تعديل العميل بنجاح!' : 'تم إضافة العميل بنجاح!',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppBar(),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== البيانات الأساسية =====
                    _buildSectionTitle('البيانات الأساسية', Icons.person),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameController,
                      label: 'اسم العميل *',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'اسم العميل مطلوب';
                        }
                        return null;
                      },
                    ),
                    _buildTextField(
                      controller: _contactPersonController,
                      label: 'جهة الاتصال',
                      icon: Icons.contact_phone,
                    ),
                    _buildTextField(
                      controller: _nationalIdController,
                      label: 'الرقم القومي',
                      icon: Icons.badge,
                      keyboardType: TextInputType.number,
                      maxLength: 14,
                    ),

                    const SizedBox(height: 24),

                    // ===== بيانات الاتصال =====
                    _buildSectionTitle('بيانات الاتصال', Icons.phone),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _phoneController,
                            label: 'الهاتف',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _phone2Controller,
                            label: 'هاتف 2',
                            icon: Icons.phone_android,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      controller: _emailController,
                      label: 'البريد الإلكتروني',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _buildTextField(
                      controller: _addressController,
                      label: 'العنوان',
                      icon: Icons.location_on,
                      maxLines: 2,
                    ),
                    _buildTextField(
                      controller: _floorNumberController,
                      label: 'رقم الدور',
                      icon: Icons.apartment,
                    ),

                    const SizedBox(height: 24),

                    // ===== مصدر الإحالة =====
                    _buildSectionTitle('مصدر الإحالة', Icons.share),
                    const SizedBox(height: 12),
                    _buildReferralSourceDropdown(),
                    const SizedBox(height: 12),
                    _buildReferralClientDropdown(),

                    const SizedBox(height: 24),

                    // ===== ملاحظات =====
                    _buildSectionTitle('ملاحظات', Icons.notes),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _notesController,
                      label: 'ملاحظات',
                      icon: Icons.notes,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    _buildSaveButton(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        isEditing ? 'تعديل عميل' : 'إضافة عميل',
        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black),
      ),
      backgroundColor: const Color(0xFF4CAF50),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.black),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFD700), size: 22),
        const SizedBox(width: 8),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        style: GoogleFonts.cairo(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(color: Colors.white60),
          prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          counterStyle: GoogleFonts.cairo(color: Colors.grey),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildReferralSourceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedReferralSourceId,
          isExpanded: true,
          hint: Text(
            'اختر مصدر الإحالة',
            style: GoogleFonts.cairo(color: Colors.white60),
          ),
          dropdownColor: const Color(0xFF1A1A1A),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFD700)),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('بدون', style: GoogleFonts.cairo(color: Colors.white)),
            ),
            ...referralSources.map((source) => DropdownMenuItem<int?>(
                  value: source['ReferralSourceID'],
                  child: Text(
                    source['SourceName'],
                    style: GoogleFonts.cairo(color: Colors.white),
                  ),
                )),
          ],
          onChanged: (value) {
            setState(() => selectedReferralSourceId = value);
          },
        ),
      ),
    );
  }

  Widget _buildReferralClientDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedReferralClientId,
          isExpanded: true,
          hint: Text(
            'إحالة من عميل',
            style: GoogleFonts.cairo(color: Colors.white60),
          ),
          dropdownColor: const Color(0xFF1A1A1A),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFD700)),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('بدون', style: GoogleFonts.cairo(color: Colors.white)),
            ),
            ...clientsList.map((client) => DropdownMenuItem<int?>(
                  value: client['PartyID'],
                  child: Text(
                    client['PartyName'],
                    style: GoogleFonts.cairo(color: Colors.white),
                  ),
                )),
          ],
          onChanged: (value) {
            setState(() => selectedReferralClientId = value);
          },
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveClient,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEditing ? Icons.save : Icons.person_add,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'حفظ التعديلات' : 'إضافة العميل',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }
}