import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_colors.dart';
import '../services/theme_service.dart';
import '../services/leads_service.dart';

class LeadDetailScreen extends StatefulWidget {
  final int leadId;
  final int userId;
  final String username;

  const LeadDetailScreen({
    Key? key,
    required this.leadId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _lead;
  List<dynamic> _interactions = [];
  final TextEditingController _interactionController = TextEditingController();
  final TextEditingController _expectedValueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final leadData = await LeadsService.getLeadById(widget.leadId);
    final interactionsData = await LeadsService.getInteractions(widget.leadId);
    setState(() {
      _lead = leadData;
      _interactions = interactionsData;
      _isLoading = false;
      if (leadData != null) {
        _notesController.text = leadData['Notes'] ?? '';
      }
    });
  }

  // الاتصال هاتفياً بالعميل
  Future<void> _callClient(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // إضافة تفاعل جديد
  Future<void> _addInteraction() async {
    if (_interactionController.text.trim().isEmpty) return;

    final success = await LeadsService.addInteraction(
      widget.leadId,
      _interactionController.text.trim(),
      widget.username,
    );

    if (success) {
      _interactionController.clear();
      _fetchData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل التفاعل بنجاح')),
      );
    }
  }

  // تحويل الـ Lead إلى عميل رسمي
  void _showConvertDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تحويل لعميل رسمي', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('سيتم إنشاء ملف عميل وفرصة مبيعات لهذا الـ Lead.', style: GoogleFonts.cairo(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _expectedValueController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'قيمة الفرصة المتوقعة (ج.م)',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              final result = await LeadsService.convertLeadToClient(widget.leadId, {
                'expectedValue': double.tryParse(_expectedValueController.text) ?? 0,
                'notes': _notesController.text,
                'userName': widget.username,
              });

              if (result['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? 'تم التحويل بنجاح')),
                );
                _fetchData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? 'فشل التحويل'), backgroundColor: Colors.red),
                );
              }
            },
            child: Text('تأكيد التحويل', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService().isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Text('تفاصيل العميل المحتمل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _lead == null
              ? const Center(child: Text('البيانات غير موجودة'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // كارت بيانات العميل الأساسية
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _lead!['FullName'] ?? '',
                                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Chip(
                                    label: Text(_lead!['LeadStatus'] ?? 'جديد'),
                                    backgroundColor: AppColors.gold.withOpacity(0.2),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                children: [
                                  const Icon(Icons.phone, color: Colors.blue, size: 18),
                                  const SizedBox(width: 8),
                                  Text(_lead!['Phone'] ?? '', style: GoogleFonts.cairo(fontSize: 15)),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.call, color: Colors.green),
                                    onPressed: () => _callClient(_lead!['Phone']),
                                  ),
                                ],
                              ),
                              if (_lead!['City'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Text(_lead!['City'], style: GoogleFonts.cairo(fontSize: 14)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.campaign, color: Colors.orange, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'الحملة: ${_lead!['CampaignName'] ?? 'غير متوفر'}',
                                      style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // زر التحويل لعميل (لو لم يتم تحويله بعد)
                      if (_lead!['IsConverted'] != true)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.person_add),
                            label: Text('تحويل إلى عميل رسمي (Convert)', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
                            onPressed: _showConvertDialog,
                          ),
                        ),

                      const SizedBox(height: 20),

                      // قسم سجل التفاعلات
                      Text('سجل التفاعلات والمكالمات', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      // حقل إضافة تفاعل جديد
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _interactionController,
                              decoration: InputDecoration(
                                hintText: 'أكتب تفاعل أو ملاحظة جديدة...',
                                hintStyle: GoogleFonts.cairo(fontSize: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.send),
                            onPressed: _addInteraction,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // قائمة التفاعلات السابقة
                      _interactions.isEmpty
                          ? Text('لا توجد تفاعلات مسجلة بعد', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _interactions.length,
                              itemBuilder: (context, index) {
                                final inter = _interactions[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(inter['Notes'] ?? '', style: GoogleFonts.cairo(fontSize: 13)),
                                    subtitle: Text(
                                      'بواسطة: ${inter['CreatedBy']} - ${inter['CreatedAt']}',
                                      style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey),
                                    ),
                                    trailing: const Icon(Icons.comment, size: 16, color: Colors.blue),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
    );
  }
}