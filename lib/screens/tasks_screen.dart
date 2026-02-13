import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import '../constants.dart';
import 'add_interaction_screen.dart';
import 'opportunity_details_screen.dart';

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
  List<dynamic> employees = [];
  int? selectedEmployeeId;
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

  // ===================================
  // 📡 تحميل البيانات
  // ===================================

  Future<void> _loadData() async {
    setState(() => loading = true);
    await Future.wait([
      _fetchEmployees(),
      _fetchTasks(),
    ]);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/opportunities/employees'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => employees = data is List ? data : []);
      }
    } catch (e) {
      print('Error fetching employees: $e');
    }
  }

  Future<void> _fetchTasks() async {
    try {
      String url = '$baseUrl/api/tasks';
      if (selectedEmployeeId != null) {
        url += '?opportunityEmployeeId=$selectedEmployeeId';
      }

      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final List<dynamic> allTasks = jsonDecode(res.body);

        overdueTasks.clear();
        todayTasks.clear();
        tomorrowTasks.clear();
        upcomingTasks.clear();
        completedTasks.clear();

        for (var task in allTasks) {
          final status = task['TaskDueStatus'] ?? '';
          final taskStatus = task['Status'] ?? '';

          if (taskStatus == 'Completed') {
            completedTasks.add(task);
          } else if (status == 'Overdue') {
            overdueTasks.add(task);
          } else if (status == 'Today') {
            todayTasks.add(task);
          } else if (status == 'Tomorrow') {
            tomorrowTasks.add(task);
          } else {
            upcomingTasks.add(task);
          }
        }
        setState(() {});
      }
    } catch (e) {
      print('Error fetching tasks: $e');
    }
  }

  // ===================================
  // 📞 دوال الاتصال والواتساب
  // ===================================

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar('لا يوجد رقم هاتف', Colors.red);
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar('لا يوجد رقم هاتف', Colors.red);
      return;
    }
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('00')) cleanPhone = cleanPhone.substring(2);
    else if (cleanPhone.startsWith('0')) cleanPhone = '20${cleanPhone.substring(1)}';
    else if (cleanPhone.length == 10 && !cleanPhone.startsWith('20')) cleanPhone = '20$cleanPhone';

    try {
      await launchUrl(Uri.parse('https://wa.me/$cleanPhone'), mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('فشل فتح واتساب', Colors.red);
    }
  }

  // ===================================
  // 🔧 دوال مساعدة
  // ===================================

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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // فتح تفاصيل الفرصة
  void _openOpportunityDetails(dynamic task) async {
    if (task['OpportunityID'] == null) {
      _showSnackBar('لا توجد فرصة مرتبطة بهذه المهمة', Colors.orange);
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/opportunities/${task['OpportunityID']}'),
      );

      if (res.statusCode == 200) {
        final opportunity = jsonDecode(res.body);
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OpportunityDetailsScreen(
                opportunity: opportunity,
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          );
          _loadData();
        }
      }
    } catch (e) {
      _showSnackBar('خطأ في تحميل الفرصة', Colors.red);
    }
  }

  // فتح تسجيل تواصل
  void _openAddInteraction(dynamic task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddInteractionScreen(
          userId: widget.userId,
          username: widget.username,
          preSelectedPartyId: task['PartyID'],
          preSelectedOpportunityId: task['OpportunityID'],
        ),
      ),
    );

    if (result == true) _loadData();
  }

  // ===================================
  // 🔍 فلتر الموظفين
  // ===================================

  void _showEmployeeFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'فلتر حسب صاحب الفرصة',
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[800],
                child: const Icon(Icons.all_inclusive, color: Colors.white),
              ),
              title: Text(
                'كل الموظفين',
                style: GoogleFonts.cairo(
                  color: selectedEmployeeId == null ? const Color(0xFFFFD700) : Colors.white,
                ),
              ),
              onTap: () {
                setState(() => selectedEmployeeId = null);
                Navigator.pop(context);
                _fetchTasks();
              },
            ),
            const Divider(color: Colors.grey),
            Expanded(
              child: ListView.builder(
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final emp = employees[index];
                  final isSelected = selectedEmployeeId == emp['EmployeeID'];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFD700).withOpacity(isSelected ? 0.3 : 0.1),
                      child: Text(
                        emp['FullName'][0],
                        style: GoogleFonts.cairo(color: const Color(0xFFFFD700)),
                      ),
                    ),
                    title: Text(
                      emp['FullName'],
                      style: GoogleFonts.cairo(
                        color: isSelected ? const Color(0xFFFFD700) : Colors.white,
                      ),
                    ),
                    onTap: () {
                      setState(() => selectedEmployeeId = emp['EmployeeID']);
                      Navigator.pop(context);
                      _fetchTasks();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================
  // 🏗️ البناء
  // ===================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const FaIcon(FontAwesomeIcons.listCheck, color: Color(0xFFFFD700), size: 20),
            const SizedBox(width: 10),
            Text(
              'المهام',
              style: GoogleFonts.cairo(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: selectedEmployeeId != null,
              label: const Icon(Icons.filter_alt, size: 10),
              child: const FaIcon(FontAwesomeIcons.filter, color: Colors.white),
            ),
            onPressed: _showEmployeeFilter,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFFFFD700),
          tabs: [
            _buildTab('متأخرة', overdueTasks.length, Colors.red),
            _buildTab('اليوم', todayTasks.length, Colors.orange),
            _buildTab('غداً', tomorrowTasks.length, Colors.blue),
            _buildTab('قادم', upcomingTasks.length, Colors.green),
            _buildTab('مكتملة', completedTasks.length, Colors.grey),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTaskList(overdueTasks),
                  _buildTaskList(todayTasks),
                  _buildTaskList(tomorrowTasks),
                  _buildTaskList(upcomingTasks),
                  _buildTaskList(completedTasks),
                ],
              ),
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
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskList(List<dynamic> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(FontAwesomeIcons.inbox, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text('لا توجد مهام', style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 18)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) => _buildTaskCard(tasks[index], index),
    );
  }

  Widget _buildTaskCard(dynamic task, int index) {
    final bool isHigh = task['Priority'] == 'High';
    final Color priorityColor = isHigh ? Colors.red : Colors.orange;
    final bool isCompleted = task['Status'] == 'Completed';

    // تنسيق تاريخ آخر تواصل
    String lastContactInfo = 'لا يوجد';
    if (task['LastContactDate'] != null) {
      try {
        final dt = DateTime.parse(task['LastContactDate']);
        final days = DateTime.now().difference(dt).inDays;
        if (days == 0) lastContactInfo = 'اليوم';
        else if (days == 1) lastContactInfo = 'من يوم';
        else if (days == 2) lastContactInfo = 'من يومين';
        else lastContactInfo = 'من $days يوم';
        lastContactInfo += ' (${dt.day}/${dt.month}/${dt.year})';
      } catch (e) {}
    }

    final String oppOwner = task['OpportunityOwnerName'] ?? 'غير محدد';

    return Dismissible(
      key: Key(task['TaskID'].toString()),
      background: _buildSwipeBackground(
        Colors.green,
        FontAwesomeIcons.phone,
        'اتصال',
        Alignment.centerRight,
      ),
      secondaryBackground: _buildSwipeBackground(
        const Color(0xFF25D366),
        FontAwesomeIcons.whatsapp,
        'واتساب',
        Alignment.centerLeft,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _makePhoneCall(task['Phone']);
        } else {
          _openWhatsApp(task['Phone']);
        }
        return false;
      },
      child: GestureDetector(
        onTap: () => _openOpportunityDetails(task),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              right: BorderSide(
                color: isCompleted ? Colors.grey : priorityColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصف 1: وصف المهمة
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isCompleted ? Colors.grey : priorityColor).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FaIcon(
                        isCompleted
                            ? FontAwesomeIcons.circleCheck
                            : (isHigh ? FontAwesomeIcons.fire : FontAwesomeIcons.clipboard),
                        color: isCompleted ? Colors.grey : priorityColor,
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
                            task['TaskTypeNameAr'] ?? 'متابعة عامة',
                            style: GoogleFonts.cairo(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(color: Colors.grey.withOpacity(0.2)),
                const SizedBox(height: 12),

                // الصف 2: بيانات العميل
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const FaIcon(FontAwesomeIcons.user, color: Colors.grey, size: 13),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task['ClientName'] ?? 'بدون اسم',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const FaIcon(FontAwesomeIcons.crown, color: Color(0xFFFFD700), size: 12),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'خاص بـ: $oppOwner',
                                  style: GoogleFonts.cairo(color: const Color(0xFFFFD700), fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const FaIcon(FontAwesomeIcons.clockRotateLeft, color: Colors.grey, size: 12),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'آخر تواصل: $lastContactInfo',
                                  style: GoogleFonts.cairo(color: Colors.grey[400], fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // التاريخ والمكلف
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            intl.DateFormat('dd/MM').format(DateTime.parse(task['DueDate'])),
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatTime(task['DueTime']),
                            style: GoogleFonts.cairo(color: Colors.grey, fontSize: 11),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                task['AssignedToName']?.split(' ')[0] ?? 'مجهول',
                                style: GoogleFonts.cairo(
                                  color: Colors.blue[300],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const FaIcon(FontAwesomeIcons.userCheck, color: Colors.blue, size: 10),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (!isCompleted) ...[
                  const SizedBox(height: 16),

                  // الصف 3: الأزرار
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'اتصال',
                          Colors.green,
                          FontAwesomeIcons.phone,
                          () => _makePhoneCall(task['Phone']),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          'واتساب',
                          const Color(0xFF25D366),
                          FontAwesomeIcons.whatsapp,
                          () => _openWhatsApp(task['Phone']),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          'تسجيل تواصل',
                          const Color(0xFFFFD700),
                          FontAwesomeIcons.commentMedical,
                          () => _openAddInteraction(task),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1);
  }

  Widget _buildSwipeBackground(Color color, IconData icon, String label, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Text(label, style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
          ],
          FaIcon(icon, color: color, size: 24),
          if (alignment == Alignment.centerRight) ...[
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, IconData icon, VoidCallback onTap) {
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
            FaIcon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.cairo(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}