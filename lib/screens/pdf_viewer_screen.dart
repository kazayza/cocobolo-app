import 'dart:io';
import '../services/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/auth/session_service.dart';
import '../widgets/design_kit.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewerScreen({Key? key, required this.url, required this.title}) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? localPath;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      // الرابط الحالي الوحيد لهذه الشاشة هو ملف من الـ API — نرسل التوكن.
      final response = await http.get(
        Uri.parse(widget.url),
        headers: SessionService.instance.authHeaders,
      );
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/temp_pdf.pdf');
        await file.writeAsBytes(response.bodyBytes);
        
        if (mounted) {
          setState(() {
            localPath = file.path;
            isLoading = false;
          });
        }
      } else {
        throw 'الملف غير موجود';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'فشل تحميل الملف: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // أو لون الثيم بتاعك
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const AppLoading()
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage, style: GoogleFonts.cairo(color: Colors.white)))
              : PDFView(
                  filePath: localPath,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  onError: (error) {
                    print(error.toString());
                  },
                ),
    );
  }
}