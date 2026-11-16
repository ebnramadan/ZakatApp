import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

class NisabChip extends StatelessWidget {
  final double nisabValue;
  final String currency;
  final bool isLoading;

  const NisabChip({
    super.key,
    required this.nisabValue,
    required this.currency,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
        symbol: currencySymbol(currency), decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.balance, size: 14, color: kGold),
          const SizedBox(width: 6),
          Text(
            'Nisab: ',
            style: TextStyle(
                fontSize: 12,
                color: Colors.brown.shade700,
                fontWeight: FontWeight.w500),
          ),
          if (isLoading)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
            )
          else
            Text(
              fmt.format(nisabValue),
              style: const TextStyle(
                  fontSize: 12,
                  color: kPrimaryGreen,
                  fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
