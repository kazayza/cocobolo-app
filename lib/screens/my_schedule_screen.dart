import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../constants.dart';

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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          _isChangingMonth = false;
        });
      }
      print('Error fetching schedule: $e');
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
      final end = shift['EndDate'] != null ? DateTime.parse(shift['EndDate']) : null;
      final dayNormalized = DateTime(day.year, day.month, day.day);
      final startNormalized = DateTime(start.year, start.month, start.day);
      
      if (dayNormalized.isAtSameMomentAs(startNormalized) || 
          (dayNormalized.isAfter(startNormalized) && (end == null || dayNormalized.isBefore(end.add(const Duration(days: 1)))))) {
        return shift;
      }
    }
    return null;
  }

  Color _getShiftColor(String? shiftType) {
    if (shiftType == null) return Colors.grey;
    return shiftType == 'صباحي' ? Colors.orange : Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8B923).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month, color: Color(0xFFE8B923), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'مواعيد الشيفتات الشهرية',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isChangingMonth)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFFE8B923),
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(color: Color(0xFFE8B923), strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'جاري تحميل جدولك...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF2A2A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('أيام العمل', totalWorkingDays.toString(), Icons.work, Colors.blue),
          _buildStatItem('حضور', presentDays.toString(), Icons.check_circle, Colors.green),
          _buildStatItem('غياب', absentDays.toString(), Icons.cancel, Colors.red),
          _buildStatItem('تأخير', lateDays.toString(), Icons.warning, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.saturday,
            locale: 'ar',
            
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
              rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
              headerPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            
            calendarStyle: CalendarStyle(
              defaultTextStyle: GoogleFonts.cairo(color: Colors.white, fontSize: 14),
              weekendTextStyle: GoogleFonts.cairo(color: Colors.red[300], fontSize: 14),
              todayDecoration: BoxDecoration(
                color: const Color(0xFFE8B923).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              todayTextStyle: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFFE8B923),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold),
              cellMargin: const EdgeInsets.all(4),
            ),
            
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: GoogleFonts.cairo(color: Colors.grey[400], fontWeight: FontWeight.bold),
              weekendStyle: GoogleFonts.cairo(color: Colors.red[300], fontWeight: FontWeight.bold),
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
                
                Color attendanceColor = Colors.green;
                if (hasAttendance && events.first is Map) {
                  final event = events.first as Map;
                  if (event['late'] != null && event['late'] > 0) {
                    attendanceColor = Colors.orange;
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
                            color: _getShiftColor(shift['ShiftType']).withOpacity(0.5),
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
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE8B923)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayDetails() {
  if (_selectedDay == null) return const SizedBox();

  final shift = _getShiftForDay(_selectedDay!);
  final events = _getEventsForDay(_selectedDay!);
  final attendanceData = events.isNotEmpty ? events.first : null;
  final shiftColor = _getShiftColor(shift?['ShiftType']);
  final isPast = _selectedDay!.isBefore(DateTime.now());

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      color: Color(0xFF1A1A1A),
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: SingleChildScrollView(  // ✅ صح - من غير تعليق داخل الـ constructor
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس التفاصيل
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B923).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline, color: Color(0xFFE8B923), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('EEEE, d MMMM yyyy', 'ar').format(_selectedDay!),
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // كارت الشيفت
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  shiftColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: shiftColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: shiftColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    shift?['ShiftType'] == 'صباحي' ? Icons.wb_sunny : Icons.nights_stay,
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
                        style: GoogleFonts.cairo(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shift != null
                            ? '${shift['ShiftType']} (${shift['StartTime']} - ${shift['EndTime']})'
                            : 'لا يوجد شيفت محدد',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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
          
          // كارت الحضور - مع الفواصل الصحيحة
          if (attendanceData != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeBox(
                          'الحضور',
                          attendanceData['checkIn'] ?? '--:--',
                          Icons.login,
                          Colors.green,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: const Icon(Icons.arrow_forward, color: Color(0xFFE8B923), size: 16),
                      ),
                      Expanded(
                        child: _buildTimeBox(
                          'الانصراف',
                          attendanceData['checkOut'] ?? '--:--',
                          Icons.logout,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                  
                  if (attendanceData['late'] > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تأخير ${attendanceData['late']} دقيقة',
                              style: GoogleFonts.cairo(
                                color: Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
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
            // حالة الغياب
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحالة',
                          style: GoogleFonts.cairo(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'غياب',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (shift != null) ...[
            // شيفت مستقبلي
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hourglass_empty, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحالة',
                          style: GoogleFonts.cairo(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'لم يحن بعد',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildTimeBox(String label, String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
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
                style: GoogleFonts.cairo(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}