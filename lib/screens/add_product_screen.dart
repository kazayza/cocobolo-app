import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';

class AddProductScreen extends StatefulWidget {
  final String username;
  final int? productId;
  final Map<String, dynamic>? existingProduct;

  const AddProductScreen({
    Key? key,
    required this.username,
    this.productId,
    this.existingProduct,
  }) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;

  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _manufacturingDescController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _periodController = TextEditingController(text: '0');

  // Dropdowns
  List<dynamic> productGroups = [];
  List<dynamic> customers = [];
  int? selectedGroupId;
  int? selectedCustomerId;
  String? selectedPricingType;

  // المكونات
  List<Map<String, dynamic>> components = [];
  final _componentNameController = TextEditingController();
  final _componentQtyController = TextEditingController(text: '1');

  // الصور
  List<Map<String, dynamic>> newImages = [];
  final ImagePicker _picker = ImagePicker();

  final List<String> pricingTypes = ['ثابت', 'قابل للتفاوض', 'بالمتر', 'بالقطعة'];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.productId != null;
    fetchDropdownData();

    if (_isEditing && widget.existingProduct != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final p = widget.existingProduct!;
    _nameController.text = p['ProductName'] ?? '';
    _descriptionController.text = p['ProductDescription'] ?? '';
    _manufacturingDescController.text = p['ManufacturingDescription'] ?? '';
    _purchasePriceController.text = (p['PurchasePrice'] ?? 0).toString();
    _salePriceController.text = (p['SuggestedSalePrice'] ?? 0).toString();
    _qtyController.text = (p['QTY'] ?? 1).toString();
    _periodController.text = (p['Period'] ?? 0).toString();
    selectedGroupId = p['ProductGroupID'];
    selectedCustomerId = p['Customer'];
    selectedPricingType = p['PricingType'];

    // المكونات
    if (p['components'] != null) {
      components = List<Map<String, dynamic>>.from(
        (p['components'] as List).map((c) => {
          'name': c['ComponentName'],
          'qty': c['Quantity'],
        }),
      );
    }
  }

