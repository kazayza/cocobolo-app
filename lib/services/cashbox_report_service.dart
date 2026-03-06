import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class CashboxReportService {
  
  // ✅ إنشاء PDF لحركات الخزينة
  static Future<Uint8List> generatePDF({
    required List<Map<String, dynamic>> transactions,
    required double totalIn,
    required double totalOut,
    required double balance,
    required String? cashboxName,
    required String? fromDate,
    required String? toDate,
  }) async {
    // تحميل الخط العربي
    final arabicFont = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final arabicFontBold = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final ttf = pw.Font.ttf(arabicFont);
    final ttfBold = pw.Font.ttf(arabicFontBold);

    final pdf = pw.Document();
    final currencyFormatter = NumberFormat('#,##0.00', 'en');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        header: (context) => _buildHeader(
          cashboxName: cashboxName,
          fromDate: fromDate,
          toDate: toDate,
          ttfBold: ttfBold,
          ttf: ttf,
        ),
        footer: (context) => _buildFooter(context, ttf),
        build: (context) => [
          _buildSummary(totalIn, totalOut, balance, ttf, ttfBold, currencyFormatter),
          pw.SizedBox(height: 20),
          _buildTable(transactions, ttf, ttfBold, currencyFormatter),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader({
    required String? cashboxName,
    required String? fromDate,
    required String? toDate,
    required pw.Font ttfBold,
    required pw.Font ttf,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'تقرير حركات الخزينة',
                style: pw.TextStyle(font: ttfBold, fontSize: 18),
                textDirection: pw.TextDirection.rtl,
              ),
              if (cashboxName != null && cashboxName.isNotEmpty)
                pw.Text(
                  'الخزنة: $cashboxName',
                  style: pw.TextStyle(font: ttf, fontSize: 12, color: PdfColors.grey700),
                  textDirection: pw.TextDirection.rtl,
                ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'الفترة:',
                style: pw.TextStyle(font: ttfBold, fontSize: 10, color: PdfColors.grey600),
                textDirection: pw.TextDirection.rtl,
              ),
              pw.Text(
                '${fromDate ?? '---'} إلى ${toDate ?? '---'}',
                style: pw.TextStyle(font: ttf, fontSize: 10),
                textDirection: pw.TextDirection.rtl,
              ),
              pw.Text(
                'تاريخ الطباعة: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey500),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font ttf) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            'تم إنشاء التقرير بواسطة النظام',
            style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey500),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummary(
    double totalIn,
    double totalOut,
    double balance,
    pw.Font ttf,
    pw.Font ttfBold,
    NumberFormat formatter,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryBox('إجمالي القبض', formatter.format(totalIn), PdfColors.green, ttf, ttfBold),
          _buildSummaryBox('إجمالي الصرف', formatter.format(totalOut), PdfColors.red, ttf, ttfBold),
          _buildSummaryBox('الصافي', formatter.format(balance), balance >= 0 ? PdfColors.blue : PdfColors.red, ttf, ttfBold),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryBox(String label, String value, PdfColor color, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700),
          textDirection: pw.TextDirection.rtl,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(font: ttfBold, fontSize: 14, color: color),
        ),
      ],
    );
  }

  // ✅ الجدول المُصحَّح
  // ✅ الجدول المُصحَّح
static pw.Widget _buildTable(
  List<Map<String, dynamic>> transactions,
  pw.Font ttf,
  pw.Font ttfBold,
  NumberFormat formatter,
) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400),
    children: [
      // رأس الجدول
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
        children: [
          _buildHeaderCell('المبلغ', ttfBold),
          _buildHeaderCell('المرجع', ttfBold),
          _buildHeaderCell('النوع', ttfBold),
          _buildHeaderCell('الخزنة', ttfBold),
          _buildHeaderCell('التاريخ', ttfBold),
          _buildHeaderCell('#', ttfBold),
        ],
      ),
      // بيانات الجدول
      ...transactions.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final t = entry.value;
        
        String dateStr = '';
        if (t['TransactionDate'] != null) {
          try {
            final date = DateTime.parse(t['TransactionDate']);
            dateStr = DateFormat('MM/dd HH:mm').format(date);
          } catch (e) {
            dateStr = t['TransactionDate'].toString();
          }
        }
        
        final isCredit = t['TransactionType'] == 'قبض';
        final amount = (t['Amount'] ?? 0).toDouble();
        final amountColor = isCredit ? PdfColors.green : PdfColors.red;
        
        return pw.TableRow(
          children: [
            _buildAmountCell('${isCredit ? '+' : '-'} ${formatter.format(amount)}', ttf, amountColor),
            _buildCell(_getReferenceTypeLabel(t['ReferenceType']), ttf),
            _buildCell(t['TransactionType'] ?? '', ttf),
            _buildCell(t['CashBoxName'] ?? '', ttf),
            _buildCell(dateStr, ttf),
            _buildCell(index.toString(), ttf),
          ],
        );
      }),
    ],
  );
}

  static pw.Widget _buildHeaderCell(String text, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          color: PdfColors.white,
        ),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  static pw.Widget _buildCell(String text, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  static pw.Widget _buildAmountCell(String text, pw.Font font, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 9, color: color),
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  // ✅ إنشاء ملف Excel
  static Future<String> generateExcel({
    required List<Map<String, dynamic>> transactions,
    required double totalIn,
    required double totalOut,
    required double balance,
    required String? cashboxName,
    required String? fromDate,
    required String? toDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['حركات الخزينة'];

    excel.delete('Sheet1');

    sheet.appendRow([TextCellValue('تقرير حركات الخزينة')]);
    sheet.appendRow([TextCellValue('الخزنة: ${cashboxName ?? 'الكل'}')]);
    sheet.appendRow([TextCellValue('الفترة: ${fromDate ?? '---'} إلى ${toDate ?? '---'}')]);
    sheet.appendRow([]);

    sheet.appendRow([TextCellValue('إجمالي القبض'), DoubleCellValue(totalIn)]);
    sheet.appendRow([TextCellValue('إجمالي الصرف'), DoubleCellValue(totalOut)]);
    sheet.appendRow([TextCellValue('الصافي'), DoubleCellValue(balance)]);
    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('#'),
      TextCellValue('التاريخ'),
      TextCellValue('الوقت'),
      TextCellValue('الخزنة'),
      TextCellValue('نوع العملية'),
      TextCellValue('نوع المرجع'),
      TextCellValue('المبلغ'),
      TextCellValue('ملاحظات'),
      TextCellValue('بواسطة'),
    ]);

    int index = 1;
    for (var t in transactions) {
      String dateStr = '';
      String timeStr = '';
      if (t['TransactionDate'] != null) {
        try {
          final date = DateTime.parse(t['TransactionDate']);
          dateStr = DateFormat('yyyy/MM/dd').format(date);
          timeStr = DateFormat('HH:mm').format(date);
        } catch (e) {}
      }

      final isCredit = t['TransactionType'] == 'قبض';
      final amount = (t['Amount'] ?? 0).toDouble();

      sheet.appendRow([
        IntCellValue(index),
        TextCellValue(dateStr),
        TextCellValue(timeStr),
        TextCellValue(t['CashBoxName'] ?? ''),
        TextCellValue(t['TransactionType'] ?? ''),
        TextCellValue(_getReferenceTypeLabel(t['ReferenceType'])),
        DoubleCellValue(isCredit ? amount : -amount),
        TextCellValue(t['Notes'] ?? ''),
        TextCellValue(t['CreatedBy'] ?? ''),
      ]);
      index++;
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'cashbox_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final filePath = '${directory.path}/$fileName';
    
    final fileBytes = excel.save();
    if (fileBytes != null) {
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
    }

    return filePath;
  }

  static String _getReferenceTypeLabel(String? type) {
    switch (type) {
      case 'Manual': return 'يدوي';
      case 'Transfer': return 'تحويل';
      case 'Payment': return 'سداد فاتورة';
      case 'Expense': return 'مصروف';
      case 'Payroll': return 'راتب';
      case 'AdvanceExpense': return 'مصروف مقدم';
      case 'Charge': return 'رسوم';
      default: return type ?? '---';
    }
  }
}