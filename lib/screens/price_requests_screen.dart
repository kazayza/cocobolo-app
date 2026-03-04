import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../services/permission_service.dart';

class PriceRequestsScreen extends StatefulWidget {
  final String username;

  const PriceRequestsScreen({
    Key? key,
    required this.username,
  }) : super(key: key);

  @override
  State<PriceRequestsScreen> createState() => _PriceRequestsScreenState();
}

class _PriceRequestsScreenState extends State<PriceRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final perm = PermissionService();

  List<dynamic> pendingRequests = [];
  List<dynamic> myRequests = [];
  List<dynamic> allRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // تحديد عدد التابات حسب الـ Role
    int tabCount = 1;
    if (perm.canReviewPriceRequests) tabCount = 2; // SalesManager: Pending + All
    if (perm.isAdmin || perm.isAccountManager) tabCount = 2; // Admin: All + Pending
    if (perm.canRequestPriceChange) tabCount = 1; // Sales: My Requests only

    _tabController = TabController(length: _getTabCount(), vsync: this);
    _fetchData();
  }

  int _getTabCount() {
    if (perm.isAdmin || perm.isAccountManager) return 2; // Pending + All
    if (perm.canReviewPriceRequests) return 2; // Pending + All
    if (perm.canRequestPriceChange) return 1; // My Requests
    return 1;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =====================
  // 📡 API Calls
  // =====================

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // SalesManager / Admin / AccountManager → Pending + All
      if (perm.canReviewPriceRequests || perm.isAdmin || perm.isAccountManager) {
        final pendingRes = await http.get(
          Uri.parse('$baseUrl/api/pricing/price-requests/pending'),
        );
        final allRes = await http.get(
          Uri.parse('$baseUrl/api/pricing/price-requests/all'),
        );

        if (pendingRes.statusCode == 200) {
          pendingRequests = jsonDecode(pendingRes.body);
        }
        if (allRes.statusCode == 200) {
          allRequests = jsonDecode(allRes.body);
        }
      }

      // Sales → My Requests
      if (perm.canRequestPriceChange) {
        final myRes = await http.get(
          Uri.parse('$baseUrl/api/pricing/price-requests/my?username=${widget.username}'),
        );
        if (myRes.statusCode == 200) {
          myRequests = jsonDecode(myRes.body);
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching requests: $e');
      setState(() => _isLoading = false);
      _showError('فشل تحميل الطلبات');
    }
  }

  Future<void> _approveRequest(int requestId) async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 10),
            Text(
              'تأكيد الموافقة',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'هل تريد الموافقة على هذا الطلب؟\nسيتم تحديث سعر البيع فوراً.',
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: notesController,
              maxLines: 2,
              style: GoogleFonts.cairo(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                labelStyle: GoogleFonts.cairo(color: Colors.grey),
                prefixIcon: const Icon(Icons.note, color: Colors.green),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('موافقة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/pricing/price-requests/$requestId/approve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reviewedBy': widget.username,
          'reviewNotes': notesController.text.isNotEmpty ? notesController.text : null,
          'clientTime': DateTime.now().toIso8601String(),
        }),
      );

      final result = jsonDecode(res.body);
      if (result['success'] == true) {
        _showSuccess('تمت الموافقة على الطلب وتم تحديث السعر');
        _fetchData();
      } else {
        _showError(result['message'] ?? 'فشل الموافقة');
      }
    } catch (e) {
      _showError('فشل الموافقة على الطلب');
    }
  }

  Future<void> _rejectRequest(int requestId) async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 24),
            const SizedBox(width: 10),
            Text(
              'تأكيد الرفض',
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'يرجى كتابة سبب الرفض:',
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: notesController,
              maxLines: 3,
              style: GoogleFonts.cairo(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'سبب الرفض *',
                labelStyle: GoogleFonts.cairo(color: Colors.grey),
                prefixIcon: const Icon(Icons.note, color: Colors.red),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (notesController.text.isEmpty) {
                _showError('سبب الرفض مطلوب');
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('رفض', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/pricing/price-requests/$requestId/reject'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reviewedBy': widget.username,
          'reviewNotes': notesController.text,
          'clientTime': DateTime.now().toIso8601String(),
        }),
      );

      final result = jsonDecode(res.body);
      if (result['success'] == true) {
        _showSuccess('تم رفض الطلب');
        _fetchData();
      } else {
        _showError(result['message'] ?? 'فشل الرفض');
      }
    } catch (e) {
      _showError('فشل رفض الطلب');
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
        title: Text(
          perm.canRequestPriceChange ? 'طلباتي' : 'طلبات تعديل الأسعار',
          style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE8B923),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: _getTabCount() > 1
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.black,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                tabs: _buildTabs(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : _getTabCount() > 1
              ? TabBarView(
                  controller: _tabController,
                  children: _buildTabViews(),
                )
              : _buildRequestsList(_getMainList()),
    );
  }

  List<Tab> _buildTabs() {
    if (perm.canReviewPriceRequests || perm.isAdmin || perm.isAccountManager) {
      return [
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pending_actions, size: 18),
              const SizedBox(width: 6),
              Text('معلقة (${pendingRequests.length})'),
            ],
          ),
        ),
        Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.list_alt, size: 18),
              const SizedBox(width: 6),
              Text('الكل (${allRequests.length})'),
            ],
          ),
        ),
      ];
    }
    return [const Tab(text: 'طلباتي')];
  }

  List<Widget> _buildTabViews() {
    if (perm.canReviewPriceRequests || perm.isAdmin || perm.isAccountManager) {
      return [
        _buildRequestsList(pendingRequests),
        _buildRequestsList(allRequests),
      ];
    }
    return [_buildRequestsList(myRequests)];
  }

  List<dynamic> _getMainList() {
    if (perm.canRequestPriceChange) return myRequests;
    if (perm.canReviewPriceRequests) return pendingRequests;
    return allRequests;
  }

  Widget _buildRequestsList(List<dynamic> requests) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 60, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'لا توجد طلبات',
              style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFFE8B923),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(requests[index], index);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, int index) {
    final status = request['Status'] ?? 'Pending';
    final priceType = request['PriceType'] ?? '';
    final productName = request['ProductName'] ?? '';
    final currentPrice = request['CurrentPrice'] ?? 0;
    final requestedPrice = request['RequestedPrice'] ?? 0;
    final reason = request['Reason'] ?? '';
    final requestedBy = request['RequestedBy'] ?? '';
    final requestedAt = request['RequestedAt'] ?? '';
    final reviewedBy = request['ReviewedBy'] ?? '';
    final reviewNotes = request['ReviewNotes'] ?? '';
    final requestId = request['RequestID'];

    // ألوان الحالة
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = 'تمت الموافقة';
        break;
      case 'Rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusLabel = 'مرفوض';
        break;
      default:
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.pending;
        statusLabel = 'معلق';
    }

    // لون الباقة
    final typeColor = priceType == 'Premium' ? const Color(0xFFFFD700) : Colors.greenAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // الهيدر
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: GoogleFonts.cairo(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priceType,
                    style: GoogleFonts.cairo(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // المحتوى
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اسم المنتج
                Text(
                  productName,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // الأسعار
                Row(
                  children: [
                    Expanded(
                      child: _buildPriceBox('السعر الحالي', currentPrice, Colors.grey),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_forward, color: typeColor, size: 22),
                    ),
                    Expanded(
                      child: _buildPriceBox('السعر المطلوب', requestedPrice, typeColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // الفرق
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'الفرق: ${_formatNumber((requestedPrice - currentPrice).abs())} ج.م',
                      style: GoogleFonts.cairo(
                        color: requestedPrice > currentPrice ? Colors.red : Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // السبب
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
                      const Icon(Icons.note, size: 16, color: Colors.orangeAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // التفاصيل
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(requestedBy, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 11)),
                    const Spacer(),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(requestedAt, style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 11)),
                  ],
                ),

                // ملاحظات المراجعة (لو موجودة)
                if (reviewedBy.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        status == 'Approved' ? Icons.check : Icons.close,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'بواسطة: $reviewedBy',
                        style: GoogleFonts.cairo(color: statusColor, fontSize: 11),
                      ),
                    ],
                  ),
                  if (reviewNotes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      reviewNotes,
                      style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ],

                // أزرار الموافقة والرفض (SalesManager فقط + Pending فقط)
                if (perm.canReviewPriceRequests && status == 'Pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _rejectRequest(requestId),
                          icon: const Icon(Icons.close, size: 18),
                          label: Text('رفض', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveRequest(requestId),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text('موافقة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildPriceBox(String label, dynamic price, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 4),
          Text(
            '${_formatNumber(price)} ج.م',
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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