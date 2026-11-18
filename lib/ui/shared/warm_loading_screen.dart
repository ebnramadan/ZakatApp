import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization/strings.dart';
import 'giving_artwork.dart';
import '../../core/constants.dart';

class WarmLoadingScreen extends StatefulWidget {
  const WarmLoadingScreen({super.key});
  @override
  State<WarmLoadingScreen> createState() => _WarmLoadingScreenState();
}

class _WarmLoadingScreenState extends State<WarmLoadingScreen>
    with SingleTickerProviderStateMixin {
  static const _duaas = [
    'O Allah, accept our giving and bless what You have provided.',
    'O Allah, grant us a compassionate heart and open the doors of goodness.',
    'O Allah, make our giving sincerely for You, and bless those we give to.'
  ];
  int _duaa = 0;
  Timer? _rotation;
  late final AnimationController _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rotation?.cancel();
    if (!MediaQuery.accessibleNavigationOf(context)) {
      _rotation = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) setState(() => _duaa = (_duaa + 1) % _duaas.length);
      });
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = .5;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _rotation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: givingCream,
      body: Center(
          child: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Semantics(
                          label: l(context, 'Preparing your space for giving'),
                          liveRegion: true,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            AnimatedBuilder(
                                animation: _motion,
                                builder: (context, _) => Transform.translate(
                                    offset: Offset(
                                        0,
                                        math.sin(_motion.value * math.pi * 2) *
                                            3),
                                    child: GivingArtwork(
                                        accentColor: kPrimaryGreen,
                                        outlineColor: kPrimaryGreen,
                                        progress: .75 +
                                            math.sin(_motion.value *
                                                    math.pi *
                                                    2) *
                                                .25))),
                            const SizedBox(height: 18),
                            Text(l(context, 'Small acts. Lasting good.'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: kPrimaryGreen)),
                            const SizedBox(height: 8),
                            Text(l(context, 'Opening your account…'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: givingBrown)),
                            const SizedBox(height: 16),
                            const LinearProgressIndicator(
                                value: .75, minHeight: 6),
                            const SizedBox(height: 8),
                            Text(l(context, '75% · 3 of 4 startup steps'),
                                style: const TextStyle(
                                    fontSize: 12, color: givingBrown)),
                            const SizedBox(height: 18),
                            Text(l(context, _duaas[_duaa]),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: givingBrown)),
                          ])))))));
}
