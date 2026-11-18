import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/services/price_service.dart';
import 'package:zakat_app/ui/calculator/one_pager_screen.dart';

void main() {
  for (final changed in [false, true]) {
    testWidgets(
        'leaving calculation prompts only for changed user input ($changed)',
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
      final calc = CalculatorProvider(
          store: store,
          prices: PriceService.forTesting(MockClient((_) async => http.Response(
              '{"symbol":"XAU","currency":"USD","price":3110.35,"updatedAt":"${DateTime.now().toUtc().toIso8601String()}"}',
              200))))
        ..startNewRecord('u', 'USD');
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: calc),
          ],
          child: MaterialApp(
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const OnePagerScreen())),
                          child: const Text('Open')))))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(calc.draft!.goldPricePerGram24k, greaterThan(0));
      if (changed) calc.draft!.cashLocal = 100;
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Leave calculation?'),
          changed ? findsOneWidget : findsNothing);
      if (!changed) {
        expect(find.text('Open'), findsOneWidget);
        expect(
            (await db.collection('users/u/zakatRecords').get()).docs, isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      calc.dispose();
    });
  }
}
