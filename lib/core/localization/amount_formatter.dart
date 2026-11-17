import 'package:flutter/services.dart';
import 'strings.dart';

/// Groups amounts without rounding decimals or moving the caret to the end.
class GroupedAmountFormatter extends TextInputFormatter {
  const GroupedAmountFormatter();
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    var raw = normalizeNumber(newValue.text);
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(raw)) return oldValue;
    var caret = normalizeNumber(newValue.text.substring(
            0, newValue.selection.extentOffset.clamp(0, newValue.text.length)))
        .length;
    // Backspace over a separator removes the adjacent digit, rather than trapping the caret.
    if (oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        oldValue.text.length == newValue.text.length + 1 &&
        normalizeNumber(oldValue.text) == raw &&
        oldValue.selection.extentOffset > 0 &&
        oldValue.text[oldValue.selection.extentOffset - 1] == ',' &&
        caret > 0) {
      raw = raw.replaceRange(caret - 1, caret, '');
      caret--;
    }
    final parts = raw.split('.');
    final integer = parts.first
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    final formatted = integer + (parts.length > 1 ? '.${parts[1]}' : '');
    var offset = 0, seen = 0;
    while (offset < formatted.length && seen < caret) {
      if (formatted[offset] != ',') seen++;
      offset++;
    }
    return TextEditingValue(
        text: formatted, selection: TextSelection.collapsed(offset: offset));
  }
}
