import 'package:flutter/material.dart';
import '../../core/localization/strings.dart';
import '../../core/services/location_currency.dart';

class LocationCurrencyButton extends StatefulWidget {
  final ValueChanged<String> onSelected;
  final LocationCurrency? service;
  const LocationCurrencyButton(
      {super.key, required this.onSelected, this.service});
  @override
  State<LocationCurrencyButton> createState() => _LocationCurrencyButtonState();
}

class _LocationCurrencyButtonState extends State<LocationCurrencyButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
          icon: Icon(busy ? Icons.hourglass_empty : Icons.my_location),
          label: Text(
              l(context, busy ? 'Finding your currency…' : 'Use my location')),
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    final currency =
                        await (widget.service ?? LocationCurrency()).suggest();
                    if (mounted) widget.onSelected(currency);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(l(context,
                              'Location was not available. Your currency has not changed; you can choose it manually.'))));
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                }));
}
