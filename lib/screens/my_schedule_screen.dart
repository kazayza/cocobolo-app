import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../services/theme_service.dart';
import '../widgets/design_kit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../core/auth/session_service.dart';

import '../widgets/app_drawer.dart';

class MyScheduleScreen extends StatefulWidget {
  final int userId;
  final String username;

  const MyScheduleScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool loading = true;
  bool _isChangingMonth = false;

  // Cache للتخزين المؤقت
  final Map<String, dynamic> _monthCache = {};

  // البيانات
  List<dynamic> shifts = [];
  List<dynamic> attendance = [];
  Map<DateTime, List<dynamic>> _events = {};

  // إحصائيات سريعة
  int totalWorkingDays = 0;
  int presentDays = 0;
  int absentDays = 0;
  int lateDays = 0;

  bool get _isDark => ThemeService().isDarkMode;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    final monthKey = '${_focusedDay.year}-${_focusedDay.month}';

    // لو البيانات موجودة في الكاش، استخدمها فوراً
    if (_monthCache.containsKey(monthKey)) {
      final data = _monthCache[monthKey];
      setState(() {
        shifts = data['shifts'];
        attendance = data['attendance'];
        _calculateStats();
        _groupEvents();
        loading = false;
        _isChangingMonth = false;
      });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/shifts/my-schedule/${widget.userId}'
            '?year=${_focusedDay.year}&month=${_focusedDay.month}'),
        headers: SessionService.instance.authHeaders,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // خزن في الكاش
        _monthCache[monthKey] = {
          'shifts': data['shifts'],
          'attendance': data['attendance'],
        };

