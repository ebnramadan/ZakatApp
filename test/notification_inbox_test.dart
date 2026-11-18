import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zakat_app/ui/notifications/notification_history_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/models/user_profile.dart';
import 'package:zakat_app/core/models/monthly_giving.dart';
import 'package:zakat_app/core/notifications/notification_provider.dart';
import 'package:zakat_app/core/notifications/notification_service.dart';
import 'package:zakat_app/core/notifications/notification_target.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/providers/tracker_provider.dart';
import 'package:zakat_app/core/providers/monthly_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/services/monthly_service.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/home/home_screen.dart';
import 'package:zakat_app/ui/monthly/monthly_screen.dart';
import 'package:zakat_app/ui/tracker/tracker_screen.dart';
import 'dashboard_recycle_test.dart' as fixtures;

void main() {
  testWidgets('Arabic inbox uses Arabic navigation copy and RTL layout',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/u/notifications/n').set({
      'title': 'دعاء اليوم · النية لله',
      'body': 'اللهم تقبّل منا وبارك في عطائنا.',
      'kind': 'duaa',
      'sentAt': DateTime.now().millisecondsSinceEpoch,
      'readAt': null
    });
    final inbox =
        NotificationProvider(service: NotificationService(database: db))
          ..load('u');
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: inbox,
        child: MaterialApp(
            theme: AppTheme.forLanguage('ar'),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            home: const NotificationHistoryScreen())));
    await tester.pumpAndSettle();
    expect(find.text('الإشعارات'), findsOneWidget);
    expect(find.text('أدعيتك وتذكيرات العطاء'), findsOneWidget);
    expect(find.text('افتح الرئيسية'), findsOneWidget);
    expect(
        Directionality.of(
            tester.element(find.byType(NotificationHistoryScreen))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    inbox.dispose();
  });

  test(
      'notification targets accept only local action kinds and safe IDs/months',
      () {
    final target = NotificationTarget.fromUri(Uri.parse(
        'https://ztracker.web.app/?open=monthly&plan=p&month=2026-11&notification=i'));
    expect(target.kind, 'monthly');
    expect(target.planId, 'p');
    expect(target.month, '2026-11');
    final bad = NotificationTarget.fromUri(Uri.parse(
        'https://ztracker.web.app/?open=https://evil.example&plan=..%2Fother&month=2026-99'));
    expect(bad.kind, 'home');
    expect(bad.planId, isNull);
    expect(bad.month, isNull);
  });
  test(
      'inbox paginates, marks older messages read, and clears all data across accounts',
      () async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 53; i++) {
      await db.doc('users/u/notifications/n$i').set({
        'kind': 'duaa',
        'title': 'Duaa $i',
        'body': 'O Allah, accept our giving.',
        'sentAt': i,
        'readAt': null
      });
    }
    final inbox =
        NotificationProvider(service: NotificationService(database: db))
          ..load('u');
    await Future<void>.delayed(Duration.zero);
    expect(inbox.items.length, 50);
    expect(inbox.hasMore, true);
    expect(inbox.hasUnread, true);
    await inbox.loadOlder();
    expect(inbox.items.length, 53);
    expect(inbox.hasMore, false);
    final oldest = inbox.items.last;
    await inbox.markRead(oldest);
    expect(inbox.items.last.readAt, isNotNull);
    expect(
        (await db.doc('users/u/notifications/${oldest.id}').get())
            .data()!['readAt'],
        isA<int>());
    inbox.load('other');
    await Future<void>.delayed(Duration.zero);
    expect(inbox.items, isEmpty);
    expect(inbox.hasUnread, false);
    inbox.dispose();
  });
  for (final fromPush in [false, true]) {
    for (final kind in ['monthly', 'zakat']) {
      testWidgets(
          'notification $fromPush opens the exact $kind action without changing the default or recording a payment',
          (tester) async {
        final db = FakeFirebaseFirestore();
        final store = FirestoreService(database: db);
        await store.saveProfile(UserProfile(
            uid: 'u',
            displayName: 'Tester',
            email: 'u@example.com',
            defaultRecordId: 'default',
            onboardingCompleted: true));
        await store.saveRecord(fixtures.record('default', currency: 'EGP'));
        await store.saveRecord(fixtures.record('target', currency: 'EGP'));
        final now = DateTime.now(), key = monthKey(DateTime.now());
        await db.doc('users/u/monthlyPlans/person').set(MonthlyPlan(
                id: 'person',
                userId: 'u',
                recipient: 'Ahmed',
                amount: 100,
                currency: 'EGP',
                startMonth: key,
                createdAt: now)
            .toMap());
        await db.doc('users/u/monthlyPlans/other').set(MonthlyPlan(
                id: 'other',
                userId: 'u',
                recipient: 'Ahmed',
                amount: 200,
                currency: 'EGP',
                startMonth: key,
                createdAt: now)
            .toMap());
        await db.doc('users/u/notifications/message').set({
          'kind': kind,
          'title': 'Reminder for $kind',
          'body': 'May Allah accept your giving.',
          'planId': 'person',
          'month': key,
          'recordId': 'target',
          'sentAt': now.millisecondsSinceEpoch,
          'readAt': null
        });
        final auth = AuthProvider(
            auth: AuthService(
                auth: MockFirebaseAuth(
                    mockUser: MockUser(
                        uid: 'u',
                        email: 'u@example.com',
                        isEmailVerified: true),
                    signedIn: true)),
            store: store);
        final calc = CalculatorProvider(store: store),
            tracker = TrackerProvider(store: store),
            monthly = MonthlyProvider(store: MonthlyService(database: db));
        final inbox =
            NotificationProvider(service: NotificationService(database: db));
        await tester.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider.value(value: calc),
              ChangeNotifierProvider.value(value: tracker),
              ChangeNotifierProvider.value(value: monthly),
              ChangeNotifierProvider.value(value: inbox)
            ],
            child: MaterialApp(
                theme: AppTheme.light,
                home: HomeScreen(
                    notificationTarget: fromPush
                        ? NotificationTarget(
                            kind: kind,
                            planId: 'person',
                            month: key,
                            recordId: 'target',
                            notificationId: 'message')
                        : null))));
        await tester.pumpAndSettle();
        expect(inbox.hasUnread, !fromPush);
        if (!fromPush) {
          await tester.tap(
              find.byKey(const Key('notification-bell')).hitTestable().first);
          await tester.pumpAndSettle();
          expect(find.text('Reminder for $kind'), findsOneWidget);
          await tester.tap(find.text('Reminder for $kind'));
          await tester.pumpAndSettle();
        }
        if (kind == 'monthly') {
          final screen =
              tester.widget<MonthlyScreen>(find.byType(MonthlyScreen).last);
          expect(screen.focusPlanId, 'person');
          expect(screen.focusMonth, key);
          expect(find.text('EGP 100.00'), findsOneWidget);
          expect(find.text('EGP 200.00'), findsNothing);
        } else {
          final targetContext = tester.element(find.byType(TrackerScreen).last);
          expect(targetContext.read<TrackerProvider>().selectedRecord!.id,
              'target');
        }
        expect(auth.profile!.defaultRecordId, 'default');
        expect((await db.collection('users/u/payments').get()).docs, isEmpty);
        expect(
            (await db.doc('users/u/notifications/message').get())
                .data()!['readAt'],
            isA<int>());
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
        calc.dispose();
        tracker.dispose();
        monthly.dispose();
        inbox.dispose();
      });
    }
  }
}
