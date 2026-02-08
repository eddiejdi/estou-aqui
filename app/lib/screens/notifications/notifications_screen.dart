import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../utils/theme.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = (data['notifications'] as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        ref.read(unreadNotificationsProvider.notifier).state = data['unreadCount'] as int? ?? 0;
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'event_nearby': return Icons.location_on;
      case 'event_starting': return Icons.play_circle;
      case 'event_update': return Icons.update;
      case 'chat_mention': return Icons.chat;
      case 'crowd_milestone': return Icons.people;
      default: return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'event_nearby': return AppTheme.primaryColor;
      case 'event_starting': return AppTheme.secondaryColor;
      case 'event_update': return AppTheme.warningColor;
      case 'chat_mention': return AppTheme.accentColor;
      case 'crowd_milestone': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          TextButton(
            onPressed: () async {
              final api = ref.read(apiServiceProvider);
              await api.markAllNotificationsRead();
              ref.read(unreadNotificationsProvider.notifier).state = 0;
              _loadNotifications();
            },
            child: const Text('Marcar todas lidas', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Nenhuma notificação', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['isRead'] == true;
                      final type = n['type'] as String? ?? 'system';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getNotificationColor(type).withOpacity(0.15),
                          child: Icon(_getNotificationIcon(type), color: _getNotificationColor(type)),
                        ),
                        title: Text(
                          n['title'] ?? '',
                          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                        ),
                        subtitle: Text(n['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                        tileColor: isRead ? null : AppTheme.primaryColor.withOpacity(0.04),
                        onTap: () async {
                          if (!isRead) {
                            final api = ref.read(apiServiceProvider);
                            await api.markNotificationRead(n['id']);
                            _loadNotifications();
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
