import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../widgets/searchable_picker.dart';

class SharingSettingsCard extends StatelessWidget {
  const SharingSettingsCard({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AuthProvider>().profile!;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.table_chart_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(l(context, "Monthly progress sheet"),
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w700)))
                  ]),
                  const SizedBox(height: 12),
                  Text(p.sharingEnabled
                      ? l(context, "Scheduled for {0} recipient(s) on day {1}",
                          [p.shareRecipients.length, p.shareDay])
                      : l(context,
                          "Monthly sharing is off. You can still send a sheet manually.")),
                  const SizedBox(height: 16),
                  StreamBuilder<Map<String, dynamic>?>(
                      stream: context.read<AuthProvider>().sheetRequestStream,
                      builder: (context, snapshot) {
                        final request = snapshot.data,
                            status = request?['status'] as String?;
                        final queued = status == 'queued';
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(spacing: 12, runSpacing: 8, children: [
                                FilledButton.icon(
                                    onPressed: queued ||
                                            p.shareRecipients.isEmpty
                                        ? null
                                        : () async {
                                            final auth =
                                                context.read<AuthProvider>();
                                            final ok = await auth
                                                .sendProgressSheetNow();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(ok
                                                          ? l(context,
                                                              "Sheet queued. It will be sent in the next few minutes, regardless of your scheduled day.")
                                                          : l(
                                                              context,
                                                              auth.error ??
                                                                  'Could not queue the sheet.'))));
                                            }
                                          },
                                    icon: const Icon(Icons.send_outlined),
                                    label: Text(queued
                                        ? l(context, "Queued for sending")
                                        : l(context, "Send now"))),
                                OutlinedButton.icon(
                                    onPressed: () => showDialog<void>(
                                        context: context,
                                        builder: (_) => const _SharingDialog()),
                                    icon: const Icon(Icons.tune),
                                    label:
                                        Text(l(context, "Sharing settings"))),
                              ]),
                              const SizedBox(height: 10),
                              if (p.shareRecipients.isEmpty)
                                Text(
                                    l(context,
                                        "Add recipients in Sharing settings before sending."),
                                    style: const TextStyle(fontSize: 13)),
                              if (status == 'sent')
                                Text(
                                    l(context,
                                        "Your latest requested sheet was accepted by the email provider."),
                                    style: const TextStyle(fontSize: 13)),
                              if (status == 'failed')
                                Text(
                                    l(context,
                                        "The latest send failed. Check your settings and try again."),
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.red)),
                              if (queued)
                                Text(
                                    l(context,
                                        "Queued requests are processed every few minutes. You can leave the app open or close it."),
                                    style: const TextStyle(fontSize: 13)),
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
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title:
                                    Text(l(context, "Enable monthly sharing")),
                                value: enabled,
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() => enabled = v)),
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
                                label: l(context, "Day of the month"),
                                value: day,
                                options: List.generate(
                                    31,
                                    (i) => PickerOption(
                                        i + 1, l(context, "Day {0}", [i + 1]))),
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() => day = v)),
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
