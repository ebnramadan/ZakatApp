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
        child: ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Monthly progress sheet'),
            subtitle: Text(p.sharingEnabled
                ? 'Scheduled for ${p.shareRecipients.length} recipient(s) on day ${p.shareDay}'
                : 'Share Zakat and Sadaqah progress by email'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(
                context: context, builder: (_) => const _SharingDialog())));
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
          title: const Text('Monthly progress sheet'),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Send a read-only Excel snapshot of your active Zakat records, payment history, and monthly Zakat/Sadaqah progress. Recipients can open it in Excel or import it into Google Sheets.'),
                            const SizedBox(height: 12),
                            const Text(
                                'The sheet includes recipient names and amounts. It is an emailed copy, not live account access; copies already sent cannot be revoked.',
                                style: TextStyle(fontSize: 13)),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Enable monthly sharing'),
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
                                decoration: const InputDecoration(
                                    labelText: 'Recipient email addresses',
                                    helperText:
                                        'Up to 5 addresses, separated by commas'),
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
                                    return 'Enter up to 5 valid email addresses';
                                  }
                                  return null;
                                }),
                            const SizedBox(height: 16),
                            SearchablePicker<int>(
                                label: 'Day of the month',
                                value: day,
                                options: List.generate(31,
                                    (i) => PickerOption(i + 1, 'Day ${i + 1}')),
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() => day = v)),
                            const SizedBox(height: 12),
                            const Text(
                                'Runs daily at 09:00 UTC and sends once per recipient each month on or after your selected day. Days 29–31 use the last day in shorter months. Turning sharing off stops future sends.',
                                style: TextStyle(fontSize: 13)),
                          ])))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
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
                              SnackBar(content: Text(auth.error!)));
                        }
                      },
                child: Text(busy ? 'Saving…' : 'Save sharing settings'))
          ]);
}
