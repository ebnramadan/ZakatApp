import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zakat_app/core/localization/strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/tracker_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/tracker/add_payment_sheet.dart';
import 'dashboard_recycle_test.dart' as fixtures;

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
        'payment name hint and grouped entry save correctly above the phone keyboard in $language',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() async {
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        await tester.binding.setSurfaceSize(null);
      });
      final db = FakeFirebaseFirestore();
      final store = FirestoreService(database: db),
          record = fixtures.record('r');
      await store.saveRecord(record);
      final auth = AuthProvider(
          auth: AuthService(
              auth: MockFirebaseAuth(
                  mockUser: MockUser(
                      uid: 'u', email: 'u@example.com', isEmailVerified: true),
                  signedIn: true)),
          store: store);
      final tracker = TrackerProvider(store: store)..selectRecord('u', record);
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: tracker)
          ],
          child: MaterialApp(
              theme: AppTheme.light,
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate
              ],
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => const AddPaymentSheet()),
                          child: const Text('Open payment')))))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open payment'));
      await tester.pumpAndSettle();
      final sheetContext = tester.element(find.byType(AddPaymentSheet));
      final amountField = find.byType(TextFormField).first;
      final nameField = find.byWidgetPredicate((w) =>
          w is TextField &&
          w.decoration?.labelText ==
              l(sheetContext, 'Payment name (optional)'));
      final nameInput = tester.widget<TextField>(nameField);
      expect(nameInput.controller!.text, isEmpty);
      expect(
          nameInput.decoration!.hintText, l(sheetContext, 'Payment {0}', [1]));
      await tester.enterText(
          nameField, language == 'ar' ? 'مساعدة أسرة' : 'Family support');
      expect(nameInput.controller!.text,
          language == 'ar' ? 'مساعدة أسرة' : 'Family support');
      if (language == 'ar') await tester.enterText(nameField, '');
      await tester.enterText(
          amountField, language == 'ar' ? '١٢٣٤٥٫٦٧' : '12345.67');
      final amountInput = tester.widget<TextField>(
          find.descendant(of: amountField, matching: find.byType(TextField)));
      expect(amountInput.controller!.text, '12,345.67');
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pumpAndSettle();
      final pay =
          find.widgetWithText(ElevatedButton, l(sheetContext, 'Add Payment'));
      await tester.scrollUntilVisible(pay, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.getRect(pay).bottom, lessThanOrEqualTo(852 - 336));
      expect(tester.takeException(), isNull);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(find.text(l(sheetContext, 'Your Zakat giving is recorded')),
          findsOneWidget);
      final close =
          find.widgetWithText(FilledButton, l(sheetContext, 'Continue'));
      expect(tester.getRect(close).bottom, lessThanOrEqualTo(852 - 336));
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(AddPaymentSheet), findsNothing);
      expect(
          (await db.collection('users/u/payments').get())
              .docs
              .single
              .data()['amount'],
          12345.67);
      final savedName = (await db.collection('users/u/payments').get())
          .docs
          .single
          .data()['name'];
      expect(savedName, language == 'ar' ? 'دفعة 1' : 'Family support');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      tracker.dispose();
    });
  }
}
