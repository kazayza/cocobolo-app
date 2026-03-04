import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../services/permission_service.dart';
import 'package:file_picker/file_picker.dart';

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
    // أسعار Elite
  final _purchasePriceEliteController = TextEditingController();
  final _salePriceEliteController = TextEditingController();

  // نسب الربح %
  final _premiumMarginController = TextEditingController(text: '60'); // 60%
  final _eliteMarginController = TextEditingController(text: '65');   // 65%

  // للتحكم في عدم تكرار الحساب داخل onChanged
  bool _updatingPremium = false;
  bool _updatingElite = false;
   double _serverPremiumMargin = 60.0;
  double _serverEliteMargin = 65.0;

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
   // PDF
  String? _pdfBase64;
  String? _pdfFileName;
  bool _hasPdf = false;

  final List<String> pricingTypes = ['Premium', 'Elite '];

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

    // أسعار Elite
    _purchasePriceEliteController.text =
        (p['PurchasePriceElite'] ?? 0).toString();
    _salePriceEliteController.text =
        (p['SuggestedSalePriceElite'] ?? 0).toString();

    // حساب نسبة الربح للبريميم
    final costPremium = _parseDouble(p['PurchasePrice']);
    final salePremium = _parseDouble(p['SuggestedSalePrice']);
    if (costPremium > 0 && salePremium > 0) {
      final margin = ((salePremium - costPremium) / costPremium) * 100;
      _premiumMarginController.text = margin.toStringAsFixed(1);
    } else {
      _premiumMarginController.text = '60'; // افتراضي
    }

    // حساب نسبة الربح للإليت
    final costElite = _parseDouble(p['PurchasePriceElite']);
    final saleElite = _parseDouble(p['SuggestedSalePriceElite']);
    if (costElite > 0 && saleElite > 0) {
      final margin = ((saleElite - costElite) / costElite) * 100;
      _eliteMarginController.text = margin.toStringAsFixed(1);
    } else {
      _eliteMarginController.text = '65'; // افتراضي
    }
     // PDF
    if (p['PDFFile'] != null) {
      _hasPdf = true;
    }
    // المكونات
    if (p['components'] != null) {
      components = List<Map<String, dynamic>>.from(
  (p['components'] as List).map((c) => <String, dynamic>{
        'name': c['ComponentName'],
        'qty': c['Quantity'],
      }),
);
    }
  }

  Future<void> fetchDropdownData() async {
    try {
      // جلب المجموعات
      final groupsRes = await http.get(Uri.parse('$baseUrl/api/products/groups'));
      if (groupsRes.statusCode == 200) {
        setState(() => productGroups = jsonDecode(groupsRes.body));
      }

      // جلب العملاء
      final customersRes = await http.get(Uri.parse('$baseUrl/api/customers-list'));
      if (customersRes.statusCode == 200) {
        setState(() => customers = jsonDecode(customersRes.body));
      }

            // جلب نسب الربح
      final marginsRes = await http.get(Uri.parse('$baseUrl/api/pricing/margins'));
      if (marginsRes.statusCode == 200) {
        final margins = jsonDecode(marginsRes.body);
        if (margins != null) {
          setState(() {
            _serverPremiumMargin = (margins['PremiumMargin'] ?? 60).toDouble();
            _serverEliteMargin = (margins['EliteMargin'] ?? 65).toDouble();
            // لو منتج جديد (مش تعديل) حط النسب الافتراضية
            if (!_isEditing) {
              _premiumMarginController.text = _serverPremiumMargin.toStringAsFixed(1);
              _eliteMarginController.text = _serverEliteMargin.toStringAsFixed(1);
            }
          });
        }
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
    _premiumMarginController.dispose();
    _eliteMarginController.dispose();
    _purchasePriceEliteController.dispose();
    _salePriceEliteController.dispose();
    super.dispose();
  }
    // =========================
  // 🔢 دوال مساعدة للحسابات
  // =========================

  // تحويل أي قيمة إلى double بأمان
  double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '')) ?? 0.0;
  }

  // بريميم: حساب سعر البيع من (التكلفة + النسبة)
  void _recalcPremiumFromCostOrMargin() {
    if (_updatingPremium) return;
    _updatingPremium = true;

    final cost = _parseDouble(_purchasePriceController.text);
    final margin = _parseDouble(_premiumMarginController.text);

    if (cost > 0) {
      final sale = cost * (1 + margin / 100);
      _salePriceController.text = sale.toStringAsFixed(2);
    }

    _updatingPremium = false;
  }

  // بريميم: حساب النسبة من (التكلفة + سعر البيع)
  void _recalcPremiumMarginFromSale() {
    if (_updatingPremium) return;
    _updatingPremium = true;

    final cost = _parseDouble(_purchasePriceController.text);
    final sale = _parseDouble(_salePriceController.text);

    if (cost > 0 && sale > 0) {
      final margin = ((sale - cost) / cost) * 100;
      _premiumMarginController.text = margin.toStringAsFixed(1);
    }

    _updatingPremium = false;
  }

  // إليت: حساب سعر البيع من (التكلفة + النسبة)
  void _recalcEliteFromCostOrMargin() {
    if (_updatingElite) return;
    _updatingElite = true;

    final cost = _parseDouble(_purchasePriceEliteController.text);
    final margin = _parseDouble(_eliteMarginController.text);

    if (cost > 0) {
      final sale = cost * (1 + margin / 100);
      _salePriceEliteController.text = sale.toStringAsFixed(2);
    }

    _updatingElite = false;
  }

  // إليت: حساب النسبة من (التكلفة + سعر البيع)
  void _recalcEliteMarginFromSale() {
    if (_updatingElite) return;
    _updatingElite = true;

    final cost = _parseDouble(_purchasePriceEliteController.text);
    final sale = _parseDouble(_salePriceEliteController.text);

    if (cost > 0 && sale > 0) {
      final margin = ((sale - cost) / cost) * 100;
      _eliteMarginController.text = margin.toStringAsFixed(1);
    }

    _updatingElite = false;
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
              
                 // PDF
              if (PermissionService().canSeePDF) ...[
                _buildSectionTitle('ملف PDF', Icons.picture_as_pdf),
                const SizedBox(height: 16),
                _buildPDFSection(),
                const SizedBox(height: 30),
              ],

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
    // نحسب قيمة آمنة للمجموعة (لو الـ ID مش موجود في القائمة نخليه null)
    final safeGroupValue = (selectedGroupId != null &&
            productGroups.any((g) => g['ProductGroupID'] == selectedGroupId))
        ? selectedGroupId
        : null;
        
    // قيمة آمنة للعميل
    final safeCustomerValue = (selectedCustomerId != null &&
        customers.any((c) => c['PartyID'] == selectedCustomerId))
    ? selectedCustomerId
    : null;
    
     // قيمة آمنة لنوع التسعير
    final safePricingType = (selectedPricingType != null &&
        pricingTypes.contains(selectedPricingType))
    ? selectedPricingType
    : null;    

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
            value: safeGroupValue,
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
          // العميل (اختياري) - مع بحث
          _buildCustomerDropdown(),

          const SizedBox(height: 16),

          // نوع التسعير
          _buildDropdown<String>(
            label: 'نوع التسعير',
            icon: Icons.price_change,
            value: safePricingType,
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

    Widget _buildCustomerDropdown() {
    String displayText = 'منتج عام';
    String displayPhone = '';

    if (selectedCustomerId != null) {
      final found = customers.where((c) => c['PartyID'] == selectedCustomerId);
      if (found.isNotEmpty) {
        displayText = found.first['PartyName'] ?? '';
        displayPhone = found.first['Phone'] ?? '';
      }
    }

    return InkWell(
      onTap: () => _showCustomerSearchDialog(),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'العميل (اختياري)',
          labelStyle: GoogleFonts.cairo(color: Colors.grey),
          prefixIcon: const Icon(Icons.person, color: Color(0xFFFFD700)),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedCustomerId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                  onPressed: () => setState(() => selectedCustomerId = null),
                ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                style: GoogleFonts.cairo(
                  color: selectedCustomerId != null ? Colors.white : Colors.grey,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (displayPhone.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                displayPhone,
                style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCustomerSearchDialog() {
    final searchController = TextEditingController();
    List<dynamic> filteredCustomers = List.from(customers);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'اختر العميل',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    style: GoogleFonts.cairo(color: Colors.white),
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم العميل أو رقم التليفون...',
                      hintStyle: GoogleFonts.cairo(color: Colors.grey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFFFD700)),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                              onPressed: () {
                                searchController.clear();
                                setDialogState(() {
                                  filteredCustomers = List.from(customers);
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFD700)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value.isEmpty) {
                          filteredCustomers = List.from(customers);
                        } else {
                          final search = value.toLowerCase();
                          filteredCustomers = customers.where((c) {
                            final name = (c['PartyName'] ?? '').toString().toLowerCase();
                            final phone = (c['Phone'] ?? '').toString().toLowerCase();
                            return name.contains(search) || phone.contains(search);
                          }).toList();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      setState(() => selectedCustomerId = null);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedCustomerId == null
                            ? const Color(0xFFFFD700).withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedCustomerId == null
                              ? const Color(0xFFFFD700).withOpacity(0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.public, color: Colors.grey, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'منتج عام',
                            style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14),
                          ),
                          const Spacer(),
                          if (selectedCustomerId == null)
                            const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 4),
                  Expanded(
                    child: filteredCustomers.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد نتائج',
                              style: GoogleFonts.cairo(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = filteredCustomers[index];
                              final isSelected = customer['PartyID'] == selectedCustomerId;
                              final name = customer['PartyName'] ?? '';
                              final phone = customer['Phone'] ?? '';

                              return InkWell(
                                onTap: () {
                                  setState(() => selectedCustomerId = customer['PartyID']);
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFFFD700).withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFFFD700).withOpacity(0.3)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFD700).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Color(0xFFFFD700),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.cairo(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (phone.isNotEmpty)
                                              Text(
                                                phone,
                                                style: GoogleFonts.cairo(
                                                  color: Colors.grey[400],
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPricesSection() {
    final perm = PermissionService();
    final showFull = perm.canSeeFullProductPricing;     // Admin + AccountManager
    final costOnly = perm.canSeeCostOnlyProductPricing;  // Factory
    final saleOnly = perm.canSeeSaleOnlyProductPricing;  // Sales + SalesManager
    final isFactory = perm.isFactory;                     // للتحكم في سلوك الحفظ

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // عمود Premium
          Expanded(
            child: _buildPackagePriceEditor(
              title: 'Premium',
              costController: _purchasePriceController,
              saleController: _salePriceController,
              marginController: _premiumMarginController,
              color: const Color(0xFFFFD700),
              showFull: showFull,
              costOnly: costOnly,
              saleOnly: saleOnly,
              onCostChanged: _recalcPremiumFromCostOrMargin,
              onSaleChanged: _recalcPremiumMarginFromSale,
            ),
          ),
          const SizedBox(width: 16),
          // عمود Elite
          Expanded(
            child: _buildPackagePriceEditor(
              title: 'Elite',
              costController: _purchasePriceEliteController,
              saleController: _salePriceEliteController,
              marginController: _eliteMarginController,
              color: Colors.greenAccent,
              showFull: showFull,
              costOnly: costOnly,
              saleOnly: saleOnly,
              onCostChanged: _recalcEliteFromCostOrMargin,
              onSaleChanged: _recalcEliteMarginFromSale,
            ),
          ),
        ],
      ),
    );
  }
  
    Widget _buildPackagePriceEditor({
    required String title,
    required TextEditingController costController,
    required TextEditingController saleController,
    required TextEditingController marginController,
    required Color color,
    required bool showFull,
    required bool costOnly,
    required bool saleOnly,
    void Function()? onCostChanged,
    void Function()? onSaleChanged,
  }) {
    final List<Widget> children = [];

    // عنوان الباقة (Premium / Elite)
    children.add(
      Text(
        title,
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    children.add(const SizedBox(height: 8));

    // ======================
    // 1) التكلفة (Cost)
    // ======================
    // تظهر وتكون قابلة للتعديل لـ:
    // - الثلاثة الكبار (showFull)
    // - المصنع (costOnly)
    if (showFull || costOnly) {
      children.add(
        TextFormField(
          controller: costController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.cairo(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'سعر التكلفة',
            labelStyle: GoogleFonts.cairo(color: Colors.grey),
            prefixIcon: const Icon(Icons.money_off, color: Color(0xFFFFD700)),
            suffixText: 'ج.م',
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
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
          onChanged: (_) {
            // لو من الـ 3 الكبار: نعيد حساب سعر البيع من التكلفة + النسبة
            if (showFull && onCostChanged != null) {
              onCostChanged();
            }
            // لو Factory: يغيّر التكلفة فقط، مش محتاج يظهر/يغيّر بيع أو نسبة
          },
        ),
      );

      children.add(const SizedBox(height: 8));
    }

    // ======================
    // 2) نسبة الربح (Margin)
    // ======================
    // تظهر وتُعدّل فقط للثلاثة الكبار (showFull)
    if (showFull) {
      children.add(
        TextFormField(
          controller: marginController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.cairo(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'نسبة الربح %',
            labelStyle: GoogleFonts.cairo(color: Colors.grey),
            prefixIcon: const Icon(Icons.percent, color: Color(0xFFFFD700)),
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
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
          onChanged: (_) {
            if (onCostChanged != null) {
              onCostChanged();
            }
          },
        ),
      );

      children.add(const SizedBox(height: 8));
    }

    // ======================
    // 3) سعر البيع (Sale)
    // ======================
    // حالتين:
    // - showFull  → Editable (الثلاثة الكبار فقط)
    // - saleOnly  → ReadOnly (باقي اليوزرات، عرض فقط)
    if (showFull) {
      // Editable Sale Price
      children.add(
        TextFormField(
          controller: saleController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.cairo(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'سعر البيع',
            labelStyle: GoogleFonts.cairo(color: Colors.grey),
            prefixIcon: Icon(Icons.attach_money, color: color),
            suffixText: 'ج.م',
            suffixStyle: GoogleFonts.cairo(color: Colors.grey),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
          onChanged: (_) {
            if (onSaleChanged != null) {
              onSaleChanged();
            }
          },
        ),
      );
    } else if (saleOnly) {
      // ReadOnly Sale Price (عرض فقط)
      children.add(
        TextFormField(
          controller: saleController,
          readOnly: true,
          enableInteractiveSelection: false,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.cairo(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'سعر البيع (عرض فقط)',
            labelStyle: GoogleFonts.cairo(color: Colors.grey),
            prefixIcon: Icon(Icons.visibility, color: color),
            suffixText: 'ج.م',
            suffixStyle: GoogleFonts.cairo(color: Colors.grey),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color.withOpacity(0.5)),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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

  Widget _buildPDFSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // لو فيه PDF قديم
          if (_hasPdf && _pdfBase64 == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'يوجد ملف PDF مرفق',
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ),
            ),

          // لو تم اختيار PDF جديد
          if (_pdfFileName != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _pdfFileName!,
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () {
                      setState(() {
                        _pdfBase64 = null;
                        _pdfFileName = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // زر اختيار PDF
          if (PermissionService().canAddPDF)
            InkWell(
              onTap: _pickPDF,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.upload_file, color: Colors.red, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        _pdfBase64 != null ? 'تغيير ملف PDF' : 'إرفاق ملف PDF',
                        style: GoogleFonts.cairo(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

  Future<void> _pickPDF() async {
    try {
      // محتاج package: file_picker
      // pubspec.yaml → file_picker: ^6.0.0
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _pdfBase64 = base64Encode(result.files.single.bytes!);
          _pdfFileName = result.files.single.name;
        });
      } else if (result != null && result.files.single.path != null) {
        final bytes = await File(result.files.single.path!).readAsBytes();
        setState(() {
          _pdfBase64 = base64Encode(bytes);
          _pdfFileName = result.files.single.name;
        });
      }
    } catch (e) {
      print('Error picking PDF: $e');
      _showError('فشل اختيار الملف');
    }
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
      final perm = PermissionService();
      final clientTime = DateTime.now().toIso8601String();

      // ============================================
      // الحالة 1: Factory - تسعير فقط (تكلفة)
      // ============================================
      if (perm.isFactory && _isEditing) {
        final res = await http.put(
          Uri.parse('$baseUrl/api/pricing/products/${widget.productId}/cost'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'purchasePrice': double.tryParse(_purchasePriceController.text) ?? 0,
            'purchasePriceElite': double.tryParse(_purchasePriceEliteController.text) ?? 0,
            'changedBy': widget.username,
            'clientTime': clientTime,
          }),
        );

        final result = jsonDecode(res.body);
        if (result['success'] == true) {
          _showSuccess('تم التسعير بنجاح');
          Navigator.pop(context, true);
        } else {
          _showError(result['message'] ?? 'فشل التسعير');
        }
        setState(() => _isLoading = false);
        return;
      }

      // ============================================
      // الحالة 2: Admin/AccountManager - تعديل سعر بيع
      // ============================================
      // (لو عدّل سعر البيع بس، نستخدم API تعديل السعر)
      // (لكن لو بيعدل بيانات المنتج كلها، نستخدم API التعديل العادي)

      // ============================================
      // الحالة 3: العادية - إضافة أو تعديل منتج
      // ============================================
      final productData = {
        'productName': _nameController.text,
        'productDescription': _descriptionController.text,
        'manufacturingDescription': _manufacturingDescController.text,
        'productGroupId': selectedGroupId,
        'customerId': selectedCustomerId,
        'purchasePrice': double.tryParse(_purchasePriceController.text) ?? 0,
        'suggestedSalePrice': double.tryParse(_salePriceController.text) ?? 0,
        'purchasePriceElite': double.tryParse(_purchasePriceEliteController.text) ?? 0,
        'suggestedSalePriceElite': double.tryParse(_salePriceEliteController.text) ?? 0,
        'pricingType': selectedPricingType,
        'qty': int.tryParse(_qtyController.text) ?? 1,
        'period': int.tryParse(_periodController.text) ?? 0,
        'createdBy': widget.username,
        'clientTime': clientTime,
      };

      http.Response res;

      if (_isEditing) {
        res = await http.put(
          Uri.parse('$baseUrl/api/products/${widget.productId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(productData),
        );
      } else {
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
              'components': components.map((c) => <String, dynamic>{
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

        // رفع PDF لو موجود
        if (_pdfBase64 != null) {
          await http.post(
            Uri.parse('$baseUrl/api/products/$productId/pdf'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pdfBase64': _pdfBase64,
              'createdBy': widget.username,
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