import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/tracker_provider.dart';
import '../home/home_screen.dart';
import '../shared/giving_celebration.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final auth = context.read<AuthProvider>();
    final currency = calc.draft?.currency ?? 'USD';
    final d = calc.draft;

    if (d == null) {
      return const Scaffold(body: Center(child: Text('No record found')));
    }

    final fmt = NumberFormat.currency(
        name: currency,
        symbol: currencySymbol(currency),
        decimalDigits: currencyDecimals(currency));

    return Scaffold(
      appBar: AppBar(title: const Text('Zakat Summary')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Nisab status banner
          _NisabBanner(met: d.nisabMet, matured: d.hawlComplete),
          const SizedBox(height: 20),

          // Asset breakdown
          _Card(
            title: 'Asset Breakdown',
            children: [
              _Row('Cash ($currency)', fmt.format(d.cashLocal)),
              ...d.foreignCash.map((e) => _Row(
                    'Cash (${e.currency})',
                    fmt.format(e.localValue),
                    sub:
                        '${e.amount.toStringAsFixed(2)} ${e.currency} × ${e.exchangeRate.toStringAsFixed(4)}',
                  )),
              ...d.goldEntries.map((e) => _Row(
                    'Gold ${e.carat}K (${e.grams}g)',
                    fmt.format(e.localValue),
                    sub:
                        '${(e.pricePerGram24k * e.purity).toStringAsFixed(2)}/g',
                  )),
              const Divider(),
              _Row('Total Wealth', fmt.format(d.totalWealth), bold: true),
            ],
          ),

          const SizedBox(height: 12),

          // Nisab & Zakat
          _Card(
            title: 'Zakat Calculation',
            children: [
              _Row('Nisab Threshold (85g gold)', fmt.format(d.nisabThreshold)),
              _Row('Nisab Met?', d.nisabMet ? 'Yes ✓' : 'No ✗',
                  valueColor: d.nisabMet ? Colors.green : Colors.orange),
              const Divider(),
              _Row(
                d.hawlComplete ? 'Zakat Due (2.5%)' : 'Estimated Zakat (2.5%)',
                fmt.format(d.estimatedZakat),
                bold: true,
                valueColor: kPrimaryGreen,
              ),
            ],
          ),

          const SizedBox(height: 24),
          if (!d.hawlComplete)
            const Text(
                'Your lunar Hawl has not completed. This estimate is not currently due. Payments recorded now are advance payments.'),
          const Text(
              'This calculation assumes your wealth remained eligible throughout the Hawl. Cash and gold only; no debt deductions.'),

          if (calc.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(calc.error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center),
            ),

          if (!d.isSubmitted) ...[
            ElevatedButton(
              onPressed: calc.loading
                  ? null
                  : () async {
                      final saved = await calc.submitDraft(auth.user!.uid);
                      if (context.mounted && saved != null) {
                        await auth.updateProfileFields(
                            defaultRecordId: saved.id);
                        if (!context.mounted) return;
                        await showGivingCelebration(context, planReady: true);
                        if (!context.mounted) return;
                        context
                            .read<TrackerProvider>()
                            .selectRecord(auth.user!.uid, saved);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const HomeScreen(initialTab: 2)),
                          (_) => false,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen),
              child: calc.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm & Submit'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Submitting locks the calculation. You can still move the record to the recycle bin later.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Submitted and locked.',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _NisabBanner extends StatelessWidget {
  final bool met;
  final bool matured;
  const _NisabBanner({required this.met, required this.matured});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: met ? kPrimaryGreen : Colors.orange.shade700,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.info_outline,
              color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  met ? 'Nisab Threshold Met' : 'Below Nisab Threshold',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  met
                      ? (matured
                          ? 'Zakat is due on your wealth.'
                          : 'Nisab met; Hawl is not yet complete.')
                      : 'Your wealth is below Nisab. Zakat is not obligatory this year.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryGreen)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final bool bold;
  final Color? valueColor;

  const _Row(this.label, this.value,
      {this.sub, this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                        color: Colors.black87)),
                if (sub != null)
                  Text(sub!,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? Colors.black87),
          ),
        ],
      ),
    );
  }
}
