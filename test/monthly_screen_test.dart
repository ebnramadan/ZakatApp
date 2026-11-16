import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/models/monthly_giving.dart';
import 'package:zakat_app/core/models/zakat_record.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/providers/tracker_provider.dart';
import 'package:zakat_app/core/providers/monthly_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/services/monthly_service.dart';
import 'package:zakat_app/ui/auth/login_screen.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/home/home_screen.dart';

void main() {
  testWidgets('Google is primary and email sign-up is an explicit alternative',
      (tester) async {
    final auth = AuthProvider(
        auth: AuthService(auth: MockFirebaseAuth()),
        store: FirestoreService(database: FakeFirebaseFirestore()));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Use email instead'));
    await tester.pumpAndSettle();
    expect(find.text('Create an account with email'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
  testWidgets(
      'monthly Zakat is managed in Monthly and reflected read-only in Tracker',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final store = FirestoreService(database: db);
    final auth = AuthProvider(
        auth: AuthService(
            auth: MockFirebaseAuth(
                mockUser: MockUser(
                    uid: 'u', email: 'u@example.com', isEmailVerified: true),
                signedIn: true)),
        store: store);
    final calc = CalculatorProvider(store: store);
    final tracker = TrackerProvider(store: store);
    final monthly = MonthlyProvider(store: MonthlyService(database: db));
    final record = ZakatRecord(
        id: 'r',
        userId: 'u',
        name: 'Annual Zakat',
        currency: 'USD',
        hawlStartDate: DateTime(2023),
        createdAt: DateTime(2023),
        isSubmitted: true,
        totalWealth: 10000,
        nisabThreshold: 8500,
        nisabMet: true,
        zakatDue: 250,
        goldPricePerGram24k: 100);
    await db.doc('users/u/zakatRecords/r').set(record.toMap());
    final plan = MonthlyPlan(
        id: 'p',
        userId: 'u',
        recipient: 'Family support',
        amount: 100,
        currency: 'USD',
        kind: 'zakat',
        zakatRecordId: 'r',
        startMonth: monthKey(DateTime.now()),
        reminderDay: 1,
        createdAt: DateTime.now());
    await MonthlyService(database: db).savePlan(plan);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: calc),
          ChangeNotifierProvider.value(value: tracker),
          ChangeNotifierProvider.value(value: monthly)
        ],
        child: MaterialApp(
            theme: AppTheme.light, home: const HomeScreen(initialTab: 2))));
    await tester.pumpAndSettle();
    expect(find.text('Family support'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mark as paid'), 300,
        scrollable: find
            .descendant(
                of: find.byKey(const Key('monthly-list')),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as paid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, I paid'));
    await tester.pumpAndSettle();
    expect(find.text('Undo payment'), findsOneWidget);
    expect(tracker.totalPaid, 100);
    await tester.tap(find.text('Tracker'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Manage in شهريات'), findsOneWidget);
    await tester.tap(find.text('شهريات'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Undo payment'), 300,
        scrollable: find
            .descendant(
                of: find.byKey(const Key('monthly-list')),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Undo payment'));
    await tester.pumpAndSettle();
    expect(tracker.totalPaid, 0);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    calc.dispose();
    tracker.dispose();
    monthly.dispose();
  });
}
