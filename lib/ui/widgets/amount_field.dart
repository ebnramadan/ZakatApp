import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import '../../core/localization/amount_formatter.dart';
import '../../core/constants.dart';

class AmountField extends StatelessWidget {
  final String label;
  final String currency;
  final TextEditingController controller;
  final String? hint;
  final void Function(String)? onChanged;
  final bool readOnly;

  const AmountField({
    super.key,
    required this.label,
    required this.currency,
    required this.controller,
    this.hint,
    this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l(context, label),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          textDirection: TextDirection.ltr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [GroupedAmountFormatter()],
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: l(context, hint ?? '0.00'),
            prefixText: '${currencySymbol(currency)} ',
            prefixStyle: const TextStyle(
                color: kPrimaryGreen, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
