import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import 'wizard_screen.dart';
import 'one_pager_screen.dart';

class EntryModeScreen extends StatelessWidget {
  const EntryModeScreen({super.key});

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
                  "Choose a pace that works for you. Both use the same calculation."),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _ModeCard(
              title: l(context, "Guided Wizard"),
              subtitle: l(context,
                  "Step-by-step walkthrough\nRecommended for first-timers"),
              icon: Icons.auto_awesome,
              onTap: () => _start(context, wizard: true),
            ),
            const SizedBox(height: 16),
            _ModeCard(
              title: l(context, "One-Pager"),
              subtitle:
                  l(context, "All fields on one screen\nFor returning users"),
              icon: Icons.list_alt,
              onTap: () => _start(context, wizard: false),
            ),
          ],
        ),
      ),
    );
  }

  void _start(BuildContext context, {required bool wizard}) {
    final auth = context.read<AuthProvider>();
    final calc = context.read<CalculatorProvider>();
    calc.startNewRecord(auth.user!.uid, auth.profile!.currency,
        language: auth.language);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => wizard ? const WizardScreen() : const OnePagerScreen(),
    ));
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kPrimaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: kPrimaryGreen, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l(context, title),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(l(context, subtitle),
                      style: const TextStyle(
                          fontSize: 13, color: Colors.grey, height: 1.4)),
                ],
              )),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
