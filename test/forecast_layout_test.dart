import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:zakat_app/core/models/giving_forecast.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/dashboard/giving_forecast_card.dart';

void main() {
  testWidgets(
      'Arabic forecast expands and scrolls on a compact phone with readable text scaling',
      (tester) async {
    await initializeDateFormatting('ar');
    final old = Intl.defaultLocale;
    Intl.defaultLocale = 'ar';
    addTearDown(() {
      Intl.defaultLocale = old;
    });
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
                body: ListView(children: [
              GivingForecastCard(
                  months: List.generate(
                      12,
                      (i) => GivingForecastMonth(DateTime(2026, 11 + i),
                          {'EGP': 1500, 'USD': 10}, {'EGP': 100}))),
            ])))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('خطة عطائك لـ ١٢ شهر'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
