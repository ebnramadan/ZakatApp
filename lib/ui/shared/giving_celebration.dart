import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'giving_artwork.dart';

Future<void> showGivingCelebration(BuildContext context,
        {bool planReady = false, bool sadaqah = false}) =>
    showDialog<void>(
        context: context,
        builder: (_) => _Celebration(planReady: planReady, sadaqah: sadaqah));

class _Celebration extends StatefulWidget {
  final bool planReady, sadaqah;
  const _Celebration({required this.planReady, required this.sadaqah});
  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _animation.value = 1;
      } else {
        _animation.forward();
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          key: const Key('giving-celebration'),
          backgroundColor: givingCream,
          scrollable: true,
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                width: 216,
                height: 192,
                child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) =>
                        GivingArtwork(progress: _animation.value))),
            const SizedBox(height: 12),
            Text(
                widget.planReady
                    ? l(context, "Your Zakat plan is ready")
                    : widget.sadaqah
                        ? l(context, "A beautiful act of Sadaqah")
                        : l(context, "Your Zakat giving is recorded"),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                l(
                    context,
                    widget.planReady
                        ? 'A good intention is a beautiful beginning.'
                        : 'Small acts. Lasting good.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: givingBrown, fontSize: 13)),
            const SizedBox(height: 18),
            const Text('اللهم تقبل منا وبارك لنا فيما رزقتنا',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 23, height: 1.7, color: givingBurgundy)),
            const SizedBox(height: 12),
            Text(
                widget.planReady
                    ? l(context,
                        "May Allah bless your intention and help you fulfil your Zakat. Record payments after you give.")
                    : l(context,
                        "O Allah, accept from us and bless what You have provided us."),
                textAlign: TextAlign.center),
          ])),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(backgroundColor: givingBurgundy),
                child: Text(l(context, "Continue")))
          ]);
}
