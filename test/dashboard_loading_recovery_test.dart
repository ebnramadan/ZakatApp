import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakat_app/core/models/payment.dart';
import 'package:zakat_app/core/models/monthly_giving.dart';
import 'package:zakat_app/core/models/user_profile.dart';
import 'package:zakat_app/core/models/zakat_record.dart';
import 'package:zakat_app/core/platform/browser_insets.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/providers/monthly_provider.dart';
import 'package:zakat_app/core/providers/tracker_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/services/monthly_service.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/home/home_screen.dart';
import 'dashboard_recycle_test.dart' as fixtures;

class SuspendedStore extends FirestoreService {
  bool online = false;
  bool healOnReconnect = false;
  bool failRecords = false;
  int restarts = 0;
  int recordSubscriptions = 0;
  final connected = Completer<void>();
  SuspendedStore(FakeFirebaseFirestore db) : super(database: db);
  @override
  Future<void> reconnectNetwork() async {
    restarts++;
    if (healOnReconnect) online = true;
    if (!connected.isCompleted) connected.complete();
  }

  @override
  Stream<List<ZakatRecord>> recordsStream(String uid) {
    recordSubscriptions++;
    if (!online && failRecords) {
      return Stream.error(StateError('Connection interrupted'));
    }
    return online
        ? Stream.value([fixtures.record('annual')])
        : const Stream.empty();
  }

  @override
  Stream<List<Payment>> allPaymentsStream(String uid) => online
      ? Stream.value([fixtures.payment('p', 'annual', 100)])
      : const Stream.empty();
}

class DelayedMonthlyStore extends MonthlyService {
  final planEvents = StreamController<List<MonthlyPlan>>();
  final paymentEvents = StreamController<List<MonthlyPayment>>();
  DelayedMonthlyStore() : super(database: FakeFirebaseFirestore());
  @override
  Stream<List<MonthlyPlan>> plans(String uid) => planEvents.stream;
  @override
  Stream<List<MonthlyPayment>> payments(String uid) => paymentEvents.stream;
  @override
  Stream<bool> emailReadiness() => Stream.value(false);
}

void main() {
  test('silent initial streams reconnect automatically and recover saved data',
      () async {
    final store = SuspendedStore(FakeFirebaseFirestore())
      ..healOnReconnect = true;
    final calc = CalculatorProvider(
        store: store, initialLoadTimeout: const Duration(milliseconds: 20));
    final ready = Completer<void>();
    calc.addListener(() {
      if (!calc.recordsLoading &&
          !calc.paymentsLoading &&
          calc.records.isNotEmpty &&
          !ready.isCompleted) ready.complete();
    });
    calc.loadRecords('u');
    await ready.future.timeout(const Duration(seconds: 2));
    expect(store.restarts, 1);
    expect(store.recordSubscriptions, 2);
    expect(calc.records.single.name, 'annual');
    expect(calc.allPayments.single.amount, 100);
    expect(calc.recordsError, isNull);
    expect(calc.paymentsError, isNull);
    calc.dispose();
  });
  test(
      'a persistently silent connection ends in a retry state and late retry can recover',
      () async {
    final store = SuspendedStore(FakeFirebaseFirestore());
    final calc = CalculatorProvider(
        store: store, initialLoadTimeout: const Duration(milliseconds: 20));
    final failed = Completer<void>();
    calc.addListener(() {
      if (!calc.recordsLoading &&
          !calc.paymentsLoading &&
          calc.recordsError != null &&
          !failed.isCompleted) failed.complete();
    });
    calc.loadRecords('u');
    await failed.future.timeout(const Duration(seconds: 2));
    expect(store.restarts, 1);
    expect(calc.paymentsError, isNotNull);
    store.online = true;
    await calc.retryRecords('u');
    await Future<void>.delayed(Duration.zero);
    expect(calc.recordsError, isNull);
    expect(calc.paymentsError, isNull);
    expect(calc.records.single.name, 'annual');
    calc.dispose();
  });
  for (final failRecords in [false, true]) {
    testWidgets(
        '${failRecords ? 'Error plus stalled' : 'Silent'} login load offers retry and recovers after app resume without reopening',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = FakeFirebaseFirestore(),
          store = SuspendedStore(FakeFirebaseFirestore())
            ..failRecords = failRecords;
      await store.saveProfile(UserProfile(
          uid: 'u',
          displayName: 'Ahmed',
          email: 'u@example.com',
          defaultRecordId: 'annual',
          onboardingCompleted: true));
      final auth = AuthProvider(
          auth: AuthService(
              auth: MockFirebaseAuth(
                  mockUser: MockUser(
                      uid: 'u', email: 'u@example.com', isEmailVerified: true),
                  signedIn: true)),
          store: store);
      final calc = CalculatorProvider(
              store: store, initialLoadTimeout: const Duration(hours: 1)),
          tracker = TrackerProvider(store: store),
          monthly = MonthlyProvider(store: MonthlyService(database: db));
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: calc),
        ChangeNotifierProvider.value(value: tracker),
        ChangeNotifierProvider.value(value: monthly)
      ], child: MaterialApp(theme: AppTheme.light, home: const HomeScreen())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          find.text(failRecords
              ? 'Your progress couldn’t load'
              : 'Loading your saved records…'),
          findsOneWidget);
      if (!failRecords) expect(find.text('Retry connection'), findsOneWidget);
      expect(find.text('Begin with your Zakat'), findsNothing);
      store.online = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(store.restarts, 1);
      expect(find.text('Loading your saved records…'), findsNothing);
      expect(find.text('annual'), findsOneWidget);
      expect(calc.allPayments.single.amount, 100);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      calc.dispose();
      tracker.dispose();
      monthly.dispose();
    });
  }
  testWidgets(
      'monthly timeout stays recoverable when just one late snapshot arrives',
      (tester) async {
    final store = DelayedMonthlyStore();
    final monthly = MonthlyProvider(store: store)..load('u');
    await tester.pump(const Duration(seconds: 21));
    expect(monthly.loading, false);
    expect(monthly.error, isNotNull);
    store.planEvents.add([]);
    await tester.pump();
    expect(monthly.loading, false);
    expect(monthly.error, isNotNull);
    store.paymentEvents.add([]);
    await tester.pump();
    expect(monthly.loading, false);
    expect(monthly.error, isNull);
    monthly.dispose();
    store.planEvents.close();
    store.paymentEvents.close();
    await tester.pump();
  });
  test(
      'iPhone standalone zero-inset fallback protects home indicator without doubling real insets',
      () {
    double bottom(
            {double reported = 0,
            bool ios = true,
            bool standalone = true,
            double width = 393,
            double height = 852}) =>
        resolveBrowserBottomInset(
            reportedBottom: reported,
            isIosPhone: ios,
            standalone: standalone,
            screenWidth: width,
            screenHeight: height);
    expect(bottom(), 34);
    expect(bottom(reported: 34), 34);
    expect(bottom(reported: 21, width: 852, height: 393), 21);
    expect(bottom(width: 852, height: 393), 21);
    expect(bottom(ios: false), 0);
    expect(bottom(standalone: false), 0);
    expect(bottom(width: 375, height: 667), 0);
    expect(bottom(width: 768, height: 1024), 0);
  });
}
