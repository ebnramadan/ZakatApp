import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/localization/strings.dart';
import '../../core/notifications/notification_provider.dart';
import '../../core/providers/auth_provider.dart';
import 'notification_navigation.dart';
import 'push_reminder_card.dart';

class NotificationHistoryScreen extends StatelessWidget {
  const NotificationHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<NotificationProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(l(context, 'Notifications')), actions: [
        IconButton(
            tooltip: l(context, 'Notification settings'),
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => Scaffold(
                    appBar:
                        AppBar(title: Text(l(context, 'Giving notifications'))),
                    body: const SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: PushReminderCard()))))),
      ]),
      body: inbox.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => inbox
                  .load(context.read<AuthProvider>().user!.uid, force: true),
              child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Text(l(context, 'Your duaa and giving reminders'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                        l(context,
                            'Tap a reminder to open its next action. Payments are only recorded after you confirm.'),
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    if (inbox.error != null) ...[
                      Text(l(context, inbox.error!),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      TextButton(
                          onPressed: () => inbox.load(
                              context.read<AuthProvider>().user!.uid,
                              force: true),
                          child: Text(l(context, 'Retry'))),
                    ],
                    if (inbox.items.isEmpty && inbox.error == null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(children: [
                            const Icon(Icons.notifications_none_rounded,
                                size: 48),
                            const SizedBox(height: 16),
                            Text(l(context, 'No notifications yet'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                                l(context,
                                    'New daily duaa and giving reminders sent to your devices will appear here.'),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                                icon: const Icon(Icons.tune),
                                label:
                                    Text(l(context, 'Notification settings')),
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (context) => Scaffold(
                                            appBar: AppBar(
                                                title: Text(l(context,
                                                    'Giving notifications'))),
                                            body: const SingleChildScrollView(
                                                padding: EdgeInsets.all(16),
                                                child: PushReminderCard()))))),
                          ])),
                    ...inbox.items.map((n) => Card(
                            child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            inbox.markRead(n);
                            openNotificationAction(context, n.target);
                          },
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Icon(
                                          n.kind == 'monthly'
                                              ? Icons.calendar_month_outlined
                                              : n.kind == 'zakat'
                                                  ? Icons
                                                      .volunteer_activism_outlined
                                                  : Icons.favorite_outline,
                                          size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(n.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium)),
                                      if (n.readAt == null) const Badge(),
                                    ]),
                                    const SizedBox(height: 10),
                                    Text(n.body,
                                        style: const TextStyle(height: 1.6)),
                                    const SizedBox(height: 12),
                                    Text(
                                        DateFormat.yMMMd()
                                            .add_jm()
                                            .format(n.sentAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Expanded(
                                          child: Text(
                                              l(
                                                  context,
                                                  n.kind == 'monthly'
                                                      ? 'View monthly payment'
                                                      : n.kind == 'zakat'
                                                          ? 'View Zakat'
                                                          : 'Go to Home'),
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600))),
                                      const Icon(Icons.chevron_right, size: 20)
                                    ]),
                                  ])),
                        ))),
                    if (inbox.hasMore)
                      TextButton(
                          onPressed:
                              inbox.loadingOlder ? null : inbox.loadOlder,
                          child: Text(l(
                              context,
                              inbox.loadingOlder
                                  ? 'Loading…'
                                  : 'Older notifications'))),
                  ]),
            ),
    );
  }
}
