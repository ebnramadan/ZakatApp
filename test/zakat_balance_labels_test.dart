import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/shared/zakat_balance_summary.dart';
import 'dashboard_recycle_test.dart' as fixtures;

void main() {
  for (final language in ['en', 'ar']) {
    for (final beforeDate in [true, false]) {
      testWidgets(
          'same clear balance labels in $language before Zakat date: $beforeDate',
          (tester) async {
        final record = fixtures.record('r', currency: 'EGP');
        record.hawlStartDate = beforeDate ? DateTime.now() : DateTime(2023);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.forLanguage(language),
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            home: Scaffold(
                body: SingleChildScrollView(
                    child: ZakatBalanceSummary(record: record, paid: 100)))));
        for (final text in language == 'ar'
            ? [
                'إجمالي الزكاة',
                'المدفوع',
                'الباقي عليك',
                'الباقي عليك = إجمالي الزكاة − المدفوع'
              ]
            : [
                'Total Zakat',
                'Paid',
                'Still To Pay',
                'Still To Pay = Total Zakat − Paid'
              ]) {
          expect(find.text(text), findsOneWidget);
        }
        expect(find.textContaining('estimate'), findsNothing);
        expect(find.text('EGP 250.00'), findsOneWidget);
        expect(find.text('EGP 100.00'), findsOneWidget);
        expect(find.text('EGP 150.00'), findsOneWidget);
        final context = tester.element(find.byType(ZakatBalanceSummary));
        expect(Directionality.of(context),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
