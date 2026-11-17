import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/models/dashboard_summary.dart';
import 'package:zakat_app/core/models/user_profile.dart';
import 'package:zakat_app/core/models/zakat_record.dart';
import 'package:zakat_app/core/models/payment.dart';
import 'package:zakat_app/core/services/firestore_service.dart';

ZakatRecord record(String id, {String currency = 'USD', bool future = false}) =>
    ZakatRecord(
      id: id,
      userId: 'u',
      name: id,
      currency: currency,
      hawlStartDate: future ? DateTime(2025, 12, 1) : DateTime(2023),
      createdAt: DateTime(2023),
      isSubmitted: true,
      nisabMet: true,
      totalWealth: 10000,
      nisabThreshold: 8500,
      goldPricePerGram24k: 100,
    );
Payment payment(String id, String recordId, double amount) => Payment(
      id: id,
      userId: 'u',
      zakatRecordId: recordId,
      amount: amount,
      name: 'Giving',
      recipient: 'Recipient',
      date: DateTime(2025),
      createdAt: DateTime(2025),
    );
void main() {
  test(
      'testing reset removes only this user’s app collections and restarts onboarding',
      () async {
    final db = FakeFirebaseFirestore();
    final local = FirestoreService(database: db);
    final fresh = UserProfile(
        uid: 'u', displayName: 'Tester', email: 'ebnramadan@gmail.com');
    await local.saveProfile(fresh.copyWith(
        sharingEnabled: true,
        shareRecipients: ['trusted@example.com'],
        onboardingCompleted: true));
    for (final name in [
      'payments',
      'monthlyPayments',
      'monthlyPlans',
      'reminderDeliveries',
      'shareDeliveries',
      'zakatRecords'
    ]) {
      await db.doc('users/u/$name/fixture').set({'fixture': true});
    }
    await db.doc('users/other/zakatRecords/saved').set({'keep': true});
    await local.resetAppData(fresh);
    for (final name in [
      'payments',
      'monthlyPayments',
      'monthlyPlans',
      'reminderDeliveries',
      'shareDeliveries',
      'zakatRecords'
    ]) {
      expect((await db.collection('users/u/$name').get()).docs, isEmpty);
    }
    final profile = (await local.getProfile('u'))!;
    expect(profile.onboardingCompleted, isFalse);
    expect(profile.sharingEnabled, isFalse);
    expect(profile.resetInProgress, isFalse);
    expect(
        (await db.doc('users/other/zakatRecords/saved').get()).exists, isTrue);
  });
  test('legacy profiles do not silently enable sharing or repeat onboarding',
      () {
    final old = UserProfile.fromMap('u', {
      'displayName': 'Old',
      'email': 'old@example.com',
      'shareRecipients': ['trusted@example.com'],
      'shareFrequency': 'monthly'
    });
    expect(old.sharingEnabled, isFalse);
    expect(old.onboardingCompleted, isTrue);
    expect(
        UserProfile(uid: 'new', displayName: 'New', email: 'new@example.com')
            .onboardingCompleted,
        isFalse);
  });

  test(
      'dashboard separates currencies and estimates, excludes bin, and does not offset other records with overpayment',
      () {
    final deleted = record('deleted')..deletedAt = DateTime(2025);
    final totals = DashboardSummary.build([
      record('a'),
      record('b'),
      record('c', currency: 'EGP'),
      record('future', future: true),
      deleted
    ], [
      payment('p', 'a', 400),
      payment('q', 'c', 50),
      payment('x', 'deleted', 100)
    ], DateTime(2026, 1, 1));
    final usd = totals.firstWhere((s) => s.currency == 'USD');
    expect(usd.due, 500);
    expect(usd.remaining, 250);
    expect(usd.given, 400);
    expect(usd.upcomingEstimate, 250);
    expect(usd.records, 3);
    final egp = totals.firstWhere((s) => s.currency == 'EGP');
    expect(egp.remaining, 200);
    expect(egp.given, 50);
  });
  test(
      'recycle/restore retain financial data and payment IDs; retries never extend retention',
      () async {
    final db = FakeFirebaseFirestore();
    final store = FirestoreService(database: db);
    final original = record('r');
    await store.saveRecord(original);
    await store.addPayment(payment('p', 'r', 100));
    await store.recycleRecord('u', 'r');
    final path = db.doc('users/u/zakatRecords/r');
    final first = (await path.get()).data()!;
    expect(first['purgeAt'] - first['deletedAt'],
        const Duration(days: 60).inMilliseconds);
    await store.recycleRecord('u', 'r');
    expect((await path.get()).data(), first);
    final recycled = ZakatRecord.fromMap('r', first);
    expect(
        recycled.canRestoreAt(
            recycled.purgeAt!.subtract(const Duration(milliseconds: 1))),
        isTrue);
    expect(recycled.canRestoreAt(recycled.purgeAt!), isFalse);
    await store.restoreRecord('u', 'r');
    expect((await path.get()).data(), original.toMap());
    expect((await db.doc('users/u/payments/p').get()).data()!['amount'], 100);
    await path.update({
      'deletedAt': DateTime.now()
          .subtract(const Duration(days: 61))
          .millisecondsSinceEpoch,
      'purgeAt': DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch
    });
    await expectLater(store.restoreRecord('u', 'r'), throwsFormatException);
  });
}