        if (mounted) {
          setState(() {
            shifts = data['shifts'];
            attendance = data['attendance'];
            _calculateStats();
            _groupEvents();
            loading = false;
            _isChangingMonth = false;
          });
        }
      } else if (mounted) {
        setState(() {
          loading = false;
          _isChangingMonth = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          _isChangingMonth = false;
        });
      }
    }
  }

  void _calculateStats() {
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    totalWorkingDays = 0;

    for (int i = 1; i <= daysInMonth; i++) {
      final day = DateTime(_focusedDay.year, _focusedDay.month, i);
      if (_getShiftForDay(day) != null) {
        totalWorkingDays++;
      }
    }

    presentDays = attendance.length;
    absentDays = totalWorkingDays - presentDays;
    lateDays = attendance.where((a) => (a['LateMinutes'] ?? 0) > 0).length;
  }

  void _groupEvents() {
    _events = {};
    for (var att in attendance) {
      final date = DateTime.parse(att['LogDate']);
      final key = DateTime(date.year, date.month, date.day);
      if (_events[key] == null) _events[key] = [];
      _events[key]!.add({
        'type': 'attendance',
        'status': att['Status'],
        'checkIn': att['CheckIn'],
        'checkOut': att['CheckOut'],
        'late': att['LateMinutes'] ?? 0,
      });
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  Map<String, dynamic>? _getShiftForDay(DateTime day) {
    for (var shift in shifts) {
      final start = DateTime.parse(shift['StartDate']);
      final end =
          shift['EndDate'] != null ? DateTime.parse(shift['EndDate']) : null;
      final dayNormalized = DateTime(day.year, day.month, day.day);
      final startNormalized = DateTime(start.year, start.month, start.day);

      if (dayNormalized.isAtSameMomentAs(startNormalized) ||
          (dayNormalized.isAfter(startNormalized) &&
              (end == null ||
                  dayNormalized.isBefore(end.add(const Duration(days: 1)))))) {
        return shift;
      }
    }
    return null;
  }

  /// لون نوع الشيفت بالمقارنة بالنص المخزَّن حرفيًا («صباحى» بألف
  /// مقصورة — كانت المقارنة بـ«صباحي» فلا ينطبق لون الصباحى أبدًا)
  Color _getShiftColor(String? shiftType) {
    switch (shiftType) {
      case 'صباحى':
        return _isDark ? AppColors.successLight : AppColors.success;
      case 'مسائى':
        return _isDark ? AppColors.warningLight : AppColors.warning;
      case 'عمل يومى':
        return _isDark ? AppColors.infoLight : AppColors.info;
      default:
        return _isDark ? AppColors.neutralLight : AppColors.neutral;
    }
  }

  IconData _getShiftIcon(String? shiftType) {
    switch (shiftType) {
      case 'صباحى':
        return Icons.wb_sunny_rounded;
      case 'مسائى':
        return Icons.nights_stay_rounded;
      case 'عمل يومى':
        return Icons.work_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: buildAppDrawer(currentRoute: 'frm_MySchedule'),
      backgroundColor: AppColors.background(_isDark),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'مواعيد الشيفتات الشهرية',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
            ),
          ],
        ),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: const AppDrawerMenuButton(),
        actions: [
          if (_isChangingMonth)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: _fetchSchedule,
            ),
        ],
      ),
      body: loading
          ? _buildLoadingState()
          : Column(
              children: [
                _buildStatsRow(),
                _buildCalendar(),
                Expanded(
                  child: _buildDayDetails(),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return const AppLoading(message: 'جاري تحميل جدولك...');
  }

  // بطاقة مرساة كحلية بإحصائيات الشهر — هوية الشاشة في الوضعين
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppGradients.identityHeader,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyDark.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem('أيام العمل', totalWorkingDays.toString(),
                  Icons.work_rounded, AppColors.infoLight),
            ),
            Expanded(
              child: _buildStatItem('حضور', presentDays.toString(),
                  Icons.check_circle_rounded, AppColors.successLight),
            ),
            Expanded(
              child: _buildStatItem('غياب', absentDays.toString(),
                  Icons.cancel_rounded, AppColors.errorLight),
            ),
            Expanded(
              child: _buildStatItem('تأخير', lateDays.toString(),
                  Icons.warning_rounded, AppColors.warningLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(height: 4),
        AmountText(value: value, color: Colors.white, size: 15),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
              ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    final textTheme = Theme.of(context).textTheme;
    final dayTextStyle = textTheme.bodyMedium?.copyWith(
      color: AppColors.text(_isDark),
      fontSize: 13.5,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.divider(_isDark)),
        ),
        child: Stack(
          children: [
            TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2035),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.saturday,
              locale: 'ar',

              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: textTheme.titleMedium?.copyWith(
                      color: AppColors.text(_isDark),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ) ??
                    const TextStyle(),
                leftChevronIcon: Icon(Icons.chevron_left_rounded,
                    color: AppColors.text(_isDark), size: 20),
                rightChevronIcon: Icon(Icons.chevron_right_rounded,
                    color: AppColors.text(_isDark), size: 20),
                headerPadding: const EdgeInsets.symmetric(vertical: 10),
              ),

              calendarStyle: CalendarStyle(
                defaultTextStyle: dayTextStyle ?? const TextStyle(),
                weekendTextStyle: (dayTextStyle ?? const TextStyle())
                    .copyWith(color: AppColors.textSecondary(_isDark)),
                todayDecoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: _isDark ? 0.25 : 0.18),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: (dayTextStyle ?? const TextStyle())
                    .copyWith(fontWeight: FontWeight.w800),
                selectedDecoration: BoxDecoration(
                  color: _isDark ? AppColors.gold : AppColors.navy,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(
                  color: _isDark ? AppColors.navy : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                outsideTextStyle: (dayTextStyle ?? const TextStyle())
                    .copyWith(color: AppColors.textHint(_isDark)),
                cellMargin: const EdgeInsets.all(4),
              ),

              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(),
                weekendStyle: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary(_isDark),
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(),
              ),

              eventLoader: _getEventsForDay,

              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },

              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                  _isChangingMonth = true;
                });
                Future.delayed(const Duration(milliseconds: 100), () {
                  _fetchSchedule();
                });
              },

              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final shift = _getShiftForDay(date);
                  final hasAttendance = events.isNotEmpty;

                  if (!hasAttendance && shift == null) return null;

                  Color attendanceColor =
                      _isDark ? AppColors.successLight : AppColors.success;
                  if (hasAttendance && events.first is Map) {
                    final event = events.first as Map;
                    if (event['late'] != null && event['late'] > 0) {
                      attendanceColor =
                          _isDark ? AppColors.warningLight : AppColors.warning;
                    }
                  }

                  return Positioned(
                    bottom: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (shift != null)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: _getShiftColor(shift['ShiftType'])
                                  .withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (hasAttendance)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: attendanceColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            if (_isChangingMonth)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background(_isDark)
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetails() {
    if (_selectedDay == null) return const SizedBox();

    final shift = _getShiftForDay(_selectedDay!);
    final events = _getEventsForDay(_selectedDay!);
    final attendanceData = events.isNotEmpty ? events.first : null;
    final shiftColor = _getShiftColor(shift?['ShiftType']);
    final isPast = _selectedDay!
        .isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(_isDark),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.divider(_isDark)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                title:
                    DateFormat('EEEE, d MMMM yyyy', 'ar').format(_selectedDay!),
                icon: Icons.info_outline_rounded,
                accent: ThemeService().accentColor,
              ),

              const SizedBox(height: 16),

              // كارت الشيفت المخطط
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: shiftColor.withValues(alpha: _isDark ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border:
                      Border.all(color: shiftColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            shiftColor.withValues(alpha: _isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getShiftIcon(shift?['ShiftType']),
                        color: shiftColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الشيفت المخطط',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary(_isDark),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            shift != null
                                ? '${shift['ShiftType']} (${shift['StartTime']} - ${shift['EndTime']})'
                                : 'لا يوجد شيفت محدد',
                            style: textTheme.titleSmall?.copyWith(
                              color: AppColors.text(_isDark),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (attendanceData != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : AppColors.inputFill(_isDark),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.divider(_isDark)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimeBox(
                              'الحضور',
                              attendanceData['checkIn'] ?? '--:--',
                              Icons.login_rounded,
                              _isDark
                                  ? AppColors.successLight
                                  : AppColors.success,
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward_rounded,
                                color: ThemeService().accentColor, size: 16),
                          ),
                          Expanded(
                            child: _buildTimeBox(
                              'الانصراف',
                              attendanceData['checkOut'] ?? '--:--',
                              Icons.logout_rounded,
                              _isDark
                                  ? AppColors.errorLight
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      if (attendanceData['late'] > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (_isDark
                                    ? AppColors.warningLight
                                    : AppColors.warning)
                                .withValues(alpha: _isDark ? 0.16 : 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: (_isDark
                                        ? AppColors.warningLight
                                        : AppColors.warning)
                                    .withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: _isDark
                                      ? AppColors.warningLight
                                      : AppColors.warning,
                                  size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تأخير ${attendanceData['late']} دقيقة',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: _isDark
                                        ? AppColors.warningLight
                                        : AppColors.warning,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else if (shift != null && isPast) ...[
                _buildStateCard(
                  Icons.close_rounded,
                  _isDark ? AppColors.errorLight : AppColors.error,
                  'غياب',
                ),
              ] else if (shift != null) ...[
                _buildStateCard(
                  Icons.hourglass_empty_rounded,
                  _isDark ? AppColors.infoLight : AppColors.info,
                  'لم يحن بعد',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard(IconData icon, Color color, String status) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: _isDark ? 0.18 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الحالة',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary(_isDark),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.text(_isDark),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(label: status, color: color, small: true),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String label, String time, IconData icon, Color color) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary(_isDark),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            time,
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.text(_isDark),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
