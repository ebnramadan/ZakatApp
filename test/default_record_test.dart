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

void main() {
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
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Set as default'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set as default'));
    await tester.pumpAndSettle();
    expect(auth.profile!.defaultRecordId, 'a');
    await tester.tap(find.text('Dashboard'));
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
