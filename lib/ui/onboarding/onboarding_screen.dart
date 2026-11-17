import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants.dart';
import '../widgets/searchable_picker.dart';

class OnboardingScreen extends StatefulWidget {
  final bool review;
  const OnboardingScreen({super.key, this.review = false});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  late String currency, language;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = context.read<AuthProvider>().profile!;
    currency = p.currency;
    language = p.language;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: ListView(padding: const EdgeInsets.all(28), children: [
                    Row(children: [
                      Image.asset('assets/brand/icon.png',
                          width: 48, height: 48),
                      const SizedBox(width: 12),
                      const Text('Zakat Tracker',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('${step + 1} / 3')
                    ]),
                    const SizedBox(height: 28),
                    LinearProgressIndicator(
                        value: (step + 1) / 3, minHeight: 5),
                    const SizedBox(height: 36),
                    Icon(
                        [
                          Icons.mosque_outlined,
                          Icons.tune,
                          Icons.volunteer_activism_outlined
                        ][step],
                        size: 64,
                        color: kPrimaryGreen),
                    const SizedBox(height: 24),
                    Text(
                        [
                          'Your giving, with intention.',
                          'Make it feel like yours.',
                          'A simple rhythm for giving.'
                        ][step],
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    if (step == 0) ...[
                      const Text(
                          'Calculate your Zakat, keep track of what you give, and build a regular habit of Sadaqah.'),
                      const SizedBox(height: 24),
                      const ListTile(
                          leading: Icon(Icons.lock_outline),
                          title: Text('Private to your account'),
                          subtitle: Text(
                              'Your financial data is shared only when you enable sharing.')),
                      const ListTile(
                          leading: Icon(Icons.star_outline),
                          title: Text('One default record'),
                          subtitle: Text(
                              'A clear dashboard focused on your current Zakat.')),
                    ],
                    if (step == 1) ...[
                      SearchablePicker<String>(
                          label: 'Your currency',
                          value: currency,
                          options: currencyOptions,
                          onChanged: (v) => setState(() => currency = v)),
                      const SizedBox(height: 20),
                      SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'en', label: Text('English')),
                            ButtonSegment(value: 'ar', label: Text('العربية'))
                          ],
                          selected: {
                            language
                          },
                          onSelectionChanged: (v) =>
                              setState(() => language = v.single)),
                      const SizedBox(height: 12),
                      const Text(
                          'Language changes navigation labels. Currency changes apply to new records; existing amounts are never converted.',
                          style: TextStyle(fontSize: 13)),
                    ],
                    if (step == 2) ...[
                      const ListTile(
                          leading: Icon(Icons.calculate_outlined),
                          title: Text('1. Calculate'),
                          subtitle: Text(
                              'Use a guided form and review your results.')),
                      const ListTile(
                          leading: Icon(Icons.check_circle_outline),
                          title: Text('2. Record your giving'),
                          subtitle: Text(
                              'Only mark payments after you have given the money.')),
                      const ListTile(
                          leading: Icon(Icons.calendar_month_outlined),
                          title: Text('3. Keep a monthly habit'),
                          subtitle: Text(
                              'Plan regular Sadaqah or payments toward Zakat.')),
                      const SizedBox(height: 12),
                      const Text(
                          'May Allah accept your good intentions and bless what you give.',
                          style: TextStyle(
                              color: kPrimaryGreen,
                              fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 32),
                    FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (step < 2) {
                                  setState(() => step++);
                                  return;
                                }
                                setState(() => busy = true);
                                final auth = context.read<AuthProvider>();
                                final ok = await auth.updateProfileFields(
                                    currency: currency,
                                    language: language,
                                    onboardingCompleted: true);
                                if (!context.mounted) return;
                                setState(() => busy = false);
                                if (ok && widget.review) {
                                  Navigator.pop(context);
                                } else if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(auth.error!)));
                                }
                              },
                        child: Text(busy
                            ? 'Saving…'
                            : step == 2
                                ? 'Start tracking'
                                : 'Continue')),
                    if (step > 0)
                      TextButton(
                          onPressed: busy ? null : () => setState(() => step--),
                          child: const Text('Back')),
                  ])))));
}
