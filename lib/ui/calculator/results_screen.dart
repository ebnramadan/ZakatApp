import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/models/zakat_record.dart';
import '../tracker/tracker_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final auth = context.read<AuthProvider>();
    final currency = auth.profile!.currency;
    final d = calc.draft;

    if (d == null) {
      return const Scaffold(body: Center(child: Text('No record found')));
    }

    final fmt = NumberFormat.currency(symbol: currencySymbol(currency), decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Zakat Summary')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Nisab status banner
          _NisabBanner(met: d.nisabMet),
          const SizedBox(height: 20),

          // Asset breakdown
          _Card(
            title: 'Asset Breakdown',
            children: [
              _Row('Cash (${currency})', fmt.format(d.cashLocal)),
              ...d.foreignCash.map((e) => _Row(
                    'Cash (${e.currency})',
                    fmt.format(e.localValue),
                    sub: '${e.amount.toStringAsFixed(2)} ${e.currency} × ${e.exchangeRate.toStringAsFixed(4)}',
                  )),
              ...d.goldEntries.map((e) => _Row(
                    'Gold ${e.carat}K (${e.grams}g)',
                    fmt.format(e.localValue),
                    sub: '${(e.pricePerGram24k * e.purity).toStringAsFixed(2)}/g',
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
                'Zakat Due (2.5%)',
                fmt.format(d.zakatDue),
                bold: true,
                valueColor: kPrimaryGreen,
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (calc.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(calc.error!,
                  style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ),

          if (!d.isSubmitted) ...[
            ElevatedButton(
              onPressed: calc.loading
                  ? null
                  : () async {
                      await calc.submitDraft(auth.user!.uid);
                      if (context.mounted && calc.error == null) {
                        // Navigate to tracker for the just-submitted record
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const TrackerScreen()),
                          (r) => r.isFirst,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen),
              child: calc.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm & Submit'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Once submitted, this record will be locked and saved permanently.',
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
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.green),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Submitted and locked.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
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
  const _NisabBanner({required this.met});

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
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  met
                      ? 'Zakat is due on your wealth.'
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
                    fontSize: 14, fontWeight: FontWeight.bold, color: kPrimaryGreen)),
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

  const _Row(this.label, this.value, {this.sub, this.bold = false, this.valueColor});

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
                  Text(sub!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
