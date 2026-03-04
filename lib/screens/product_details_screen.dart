import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import 'add_product_screen.dart';
import '../services/permission_service.dart';
import '../screens/price_history_screen.dart';
import '../screens/price_requests_screen.dart';
import '../screens/pdf_viewer_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int productId;
  final String username;

  const ProductDetailsScreen({
    Key? key,
    required this.productId,
    required this.username,
  }) : super(key: key);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? product;
  List<dynamic> images = [];
  List<dynamic> components = [];
  bool loading = true;
  int currentImageIndex = 0;
  final PageController _pageController = PageController();
  bool _hasPdf = false;

  @override
  void initState() {
    super.initState();
    fetchProductDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> fetchProductDetails() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/products/${widget.productId}'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          product = data;
          images = data['images'] ?? [];
          components = data['components'] ?? [];
          _hasPdf = data['PDFFile'] != null;
          loading = false;
        });
      }
    } catch (e) {
      print('Error fetching product: $e');
      setState(() => loading = false);
      _showError('فشل في تحميل بيانات المنتج');
    }
  }

  void _showError(String message) {
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
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            )
          : product == null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'فشل في تحميل المنتج',
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: fetchProductDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8B923),
            ),
            child: Text('إعادة المحاولة', style: GoogleFonts.cairo(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // AppBar مع الصور
        _buildSliverAppBar(),

        // تفاصيل المنتج
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اسم المنتج والسعر
                _buildHeader(),

                const SizedBox(height: 24),

                  // أزرار إجراءات الأسعار
                _buildPriceActionsSection(),
                const SizedBox(height: 24),

                // معلومات أساسية
                _buildInfoSection(),

                const SizedBox(height: 24),

                // الوصف
                if (product!['ProductDescription'] != null &&
                    product!['ProductDescription'].toString().isNotEmpty)
                  _buildDescriptionSection(),

                const SizedBox(height: 24),

                // وصف التصنيع
                if (product!['ManufacturingDescription'] != null &&
                    product!['ManufacturingDescription'].toString().isNotEmpty)
                  _buildManufacturingSection(),

                const SizedBox(height: 24),

                // المكونات
                if (components.isNotEmpty) _buildComponentsSection(),

                const SizedBox(height: 24),
                     // PDF
                if (_hasPdf) _buildPDFSection(),

                if (_hasPdf) const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar() {
    final perm = PermissionService();

    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        // زر تاريخ الأسعار (للكل ماعدا Account)
        if (perm.canSeeFullProductPricing)
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFFFFD700)),
            tooltip: 'تاريخ الأسعار',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PriceHistoryScreen(
                    productId: widget.productId,
                    productName: product?['ProductName'] ?? '',
                  ),
                ),
              );
            },
          ),

        // زر التعديل (حسب الصلاحية)
        if (perm.canEdit(FormNames.productsAdd) || perm.isFactory)
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFFFFD700)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddProductScreen(
                    username: widget.username,
                    productId: widget.productId,
                    existingProduct: product,
                  ),
                ),
              ).then((_) => fetchProductDetails());
            },
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildImageGallery(),
      ),
    );
  }

  Widget _buildImageGallery() {
    if (images.isEmpty) {
      return Container(
        color: const Color(0xFF1A1A1A),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 80,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد صور',
                style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // الصور
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (index) {
            setState(() => currentImageIndex = index);
          },
          itemBuilder: (context, index) {
            final image = images[index];
            return GestureDetector(
              onTap: () => _showFullImage(image),
              child: Container(
                color: const Color(0xFF1A1A1A),
                child: image['image'] != null
                    ? Image.memory(
                        base64Decode(image['image']),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
            );
          },
        ),

        // مؤشر الصور
        if (images.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentImageIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentImageIndex == index
                        ? const Color(0xFFFFD700)
                        : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

        // عداد الصور
        Positioned(
          top: 100,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${currentImageIndex + 1} / ${images.length}',
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Icon(
        Icons.image_outlined,
        size: 80,
        color: Colors.grey[700],
      ),
    );
  }

  void _showFullImage(Map<String, dynamic> image) {
    if (image['image'] == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // الصورة
            InteractiveViewer(
              child: Center(
                child: Image.memory(
                  base64Decode(image['image']),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // زر الإغلاق
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // ملاحظة الصورة
            if (image['note'] != null && image['note'].toString().isNotEmpty)
              Positioned(
                bottom: 50,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    image['note'],
                    style: GoogleFonts.cairo(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
    // حساب نسبة الربح = (البيع - التكلفة) / التكلفة * 100
  double _calcMargin(dynamic cost, dynamic sale) {
    double c = 0;
    double s = 0;

    if (cost != null) {
      if (cost is num) c = cost.toDouble();
      else c = double.tryParse(cost.toString()) ?? 0;
    }
    if (sale != null) {
      if (sale is num) s = sale.toDouble();
      else s = double.tryParse(sale.toString()) ?? 0;
    }

    if (c <= 0 || s <= 0) return 0;
    return ((s - c) / c) * 100;
  }
  
  Widget _buildHeader() {
    final costPremium = product!['PurchasePrice'] ?? 0;
    final salePremium = product!['SuggestedSalePrice'] ?? 0;
    final marginPremium = _calcMargin(costPremium, salePremium);

    final costElite = product!['PurchasePriceElite'] ?? 0;
    final saleElite = product!['SuggestedSalePriceElite'] ?? 0;
    final marginElite = _calcMargin(costElite, saleElite);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // اسم المنتج
        Text(
          product!['ProductName'] ?? 'بدون اسم',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),

        const SizedBox(height: 12),

        // المجموعة
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.category, color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 6),
              Text(
                product!['GroupName'] ?? '',
                style: GoogleFonts.cairo(
                  color: const Color(0xFFFFD700),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0),

        const SizedBox(height: 16),

        // أسعار Premium / Elite
        Row(
          children: [
            // كارت Premium
            Expanded(
              child: _buildPackagePriceCard(
                title: 'Premium',
                cost: costPremium,
                sale: salePremium,
                margin: marginPremium,
                color: const Color(0xFFFFD700),
              ),
            ),
            const SizedBox(width: 12),
            // كارت Elite (نظهره بس لو فيه بيانات)
            Expanded(
              child: (costElite == 0 && saleElite == 0)
                  ? _buildEmptyEliteCard()
                  : _buildPackagePriceCard(
                      title: 'Elite',
                      cost: costElite,
                      sale: saleElite,
                      margin: marginElite,
                      color: Colors.greenAccent,
                    ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }
  
  Widget _buildPriceActionsSection() {
    final perm = PermissionService();
    final List<Widget> buttons = [];

    // زر طلب تعديل سعر (Sales فقط)
    if (perm.canRequestPriceChange) {
      buttons.add(
        Expanded(
          child: _buildActionButton(
            icon: Icons.price_change,
            label: 'طلب تعديل سعر',
            color: Colors.orangeAccent,
            onTap: () => _showPriceChangeRequestDialog(),
          ),
        ),
      );
    }

    // زر تعديل سعر البيع مباشرة (Admin / AccountManager)
    if (perm.canEditSalePrice) {
      buttons.add(
        Expanded(
          child: _buildActionButton(
            icon: Icons.edit_note,
            label: 'تعديل سعر البيع',
            color: const Color(0xFFFFD700),
            onTap: () => _showEditSalePriceDialog(),
          ),
        ),
      );
    }

    // زر تاريخ الأسعار (للكل ماعدا Account)
    if (perm.canSeeFullProductPricing) {
      buttons.add(
        Expanded(
          child: _buildActionButton(
            icon: Icons.history,
            label: 'تاريخ الأسعار',
            color: Colors.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PriceHistoryScreen(
                    productId: widget.productId,
                    productName: product?['ProductName'] ?? '',
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    // إضافة SizedBox بين الأزرار
    final List<Widget> spacedButtons = [];
    for (int i = 0; i < buttons.length; i++) {
      spacedButtons.add(buttons[i]);
      if (i < buttons.length - 1) {
        spacedButtons.add(const SizedBox(width: 10));
      }
    }

    return Row(children: spacedButtons)
        .animate()
        .fadeIn(delay: 250.ms)
        .slideY(begin: 0.1, end: 0);
  }

  void _showPriceChangeRequestDialog() {
    final priceTypeController = ValueNotifier<String>('Premium');
    final requestedPriceController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.price_change, color: Colors.orangeAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              'طلب تعديل سعر',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // اختيار نوع الباقة
              ValueListenableBuilder<String>(
                valueListenable: priceTypeController,
                builder: (context, priceType, _) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildTypeChip(
                          'Premium',
                          priceType == 'Premium',
                          const Color(0xFFFFD700),
                          () => priceTypeController.value = 'Premium',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTypeChip(
                          'Elite',
                          priceType == 'Elite',
                          Colors.greenAccent,
                          () => priceTypeController.value = 'Elite',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // السعر الحالي (عرض فقط)
              ValueListenableBuilder<String>(
                valueListenable: priceTypeController,
                builder: (context, priceType, _) {
                  final currentPrice = priceType == 'Premium'
                      ? (product?['SuggestedSalePrice'] ?? 0)
                      : (product?['SuggestedSalePriceElite'] ?? 0);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('السعر الحالي:', style: GoogleFonts.cairo(color: Colors.grey)),
                        Text(
                          '${_formatNumber(currentPrice)} ج.م',
                          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // السعر المطلوب
              TextFormField(
                controller: requestedPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.cairo(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'السعر المطلوب *',
                  labelStyle: GoogleFonts.cairo(color: Colors.grey),
                  prefixIcon: const Icon(Icons.attach_money, color: Color(0xFFFFD700)),
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
                ),
              ),
              const SizedBox(height: 16),

              // السبب
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                style: GoogleFonts.cairo(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'سبب الطلب *',
                  labelStyle: GoogleFonts.cairo(color: Colors.grey),
                  prefixIcon: const Icon(Icons.note, color: Color(0xFFFFD700)),
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
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final requestedPrice = double.tryParse(requestedPriceController.text);
              if (requestedPrice == null || requestedPrice <= 0) {
                _showError('يرجى إدخال سعر صحيح');
                return;
              }
              if (reasonController.text.isEmpty) {
                _showError('يرجى كتابة سبب الطلب');
                return;
              }

              Navigator.pop(context);
              await _submitPriceChangeRequest(
                priceType: priceTypeController.value,
                currentPrice: priceTypeController.value == 'Premium'
                    ? (product?['SuggestedSalePrice'] ?? 0).toDouble()
                    : (product?['SuggestedSalePriceElite'] ?? 0).toDouble(),
                requestedPrice: requestedPrice,
                reason: reasonController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8B923),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('إرسال الطلب', style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, bool selected, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.white.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: selected ? color : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPriceChangeRequest({
    required String priceType,
    required double currentPrice,
    required double requestedPrice,
    required String reason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/pricing/products/${widget.productId}/price-request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'priceType': priceType,
          'currentPrice': currentPrice,
          'requestedPrice': requestedPrice,
          'reason': reason,
          'requestedBy': widget.username,
          'clientTime': DateTime.now().toIso8601String(),
        }),
      );

      final result = jsonDecode(res.body);
      if (result['success'] == true) {
        _showSuccess('تم إرسال طلب التعديل بنجاح');
      } else {
        _showError(result['message'] ?? 'فشل إرسال الطلب');
      }
    } catch (e) {
      _showError('فشل إرسال الطلب');
    }
  }

   void _showEditSalePriceDialog() {
    final priceTypeController = ValueNotifier<String>('Premium');
    final newPriceController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note, color: Color(0xFFFFD700), size: 24),
            const SizedBox(width: 10),
            Text(
              'تعديل سعر البيع',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // اختيار نوع الباقة
              ValueListenableBuilder<String>(
                valueListenable: priceTypeController,
                builder: (context, priceType, _) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildTypeChip(
                          'Premium',
                          priceType == 'Premium',
                          const Color(0xFFFFD700),
                          () => priceTypeController.value = 'Premium',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTypeChip(
                          'Elite',
                          priceType == 'Elite',
                          Colors.greenAccent,
                          () => priceTypeController.value = 'Elite',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // السعر الحالي
              ValueListenableBuilder<String>(
                valueListenable: priceTypeController,
                builder: (context, priceType, _) {
                  final currentPrice = priceType == 'Premium'
                      ? (product?['SuggestedSalePrice'] ?? 0)
                      : (product?['SuggestedSalePriceElite'] ?? 0);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('السعر الحالي:', style: GoogleFonts.cairo(color: Colors.grey)),
                        Text(
                          '${_formatNumber(currentPrice)} ج.م',
                          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // السعر الجديد
              TextFormField(
                controller: newPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.cairo(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'السعر الجديد *',
                  labelStyle: GoogleFonts.cairo(color: Colors.grey),
                  prefixIcon: const Icon(Icons.attach_money, color: Color(0xFFFFD700)),
                  suffixText: 'ج.م',
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
                ),
              ),
              const SizedBox(height: 16),

              // السبب
              TextFormField(
                controller: reasonController,
                maxLines: 2,
                style: GoogleFonts.cairo(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'سبب التعديل (اختياري)',
                  labelStyle: GoogleFonts.cairo(color: Colors.grey),
                  prefixIcon: const Icon(Icons.note, color: Color(0xFFFFD700)),
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
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(newPriceController.text);
              if (newPrice == null || newPrice <= 0) {
                _showError('يرجى إدخال سعر صحيح');
                return;
              }

              Navigator.pop(context);
              await _updateSalePriceDirectly(
                priceType: priceTypeController.value,
                newPrice: newPrice,
                reason: reasonController.text,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8B923),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('تحديث السعر', style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSalePriceDirectly({
    required String priceType,
    required double newPrice,
    required String reason,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/pricing/products/${widget.productId}/sale-price'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'priceType': priceType,
          'newSalePrice': newPrice,
          'changedBy': widget.username,
          'reason': reason.isNotEmpty ? reason : 'تعديل مباشر',
          'clientTime': DateTime.now().toIso8601String(),
        }),
      );

      final result = jsonDecode(res.body);
      if (result['success'] == true) {
        _showSuccess('تم تحديث سعر البيع بنجاح');
        fetchProductDetails(); // إعادة تحميل البيانات
      } else {
        _showError(result['message'] ?? 'فشل تحديث السعر');
      }
    } catch (e) {
      _showError('فشل تحديث السعر');
    }
  }

    Widget _buildPDFSection() {
    return _buildSection(
      'ملف PDF',
      Icons.picture_as_pdf,
      InkWell(
        onTap: () {
          final pdfUrl = '$baseUrl/api/products/${widget.productId}/pdf';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(
                url: pdfUrl, // ✅ الرابط
                title: 'كتالوج المنتج', // ✅ العنوان
              ),
            ),
          );
        },
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملف PDF مرفق',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'اضغط لفتح الملف',
                    style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Colors.red, size: 22),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1, end: 0);
  }

    Future<void> _openPdfFile() async { // 👈 سميناها _openPdfFile عشان نضمن الاسم
    final url = '$baseUrl/api/products/${widget.productId}/pdf';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل فتح ملف الـ PDF')),
        );
      }
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagePriceCard({
    required String title,
    required dynamic cost,
    required dynamic sale,
    required double margin,
    required Color color,
  }) {
    final permService = PermissionService();
    final showFull = permService.canSeeFullProductPricing;          // admin / nabil / hassan
    final costOnly = permService.canSeeCostOnlyProductPricing;      // factory
    final saleOnly = permService.canSeeSaleOnlyProductPricing;      // باقي اليوزرات

    final costText = '${_formatNumber(cost ?? 0)} ج.م';
    final saleText = '${_formatNumber(sale ?? 0)} ج.م';
    final marginText = '${margin.toStringAsFixed(1)} %';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان (Premium / Elite)
          Text(
            title,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // 🌕 الحالة الأولى: يشوف كل حاجة
          if (showFull) ...[
            // التكلفة
            Row(
              children: [
                Text(
                  'التكلفة:',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  costText,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // سعر البيع
            Row(
              children: [
                Text(
                  'سعر البيع:',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  saleText,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // نسبة الربح
            Row(
              children: [
                Text(
                  'نسبة الربح:',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  marginText,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ]

          // 🌗 الحالة الثانية: يشوف تكلفة بس (factory)
          else if (costOnly) ...[
            Row(
              children: [
                Text(
                  'التكلفة:',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  costText,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ]

          // 🌘 الحالة الثالثة: يشوف سعر البيع بس (الباقيين)
          else if (saleOnly) ...[
            Row(
              children: [
                Text(
                  'سعر البيع:',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  saleText,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyEliteCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Elite',
            style: GoogleFonts.cairo(
              color: Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم إدخال أسعار Elite',
            style: GoogleFonts.cairo(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(String label, dynamic price, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatNumber(price ?? 0)} ج.م',
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.person_outline,
            'العميل',
            product!['CustomerName'] ?? 'منتج عام',
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.inventory_2_outlined,
            'الكمية',
            '${product!['QTY'] ?? 1} قطعة',
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.timer_outlined,
            'مدة التصنيع',
            '${product!['Period'] ?? 0} يوم',
          ),
          if (product!['PricingType'] != null) ...[
            _buildDivider(),
            _buildInfoRow(
              Icons.price_change_outlined,
              'نوع التسعير',
              product!['PricingType'],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 22),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.white.withOpacity(0.1), height: 1);
  }

  Widget _buildDescriptionSection() {
    return _buildSection(
      'الوصف',
      Icons.description_outlined,
      Text(
        product!['ProductDescription'],
        style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 14, height: 1.6),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildManufacturingSection() {
    return _buildSection(
      'وصف التصنيع',
      Icons.precision_manufacturing_outlined,
      Text(
        product!['ManufacturingDescription'],
        style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 14, height: 1.6),
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildComponentsSection() {
    return _buildSection(
      'المكونات',
      Icons.widgets_outlined,
      Column(
        children: components.map((comp) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${comp['Quantity']}',
                      style: GoogleFonts.cairo(
                        color: const Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  comp['ComponentName'],
                  style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFFD700), size: 22),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}