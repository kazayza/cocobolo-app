import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel; // ✅ أضف as excel
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../services/icon_utils.dart';
import '../services/permission_service.dart';
import 'add_opportunity_screen.dart';
import 'add_interaction_screen.dart';
import 'opportunity_details_screen.dart';
import 'closure_approval_requests_screen.dart'
    show ClosureApprovalRequestsScreen;
import 'lost_recovery_screen.dart';
import 'general_tasks_screen.dart';
import '../core/auth/session_service.dart';


import '../widgets/app_drawer.dart';
import '../widgets/design_kit.dart';
import '../services/design_tokens.dart';
class OpportunitiesScreen extends StatefulWidget {
  final int userId;
  final String username;

  const OpportunitiesScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  List<dynamic> opportunities = [];
  List<dynamic> stages = [];
  List<dynamic> sources = [];
  List<dynamic> adTypes = [];
  List<dynamic> employees = [];

  Map<String, dynamic> summary = {};
  bool loading = true;
    // ✅ Pagination
  int currentPage = 1;
  int totalPages = 1;
  bool hasMore = true;
  bool loadingMore = false;
  final ScrollController _scrollController = ScrollController();
    // ✅ متغيرات الـ Summary Carousel
  int _currentSummaryPage = 0;
  final PageController _summaryPageController = PageController(viewportFraction: 0.93);
  String searchQuery = '';

  int? selectedStageId;
  int? selectedSourceId;
  int? selectedAdTypeId;
  int? selectedEmployeeId;
  String? selectedFollowUpStatus;
  String? sortBy;
  
  // ✅ فلتر التاريخ
  DateTime? dateFrom;
  DateTime? dateTo;
  
  Timer? _debounceTimer;

  final TextEditingController _searchController = TextEditingController();

  int get _activeFiltersCount {
    int count = 0;
    if (selectedStageId != null) count++;
    if (selectedSourceId != null) count++;
    if (selectedAdTypeId != null) count++;
    if (selectedEmployeeId != null) count++;
    if (selectedFollowUpStatus != null) count++;
    if (searchQuery.isNotEmpty) count++;
    if (sortBy != null) count++;
    if (dateFrom != null) count++;
    if (dateTo != null) count++;
    return count;
  }

@override
void initState() {
  super.initState();
  _loadData();
  
  // ✅ Listener للـ Scroll
  _scrollController.addListener(() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreOpportunities();
    }
  });
}
// ===================================
// 🖨️ دوال التصدير والطباعة (تم التعديل لجلب الداتا من السيرفر)
// ===================================

/// ✅ دالة جديدة: تجلب كل البيانات من السيرفر حسب الفلاتر الحالية
Future<List<dynamic>> _fetchAllDataForReport() async {
  try {
    // نجهز الرابط بنفس الفلاتر المستخدمة في الشاشة
    String url = '$baseUrl/api/opportunities?limit=10000'; // رقم كبير لجلب الكل

    if (searchQuery.isNotEmpty) url += '&search=$searchQuery';
    if (selectedStageId != null) url += '&stageId=$selectedStageId';
    if (selectedSourceId != null) url += '&sourceId=$selectedSourceId';
    if (selectedAdTypeId != null) url += '&adTypeId=$selectedAdTypeId';
    if (selectedEmployeeId != null) url += '&employeeId=$selectedEmployeeId';
    if (selectedFollowUpStatus != null) url += '&followUpStatus=$selectedFollowUpStatus';
    if (sortBy != null) url += '&sortBy=$sortBy';
    if (dateFrom != null) url += '&dateFrom=${_formatDateForApi(dateFrom!)}';
    if (dateTo != null) url += '&dateTo=${_formatDateForApi(dateTo!)}';

    final res = await http.get(Uri.parse(url), headers: SessionService.instance.authHeaders);

    if (res.statusCode == 200) {
      final responseData = jsonDecode(res.body);
      // تأكد أن الاستجابة تحتوي على Data list
      return responseData['data'] ?? [];
    } else {
      debugPrint('Error fetching report data: ${res.statusCode}');
      return [];
    }
  } catch (e) {
    debugPrint('Exception in report fetch: $e');
    return [];
  }
}

