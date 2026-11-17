import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakat_app/core/models/user_profile.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/onboarding/onboarding_screen.dart';
import 'push_reminder_card_test.dart' show TestPushService;

void main() {
  setUpAll(() async {
    for (final family in ['Inter', 'Tajawal']) {
      final loader = FontLoader(family);
      for (final weight in [400, 500, 700]) {
        loader.addFont(rootBundle.load('assets/fonts/$family-$weight.ttf'));
      }
      await loader.load();
    }
  });
  for (final language in ['en', 'ar']) {
    for (final size in [
      const Size(393, 852),
      const Size(375, 812),
      const Size(320, 668)
    ]) {
      testWidgets(
          'all onboarding steps fit $language $size with pinned safe-area actions',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        await tester.binding.setSurfaceSize(size);
        tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
        addTearDown(() async {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPadding();
          tester.view.resetViewPadding();
          await tester.binding.setSurfaceSize(null);
        });
        SharedPreferences.setMockInitialValues({'language': language});
        final store = FirestoreService(database: FakeFirebaseFirestore());
        await store.saveProfile(UserProfile(
            uid: 'u',
            displayName: 'Ahmed',
            email: 'u@example.com',
            language: language));
        final auth = AuthProvider(
            auth: AuthService(
                auth: MockFirebaseAuth(
                    mockUser: MockUser(
                        uid: 'u',
                        email: 'u@example.com',
                        isEmailVerified: true),
                    signedIn: true)),
            store: store);
        await tester.pumpWidget(ChangeNotifierProvider.value(
            value: auth,
            child: Consumer<AuthProvider>(
                builder: (context, a, _) => MaterialApp(
                    locale: Locale(a.language),
                    supportedLocales: const [Locale('en'), Locale('ar')],
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate
                    ],
                    theme: AppTheme.forLanguage(a.language),
                    home: a.profile == null
                        ? const SizedBox()
                        : OnboardingScreen(
                            notificationService: TestPushService()
                              ..schedulingConfirmed = false)))));
        await tester.pumpAndSettle();
        final next = find.byKey(const Key('onboarding-next'));
        final back = find.byKey(const Key('onboarding-back'));
        final firstFooter =
            tester.getRect(find.byKey(const Key('onboarding-footer')));
        expect(tester.widget<OutlinedButton>(back).onPressed, isNull);
        for (var step = 0; step < 4; step++) {
          final scroll = tester.state<ScrollableState>(find
              .descendant(
                  of: find.byKey(const Key('onboarding-content')),
                  matching: find.byType(Scrollable))
              .first);
          expect(scroll.position.maxScrollExtent, 0,
              reason:
                  '$language step $step on $size should fit without scrolling');
          expect(
              tester.getRect(next).bottom, lessThanOrEqualTo(size.height - 34));
          expect(
              tester.getRect(back).bottom, lessThanOrEqualTo(size.height - 34));
          expect(tester.getRect(find.byKey(const Key('onboarding-footer'))),
              firstFooter);
          expect(tester.takeException(), isNull);
          if (step < 3) {
            await tester.tap(next);
            await tester.pumpAndSettle();
          }
        }
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.byType(SegmentedButton<String>), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
      });
    }
  }
}
