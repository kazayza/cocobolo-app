import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/permission_service.dart';
import 'add_exemption_screen.dart'; // هننشئها الخطوة الجاية

class ExemptionsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const ExemptionsScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<ExemptionsScreen> createState() => _ExemptionsScreenState();
}

class _ExemptionsScreenState extends State<ExemptionsScreen> {
  List<dynamic> exemptions = [];
  bool loading = true;
  String searchQuery = '';
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    if (!PermissionService().canView(FormNames.dailyExemptions)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
      return;
    }
    fetchExemptions();
  }

  Future<void> fetchExemptions() async {
    setState(() => loading = true);
    try {
      String url = '$baseUrl/api/attendance/exemptions-list?';
      if (searchQuery.isNotEmpty) url += 'employeeName=$searchQuery&';
      if (selectedDate != null) url += 'date=${DateFormat('yyyy-MM-dd').format(selectedDate!)}';

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        setState(() {
          exemptions = jsonDecode(res.body);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> _deleteExemption(int id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/api/attendance/exemptions/$id'));
      fetchExemptions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم الحذف بنجاح', style: GoogleFonts.cairo()), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحذف', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFE8B923), surface: Color(0xFF1E1E1E)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      fetchExemptions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = PermissionService().canAdd(FormNames.dailyExemptions);
    final canDelete = PermissionService().canDelete(FormNames.dailyExemptions);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text('الأذونات والاستثناءات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(selectedDate == null ? Icons.filter_alt_off : Icons.filter_alt, 
                color: selectedDate == null ? Colors.grey : const Color(0xFFE8B923)),
            onPressed: () => _selectDate(context),
          ),
          if (selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: () {
                setState(() => selectedDate = null);
                fetchExemptions();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              style: GoogleFonts.cairo(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'بحث باسم الموظف...',
                hintStyle: GoogleFonts.cairo(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE8B923)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                searchQuery = val;
                // Debounce
              },
              onSubmitted: (_) => fetchExemptions(),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8B923)))
                : exemptions.isEmpty
                    ? Center(child: Text('لا توجد استثناءات', style: GoogleFonts.cairo(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: exemptions.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final ex = exemptions[index];
                          return Dismissible(
                            key: Key(ex['ExemptionID'].toString()),
                            direction: canDelete ? DismissDirection.endToStart : DismissDirection.none,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: Text('تأكيد الحذف', style: GoogleFonts.cairo(color: Colors.white)),
                                  content: Text('هل تريد حذف هذا الاستثناء؟', style: GoogleFonts.cairo(color: Colors.grey)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text('حذف', style: GoogleFonts.cairo(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) => _deleteExemption(ex['ExemptionID']),
                            child: Card(
                              color: const Color(0xFF1E1E1E),
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getColorForReason(ex['ReasonCode']).withOpacity(0.2),
                                  child: Icon(_getIconForReason(ex['ReasonCode']), color: _getColorForReason(ex['ReasonCode'])),
                                ),
                                title: Text(ex['EmployeeName'], style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${ex['ReasonCode']} • ${DateFormat('yyyy-MM-dd').format(DateTime.parse(ex['ExemptionDate']))}',
                                        style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12)),
                                    if (ex['Description'] != null)
                                      Text(ex['Description'], style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 11)),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(delay: Duration(milliseconds: index * 50)),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddExemptionScreen(username: widget.username)),
                );
                if (result == true) fetchExemptions();
              },
              backgroundColor: const Color(0xFFE8B923),
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
    );
  }

  Color _getColorForReason(String reason) {
    if (reason.contains('إجازة')) return Colors.green;
    if (reason.contains('مرضي')) return Colors.red;
    if (reason.contains('مأمورية')) return Colors.blue;
    return Colors.orange;
  }

  IconData _getIconForReason(String reason) {
    if (reason.contains('إجازة')) return Icons.beach_access;
    if (reason.contains('مرضي')) return Icons.local_hospital;
    if (reason.contains('مأمورية')) return Icons.business_center;
    return Icons.timer;
  }
}