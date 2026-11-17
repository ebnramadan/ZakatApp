import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'core/platform/browser_insets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'core/localization/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
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
import 'ui/shared/warm_loading_screen.dart';
import 'ui/auth/verify_email_screen.dart';
import 'ui/home/home_screen.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/auth/account_reset_card.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  try {
    const emulatorMode = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    if (emulatorMode && !kDebugMode) {
      throw StateError('Emulators are only available in a debug build.');
    }
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
    String language = 'en';
    try {
      language =
          (await SharedPreferences.getInstance()).getString('language') ?? 'en';
    } catch (_) {}
    runApp(MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        theme: AppTheme.forLanguage(language),
        home: Builder(
            builder: (context) => Scaffold(
                body: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.cloud_off_outlined, size: 48),
                          const SizedBox(height: 16),
                          Text(
                              l(context,
                                  'Zakat Tracker couldn’t connect. Check your connection and try again.'),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          TextButton(
                              onPressed: main,
                              child: Text(l(context, 'Try again'))),
                        ])))))));
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
                  key: ValueKey(
                      '${auth.user?.uid}:${auth.isVerified}:${auth.dataRevision}'),
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
                          title: auth.language == 'ar'
                              ? 'متتبع الزكاة'
                              : 'Zakat Tracker',
                          locale: Locale(auth.language),
                          supportedLocales: const [Locale('en'), Locale('ar')],
                          localizationsDelegates: const [
                            GlobalMaterialLocalizations.delegate,
                            GlobalWidgetsLocalizations.delegate,
                            GlobalCupertinoLocalizations.delegate
                          ],
                          debugShowCheckedModeBanner: false,
                          theme: AppTheme.forLanguage(auth.language),
                          builder: (context, child) {
                            Intl.defaultLocale = auth.language;
                            HijriCalendar.setLocal(auth.language);
                            final media = MediaQuery.of(context),
                                safe = browserSafeInsets();
                            final view = media.viewPadding;
                            final combined = EdgeInsets.fromLTRB(
                                math.max(view.left, safe.left),
                                math.max(view.top, safe.top),
                                math.max(view.right, safe.right),
                                math.max(view.bottom, safe.bottom));
                            return MediaQuery(
                                data: media.copyWith(
                                    viewPadding: combined,
                                    padding: EdgeInsets.fromLTRB(
                                        combined.left,
                                        combined.top,
                                        combined.right,
                                        math.max(
                                            0,
                                            combined.bottom -
                                                media.viewInsets.bottom))),
                                child: child ?? const SizedBox());
                          },
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
      if (auth.isLoading) return const WarmLoadingScreen();
      return const LoginScreen();
    }
    if (!auth.isVerified) return const VerifyEmailScreen();
    if (auth.profile == null) {
      if (auth.isLoading) return const WarmLoadingScreen();
      return Scaffold(
          body: Center(
              child: auth.isLoading
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l(context, auth.error ?? 'Profile unavailable')),
                        TextButton(
                            onPressed: auth.retryProfile,
                            child: Text(l(context, 'Retry'))),
                        TextButton(
                            onPressed: auth.signOut,
                            child: Text(l(context, 'Sign out'))),
                      ],
                    )));
    }
    if (auth.profile!.resetInProgress) {
      return Scaffold(
          appBar: AppBar(title: Text(l(context, 'Finish resetting your app'))),
          body: const SingleChildScrollView(
              padding: EdgeInsets.all(24), child: AccountResetCard()));
    }
    if (!auth.profile!.onboardingCompleted) return const OnboardingScreen();
    return const HomeScreen();
  }
}
