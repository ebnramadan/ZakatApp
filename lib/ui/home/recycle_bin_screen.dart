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
  FocusManager.instance.primaryFocus?.unfocus();
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

class _DeleteRecordDialog extends StatelessWidget {
  final ZakatRecord record;
  final bool isDefault;
  const _DeleteRecordDialog({required this.record, required this.isDefault});
  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.delete_outline, color: Color(0xFFB3261E)),
        title: Text(isDefault
            ? l(context, 'Delete your default record?')
            : l(context, 'Move this record to the recycle bin?')),
        content: Text(l(
            context,
            isDefault
                ? '“{0}” is your default record. Another available record will become the default. You can restore this record and its payments from the recycle bin for 60 days. Linked monthly Zakat payments are paused while it is deleted.'
                : '“{0}” and its payments will move to the recycle bin. You can restore them for 60 days. Linked monthly Zakat payments are paused while it is deleted.',
            [record.name])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l(context, 'Keep record'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB3261E)),
              child: Text(l(context, 'Move to recycle bin'))),
        ],
      );
}
