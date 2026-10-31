import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/network/api_client.dart';
import '../features/home/widgets/home_accent.dart';
import '../services/app_colors.dart';
import '../services/design_tokens.dart';
import '../widgets/design_kit.dart';
import '../core/notifications/notification_navigator.dart';
import '../core/notifications/blazor_form_routes.dart';
import 'add_expense_screen.dart';
import 'products_screen.dart';

/// ─────────────────────────────────────────────────────────────
///  الإشعارات — Theme-aware (ليلي/نهاري)
///  + بحث في الإشعارات + إحصائيات (الكل / مقروء / غير مقروء)
/// ─────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  final int userId;
  final String? username;

  const NotificationsScreen({Key? key, required this.userId, this.username})
    : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notifications = [];
  List<dynamic> _filtered = [];
  bool loading = true;
  String _searchText = '';
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      // forceRefresh: بعد «تعليم كمقروء»/«قراءة الكل» يجب أن تعكس القائمة
      // والإحصائيات حالة الخادم فورًا، لا كاش الـ٢٤ ساعة.
      // (عند انقطاع الشبكة يرجع ApiClient للكاش كاحتياط تلقائيًا.)
      final res = await ApiClient.instance.get(
        '/api/notifications',
        forceRefresh: true,
      );
      final data = ApiClient.instance.decode(res);
      if (!mounted) return;
      setState(() {
        notifications = data is List ? data : [];
        _applyFilter();
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _applyFilter() {
    var list = notifications;
    if (_showUnreadOnly) {
      list = list.where((n) => n['IsRead'] != true).toList();
    }
    if (_searchText.trim().isNotEmpty) {
      final q = _searchText.trim().toLowerCase();
      list = list.where((n) {
        final title = (n['Title'] ?? '').toString().toLowerCase();
        final message = (n['Message'] ?? '').toString().toLowerCase();
        final sender = (n['CreatedBy'] ?? '').toString().toLowerCase();
        return title.contains(q) || message.contains(q) || sender.contains(q);
      }).toList();
    }
    _filtered = list;
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final res = await ApiClient.instance.put(
        '/api/notifications/$notificationId/read',
      );
      ApiClient.instance.decode(res);
      fetchNotifications();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final res = await ApiClient.instance.put('/api/notifications/read-all');
      ApiClient.instance.decode(res);
      fetchNotifications();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد الكل كمقروء'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final total = notifications.length;
    final unread = notifications.where((n) => n['IsRead'] != true).length;
    final read = total - unread;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        centerTitle: true,
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 20),
              label: const Text('قراءة الكل', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── الإحصائيات ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: AppStatCard(
                    label: 'الكل',
                    value: '$total',
                    color: HomeAccent.indigo,
                    icon: Icons.notifications_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppStatCard(
                    label: 'مقروء',
                    value: '$read',
                    color: AppColors.success,
                    icon: Icons.done_all_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppStatCard(
                    label: 'غير مقروء',
                    value: '$unread',
                    color: AppColors.error,
                    icon: Icons.notifications_active_rounded,
                  ),
                ),
              ],
            ),
          ),

          // ── البحث ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              onChanged: (v) => setState(() {
                _searchText = v;
                _applyFilter();
              }),
              decoration: InputDecoration(
                hintText: 'ابحث في الإشعارات...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() {
                          _searchText = '';
                          _applyFilter();
                        }),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.inputFill(isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),

          // ── فلتر غير المقروء فقط ───────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(() {
                  _showUnreadOnly = !_showUnreadOnly;
                  _applyFilter();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _showUnreadOnly
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.inputFill(isDark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _showUnreadOnly
                          ? AppColors.error.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showUnreadOnly
                            ? Icons.filter_alt_rounded
                            : Icons.filter_alt_outlined,
                        size: 14,
                        color: _showUnreadOnly
                            ? AppColors.error
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'غير المقروء فقط',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _showUnreadOnly
                              ? AppColors.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),
          Expanded(
            child: loading
                ? const AppLoading()
                : _filtered.isEmpty
                ? _buildEmptyState()
                : _buildNotificationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasContent = notifications.isNotEmpty;

    return AppEmpty(
      message: hasContent ? 'لا توجد نتائج مطابقة' : 'لا توجد إشعارات',
      hint: hasContent ? 'جرب كلمة بحث مختلفة' : null,
      icon: hasContent ? Icons.search_off_rounded : Icons.notifications_none,
    );
  }

  Widget _buildNotificationsList() {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: fetchNotifications,
      color: AppColors.gold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filtered.length,
        itemBuilder: (context, index) {
          final notification = Map<String, dynamic>.from(_filtered[index]);
          return _buildNotificationCard(notification, index);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, int index) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isRead = notification['IsRead'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        radius: AppRadius.lg,
        color: isRead ? null : AppColors.gold.withValues(alpha: 0.08),
        onTap: () {
          if (!isRead) {
            markAsRead(notification['NotificationID']);
          }
          _handleNavigation(notification);
        },
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الأيقونة
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isRead
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.1)
                      : AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getNotificationIcon(notification['RelatedTable']),
                  color: isRead ? scheme.onSurfaceVariant : AppColors.gold,
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
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 14.5,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // الرسالة
                    Text(
                      notification['Message'] ?? '',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // التاريخ والمرسل
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(notification['CreatedAt']),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.person_outline_rounded,
                          size: 13,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          notification['CreatedBy'] ?? '',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
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
    ).animate().fadeIn(
      delay: Duration(milliseconds: 40 * index),
      duration: 350.ms,
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final s = value.toString();
    // لو تاريخ بصيغة ISO → نحوله لصيغة عربية مختصرة
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return 'اليوم $h:$m';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _handleNavigation(Map<String, dynamic> notification) {
    // نستخدم الراوتر الشامل (نفس منطق فتح الإشعار من خارج التطبيق)
    // — هو بيترجم أي FormName من بلازور لشاشة الموبايل الصحيحة
    final formName = notification['FormName'];
    final relatedTable = notification['RelatedTable'];
    final relatedId = notification['RelatedID'];

    final decision = BlazorNotificationRouter.resolve(
      formName: formName?.toString(),
      relatedTable: relatedTable?.toString(),
      relatedId: relatedId,
    );

    final page = NotificationNavigator.buildPage(
      decision,
      userId: widget.userId ?? 0,
      username: widget.username ?? 'User',
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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
