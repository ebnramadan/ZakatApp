import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/models/zakat_record.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/providers/tracker_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/ui/calculator/asset_form_screen.dart';

void main() {
  for (final guided in [false, true]) {
    testWidgets(
        '${guided ? 'Wizard' : 'One-pager'} preserves model prices and computes the same total',
        (tester) async {
      final store = FirestoreService(database: FakeFirebaseFirestore());
      final auth = AuthProvider(
          auth: AuthService(
              auth: MockFirebaseAuth(
                  mockUser: MockUser(uid: 'alice'), signedIn: true)),
          store: store);
      final calc = CalculatorProvider(store: store)
        ..startNewRecord('alice', 'USD');
      final tracker = TrackerProvider(store: store);
      calc.updateGoldPrice(100);
      calc.draft!.hawlStartDate = DateTime(2023);
      calc.draft!.goldEntries
          .add(GoldEntry(grams: 100, carat: 18, pricePerGram24k: 100));
      calc.draft!.cashLocal = 2500;
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: calc),
        ChangeNotifierProvider.value(value: tracker),
      ], child: MaterialApp(home: AssetFormScreen(guided: guided))));
      await tester.pumpAndSettle();
      if (guided) {
        for (var i = 0; i < 3; i++) {
          await tester.scrollUntilVisible(find.text('Next'), 400,
              scrollable: find.byType(Scrollable).first);
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
      await tester.scrollUntilVisible(find.text('Calculate Zakat'), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Calculate Zakat'));
      await tester.pumpAndSettle();
      expect(find.text('Zakat Summary'), findsOneWidget);
      expect(calc.draft!.totalWealth, 10000);
      expect(calc.draft!.nisabThreshold, 8500);
      expect(calc.draft!.zakatDue, 250);
      await tester.scrollUntilVisible(find.text('Confirm & Submit'), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Confirm & Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Zakat Tracker'), findsOneWidget);
      expect(tracker.selectedRecord!.totalWealth, 10000);
      expect(calc.draft, isNull);
      await tester.tap(find.text('Calculator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zakat ${DateTime.now().year}'));
      await tester.pumpAndSettle();
      expect(find.text('Zakat Tracker'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      calc.dispose();
      tracker.dispose();
      auth.dispose();
    });
  }
}
