import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/models/zakat_record.dart';
import '../../core/providers/calculator_provider.dart';
import '../shared/app_components.dart';

Future<void> moveToRecycleBin(BuildContext context, ZakatRecord record) async {
  final calc = context.read<CalculatorProvider>();
  final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFB3261E)),
            title: const Text('Move this record to the recycle bin?'),
            content: Text(
                '“${record.name}” and its payment history will be removed from your active totals. Linked monthly Zakat commitments cannot be paid while it is in the bin.\n\nYou can restore everything for 60 days. After that, the record and its linked payments are permanently deleted by automatic cleanup.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep record')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB3261E)),
                  child: const Text('Move to recycle bin'))
            ],
          ));
  if (yes != true) return;
  final ok = await calc.recycleRecord(record);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Record moved to recycle bin. Restore within 60 days.'
          : calc.error!),
      action: ok
          ? SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                final restored = await calc.restoreRecord(record);
                if (context.mounted && !restored) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(calc.error!)));
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
        appBar: AppBar(title: const Text('Recycle bin')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const PageIntro(
              eyebrow: 'A second chance',
              title: 'Restore what matters.',
              description:
                  'Deleted records and their payment history can be restored for 60 days. Expired items are removed automatically in the daily cleanup.'),
          if (records.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(children: [
                      Icon(Icons.delete_outline, size: 42),
                      SizedBox(height: 12),
                      Text('Your recycle bin is empty'),
                      SizedBox(height: 8),
                      Text('Records you delete will appear here for 60 days.',
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
                        Text(
                            'Deleted ${DateFormat.yMMMd().format(r.deletedAt!)}'),
                        Text(
                            'Restore before ${DateFormat.yMMMd().add_jm().format(r.purgeAt!)}',
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
                                                ? 'Record and payment history restored.'
                                                : calc.error!)));
                                  },
                            icon: const Icon(Icons.restore),
                            label: Text(_busy.contains(r.id)
                                ? 'Restoring…'
                                : 'Restore record')),
                      ])))),
        ]));
  }
}
