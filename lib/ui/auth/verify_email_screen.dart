import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  String? _notice;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        !context.read<AuthProvider>().busy) {
      context.read<AuthProvider>().checkVerification();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
        appBar: AppBar(title: Text(l(context, "Verify your email"))),
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(Icons.mark_email_unread_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 24),
                          Text(l(context, "Check your inbox"),
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 16),
                          Text(
                              l(
                                  context,
                                  "Open the verification link sent to {0}. Then return here to continue.",
                                  [
                                    auth.user?.email ?? 'your email address'
                                  ]),
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontSize: 16, height: 1.6)),
                          const SizedBox(height: 12),
                          Text(
                              l(context,
                                  "Check spam or junk too. Your financial records remain protected until your address is verified."),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.black54, height: 1.5)),
                          if (auth.error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(l(context, auth.error!),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          if (_notice != null)
                            Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(l(context, _notice!))),
                          const SizedBox(height: 24),
                          ElevatedButton(
                              onPressed:
                                  auth.busy ? null : auth.checkVerification,
                              child: Text(auth.busy
                                  ? l(context, "Checking…")
                                  : l(context, "I’ve verified my email"))),
                          TextButton(
                              onPressed: auth.busy
                                  ? null
                                  : () async {
                                      final sent =
                                          await auth.sendVerification();
                                      if (mounted && sent) {
                                        setState(() => _notice =
                                            'Verification email sent. Please check your inbox.');
                                      }
                                    },
                              child: Text(
                                  l(context, "Resend verification email"))),
                          TextButton(
                              onPressed: auth.busy ? null : auth.signOut,
                              child:
                                  Text(l(context, "Use a different account"))),
                        ])))));
  }
}