Future<void> _exportToExcel() async {
  try {
    _showSnackBar('جاري تحضير ملف Excel...', Colors.blue);
    
    // 1️⃣ جلب البيانات من السيرفر
    final data = await _fetchAllDataForReport();
    
    if (data.isEmpty) {
      _showSnackBar('لا توجد بيانات للتصدير', Colors.orange);
      return;
    }

    var excelFile = excel.Excel.createExcel();
    excel.Sheet sheetObject = excelFile['الفرص'];

    // إضافة العناوين
    sheetObject.appendRow([
      excel.TextCellValue('العميل'),
      excel.TextCellValue('الهاتف'),
      excel.TextCellValue('المرحلة'),
      excel.TextCellValue('المصدر'),
      excel.TextCellValue('الحملة'),
      excel.TextCellValue('الموظف'),
      excel.TextCellValue('القيمة'),
      excel.TextCellValue('أول تواصل'),
      excel.TextCellValue('آخر تواصل'),
      excel.TextCellValue('عدد التواصلات'),
      excel.TextCellValue('حالة المتابعة'),
      excel.TextCellValue('المنتج المهتم به'),
    ]);

    for (var opp in data) {
      sheetObject.appendRow([
        excel.TextCellValue(opp['ClientName'] ?? ''),
        excel.TextCellValue(opp['Phone1'] ?? ''),
        excel.TextCellValue(opp['StageNameAr'] ?? opp['StageName'] ?? ''),
        excel.TextCellValue(opp['SourceNameAr'] ?? opp['SourceName'] ?? ''),
        excel.TextCellValue(opp['AdTypeName'] ?? ''),
        excel.TextCellValue(opp['EmployeeName'] ?? ''),
        excel.TextCellValue(_formatCurrency(opp['ExpectedValue'] ?? 0)),
        excel.TextCellValue(_formatDateShort(opp['FirstContactDate'])),
        excel.TextCellValue(_formatDateShort(opp['LastContactDate'])),
        excel.TextCellValue('${opp['InteractionCount'] ?? 0}'),
        excel.TextCellValue(_getFollowUpStatusText(opp['FollowUpStatus'])),
        excel.TextCellValue(opp['InterestedProduct'] ?? ''),
      ]);
    }

    var fileBytes = excelFile.save();
    if (fileBytes == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'opportunities_report_$timestamp.xlsx';
    final file = File('${directory.path}/$fileName');
    
    await file.writeAsBytes(fileBytes);
    
    await Share.shareXFiles([XFile(file.path)], 
        text: 'تقرير الفرص - ${_getDateRangeForReport()}');
    
    _showSnackBar('تم تصدير الملف بنجاح', Colors.green);
  } catch (e) {
    _showSnackBar('حدث خطأ أثناء التصدير: $e', Colors.red);
  }
}

Future<void> _exportToPDF() async {
  try {
    _showSnackBar('جاري تحضير ملف PDF...', Colors.blue);

    final data = await _fetchAllDataForReport();

    if (data.isEmpty) {
      _showSnackBar('لا توجد بيانات للتصدير', Colors.orange);
      return;
    }

    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    // 1️⃣ عكسنا ترتيب البيانات (المنتج في الأول -> العميل في الآخر)
    final List<List<String>> tableData = data.map((item) {
      return <String>[
        (item['InterestedProduct'] ?? '').toString(),      // 0. المنتج (يسار الصفحة)
        _getFollowUpStatusText(item['FollowUpStatus']),    // 1. المتابعة
        '${item['InteractionCount'] ?? 0}',                // 2. العدد
        _formatDateShort(item['LastContactDate']),         // 3. آخر تواصل
        _formatDateShort(item['FirstContactDate']),        // 4. أول تواصل
        _formatCurrency(item['ExpectedValue'] ?? 0),       // 5. القيمة
        (item['EmployeeName'] ?? '').toString(),           // 6. الموظف
        (item['AdTypeName'] ?? '').toString(),             // 7. الحملة
        (item['SourceNameAr'] ?? item['SourceName'] ?? '').toString(), // 8. المصدر
        (item['StageNameAr'] ?? item['StageName'] ?? '').toString(),   // 9. المرحلة
        (item['Phone1'] ?? '').toString(),                 // 10. الهاتف
        (item['ClientName'] ?? '').toString(),             // 11. العميل (يمين الصفحة)
      ];
    }).toList();

    // 2️⃣ عكسنا ترتيب العناوين ليطابق البيانات
    const headers = [
      'المنتج',
      'المتابعة',
      'العدد',
      'آخر تواصل',
      'أول تواصل',
      'القيمة',
      'الموظف',
      'الحملة',
      'المصدر',
      'المرحلة',
      'الهاتف',
      'العميل'
    ];

    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(10),
        theme: pw.ThemeData.withFont(base: ttf),
        textDirection: pw.TextDirection.rtl, // اتجاه الصفحة ككل

        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'تقرير فرص البيع',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: ttf),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.Text(
                    _getDateRangeForReport(),
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, font: ttf),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'COCOBOLO FURNITURE',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.amber700, font: ttf),
                    textDirection: pw.TextDirection.rtl,
                  ),
                  pw.Text(
                    DateFormat('yyyy/MM/dd - HH:mm').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),

        build: (context) => [
          pw.Table.fromTextArray(
            context: context,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headers: headers,
            data: tableData,
            
            // ✅ عكسنا توزيع المساحات (رقم 0 هو المنتج، رقم 11 هو العميل)
            columnWidths: {
              0: const pw.FlexColumnWidth(2.0), // المنتج
              1: const pw.FlexColumnWidth(1.5), // المتابعة
              2: const pw.FlexColumnWidth(0.8), // العدد
              3: const pw.FlexColumnWidth(1.3), // آخر تواصل
              4: const pw.FlexColumnWidth(1.3), // أول تواصل
              5: const pw.FlexColumnWidth(1.4), // القيمة
              6: const pw.FlexColumnWidth(1.8), // الموظف
              7: const pw.FlexColumnWidth(1.5), // الحملة
              8: const pw.FlexColumnWidth(1.5), // المصدر
              9: const pw.FlexColumnWidth(1.5), // المرحلة
              10: const pw.FlexColumnWidth(1.8), // الهاتف
              11: const pw.FlexColumnWidth(2.5), // العميل (أعرض واحد)
            },

            headerStyle: pw.TextStyle(
              font: ttf, 
              fontSize: 9, 
              fontWeight: pw.FontWeight.bold, 
              color: PdfColors.white
            ),
            cellStyle: pw.TextStyle(font: ttf, fontSize: 7),
            headerAlignment: pw.Alignment.center,
            cellAlignment: pw.Alignment.center,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
        ],

        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: pw.TextStyle(color: PdfColors.grey, fontSize: 8, font: ttf),
            textDirection: pw.TextDirection.rtl,
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'opportunities_report.pdf',
    );
    
  } catch (e) {
    _showSnackBar('حدث خطأ: $e', Colors.red);
  }
}


Future<void> _printReport() async {
  try {
    _showSnackBar('جاري تحضير الطباعة...', Colors.blue);
    
    // 1️⃣ جلب البيانات من السيرفر
    final data = await _fetchAllDataForReport();
    
    if (data.isEmpty) {
      _showSnackBar('لا توجد بيانات للطباعة', Colors.orange);
      return;
    }

    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Center(
             child: pw.Text('تقرير الفرص', 
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: ttf), textDirection: pw.TextDirection.rtl),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
               pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('العميل', ttf, isHeader: true),
                  _buildTableCell('الهاتف', ttf, isHeader: true),
                  _buildTableCell('المرحلة', ttf, isHeader: true),
                  _buildTableCell('آخر تواصل', ttf, isHeader: true),
                ],
              ),
              ...data.map((opp) => pw.TableRow(
                children: [
                   _buildTableCell(opp['ClientName'] ?? '', ttf),
                   _buildTableCell(opp['Phone1'] ?? '', ttf),
                   _buildTableCell(opp['StageNameAr'] ?? opp['StageName'] ?? '', ttf),
                   _buildTableCell(_formatDaysAgo(opp['LastContactDate']), ttf),
                ]
              )).toList(),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'opportunities_report.pdf',
    );
    
  } catch (e) {
    _showSnackBar('حدث خطأ أثناء الطباعة: $e', Colors.red);
  }
}

// ===================================
// 🔧 دوال مساعدة للـ PDF (توضع مرة واحدة فقط في نهاية الكلاس)
// ===================================

// ✅ دالة بناء الخلية (معدلة لتناسب الـ 12 عمود)
pw.Widget _buildTableCell(String text, pw.Font font, {bool isHeader = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
    alignment: pw.Alignment.center, // توسيط المحتوى
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: font,
        fontSize: isHeader ? 8 : 7, // خط صغير عشان يكفي الصفحة
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: isHeader ? PdfColors.black : PdfColors.grey800,
      ),
      textDirection: pw.TextDirection.rtl,
      textAlign: pw.TextAlign.center,
      maxLines: 2, // لو النص طويل ينزل سطر
    ),
  );
}

