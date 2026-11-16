import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';

class AccountSecurityCard extends StatelessWidget {
  const AccountSecurityCard({super.key});
  Future<void> _change(BuildContext context,
      {required bool addPassword}) async {
    final auth = context.read<AuthProvider>();
    final password = TextEditingController();
    final confirm = TextEditingController();
    final form = GlobalKey<FormState>();
    final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(addPassword
                  ? 'Add an email password'
                  : 'Connect your Google account'),
              content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                      key: form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(addPassword
                            ? 'You’ll confirm your Google account in a secure popup. The password will sign in to ${auth.user?.email}. Your records stay in this same account.'
                            : 'Confirm your current password, then choose the Google account to connect. Both sign-in methods will open these same records.'),
                        const SizedBox(height: 20),
                        TextFormField(
                            controller: password,
                            obscureText: true,
                            decoration: InputDecoration(
                                labelText: addPassword
                                    ? 'New password'
                                    : 'Current password'),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Enter your password'
                                : addPassword && v.length < 10
                                    ? 'Use at least 10 characters'
                                    : null),
                        if (addPassword) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: confirm,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'Confirm new password'),
                              validator: (v) => v == password.text
                                  ? null
                                  : 'Passwords do not match')
                        ],
                      ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(ctx, true);
                      }
                    },
                    child: const Text('Continue securely'))
              ],
            ));
    final value = password.text;
    // Dialog route disposal is asynchronous; dispose after its animation.
    Future<void>.delayed(const Duration(seconds: 1), () {
      password.dispose();
      confirm.dispose();
    });
    if (approved != true || !context.mounted) return;
    final ok = addPassword
        ? await auth.addPassword(value)
        : await auth.linkGoogle(value);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Sign-in method connected. Your account and records are unchanged.'
            : auth.error ?? 'Could not connect this sign-in method.')));
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
