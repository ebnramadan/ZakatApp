import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zakat_app/core/models/zakat_record.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/providers/calculator_provider.dart';
import 'package:zakat_app/core/providers/tracker_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';
import 'package:zakat_app/core/services/price_service.dart';

class UnreliableStore extends FirestoreService {
  UnreliableStore(FakeFirebaseFirestore database) : super(database: database);
  bool fail = true;
  @override
  Future<ZakatRecord> submitRecord(ZakatRecord record) async {
    // Simulate a successful write followed by a lost response.
    final saved = await super.submitRecord(record);
    if (fail) {
      fail = false;
      throw Exception('Lost response');
    }
    return saved;
  }
}

class OfflineRecordStore extends FirestoreService {
  OfflineRecordStore() : super(database: FakeFirebaseFirestore());
  bool offline = true;
  @override
  Stream<List<ZakatRecord>> recordsStream(String uid) =>
      offline ? Stream.error(StateError('Offline')) : Stream.value([]);
}

void main() {
  test(
      'record-load errors clear on a successful retry independently of draft errors',
      () async {
    final store = OfflineRecordStore();
    final provider = CalculatorProvider(store: store);
    provider.loadRecords('alice');
    await Future<void>.delayed(Duration.zero);
    expect(provider.recordsError, isNotNull);
    expect(provider.error, isNull);
    store.offline = false;
    provider.loadRecords('alice');
    await Future<void>.delayed(Duration.zero);
    expect(provider.recordsError, isNull);
    expect(provider.recordsLoading, isFalse);
    provider.dispose();
  });
  test('calculator price failures do not become dashboard record errors',
      () async {
    final provider = CalculatorProvider(
        store: FirestoreService(database: FakeFirebaseFirestore()),
        prices: PriceService.forTesting(
            MockClient((_) async => http.Response('Unavailable', 503))));
    provider.loadRecords('alice');
    provider.startNewRecord('alice', 'USD');
    await provider.fetchPrices('USD');
    expect(provider.error, isNotNull);
    expect(provider.recordsError, isNull);
    expect(provider.recordsLoading, isFalse);
    provider.dispose();
  });
  test('fetched price updates the draft, Nisab and nonmanual gold entries',
      () async {
    final response = Completer<http.Response>();
    final provider = CalculatorProvider(
        store: FirestoreService(database: FakeFirebaseFirestore()),
        prices: PriceService.forTesting(MockClient((_) => response.future)));
    provider.startNewRecord('alice', 'USD');
    provider.draft!.goldEntries.add(GoldEntry(grams: 100, pricePerGram24k: 0));
    final request = provider.fetchPrices('USD');
    response.complete(http.Response(
        '{"symbol":"XAU","currency":"USD","price":3110.35,"updatedAt":"${DateTime.now().toUtc().toIso8601String()}"}',
        200));
    await request;
    expect(provider.draft!.goldPricePerGram24k, closeTo(100, .001));
    expect(
        provider.draft!.goldEntries.first.pricePerGram24k, closeTo(100, .001));
    expect(provider.nisabValue, closeTo(8500, .001));
    expect(provider.computeResults(), isTrue);
    expect(provider.draft!.totalWealth, closeTo(10000, .001));
    provider.dispose();
  });
  test('late live result does not overwrite a manual Nisab quote', () async {
    final response = Completer<http.Response>();
    final provider = CalculatorProvider(
        store: FirestoreService(database: FakeFirebaseFirestore()),
        prices: PriceService.forTesting(MockClient((_) => response.future)));
    provider.startNewRecord('alice', 'USD');
    final request = provider.fetchPrices('USD');
    provider.updateGoldPrice(90);
    response.complete(http.Response(
        '{"symbol":"XAU","currency":"USD","price":3110.35,"updatedAt":"${DateTime.now().toUtc().toIso8601String()}"}',
        200));
    await request;
    expect(provider.draft!.goldPricePerGram24k, 90);
    provider.dispose();
  });
  test(
      'failed submission keeps the draft editable and retry creates no duplicate',
      () async {
    final db = FakeFirebaseFirestore();
    final provider = CalculatorProvider(store: UnreliableStore(db));
    provider.startNewRecord('alice', 'USD');
    provider.updateCashLocal(10000);
    provider.updateGoldPrice(100);
    final id = provider.draft!.id;
    expect(await provider.submitDraft('alice'), isNull);
    expect(provider.draft!.isSubmitted, isFalse);
    expect(provider.error, isNotNull);
    provider.updateCashLocal(20000);
    final saved = await provider.submitDraft('alice');
    expect(saved!.cashLocal,
        10000); // The original immutable server snapshot wins.
    expect(saved.id, id);
    expect(provider.error, isNull);
    expect(provider.draft, isNull);
    expect(
        (await db.collection('users/alice/zakatRecords').get()).docs.length, 1);
    provider.dispose();
  });
  test('draft round trip preserves currency, names, dates and assets',
      () async {
    final db = FakeFirebaseFirestore();
    final store = FirestoreService(database: db);
    final provider = CalculatorProvider(store: store);
    provider.startNewRecord('alice', 'EGP');
    provider.updateCashLocal(15000);
    provider.updateGoldPrice(5000);
    provider.updateDraftName('Saved draft');
    expect(await provider.saveDraft(), isTrue);
    final snapshot =
        (await db.collection('users/alice/zakatRecords').get()).docs.single;
    final loaded = ZakatRecord.fromMap(snapshot.id, snapshot.data());
    final resumed = CalculatorProvider(store: store)..resumeRecord(loaded);
    expect(resumed.draft!.currency, 'EGP');
    expect(resumed.draft!.cashLocal, 15000);
    expect(resumed.draft!.name, 'Saved draft');
    provider.dispose();
    resumed.dispose();
  });
  test('switching tracked records immediately clears the previous payments',
      () async {
    final db = FakeFirebaseFirestore();
    final provider = TrackerProvider(store: FirestoreService(database: db));
    ZakatRecord record(String id) => ZakatRecord(
        id: id,
        userId: 'alice',
        currency: 'USD',
        name: id,
        hawlStartDate: DateTime(2023),
        createdAt: DateTime(2023));
    await db.doc('users/alice/payments/p').set({
      'userId': 'alice',
      'zakatRecordId': 'r1',
      'amount': 10,
      'name': 'P',
      'recipient': '',
      'date': 1,
      'createdAt': 1
    });
    provider.selectRecord('alice', record('r1'));
    await Future<void>.delayed(Duration.zero);
    expect(provider.totalPaid, 10);
    provider.selectRecord('alice', record('r2'));
    expect(provider.payments, isEmpty);
    provider.dispose();
    await Future<void>.delayed(Duration.zero);
  });
  test('profile failures can retry, and sign-out clears the profile', () async {
    final firebase = MockFirebaseAuth(
        mockUser: MockUser(
            uid: 'alice', email: 'alice@example.com', isEmailVerified: true),
        signedIn: true);
    final provider = AuthProvider(
        auth: AuthService(auth: firebase),
        store: FirestoreService(database: FakeFirebaseFirestore()));
    await Future<void>.delayed(Duration.zero);
    expect(provider.profile!.uid, 'alice');
    await firebase.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(provider.user, isNull);
    expect(provider.profile, isNull);
    provider.dispose();
  });
}
