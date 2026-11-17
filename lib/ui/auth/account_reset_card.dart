import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';

class AccountResetCard extends StatelessWidget {
  const AccountResetCard({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.canResetAccount) return const SizedBox.shrink();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  auth.profile?.resetInProgress == true
                      ? l(context, "Finish interrupted reset")
                      : l(context, "Testing: reset your app"),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB3261E))),
              const SizedBox(height: 8),
              Text(l(context,
                  "Only available for ebnramadan@gmail.com. This permanently clears all app data and restarts onboarding. Your Google/email sign-in account is kept.")),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                  onPressed: auth.busy
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const _ResetDialog()),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l(context, "Reset app data"))),
            ])));
  }
}

class _ResetDialog extends StatefulWidget {
  const _ResetDialog();
  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  final confirm = TextEditingController(), password = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    confirm.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AlertDialog(
        title: Text(l(context, "Permanently reset your app?")),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l(context,
              "All records (including the recycle bin), payments, monthly recipients, settings and delivery history will be deleted. Sharing will stop. This cannot be undone. Previously emailed sheets cannot be recalled.")),
          const SizedBox(height: 16),
          TextField(
              controller: confirm,
              enabled: !busy,
              decoration: InputDecoration(
                  labelText: l(context, "Type RESET to confirm")),
              onChanged: (_) => setState(() {})),
          if (auth.hasPassword) ...[
            const SizedBox(height: 12),
            TextField(
                controller: password,
                enabled: !busy,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: l(context, "Current password")))
          ],
          if (auth.error != null)
            Text(l(context, auth.error!),
                style: const TextStyle(color: Colors.red)),
        ])),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: Text(l(context, "Cancel"))),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB3261E)),
              onPressed: busy || confirm.text != 'RESET'
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final ok =
                          await auth.resetAppData(password: password.text);
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.pop(context);
                      } else {
                        setState(() => busy = false);
                      }
                    },
              child: Text(busy
                  ? l(context, "Resetting…")
                  : auth.hasPassword
                      ? l(context, "Reset permanently")
                      : l(context, "Confirm with Google & reset")))
        ]);
  }
}
