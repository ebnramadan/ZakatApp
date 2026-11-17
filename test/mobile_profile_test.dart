import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakat_app/core/models/user_profile.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/auth/profile_screen.dart';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('compact $language profile reflows at 320px with enlarged text',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = FakeFirebaseFirestore();
      final service = FirestoreService(database: db);
      await service.saveProfile(UserProfile(
          uid: 'u',
          displayName: 'Ahmed Ramadan',
          email: 'ahmed@example.com',
          language: language,
          shareRecipients: ['trusted@example.com']));
      await db.doc('users/u').update({
        'sheetRequest': {
          'id': 'delayed-request-123456',
          'status': 'queued',
          'requestedAt': DateTime.now()
              .subtract(const Duration(minutes: 11))
              .millisecondsSinceEpoch,
          'recipients': ['trusted@example.com']
        }
      });
      final auth = AuthProvider(
          auth: AuthService(
              auth: MockFirebaseAuth(
                  mockUser: MockUser(
                      uid: 'u',
                      email: 'ahmed@example.com',
                      isEmailVerified: true),
                  signedIn: true)),
          store: service);
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(
              theme: AppTheme.light,
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate
              ],
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.6)),
                  child: child!),
              home: const ProfileScreen())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final retry = find
          .text(language == 'ar' ? 'إعادة محاولة الإرسال' : 'Retry delivery');
      await tester.scrollUntilVisible(retry, 250);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(retry, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    });
  }
}
