import '../../core/localization/strings.dart';
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
  late String currency, language, monthlyKind;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = context.read<AuthProvider>().profile!;
    monthlyKind = p.monthlyDefaultKind;
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
                      Text(l(context, "Zakat Tracker"),
                          style: const TextStyle(
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
                        l(
                            context,
                            [
                              'Give for Allah, with intention.',
                              'Make it feel like yours.',
                              'A simple rhythm for giving.'
                            ][step]),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    if (step == 0) ...[
                      Text(l(context,
                          "Calculate your Zakat, keep track of what you give, and build a regular habit of Sadaqah.")),
                      const SizedBox(height: 24),
                      ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: Text(l(context, "Private to your account")),
                          subtitle: Text(l(context,
                              "Your financial data is shared only when you enable sharing."))),
                      ListTile(
                          leading: const Icon(Icons.star_outline),
                          title: Text(l(context, "One default record")),
                          subtitle: Text(l(context,
                              "A clear dashboard focused on your current Zakat."))),
                    ],
                    if (step == 1) ...[
                      SearchablePicker<String>(
                          label: l(context, "Your currency"),
                          value: currency,
                          options: currencyOptions,
                          onChanged: (v) => setState(() => currency = v)),
                      const SizedBox(height: 20),
                      SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                                value: 'en',
                                label: Text(l(context, "English"))),
                            const ButtonSegment(
                                value: 'ar', label: Text('العربية'))
                          ],
                          selected: {
                            language
                          },
                          onSelectionChanged: (v) {
                            setState(() => language = v.single);
                            context
                                .read<AuthProvider>()
                                .updateProfileFields(language: v.single);
                          }),
                      const SizedBox(height: 12),
                      Text(
                          l(context,
                              "Your language applies throughout the app. Currency changes apply to new records; existing amounts are never converted."),
                          style: const TextStyle(fontSize: 13)),
                    ],
                    if (step == 2) ...[
                      Text(l(context, 'Default for monthly giving'),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                                value: 'sadaqah',
                                label: Text(l(context, 'صدقة · Sadaqah'))),
                            ButtonSegment(
                                value: 'zakat',
                                label:
                                    Text(l(context, 'زكاة · Part of Zakat'))),
                          ],
                          selected: {
                            monthlyKind
                          },
                          onSelectionChanged: (v) =>
                              setState(() => monthlyKind = v.single)),
                      const SizedBox(height: 12),
                      Text(l(context,
                          'Sadaqah is extra giving. Zakat payments reduce the record you choose, only after you mark them paid.')),
                      const SizedBox(height: 20),
                      ListTile(
                          leading: const Icon(Icons.calculate_outlined),
                          title: Text(l(context, "1. Calculate")),
                          subtitle: Text(l(context,
                              "Use a guided form and review your results."))),
                      ListTile(
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text(l(context, "2. Record your giving")),
                          subtitle: Text(l(context,
                              "Only mark payments after you have given the money."))),
                      ListTile(
                          leading: const Icon(Icons.calendar_month_outlined),
                          title: Text(l(context, "3. Keep a monthly habit")),
                          subtitle: Text(l(context,
                              "Plan regular Sadaqah or payments toward Zakat."))),
                      const SizedBox(height: 12),
                      Text(
                          l(context,
                              "May Allah accept your good intentions and bless what you give."),
                          style: const TextStyle(
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
                                    monthlyDefaultKind: monthlyKind,
                                    currency: currency,
                                    language: language,
                                    onboardingCompleted: true);
                                if (!context.mounted) return;
                                setState(() => busy = false);
                                if (ok && widget.review) {
                                  Navigator.pop(context);
                                } else if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text(l(context, auth.error!))));
                                }
                              },
                        child: Text(busy
                            ? l(context, "Saving…")
                            : step == 2
                                ? l(context, "Start tracking")
                                : l(context, "Continue"))),
                    if (step > 0)
                      TextButton(
                          onPressed: busy ? null : () => setState(() => step--),
                          child: Text(l(context, "Back"))),
                  ])))));
}
