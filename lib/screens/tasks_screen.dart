import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

class TasksScreen extends StatefulWidget {
  final int userId;
  final String username;

  const TasksScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> overdueTasks = [];
  List<dynamic> todayTasks = [];
  List<dynamic> tomorrowTasks = [];
  List<dynamic> upcomingTasks = [];
  List<dynamic> completedTasks = [];
  Map<String, dynamic> summary = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
    });

    try {
      // جلب كل المهام مرة واحدة وتقسيمهم
      final res = await http.get(Uri.parse('$baseUrl/api/tasks'));
      
      if (res.statusCode == 200) {
        final List<dynamic> allTasks = jsonDecode(res.body);
        
        // تصفير القوائم
        overdueTasks = [];
        todayTasks = [];
        tomorrowTasks = [];
        upcomingTasks = [];
        completedTasks = [];
        
        // تقسيم المهام حسب الحالة
        for (var task in allTasks) {
          final status = task['TaskDueStatus'] ?? task['Status'] ?? '';
          
          if (task['Status'] == 'Completed') {
            completedTasks.add(task);
          } else if (status == 'Overdue') {
            overdueTasks.add(task);
          } else if (status == 'Today') {
            todayTasks.add(task);
          } else if (status == 'Tomorrow') {
            tomorrowTasks.add(task);
          } else if (status == 'Upcoming') {
            upcomingTasks.add(task);
          } else {
            // لو مفيش حالة، نضيفها للقادم
            upcomingTasks.add(task);
          }
        }
        
        // تحديث الـ summary
        summary = {
          'overdueTasks': overdueTasks.length,
          'todayTasks': todayTasks.length,
          'tomorrowTasks': tomorrowTasks.length,
          'upcomingTasks': upcomingTasks.length,
          'completedTasks': completedTasks.length,
        };
      }
    } catch (e) {
      print('Error loading tasks: $e');
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  // تنسيق التاريخ
  String _formatDate(dynamic date) {
    if (date == null) return 'غير محدد';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (e) {
      return 'غير محدد';
    }
  }

  // تنسيق الوقت
  String _formatTime(dynamic time) {
    if (time == null) return '';
    try {
      if (time.toString().contains(':')) {
        final parts = time.toString().split(':');
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'م' : 'ص';
        final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$hour12:$minute $period';
      }
      return time.toString();
    } catch (e) {
      return '';
    }
  }

  // تنسيق التاريخ والوقت معاً
  String _formatDateTime(dynamic date, dynamic time) {
    final dateStr = _formatDate(date);
    final timeStr = _formatTime(time);
    if (timeStr.isNotEmpty) {
      return '$dateStr - $timeStr';
    }
    return dateStr;
  }

  // الاتصال
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

  // واتساب
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('فشل فتح واتساب', Colors.red);
    }
  }

  // إكمال المهمة
  Future<void> _completeTask(dynamic task) async {
    final taskId = task['TaskID'];
    
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/tasks/$taskId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': 'Completed',
          'completedBy': widget.username,
          'completionNotes': 'تم الإكمال من التطبيق',
        }),
      );

      if (res.statusCode == 200) {
        _showSnackBar('تم إكمال المهمة بنجاح ✓', Colors.green);
        _loadData(); // إعادة تحميل البيانات
      } else {
        _showSnackBar('فشل إكمال المهمة', Colors.red);
      }
    } catch (e) {
      _showSnackBar('خطأ: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // لون الحالة
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Overdue':
        return Colors.red;
      case 'Today':
        return Colors.orange;
      case 'Tomorrow':
        return Colors.blue;
      case 'Upcoming':
        return Colors.green;
      case 'Completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // نص الحالة
  String _getStatusText(String status, {int? daysOverdue, int? daysUntilDue}) {
    switch (status) {
      case 'Overdue':
        return daysOverdue != null ? 'متأخر $daysOverdue يوم' : 'متأخر';
      case 'Today':
        return 'اليوم';
      case 'Tomorrow':
        return 'غداً';
      case 'Upcoming':
        return daysUntilDue != null ? 'بعد $daysUntilDue يوم' : 'قادم';
      case 'Completed':
        return 'مكتملة';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: _buildAppBar(),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFFFFD700),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(overdueTasks, 'Overdue'),
                  _buildTaskList(todayTasks, 'Today'),
                  _buildTaskList(tomorrowTasks, 'Tomorrow'),
                  _buildTaskList(upcomingTasks, 'Upcoming'),
                  _buildTaskList(completedTasks, 'Completed'),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFFD700),
        onPressed: () {
          // إضافة مهمة جديدة
        },
        icon: const FaIcon(FontAwesomeIcons.plus, color: Colors.black, size: 18),
        label: Text('مهمة جديدة', style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(FontAwesomeIcons.listCheck, color: Color(0xFFFFD700), size: 20),
          const SizedBox(width: 10),
          Text('المهام', style: GoogleFonts.cairo(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        ],
      ),
      centerTitle: true,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFFFFD700),
        labelColor: const Color(0xFFFFD700),
        unselectedLabelColor: Colors.grey,
        tabAlignment: TabAlignment.center,
        tabs: [
          _buildTab('متأخرة', overdueTasks.length, Colors.red),
          _buildTab('اليوم', todayTasks.length, Colors.orange),
          _buildTab('غداً', tomorrowTasks.length, Colors.blue),
          _buildTab('قادم', upcomingTasks.length, Colors.green),
          _buildTab('مكتملة', completedTasks.length, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.cairo(fontSize: 13)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskList(List<dynamic> tasks, String status) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              status == 'Overdue'
                  ? FontAwesomeIcons.triangleExclamation
                  : status == 'Completed'
                      ? FontAwesomeIcons.circleCheck
                      : FontAwesomeIcons.clipboardList,
              size: 60,
              color: _getStatusColor(status).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              status == 'Overdue'
                  ? 'لا توجد مهام متأخرة 🎉'
                  : status == 'Completed'
                      ? 'لا توجد مهام مكتملة'
                      : 'لا توجد مهام',
              style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return _buildTaskCard(tasks[index], index, status);
      },
    );
  }

  Widget _buildTaskCard(dynamic task, int index, String status) {
    final bool isHigh = task['Priority'] == 'High';
    final Color priorityColor = isHigh ? Colors.red : Colors.orange;
    final Color statusColor = _getStatusColor(status);
    final bool isCompleted = status == 'Completed';

    return Dismissible(
      key: Key(task['TaskID'].toString()),
      direction: isCompleted ? DismissDirection.none : DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.circleCheck, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text('إكمال', style: GoogleFonts.cairo(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        await _completeTask(task);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isCompleted ? 0.03 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            right: BorderSide(color: statusColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: الوصف + الأولوية
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FaIcon(
                      isHigh ? FontAwesomeIcons.fire : FontAwesomeIcons.clipboard,
                      color: priorityColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['TaskDescription'] ?? 'مهمة',
                          style: GoogleFonts.cairo(
                            color: isCompleted ? Colors.grey : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task['TaskTypeNameAr'] ?? task['TaskTypeName'] ?? 'متابعة',
                          style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _getStatusText(
                        status,
                        daysOverdue: task['DaysOverdue'],
                        daysUntilDue: task['DaysUntilDue'],
                      ),
                      style: GoogleFonts.cairo(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: Colors.grey.withOpacity(0.2), height: 1),
              const SizedBox(height: 12),

              // الصف الثاني: العميل + التاريخ
              Row(
                children: [
                  // العميل
                  if (task['ClientName'] != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(FontAwesomeIcons.user, color: Colors.grey, size: 12),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                task['ClientName'],
                                style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // التاريخ والوقت
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.calendar, color: Colors.grey, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateTime(task['DueDate'], task['DueTime']),
                          style: GoogleFonts.cairo(color: Colors.grey[300], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // الصف الثالث: الموظف
              if (task['AssignedToName'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(FontAwesomeIcons.userTie, color: Color(0xFFFFD700), size: 12),
                      const SizedBox(width: 6),
                      Text(
                        task['AssignedToName'],
                        style: GoogleFonts.cairo(color: const Color(0xFFFFD700), fontSize: 12),
                      ),
                    ],
                  ),
                ),

              // الأزرار (لو مش مكتملة)
              if (!isCompleted) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: FontAwesomeIcons.circleCheck,
                        label: 'إكمال',
                        color: Colors.green,
                        onTap: () => _completeTask(task),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: FontAwesomeIcons.phone,
                        label: 'اتصال',
                        color: Colors.blue,
                        onTap: () => _makePhoneCall(task['Phone']),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: FontAwesomeIcons.whatsapp,
                        label: 'واتساب',
                        color: const Color(0xFF25D366),
                        onTap: () => _openWhatsApp(task['Phone']),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1, end: 0);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.cairo(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}