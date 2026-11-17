import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/localization/amount_formatter.dart';
import 'package:zakat_app/core/localization/strings.dart';

void main() {
  const formatter = GroupedAmountFormatter();
  TextEditingValue value(String text, [int? caret]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret ?? text.length));
  test('Arabic, Persian and pasted grouped amounts preserve their exact value',
      () {
    for (final input in [
      '12345.670',
      '١٢٬٣٤٥٫٦٧٠',
      '۱۲,۳۴۵.۶۷۰',
      '12,345.670'
    ]) {
      final output = formatter.formatEditUpdate(value(''), value(input));
      expect(output.text, '12,345.670');
      expect(output.selection.extentOffset, output.text.length);
      expect(parseLocalizedNumber(output.text), 12345.67);
    }
    expect(
        formatter.formatEditUpdate(value(''), value('1234.')).text, '1,234.');
    expect(formatter.formatEditUpdate(value(''), value('.5')).text, '.5');
  });
  test('insertion and backspace around a grouping comma keep a usable caret',
      () {
    final inserted =
        formatter.formatEditUpdate(value('12,345', 2), value('129,345', 3));
    expect(inserted.text, '129,345');
    expect(inserted.selection.extentOffset, 3);
    final deleted =
        formatter.formatEditUpdate(value('1,234', 2), value('1234', 1));
    expect(deleted.text, '234');
    expect(deleted.selection.extentOffset, 0);
    expect(formatter.formatEditUpdate(value('1,234'), value('')).text, '');
  });
  test(
      'invalid financial entry is rejected, while an IME composition is preserved',
      () {
    for (final text in ['-5', '1.2.3', 'abc', '1e9']) {
      expect(formatter.formatEditUpdate(value('50'), value(text)), value('50'));
    }
    final composing =
        value('١٢').copyWith(composing: const TextRange(start: 0, end: 2));
    expect(formatter.formatEditUpdate(value(''), composing), composing);
  });
}
