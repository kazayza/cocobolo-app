import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../widgets/design_kit.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:map_launcher/map_launcher.dart';
import '../constants.dart';
import '../core/auth/session_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_drawer.dart';

class AttendanceScreen extends StatefulWidget {
  final int userId;
  final String username;

  const AttendanceScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════
  // المتغيرات
  // ═══════════════════════════════════════════════════════════════

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String status = 'loading';
  DateTime? checkInTime;
  DateTime? checkOutTime;
  bool processing = false;
  String? errorMessage;

  double? currentLatitude;
  double? currentLongitude;

  int attendanceDaysThisMonth = 0;
  double totalHoursToday = 0.0;
  int lateMinutes = 0;

  late AnimationController _pulseController;
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  // ═══════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _fetchStatistics();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _currentTime = DateTime.now());
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // API Calls
  // ═══════════════════════════════════════════════════════════════

  Future<void> _fetchStatistics() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/attendance/statistics/${widget.userId}'),
       headers: SessionService.instance.authHeaders,);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          attendanceDaysThisMonth = data['daysThisMonth'] ?? 0;
          totalHoursToday = (data['hoursToday'] ?? 0).toDouble();
          lateMinutes = data['lateMinutes'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('خطأ في جلب الإحصائيات: $e');
    }
  }

  Future<void> _fetchStatus() async {
    setState(() => status = 'loading');
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/attendance/status/${widget.userId}'),
       headers: SessionService.instance.authHeaders,);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          status = data['status'];
          if (data['in'] != null) {
            checkInTime = _parseTime(data['in']);
          }
          if (data['out'] != null) {
            checkOutTime = _parseTime(data['out']);
          }
        });
      } else {
        setState(() => errorMessage = 'فشل الاتصال بالسيرفر');
      }
    } catch (e) {
      setState(() => errorMessage = 'خطأ في الاتصال');
    }
  }

  DateTime _parseTime(String timeStr) {
    String cleanTime = timeStr;
    if (timeStr.contains('T')) {
      cleanTime = timeStr.split('T')[1].split('.')[0].replaceAll('Z', '');
    }

    final parts = cleanTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final second = parts.length > 2 ? int.parse(parts[2]) : 0;

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute, second);
  }

  Future<void> _handleCheckInOut() async {
    HapticFeedback.heavyImpact();

    setState(() {
      processing = true;
      errorMessage = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'تم رفض إذن الموقع';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'تم رفض إذن الموقع نهائياً. يرجى تفعيله من الإعدادات.';
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
      });

      final isCheckIn = status == 'not_checked_in';
      final endpoint = isCheckIn ? 'check-in' : 'check-out';

      final res = await http.post(
        Uri.parse('$baseUrl/api/attendance/$endpoint'),
        headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      final result = jsonDecode(res.body);

      if (res.statusCode == 200 && result['success'] == true) {
        HapticFeedback.mediumImpact();
        _showSuccessDialog(result['message'], isCheckIn);
        _fetchStatus();
        _fetchStatistics();
      } else {
        _showErrorDialog(result['message'] ?? 'فشل العملية');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => processing = false);
    }
  }

  Future<void> _showLocationOnMap() async {
    if (currentLatitude == null || currentLongitude == null) return;

    try {
      await MapLauncher.marker(
        LocationCoords(currentLatitude!, currentLongitude!,
            title: 'موقع تسجيل الحضور'),
      ).show();
    } catch (e) {
      debugPrint('خطأ في فتح الخريطة: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'مساء الخير';
    return 'مساء النور';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_twilight;
    return Icons.nightlight_round;
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  // الحضور اليدوي للمعفيين من البصمة — بوابة الكتابة نفسها خادميًا:
  // Admin/HrManager/AccountManager/Account
  bool get _canWriteManualAttendance {
    final role = (PermissionService().role ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_-]+'), '');
    return ['admin', 'hrmanager', 'accountmanager', 'account'].contains(role);
  }

  Future<void> _openManualAttendance() async {
    final monthCtrl = TextEditingController(
      text: DateFormat('yyyy-MM').format(DateTime.now()),
    );
    List<dynamic> rows = [];
    bool loadingRows = false;
    bool loadedOnce = false;
    String? loadError;
    final editors = <int, Map<String, TextEditingController>>{};

    void buildEditors() {
      for (final e in editors.values) {
        for (final c in e.values) {
          c.dispose();
        }
      }
      editors.clear();
      for (final r in rows) {
        final m = Map<String, dynamic>.from(r as Map);
        final id = (m['EmployeeID'] as num?)?.toInt() ?? 0;
        editors[id] = {
          'present': TextEditingController(text: '${m['PresentDays'] ?? 0}'),
          'absence': TextEditingController(text: '${m['AbsenceDays'] ?? 0}'),
          'late': TextEditingController(text: '${m['LateMinutes'] ?? 0}'),
          'notes': TextEditingController(text: '${m['Notes'] ?? ''}'),
        };
      }
    }

    Future<void> load(StateSetter setDialogState) async {
      setDialogState(() {
        loadingRows = true;
        loadError = null;
      });
      try {
        final res = await http.get(
          Uri.parse('$baseUrl/api/attendance/manual?month=${monthCtrl.text.trim()}'),
          headers: SessionService.instance.authHeaders,
        );
        final decoded = jsonDecode(res.body);
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception(decoded is Map ? (decoded['message'] ?? 'فشل التحميل') : 'فشل التحميل');
        }
        final data = decoded is Map ? decoded['data'] : decoded;
        setDialogState(() {
          rows = data is List ? data : [];
          buildEditors();
        });
      } catch (e) {
        setDialogState(() => loadError = e.toString());
      } finally {
        setDialogState(() {
          loadingRows = false;
          loadedOnce = true;
        });
      }
    }

    Future<void> saveRow(Map<String, dynamic> row) async {
      final id = (row['EmployeeID'] as num?)?.toInt() ?? 0;
      final e = editors[id];
      if (e == null) return;
      try {
        final res = await http.post(
          Uri.parse('$baseUrl/api/attendance/manual'),
          headers: {...SessionService.instance.authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'EmployeeID': id,
            'AttendanceMonth': monthCtrl.text.trim(),
            'PresentDays': int.tryParse(e['present']!.text) ?? 0,
            'AbsenceDays': int.tryParse(e['absence']!.text) ?? 0,
            'LateMinutes': int.tryParse(e['late']!.text) ?? 0,
            'Notes': e['notes']!.text.trim(),
          }),
        );
        final decoded = jsonDecode(res.body);
        final ok = res.statusCode >= 200 && res.statusCode < 300 && decoded['success'] == true;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'تم حفظ حضور ${row['EmployeeName']}' : (decoded['message']?.toString() ?? 'فشل الحفظ'),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الحفظ: $err', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
          );
        }
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!loadedOnce && !loadingRows) {
            WidgetsBinding.instance.addPostFrameCallback((_) => load(setDialogState));
          }
          return AlertDialog(
            title: Text('الحضور اليدوي للمعفيين من البصمة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: monthCtrl,
                        decoration: InputDecoration(labelText: 'الشهر (YYYY-MM)', labelStyle: GoogleFonts.cairo(fontSize: 12)),
                        style: GoogleFonts.cairo(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: loadingRows ? null : () => load(setDialogState),
                      child: Text('تحميل', style: GoogleFonts.cairo(fontSize: 12)),
                    ),
                  ]),
                  if (loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(loadError!, style: GoogleFonts.cairo(color: Colors.red, fontSize: 12)),
                    ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: loadingRows
                        ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
                        : rows.isEmpty
                            ? Text('لا يوجد موظفون معفيون من البصمة', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey))
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: rows.length,
                                itemBuilder: (_, i) {
                                  final row = Map<String, dynamic>.from(rows[i] as Map);
                                  final id = (row['EmployeeID'] as num?)?.toInt() ?? 0;
                                  final e = editors[id];
                                  if (e == null) return const SizedBox.shrink();
                                  Widget numField(String key, String label) => SizedBox(
                                        width: 76,
                                        child: TextField(
                                          controller: e[key],
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(labelText: label, labelStyle: GoogleFonts.cairo(fontSize: 10)),
                                          style: GoogleFonts.cairo(fontSize: 12),
                                        ),
                                      );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${row['EmployeeName'] ?? ''} • ${row['Department'] ?? ''}', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
                                        Row(children: [
                                          numField('present', 'حضور'),
                                          const SizedBox(width: 6),
                                          numField('absence', 'غياب'),
                                          const SizedBox(width: 6),
                                          numField('late', 'تأخير (د)'),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(Icons.save_outlined, size: 20),
                                            tooltip: 'حفظ',
                                            onPressed: () => saveRow(row),
                                          ),
                                        ]),
                                        TextField(
                                          controller: e['notes'],
                                          decoration: InputDecoration(labelText: 'ملاحظات', labelStyle: GoogleFonts.cairo(fontSize: 10)),
                                          style: GoogleFonts.cairo(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('إغلاق', style: GoogleFonts.cairo()),
              ),
            ],
          );
        },
      ),
    );

    monthCtrl.dispose();
    for (final e in editors.values) {
      for (final c in e.values) {
        c.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: buildAppDrawer(currentRoute: 'frm_empAttendance'),
      backgroundColor: const Color(0xFF0F0F0F),
      floatingActionButton: _canWriteManualAttendance
          ? FloatingActionButton.extended(
              onPressed: _openManualAttendance,
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text('الحضور اليدوي', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            )
          : null,
      body: status == 'loading'
          ? _buildLoadingState()
          : status == 'not_linked'
              ? _buildNotLinkedState()
              : _buildMainContent(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LOADING STATE - Skeleton
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSkeleton(44, 44, 12),
                _buildSkeleton(44, 44, 12),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildSkeleton(60, 60, 18),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeleton(100, 14, 6),
                      const SizedBox(height: 8),
                      _buildSkeleton(160, 20, 8),
                      const SizedBox(height: 8),
                      _buildSkeleton(130, 12, 6),
                    ],
                  ),
                ),
                _buildSkeleton(60, 60, 12),
              ],
            ),
            const SizedBox(height: 20),
            _buildSkeleton(double.infinity, 56, 14),
            const Spacer(),
            _buildSkeleton(140, 140, 70),
            const Spacer(),
            _buildSkeleton(double.infinity, 90, 16),
            const SizedBox(height: 16),
            _buildSkeleton(double.infinity, 110, 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(double width, double height, double radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.04));
  }

  // ═══════════════════════════════════════════════════════════════
  // NOT LINKED STATE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildNotLinkedState() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // زر الرجوع
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

            const Spacer(),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_off_outlined,
                size: 60,
                color: AppColors.gold,
              ),
            ).animate().shake(duration: 800.ms),

            const SizedBox(height: 24),

            Text(
              'لم يتم الربط بعد!',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 12),

            Text(
              'حسابك غير مرتبط بموظف حتى الآن\nيرجى التواصل مع إدارة الموارد البشرية',
              style: GoogleFonts.cairo(
                color: Colors.grey[400],
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 32),

            GestureDetector(
              onTap: _showSupportDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gold, AppColors.goldDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.support_agent, color: Colors.black, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'تواصل مع الدعم',
                      style: GoogleFonts.cairo(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().scale(delay: 600.ms),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MAIN CONTENT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMainContent() {
    final isCheckedOut = status == 'checked_out';

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // الساعة الرقمية
                  _buildDigitalClock(),

                  const SizedBox(height: 28),

                  // زر البصمة
                  if (!isCheckedOut) _buildFingerprintButton(),

                  if (!isCheckedOut) const SizedBox(height: 28),

                  // الإحصائيات
                  _buildStatisticsCard(),

                  const SizedBox(height: 16),

                  // سجل اليوم
                  _buildTodayRecord(),

                  const SizedBox(height: 16),

                  // حالة الانتهاء
                  if (isCheckedOut) _buildCheckedOutCard(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (status == 'checked_in' && checkInTime != null) {
      statusText = 'حاضر منذ ${DateFormat('hh:mm a').format(checkInTime!)}';
      statusColor = const Color(0xFF4CAF50);
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'checked_out') {
      statusText = 'تم تسجيل الانصراف';
      statusColor = const Color(0xFF9E9E9E);
      statusIcon = Icons.logout_rounded;
    } else {
      statusText = 'لم يتم تسجيل الحضور بعد';
      statusColor = AppColors.warning;
      statusIcon = Icons.access_time_rounded;
    }

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D2006), Color(0xFF1A1A1A)],
        ),
      ),
      child: Column(
        children: [
          // الصف الأول
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeaderButton(
                    Icons.arrow_back_ios_new_rounded,
                    () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  _buildHeaderButton(
                    Icons.menu_rounded,
                    () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ],
              ),
              _buildHeaderButton(
                Icons.refresh_rounded,
                () {
                  HapticFeedback.lightImpact();
                  _fetchStatus();
                  _fetchStatistics();
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // الصف الثاني
          Row(
            children: [
              // أيقونة البصمة
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gold, AppColors.goldDark],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: Colors.black,
                  size: 32,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    duration: 500.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(width: 16),

              // المعلومات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getGreetingIcon(),
                          color: AppColors.gold,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getGreeting(),
                          style: GoogleFonts.cairo(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.username,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE، d MMMM', 'ar').format(DateTime.now()),
                      style: GoogleFonts.cairo(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // ساعات اليوم
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    Text(
                      totalHoursToday.toStringAsFixed(1),
                      style: GoogleFonts.cairo(
                        color: AppColors.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ساعة',
                      style: GoogleFonts.cairo(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // شريط الحالة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    statusText,
                    style: GoogleFonts.cairo(
                      color: statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (status == 'checked_in')
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fade(begin: 0.4, end: 1, duration: 1200.ms),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideY(begin: -0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DIGITAL CLOCK
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDigitalClock() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // الأيقونة
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: AppColors.gold,
              size: 22,
            ),
          ),

          const SizedBox(width: 20),

          // الساعة
          Text(
            DateFormat('hh:mm').format(_currentTime),
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(width: 8),

          // الثواني و AM/PM
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('ss').format(_currentTime),
                style: GoogleFonts.cairo(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('a').format(_currentTime),
                style: GoogleFonts.cairo(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // ═══════════════════════════════════════════════════════════════
  // FINGERPRINT BUTTON
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFingerprintButton() {
    final isCheckIn = status == 'not_checked_in';
    final color = isCheckIn ? const Color(0xFF4CAF50) : const Color(0xFFE91E63);
    final text = isCheckIn ? 'تسجيل حضور' : 'تسجيل انصراف';
    final icon = isCheckIn ? Icons.login_rounded : Icons.logout_rounded;

    return GestureDetector(
      onTap: processing ? null : _handleCheckInOut,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الدائرة الخارجية (Pulse)
          if (!processing)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 160 + (_pulseController.value * 20),
                  height: 160 + (_pulseController.value * 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.08 + (_pulseController.value * 0.08)),
                  ),
                );
              },
            ),

          // الدائرة الوسطى
          if (!processing)
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
            ),

          // الزر الرئيسي
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withOpacity(0.85)],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: processing
                ? const Center(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 36, color: Colors.white),
                      const SizedBox(height: 6),
                      Text(
                        text,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.9, 0.9),
          duration: 600.ms,
          curve: Curves.elasticOut,
        );
  }

  // ═══════════════════════════════════════════════════════════════
  // STATISTICS CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStatisticsCard() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: AppRadius.xxl,
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'أيام الحضور',
                '$attendanceDaysThisMonth',
                Icons.calendar_month_rounded,
                AppColors.gold,
              ),
              _buildDivider(),
              _buildStatItem(
                'ساعات اليوم',
                totalHoursToday.toStringAsFixed(1),
                Icons.timer_rounded,
                const Color(0xFF4CAF50),
              ),
              _buildDivider(),
              _buildStatItem(
                'التأخير',
                '$lateMinutes د',
                Icons.warning_amber_rounded,
                lateMinutes > 0 ? AppColors.warning : Colors.grey,
              ),
            ],
          ),
          if (lateMinutes > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'تأخير $lateMinutes دقيقة اليوم',
                    style: GoogleFonts.cairo(
                      color: AppColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
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
            color: Colors.grey[500],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.08),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TODAY RECORD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTodayRecord() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: AppRadius.xxl,
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // العنوان
          const AppSectionHeader(
            title: 'سجل اليوم',
            icon: Icons.history_rounded,
          ),

          const SizedBox(height: 18),

          // الحضور والانصراف
          Row(
            children: [
              Expanded(
                child: _buildTimeCard(
                  'الحضور',
                  checkInTime,
                  Icons.login_rounded,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeCard(
                  'الانصراف',
                  checkOutTime,
                  Icons.logout_rounded,
                  const Color(0xFFE91E63),
                ),
              ),
            ],
          ),

          // الموقع
          if (currentLatitude != null && currentLongitude != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _showLocationOnMap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.gold,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تم التسجيل من موقعك الحالي',
                        style: GoogleFonts.cairo(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'عرض',
                            style: GoogleFonts.cairo(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.gold,
                            size: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildTimeCard(
    String label,
    DateTime? time,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            time != null ? DateFormat('hh:mm a').format(time) : '--:--',
            style: GoogleFonts.cairo(
              color: time != null ? Colors.white : Colors.grey[600],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CHECKED OUT CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCheckedOutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.15),
            const Color(0xFF4CAF50).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: Color(0xFF4CAF50),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'انتهى يوم العمل! ',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إجمالي ساعات العمل: ${totalHoursToday.toStringAsFixed(1)} ساعة',
                  style: GoogleFonts.cairo(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '👋',
            style: GoogleFonts.cairo(fontSize: 28),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.95, 0.95), curve: Curves.elasticOut);
  }

  // ═══════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════

  void _showSuccessDialog(String message, bool isCheckIn) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isCheckIn
                  ? const Color(0xFF4CAF50).withOpacity(0.3)
                  : const Color(0xFFE91E63).withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isCheckIn ? const Color(0xFF4CAF50) : const Color(0xFFE91E63))
                    .withOpacity(0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // الأيقونة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isCheckIn
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE91E63))
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                  color: isCheckIn
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE91E63),
                  size: 40,
                ),
              )
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.elasticOut)
                  .then()
                  .shake(duration: 400.ms),

              const SizedBox(height: 20),

              // العنوان
              Text(
                isCheckIn ? 'تم تسجيل الحضور! ✅' : 'تم تسجيل الانصراف! 👋',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 10),

              // الرسالة
              Text(
                message,
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),

              // زر عرض الموقع
              if (currentLatitude != null && currentLongitude != null) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _showLocationOnMap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.map_rounded,
                          color: AppColors.gold,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'عرض الموقع',
                          style: GoogleFonts.cairo(
                            color: AppColors.gold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],

              const SizedBox(height: 20),

              // زر حسناً
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'حسناً',
                    style: GoogleFonts.cairo(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );

    // إغلاق تلقائي بعد 3 ثواني
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'حدث خطأ',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'إلغاء',
                          style: GoogleFonts.cairo(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _handleCheckInOut();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'إعادة المحاولة',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
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
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.gold,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'تواصل مع الدعم',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'يرجى التواصل مع إدارة الموارد البشرية\nلربط حسابك بالنظام',
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'حسناً',
                    style: GoogleFonts.cairo(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}