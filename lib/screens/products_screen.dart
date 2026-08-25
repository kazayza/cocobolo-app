import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import 'product_details_screen.dart';
import 'add_product_screen.dart';
import '../services/permission_service.dart';
import 'price_requests_screen.dart';


class ProductsScreen extends StatefulWidget {
  final int userId;
  final String username;
  
  const ProductsScreen({
    Key? key, 
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<dynamic> products = [];
  List<dynamic> productGroups = [];
  List<dynamic> pricingStatuses = [];
  Map<String, dynamic> productStats = {};
  bool loading = true;
  
  // للبحث والفلتر
  final TextEditingController _searchController = TextEditingController();
  int? selectedGroupId;
  String searchQuery = '';

  // فلاتر جديدة (مطابقة لبلازور)
  int? selectedStatusId;          // فلتر الحالة (PricingStatusID)
  String ownershipFilter = 'all'; // all / showroom / linked
  String pricedFilter = 'all';    // all / priced / unpriced

  @override
  void initState() {
    super.initState();
    fetchProductGroups();
    fetchPricingStatuses();
    fetchStats();
    fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // جلب مجموعات المنتجات
Future<void> fetchProductGroups() async {
  try {
    final url = '$baseUrl/api/products/groups';
    print('📡 Fetching groups from: $url');

    final res = await http.get(Uri.parse(url));

    print('📡 Groups status: ${res.statusCode}');
    print('📡 Groups body: ${res.body}');

    if (res.statusCode == 200) {
      setState(() {
        productGroups = jsonDecode(res.body);
      });
    } else {
      // هنا ممكن نخليها بس تطبع ومانكسرش الشاشة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحميل المجموعات (${res.statusCode})'),
        ),
      );
    }
  } catch (e) {
    print('Error fetching groups: $e');
  }
}

  // جلب إحصائيات المنتجات
  Future<void> fetchStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/products/stats'));
      if (res.statusCode == 200) {
        setState(() {
          productStats = jsonDecode(res.body);
        });
      }
    } catch (e) {
      print('Error fetching stats: $e');
    }
  }

  // جلب حالات التسعير (للفلتر)
  Future<void> fetchPricingStatuses() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/products/pricing-statuses'));
      if (res.statusCode == 200) {
        setState(() {
          pricingStatuses = jsonDecode(res.body);
        });
      }
    } catch (e) {
      print('Error fetching pricing statuses: $e');
    }
  }

  // إعادة تعيين كل الفلاتر
  void clearAllFilters() {
    setState(() {
      selectedGroupId = null;
      selectedStatusId = null;
      ownershipFilter = 'all';
      pricedFilter = 'all';
      _searchController.clear();
      searchQuery = '';
    });
    fetchProducts();
  }

  // جلب المنتجات (بحث + مجموعة + حالة + ملكية + مسعرة)
