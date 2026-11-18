import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/notifications/notification_target.dart';
import '../../core/providers/tracker_provider.dart';
import '../home/home_screen.dart';
import '../monthly/monthly_screen.dart';
import '../tracker/tracker_screen.dart';

Future<void> openNotificationAction(
    BuildContext context, NotificationTarget target) async {
  if (target.kind == 'monthly') {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MonthlyScreen(
            focusPlanId: target.planId, focusMonth: target.month)));
  } else if (target.kind == 'zakat') {
    final source = context.read<TrackerProvider>();
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
            create: (_) => source.fork(),
            child: TrackerScreen(recordId: target.recordId))));
  } else {
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }
}
