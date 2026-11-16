import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/models/monthly_giving.dart';
import 'package:zakat_app/core/models/payment.dart';
import 'package:zakat_app/core/models/user_profile.dart';
import 'package:zakat_app/core/services/monthly_service.dart';

void main() {
  MonthlyPlan plan(
          {String kind = 'sadaqah', String currency = 'USD', int day = 31}) =>
      MonthlyPlan(
          id: 'p',
          userId: 'u',
          recipient: 'A family',
          amount: 100,
          currency: currency,
          kind: kind,
          zakatRecordId: kind == 'zakat' ? 'r' : '',
          reminderDay: day,
          startMonth: '2024-01',
          createdAt: DateTime(2024));
  test('short months and leap years use the last valid reminder day', () {
    expect(plan().dueDate('2024-02'), DateTime(2024, 2, 29));
    expect(plan().dueDate('2025-02'), DateTime(2025, 2, 28));
    expect(plan().dueDate('2025-04'), DateTime(2025, 4, 30));
    expect(plan(day: 15).dueIn('2025-04', DateTime(2025, 4, 14)), isFalse);
    expect(plan(day: 15).dueIn('2025-04', DateTime(2025, 4, 15)), isTrue);
  });
  test('Sadaqah payment never creates a Zakat ledger entry', () async {
    final db = FakeFirebaseFirestore();
    final service = MonthlyService(database: db);
    await service.savePlan(plan());
    await service.markPaid(plan(), monthKey(DateTime.now()));
    expect(
        (await db.collection('users/u/monthlyPayments').get())
            .docs
            .single
            .data()['kind'],
        'sadaqah');
    expect((await db.collection('users/u/payments').get()).docs, isEmpty);
  });
  test(
      'monthly Zakat is atomic, retry-safe, and removed from both views by undo',
      () async {
    final db = FakeFirebaseFirestore();
    final service = MonthlyService(database: db);
    await db
        .doc('users/u/zakatRecords/r')
        .set({'isSubmitted': true, 'currency': 'USD'});
    final p = plan(kind: 'zakat');
    final month = monthKey(DateTime.now());
    await service.savePlan(p);
    await service.markPaid(p, month);
    await service.markPaid(p, month);
    final receipts = await db.collection('users/u/monthlyPayments').get();
    final ledger = await db.collection('users/u/payments').get();
    expect(receipts.docs.length, 1);
    expect(ledger.docs.length, 1);
    final payment =
        Payment.fromMap(ledger.docs.single.id, ledger.docs.single.data());
    expect(payment.isMonthly, isTrue);
    expect(payment.amount, 100);
    expect(payment.zakatRecordId, 'r');
    await service.undoPayment(MonthlyPayment.fromMap(
        receipts.docs.single.id, receipts.docs.single.data()));
    expect(
        (await db.collection('users/u/monthlyPayments').get()).docs, isEmpty);
    expect((await db.collection('users/u/payments').get()).docs, isEmpty);
  });
  test('future-month payments and cross-currency Zakat links are rejected',
      () async {
    final db = FakeFirebaseFirestore();
    final service = MonthlyService(database: db);
    final next = DateTime(DateTime.now().year, DateTime.now().month + 1);
    await expectLater(
        service.markPaid(plan(), monthKey(next)), throwsFormatException);
    await db
        .doc('users/u/zakatRecords/r')
        .set({'isSubmitted': true, 'currency': 'EGP'});
    await expectLater(
        service.savePlan(plan(kind: 'zakat')), throwsFormatException);
    await expectLater(
        service.markPaid(plan(kind: 'zakat'), monthKey(DateTime.now())),
        throwsFormatException);
    expect(
        (await db.collection('users/u/monthlyPayments').get()).docs, isEmpty);
  });
  test('editing a commitment or pausing it preserves past payment snapshots',
      () async {
    final db = FakeFirebaseFirestore();
    final service = MonthlyService(database: db);
    final p = plan();
    await service.savePlan(p);
    await service.markPaid(p, monthKey(DateTime.now()));
    final changed = MonthlyPlan.fromMap('p', {...p.toMap(), 'amount': 250});
    await service.savePlan(changed);
    await service.savePlan(changed.archived());
    final receipt = (await db.collection('users/u/monthlyPayments').get())
        .docs
        .single
        .data();
    expect(receipt['amount'], 100);
    expect((await db.doc('users/u/monthlyPlans/p').get()).data()!['active'],
        isFalse);
  });
  test('profile defaults round trip without reclassifying existing plans', () {
    final profile =
        UserProfile(uid: 'u', displayName: 'U', email: 'u@example.com');
    final updated = profile.copyWith(
        monthlyDefaultKind: 'zakat', monthlyEmailReminders: true);
    final loaded = UserProfile.fromMap('u', updated.toMap());
    expect(loaded.monthlyDefaultKind, 'zakat');
    expect(loaded.monthlyEmailReminders, isTrue);
    expect(profile.monthlyDefaultKind, 'sadaqah');
    expect(plan().kind, 'sadaqah');
  });
}
