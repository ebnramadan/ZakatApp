import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import 'one_pager_screen.dart';

class EntryModeScreen extends StatefulWidget {
  const EntryModeScreen({super.key});

  @override
  State<EntryModeScreen> createState() => _EntryModeScreenState();
}

class _EntryModeScreenState extends State<EntryModeScreen> {
  bool _makeDefault = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l(context, "New Zakat Calculation"))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const SizedBox(height: 24),
            Text(
              l(context, "Let’s calculate your Zakat."),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryGreen),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l(context,
                  "Add your cash and gold on one page, then review your Zakat."),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
                l(
                    context,
                    _makeDefault
                        ? 'When saved or submitted, this becomes your default record for Home and Tracker.'
                        : 'Your current default will stay on Home and Tracker.'),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
                l(context,
                    'To change it later: Home → View all records → Set as default.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            if (context.read<CalculatorProvider>().records.isNotEmpty)
              TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.brown,
                      textStyle: const TextStyle(fontSize: 12),
                      minimumSize: const Size(0, 44)),
                  onPressed: () => setState(() => _makeDefault = !_makeDefault),
                  child: Text(l(
                      context,
                      _makeDefault
                          ? 'Keep my current default instead'
                          : 'Use the new record as default'))),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: () => _start(context),
                icon: const Icon(Icons.calculate_outlined),
                label: Text(l(context, 'Start calculation'))),
          ],
        ),
      ),
    );
  }

  void _start(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final calc = context.read<CalculatorProvider>();
    calc.startNewRecord(auth.user!.uid, auth.profile!.currency,
        language: auth.language,
        previousDefaultRecordId:
            calc.defaultRecord(auth.profile?.defaultRecordId)?.id);
    calc.setMakeDefault(_makeDefault);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const OnePagerScreen(),
    ));
  }
}
