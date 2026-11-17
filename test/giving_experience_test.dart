import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/shared/giving_celebration.dart';
import 'package:zakat_app/ui/shared/warm_loading_screen.dart';

void main() {
  testWidgets(
      'cream loading scene settles with reduced motion and enlarged text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: const WarmLoadingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Small acts. Lasting good.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final planReady in [true, false]) {
    testWidgets(
        '${planReady ? "Plan" : "Sadaqah"} celebration keeps its meaning and can close on a small phone',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: const TextScaler.linear(1.5)),
              child: child!),
          home: Builder(
              builder: (context) => Scaffold(
                  body: Center(
                      child: TextButton(
                          onPressed: () => showGivingCelebration(context,
                              planReady: planReady, sadaqah: !planReady),
                          child: const Text('Open')))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
          find.text(planReady
              ? 'Your Zakat plan is ready'
              : 'A beautiful act of Sadaqah'),
          findsOneWidget);
      expect(find.text('اللهم تقبل منا وبارك لنا فيما رزقتنا'), findsOneWidget);
      final close = find.widgetWithText(FilledButton, 'Continue');
      expect(tester.getRect(close).bottom, lessThanOrEqualTo(740));
      expect(tester.takeException(), isNull);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('giving-celebration')), findsNothing);
    });
  }
}
