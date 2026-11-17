import 'dart:convert';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakat_app/core/localization/arabic.dart';
import 'package:zakat_app/core/localization/strings.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/ui/onboarding/onboarding_screen.dart';

void main() {
  test('Arabic and Persian numeric inputs preserve financial amounts', () {
    expect(parseLocalizedNumber('١٢٬٣٤٥٫٦٧'), 12345.67);
    expect(parseLocalizedNumber('۱۲۳٫۵'), 123.5);
    expect(parseLocalizedNumber('100.25'), 100.25);
    expect(parseLocalizedNumber('abc'), isNull);
  });
  test(
      'Arabic catalog preserves placeholders and has no missing UI message keys',
      () {
    final source = Map<String, dynamic>.from(
        jsonDecode(File('assets/translations/ar.json').readAsStringSync()));
    expect(source, arabic);
    final placeholder = RegExp(r'\{\d+\}');
    for (final e in arabic.entries) {
      expect(placeholder.allMatches(e.key).map((m) => m[0]).toSet(),
          placeholder.allMatches(e.value).map((m) => m[0]).toSet(),
          reason: e.key);
      expect(e.value.trim(), isNotEmpty);
    }
    final literal = RegExp(
        r'''l\(\s*(?:state\.)?context,\s*("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')''');
    for (final f in Directory('lib/ui')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in literal.allMatches(f.readAsStringSync())) {
        final raw = m[1]!;
        String key;
        if (raw.startsWith('"')) {
          key = jsonDecode(raw.replaceAll(r'\$', r'$')) as String;
        } else {
          key = raw.substring(1, raw.length - 1);
        }
        if (key.contains(r'$')) continue;
        expect(arabic.containsKey(key), isTrue, reason: '${f.path}: $key');
      }
    }
  });
  testWidgets(
      'onboarding language switches all interface copy and direction immediately',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(
        auth: AuthService(
            auth: MockFirebaseAuth(
                mockUser: MockUser(
                    uid: 'u', email: 'u@example.com', isEmailVerified: true),
                signedIn: true)),
        store: FirestoreService(database: FakeFirebaseFirestore()));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth,
        child: Consumer<AuthProvider>(
            builder: (context, value, _) => MaterialApp(
                locale: Locale(value.language),
                supportedLocales: const [Locale('en'), Locale('ar')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate
                ],
                home: value.profile == null
                    ? const SizedBox()
                    : const OnboardingScreen()))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continue'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text('ظبّطه على راحتك.'), findsOneWidget);
    expect(find.text('عملتك'), findsOneWidget);
    expect(find.text('Your currency'), findsNothing);
    expect(Directionality.of(tester.element(find.byType(OnboardingScreen))),
        TextDirection.rtl);
    expect(auth.profile!.language, 'ar');
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Make it feel like yours.'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(OnboardingScreen))),
        TextDirection.ltr);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zakat · Part of Zakat'));
    await tester.scrollUntilVisible(find.text('Start tracking'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();
    expect(auth.profile!.monthlyDefaultKind, 'zakat');
    expect(auth.profile!.onboardingCompleted, isTrue);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
  testWidgets(
      'translated template keeps person names and currency codes unchanged',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        home: Builder(
            builder: (context) =>
                Text(l(context, 'Give {0} to {1}', ['EGP 500', 'Sarah'])))));
    await tester.pumpAndSettle();
    expect(find.text('ادفع EGP 500 لـ Sarah'), findsOneWidget);
  });
}
