import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/leads_service.dart';
import 'lead_detail_screen.dart'; // سننشئها لاحقاً أو تعرض التفاصيل

class LeadsScreen extends StatefulWidget {
  final int userId;
  final String username;

  const LeadsScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  bool _isLoading = true;
  List<dynamic> _leads = [];
  String _selectedStatus = 'الكل';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statuses = ['الكل', 'جديد', 'تم التواصل', 'مؤهل', 'محوّل', 'مرفوض'];

  @override
  void initState() {
    super.initState();
    _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLoading = true);
    final leads = await LeadsService.getLeads(
      status: _selectedStatus,
      search: _searchController.text.trim(),
    );
    setState(() {
      _leads = leads;
      _isLoading = false;
    });
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'جديد':
        return Colors.blue;
      case 'تم التواصل':
        return Colors.orange;
      case 'مؤهل':
        return Colors.purple;
      case 'محوّل':
        return Colors.green;
      case 'مرفوض':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Text(
          'العملاء المحتملين (Meta Leads)',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLeads,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والفلاتر
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? Colors.grey[900] : Colors.white,
            child: Column(
              children: [
                // حقل البحث
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _fetchLeads(),
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم، الهاتف، أو الحملة...',
                    hintStyle: GoogleFonts.cairo(fontSize: 13),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _fetchLeads();
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 10),
                // فلاتر الحالة (Chips)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statuses.length,
                    itemBuilder: (context, index) {
                      final status = _statuses[index];
                      final isSelected = _selectedStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedStatus = status;
                            });
                            _fetchLeads();
                          },
                          selectedColor: AppColors.gold,
                          labelStyle: GoogleFonts.cairo(
                            color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // قائمة الـ Leads
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.gold))
                : _leads.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد عملاء محتملين مطابقة',
                          style: GoogleFonts.cairo(color: AppColors.textSecondary(isDark)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _leads.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          final lead = _leads[index];
                          final status = lead['LeadStatus'] ?? 'جديد';
                          final statusColor = _getStatusColor(status);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                // TODO: الانتقال لشاشة التفاصيل
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lead['FullName'] ?? 'بدون اسم',
                                            style: GoogleFonts.cairo(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: statusColor),
                                          ),
                                          child: Text(
                                            status,
                                            style: GoogleFonts.cairo(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(
                                          lead['Phone'] ?? '',
                                          style: GoogleFonts.cairo(fontSize: 13, color: Colors.blueGrey),
                                        ),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.campaign, size: 14, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            lead['CampaignName'] ?? 'إعلان عام',
                                            style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'التاريخ: ${lead['LeadDate'] ?? ''}',
                                          style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                                        ),
                                        Text(
                                          'المسؤول: ${lead['EmployeeName'] ?? 'غير مسند'}',
                                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}