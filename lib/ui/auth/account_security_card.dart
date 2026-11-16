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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Sign-in method connected. Your account and records are unchanged.')));
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
                  Text('Account security',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('One account. Your choice of sign-in methods.',
                      style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('Email verified'),
                      subtitle: Text(auth.user?.email ?? ''),
                      trailing:
                          const Icon(Icons.check_circle, color: Colors.green)),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.g_mobiledata),
                      title: const Text('Google'),
                      subtitle: Text(auth.hasGoogle
                          ? 'Connected'
                          : 'Connect a Google account to sign in more easily'),
                      trailing: auth.hasGoogle
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null),
                  if (!auth.hasGoogle && auth.hasPassword)
                    OutlinedButton(
                        onPressed: auth.busy
                            ? null
                            : () => _change(context, addPassword: false),
                        child: const Text('Connect Google securely')),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.password_outlined),
                      title: const Text('Email & password'),
                      subtitle: Text(auth.hasPassword
                          ? 'Connected'
                          : 'Add a password for your verified email'),
                      trailing: auth.hasPassword
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null),
                  if (!auth.hasPassword && auth.hasGoogle)
                    OutlinedButton(
                        onPressed: auth.busy
                            ? null
                            : () => _change(context, addPassword: true),
                        child: const Text('Add a password')),
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
                                        ? 'Password reset link sent to your verified email.'
                                        : auth.error!)));
                              },
                        child: const Text('Send password reset link')),
                  const SizedBox(height: 8),
                  const Text(
                      'Connecting a sign-in method requires proof that you own both identities. Separate existing accounts are never combined automatically.',
                      style: TextStyle(
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
            ? 'Add an email password'
            : _confirmed
                ? 'Choose your Google account'
                : 'Confirm your identity'),
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
                              ? 'Create a password for ${auth.user?.email}. You’ll then confirm your existing Google identity in a secure popup.'
                              : _confirmed
                                  ? 'Password confirmed. Now choose the Google identity you own. Both sign-in methods will open your existing records.'
                                  : 'Enter your current password before connecting a Google identity. Your financial data stays in this same account.'),
                          if (!_confirmed) ...[
                            const SizedBox(height: 18),
                            TextFormField(
                                controller: _password,
                                obscureText: true,
                                decoration: InputDecoration(
                                    labelText: widget.addPassword
                                        ? 'New password'
                                        : 'Current password'),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Enter your password'
                                    : widget.addPassword && v.length < 10
                                        ? 'Use at least 10 characters'
                                        : null),
                            if (widget.addPassword) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: _confirm,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Confirm new password'),
                                  validator: (v) => v == _password.text
                                      ? null
                                      : 'Passwords do not match')
                            ],
                          ],
                          if (auth.error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(auth.error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                        ])))),
        actions: [
          TextButton(
              onPressed: auth.busy ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: auth.busy ? null : _submit,
              child: Text(auth.busy
                  ? 'Confirming…'
                  : _confirmed
                      ? 'Continue with Google'
                      : widget.addPassword
                          ? 'Confirm with Google'
                          : 'Confirm password'))
        ]);
  }
}
