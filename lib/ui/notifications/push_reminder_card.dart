import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/strings.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/push_service.dart';

class PushReminderCard extends StatefulWidget {
  final PushService? service;
  final bool compact, showEnableButton;
  const PushReminderCard(
      {super.key,
      this.service,
      this.compact = false,
      this.showEnableButton = true});
  @override
  PushReminderCardState createState() => PushReminderCardState();
}

class PushReminderCardState extends State<PushReminderCard> {
  late final _service = widget.service ?? PushService();
  Map<String, dynamic> _config = {};
  late Future<void> _initialLoad;
  bool _loading = true,
      _busy = false,
      _enabled = false,
      _monthly = true,
      _zakat = true,
      _names = true,
      _dailyDuaa = true;
  String? _error, _loadError;
  bool _settingsFailed = false;
  @override
  void initState() {
    super.initState();
    _initialLoad = _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user!.uid;
    _loadError = null;
    _error = null;
    _settingsFailed = false;
    _enabled = false;
    if (_service.support == 'supported') {
      try {
        _config = await _service.configuration();
      } catch (_) {
        _loadError = 'Notification settings could not load. Please retry.';
      }
      try {
        final settings = await _service.settings(uid);
        if (settings != null && _service.permission == 'granted') {
          _enabled = true;
          _monthly = settings['monthly'] == true;
          _zakat = settings['zakat'] == true;
          _names = settings['showNames'] == true;
          _dailyDuaa = settings['dailyDuaa'] != false;
        }
      } catch (_) {
        _settingsFailed = true;
        _loadError = 'Notification settings could not load. Please retry.';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Invoked from the onboarding footer tap. Ask OS permission before any
  /// configuration/network await so iOS retains the user activation.
  Future<bool> enableFromOnboarding() async {
    if (_busy) return false;
    if (_service.support != 'supported' ||
        (!_monthly && !_zakat && !_dailyDuaa)) return true;
    var continueSetup = false;
    await _perform(() async {
      final permission = await _service.requestPermission();
      if (!mounted) return;
      if (permission != 'granted') {
        continueSetup = true;
        return;
      }
      await _initialLoad;
      if (!mounted) return;
      if (_settingsFailed || _config['publicKey'] == null) {
        throw const PushSetupException(
            'Notification settings could not load. Please retry.');
      }
      await _service.enable(context.read<AuthProvider>().user!.uid,
          _config['publicKey'] as String,
          monthly: _monthly,
          zakat: _zakat,
          showNames: _names,
          dailyDuaa: _dailyDuaa);
      _enabled = true;
      continueSetup = true;
    });
    return continueSetup;
  }

  Future<void> _test() => _perform(() async {
        await _service.showTest(
            l(context, 'Zakat Tracker'),
            l(context,
                'Notifications are allowed on this device. May Allah accept your giving.'));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l(context,
                'Test notification requested. Check Notification Centre if no banner appears.'))));
      });

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      _error = _service.permission == 'denied'
          ? 'Notifications are blocked. Allow them in your browser or iPhone notification settings.'
          : error is PushSetupException
              ? error.message
              : 'Could not update notifications. Check your connection and retry.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() => _perform(() async {
        await _service.enable(context.read<AuthProvider>().user!.uid,
            _config['publicKey'] as String,
            monthly: _monthly,
            zakat: _zakat,
            showNames: _names,
            dailyDuaa: _dailyDuaa);
        _enabled = true;
      });
  @override
  Widget build(BuildContext context) {
    final support = _service.support;
    final scheduledAt = _config['scheduledAt'];
    final ready = scheduledAt is num &&
        DateTime.now().millisecondsSinceEpoch - scheduledAt <
            const Duration(hours: 3).inMilliseconds;
    final content = Padding(
        padding: EdgeInsets.all(widget.compact ? 0 : 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!widget.compact)
            Row(children: [
              const Icon(Icons.notifications_outlined, size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(l(context, 'Giving notifications'),
                      style: Theme.of(context).textTheme.titleMedium)),
              IconButton(
                  tooltip: l(context, 'Refresh notification status'),
                  onPressed: _busy || _loading
                      ? null
                      : () {
                          setState(() => _loading = true);
                          _initialLoad = _load();
                        },
                  icon: const Icon(Icons.refresh)),
            ]),
          if (!widget.compact) const SizedBox(height: 10),
          if (!widget.compact)
            Text(
                l(context,
                    'One daily duaa, with a giving reminder when something is due. Sent during daytime.'),
                style: Theme.of(context).textTheme.bodySmall),
          if (support == 'supported' && !widget.compact) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
                key: const Key('test-notification'),
                onPressed: _busy ? null : _test,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(l(context, 'Send test notification'))),
            const SizedBox(height: 6),
            Text(
                l(context,
                    'Tests this device only. Enable reminders below for automatic notifications.'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(12), child: LinearProgressIndicator())
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
            if (_loadError != null || _error != null) ...[
              const SizedBox(height: 12),
              Text(l(context, _error ?? _loadError!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (_loadError != null)
                TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() => _loading = true);
                            _initialLoad = _load();
                          },
                    child: Text(l(context, 'Retry'))),
            ],
            if (_config['publicKey'] == null && _loadError == null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l(context,
                      'Notification delivery is being prepared. In-app reminders are available now.'))),
            if (_config['publicKey'] != null) ...[
              if (!ready)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                        l(
                            context,
                            scheduledAt is num && scheduledAt > 0
                                ? 'Automatic reminders may be delayed. Check Home for anything due.'
                                : widget.compact
                                    ? 'Automatic delivery is still being verified.'
                                    : 'Automatic notification scheduling has not been confirmed yet. You can set up this device; reminders will start once scheduling is active.'),
                        style: Theme.of(context).textTheme.bodySmall)),
              SwitchListTile(
                  dense: widget.compact,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l(context, 'Daily duaa')),
                  value: _dailyDuaa,
                  onChanged:
                      _busy ? null : (v) => setState(() => _dailyDuaa = v)),
              if (widget.compact)
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(l(context, 'Giving reminder preferences')),
                    children: [
                      SwitchListTile(
                          dense: widget.compact,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l(context, 'Monthly giving reminders')),
                          value: _monthly,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _monthly = v)),
                      SwitchListTile(
                          dense: widget.compact,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l(context, 'Zakat reminders')),
                          value: _zakat,
                          onChanged:
                              _busy ? null : (v) => setState(() => _zakat = v)),
                      SwitchListTile(
                          dense: widget.compact,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l(context, 'Show recipient names')),
                          subtitle: Text(l(
                              context,
                              widget.compact
                                  ? 'Names can appear on your lock screen.'
                                  : 'Names may appear on your lock screen. Amounts are not included.')),
                          value: _names,
                          onChanged:
                              _busy ? null : (v) => setState(() => _names = v)),
                    ])
              else ...[
                SwitchListTile(
                    dense: widget.compact,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l(context, 'Monthly giving reminders')),
                    value: _monthly,
                    onChanged:
                        _busy ? null : (v) => setState(() => _monthly = v)),
                SwitchListTile(
                    dense: widget.compact,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l(context, 'Zakat reminders')),
                    value: _zakat,
                    onChanged:
                        _busy ? null : (v) => setState(() => _zakat = v)),
                SwitchListTile(
                    dense: widget.compact,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l(context, 'Show recipient names')),
                    subtitle: Text(l(
                        context,
                        widget.compact
                            ? 'Names can appear on your lock screen.'
                            : 'Names may appear on your lock screen. Amounts are not included.')),
                    value: _names,
                    onChanged:
                        _busy ? null : (v) => setState(() => _names = v)),
              ],
              if (widget.showEnableButton)
                FilledButton.icon(
                    onPressed: _busy ||
                            _settingsFailed ||
                            (!_monthly && !_zakat && !_dailyDuaa)
                        ? null
                        : _save,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(_busy
                        ? l(context, 'Saving…')
                        : _enabled
                            ? l(context, 'Save notification preferences')
                            : l(context,
                                'Enable notifications on this device'))),
              if (_enabled && widget.compact)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                        l(context, 'Notifications enabled on this device.'),
                        style: Theme.of(context).textTheme.bodySmall)),
              if (_enabled && !widget.compact)
                Wrap(spacing: 8, children: [
                  TextButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(() async {
                                await _service.disable(
                                    context.read<AuthProvider>().user!.uid);
                                _enabled = false;
                              }),
                      child: Text(l(context, 'Turn off on this device'))),
                ]),
            ],
          ],
        ]));
    return widget.compact ? content : Card(child: content);
  }
}
