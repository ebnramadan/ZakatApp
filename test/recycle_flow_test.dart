import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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

void main() {
  testWidgets(
      'mobile dashboard, warning cancellation, recycle bin and restore preserve payment history',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = FakeFirebaseFirestore();
    // All UI providers use the same local fixture database.
    final local = FirestoreService(database: db);
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
    await local.saveRecord(fixtures.record('Annual Zakat'));
    await local.addPayment(fixtures.payment('p', 'Annual Zakat', 100));
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: calc),
      ChangeNotifierProvider.value(value: tracker),
      ChangeNotifierProvider.value(value: monthly),
    ], child: MaterialApp(theme: AppTheme.light, home: const HomeScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Assalamu alaikum, u.'), findsOneWidget);
    expect(find.text('USD 150.00'), findsOneWidget);
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Record actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Record actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to recycle bin'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You can restore everything for 60 days'),
        findsOneWidget);
    await tester.tap(find.text('Keep record'));
    await tester.pumpAndSettle();
    expect(
        (await db.doc('users/u/zakatRecords/Annual Zakat').get())
            .data()!['deletedAt'],
        isNull);
    await tester.tap(find.byTooltip('Record actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to recycle bin'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move to recycle bin'));
    await tester.pumpAndSettle();
    expect(calc.records, isEmpty);
    expect(calc.recycledRecords, hasLength(1));
    await tester.tap(find.text('Recycle bin (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Restore record'), findsOneWidget);
    await tester.ensureVisible(find.text('Restore record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore record'));
    await tester.pumpAndSettle();
    expect(calc.records, hasLength(1));
    expect(calc.recycledRecords, isEmpty);
    expect((await db.doc('users/u/payments/p').get()).data()!['amount'], 100);
    expect(find.text('Your recycle bin is empty'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    calc.dispose();
    tracker.dispose();
    monthly.dispose();
  });
}