Future<void> fetchProducts() async {
  setState(() => loading = true);
  
  try {
    String url = '$baseUrl/api/products?';
    
    if (searchQuery.isNotEmpty) {
      url += 'search=${Uri.encodeComponent(searchQuery)}&';
    }
    if (selectedGroupId != null) {
      url += 'groupId=$selectedGroupId&';
    }
    if (selectedStatusId != null) {
      url += 'statusId=$selectedStatusId&';
    }
    if (ownershipFilter != 'all') {
      url += 'ownership=$ownershipFilter&';
    }
    if (pricedFilter != 'all') {
      url += 'priced=$pricedFilter&';
    }
    url = url.substring(0, url.length - 1); // شيل آخر &

    print('📡 Fetching products from: $url');

    final res = await http.get(Uri.parse(url));

    print('📡 Products status: ${res.statusCode}');
    // لو الريسبونس كبير، نطبع أول 300 حرف بس
    print('📡 Products body (first 300): ${res.body.substring(0, res.body.length > 300 ? 300 : res.body.length)}');

    if (res.statusCode == 200) {
      setState(() {
        products = jsonDecode(res.body);
        loading = false;
      });
    } else {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحميل المنتجات (${res.statusCode})'),
        ),
      );
    }
  } catch (e) {
    print('Error fetching products: $e');
    setState(() => loading = false);
  }
}

  // البحث
  void _onSearch(String value) {
    setState(() => searchQuery = value);
    fetchProducts();
  }

  // تغيير الفلتر
  void _onFilterChanged(int? groupId) {
    setState(() => selectedGroupId = groupId);
    fetchProducts();
  }

  Future<void> _deleteProduct(int productId, String productName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(
              'تأكيد الحذف',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'هل تريد حذف المنتج "$productName"؟\nلا يمكن التراجع عن هذا الإجراء.',
          style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/products/$productId'),
      );

      if (res.statusCode == 200) {
        final result = jsonDecode(res.body);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('تم حذف المنتج بنجاح', style: GoogleFonts.cairo()),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          fetchProducts();
        } else {
          _showError(result['message'] ?? 'فشل حذف المنتج');
        }
      } else {
        _showError('فشل حذف المنتج');
      }
    } catch (e) {
      print('Error deleting product: $e');
      _showError('فشل حذف المنتج');
    }
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

  void _showProductOptions(Map<String, dynamic> product) {
    final perm = PermissionService();
    final productId = product['ProductID'];
    final productName = product['ProductName'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // العنوان
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              productName,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // فتح التفاصيل
            _buildOptionTile(
              icon: Icons.visibility,
              title: 'عرض التفاصيل',
              color: const Color(0xFFFFD700),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailsScreen(
                      productId: productId,
                      username: widget.username,
                    ),
                  ),
                ).then((_) => fetchProducts());
              },
            ),

            // تعديل (لو عنده صلاحية)
            if (perm.canEdit(FormNames.productsAdd) || perm.isFactory)
              _buildOptionTile(
                icon: Icons.edit,
                title: 'تعديل المنتج',
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddProductScreen(
                        username: widget.username,
                        productId: productId,
                        existingProduct: product,
                      ),
                    ),
                  ).then((_) => fetchProducts());
                },
              ),

            // طلب تعديل سعر (Sales فقط)
            if (perm.canRequestPriceChange)
              _buildOptionTile(
                icon: Icons.price_change,
                title: 'طلب تعديل سعر',
                color: Colors.orangeAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailsScreen(
                        productId: productId,
                        username: widget.username,
                      ),
                    ),
                  );
                },
              ),

            // حذف (لو عنده صلاحية)
            if (perm.canDelete(FormNames.productsAdd))
              _buildOptionTile(
                icon: Icons.delete,
                title: 'حذف المنتج',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _deleteProduct(productId, productName);
                },
              ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // شريط البحث والفلتر
          _buildSearchAndFilter(),
          
          // قائمة المنتجات
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                  )
                : products.isEmpty
                    ? _buildEmptyState()
                    : _buildProductsList(),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'المنتجات',
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      backgroundColor: const Color(0xFFE8B923),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: fetchProducts,
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFFD700).withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // حقل البحث
          TextField(
            controller: _searchController,
            style: GoogleFonts.cairo(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو العميل...',
              hintStyle: GoogleFonts.cairo(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFFFD700)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: _onSearch,
          ),
          
          const SizedBox(height: 12),
          
          // فلتر المجموعات
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: selectedGroupId,
                isExpanded: true,
                hint: Text(
                  'كل المجموعات',
                  style: GoogleFonts.cairo(color: Colors.white70),
                ),
                dropdownColor: const Color(0xFF1A1A1A),
                icon: const Icon(Icons.filter_list, color: Color(0xFFFFD700)),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'كل المجموعات',
                      style: GoogleFonts.cairo(color: Colors.white),
                    ),
                  ),
                  ...productGroups.map((group) => DropdownMenuItem<int?>(
                    value: group['ProductGroupID'],
                    child: Text(
                      group['GroupName'],
                      style: GoogleFonts.cairo(color: Colors.white),
                    ),
                  )),
                ],
                onChanged: _onFilterChanged,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── فلتر الحالة + الملكية (صف واحد) ──
          Row(
            children: [
              Expanded(
                child: _filterDropdown(
                  value: selectedStatusId,
                  hint: 'كل الحالات',
                  icon: Icons.flag_rounded,
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text('كل الحالات', style: GoogleFonts.cairo(color: Colors.white))),
                    ...pricingStatuses.map((s) => DropdownMenuItem<int?>(
                      value: (s['PricingStatusID'] as num?)?.toInt(),
                      child: Text(_statusName(s['StatusName']?.toString()), style: GoogleFonts.cairo(color: Colors.white)),
                    )),
                  ],
                  onChanged: (v) {
                    setState(() => selectedStatusId = v);
                    fetchProducts();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterDropdown(
                  value: ownershipFilter,
                  hint: 'كل المنتجات',
                  icon: Icons.store_rounded,
                  items: [
                    DropdownMenuItem<String>(value: 'all', child: Text('كل المنتجات', style: GoogleFonts.cairo(color: Colors.white))),
                    DropdownMenuItem<String>(value: 'showroom', child: Text('منتجات المعرض (${productStats['showroom'] ?? 0})', style: GoogleFonts.cairo(color: Colors.white))),
                    DropdownMenuItem<String>(value: 'linked', child: Text('مرتبطة بعميل (${productStats['linked'] ?? 0})', style: GoogleFonts.cairo(color: Colors.white))),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => ownershipFilter = v);
                    fetchProducts();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── فلتر المسعرة/غير المسعرة (شرائح) ──
          Row(
            children: [
              _statChip('الكل', productStats['total'] ?? 0, pricedFilter == 'all', () {
                setState(() => pricedFilter = 'all');
                fetchProducts();
              }),
              const SizedBox(width: 8),
              _statChip('مسعرة', productStats['priced'] ?? 0, pricedFilter == 'priced', () {
                setState(() => pricedFilter = 'priced');
                fetchProducts();
              }),
              const SizedBox(width: 8),
              _statChip('غير مسعرة', productStats['unpriced'] ?? 0, pricedFilter == 'unpriced', () {
                setState(() => pricedFilter = 'unpriced');
                fetchProducts();
              }),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  // قائمة منسدلة موحدة للفلاتر
  Widget _filterDropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: const Color(0xFFFFD700)),
              const SizedBox(width: 6),
              Flexible(child: Text(hint, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
            ],
          ),
          dropdownColor: const Color(0xFF1A1A1A),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFD700)),
          items: items,
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // شريحة إحصائية (مسعرة/غير مسعرة/الكل)
  Widget _statChip(String label, int count, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFFD700).withOpacity(0.15)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xFFFFD700).withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: active ? const Color(0xFFFFD700) : Colors.white,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 10.5,
                  color: active ? const Color(0xFFFFD700) : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ترجمة اسم الحالة من الإنجليزي للعربي
  String _statusName(String? name) {
    switch (name) {
      case 'Draft': return 'مسودة';
      case 'WaitingForPricing': return 'بانتظار التسعير';
      case 'Priced': return 'تم التسعير';
      case 'PriceChangeRequested': return 'طلب تعديل سعر';
      case 'PriceApproved': return 'تمت الموافقة';
      case 'PriceRejected': return 'مرفوض';
      case 'SalePriceChangeRequested': return 'طلب تعديل سعر بيع';
      case 'CostChangeRequested': return 'طلب تعديل تكلفة';
      default: return name ?? '—';
    }
  }

  // شارة الحالة في كارت المنتج (بلون حسب الحالة)
  Widget _statusBadge(String? statusName) {
    Color color;
    switch (statusName) {
      case 'Draft': color = const Color(0xFF9E9E9E); break;
      case 'WaitingForPricing': color = const Color(0xFFFF9800); break;
      case 'Priced': color = const Color(0xFF4CAF50); break;
      case 'PriceChangeRequested': color = const Color(0xFF2196F3); break;
      case 'PriceApproved': color = const Color(0xFF00BCD4); break;
      case 'PriceRejected': color = const Color(0xFFF44336); break;
      default: color = const Color(0xFF9E9E9E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        _statusName(statusName),
        style: GoogleFonts.cairo(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد منتجات',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'اضغط + لإضافة منتج جديد',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return RefreshIndicator(
      onRefresh: fetchProducts,
      color: const Color(0xFFE8B923),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product, index);
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    // 🔐 منطق عرض الأسعار حسب نوع المستخدم
    final permService = PermissionService();
    final costOnly = permService.canSeeCostOnlyProductPricing;      // factory
    // باقي اليوزرات (ومنهم أصحاب الـ full) → في الليست نعرض سعر البيع فقط
    final saleOnly = permService.canSeeSaleOnlyProductPricing ||
        permService.canSeeFullProductPricing;

    // الباقات الثلاثة (Standard = CClass / Premium = الأساسي / Elite)
    final Map<String, dynamic> packages = {
      'Standard': {
        'cost': product['PurchasePriceCClass'] ?? 0,
        'sale': product['SuggestedSalePriceCClass'] ?? 0,
        'color': const Color(0xFF42A5F5),
      },
      'Premium': {
        'cost': product['PurchasePrice'] ?? 0,
        'sale': product['SuggestedSalePrice'] ?? 0,
        'color': const Color(0xFFFFD700),
      },
      'Elite': {
        'cost': product['PurchasePriceElite'] ?? 0,
        'sale': product['SuggestedSalePriceElite'] ?? 0,
        'color': Colors.greenAccent,
      },
    };

    return Card(
      color: Colors.white.withOpacity(0.08),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFFFD700).withOpacity(0.2),
        ),
      ),
       child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(
                productId: product['ProductID'],
                username: widget.username,
              ),
            ),
          ).then((_) => fetchProducts());
        },
        onLongPress: () {
          // Long Press لعرض خيارات
          _showProductOptions(product);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // الصورة (Thumbnail من الـ API)
              _buildProductThumbnail(product),

              const SizedBox(width: 16),

              // تفاصيل المنتج
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم المنتج + شارة الحالة
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product['ProductName'] ?? 'بدون اسم',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (product['PricingStatusName'] != null) ...[
                          const SizedBox(width: 6),
                          _statusBadge(product['PricingStatusName']?.toString()),
                        ],
                      ],
                    ),

                    const SizedBox(height: 6),

                    // العميل
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product['CustomerName'] ?? 'منتج عام',
                            style: GoogleFonts.cairo(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // المجموعة
                    Row(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product['GroupName'] ?? '',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFFFFD700),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // أسعار الباقات الثلاثة (Standard / Premium / Elite)
                    // — المصنع يشوف التكلفة، والباقي يشوف سعر البيع
                    Row(
                      children: packages.entries.map((entry) {
                        final pkg = entry.value;
                        final pkgCost = pkg['cost'] ?? 0;
                        final pkgSale = pkg['sale'] ?? 0;
                        final pkgColor = pkg['color'] as Color;

                        // نخفي الباقة لو القيمتين صفر (مفيش بيانات)
                        final hasData =
                            (pkgCost is num ? pkgCost : 0) != 0 ||
                            (pkgSale is num ? pkgSale : 0) != 0;
                        if (!hasData) return const SizedBox.shrink();

                        final displayValue = costOnly ? pkgCost : pkgSale;

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 5),
                            decoration: BoxDecoration(
                              color: pkgColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: pkgColor.withOpacity(0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: GoogleFonts.cairo(
                                    color: pkgColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${_formatNumber(displayValue)} ج.م',
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // سهم
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white24,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }
  
    Widget _buildProductThumbnail(Map<String, dynamic> product) {
    final mainImageId = product['MainImageId'];

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: mainImageId != null
            ? Image.network(
                '$baseUrl/api/product-image-by-id/$mainImageId',
                fit: BoxFit.cover,
                // Placeholder أثناء التحميل
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  );
                },
                // Placeholder في حالة الخطأ
                errorBuilder: (context, error, stackTrace) {
                  return _buildThumbnailPlaceholderIcon();
                },
              )
            : _buildThumbnailPlaceholderIcon(),
      ),
    );
  }

  Widget _buildThumbnailPlaceholderIcon() {
    return Container(
      color: Colors.white.withOpacity(0.02),
      child: Icon(
        Icons.inventory_2_outlined,
        size: 32,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: product['ProductImage'] != null
            ? Image.memory(
                base64Decode(product['ProductImage']),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }
    Widget _buildProductThumbnailPlaceholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.3),
        ),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: 32,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.05),
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: Colors.grey[600],
      ),
    );
  }

  // ✅ تم التعديل - إضافة الصلاحيات
  Widget _buildFAB() {
    final perm = PermissionService();

    // Factory مش بيضيف منتجات
    // Account مش بيضيف منتجات
    if (perm.isFactory || perm.isAccount) {
      return const SizedBox.shrink();
    }

    // لو مش عنده صلاحية الإضافة
    if (!perm.canAdd(FormNames.productsAdd)) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddProductScreen(
              username: widget.username,
            ),
          ),
        ).then((_) => fetchProducts());
      },
      backgroundColor: const Color(0xFFE8B923),
      icon: const Icon(Icons.add, color: Colors.black),
      label: Text(
        'إضافة منتج',
        style: GoogleFonts.cairo(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}