// ✅ دالة الإحصائيات (لو لسه بتستخدمها في مكان تاني)
pw.Widget _buildPdfStat(String label, String value, pw.Font font) {
  return pw.Column(
    children: [
      pw.Text(
        value, 
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font, fontSize: 12),
        textDirection: pw.TextDirection.rtl,
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        label, 
        style: pw.TextStyle(color: PdfColors.grey, font: font, fontSize: 8),
        textDirection: pw.TextDirection.rtl,
      ),
    ],
  );
}
@override
void dispose() {
  _searchController.dispose();
  _debounceTimer?.cancel();
  _scrollController.dispose();
  super.dispose();
}

  Future<void> _loadData() async {
    setState(() => loading = true);
    await Future.wait([
      _fetchStages(),
      _fetchSources(),
      _fetchAdTypes(),
      _fetchEmployees(),
      _fetchSummary(),
      _fetchOpportunities(),
    ]);
    setState(() => loading = false);
  }

  Future<void> _fetchStages() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/stages'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        setState(() => stages = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching stages: $e');
    }
  }

  Future<void> _fetchSources() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/sources'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        setState(() => sources = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching sources: $e');
    }
  }

  Future<void> _fetchAdTypes() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/ad-types'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        setState(() => adTypes = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching ad types: $e');
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/employees'), headers: SessionService.instance.authHeaders);
      if (res.statusCode == 200) {
        setState(() => employees = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
    }
  }

  Future<void> _fetchSummary() async {
  try {
    String url = '$baseUrl/api/opportunities/summary?username=${widget.username}';
    if (selectedEmployeeId != null) url += '&employeeId=$selectedEmployeeId';
    if (selectedSourceId != null) url += '&sourceId=$selectedSourceId';
    if (selectedAdTypeId != null) url += '&adTypeId=$selectedAdTypeId';
    if (selectedStageId != null) url += '&stageId=$selectedStageId';
    if (dateFrom != null) url += '&dateFrom=${_formatDateForApi(dateFrom!)}';
    if (dateTo != null) url += '&dateTo=${_formatDateForApi(dateTo!)}';

    debugPrint('📊 Summary URL: $url'); // ✅ للتأكد

    final res = await http.get(Uri.parse(url), headers: SessionService.instance.authHeaders);
    if (res.statusCode == 200) {
      setState(() => summary = jsonDecode(res.body));
    }
  } catch (e) {
    debugPrint('Error fetching summary: $e');
  }
}

Future<void> _fetchOpportunities({bool reset = true}) async {
  try {
    if (reset) {
      currentPage = 1;
      hasMore = true;
    }

    String url = '$baseUrl/api/opportunities?page=$currentPage&limit=30';

    if (searchQuery.isNotEmpty) url += '&search=$searchQuery';
    if (selectedStageId != null) url += '&stageId=$selectedStageId';
    if (selectedSourceId != null) url += '&sourceId=$selectedSourceId';
    if (selectedAdTypeId != null) url += '&adTypeId=$selectedAdTypeId';
    if (selectedEmployeeId != null) url += '&employeeId=$selectedEmployeeId';
    if (selectedFollowUpStatus != null) url += '&followUpStatus=$selectedFollowUpStatus';
    if (sortBy != null) url += '&sortBy=$sortBy';
    if (dateFrom != null) url += '&dateFrom=${_formatDateForApi(dateFrom!)}';
    if (dateTo != null) url += '&dateTo=${_formatDateForApi(dateTo!)}';

    final res = await http.get(Uri.parse(url), headers: SessionService.instance.authHeaders);

    if (res.statusCode == 200) {
      final responseData = jsonDecode(res.body);
      
      setState(() {
        if (reset) {
          opportunities = responseData['data'];
        } else {
          opportunities.addAll(responseData['data']);
        }
        
        currentPage = responseData['pagination']['page'];
        totalPages = responseData['pagination']['totalPages'];
        hasMore = responseData['pagination']['hasMore'];
      });
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

List<Map<String, dynamic>> _prepareReportData() {
  // بنفس الفلاتر المستخدمة في الشاشة
  var filteredData = opportunities.where((opp) {
    // فلتر البحث في الاسم أو الهاتف
    if (searchQuery.isNotEmpty) {
      final name = (opp['ClientName'] ?? '').toString().toLowerCase();
      final phone = (opp['Phone1'] ?? '').toString().toLowerCase();
      if (!name.contains(searchQuery.toLowerCase()) && 
          !phone.contains(searchQuery.toLowerCase())) {
        return false;
      }
    }
    
    // فلتر المرحلة
    if (selectedStageId != null && opp['StageID'] != selectedStageId) {
      return false;
    }
    
    // فلتر المصدر
    if (selectedSourceId != null && opp['SourceID'] != selectedSourceId) {
      return false;
    }
    
    // فلتر الحملة
    if (selectedAdTypeId != null && opp['AdTypeID'] != selectedAdTypeId) {
      return false;
    }
    
    // فلتر الموظف
    if (selectedEmployeeId != null && opp['EmployeeID'] != selectedEmployeeId) {
      return false;
    }
    
    // فلتر حالة المتابعة
    if (selectedFollowUpStatus != null && opp['FollowUpStatus'] != selectedFollowUpStatus) {
      return false;
    }
    
    // فلتر التاريخ
    if (dateFrom != null) {
      final createdAt = opp['CreatedAt'] != null 
          ? DateTime.parse(opp['CreatedAt']) 
          : null;
      if (createdAt != null && createdAt.isBefore(dateFrom!)) {
        return false;
      }
    }
    if (dateTo != null) {
      final createdAt = opp['CreatedAt'] != null 
          ? DateTime.parse(opp['CreatedAt']) 
          : null;
      if (createdAt != null && createdAt.isAfter(dateTo!)) {
        return false;
      }
    }
    
    return true;
  }).toList();

  return filteredData.cast<Map<String, dynamic>>();
}

Future<void> _loadMoreOpportunities() async {
  if (loadingMore || !hasMore) return;

  setState(() => loadingMore = true);

  currentPage++;
  await _fetchOpportunities(reset: false);

  setState(() => loadingMore = false);
}

  Color _getStageColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return AppColors.neutral;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.neutral;
    }
  }

  Color _getFollowUpStatusColor(String? status) {
    switch (status) {
      case 'Overdue':
        return AppColors.error;
      case 'Today':
        return AppColors.warning;
      case 'Tomorrow':
        return AppColors.info;
      case 'Upcoming':
        return AppColors.success;
      default:
        return AppColors.neutral;
    }
  }

  String _getFollowUpStatusText(String? status) {
    switch (status) {
      case 'Overdue':
        return 'متأخر';
      case 'Today':
        return 'اليوم';
      case 'Tomorrow':
        return 'غداً';
      case 'Upcoming':
        return 'قادم';
      case 'NotSet':
        return 'غير محدد';
      default:
        return '';
    }
  }

  Widget _getSourceIcon(String? sourceName, {double size = 18}) {
    final name = sourceName?.toLowerCase() ?? '';

    if (name.contains('whatsapp') || name.contains('واتساب')) {
      return FaFaIcon(FontAwesomeIcons.whatsapp, size: size, color: AppColors.whatsapp);
    } else if (name.contains('facebook') || name.contains('فيسبوك')) {
      return FaFaIcon(FontAwesomeIcons.facebook, size: size, color: AppColors.info);
    } else if (name.contains('instagram') || name.contains('انستجرام')) {
      return FaFaIcon(FontAwesomeIcons.instagram, size: size, color: const Color(0xFFE4405F));
    } else if (name.contains('tiktok') || name.contains('تيك توك')) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: FaFaIcon(FontAwesomeIcons.tiktok, size: size - 6, color: Colors.black),
      );
    } else if (name.contains('phone') || name.contains('مكالمة') || name.contains('تليفون')) {
      return FaFaIcon(FontAwesomeIcons.phoneVolume, size: size, color: AppColors.success);
    } else if (name.contains('showroom') || name.contains('معرض') || name.contains('زيارة')) {
      return FaFaIcon(FontAwesomeIcons.store, size: size, color: AppStatus.editPending);
    } else if (name.contains('referral') || name.contains('توصية')) {
      return FaFaIcon(FontAwesomeIcons.userGroup, size: size, color: AppColors.info);
    } else if (name.contains('google') || name.contains('جوجل')) {
      return FaFaIcon(FontAwesomeIcons.google, size: size, color: AppColors.info);
    } else {
      return FaFaIcon(FontAwesomeIcons.globe, size: size, color: AppColors.neutral);
    }
  }

  Widget _getStageIconWidget(int? stageId, Color color, {double size = 14}) {
    FaIconData iconData;
    switch (stageId) {
      case 1:
        iconData = FontAwesomeIcons.userPlus;
        break;
      case 2:
        iconData = FontAwesomeIcons.fire;
        break;
      case 3:
        iconData = FontAwesomeIcons.circleCheck;
        break;
      case 4:
        iconData = FontAwesomeIcons.circleXmark;
        break;
      case 5:
        iconData = FontAwesomeIcons.ban;
        break;
      default:
        iconData = FontAwesomeIcons.circle;
    }
    return FaIcon(iconData, size: size, color: color);
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar('لا يوجد رقم هاتف', Colors.red);
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar('لا يوجد رقم هاتف', Colors.red);
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.startsWith('00')) {
      cleanPhone = cleanPhone.substring(2);
    } else if (cleanPhone.startsWith('0')) {
      cleanPhone = '20${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 10 && !cleanPhone.startsWith('20')) {
      cleanPhone = '20$cleanPhone';
    }

    final waUrl = 'https://wa.me/$cleanPhone';

    try {
      final uri = Uri.parse(waUrl);
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched) {
        final waUri = Uri.parse('whatsapp://send?phone=$cleanPhone');
        launched = await launchUrl(waUri);

        if (!launched) {
          _showSnackBar('لم يتم العثور على واتساب', Colors.orange);
        }
      }
    } catch (e) {
      debugPrint('❌ WhatsApp Error: $e');
      _showSnackBar('حدث خطأ: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.sm)),
      ),
    );
  }
  
  // حساب عدد الأيام من تاريخ معين
