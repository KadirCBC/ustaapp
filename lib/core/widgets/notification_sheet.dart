import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_notification_model.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationSheet extends StatefulWidget {
  const NotificationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationSheet(),
    );
  }

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ValueListenableBuilder<List<AppNotificationModel>>(
              valueListenable: NotificationService.instance.notificationsNotifier,
              builder: (context, notifs, _) {
                final unreadCount = notifs.where((n) => !n.isRead).length;

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.customerPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppTheme.customerPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Bildirim Merkezi',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$unreadCount Yeni',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Anlık usta varışları, sistem güncellemeleri ve duyurular',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (notifs.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                        onSelected: (val) {
                          if (val == 'read_all') {
                            NotificationService.instance.markAllAsRead();
                          } else if (val == 'clear_all') {
                            NotificationService.instance.clearAll();
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'read_all',
                            child: Row(
                              children: [
                                Icon(Icons.done_all_rounded, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Tümünü Okundu Yap'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'clear_all',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Bildirimleri Temizle'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Filter bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'Tümü', Icons.inbox_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('arrived', '🚨 Usta Varışları', Icons.doorbell_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('update', '🚀 Güncellemeler', Icons.system_update_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('feature', '💡 Yenilikler', Icons.lightbulb_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('warning', '⚠️ Önemli', Icons.warning_amber_rounded),
              ],
            ),
          ),

          const Divider(height: 1),

          // List content
          Expanded(
            child: ValueListenableBuilder<List<AppNotificationModel>>(
              valueListenable: NotificationService.instance.notificationsNotifier,
              builder: (context, notifs, _) {
                final filtered = notifs.where((n) {
                  if (_selectedFilter == 'all') return true;
                  return n.type == _selectedFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_off_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Henüz bildirim bulunmuyor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Usta varışları ve admin duyuruları burada görünecektir.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notif = filtered[index];
                    return _buildNotificationCard(notif);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.customerPrimary
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.customerPrimary
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotificationModel notif) {
    Color iconColor;
    Color iconBg;
    IconData icon;

    switch (notif.type) {
      case 'arrived':
        icon = Icons.doorbell_rounded;
        iconColor = Colors.white;
        iconBg = const Color(0xFFDC2626); // Urgent red
        break;
      case 'update':
        icon = Icons.rocket_launch_rounded;
        iconColor = Colors.white;
        iconBg = const Color(0xFF0284C7); // Sky blue
        break;
      case 'feature':
        icon = Icons.lightbulb_rounded;
        iconColor = Colors.white;
        iconBg = const Color(0xFFD97706); // Amber
        break;
      case 'warning':
        icon = Icons.warning_rounded;
        iconColor = Colors.white;
        iconBg = const Color(0xFFEA580C); // Orange
        break;
      case 'pricing':
        icon = Icons.sell_rounded;
        iconColor = Colors.white;
        iconBg = const Color(0xFF16A34A); // Green
        break;
      default:
        icon = Icons.campaign_rounded;
        iconColor = Colors.white;
        iconBg = const Color(0xFF4F46E5); // Indigo
    }

    final timeStr = _formatRelativeTime(notif.createdAt);

    return InkWell(
      onTap: () {
        if (!notif.isRead) {
          NotificationService.instance.markAsRead(notif.id);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isUrgent
                ? Colors.red.shade200
                : (notif.isRead ? Colors.grey.shade200 : Colors.blue.shade200),
            width: notif.isUrgent ? 1.5 : (notif.isRead ? 1 : 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconBg.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (!notif.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.customerPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: notif.isRead ? const Color(0xFF475569) : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getTargetLabel(notif.target),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
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
    );
  }

  String _getTargetLabel(String target) {
    switch (target) {
      case 'ustalar':
        return '🛠️ Ustalara Özel';
      case 'musteriler':
        return '👤 Müşterilere Özel';
      case 'user':
        return '📱 Size Özel';
      default:
        return '🌐 Tüm Kullanıcılar';
    }
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 45) {
      return 'Az önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} sa önce';
    } else {
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    }
  }
}