  Future<void> fetchDropdownData() async {
    try {
      // جلب المجموعات
      final groupsRes = await http.get(Uri.parse('$baseUrl/api/product-groups'));
      if (groupsRes.statusCode == 200) {
        setState(() => productGroups = jsonDecode(groupsRes.body));
      }

      // جلب العملاء
      final customersRes = await http.get(Uri.parse('$baseUrl/api/customers-list'));
      if (customersRes.statusCode == 200) {
        setState(() => customers = jsonDecode(customersRes.body));
      }
    } catch (e) {
      print('Error fetching dropdown data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _manufacturingDescController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _qtyController.dispose();
    _periodController.dispose();
    _componentNameController.dispose();
    _componentQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'تعديل المنتج' : 'إضافة منتج جديد',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: const Color(0xFFE8B923),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // البيانات الأساسية
              _buildSectionTitle('البيانات الأساسية', Icons.info_outline),
              const SizedBox(height: 16),
              _buildBasicInfoSection(),

              const SizedBox(height: 30),

              // الأسعار
              _buildSectionTitle('الأسعار', Icons.attach_money),
              const SizedBox(height: 16),
              _buildPricesSection(),

              const SizedBox(height: 30),

              // الوصف
              _buildSectionTitle('الوصف', Icons.description_outlined),
              const SizedBox(height: 16),
              _buildDescriptionSection(),

              const SizedBox(height: 30),

              // المكونات
              _buildSectionTitle('المكونات', Icons.widgets_outlined),
              const SizedBox(height: 16),
              _buildComponentsSection(),

              const SizedBox(height: 30),

              // الصور
              _buildSectionTitle('الصور', Icons.photo_library_outlined),
              const SizedBox(height: 16),
              _buildImagesSection(),

              const SizedBox(height: 40),

              // زر الحفظ
              _buildSaveButton(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFD700), size: 24),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // اسم المنتج
          _buildTextField(
            controller: _nameController,
            label: 'اسم المنتج *',
            icon: Icons.inventory_2,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'اسم المنتج مطلوب';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // المجموعة
          _buildDropdown<int>(
            label: 'المجموعة *',
            icon: Icons.category,
            value: selectedGroupId,
            items: productGroups.map((g) {
              return DropdownMenuItem<int>(
                value: g['ProductGroupID'],
                child: Text(g['GroupName'], style: GoogleFonts.cairo(color: Colors.white)),
              );
            }).toList(),
            onChanged: (value) => setState(() => selectedGroupId = value),
            validator: (value) => value == null ? 'المجموعة مطلوبة' : null,
          ),

          const SizedBox(height: 16),

          // العميل (اختياري)
          _buildDropdown<int>(
            label: 'العميل (اختياري)',
            icon: Icons.person,
            value: selectedCustomerId,
            items: [
              DropdownMenuItem<int>(
                value: null,
                child: Text('منتج عام', style: GoogleFonts.cairo(color: Colors.grey)),
              ),
              ...customers.map((c) {
                return DropdownMenuItem<int>(
                  value: c['PartyID'],
                  child: Text(c['PartyName'], style: GoogleFonts.cairo(color: Colors.white)),
                );
              }),
            ],
            onChanged: (value) => setState(() => selectedCustomerId = value),
          ),

          const SizedBox(height: 16),

          // نوع التسعير
          _buildDropdown<String>(
            label: 'نوع التسعير',
            icon: Icons.price_change,
            value: selectedPricingType,
            items: pricingTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type, style: GoogleFonts.cairo(color: Colors.white)),
              );
            }).toList(),
            onChanged: (value) => setState(() => selectedPricingType = value),
          ),

          const SizedBox(height: 16),

          // الكمية ومدة التصنيع
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _qtyController,
                  label: 'الكمية',
                  icon: Icons.numbers,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _periodController,
                  label: 'مدة التصنيع (يوم)',
                  icon: Icons.timer,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _purchasePriceController,
              label: 'سعر التكلفة',
              icon: Icons.money_off,
              keyboardType: TextInputType.number,
              suffixText: 'ج.م',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildTextField(
              controller: _salePriceController,
              label: 'سعر البيع',
              icon: Icons.attach_money,
              keyboardType: TextInputType.number,
              suffixText: 'ج.م',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _descriptionController,
            label: 'وصف المنتج',
            icon: Icons.short_text,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _manufacturingDescController,
            label: 'وصف التصنيع',
            icon: Icons.precision_manufacturing,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // إضافة مكون جديد
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _componentNameController,
                  style: GoogleFonts.cairo(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'اسم المكون',
                    hintStyle: GoogleFonts.cairo(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _componentQtyController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.cairo(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'العدد',
                    hintStyle: GoogleFonts.cairo(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addComponent,
                icon: const Icon(Icons.add_circle, color: Color(0xFFFFD700), size: 32),
              ),
            ],
          ),

          if (components.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),

            // قائمة المكونات
            ...components.asMap().entries.map((entry) {
              final index = entry.key;
              final comp = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${comp['qty']}',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        comp['name'],
                        style: GoogleFonts.cairo(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeComponent(index),
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _addComponent() {
    if (_componentNameController.text.isEmpty) return;

    setState(() {
      components.add({
        'name': _componentNameController.text,
        'qty': int.tryParse(_componentQtyController.text) ?? 1,
      });
      _componentNameController.clear();
      _componentQtyController.text = '1';
    });
  }

  void _removeComponent(int index) {
    setState(() => components.removeAt(index));
  }

  Widget _buildImagesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // زر إضافة صورة
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate, color: Color(0xFFFFD700), size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'إضافة صورة',
                      style: GoogleFonts.cairo(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (newImages.isNotEmpty) ...[
            const SizedBox(height: 16),

            // عرض الصور المضافة
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: newImages.length,
                itemBuilder: (context, index) {
                  final image = newImages[index];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(image['path']),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          newImages.add({
            'path': image.path,
            'base64': base64Encode(bytes),
            'note': '',
          });
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _removeImage(int index) {
    setState(() => newImages.removeAt(index));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.cairo(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
        suffixText: suffixText,
        suffixStyle: GoogleFonts.cairo(color: Colors.grey),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      dropdownColor: const Color(0xFF1A1A1A),
      style: GoogleFonts.cairo(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8B923),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, color: Colors.black),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing ? 'حفظ التعديلات' : 'إضافة المنتج',
                    style: GoogleFonts.cairo(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final productData = {
        'productName': _nameController.text,
        'productDescription': _descriptionController.text,
        'manufacturingDescription': _manufacturingDescController.text,
        'productGroupId': selectedGroupId,
        'customerId': selectedCustomerId,
        'purchasePrice': double.tryParse(_purchasePriceController.text) ?? 0,
        'suggestedSalePrice': double.tryParse(_salePriceController.text) ?? 0,
        'pricingType': selectedPricingType,
        'qty': int.tryParse(_qtyController.text) ?? 1,
        'period': int.tryParse(_periodController.text) ?? 0,
        'createdBy': widget.username,
      };

      http.Response res;

      if (_isEditing) {
        // تعديل
        res = await http.put(
          Uri.parse('$baseUrl/api/products/${widget.productId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(productData),
        );
      } else {
        // إضافة
        res = await http.post(
          Uri.parse('$baseUrl/api/products'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(productData),
        );
      }

      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        final productId = _isEditing ? widget.productId : result['productId'];

        // حفظ المكونات
        if (components.isNotEmpty) {
          await http.post(
            Uri.parse('$baseUrl/api/products/$productId/components'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'components': components.map((c) => {
                'componentName': c['name'],
                'quantity': c['qty'],
              }).toList(),
              'createdBy': widget.username,
            }),
          );
        }

        // رفع الصور الجديدة
        for (final img in newImages) {
          await http.post(
            Uri.parse('$baseUrl/api/products/$productId/images'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'imageBase64': img['base64'],
              'imageNote': img['note'],
            }),
          );
        }

        _showSuccess(_isEditing ? 'تم تعديل المنتج بنجاح' : 'تم إضافة المنتج بنجاح');
        Navigator.pop(context, true);
      } else {
        _showError(result['message'] ?? 'حدث خطأ');
      }
    } catch (e) {
      print('Error saving product: $e');
      _showError('فشل في حفظ المنتج');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text(message, style: GoogleFonts.cairo()),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 10),
            Text(message, style: GoogleFonts.cairo()),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}