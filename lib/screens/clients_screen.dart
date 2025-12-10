import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';
import '../services/permission_service.dart';
import 'add_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ClientsScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<dynamic> clients = [];
  List<dynamic> filteredClients = [];
  Map<String, dynamic> summary = {};
  bool loading = true;

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchSummary();
    fetchClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchSummary() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/clients/summary'));
      
      // طباعة للتشخيص - سأزيلها لاحقًا
      print('📊 إحصائيات - كود الاستجابة: ${res.statusCode}');
      print('📊 إحصائيات - نص الاستجابة: ${res.body}');
      
      if (res.statusCode == 200) {
        setState(() => summary = jsonDecode(res.body));
      } else {
        print('⚠️ الخادم رجع كود خطأ: ${res.statusCode}');
        // تعيين قيم افتراضية إذا فشل الاتصال
        setState(() {
          summary = {
            'totalClients': 0,
            'newToday': 0,
            'newThisMonth': 0
          };
        });
      }
    } catch (e) {
      print('❌ خطأ في جلب الإحصائيات: $e');
      // تعيين قيم افتراضية في حالة الخطأ
      setState(() {
        summary = {
          'totalClients': 0,
          'newToday': 0,
          'newThisMonth': 0
        };
      });
    }
  }

  Future<void> fetchClients() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/clients'));
      if (res.statusCode == 200) {
        setState(() {
          clients = jsonDecode(res.body);
          filteredClients = clients;
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
      _showErrorSnackBar('فشل في تحميل العملاء');
    }
  }

  void _filterClients(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredClients = clients;
      } else {
        filteredClients = clients.where((client) {
          final name = client['PartyName']?.toString().toLowerCase() ?? '';
          final phone = client['Phone']?.toString().toLowerCase() ?? '';
          final phone2 = client['Phone2']?.toString().toLowerCase() ?? '';
          final nationalId = client['NationalID']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();
          return name.contains(searchLower) ||
              phone.contains(searchLower) ||
              phone2.contains(searchLower) ||
              nationalId.contains(searchLower); // إضافة البحث بالرقم القومي
        }).toList();
      }
    });
  }

  Future<void> _refreshAll() async {
    await fetchSummary();
    await fetchClients();
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
      body: Column(
        children: [
          _buildSummarySection(),
          _buildSearchBar(),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                  )
                : filteredClients.isEmpty
                    ? _buildEmptyState()
                    : _buildClientsList(),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'العملاء',
        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.black),
      ),
      backgroundColor: const Color(0xFFE8B923),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshAll,
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    // إذا كانت الإحصائيات فارغة، نعرض قيم افتراضية
    final totalClients = summary['totalClients'] ?? 0;
    final newToday = summary['newToday'] ?? 0;
    final newThisMonth = summary['newThisMonth'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.2),
            const Color(0xFF4CAF50).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              'إجمالي العملاء',
              '$totalClients',
              Icons.people,
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          Expanded(
            child: _buildSummaryItem(
              'عملاء اليوم',
              '$newToday',
              Icons.person_add,
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          Expanded(
            child: _buildSummaryItem(
              'هذا الشهر',
              '$newThisMonth',
              Icons.calendar_month,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.cairo(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'بحث بالاسم، الهاتف، أو الرقم القومي...',
          hintStyle: GoogleFonts.cairo(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFFFD700)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    _filterClients('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: _filterClients,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 20),
          Text(
            searchQuery.isEmpty ? 'لا يوجد عملاء' : 'لا توجد نتائج',
            style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey[400]),
          ),
          const SizedBox(height: 10),
          Text(
            'اضغط + لإضافة عميل جديد',
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildClientsList() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: const Color(0xFFE8B923),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredClients.length,
        itemBuilder: (context, index) {
          final client = filteredClients[index];
          return _buildClientCard(client, index);
        },
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client, int index) {
    return Card(
      color: Colors.white.withOpacity(0.08),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF4CAF50).withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showClientDetails(client),
        onLongPress: () => _showClientOptions(client),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (client['PartyName'] ?? 'ع')[0].toUpperCase(),
                    style: GoogleFonts.cairo(
                      color: const Color(0xFF4CAF50),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client['PartyName'] ?? 'بدون اسم',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (client['Phone'] != null)
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            client['Phone'],
                            style: GoogleFonts.cairo(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    if (client['Address'] != null &&
                        client['Address'].toString().isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              client['Address'],
                              style: GoogleFonts.cairo(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // ========== التعديل هنا: استبدال الرصيد بالرقم القومي ==========
              if (client['NationalID'] != null && client['NationalID'].toString().isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.badge, size: 20, color: const Color(0xFFFFD700)),
                    const SizedBox(height: 4),
                    Text(
                      '${client['NationalID']}',
                      style: GoogleFonts.cairo(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.badge_outlined, size: 20, color: Colors.grey[600]),
                    const SizedBox(height: 4),
                    Text(
                      'لا يوجد',
                      style: GoogleFonts.cairo(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ), // <-- هذه الفاصلة كانت مفقودة وهنا كانت المشكلة!
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }

 void _showClientDetails(Map<String, dynamic> client) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      (client['PartyName'] ?? 'ع')[0].toUpperCase(),
                      style: GoogleFonts.cairo(
                        color: const Color(0xFF4CAF50),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  client['PartyName'] ?? '',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              
              // ===== البيانات المعروضة =====
              _buildDetailRow(Icons.phone, 'الهاتف', client['Phone'] ?? 'غير محدد'),
              if (client['Phone2'] != null && client['Phone2'].toString().isNotEmpty)
                _buildDetailRow(Icons.phone_android, 'هاتف 2', client['Phone2']),
              _buildDetailRow(Icons.email, 'البريد', client['Email'] ?? 'غير محدد'),
              _buildDetailRow(Icons.location_on, 'العنوان', client['Address'] ?? 'غير محدد'),
              _buildDetailRow(Icons.person, 'جهة الاتصال', client['ContactPerson'] ?? 'غير محدد'),
              
              // ✅ تم إزالة الرقم الضريبي
              // _buildDetailRow(Icons.credit_card, 'الرقم الضريبي', client['TaxNumber'] ?? 'غير محدد'),
              
              // ✅ إبقاء الرقم القومي
              if (client['NationalID'] != null && client['NationalID'].toString().isNotEmpty)
                _buildDetailRow(Icons.badge, 'الرقم القومي', client['NationalID']),
              
              // ✅ إضافة رقم الدور لو موجود
              if (client['FloorNumber'] != null && client['FloorNumber'].toString().isNotEmpty)
                _buildDetailRow(Icons.apartment, 'رقم الدور', client['FloorNumber']),
              
              // ✅ إضافة الملاحظات لو موجودة
              if (client['Notes'] != null && client['Notes'].toString().isNotEmpty)
                _buildDetailRow(Icons.notes, 'ملاحظات', client['Notes']),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddClientScreen(
                              username: widget.username,
                              existingClient: client,
                            ),
                          ),
                        ).then((result) {
                          if (result == true) _refreshAll();
                        });
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text('تعديل', style: GoogleFonts.cairo()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: إضافة وظيفة الاتصال
                      },
                      icon: const Icon(Icons.phone, size: 18),
                      label: Text('اتصال', style: GoogleFonts.cairo()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        side: const BorderSide(color: Color(0xFF4CAF50)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 20),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showClientOptions(Map<String, dynamic> client) {
    final permissions = PermissionService();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (permissions.canEdit(FormNames.partiesAdd))
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFFFFD700)),
                title: Text('تعديل', style: GoogleFonts.cairo(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddClientScreen(
                        username: widget.username,
                        existingClient: client,
                      ),
                    ),
                  ).then((result) {
                    if (result == true) _refreshAll();
                  });
                },
              ),
            if (permissions.canDelete(FormNames.partiesAdd))
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(client);
                },
              ),
            if (!permissions.canEdit(FormNames.partiesAdd) &&
                !permissions.canDelete(FormNames.partiesAdd))
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'ليس لديك صلاحيات للتعديل أو الحذف',
                  style: GoogleFonts.cairo(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'تأكيد الحذف',
          style: GoogleFonts.cairo(color: Colors.white),
        ),
        content: Text(
          'هل تريد حذف "${client['PartyName']}"؟',
          style: GoogleFonts.cairo(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteClient(client['PartyID']);
            },
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClient(int id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/api/clients/$id'));
      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الحذف بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
          ),
        );
        _refreshAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'فشل في الحذف', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في الحذف', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildFAB() {
    if (!PermissionService().canAdd(FormNames.partiesAdd)) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddClientScreen(username: widget.username),
          ),
        ).then((result) {
          if (result == true) _refreshAll();
        });
      },
      backgroundColor: const Color(0xFF4CAF50),
      icon: const Icon(Icons.person_add, color: Colors.white),
      label: Text(
        'إضافة عميل',
        style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
      ),
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