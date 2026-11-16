import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _emailMode = false;
  bool _register = true;
  bool _obscure = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (_register) {
      await auth.registerWithEmail(_email.text.trim(), _password.text);
    } else {
      await auth.signInWithEmail(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AutofillGroup(
              child: Form(
            key: _form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset('assets/brand/icon.png',
                              width: 80, height: 80))),
                  const SizedBox(height: 24),
                  Text('Zakat Tracker',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: kPrimaryGreen)),
                  const SizedBox(height: 10),
                  const Text(
                      'Your Zakat, monthly giving, and payment history—together in one private account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 1.6)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                      key: const Key('google-sign-in'),
                      onPressed: auth.busy ? null : auth.signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 30),
                      label: const Text('Continue with Google')),
                  const SizedBox(height: 8),
                  const Text(
                      'Sign in or create an account. No extra password needed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, height: 1.5)),
                  if (auth.error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(auth.error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                            textAlign: TextAlign.center)),
                  const SizedBox(height: 20),
                  if (!_emailMode)
                    OutlinedButton(
                        onPressed: auth.busy
                            ? null
                            : () => setState(() => _emailMode = true),
                        child: const Text('Use email instead')),
                  if (_emailMode) ...[
                    const Divider(height: 32),
                    Text(
                        _register
                            ? 'Create an account with email'
                            : 'Sign in with email',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                        _register
                            ? 'We’ll send a verification link before you can access financial records.'
                            : 'Use the password for your existing account.',
                        style: const TextStyle(
                            color: Colors.black54, height: 1.5)),
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: _email,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.alternate_email)),
                        validator: (v) => v != null &&
                                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(v.trim())
                            ? null
                            : 'Enter a valid email address'),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: _password,
                        textInputAction: _register
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: _register ? null : (_) => _submit(),
                        obscureText: _obscure,
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password
                        ],
                        decoration: InputDecoration(
                            labelText: 'Password',
                            helperText: _register
                                ? 'At least 10 characters. A passphrase works well.'
                                : null,
                            suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined))),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Enter your password'
                            : _register && v.length < 10
                                ? 'Use at least 10 characters'
                                : null),
                    if (_register) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                          controller: _confirm,
                          onFieldSubmitted: (_) => _submit(),
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'Confirm password'),
                          validator: (v) => v == _password.text
                              ? null
                              : 'Passwords do not match'),
                    ],
                    if (!_register)
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              onPressed: auth.busy
                                  ? null
                                  : () async {
                                      if (_email.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Enter your email address first.')));
                                        return;
                                      }
                                      final sent = await auth.sendPasswordReset(
                                          _email.text.trim());
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(sent
                                                  ? 'If that account exists, a reset link is on its way. Check your inbox and spam folder.'
                                                  : auth.error!)));
                                    },
                              child: const Text('Forgot password?'))),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: auth.busy ? null : _submit,
                        child: Text(auth.busy
                            ? 'Please wait…'
                            : _register
                                ? 'Create account & verify email'
                                : 'Sign in')),
                    TextButton(
                        onPressed: auth.busy
                            ? null
                            : () {
                                auth.clearError();
                                setState(() => _register = !_register);
                              },
                        child: Text(_register
                            ? 'Already have an email account? Sign in'
                            : 'New to Zakat? Create an email account')),
                  ],
                  const SizedBox(height: 28),
                  const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 15, color: Colors.black54),
                        SizedBox(width: 6),
                        Flexible(
                            child: Text(
                                'Your financial records stay in your account.',
                                style: TextStyle(
                                    color: Colors.black54, fontSize: 12)))
                      ]),
                  const SizedBox(height: 24),
                ]),
          ))),
    ))));
  }
}
