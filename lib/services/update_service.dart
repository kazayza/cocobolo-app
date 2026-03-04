import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'theme_service.dart';

class UpdateService {
  // ✅ غيّر ده باسم الريبو بتاعك
  static const String _githubOwner = 'kazayza';
  static const String _githubRepo = 'cocobolo-app';

  // ===================================
  // 🔍 تشييك لو فيه تحديث
  // ===================================
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
        final currentInfo = await PackageInfo.fromPlatform();
        final currentVersion = currentInfo.version;

        print('📱 النسخة الحالية: $currentVersion');
        print('🌐 آخر نسخة: $latestVersion');

        if (_isNewerVersion(latestVersion, currentVersion)) {
          // البحث عن ملف الـ APK في الـ Assets
          String? apkUrl;
          final assets = data['assets'] as List<dynamic>? ?? [];
          for (var asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.endsWith('.apk')) {
              apkUrl = asset['browser_download_url'] as String;
              break;
            }
          }

          if (apkUrl != null) {
            return {
              'hasUpdate': true,
              'currentVersion': currentVersion,
              'latestVersion': latestVersion,
              'downloadUrl': apkUrl,
              'releaseNotes': data['body'] ?? 'تحديث جديد متاح',
              'releaseName': data['name'] ?? 'v$latestVersion',
            };
          }
        }

        return {'hasUpdate': false};
      }
    } catch (e) {
      print('❌ خطأ في تشييك التحديث: $e');
    }
    return null;
  }

  // ===================================
  // 📊 مقارنة النسخ
  // ===================================
  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      // نكمّل بأصفار لو أحدهم أقصر
      while (latestParts.length < 3) latestParts.add(0);
      while (currentParts.length < 3) currentParts.add(0);

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      return false; // نفس النسخة
    } catch (e) {
      return false;
    }
  }

  // ===================================
  // 📥 تحميل وتثبيت التحديث
  // ===================================
  static Future<void> downloadAndInstall({
    required String downloadUrl,
    required String version,
    required Function(double) onProgress,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    try {
      final dio = Dio();
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/cocobolo_$version.apk';

      // حذف أي ملف قديم
      final oldFile = File(filePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      // تحميل الملف
      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );

      onComplete();

      // فتح الملف للتثبيت
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        onError('فشل فتح ملف التحديث: ${result.message}');
      }
    } catch (e) {
      onError('فشل تحميل التحديث: $e');
    }
  }

  // ===================================
  // 🔔 عرض Dialog التحديث
  // ===================================
  static Future<void> showUpdateDialog({
    required BuildContext context,
    required Map<String, dynamic> updateInfo,
  }) async {
    final isDark = ThemeService().isDarkMode;
    double downloadProgress = 0;
    bool isDownloading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isDownloading,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.card(isDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        color: AppColors.gold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تحديث جديد متاح!',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.text(isDark),
                            ),
                          ),
                          Text(
                            '${updateInfo['currentVersion']} ← ${updateInfo['latestVersion']}',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ملاحظات التحديث
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill(isDark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider(isDark)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📝 ما الجديد:',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.text(isDark),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            updateInfo['releaseNotes'] ?? '',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.textSecondary(isDark),
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // شريط التحميل
                    if (isDownloading) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.downloading_rounded, 
                              color: AppColors.gold, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'جاري التحميل...',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: AppColors.text(isDark),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(downloadProgress * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: downloadProgress,
                          minHeight: 10,
                          backgroundColor: AppColors.divider(isDark),
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: isDownloading
                    ? null
                    : [
                        // زرار لاحقاً
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'لاحقاً',
                            style: GoogleFonts.cairo(
                              color: AppColors.textHint(isDark),
                            ),
                          ),
                        ),
                        // زرار تحديث الآن
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: AppColors.buttonGradient(isDark),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                isDownloading = true;
                                downloadProgress = 0;
                              });

                              downloadAndInstall(
                                downloadUrl: updateInfo['downloadUrl'],
                                version: updateInfo['latestVersion'],
                                onProgress: (progress) {
                                  setDialogState(() {
                                    downloadProgress = progress;
                                  });
                                },
                                onComplete: () {
                                  Navigator.pop(context);
                                },
                                onError: (error) {
                                  setDialogState(() {
                                    isDownloading = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(error, 
                                          style: GoogleFonts.cairo()),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.download_rounded, size: 20),
                            label: Text(
                              'تحديث الآن',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: isDark ? AppColors.navy : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
              ),
            );
          },
        );
      },
    );
  }

  // ===================================
  // 🚀 تشييك وعرض (الدالة الرئيسية)
  // ===================================
  static Future<void> checkAndPrompt(BuildContext context) async {
    try {
      final updateInfo = await checkForUpdate();

      if (updateInfo != null && updateInfo['hasUpdate'] == true) {
        if (context.mounted) {
          await showUpdateDialog(
            context: context,
            updateInfo: updateInfo,
          );
        }
      }
    } catch (e) {
      print('❌ خطأ في تشييك التحديث: $e');
    }
  }
}