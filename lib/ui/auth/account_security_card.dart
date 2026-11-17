import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';

class AccountSecurityCard extends StatelessWidget {
  const AccountSecurityCard({super.key});
  Future<void> _change(BuildContext context,
      {required bool addPassword}) async {
    final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SecurityDialog(addPassword: addPassword));
    if (!context.mounted || ok != true) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l(context,
            "Sign-in method connected. Your account and records are unchanged."))));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l(context, "Account security"),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                      l(context,
                          "One account. Your choice of sign-in methods."),
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(l(context, "Email verified")),
                      subtitle: Text(l(context, auth.user?.email ?? '')),
                      trailing:
                          const Icon(Icons.check_circle, color: Colors.green)),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.g_mobiledata),
                      title: Text(l(context, "Google")),
                      subtitle: Text(auth.hasGoogle
                          ? l(context, "Connected")
                          : l(context,
                              "Connect a Google account to sign in more easily")),
                      trailing: auth.hasGoogle
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null),
                  if (!auth.hasGoogle && auth.hasPassword)
                    OutlinedButton(
                        onPressed: auth.busy
                            ? null
                            : () => _change(context, addPassword: false),
                        child: Text(l(context, "Connect Google securely"))),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.password_outlined),
                      title: Text(l(context, "Email & password")),
                      subtitle: Text(auth.hasPassword
                          ? l(context, "Connected")
                          : l(context,
                              "Add a password for your verified email")),
                      trailing: auth.hasPassword
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null),
                  if (!auth.hasPassword && auth.hasGoogle)
                    OutlinedButton(
                        onPressed: auth.busy
                            ? null
                            : () => _change(context, addPassword: true),
                        child: Text(l(context, "Add a password"))),
                  if (auth.hasPassword)
                    TextButton(
                        onPressed: auth.busy
                            ? null
                            : () async {
                                final sent = await auth
                                    .sendPasswordReset(auth.user!.email!);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(sent
                                        ? l(context,
                                            "Password reset link sent to your verified email.")
                                        : l(context, auth.error!))));
                              },
                        child: Text(l(context, "Send password reset link"))),
                  const SizedBox(height: 8),
                  Text(
                      l(context,
                          "Connecting a sign-in method requires proof that you own both identities. Separate existing accounts are never combined automatically."),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54, height: 1.5)),
                ])));
  }
}

class _SecurityDialog extends StatefulWidget {
  final bool addPassword;
  const _SecurityDialog({required this.addPassword});
  @override
  State<_SecurityDialog> createState() => _SecurityDialogState();
}

class _SecurityDialogState extends State<_SecurityDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _confirmed = false;
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.busy) return;
    if (!_confirmed && !_form.currentState!.validate()) return;
    if (widget.addPassword) {
      // This starts the Google popup directly from the user's button gesture.
      final ok = await auth.addPassword(_password.text);
      if (mounted && ok) Navigator.pop(context, true);
    } else if (!_confirmed) {
      final ok = await auth.confirmPassword(_password.text);
      if (mounted && ok) setState(() => _confirmed = true);
    } else {
      // The second gesture avoids Safari blocking a popup after password validation.
      final ok = await auth.connectGoogle();
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else if (!auth.hasRecentPasswordProof) {
        setState(() => _confirmed = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AlertDialog(
        title: Text(widget.addPassword
            ? l(context, "Add an email password")
            : _confirmed
                ? l(context, "Choose your Google account")
                : l(context, "Confirm your identity")),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(widget.addPassword
                              ? l(
                                  context,
                                  "Create a password for {0}. You’ll then confirm your existing Google identity in a secure popup.",
                                  [
                                      auth.user?.email
                                    ])
                              : _confirmed
                                  ? l(context,
                                      "Password confirmed. Now choose the Google identity you own. Both sign-in methods will open your existing records.")
                                  : l(context,
                                      "Enter your current password before connecting a Google identity. Your financial data stays in this same account.")),
                          if (!_confirmed) ...[
                            const SizedBox(height: 18),
                            TextFormField(
                                controller: _password,
                                obscureText: true,
                                decoration: InputDecoration(
                                    labelText: widget.addPassword
                                        ? l(context, "New password")
                                        : l(context, "Current password")),
                                validator: (v) => v == null || v.isEmpty
                                    ? l(context, "Enter your password")
                                    : widget.addPassword && v.length < 10
                                        ? l(context,
                                            "Use at least 10 characters")
                                        : null),
                            if (widget.addPassword) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: _confirm,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                      labelText:
                                          l(context, "Confirm new password")),
                                  validator: (v) => v == _password.text
                                      ? null
                                      : l(context, "Passwords do not match"))
                            ],
                          ],
                          if (auth.error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(l(context, auth.error!),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                        ])))),
        actions: [
          TextButton(
              onPressed: auth.busy ? null : () => Navigator.pop(context, false),
              child: Text(l(context, "Cancel"))),
          TextButton(
              onPressed: auth.busy ? null : _submit,
              child: Text(auth.busy
                  ? l(context, "Confirming…")
                  : _confirmed
                      ? l(context, "Continue with Google")
                      : widget.addPassword
                          ? l(context, "Confirm with Google")
                          : l(context, "Confirm password")))
        ]);
  }
}
