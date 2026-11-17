import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/strings.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/push_service.dart';

class PushReminderCard extends StatefulWidget {
  const PushReminderCard({super.key});
  @override
  State<PushReminderCard> createState() => _PushReminderCardState();
}

class _PushReminderCardState extends State<PushReminderCard> {
  final _service = PushService();
  Map<String, dynamic> _config = {};
  bool _loading = true,
      _busy = false,
      _enabled = false,
      _monthly = true,
      _zakat = true,
      _names = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = context.read<AuthProvider>().user!.uid;
      if (_service.support == 'supported') {
        _config = await _service.configuration();
        final settings = await _service.settings(uid);
        if (settings != null && _service.permission == 'granted') {
          _enabled = true;
          _monthly = settings['monthly'] == true;
          _zakat = settings['zakat'] == true;
          _names = settings['showNames'] == true;
        }
      }
    } catch (_) {
      _error = 'Notification settings could not load. Please retry.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      _error = _service.permission == 'denied'
          ? 'Notifications are blocked. Allow them in your browser or iPhone notification settings.'
          : 'Could not update notifications. Check your connection and retry.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() => _perform(() async {
        await _service.enable(context.read<AuthProvider>().user!.uid,
            _config['publicKey'] as String,
            monthly: _monthly, zakat: _zakat, showNames: _names);
        _enabled = true;
      });
  @override
  Widget build(BuildContext context) {
    final support = _service.support;
    final scheduledAt = _config['scheduledAt'];
    final ready = scheduledAt is num &&
        DateTime.now().millisecondsSinceEpoch - scheduledAt <
            const Duration(hours: 3).inMilliseconds;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.notifications_outlined, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(l(context, 'Giving notifications'),
                            style: Theme.of(context).textTheme.titleMedium))
                  ]),
                  const SizedBox(height: 10),
                  Text(
                      l(context,
                          'Gentle reminders for monthly giving and Zakat, up to twice a week during daytime.'),
                      style: Theme.of(context).textTheme.bodySmall),
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.all(12),
                        child: LinearProgressIndicator())
                  else if (support == 'install')
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(l(context,
                            'On iPhone: open in Safari, tap Share → Add to Home Screen, then open the installed app to enable notifications.')))
                  else if (support != 'supported')
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(l(context,
                            'Push notifications are not supported in this browser. In-app reminders are still available.')))
                  else ...[
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(l(context, _error!),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      if (_config['publicKey'] == null)
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() => _loading = true);
                                    _load();
                                  },
                            child: Text(l(context, 'Retry'))),
                    ],
                    if (_config['publicKey'] == null && _error == null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(l(context,
                              'Notification delivery is being prepared. In-app reminders are available now.'))),
                    if (_config['publicKey'] != null) ...[
                      if (!ready)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                                l(context,
                                    'Automatic notification scheduling has not been confirmed yet. You can set up this device; reminders will start once scheduling is active.'),
                                style: Theme.of(context).textTheme.bodySmall)),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l(context, 'Monthly giving reminders')),
                          value: _monthly,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _monthly = v)),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l(context, 'Zakat reminders')),
                          value: _zakat,
                          onChanged:
                              _busy ? null : (v) => setState(() => _zakat = v)),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l(context, 'Show recipient names')),
                          subtitle: Text(l(context,
                              'Names may appear on your lock screen. Amounts are not included.')),
                          value: _names,
                          onChanged:
                              _busy ? null : (v) => setState(() => _names = v)),
                      FilledButton.icon(
                          onPressed:
                              _busy || (!_monthly && !_zakat) ? null : _save,
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(_busy
                              ? l(context, 'Saving…')
                              : _enabled
                                  ? l(context, 'Save notification preferences')
                                  : l(context,
                                      'Enable notifications on this device'))),
                      if (_enabled)
                        Wrap(spacing: 8, children: [
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _perform(() => _service.showTest(
                                      l(context, 'Zakat Tracker'),
                                      l(context,
                                          'Notifications are allowed on this device. May Allah accept your giving.'))),
                              child:
                                  Text(l(context, 'Show a test notification'))),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _perform(() async {
                                        await _service.disable(context
                                            .read<AuthProvider>()
                                            .user!
                                            .uid);
                                        _enabled = false;
                                      }),
                              child:
                                  Text(l(context, 'Turn off on this device'))),
                        ]),
                    ],
                  ],
                ])));
  }
}
