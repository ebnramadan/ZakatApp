import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/location_currency_button.dart';
import '../notifications/push_reminder_card.dart';
import '../../core/services/push_service.dart';
import '../../core/providers/calculator_provider.dart';
import '../calculator/one_pager_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool review;
  final PushService? notificationService;
  const OnboardingScreen(
      {super.key, this.review = false, this.notificationService});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  late String currency, language;
  final _notificationKey = GlobalKey<PushReminderCardState>();
  final _scroll = ScrollController();
  bool busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = context.read<AuthProvider>().profile!;
    currency = p.onboardingCompleted ? p.currency : 'EGP';
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
    setState(() {
      step = next;
      _error = null;
    });
  }

  Future<void> _next() async {
    if (busy) return;
    if (step < 2) {
      _go(step + 1);
      return;
    }
    if (step == 2) {
      setState(() => busy = true);
      final enabled =
          await _notificationKey.currentState?.enableFromOnboarding() ?? false;
      if (!mounted) return;
      setState(() => busy = false);
      if (enabled) _go(3);
      return;
    }
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final calc = widget.review ? null : context.read<CalculatorProvider>();
    setState(() {
      busy = true;
      _error = null;
    });
    final ok = await auth.completeOnboarding(
        currency: currency,
        language: language,
        monthlyDefaultKind:
            widget.review ? auth.profile!.monthlyDefaultKind : 'sadaqah');
    if (!navigator.mounted) return;
    if (!ok) {
      if (mounted) {
        setState(() {
          busy = false;
          _error = auth.error;
        });
      }
      return;
    }
    if (widget.review) {
      if (mounted) navigator.pop();
    } else {
      calc!.startNewRecord(auth.user!.uid, currency,
          language: language,
          previousDefaultRecordId:
              calc.defaultRecord(auth.profile?.defaultRecordId)?.id);
      navigator.push(MaterialPageRoute(builder: (_) => const OnePagerScreen()));
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
                    Text(l(context, '{0} of {1}', [step + 1, 4]),
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: (step + 1) / 4, minHeight: 3),
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
                                      Icons.notifications_outlined,
                                      Icons.calculate_outlined
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
                                              'A gentle nudge to give.',
                                              'Let’s calculate your Zakat.'
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
                                'A clear Home screen focused on your current Zakat.')),
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
                        LocationCurrencyButton(
                            onSelected: (v) => setState(() => currency = v)),
                        Text(
                            l(context,
                                'EGP is the default. Choose a currency manually or use your location once to fill it in.'),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Text(
                            l(context,
                                'Currency changes only affect new records. Existing amounts are never converted.'),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (step == 2) ...[
                        Text(
                            l(context,
                                'Tap Next to allow notifications. You can also set them up later from Profile.'),
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        PushReminderCard(
                            key: _notificationKey,
                            compact: true,
                            showEnableButton: false,
                            service: widget.notificationService),
                        TextButton(
                            key: const Key('onboarding-skip-notifications'),
                            onPressed: busy ? null : () => _go(3),
                            child: Text(l(context, 'Not now'))),
                      ],
                      if (step == 3) ...[
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(l(context, _error!),
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        Text(l(context,
                            'Add your cash and gold on one page, then review your Zakat.')),
                        SizedBox(height: gap),
                        _Benefit(
                            icon: Icons.calculate_outlined,
                            title: l(context, 'Your first Zakat calculation'),
                            detail: l(context,
                                'Your calculation appears on Home after you save it.')),
                        SizedBox(height: gap),
                        _Benefit(
                            icon: Icons.calendar_month_outlined,
                            title: l(context, 'Monthly giving'),
                            detail: l(
                                context,
                                widget.review
                                    ? 'Change your monthly giving default anytime in Profile.'
                                    : 'Monthly giving defaults to Sadaqah. You can change it anytime in Profile.')),
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
                              ? l(context, step == 2 ? 'Enabling…' : 'Saving…')
                              : step == 3
                                  ? l(
                                      context,
                                      widget.review
                                          ? 'Done'
                                          : 'Calculate my Zakat')
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
