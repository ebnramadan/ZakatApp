import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/models/zakat_record.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/providers/tracker_provider.dart';
import 'package:zakat_app/core/providers/monthly_provider.dart';
import 'package:zakat_app/core/services/monthly_service.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/ui/calculator/asset_form_screen.dart';

void main() {
  for (final guided in [false, true]) {
    testWidgets(
        '${guided ? 'Wizard' : 'One-pager'} preserves model prices and computes the same total',
        (tester) async {
      final database = FakeFirebaseFirestore();
      final store = FirestoreService(database: database);
      final monthly =
          MonthlyProvider(store: MonthlyService(database: database));
      final auth = AuthProvider(
          auth: AuthService(
              auth: MockFirebaseAuth(
                  mockUser: MockUser(
                      uid: 'alice',
                      email: 'alice@example.com',
                      isEmailVerified: true),
                  signedIn: true)),
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
        ChangeNotifierProvider.value(value: monthly),
      ], child: MaterialApp(home: AssetFormScreen(guided: guided))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      final price = find.descendant(
          of: find.byKey(const ValueKey('nisab-price')),
          matching: find.byType(TextFormField));
      calc.draft!.manualNisabPrice = false;
      await tester.ensureVisible(price);
      await tester.tap(price);
      await tester.enterText(price, '1');
      await tester.pump();
      await tester.enterText(price, '100');
      await tester.pump();
      expect(calc.draft!.goldPricePerGram24k, 100);
      final priceField = tester.widget<TextFormField>(price);
      expect(priceField.controller!.text, '100');
      expect(
          tester
              .widget<EditableText>(find.descendant(
                  of: price, matching: find.byType(EditableText)))
              .focusNode
              .hasFocus,
          isTrue);
      if (guided) {
        for (var i = 0; i < 3; i++) {
          await tester.scrollUntilVisible(find.text('Next'), 400,
              scrollable: find.byType(Scrollable).first);
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
      await tester.ensureVisible(find.text('21K'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('21K'));
      await tester.pumpAndSettle();
      expect(find.text('21K price: USD 87.50 / g'), findsOneWidget);
      expect(find.text('Gold value: USD 8750.00'), findsOneWidget);
      await tester.tap(find.text('18K'));
      await tester.pumpAndSettle();
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
      expect(find.text('Your Zakat plan is ready'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Zakat Tracker'), findsOneWidget);
      expect(tracker.selectedRecord!.totalWealth, 10000);
      expect(calc.draft, isNull);
      await tester.tap(find.text('Records'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open payment tracker'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open payment tracker'));
      await tester.pumpAndSettle();
      expect(find.text('Zakat Tracker'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      calc.dispose();
      tracker.dispose();
      monthly.dispose();
      auth.dispose();
    });
  }
}
