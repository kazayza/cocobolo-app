import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import '../models/dashboard_model.dart';

class CrmPdfGenerator {
  final DashboardData data;
  final String username;
  final String periodName;
  final String? employeeName;
  final String? sourceName;

  CrmPdfGenerator({
    required this.data,
    required this.username,
    required this.periodName,
    this.employeeName,
    this.sourceName,
  });

  // === 1. دالة الطباعة المباشرة ===
  Future<void> generateAndPrint() async {
    final pdf = await _generateDocument();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'CRM_Report_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // === 2. دالة المشاركة ===
  Future<void> generateAndShare() async {
    final pdf = await _generateDocument();
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'CRM_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // === بناء المستند (مشترك) ===
  Future<pw.Document> _generateDocument() async {
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final ttfBold = pw.Font.ttf(fontBoldData);

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/icons/app_icon.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      print('Logo error: $e');
    }

    final pdf = pw.Document();
    final navy = PdfColor.fromHex('#13273F');
    final gold = PdfColor.fromHex('#DBBF74');
    final lightGrey = PdfColor.fromHex('#F9F9F9');

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(20),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: navy, width: 3),
              ),
            ),
          ),
        ),
        header: (context) => _buildHeader(navy, gold, logoImage),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildFilterBox(),
          pw.SizedBox(height: 15),

          _buildSectionHeader('1. الملخص التنفيذي والتحليل', navy),
          _buildAnalyticalText(),
          pw.SizedBox(height: 20),

          _buildSectionHeader('2. الموقف المالي والمبيعات', navy),
          _buildFinancialTable(lightGrey),
          pw.SizedBox(height: 20),

          _buildSectionHeader('3. تحليل مراحل البيع (Funnel)', navy),
          _buildFunnelTable(lightGrey),
          pw.SizedBox(height: 20),

          _buildSectionHeader('4. أداء مصادر العملاء', navy),
          _buildSourcesTable(lightGrey),
          pw.SizedBox(height: 20),

          if (data.adTypes.isNotEmpty) ...[
            _buildSectionHeader('5. تقييم الحملات الإعلانية', navy),
            _buildAdTypesTable(lightGrey),
            pw.SizedBox(height: 20),
          ],

          if (data.leaderboard.isNotEmpty) ...[
            _buildSectionHeader('6. أداء فريق المبيعات', navy),
            _buildLeaderboardTable(lightGrey),
            pw.SizedBox(height: 20),
          ],

          if (data.lostReasons.isNotEmpty) ...[
            _buildSectionHeader('7. تحليل أسباب خسارة الفرص', navy),
            _buildLostReasonsTable(lightGrey),
            pw.SizedBox(height: 20),
          ],

          if (data.kpi.totalAlerts > 0) ...[
            _buildSectionHeader('8. تنبيهات تشغيلية', PdfColors.red900),
            _buildAlertsSection(),
            pw.SizedBox(height: 20),
          ],

          _buildSectionHeader('9. التوصيات والمقترحات', gold),
          _buildRecommendationsSection(),
        ],
      ),
    );

    return pdf;
  }

  // ══════════════════════════════════════
  // UI Helpers
  // ══════════════════════════════════════

  pw.Widget _buildHeader(PdfColor navy, PdfColor gold, pw.MemoryImage? logo) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logo != null) pw.Container(width: 50, height: 50, child: pw.Image(logo)) else pw.SizedBox(width: 50),
            pw.Column(
              children: [
                pw.Text('COCOBOLO Furniture', style: pw.TextStyle(fontSize: 16, color: navy, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('تقرير مؤشرات الأداء (CRM)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('تاريخ التقرير', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(intl.DateFormat('yyyy-MM-dd').format(DateTime.now()), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text(intl.DateFormat('hh:mm a').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.Divider(color: gold, thickness: 2),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('المستخدم: $username', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget _buildFilterBox() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _filterItem('الفترة', periodName),
          if (employeeName != null) _filterItem('الموظف', employeeName!),
          if (sourceName != null) _filterItem('المصدر', sourceName!),
        ],
      ),
    );
  }

  pw.Widget _filterItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildSectionHeader(String title, PdfColor color) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: color))),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
    );
  }

  pw.Widget _buildAnalyticalText() {
    final kpi = data.kpi;
    final growthText = kpi.actualRevenueGrowth >= 0 ? 'ارتفاع' : 'انخفاض';
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'خلال فترة التقرير ($periodName)، تم تحقيق إيرادات فعلية بقيمة ${_formatCurrency(kpi.currentActualRevenue)} ج.م، مما يمثل $growthText بنسبة ${kpi.actualRevenueGrowth.abs().toStringAsFixed(1)}% مقارنة بالفترة السابقة.',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
          ),
          pw.Text(
            'تم فتح ${kpi.currentOpportunities} فرصة بيعية جديدة، تم إغلاق ${kpi.currentWon} منها كصفقات ناجحة، بنسبة تحويل إجمالية بلغت ${kpi.currentConversion}%.',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
          ),
          if (data.sources.isNotEmpty)
            pw.Text(
              'المصدر الأكثر فعالية هو "${data.sources.first.name}" بعدد ${data.sources.first.won} صفقة ناجحة.',
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildRecommendationsSection() {
    final List<String> recommendations = [];

    if (data.kpi.currentConversion < 10) {
      recommendations.add('[تنبيه] نسبة التحويل منخفضة (أقل من 10%). يوصى بمراجعة جودة "Leads" أو تدريب الفريق على الإغلاق.');
    }
    if (data.kpi.overdueTasks > 5) {
      recommendations.add('[هام] يوجد تراكم في المهام المتأخرة. يجب تخصيص يوم لتصفية جميع المهام العالقة.');
    }
    if (data.kpi.stagnantOpportunities > 10) {
      recommendations.add('[تحذير] الفرص الراكدة مرتفعة. يوصى بإطلاق حملة "إعادة استهداف" للعملاء غير المتفاعلين.');
    }
    if (data.kpi.collectionRate < 50) {
      recommendations.add('[مالي] نسبة التحصيل ضعيفة. يجب التركيز على تحصيل الدفعات المستحقة من العملاء.');
    }
    if (data.lostReasons.isNotEmpty && data.lostReasons.first.name.contains('سعر')) {
      recommendations.add('[تسعير] "السعر" هو السبب الرئيسي للخسارة. يرجى مراجعة استراتيجية التسعير أو تقديم عروض ترويجية.');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('[جيد] الأداء العام جيد. يوصى بالحفاظ على نفس الاستراتيجية مع زيادة ميزانية التسويق بنسبة 10%.');
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.amber700),
        borderRadius: pw.BorderRadius.circular(5),
        color: PdfColors.amber50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: recommendations.map((rec) => 
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text('• $rec', style: const pw.TextStyle(fontSize: 10)),
          )
        ).toList(),
      ),
    );
  }

  pw.Widget _buildFinancialTable(PdfColor bg) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        _tableHeader(['ملاحظات', 'القيمة', 'البيان'], bg),
        _tableRow(['مبيعات مؤكدة', '${_formatCurrency(data.kpi.currentActualRevenue)} ج.م', 'الإيراد الفعلي']),
        _tableRow(['بناءً على الفرص', '${_formatCurrency(data.kpi.currentExpectedRevenue)} ج.م', 'الإيراد المتوقع']),
        _tableRow(['سيولة مستلمة', '${_formatCurrency(data.kpi.currentCollected)} ج.م', 'المحصل (Cash)']),
        _tableRow(['ROI: ${data.kpi.roi.toStringAsFixed(0)}%', '${_formatCurrency(data.kpi.currentMarketingCost)} ج.م', 'تكلفة التسويق']),
      ],
    );
  }

  pw.Widget _buildFunnelTable(PdfColor bg) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        _tableHeader(['القيمة المتوقعة', 'النسبة', 'العدد', 'المرحلة'], bg),
        ...data.funnel.map((item) {
          final total = data.funnel.fold<int>(0, (sum, i) => sum + i.count);
          final percent = total > 0 ? (item.count / total * 100).toStringAsFixed(1) : '0';
          return _tableRow([
            '${_formatCurrency(item.totalValue)} ج.م',
            '$percent%',
            '${item.count}',
            item.stageNameAr
          ]);
        }),
      ],
    );
  }

  pw.Widget _buildSourcesTable(PdfColor bg) {
    final sources = data.sources.take(8).toList();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        _tableHeader(['الإيراد', 'نسبة التحويل', 'صفقات', 'فرص', 'المصدر'], bg),
        ...sources.map((item) => _tableRow([
              _formatCurrency(item.actualRevenue),
              '${item.conversionRate.toStringAsFixed(1)}%',
              '${item.won}',
              '${item.total}',
              item.name
            ])),
      ],
    );
  }

  pw.Widget _buildAdTypesTable(PdfColor bg) {
    final ads = data.adTypes.take(5).toList();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        _tableHeader(['الإيراد', 'نسبة التحويل', 'صفقات', 'فرص', 'اسم الحملة'], bg),
        ...ads.map((item) => _tableRow([
              _formatCurrency(item.actualRevenue),
              '${item.conversionRate.toStringAsFixed(1)}%',
              '${item.won}',
              '${item.total}',
              item.name
            ])),
      ],
    );
  }

  pw.Widget _buildLeaderboardTable(PdfColor bg) {
    final top = data.leaderboard.take(10).toList();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        _tableHeader(['الإيراد', 'نسبة التحويل', 'صفقات', 'الموظف', '#'], bg),
        ...top.asMap().entries.map((entry) => _tableRow([
              _formatCurrency(entry.value.actualRevenue),
              '${entry.value.conversionRate.toStringAsFixed(1)}%',
              '${entry.value.wonDeals}',
              entry.value.fullName,
              '${entry.key + 1}'
            ])),
      ],
    );
  }

  pw.Widget _buildLostReasonsTable(PdfColor bg) {
    final reasons = data.lostReasons.take(5).toList();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        _tableHeader(['القيمة المهدرة', 'العدد', 'السبب'], bg),
        ...reasons.map((item) => _tableRow([
              _formatCurrency(item.lostValue),
              '${item.count}',
              item.name
            ])),
      ],
    );
  }

  pw.Widget _buildAlertsSection() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: PdfColors.red50, border: pw.Border.all(color: PdfColors.red900)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (data.kpi.overdueTasks > 0) _alertItem('${data.kpi.overdueTasks} مهام متأخرة'),
          if (data.kpi.stagnantOpportunities > 0) _alertItem('${data.kpi.stagnantOpportunities} فرص راكدة'),
          if (data.kpi.overdueFollowUps > 0) _alertItem('${data.kpi.overdueFollowUps} متابعات فائتة'),
        ],
      ),
    );
  }

  pw.Widget _alertItem(String text) {
    return pw.Text('• $text', style: const pw.TextStyle(fontSize: 10));
  }

  pw.TableRow _tableHeader(List<String> cells, PdfColor bg) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: cells.map((text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      )).toList(),
    );
  }

  pw.TableRow _tableRow(List<String> cells) {
    return pw.TableRow(
      children: cells.map((text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
      )).toList(),
    );
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return '0';
    return intl.NumberFormat('#,###').format(amount);
  }
}