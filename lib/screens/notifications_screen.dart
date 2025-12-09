import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants.dart';

class NotificationsScreen extends StatefulWidget {
  final int userId;
  final String? username;
  
  const NotificationsScreen({
    Key? key, 
    required this.userId,
    this.username,
  }) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/notifications?username=${widget.username}'),
      );
      if (res.statusCode == 200) {
        setState(() {
          notifications = jsonDecode(res.body);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
      );
      fetchNotifications();
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await http.put(
        Uri.parse('$baseUrl/api/notifications/read-all'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': widget.username}),
      );
      fetchNotifications();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديد الكل كمقروء', style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((n) => n['IsRead'] == false).length;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          'الإشعارات',
          style: GoogleFonts.cairo(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE8B923),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.black, size: 20),
              label: Text(
                'قراءة الكل',
                style: GoogleFonts.cairo(color: Colors.black, fontSize: 12),
              ),
            ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            )
          : notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 20),
          Text(
            'لا توجد إشعارات',
            style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return RefreshIndicator(
      onRefresh: fetchNotifications,
      color: const Color(0xFFE8B923),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _buildNotificationCard(notification, index);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, int index) {
    final isRead = notification['IsRead'] == true;
    
    return Card(
      color: isRead 
          ? Colors.white.withOpacity(0.05)
          : Colors.white.withOpacity(0.12),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isRead
            ? BorderSide.none
            : const BorderSide(color: Color(0xFFFFD700), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!isRead) {
            markAsRead(notification['NotificationID']);
          }
          // TODO: فتح الشاشة المرتبطة حسب RelatedTable
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الأيقونة
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isRead
                      ? Colors.grey.withOpacity(0.2)
                      : const Color(0xFFFFD700).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getNotificationIcon(notification['RelatedTable']),
                  color: isRead ? Colors.grey : const Color(0xFFFFD700),
                  size: 26,
                ),
              ),
              
              const SizedBox(width: 14),
              
              // المحتوى
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // العنوان
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['Title'] ?? 'إشعار',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFD700),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // الرسالة
                    Text(
                      notification['Message'] ?? '',
                      style: GoogleFonts.cairo(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // التاريخ والمرسل
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          notification['CreatedAt'] ?? '',
                          style: GoogleFonts.cairo(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'من: ${notification['CreatedBy'] ?? ''}',
                          style: GoogleFonts.cairo(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 400.ms)
        .slideX(begin: 0.1, end: 0);
  }

  IconData _getNotificationIcon(String? relatedTable) {
    switch (relatedTable?.toLowerCase()) {
      case 'crm_tasks':
        return Icons.task_alt;
      case 'salesopportunities':
        return Icons.lightbulb;
      case 'parties':
        return Icons.person;
      case 'transactions':
        return Icons.receipt;
      case 'expenses':
        return Icons.money_off;
      default:
        return Icons.notifications;
    }
  }
}