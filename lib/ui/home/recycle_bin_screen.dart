import '../../core/localization/strings.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/zakat_record.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../shared/app_components.dart';

Future<void> moveToRecycleBin(BuildContext context, ZakatRecord record) async {
  final calc = context.read<CalculatorProvider>();
  final isDefault = calc
          .defaultRecord(context.read<AuthProvider>().profile?.defaultRecordId)
          ?.id ==
      record.id;
  final yes = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _DeleteRecordDialog(record: record, isDefault: isDefault));
  if (yes != true) return;
  final ok = await calc.recycleRecord(record);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? l(context, "Record moved to recycle bin. Restore within 60 days.")
          : l(context, calc.error!)),
      action: ok
          ? SnackBarAction(
              label: l(context, "Undo"),
              onPressed: () async {
                final restored = await calc.restoreRecord(record);
                if (context.mounted && !restored) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l(context, calc.error!))));
                }
              })
          : null));
}

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});
  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  Timer? _clock;
  final _busy = <String>{};
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final records = calc.recycledRecords;
    return Scaffold(
        appBar: AppBar(title: Text(l(context, "Recycle bin"))),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          PageIntro(
              eyebrow: l(context, "A second chance"),
              title: l(context, "Restore what matters."),
              description: l(context,
                  "Deleted records and their payment history can be restored for 60 days. Expired items are removed automatically in the daily cleanup.")),
          if (records.isEmpty)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      const Icon(Icons.delete_outline, size: 42),
                      const SizedBox(height: 12),
                      Text(l(context, "Your recycle bin is empty")),
                      const SizedBox(height: 8),
                      Text(
                          l(context,
                              "Records you delete will appear here for 60 days."),
                          textAlign: TextAlign.center)
                    ]))),
          ...records.map((r) => Card(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(l(context, "Deleted {0}",
                            [DateFormat.yMMMd().format(r.deletedAt!)])),
                        Text(
                            l(context, "Restore before {0}", [
                              DateFormat.yMMMd().add_jm().format(r.purgeAt!)
                            ]),
                            style: const TextStyle(color: Color(0xFF805600))),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                            onPressed: _busy.contains(r.id)
                                ? null
                                : () async {
                                    setState(() => _busy.add(r.id));
                                    final ok = await calc.restoreRecord(r);
                                    if (!context.mounted) return;
                                    setState(() => _busy.remove(r.id));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(ok
                                                ? l(context,
                                                    "Record and payment history restored.")
                                                : l(context, calc.error!))));
                                  },
                            icon: const Icon(Icons.restore),
                            label: Text(_busy.contains(r.id)
                                ? l(context, "Restoring…")
                                : l(context, "Restore record"))),
                      ])))),
        ]));
  }
}

class _DeleteRecordDialog extends StatefulWidget {
  final ZakatRecord record;
  final bool isDefault;
  const _DeleteRecordDialog({required this.record, required this.isDefault});
  @override
  State<_DeleteRecordDialog> createState() => _DeleteRecordDialogState();
}

class _DeleteRecordDialogState extends State<_DeleteRecordDialog> {
  final confirmation = TextEditingController();
  @override
  void dispose() {
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          icon: const Icon(Icons.delete_outline, color: Color(0xFFB3261E)),
          title: Text(widget.isDefault
              ? l(context, "Delete your default record?")
              : l(context, "Move this record to the recycle bin?")),
          content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (widget.isDefault) ...[
                      Text(l(context,
                          "This is the record used by your dashboard and tracker. Another available record will become the default, or your dashboard will be empty.")),
                      const SizedBox(height: 16)
                    ],
                    Text(l(
                        context,
                        "“{0}” and its payment history will be removed from your active totals. Linked monthly Zakat commitments cannot be paid while it is in the bin.\n\nYou can restore everything for 60 days. After that, the record and its linked payments are permanently deleted by automatic cleanup.",
                        [widget.record.name])),
                    if (widget.isDefault) ...[
                      const SizedBox(height: 20),
                      SelectableText(widget.record.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      TextField(
                          key: const ValueKey('default-delete-confirmation'),
                          controller: confirmation,
                          decoration: InputDecoration(
                              labelText: l(
                                  context, "Type the record name to confirm")),
                          onChanged: (_) => setState(() {}))
                    ],
                  ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l(context, "Keep record"))),
            FilledButton(
                onPressed: widget.isDefault &&
                        confirmation.text.trim() != widget.record.name.trim()
                    ? null
                    : () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB3261E)),
                child: Text(widget.isDefault
                    ? l(context, "Delete default record")
                    : l(context, "Move to recycle bin")))
          ]);
}
