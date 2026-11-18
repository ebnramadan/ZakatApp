import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/strings.dart';
import '../../core/notifications/notification_provider.dart';
import 'notification_history_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<NotificationProvider?>();
    return IconButton(
        key: const Key('notification-bell'),
        tooltip: l(context, 'Notifications'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const NotificationHistoryScreen())),
        icon: Badge(
            isLabelVisible: inbox?.hasUnread == true,
            child: const Icon(Icons.notifications_none_rounded)));
  }
}