String _formatDaysAgo(String? dateStr) {
  if (dateStr == null) return 'لا يوجد';
  try {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) return 'اليوم';
    if (difference == 1) return 'من يوم';
    if (difference == 2) return 'من يومين';
    if (difference <= 7) return 'من $difference أيام';
    if (difference <= 30) return 'من ${(difference / 7).floor()} أسابيع';
    return 'من ${(difference / 30).floor()} شهور';
  } catch (e) {
    return 'لا يوجد';
  }
}

// تنسيق التاريخ
String _formatDateShort(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year}';
  } catch (e) {
    return '';
  }
}

String _getDateRangeForReport() {
  if (dateFrom != null && dateTo != null) {
    return 'من ${_formatDate(dateFrom!)} إلى ${_formatDate(dateTo!)}';
  } else if (dateFrom != null) {
    return 'من ${_formatDate(dateFrom!)}';
  } else if (dateTo != null) {
    return 'إلى ${_formatDate(dateTo!)}';
  } else {
    return 'كل الفترات';
  }
}

String _getFormattedDate() {
  final now = DateTime.now();
  const days = [
    'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
    'الجمعة', 'السبت', 'الأحد',
  ];
  const months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  return '${days[now.weekday - 1]}، ${now.day} ${months[now.month - 1]}';
}

// التحقق إذا كانت الفرصة جديدة (أقل من 3 أيام)
bool _isNewOpportunity(String? createdAt) {
  if (createdAt == null) return false;
  try {
    final date = DateTime.parse(createdAt);
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
      return difference <= 3;
    } catch (e) {
      return false;
    }
  }
  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0 ج.م';
    final num = double.tryParse(amount.toString()) ?? 0;
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M ج.م';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K ج.م';
    }
    return '${num.toInt()} ج.م';
  }

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

