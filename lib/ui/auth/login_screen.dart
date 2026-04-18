import 'dart:io';
import 'package:flutter/foundation.dart';
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
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isRegister = false;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _doEmailAuth(AuthProvider auth) async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() => _busy = true);
    if (_isRegister) {
      await auth.registerWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
    } else {
      await auth.signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 60),
              _Logo(),
              const SizedBox(height: 40),
              if (auth.error != null) _ErrorBanner(auth.error!, onClose: auth.clearError),
              const SizedBox(height: 8),
              _EmailForm(
                emailCtrl: _emailCtrl,
                passwordCtrl: _passwordCtrl,
                obscure: _obscure,
                isRegister: _isRegister,
                busy: _busy,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                onToggleMode: () => setState(() => _isRegister = !_isRegister),
                onSubmit: () => _doEmailAuth(auth),
                onForgot: () async {
                  if (_emailCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter your email first')));
                    return;
                  }
                  await auth.sendPasswordReset(_emailCtrl.text.trim());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset email sent')));
                  }
                },
              ),
              const SizedBox(height: 20),
              _Divider(),
              const SizedBox(height: 20),
              _SocialButton(
                icon: Icons.g_mobiledata,
                label: 'Continue with Google',
                onTap: auth.isLoading ? null : auth.signInWithGoogle,
              ),
              if (!kIsWeb && Platform.isIOS) ...[
                const SizedBox(height: 12),
                _SocialButton(
                  icon: Icons.apple,
                  label: 'Continue with Apple',
                  onTap: auth.isLoading ? null : auth.signInWithApple,
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: kPrimaryGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.mosque, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 16),
        const Text('Zakat',
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: kPrimaryGreen)),
        const Text('Your personal Zakat companion',
            style: TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorBanner(this.message, {required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red, fontSize: 13))),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _EmailForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final bool isRegister;
  final bool busy;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;
  final VoidCallback onForgot;

  const _EmailForm({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.isRegister,
    required this.busy,
    required this.onToggleObscure,
    required this.onToggleMode,
    required this.onSubmit,
    required this.onForgot,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordCtrl,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggleObscure,
            ),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        if (!isRegister)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgot,
              child: const Text('Forgot password?'),
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: busy ? null : onSubmit,
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isRegister ? 'Create Account' : 'Sign In'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onToggleMode,
          child: Text(isRegister
              ? 'Already have an account? Sign in'
              : 'New here? Create an account'),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SocialButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      label: Text(label),
    );
  }
}
