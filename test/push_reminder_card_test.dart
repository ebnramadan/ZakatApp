import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/services/push_service.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/notifications/push_reminder_card.dart';

class TestPushService extends PushService {
  bool configFails = false, settingsFail = false;
  String? registrationError;
  int testsShown = 0, registrations = 0;
  bool schedulingConfirmed = true;
  bool? lastShowNames;
  Map<String, dynamic>? savedSettings;
  @override
  String get support => 'supported';
  @override
  String get permission => 'granted';
  @override
  Future<Map<String, dynamic>> configuration() async {
    if (configFails) throw StateError('Simulated connection failure');
    return {
      'publicKey': 'B${'a' * 86}',
      'scheduledAt':
          schedulingConfirmed ? DateTime.now().millisecondsSinceEpoch : 0
    };
  }

  @override
  Future<Map<String, dynamic>?> settings(String uid) async {
    if (settingsFail) throw StateError('Simulated saved-settings failure');
    return savedSettings;
  }

  @override
  Future<void> showTest(String title, String body) async {
    testsShown++;
  }

  @override
  Future<void> enable(String uid, String publicKey,
      {required bool monthly,
      required bool zakat,
      required bool showNames}) async {
    registrations++;
    if (registrationError != null) throw PushSetupException(registrationError!);
    lastShowNames = showNames;
  }
}

void main() {
  Future<AuthProvider> mount(
      WidgetTester tester, TestPushService service) async {
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
            builder: (context, a, _) => MaterialApp(
                theme: AppTheme.light,
                home: Scaffold(
                    body: SingleChildScrollView(
                        child: a.user == null
                            ? const SizedBox()
                            : PushReminderCard(service: service)))))));
    await tester.pumpAndSettle();
    addTearDown(auth.dispose);
    return auth;
  }

  testWidgets('registration failures explain the failing step and allow retry',
      (tester) async {
    const message =
        'This device could not register for automatic reminders. Test notifications only check permission. Please retry.';
    final service = TestPushService()..registrationError = message;
    await mount(tester, service);
    await tester
        .ensureVisible(find.text('Enable notifications on this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable notifications on this device'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(find.text('Save notification preferences'), findsNothing);
    service.registrationError = null;
    await tester
        .ensureVisible(find.text('Enable notifications on this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable notifications on this device'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
    expect(find.text('Save notification preferences'), findsOneWidget);
  });

  testWidgets(
      'first-time users can test notifications without enabling automatic reminders',
      (tester) async {
    final service = TestPushService();
    await mount(tester, service);
    expect(find.text('Send test notification'), findsOneWidget);
    await tester.tap(find.byKey(const Key('test-notification')));
    await tester.pumpAndSettle();
    expect(service.testsShown, 1);
    expect(service.registrations, 0);
    expect(find.textContaining('Check Notification Centre'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'a failed config load never hides the local test and retry clears stale errors',
      (tester) async {
    final service = TestPushService()..configFails = true;
    await mount(tester, service);
    expect(find.text('Notification settings could not load. Please retry.'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('test-notification')));
    await tester.pumpAndSettle();
    expect(service.testsShown, 1);
    service.configFails = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Notification settings could not load. Please retry.'),
        findsNothing);
    expect(find.text('Enable notifications on this device'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'failed private settings do not overwrite existing choices but still allow testing',
      (tester) async {
    final service = TestPushService()..settingsFail = true;
    await mount(tester, service);
    final enable = find.byWidgetPredicate((widget) => widget is FilledButton);
    expect(tester.widget<FilledButton>(enable).onPressed, isNull);
    await tester.tap(find.byKey(const Key('test-notification')));
    await tester.pumpAndSettle();
    expect(service.testsShown, 1);
    expect(service.registrations, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('new notification setup includes recipient names by default',
      (tester) async {
    final service = TestPushService();
    await mount(tester, service);
    final names = find.widgetWithText(SwitchListTile, 'Show recipient names');
    expect(tester.widget<SwitchListTile>(names).value, isTrue);
    await tester
        .ensureVisible(find.text('Enable notifications on this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
    await tester.pumpAndSettle();
    expect(service.lastShowNames, isTrue);
  });
  testWidgets('a saved preference to hide names remains respected',
      (tester) async {
    final service = TestPushService()
      ..savedSettings = {'monthly': true, 'zakat': true, 'showNames': false};
    await mount(tester, service);
    expect(
        tester
            .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Show recipient names'))
            .value,
        isFalse);
  });
}
