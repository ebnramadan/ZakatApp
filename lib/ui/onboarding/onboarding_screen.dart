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
  final _scroll = ScrollController();
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
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int next) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => step = next);
  }

  Future<void> _next() async {
    if (step < 2) {
      _go(step + 1);
      return;
    }
    setState(() => busy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfileFields(
        monthlyDefaultKind: monthlyKind,
        currency: currency,
        language: language,
        onboardingCompleted: true);
    if (!mounted) return;
    setState(() => busy = false);
    if (ok && widget.review) {
      Navigator.pop(context);
    } else if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l(context, auth.error!))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Column(children: [
                  Row(children: [
                    Image.asset('assets/brand/icon.png', width: 32, height: 32),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(l(context, 'Zakat Tracker'),
                            style: Theme.of(context).textTheme.titleLarge)),
                    const SizedBox(width: 8),
                    Text(l(context, '{0} of {1}', [step + 1, 3]),
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: (step + 1) / 3, minHeight: 3),
                ])),
            Expanded(child: LayoutBuilder(builder: (context, constraints) {
              final gap = constraints.maxHeight < 430 ? 12.0 : 20.0;
              return SingleChildScrollView(
                key: const Key('onboarding-content'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                                padding: const EdgeInsetsDirectional.only(
                                    top: 4, end: 12),
                                child: Icon(
                                    [
                                      Icons.mosque_outlined,
                                      Icons.tune,
                                      Icons.volunteer_activism_outlined
                                    ][step],
                                    size: 32,
                                    color: kPrimaryGreen)),
                            Expanded(
                                child: Semantics(
                                    header: true,
                                    child: Text(
                                        l(
                                            context,
                                            [
                                              'Give for Allah, with intention.',
                                              'Make it feel like yours.',
                                              'A simple rhythm for giving.'
                                            ][step]),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium))),
                          ]),
                      SizedBox(height: gap),
                      if (step == 0) ...[
                        Text(l(context,
                            'Calculate your Zakat, keep track of what you give, and build a regular habit of Sadaqah.')),
                        SizedBox(height: gap),
                        _Benefit(
                            icon: Icons.lock_outline,
                            title: l(context, 'Private to your account'),
                            detail: l(context,
                                'Your financial data is shared only when you enable sharing.')),
                        const SizedBox(height: 16),
                        _Benefit(
                            icon: Icons.star_outline,
                            title: l(context, 'One default record'),
                            detail: l(context,
                                'A clear dashboard focused on your current Zakat.')),
                      ],
                      if (step == 1) ...[
                        Text(l(context, 'Language / اللغة'),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                  value: 'en',
                                  label: Text(l(context, 'English'))),
                              const ButtonSegment(
                                  value: 'ar', label: Text('العربية')),
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
                        SizedBox(height: gap),
                        SearchablePicker<String>(
                            label: l(context, 'Your currency'),
                            value: currency,
                            options: currencyOptions,
                            onChanged: (v) => setState(() => currency = v)),
                        const SizedBox(height: 12),
                        Text(
                            l(context,
                                'Suggested from your device region, or EGP when unavailable. You can change it.'),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Text(
                            l(context,
                                'Your language applies throughout the app. Currency changes apply to new records; existing amounts are never converted.'),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (step == 2) ...[
                        Text(l(context, 'Default for monthly giving'),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                            segments: [
                              ButtonSegment(
                                  value: 'sadaqah',
                                  label: Text(l(context, 'Sadaqah'))),
                              ButtonSegment(
                                  value: 'zakat',
                                  label: Text(l(context, 'Zakat'))),
                            ],
                            selected: {
                              monthlyKind
                            },
                            onSelectionChanged: (v) =>
                                setState(() => monthlyKind = v.single)),
                        const SizedBox(height: 12),
                        Text(l(
                            context,
                            monthlyKind == 'sadaqah'
                                ? 'Extra giving, separate from Zakat. You can choose differently for each recipient.'
                                : 'Counts toward the Zakat record you choose, only after you confirm payment.')),
                        SizedBox(height: gap),
                        Text(
                            l(context,
                                'Add a recipient and amount in Monthly Giving. Mark payments after you give.'),
                            style: Theme.of(context).textTheme.bodySmall),
                        SizedBox(height: gap),
                        Text(
                            l(context,
                                'May Allah accept your good intentions and bless what you give.'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: kPrimaryGreen,
                                    fontWeight: FontWeight.w600)),
                      ],
                    ]),
              );
            })),
            // Actions are outside the scroll view and above the iPhone home indicator.
            Container(
                key: const Key('onboarding-footer'),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE8DFD2)))),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          key: const Key('onboarding-back'),
                          onPressed:
                              step == 0 || busy ? null : () => _go(step - 1),
                          child: Text(l(context, 'Back')))),
                  const SizedBox(width: 12),
                  Expanded(
                      flex: 2,
                      child: FilledButton(
                          key: const Key('onboarding-next'),
                          onPressed: busy ? null : _next,
                          child: Text(busy
                              ? l(context, 'Saving…')
                              : step == 2
                                  ? l(context, 'Start tracking')
                                  : l(context, 'Next')))),
                ])),
          ]),
        ))),
      );
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title, detail;
  const _Benefit(
      {required this.icon, required this.title, required this.detail});
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: kPrimaryGreen, size: 22),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ])),
      ]);
}