// ✅ جديد - للـ API
String _formatDateForApi(DateTime date) {
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

  // ✅ اختيار التاريخ
// ✅ اختيار التاريخ - النسخة المصححة
Future<void> _selectDate(BuildContext context, bool isFromDate, StateSetter setModalState) async {
  final DateTime initialDate = isFromDate 
      ? (dateFrom ?? DateTime.now()) 
      : (dateTo ?? DateTime.now());
  
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.gold,
            onPrimary: AppColors.navy,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gold,
            ),
          ),
        ),
        child: child!,
      );
    },
  );

  if (picked != null) {
    setModalState(() {
      if (isFromDate) {
        dateFrom = picked;
        if (dateTo != null && dateFrom!.isAfter(dateTo!)) {
          dateTo = dateFrom;
        }
      } else {
        dateTo = picked;
        if (dateFrom != null && dateTo!.isBefore(dateFrom!)) {
          dateFrom = dateTo;
        }
      }
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frmManamgerSales'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: loading
          ? const AppLoading(message: 'جاري تحميل الفرص...')
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.gold,
              child: CustomScrollView(
                controller: _scrollController, 
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildSummaryCards()),
                  SliverToBoxAdapter(child: _buildSearchAndSort()),
                  // ✅ عرض الفلاتر النشطة
                  if (_activeFiltersCount > 0)
                    SliverToBoxAdapter(child: _buildActiveFiltersBar()),
                  SliverToBoxAdapter(child: _buildStageFilter()),
                  opportunities.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildOpportunityCard(opportunities[index], index),
                            childCount: opportunities.length,
                          ),
                        ),
                        // ✅ Loading Indicator للـ Pagination
if (loadingMore)
  const SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    ),
  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ✅ شريط الفلاتر النشطة
  Widget _buildActiveFiltersBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (dateFrom != null || dateTo != null)
              _buildActiveFilterChip(
                '${dateFrom != null ? _formatDate(dateFrom!) : '...'} - ${dateTo != null ? _formatDate(dateTo!) : '...'}',
                FontAwesomeIcons.calendar,
                AppColors.info,
                () {
                  setState(() {
                    dateFrom = null;
                    dateTo = null;
                  });
                  _fetchOpportunities();
                  _fetchSummary();
                },
              ),
            if (selectedEmployeeId != null)
              _buildActiveFilterChip(
                employees.firstWhere((e) => e['EmployeeID'] == selectedEmployeeId, orElse: () => {'FullName': ''})['FullName'] ?? '',
                FontAwesomeIcons.userTie,
                AppColors.warning,
                () {
                  setState(() => selectedEmployeeId = null);
                  _fetchOpportunities();
                  _fetchSummary();
                },
              ),
            if (selectedAdTypeId != null)
              _buildActiveFilterChip(
                adTypes.firstWhere((a) => a['AdTypeID'] == selectedAdTypeId, orElse: () => {'AdTypeName': ''})['AdTypeName'] ?? '',
                FontAwesomeIcons.bullhorn,
                AppStatus.editPending,
                () {
                  setState(() => selectedAdTypeId = null);
                  _fetchOpportunities();
                  _fetchSummary();
                },
              ),
            if (selectedFollowUpStatus != null)
              _buildActiveFilterChip(
                _getFollowUpStatusText(selectedFollowUpStatus),
                FontAwesomeIcons.clock,
                _getFollowUpStatusColor(selectedFollowUpStatus),
                () {
                  setState(() => selectedFollowUpStatus = null);
                  _fetchOpportunities();
                },
              ),
            if (selectedSourceId != null)
              _buildActiveFilterChip(
                sources.firstWhere((s) => s['SourceID'] == selectedSourceId, orElse: () => {'SourceNameAr': ''})['SourceNameAr'] ?? '',
                FontAwesomeIcons.shareNodes,
                AppColors.success,
                () {
                  setState(() => selectedSourceId = null);
                  _fetchOpportunities();
                  _fetchSummary();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, dynamic icon, Color color, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.all(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          compatIcon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return const AppLoading(message: 'جاري تحميل الفرص...');
  }

  PreferredSizeWidget _buildAppBar() {
  final perms = PermissionService();
  final canViewClosure =
      perms.isAdmin || perms.isSalesManager || perms.isGeneralManager;
  final canViewRecovery = perms.canViewLostRecovery;
  final canViewGeneralTasks = perms.isAdmin ||
      perms.isGeneralManager ||
      perms.isAccountManager ||
      perms.canView(FormNames.generalTasks);
  return AppBar(
    backgroundColor: AppColors.navy,
    foregroundColor: Colors.white,
    elevation: 0,
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.lightbulb_rounded, color: AppColors.gold, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'فرص البيع',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                _getFormattedDate(),
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    centerTitle: false,
    leading: const AppDrawerMenuButton(),
    actions: [
      if (canViewGeneralTasks)
        IconButton(
          tooltip: 'التكليفات العامة',
          icon: const Icon(
            Icons.assignment_turned_in_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GeneralTasksScreen(
                  userId: widget.userId,
                  username: widget.username,
                ),
              ),
            );
          },
        ),
      // زر استرداد الفرص الخاسرة
      if (canViewRecovery)
        IconButton(
          tooltip: 'استرداد الفرص الخاسرة',
          icon: const Icon(Icons.restart_alt_rounded, color: AppColors.info),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => LostRecoveryScreen(userId: widget.userId, username: widget.username)));
          },
        ),
      // 🛑 زر طلبات موافقة الإغلاق - يظهر للـ GM/SalesManager/Admin فقط
      if (canViewClosure)
        IconButton(
          tooltip: 'طلبات موافقة الإغلاق',
          icon: Stack(children: [
            const Icon(Icons.admin_panel_settings_rounded, color: AppColors.warning),
            Positioned(top: 0, right: 0, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle))),
          ]),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ClosureApprovalRequestsScreen(userId: widget.userId, username: widget.username)));
          },
        ),
      // ✅ زر التقرير الجديد
      PopupMenuButton<String>(
        icon: const FaFaIcon(FontAwesomeIcons.fileExport, color: Colors.white, size: 18),
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          switch (value) {
            case 'excel':
              _exportToExcel();
              break;
            case 'pdf':
              _exportToPDF();
              break;
            case 'print':
              _printReport();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'excel',
            child: Row(
              children: [
                FaFaIcon(FontAwesomeIcons.fileExcel, color: AppColors.success, size: 16),
                const SizedBox(width: 10),
                Text('تصدير Excel', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'pdf',
            child: Row(
              children: [
                FaFaIcon(FontAwesomeIcons.filePdf, color: AppColors.error, size: 16),
                const SizedBox(width: 10),
                Text('تصدير PDF', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'print',
            child: Row(
              children: [
                FaFaIcon(FontAwesomeIcons.print, color: AppColors.info, size: 16),
                const SizedBox(width: 10),
                Text('طباعة', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(width: 8),
      
      // ✅ الفلتر الموجود (زي ما هو)
      Stack(
        children: [
          IconButton(
            icon: const FaFaIcon(FontAwesomeIcons.filter, color: Colors.white, size: 18),
            onPressed: _showFilterBottomSheet,
          ),
          if (_activeFiltersCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$_activeFiltersCount',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

// ===================================
// 🎠 Summary Carousel
// ===================================
// ===================================
// 🎠 Summary Carousel (New Design)
// ===================================

Widget _buildSummaryCards() {
  if (summary.isEmpty) return const SizedBox.shrink();
  final stats = summary['stats'] ?? {};
  final topSources = summary['topSources'] as List? ?? [];
  final topCampaigns = summary['topCampaigns'] as List? ?? [];
  
  return Column(
    children: [
      SizedBox(
        height: 200, // ✅ زودنا الارتفاع لـ 200
        child: PageView(
          controller: _summaryPageController,
          onPageChanged: (index) => setState(() => _currentSummaryPage = index),
          children: [
            // 1️⃣ نظرة عامة (الذهب والأسود)
            _buildArtisticCard(
              title: 'نظرة عامة',
              icon: FontAwesomeIcons.chartPie,
              gradientColors: AppGradients.identityHeader,
              accentColor: AppColors.gold,
              content: Column(
                children: [
                  _buildRow('الكل', '${stats['totalOpportunities'] ?? 0}'),
                  _buildRow('جدد هذا الشهر', '${stats['newThisMonth'] ?? 0}'),
                  const Divider(color: Colors.white24),
                  _buildRow('القيمة المتوقعة', _formatCurrency(stats['totalExpectedValue']), isValueBold: true, valueColor: AppColors.gold),
                ],
              ),
            ),

           // 2️⃣ المتابعة والاهتمام
_buildArtisticCard(
  title: 'المتابعة والاهتمام',
  icon: FontAwesomeIcons.listCheck,
  gradientColors: [AppColors.navyDark, AppColors.navyLight],
  accentColor: AppColors.info,
  content: Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('محتمل (Lead)', '${stats['leadCount'] ?? 0}', Colors.white), // ✅ أضفنا ده
          _buildMiniStat('مهتم', '${stats['potentialCount'] ?? 0}', AppColors.warning),
          _buildMiniStat('عالي الاهتمام', '${stats['highInterestCount'] ?? 0}', AppStatus.overdue),
        ],
      ),
      const SizedBox(height: 12),
      const Divider(color: Colors.white10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('اليوم', '${stats['todayCount'] ?? 0}', AppColors.success),
          _buildMiniStat('متأخرة', '${stats['overdueCount'] ?? 0}', AppColors.error),
        ],
      ),
    ],
  ),
),

            // 3️⃣ المصادر (البنفسجي والأسود)
            _buildArtisticCard(
              title: 'أهم المصادر',
              icon: FontAwesomeIcons.shareNodes,
              gradientColors: [AppColors.navy, AppColors.info],
              accentColor: Colors.white,
              content: Column(
                children: [
                  if (topSources.isEmpty)
                    const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey)))
                  else
                    ...topSources.take(3).map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          FaIcon(_getSourceIconData(s['name']), color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(s['name'] ?? '', style: GoogleFonts.cairo(color: Colors.white, fontSize: 12)),
                          const Spacer(),
                          Text('${s['count']}', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                ],
              ),
            ),

            // 4️⃣ الأداء (الأخضر والأسود)
            _buildArtisticCard(
              title: 'الأداء والتحويل',
              icon: FontAwesomeIcons.trophy,
              gradientColors: [AppColors.navyDark, AppColors.success],
              accentColor: AppColors.success,
              content: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('مكسبة', '${stats['wonCount'] ?? 0}', Colors.white),
                      _buildMiniStat('خسارة', '${stats['lostCount'] ?? 0}', Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildWinRateBar(stats['wonCount'] ?? 0, (stats['wonCount'] ?? 0) + (stats['lostCount'] ?? 0)),
                ],
              ),
            ),
            // 5️⃣ كارت الحملات الإعلانية
_buildArtisticCard(
  title: 'أهم الحملات',
  icon: FontAwesomeIcons.bullhorn,
  gradientColors: [AppColors.info, AppStatus.editPending],
  accentColor: Colors.white,
  content: Column(
    children: [
      if (topCampaigns.isEmpty)
        const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey)))
      else
        ...topCampaigns.take(3).map((c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const FaFaIcon(FontAwesomeIcons.rectangleAd, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(c['name'] ?? '', style: GoogleFonts.cairo(color: Colors.white, fontSize: 12)),
              const Spacer(),
              Text('${c['count']}', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        )),
    ],
  ),
),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // المؤشر (Dots)
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) => AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), height: 6, width: _currentSummaryPage == index ? 24 : 6, decoration: BoxDecoration(color: _currentSummaryPage == index ? AppColors.gold : Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(3)))),
      ),
      const SizedBox(height: 20),
    ],
  );
}

// 🔧 دوال التصميم الجديدة

Widget _buildArtisticCard({
  required String title,
  required dynamic icon,
  required List<Color> gradientColors,
  required Color accentColor,
  required Widget content,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: AppRadius.all(AppRadius.sm)),
              child: compatIcon(icon, size: 14, color: accentColor),
            ),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.cairo(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: content),
      ],
    ),
  );
}
  

