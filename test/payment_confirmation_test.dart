import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:provider/provider.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/theme.dart';
import 'package:zakat_app/ui/tracker/tracker_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/models/payment.dart';
import 'package:zakat_app/core/models/confirmed_payments.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/providers/tracker_provider.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'dashboard_recycle_test.dart' as fixtures;

class DelayedPaymentStore extends FirestoreService {
  DelayedPaymentStore() : super(database: FakeFirebaseFirestore());
  final trackerSnapshots = StreamController<List<Payment>>.broadcast();
  final homeSnapshots = StreamController<List<Payment>>.broadcast();
  final saved = <Payment>[];
  final attemptIds = <String>[];
  bool fail = false;
  Completer<void>? writeGate;
  @override
  Stream<List<Payment>> paymentsStream(String uid, String recordId) =>
      trackerSnapshots.stream;
  @override
  Stream<List<Payment>> allPaymentsStream(String uid) => homeSnapshots.stream;
  @override
  Future<String> addPayment(Payment payment) async {
    attemptIds.add(payment.id);
    if (writeGate != null) await writeGate!.future;
    if (fail) throw StateError('Offline');
    saved.add(payment);
    return payment.id;
  }
}

void main() {
  testWidgets(
      'saving the first payment shows its row immediately and clears an old search filter',
      (tester) async {
    final store = DelayedPaymentStore();
    final record = fixtures.record('r', currency: 'EGP');
    await store.saveRecord(record);
    final auth = AuthProvider(
        auth: AuthService(
            auth: MockFirebaseAuth(
                mockUser: MockUser(
                    uid: 'u', email: 'u@example.com', isEmailVerified: true),
                signedIn: true)),
        store: store);
    final calc = CalculatorProvider(store: store)..loadRecords('u');
    final tracker = TrackerProvider(store: store)..selectRecord('u', record);
    store.homeSnapshots.add([]);
    store.trackerSnapshots.add([]);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: calc),
      ChangeNotifierProvider.value(value: tracker),
    ], child: MaterialApp(theme: AppTheme.light, home: const TrackerScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'old search');
    await tester.pumpAndSettle();
    expect(find.text('No matching payments'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '100');
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Name'),
        'First payment');
    await tester.tap(find.widgetWithText(FilledButton, 'Add Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('First payment'), findsOneWidget);
    expect(find.text('No matching payments'), findsNothing);
    expect(tracker.totalPaid, 100);
    expect(calc.allPayments.single.amount, 100);
    expect(store.saved.length, 1);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    tracker.dispose();
    calc.dispose();
    await store.trackerSnapshots.close();
    await store.homeSnapshots.close();
  });

  test(
      'confirmed first payment appears in Tracker and Home before live queries refresh, then deduplicates',
      () async {
    final store = DelayedPaymentStore();
    final tracker = TrackerProvider(store: store)
      ..selectRecord('u', fixtures.record('r'));
    final calc = CalculatorProvider(store: store)..loadRecords('u');
    final payment = await tracker.addPayment(
        uid: 'u',
        amount: 100,
        name: 'Ahmed',
        date: DateTime.now(),
        recipient: '');
    expect(payment, isNotNull);
    calc.confirmPayment(payment!);
    expect(tracker.payments.single.id, payment.id);
    expect(tracker.totalPaid, 100);
    expect(calc.allPayments.single.id, payment.id);
    // An older cached query arriving after the successful commit must not erase it.
    store.trackerSnapshots.add([]);
    store.homeSnapshots.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(tracker.totalPaid, 100);
    expect(calc.allPayments.single.id, payment.id);
    tracker.reload();
    expect(tracker.totalPaid, 100);
    store.trackerSnapshots.add([payment]);
    store.homeSnapshots.add([payment]);
    await Future<void>.delayed(Duration.zero);
    expect(tracker.payments.length, 1);
    expect(tracker.totalPaid, 100);
    expect(calc.allPayments.length, 1);
    tracker.dispose();
    calc.dispose();
    await store.trackerSnapshots.close();
    await store.homeSnapshots.close();
  });
  test('failed writes never appear and a retry uses the same payment ID',
      () async {
    final store = DelayedPaymentStore()..fail = true;
    final tracker = TrackerProvider(store: store)
      ..selectRecord('u', fixtures.record('r'));
    expect(
        await tracker.addPayment(
            uid: 'u',
            amount: 100,
            name: 'Ahmed',
            date: DateTime.now(),
            recipient: ''),
        isNull);
    expect(tracker.payments, isEmpty);
    expect(tracker.error, isNotNull);
    store.fail = false;
    final saved = await tracker.addPayment(
        uid: 'u',
        amount: 100,
        name: 'Ahmed',
        date: DateTime.now(),
        recipient: '');
    expect(saved, isNotNull);
    expect(store.attemptIds.toSet().length, 1);
    expect(tracker.payments.length, 1);
    tracker.dispose();
    await store.trackerSnapshots.close();
    await store.homeSnapshots.close();
  });
  test(
      'rapid second save does not create a second payment and account switches cannot leak the confirmed write',
      () async {
    final gate = Completer<void>();
    final store = DelayedPaymentStore()..writeGate = gate;
    final tracker = TrackerProvider(store: store)
      ..selectRecord('u', fixtures.record('r'));
    final first = tracker.addPayment(
        uid: 'u',
        amount: 100,
        name: 'Ahmed',
        date: DateTime.now(),
        recipient: '');
    expect(
        await tracker.addPayment(
            uid: 'u',
            amount: 100,
            name: 'Ahmed',
            date: DateTime.now(),
            recipient: ''),
        isNull);
    tracker.clearSelection();
    gate.complete();
    await first;
    expect(store.saved.length, 1);
    expect(tracker.payments, isEmpty);
    tracker.dispose();
    await store.trackerSnapshots.close();
    await store.homeSnapshots.close();
  });
  test('confirmed edit and delete cannot be undone by a delayed older snapshot',
      () {
    final p = fixtures.payment('p', 'r', 100);
    final changed = Payment.fromMap(p.id, p.toMap())..amount = 200;
    final cache = ConfirmedPayments()..save(changed);
    expect(cache.merge([p], acknowledge: true).single.amount, 200);
    expect(cache.merge([changed], acknowledge: true).single.amount, 200);
    cache.delete(p.id);
    expect(cache.merge([p], acknowledge: true), isEmpty);
    expect(cache.merge([], acknowledge: true), isEmpty);
  });
}
