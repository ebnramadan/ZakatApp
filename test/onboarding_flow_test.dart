import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/models/user_profile.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/services/price_service.dart';
import 'package:zakat_app/ui/calculator/one_pager_screen.dart';
import 'package:zakat_app/ui/onboarding/onboarding_screen.dart';
import 'push_reminder_card_test.dart' show TestPushService;

class SetupStore extends FirestoreService {
  SetupStore({required FakeFirebaseFirestore database})
      : super(database: database);
  bool failSetup = false;
  @override
  Future<void> updateProfileFields(String uid, Map<String, dynamic> fields) {
    if (failSetup && fields['onboardingCompleted'] == true) {
      return Future.error(StateError('Offline'));
    }
    return super.updateProfileFields(uid, fields);
  }
}

class DeferredPushService extends TestPushService {
  final configurationReady = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> configuration() => configurationReady.future;
}

class UnsupportedPush extends TestPushService {
  @override
  String get support => 'unsupported';
}

void main() {
  Future<
          ({
            AuthProvider auth,
            CalculatorProvider calc,
            SetupStore store,
            FakeFirebaseFirestore db
          })>
      mount(WidgetTester tester, TestPushService push,
          {bool failSetup = false, bool review = false}) async {
    final db = FakeFirebaseFirestore();
    final store = SetupStore(database: db)..failSetup = failSetup;
    await store.saveProfile(UserProfile(
        uid: 'u',
        displayName: 'Tester',
        email: 'u@example.com',
        currency: 'EGP',
        monthlyDefaultKind: 'zakat',
        onboardingCompleted: review));
    final auth = AuthProvider(
        auth: AuthService(
            auth: MockFirebaseAuth(
                mockUser: MockUser(
                    uid: 'u', email: 'u@example.com', isEmailVerified: true),
                signedIn: true)),
        store: store);
    final calc = CalculatorProvider(
        store: store,
        prices: PriceService.forTesting(
            MockClient((_) async => http.Response('Unavailable', 503))));
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: calc)
        ],
        child: Consumer<AuthProvider>(
            builder: (context, a, _) => MaterialApp(
                home: a.profile == null
                    ? const SizedBox()
                    : a.profile!.onboardingCompleted
                        ? Builder(
                            builder: (context) => Scaffold(
                                body: TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => OnboardingScreen(
                                                review: true,
                                                notificationService: push))),
                                    child: const Text('Home ready'))))
                        : OnboardingScreen(notificationService: push)))));
    await tester.pumpAndSettle();
    if (review) {
      await tester.tap(find.text('Home ready'));
      await tester.pumpAndSettle();
    }
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      calc.dispose();
    });
    return (auth: auth, calc: calc, store: store, db: db);
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
  }

  for (final permission in ['granted', 'denied']) {
    testWidgets(
        'Next requests permission ($permission), defaults to Sadaqah and opens calculator above Home',
        (tester) async {
      final push = TestPushService()..permissionResult = permission;
      final state = await mount(tester, push);
      await next(tester);
      await next(tester);
      expect(find.text('Zakat'), findsNothing);
      expect(find.text('Enable notifications on this device'), findsNothing);
      await next(tester);
      expect(push.permissionRequests, 1);
      expect(push.registrations, permission == 'granted' ? 1 : 0);
      expect(state.auth.profile!.onboardingCompleted, false);
      await next(tester);
      expect(find.byType(OnePagerScreen), findsOneWidget);
      expect(state.auth.profile!.monthlyDefaultKind, 'sadaqah');
      expect(state.auth.profile!.onboardingCompleted, true);
      expect(state.calc.draft!.currency, 'EGP');
      expect((await state.db.collection('users/u/zakatRecords').get()).docs,
          isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Home ready'), findsOneWidget);
      expect(find.text('Leave calculation?'), findsNothing);
    });
  }
  testWidgets(
      'notification permission is requested before waiting for configuration',
      (tester) async {
    final push = DeferredPushService();
    await mount(tester, push);
    await next(tester);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    expect(push.permissionRequests, 1);
    expect(push.registrations, 0);
    push.configurationReady.complete({'publicKey': 'B${'a' * 86}'});
    await tester.pumpAndSettle();
    expect(push.registrations, 1);
    expect(find.text('Let’s calculate your Zakat.'), findsOneWidget);
  });
  testWidgets(
      'notification setup failure is retryable and can be skipped without blocking calculation',
      (tester) async {
    final push = TestPushService()..configFails = true;
    await mount(tester, push);
    await next(tester);
    await next(tester);
    await next(tester);
    expect(find.text('A gentle nudge to give.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-skip-notifications')));
    await tester.pumpAndSettle();
    await next(tester);
    expect(find.byType(OnePagerScreen), findsOneWidget);
  });
  testWidgets(
      'failed setup save keeps the final page and does not start a draft until retry succeeds',
      (tester) async {
    final state = await mount(tester, UnsupportedPush(), failSetup: true);
    await next(tester);
    await next(tester);
    await next(tester);
    await next(tester);
    expect(state.auth.profile!.onboardingCompleted, false);
    expect(state.calc.draft, isNull);
    expect(find.text('Let’s calculate your Zakat.'), findsOneWidget);
    state.store.failSetup = false;
    await next(tester);
    expect(find.byType(OnePagerScreen), findsOneWidget);
  });
  testWidgets(
      'review guide preserves an existing Zakat monthly preference and starts no new draft',
      (tester) async {
    final state = await mount(tester, UnsupportedPush(), review: true);
    await next(tester);
    await next(tester);
    await next(tester);
    await next(tester);
    expect(state.auth.profile!.monthlyDefaultKind, 'zakat');
    expect(state.calc.draft, isNull);
    expect(find.text('Home ready'), findsOneWidget);
  });
}
