import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

class PriceHistoryScreen extends StatefulWidget {
  final int productId;
  final String productName;

  const PriceHistoryScreen({
    Key? key,
    required this.productId,
    required this.productName,
  }) : super(key: key);

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  List<dynamic> history = [];
  bool _isLoading = true;

  // فلتر نوع السعر
  String _selectedFilter = 'all'; // all, PurchasePrice, SalePrice, PurchasePriceElite, SalePriceElite

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // =====================
  // 📡 API
  // =====================

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/pricing/products/${widget.productId}/history'),
      );

      if (res.statusCode == 200) {
        setState(() {
          history = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showError('فشل تحميل تاريخ الأسعار');
      }
    } catch (e) {
      print('Error fetching price history: $e');
      setState(() => _isLoading = false);
      _showError('فشل الاتصال بالسيرفر');
    }
  }

  // =====================
  // 🎨 UI
  // =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'تاريخ الأسعار',
              style: GoogleFonts.cairo(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              widget.productName,
              style: GoogleFonts.cairo(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE8B923),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // فلتر نوع السعر
          _buildFilterBar(),

          // القائمة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
                : _filteredHistory.isEmpty
                    ? _buildEmptyState()
                    : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  // الفلترة
  List<dynamic> get _filteredHistory {
    if (_selectedFilter == 'all') return history;
    return history.where((h) => h['PriceType'] == _selectedFilter).toList();
  }

    Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: const Color(0xFFFFD700).withOpacity(0.3)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', 'الكل', Icons.all_inclusive, Colors.white),
            const SizedBox(width: 8),
            // ✅ القيم هنا لازم تكون زي اللي جاية من السيرفر بالظبط
            _buildFilterChip('شراء', 'تكلفة Premium', Icons.money_off, Colors.orangeAccent),
            const SizedBox(width: 8),
            _buildFilterChip('بيع', 'بيع Premium', Icons.attach_money, const Color(0xFFFFD700)),
            const SizedBox(width: 8),
            _buildFilterChip('شراء Elite', 'تكلفة Elite', Icons.money_off, Colors.tealAccent),
            const SizedBox(width: 8),
            _buildFilterChip('بيع Elite', 'بيع Elite', Icons.attach_money, Colors.greenAccent),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildFilterChip(String value, String label, IconData icon, Color color) {
    final isSelected = _selectedFilter == value;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: isSelected ? color : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 60, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'لا يوجد سجل تغييرات',
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم تعديل أسعار هذا المنتج بعد',
            style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: const Color(0xFFE8B923),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredHistory.length,
        itemBuilder: (context, index) {
          return _buildHistoryCard(_filteredHistory[index], index);
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record, int index) {
    final priceType = record['PriceType'] ?? '';
    final oldPrice = record['OldPrice'] ?? 0;
    final newPrice = record['NewPrice'] ?? 0;
    final changedBy = record['ChangedBy'] ?? '';
    final changedAt = record['ChangedAt'] ?? '';
    final reason = record['ChangeReason'] ?? '';

    // ✅ قيم افتراضية عشان نتجنب الأخطاء
    Color typeColor = Colors.grey;
    String typeLabel = priceType;
    IconData typeIcon = Icons.price_change;

    // ✅ Switch واحدة بس وصحيحة
    switch (priceType) {
      case 'شراء':
        typeColor = Colors.orangeAccent;
        typeLabel = 'تكلفة Premium';
        typeIcon = Icons.money_off;
        break;
      case 'بيع':
        typeColor = const Color(0xFFFFD700);
        typeLabel = 'بيع Premium';
        typeIcon = Icons.attach_money;
        break;
      case 'شراء Elite':
        typeColor = Colors.tealAccent;
        typeLabel = 'تكلفة Elite';
        typeIcon = Icons.money_off;
        break;
      case 'بيع Elite':
        typeColor = Colors.greenAccent;
        typeLabel = 'بيع Elite';
        typeIcon = Icons.attach_money;
        break;
      default:
        typeColor = Colors.grey;
        typeLabel = priceType;
        typeIcon = Icons.price_change;
    }

    final isIncrease = (newPrice as num) > (oldPrice as num);
    final changeIcon = isIncrease ? Icons.arrow_upward : Icons.arrow_downward;
    final changeColor = isIncrease ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: typeColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(typeIcon, color: typeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  typeLabel,
                  style: GoogleFonts.cairo(
                    color: typeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(changeIcon, color: changeColor, size: 18),
                const SizedBox(width: 4),
                Text(
                  isIncrease ? 'زيادة' : 'تخفيض',
                  style: GoogleFonts.cairo(color: changeColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          'السعر القديم',
                          style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatNumber(oldPrice)} ج.م',
                          style: GoogleFonts.cairo(
                            color: Colors.grey,
                            fontSize: 15,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(
                        Icons.arrow_forward,
                        color: typeColor,
                        size: 24,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          'السعر الجديد',
                          style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatNumber(newPrice)} ج.م',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: changeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'الفرق: ${_formatNumber((newPrice - oldPrice).abs())} ج.م (${isIncrease ? '+' : '-'}${(((newPrice - oldPrice).abs() / (oldPrice == 0 ? 1 : oldPrice)) * 100).toStringAsFixed(1)}%)',
                    style: GoogleFonts.cairo(
                      color: changeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      changedBy,
                      style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 12),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      changedAt,
                      style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: 50 * index),
      duration: 400.ms,
    ).slideX(begin: 0.1, end: 0);
  }

  // =====================
  // 🔧 Helpers
  // =====================

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    if (number is double) {
      return number.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
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