Widget _buildRow(String label, String value, {bool isValueBold = false, Color valueColor = Colors.white}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
        if (isValueBold)
          AmountText(value: value, size: 15, color: valueColor)
        else
          Text(value, style: GoogleFonts.cairo(color: valueColor, fontSize: 15, fontWeight: FontWeight.normal)),
      ],
    ),
  );
}

Widget _buildMiniStat(String label, String value, Color color) {
  return Column(
    children: [
      Text(value, style: GoogleFonts.cairo(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11)),
    ],
  );
}

// 🔧 الدوال المساعدة للكروت

Widget _buildSummaryCard({
  required String title,
  required dynamic icon,
  required Gradient gradient,
  required Color borderColor,
  required List<Widget> children,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      border: Border.all(color: borderColor.withValues(alpha: 0.3), width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: borderColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: compatIcon(icon, size: 14, color: borderColor),
            ),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

Widget _buildSummaryRow(String label, String value, dynamic icon, Color color, {bool isBold = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        compatIcon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        Text(value, style: GoogleFonts.cairo(color: isBold ? color : Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

Widget _buildSummaryItem(String label, String value, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: GoogleFonts.cairo(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: GoogleFonts.cairo(color: color, fontSize: 12)),
    ],
  );
}

Widget _buildWinRateBar(int won, int total) {
  double rate = total == 0 ? 0 : (won / total);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('نسبة النجاح', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
          Text('${(rate * 100).toStringAsFixed(1)}%', style: GoogleFonts.cairo(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
      const SizedBox(height: 8),
      Stack(
        children: [
          Container(height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4))),
          FractionallySizedBox(widthFactor: rate, child: Container(height: 8, decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(4)))),
        ],
      ),
    ],
  );
}

// 🔧 دالة لجلب أيقونة المصدر
FaIconData _getSourceIconData(String? sourceName) {
  final name = (sourceName ?? '').toLowerCase();
  if (name.contains('whatsapp') || name.contains('واتساب')) return FontAwesomeIcons.whatsapp;
  if (name.contains('facebook') || name.contains('فيسبوك')) return FontAwesomeIcons.facebook;
  if (name.contains('instagram') || name.contains('انستجرام')) return FontAwesomeIcons.instagram;
  if (name.contains('tiktok') || name.contains('تيك توك')) return FontAwesomeIcons.tiktok;
  if (name.contains('phone') || name.contains('هاتف') || name.contains('تليفون')) return FontAwesomeIcons.phone;
  if (name.contains('google') || name.contains('جوجل')) return FontAwesomeIcons.google;
  return FontAwesomeIcons.shareNodes;
}

  Widget _buildMiniSummaryCard(String label, String value, Color color, dynamic icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          compatIcon(icon, color: color, size: 14),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الهاتف...',
                hintStyle: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search, color: AppColors.neutral),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.neutral),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => searchQuery = '');
                          _fetchOpportunities();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.all(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
              ),
              onChanged: (value) {
                setState(() => searchQuery = value);
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                  _fetchOpportunities();
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: sortBy != null
                  ? AppColors.gold.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: AppRadius.all(AppRadius.sm),
              border: sortBy != null
                  ? Border.all(color: AppColors.gold.withValues(alpha: 0.5))
                  : Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: IconButton(
              icon: FaIcon(
                FontAwesomeIcons.arrowDownWideShort,
                color: sortBy != null ? AppColors.gold : AppColors.neutral,
                size: 18,
              ),
              onPressed: _showSortBottomSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageFilter() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStageChip(null, 'الكل', AppColors.gold, null),
            ...stages.map((stage) => _buildStageChip(
                  stage['StageID'],
                  stage['StageNameAr'] ?? stage['StageName'],
                  _getStageColor(stage['StageColor']),
                  stage['StageID'],
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildStageChip(int? stageId, String label, Color color, int? stageIdForIcon) {
    final isSelected = selectedStageId == stageId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: stageIdForIcon != null
            ? _getStageIconWidget(stageIdForIcon, isSelected ? AppColors.navy : color, size: 12)
            : null,
        label: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? AppColors.navy : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => selectedStageId = selected ? stageId : null);
          _fetchOpportunities();
        },
        backgroundColor: color.withValues(alpha: 0.12),
        selectedColor: color,
        checkmarkColor: AppColors.navy,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildOpportunityCard(dynamic opportunity, int index) {
    final theme = Theme.of(context);
    final stageColor = _getStageColor(opportunity['StageColor']);
    final followUpStatus = opportunity['FollowUpStatus'];
    final followUpColor = _getFollowUpStatusColor(followUpStatus);
    final stageId = opportunity['StageID'];
    final hasValue = opportunity['ExpectedValue'] != null && opportunity['ExpectedValue'] > 0;

    return Dismissible(
      key: Key(opportunity['OpportunityID'].toString()),
      background: _buildSwipeBackground(AppColors.info, Icons.call_rounded, 'اتصال', Alignment.centerRight),
      secondaryBackground: _buildSwipeBackground(AppColors.whatsapp, FontAwesomeIcons.whatsapp, 'واتساب', Alignment.centerLeft),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _makePhoneCall(opportunity['Phone1']);
        } else {
          _openWhatsApp(opportunity['Phone1']);
        }
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
        child: AppCard(
          onTap: () => _openOpportunityDetails(opportunity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.12),
                      borderRadius: AppRadius.all(AppRadius.sm),
                    ),
                    child: _getStageIconWidget(stageId, stageColor, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                opportunity['ClientName'] ?? 'بدون اسم',
                                style: GoogleFonts.cairo(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isNewOpportunity(opportunity['CreatedAt'])) ...[
                              const SizedBox(width: 6),
                              StatusBadge(label: 'جديد', color: AppColors.success, small: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opportunity['StageNameAr'] ?? opportunity['StageName'] ?? '',
                          style: GoogleFonts.cairo(color: stageColor, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(
                    label: opportunity['Phone1'] ?? 'لا يوجد',
                    color: AppColors.neutral,
                    icon: Icons.phone_rounded,
                    small: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), height: 1),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoPill(
                      icon: FontAwesomeIcons.calendarPlus,
                      text: 'أول تواصل: ${_formatDateShort(opportunity['FirstContactDate'])}',
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildInfoPill(
                      icon: FontAwesomeIcons.clockRotateLeft,
                      text: 'آخر تواصل: ${_formatDaysAgo(opportunity['LastContactDate'])}',
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const FaFaIcon(FontAwesomeIcons.userTie, color: AppColors.gold, size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      opportunity['EmployeeName'] ?? 'غير محدد',
                      style: GoogleFonts.cairo(color: AppColors.gold, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(
                    label: '${opportunity['InteractionCount'] ?? 0}',
                    color: AppColors.info,
                    icon: Icons.forum_rounded,
                    small: true,
                  ),
                  if (followUpStatus != null && followUpStatus != 'NotSet') ...[
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge(
                      label: _getFollowUpStatusText(followUpStatus),
                      color: followUpColor,
                      icon: followUpStatus == 'Overdue' ? Icons.history_rounded : Icons.schedule_rounded,
                      small: true,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: AppRadius.all(AppRadius.xs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _getSourceIcon(opportunity['SourceName'], size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              opportunity['SourceNameAr'] ?? opportunity['SourceName'] ?? '',
                              style: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildInfoPill(
                      icon: FontAwesomeIcons.bullhorn,
                      text: opportunity['AdTypeName'] ?? 'بدون حملة',
                      color: AppStatus.editPending,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (hasValue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: AppRadius.all(AppRadius.xs),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaFaIcon(FontAwesomeIcons.coins, color: AppColors.success, size: 12),
                          const SizedBox(width: 6),
                          AmountText(
                            value: _formatCurrency(opportunity['ExpectedValue']),
                            size: 12,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  if (opportunity['InterestedProduct'] != null && opportunity['InterestedProduct'].toString().isNotEmpty) ...[
                    if (hasValue) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: AppRadius.all(AppRadius.xs),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaFaIcon(FontAwesomeIcons.box, color: theme.colorScheme.onSurfaceVariant, size: 12),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                opportunity['InterestedProduct'],
                                style: GoogleFonts.cairo(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'اتصال',
                      icon: Icons.call_rounded,
                      color: AppColors.info,
                      onTap: () => _makePhoneCall(opportunity['Phone1']),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Material(
                      color: AppColors.whatsapp.withValues(alpha: 0.09),
                      borderRadius: AppRadius.all(AppRadius.lg),
                      child: InkWell(
                        onTap: () => _openWhatsApp(opportunity['Phone1']),
                        borderRadius: AppRadius.all(AppRadius.lg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.all(AppRadius.lg),
                            border: Border.all(color: AppColors.whatsapp.withValues(alpha: 0.28)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              WhatsAppChip(onTap: () => _openWhatsApp(opportunity['Phone1'])),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'واتساب',
                                style: TextStyle(color: AppColors.whatsapp, fontSize: 13.5, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'تفاصيل',
                      icon: Icons.info_rounded,
                      color: AppColors.gold,
                      onTap: () => _openOpportunityDetails(opportunity),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildInfoPill({required dynamic icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.all(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          compatIcon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.cairo(color: color, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeBackground(Color color, dynamic icon, String label, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.all(AppRadius.lg),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Text(label, style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(width: AppSpacing.sm),
          ],
          compatIcon(icon, color: color, size: 24),
          if (alignment == Alignment.centerRight) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppEmpty(
      message: 'لا توجد فرص',
      hint: 'أضف فرصة جديدة للبدء',
      icon: Icons.folder_open_rounded,
      onRefresh: _addNewOpportunity,
      refreshLabel: 'إضافة فرصة',
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _addNewOpportunity,
      backgroundColor: AppColors.gold,
      foregroundColor: AppColors.navy,
      icon: const FaFaIcon(FontAwesomeIcons.plus, color: AppColors.navy, size: 18),
      label: Text(
        'فرصة جديدة',
        style: GoogleFonts.cairo(color: AppColors.navy, fontWeight: FontWeight.bold),
      ),
    ).animate().scale(delay: 500.ms, duration: 300.ms);
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const FaFaIcon(FontAwesomeIcons.arrowDownWideShort, color: AppColors.gold, size: 18),
                const SizedBox(width: 10),
                Text(
                  'ترتيب حسب',
                  style: GoogleFonts.cairo(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSortOption('newest', 'الأحدث أولاً', FontAwesomeIcons.arrowDown),
            _buildSortOption('oldest', 'الأقدم أولاً', FontAwesomeIcons.arrowUp),
            _buildSortOption('value_high', 'القيمة (الأعلى)', FontAwesomeIcons.arrowUp),
            _buildSortOption('value_low', 'القيمة (الأقل)', FontAwesomeIcons.arrowDown),
            _buildSortOption('name', 'الاسم (أ → ي)', FontAwesomeIcons.arrowDownAZ),
            _buildSortOption('stage', 'حسب المرحلة', FontAwesomeIcons.stairs),
            const SizedBox(height: 10),
            if (sortBy != null)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => sortBy = null);
                    Navigator.pop(context);
                    _fetchOpportunities();
                  },
                  icon: const FaFaIcon(FontAwesomeIcons.rotateLeft, size: 14, color: AppColors.neutral),
                  label: Text('إزالة الترتيب', style: GoogleFonts.cairo(color: AppColors.neutral)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label, dynamic icon) {
    final isSelected = sortBy == value;
    return ListTile(
      leading: compatIcon(icon, color: isSelected ? AppColors.gold : AppColors.neutral, size: 16),
      title: Text(
        label,
        style: GoogleFonts.cairo(
          color: isSelected ? AppColors.gold : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const FaFaIcon(FontAwesomeIcons.check, color: AppColors.gold, size: 16) : null,
      onTap: () {
        setState(() => sortBy = value);
        Navigator.pop(context);
        _fetchOpportunities();
      },
      shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.sm)),
      tileColor: isSelected ? AppColors.gold.withValues(alpha: 0.1) : null,
    );
  }

  // ✅ الفلتر المتقدم مع التاريخ
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const FaFaIcon(FontAwesomeIcons.filter, color: AppColors.gold, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'فلترة الفرص',
                    style: GoogleFonts.cairo(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ✅ قسم التاريخ (من - إلى)
              Text('الفترة الزمنية', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true, setModalState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: dateFrom != null 
                                ? AppColors.gold.withValues(alpha: 0.5) 
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.calendarDay, 
                              size: 14, 
                              color: dateFrom != null ? AppColors.gold : AppColors.neutral,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dateFrom != null ? _formatDate(dateFrom!) : 'من تاريخ',
                                style: GoogleFonts.cairo(
                                  color: dateFrom != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (dateFrom != null)
                              InkWell(
                                onTap: () => setModalState(() => dateFrom = null),
                                child: const Icon(Icons.close, size: 16, color: AppColors.neutral),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const FaFaIcon(FontAwesomeIcons.arrowRight, size: 12, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false, setModalState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: dateTo != null 
                                ? AppColors.gold.withValues(alpha: 0.5) 
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.calendarCheck, 
                              size: 14, 
                              color: dateTo != null ? AppColors.gold : AppColors.neutral,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dateTo != null ? _formatDate(dateTo!) : 'إلى تاريخ',
                                style: GoogleFonts.cairo(
                                  color: dateTo != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (dateTo != null)
                              InkWell(
                                onTap: () => setModalState(() => dateTo = null),
                                child: const Icon(Icons.close, size: 16, color: AppColors.neutral),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ✅ اختصارات سريعة للتاريخ
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDateQuickChip('اليوم', () {
                      setModalState(() {
                        dateFrom = DateTime.now();
                        dateTo = DateTime.now();
                      });
                    }),
                    _buildDateQuickChip('آخر 7 أيام', () {
                      setModalState(() {
                        dateTo = DateTime.now();
                        dateFrom = DateTime.now().subtract(const Duration(days: 7));
                      });
                    }),
                    _buildDateQuickChip('آخر 30 يوم', () {
                      setModalState(() {
                        dateTo = DateTime.now();
                        dateFrom = DateTime.now().subtract(const Duration(days: 30));
                      });
                    }),
                    _buildDateQuickChip('هذا الشهر', () {
                      setModalState(() {
                        dateFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
                        dateTo = DateTime.now();
                      });
                    }),
                    _buildDateQuickChip('الشهر الماضي', () {
                      setModalState(() {
                        dateFrom = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
                        dateTo = DateTime(DateTime.now().year, DateTime.now().month, 0);
                      });
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // قسم الموظف - Dropdown
              Text('الموظف المسؤول', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: selectedEmployeeId,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    hint: Text('اختر الموظف', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    icon: const FaFaIcon(FontAwesomeIcons.chevronDown, color: AppColors.neutral, size: 14),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('الكل', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurface)),
                      ),
                      ...employees.map((e) => DropdownMenuItem<int?>(
                            value: e['EmployeeID'],
                            child: Text(e['FullName'] ?? '', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurface)),
                          )),
                    ],
                    onChanged: (value) {
                      setModalState(() => selectedEmployeeId = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // قسم الحملة الإعلانية - Dropdown
              Text('الحملة الإعلانية', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: selectedAdTypeId,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    hint: Text('اختر الحملة', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    icon: const FaFaIcon(FontAwesomeIcons.chevronDown, color: AppColors.neutral, size: 14),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('الكل', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurface)),
                      ),
                      ...adTypes.map((a) => DropdownMenuItem<int?>(
                            value: a['AdTypeID'],
                            child: Text(a['AdTypeName'] ?? '', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurface)),
                          )),
                    ],
                    onChanged: (value) {
                      setModalState(() => selectedAdTypeId = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // حالة المتابعة - Chips
              Text('حالة المتابعة', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFollowUpChip('الكل', null, AppColors.neutral, setModalState),
                  _buildFollowUpChip('متأخرة', 'Overdue', AppColors.error, setModalState),
                  _buildFollowUpChip('اليوم', 'Today', AppColors.warning, setModalState),
                  _buildFollowUpChip('غداً', 'Tomorrow', AppColors.info, setModalState),
                  _buildFollowUpChip('قادم', 'Upcoming', AppColors.success, setModalState),
                ],
              ),
              const SizedBox(height: 20),

              // المصدر - Chips
              Text('المصدر', style: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSourceChip(null, 'الكل', setModalState),
                  ...sources.map((source) => _buildSourceChip(
                        source['SourceID'],
                        source['SourceNameAr'] ?? source['SourceName'],
                        setModalState,
                      )),
                ],
              ),
              const SizedBox(height: 24),

              // زر تطبيق الفلتر
              SizedBox(
                width: double.infinity,
                child: GoldButton(
                  label: 'تطبيق الفلتر',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                    _fetchOpportunities();
                    _fetchSummary();
                  },
                ),
              ),
              const SizedBox(height: 10),

              // زر إعادة تعيين
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    setModalState(() {
                      selectedFollowUpStatus = null;
                      selectedSourceId = null;
                      selectedAdTypeId = null;
                      selectedEmployeeId = null;
                      dateFrom = null;
                      dateTo = null;
                    });
                    setState(() {
                      selectedFollowUpStatus = null;
                      selectedSourceId = null;
                      selectedStageId = null;
                      selectedAdTypeId = null;
                      selectedEmployeeId = null;
                      dateFrom = null;
                      dateTo = null;
                      sortBy = null;
                    });
                    Navigator.pop(context);
                    _fetchOpportunities();
                    _fetchSummary();
                  },
                  icon: const FaFaIcon(FontAwesomeIcons.rotateLeft, size: 14, color: AppColors.neutral),
                  label: Text(
                    'إعادة تعيين',
                    style: GoogleFonts.cairo(color: AppColors.neutral),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateQuickChip(String label, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.12),
          borderRadius: AppRadius.all(AppRadius.pill),
          // ✅ شيل border تماماً
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(color: AppColors.info, fontSize: 11),
        ),
      ),
    ),
  );
}

  Widget _buildFollowUpChip(String label, String? value, Color color, StateSetter setModalState) {
    final isSelected = selectedFollowUpStatus == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.cairo(
          color: isSelected ? AppColors.navy : Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() => selectedFollowUpStatus = selected ? value : null);
      },
      backgroundColor: color.withValues(alpha: 0.12),
      selectedColor: color,
      checkmarkColor: AppColors.navy,
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildSourceChip(int? sourceId, String label, StateSetter setModalState) {
    final isSelected = selectedSourceId == sourceId;

    String? sourceName;
    if (sourceId != null) {
      final source = sources.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['SourceID'] == sourceId,
        orElse: () => <String, dynamic>{},
      );
      sourceName = source['SourceName'] ?? source['SourceNameAr'];
    }

    return FilterChip(
      avatar: sourceId != null ? _getSourceIcon(sourceName, size: 14) : null,
      label: Text(
        label,
        style: GoogleFonts.cairo(
          color: isSelected ? AppColors.navy : Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() => selectedSourceId = selected ? sourceId : null);
      },
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      selectedColor: AppColors.gold,
      checkmarkColor: AppColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _openOpportunityDetails(dynamic opportunity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OpportunityDetailsScreen(
          opportunity: opportunity,
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  void _addNewOpportunity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddOpportunityScreen(
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }
}