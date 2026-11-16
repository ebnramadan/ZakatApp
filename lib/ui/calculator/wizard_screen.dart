import 'package:flutter/material.dart';
import 'asset_form_screen.dart';

class WizardScreen extends StatelessWidget {
  const WizardScreen({super.key});
  @override
  Widget build(BuildContext context) => const AssetFormScreen(guided: true);
}
