import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

String money(double value, String? currency) => currency == null
    ? NumberFormat('#,##0.00').format(value)
    : NumberFormat.currency(
            name: currency,
            symbol: '$currency ',
            decimalDigits: currencyDecimals(currency))
        .format(value);

class PageIntro extends StatelessWidget {
  final String eyebrow, title, description;
  final Widget? action;
  const PageIntro(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.description,
      this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: kPrimaryGreen)),
          const SizedBox(height: 8),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.7)),
          const SizedBox(height: 8),
          Text(description,
              style: const TextStyle(color: Color(0xFF52655F), height: 1.5)),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!
        ]),
      );
}

class StatusPill extends StatelessWidget {
  final String label;
  final bool warning;
  const StatusPill(this.label, {super.key, this.warning = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: warning ? const Color(0xFFFFF3D8) : const Color(0xFFE8F2ED),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                color: warning ? const Color(0xFF805600) : kPrimaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const ActionCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
          child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFE8F2ED),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: kPrimaryGreen)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF52655F))),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ));
}
