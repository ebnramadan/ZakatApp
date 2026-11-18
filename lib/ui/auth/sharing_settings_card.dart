import 'dart:async';
import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../widgets/searchable_picker.dart';

class SharingSettingsCard extends StatefulWidget {
  const SharingSettingsCard({super.key});
  @override
  State<SharingSettingsCard> createState() => _SharingSettingsCardState();
}

class _SharingSettingsCardState extends State<SharingSettingsCard> {
  late final Stream<Map<String, dynamic>?> _requests;
  Timer? _clock;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _requests = context.read<AuthProvider>().sheetRequestStream;
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await action();
    if (mounted) {
      setState(() {
        _busy = false;
        _error = ok ? null : context.read<AuthProvider>().error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>(), p = auth.profile!;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE8F2EC),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.table_chart_outlined,
                            size: 20, color: Color(0xFF146356))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(l(context, 'Monthly progress sheet'),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(
                              p.sharingEnabled
                                  ? l(context, 'Day {0} · {1} recipient(s)',
                                      [p.shareDay, p.shareRecipients.length])
                                  : l(context,
                                      'Send a snapshot of your giving'),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF63716B))),
                        ])),
                  ]),
                  const SizedBox(height: 16),
                  StreamBuilder<Map<String, dynamic>?>(
                      stream: _requests,
                      builder: (context, snapshot) {
                        final request = snapshot.data,
                            status = request?['status'] as String?;
                        final queued = status == 'queued';
                        final requestedAt = request?['requestedAt'] as int?;
                        final delayed = queued &&
                            requestedAt != null &&
                            DateTime.now().millisecondsSinceEpoch -
                                    requestedAt >=
                                600000;
                        final retry = delayed || status == 'failed';
                        final message = snapshot.hasError
                            ? 'Delivery status could not load. Check your connection.'
                            : delayed
                                ? 'Delivery is delayed. Your request is saved. Retry keeps the same request and delivery history.'
                                : queued
                                    ? 'Waiting for background delivery. Scheduling can be delayed; you can close the app.'
                                    : status == 'sent'
                                        ? 'Your latest requested sheet was accepted by the email provider.'
                                        : status == 'failed'
                                            ? 'The latest send failed. Check your settings and try again.'
                                            : status == 'cancelled'
                                                ? 'Send request cancelled.'
                                                : p.shareRecipients.isEmpty
                                                    ? 'Add recipients in Sharing settings before sending.'
                                                    : 'Zakat and Sadaqah, together in one private report.';
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: FilledButton.icon(
                                        onPressed: _busy ||
                                                snapshot.connectionState ==
                                                    ConnectionState.waiting ||
                                                snapshot.hasError ||
                                                p.shareRecipients.isEmpty ||
                                                (queued && !delayed)
                                            ? null
                                            : () => _run(() => retry
                                                ? auth.retryProgressSheet(
                                                    request!['id'] as String)
                                                : auth.sendProgressSheetNow()),
                                        icon: _busy
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : Icon(
                                                retry
                                                    ? Icons.refresh_rounded
                                                    : queued
                                                        ? Icons.schedule_rounded
                                                        : Icons.send_rounded,
                                                size: 18),
                                        label: Text(l(
                                            context,
                                            _busy
                                                ? 'Saving…'
                                                : retry
                                                    ? 'Retry delivery'
                                                    : queued
                                                        ? 'Queued for sending'
                                                        : 'Send now')))),
                                const SizedBox(width: 8),
                                IconButton.outlined(
                                    tooltip: l(context, 'Sharing settings'),
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            showDialog<void>(
                                                context: context,
                                                builder: (_) =>
                                                    const _SharingDialog());
                                          },
                                    icon: const Icon(Icons.tune_rounded,
                                        size: 21)),
                              ]),
                              const SizedBox(height: 10),
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                        status == 'sent'
                                            ? Icons.check_circle_outline
                                            : delayed || status == 'failed'
                                                ? Icons.info_outline_rounded
                                                : Icons.lock_outline_rounded,
                                        size: 15,
                                        color: delayed || status == 'failed'
                                            ? const Color(0xFF9A6500)
                                            : const Color(0xFF63716B)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Text(l(context, message),
                                            style: TextStyle(
                                                fontSize: 11,
                                                height: 1.4,
                                                color: delayed ||
                                                        status == 'failed'
                                                    ? const Color(0xFF9A6500)
                                                    : const Color(
                                                        0xFF63716B)))),
                                  ]),
                              if (queued)
                                Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _run(() =>
                                                auth.cancelProgressSheet(
                                                    request!['id'] as String)),
                                        child: Text(
                                            l(context, 'Cancel request')))),
                              if (_error != null)
                                Text(l(context, _error!),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.red)),
                            ]);
                      }),
                ])));
  }
}

