import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/models/user_profile.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/providers/tracker_provider.dart';
import 'package:zakat_app/core/providers/monthly_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/services/monthly_service.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/home/home_screen.dart';
import 'dashboard_recycle_test.dart' as fixtures;
import 'package:zakat_app/ui/dashboard/dashboard_screen.dart';
import 'package:zakat_app/ui/calculator/results_screen.dart';

void main() {
  for (final keepCurrent in [true, false]) {
    testWidgets(
        'submitting a second record respects keep current default ($keepCurrent)',
        (tester) async {
      final db = FakeFirebaseFirestore();
      final store = FirestoreService(database: db);
      await store.saveProfile(UserProfile(
          uid: 'u',
          displayName: 'Tester',
          email: 'u@example.com',
          defaultRecordId: 'previous',
          onboardingCompleted: true));
      await store.saveRecord(fixtures.record('previous', currency: 'EGP'));
      final auth = AuthProvider(
          auth: AuthService(
              auth: MockFirebaseAuth(
                  mockUser: MockUser(
                      uid: 'u', email: 'u@example.com', isEmailVerified: true),
                  signedIn: true)),
          store: store);
      final calc = CalculatorProvider(store: store)..loadRecords('u');
      final tracker = TrackerProvider(store: store);
      final monthly = MonthlyProvider(store: MonthlyService(database: db));
      calc.startNewRecord('u', 'EGP', previousDefaultRecordId: 'previous');
      final newId = calc.draft!.id;
      calc.updateGoldPrice(100);
      calc.draft!.cashLocal = 10000;
      calc.draft!.hawlStartDate = DateTime(2023);
      calc.computeResults();
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: calc),
            ChangeNotifierProvider.value(value: tracker),
            ChangeNotifierProvider.value(value: monthly),
          ],
          child:
              MaterialApp(theme: AppTheme.light, home: const ResultsScreen())));
      await tester.pumpAndSettle();
      if (keepCurrent) {
        await tester.scrollUntilVisible(
            find.text('Keep my current default instead'), 300,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep my current default instead'));
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(find.text('Confirm & Submit'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Submit'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(auth.profile!.defaultRecordId, keepCurrent ? 'previous' : newId);
      expect(
          (await db.doc('users/u/zakatRecords/$newId').get())
              .data()!['isSubmitted'],
          true);
      expect(
          (await db.doc('users/u/zakatRecords/previous').get())
              .data()!['isSubmitted'],
          true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      calc.dispose();
      tracker.dispose();
      monthly.dispose();
    });
  }

  for (final belowNisab in [false, true]) {
    testWidgets(
        'new calculation action only follows a paid positive Zakat target ($belowNisab)',
        (tester) async {
      final db = FakeFirebaseFirestore();
      final store = FirestoreService(database: db);
      await store.saveProfile(UserProfile(
          uid: 'u',
          displayName: 'Tester',
          email: 'u@example.com',
          defaultRecordId: 'paid',
          onboardingCompleted: true));
      final record = fixtures.record('paid', currency: 'EGP');
      if (belowNisab) record.nisabMet = false;
      await store.saveRecord(record);
      if (!belowNisab) {
        await store.addPayment(fixtures.payment('full', 'paid', 250));
      }
      final auth = AuthProvider(
          auth: AuthService(
              auth: MockFirebaseAuth(
                  mockUser: MockUser(
                      uid: 'u', email: 'u@example.com', isEmailVerified: true),
                  signedIn: true)),
          store: store);
      final calc = CalculatorProvider(store: store)..loadRecords('u');
      final monthly = MonthlyProvider(store: MonthlyService(database: db))
        ..load('u');
      var started = false;
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: calc),
            ChangeNotifierProvider.value(value: monthly),
          ],
          child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                  body: DashboardScreen(
                      onRecords: () {},
                      onMonthly: () {},
                      onCreate: () => started = true,
                      onRecord: (_) {})))));
      await tester.pumpAndSettle();
      expect(find.text('Calculate new Zakat'),
          belowNisab ? findsNothing : findsOneWidget);
      if (!belowNisab) {
        await tester.ensureVisible(find.text('Calculate new Zakat'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Calculate new Zakat'));
        expect(started, true);
        expect(
            (await db.doc('users/u/zakatRecords/paid').get())
                .data()!['isSubmitted'],
            true);
      }
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      calc.dispose();
      monthly.dispose();
    });
  }

  testWidgets(
      'saved default drives both dashboard and tracker and can be changed from Records',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final local = FirestoreService(database: db);
    await local.saveProfile(UserProfile(
        uid: 'u',
        displayName: 'Tester',
        email: 'u@example.com',
        defaultRecordId: 'b',
        onboardingCompleted: true));
    await local.saveRecord(fixtures.record('a'));
    await local.saveRecord(fixtures.record('b', currency: 'EGP'));
    await local.addPayment(fixtures.payment('pb', 'b', 100));
    final auth = AuthProvider(
        auth: AuthService(
            auth: MockFirebaseAuth(
                mockUser: MockUser(
                    uid: 'u', email: 'u@example.com', isEmailVerified: true),
                signedIn: true)),
        store: local);
    final calc = CalculatorProvider(store: local),
        tracker = TrackerProvider(store: local),
        monthly = MonthlyProvider(store: MonthlyService(database: db));
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: calc),
      ChangeNotifierProvider.value(value: tracker),
      ChangeNotifierProvider.value(value: monthly)
    ], child: MaterialApp(theme: AppTheme.light, home: const HomeScreen())));
    await tester.pumpAndSettle();
    expect(find.text('EGP 150.00'), findsOneWidget);
    expect(find.text('USD 250.00'), findsNothing);
    await tester.tap(find.text('Tracker'));
    await tester.pumpAndSettle();
    expect(tracker.selectedRecord!.id, 'b');
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all records'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Set as default'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set as default'));
    await tester.pumpAndSettle();
    expect(auth.profile!.defaultRecordId, 'a');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('USD 250.00'), findsWidgets);
    expect(find.text('EGP 150.00'), findsNothing);
    await tester.tap(find.text('Tracker'));
    await tester.pumpAndSettle();
    expect(tracker.selectedRecord!.id, 'a');
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    calc.dispose();
    tracker.dispose();
    monthly.dispose();
  });
}
