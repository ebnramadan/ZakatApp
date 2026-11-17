import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/constants.dart';
import 'package:zakat_app/ui/widgets/searchable_picker.dart';

void main() {
  testWidgets(
      'currency options can be found by country name and EGP uses its ISO code',
      (tester) async {
    String value = 'USD';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, set) => SearchablePicker<String>(
                    label: 'Currency',
                    value: value,
                    options: currencyOptions,
                    onChanged: (v) => set(() => value = v))))));
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Egyptian');
    await tester.pumpAndSettle();
    expect(find.text('EGP'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('USD')),
        findsNothing);
    await tester.tap(find.text('EGP'));
    await tester.pumpAndSettle();
    expect(value, 'EGP');
    expect(currencySymbol('EGP'), 'EGP');
  });
}
