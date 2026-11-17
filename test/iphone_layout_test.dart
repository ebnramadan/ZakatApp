import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/models/user_profile.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/providers/monthly_provider.dart';
import 'package:zakat_app/core/providers/tracker_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/services/monthly_service.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/home/home_screen.dart';
import 'package:zakat_app/ui/home/recycle_bin_screen.dart';
import 'dashboard_recycle_test.dart' as fixtures;

void main() {
  testWidgets(
      'iPhone safe area protects tabs and keyboard keeps delete actions reachable',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(393, 852));
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(() async {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.view.resetViewInsets();
      await tester.binding.setSurfaceSize(null);
    });
    final db = FakeFirebaseFirestore();
    final service = FirestoreService(database: db),
        record = fixtures.record('r');
    await service.saveProfile(UserProfile(
        uid: 'u',
        displayName: 'Ahmed',
        email: 'u@example.com',
        defaultRecordId: 'r',
        onboardingCompleted: true));
    await service.saveRecord(record);
    final auth = AuthProvider(
        auth: AuthService(
            auth: MockFirebaseAuth(
                mockUser: MockUser(
                    uid: 'u', email: 'u@example.com', isEmailVerified: true),
                signedIn: true)),
        store: service);
    final calc = CalculatorProvider(store: service),
        tracker = TrackerProvider(store: service),
        monthly = MonthlyProvider(store: MonthlyService(database: db));
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: calc),
      ChangeNotifierProvider.value(value: tracker),
      ChangeNotifierProvider.value(value: monthly)
    ], child: MaterialApp(theme: AppTheme.light, home: const HomeScreen())));
    await tester.pumpAndSettle();
    final tabLabel = find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Profile'));
    expect(tester.getRect(tabLabel).bottom, lessThanOrEqualTo(852 - 34));
    await tester.tap(find.text('View all records'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TextField), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(TextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    unawaited(
        moveToRecycleBin(tester.element(find.byType(TextField).first), record));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        findsNothing);
    final confirm = find.widgetWithText(FilledButton, 'Move to recycle bin');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(852 - 336));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Keep record'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    calc.dispose();
    tracker.dispose();
    monthly.dispose();
  });
}