class _SharingDialog extends StatefulWidget {
  const _SharingDialog();
  @override
  State<_SharingDialog> createState() => _SharingDialogState();
}

class _SharingDialogState extends State<_SharingDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController recipients;
  late bool enabled;
  late int day;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = context.read<AuthProvider>().profile!;
    recipients = TextEditingController(text: p.shareRecipients.join(', '));
    enabled = p.sharingEnabled;
    day = p.shareDay;
  }

  @override
  void dispose() {
    recipients.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(l(context, "Monthly progress sheet")),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l(context,
                                "Send a read-only Excel snapshot of your active Zakat records, payment history, and monthly Zakat/Sadaqah progress. Recipients can open it in Excel or import it into Google Sheets.")),
                            const SizedBox(height: 12),
                            Text(
                                l(context,
                                    "The sheet includes recipient names and amounts. It is an emailed copy, not live account access; copies already sent cannot be revoked."),
                                style: const TextStyle(fontSize: 13)),
                            TextFormField(
                                controller: recipients,
                                enabled: !busy,
                                keyboardType: TextInputType.emailAddress,
                                minLines: 2,
                                maxLines: 4,
                                decoration: InputDecoration(
                                    labelText:
                                        l(context, "Recipient email addresses"),
                                    helperText: l(context,
                                        "Up to 5 addresses, separated by commas")),
                                validator: (text) {
                                  final values = (text ?? '')
                                      .split(',')
                                      .map((e) => e.trim())
                                      .where((e) => e.isNotEmpty)
                                      .toSet();
                                  if ((enabled && values.isEmpty) ||
                                      values.length > 5 ||
                                      values.any((e) => !RegExp(
                                              r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$')
                                          .hasMatch(e))) {
                                    return l(context,
                                        "Enter up to 5 valid email addresses");
                                  }
                                  return null;
                                }),
                            const SizedBox(height: 16),
                            SearchablePicker<int>(
                                label: l(context, "Monthly sharing"),
                                value: enabled ? day : 0,
                                options: [
                                  PickerOption(
                                      0, l(context, "Disable monthly sharing")),
                                  ...List.generate(
                                      31,
                                      (i) => PickerOption(i + 1,
                                          l(context, "Day {0}", [i + 1]))),
                                ],
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() {
                                          enabled = v != 0;
                                          if (enabled) day = v;
                                        })),
                            const SizedBox(height: 12),
                            Text(
                                l(context,
                                    "Runs daily at 09:00 UTC and sends once per recipient each month on or after your selected day. Days 29–31 use the last day in shorter months. Turning sharing off stops future sends."),
                                style: const TextStyle(fontSize: 13)),
                          ])))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: Text(l(context, "Cancel"))),
            FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => busy = true);
                        final auth = context.read<AuthProvider>();
                        final ok = await auth.updateProfileFields(
                            sharingEnabled: enabled,
                            shareDay: day,
                            shareRecipients: recipients.text
                                .split(',')
                                .map((e) => e.trim().toLowerCase())
                                .where((e) => e.isNotEmpty)
                                .toSet()
                                .toList());
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.pop(context);
                        } else {
                          setState(() => busy = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l(context, auth.error!))));
                        }
                      },
                child: Text(busy
                    ? l(context, "Saving…")
                    : l(context, "Save sharing settings")))
          ]);
}
