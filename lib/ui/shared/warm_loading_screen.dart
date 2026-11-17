import 'dart:math' as math;
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
  late final AnimationController _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: givingCream,
      body: Center(
          child: Semantics(
              label: l(context, 'Preparing your space for giving'),
              liveRegion: true,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(
                    animation: _motion,
                    builder: (context, _) => Transform.translate(
                        offset: Offset(
                            0, math.sin(_motion.value * math.pi * 2) * 3),
                        child: GivingArtwork(
                            accentColor: kPrimaryGreen,
                            outlineColor: kPrimaryGreen,
                            progress: .75 +
                                math.sin(_motion.value * math.pi * 2) * .25))),
                const SizedBox(height: 18),
                Text(l(context, 'Small acts. Lasting good.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryGreen)),
                const SizedBox(height: 8),
                Text(l(context, 'Preparing your space for giving'),
                    style: const TextStyle(fontSize: 12, color: givingBrown)),
              ]))));
}
