import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/calculator_provider.dart';
import 'core/providers/tracker_provider.dart';
import 'core/providers/monthly_provider.dart';
import 'ui/auth/login_screen.dart';
import 'ui/auth/verify_email_screen.dart';
import 'ui/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const emulatorMode = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    if (emulatorMode && !kDebugMode)
      throw StateError('Emulators are only available in a debug build.');
    final options = emulatorMode
        ? const FirebaseOptions(
            apiKey: 'demo-key',
            appId: '1:123:web:demo',
            messagingSenderId: '123',
            projectId: 'demo-zakat-app',
            authDomain: 'localhost')
        : DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey == 'REPLACE_ME') {
      throw StateError('Firebase is not configured');
    }
    await Firebase.initializeApp(options: options);
    if (emulatorMode) {
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    }
    runApp(const ZakatApp());
  } catch (_) {
    runApp(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
            body: Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Zakat could not start. Configure Firebase for this platform and check your connection, then restart the app.',
                  textAlign: TextAlign.center)),
        ))));
  }
}

class ZakatApp extends StatelessWidget {
  const ZakatApp({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: Consumer<AuthProvider>(
            builder: (context, auth, _) => KeyedSubtree(
                  // Disposes all account data and navigation when the Firebase UID changes.
                  key: ValueKey('${auth.user?.uid}:${auth.isVerified}'),
                  child: MultiProvider(
                      providers: [
                        ChangeNotifierProvider(
                            create: (_) => CalculatorProvider()),
                        ChangeNotifierProvider(
                            create: (_) => TrackerProvider()),
                        ChangeNotifierProvider(
                            create: (_) => MonthlyProvider()),
                      ],
                      child: MaterialApp(
                          title: 'Zakat Tracker',
                          debugShowCheckedModeBanner: false,
                          theme: AppTheme.light,
                          builder: (context, child) => ColoredBox(
                              color: const Color(0xFFEDEFE9),
                              child: Center(
                                  child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 1080),
                                      child: child ?? const SizedBox()))),
                          home: const _AuthGate())),
                )),
      );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user == null) {
      if (auth.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const LoginScreen();
    }
    if (!auth.isVerified) return const VerifyEmailScreen();
    if (auth.profile == null) {
      return Scaffold(
          body: Center(
              child: auth.isLoading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(auth.error ?? 'Profile unavailable'),
                        TextButton(
                            onPressed: auth.retryProfile,
                            child: const Text('Retry')),
                        TextButton(
                            onPressed: auth.signOut,
                            child: const Text('Sign out')),
                      ],
                    )));
    }
    return const HomeScreen();
  }
}
