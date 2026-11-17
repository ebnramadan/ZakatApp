import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:zakat_app/core/models/giving_forecast.dart';
import 'package:zakat_app/core/models/monthly_giving.dart';
import 'package:zakat_app/core/services/monthly_service.dart';

void main() {
  MonthlyPlan plan(String id,
          {String currency = 'EGP',
          String kind = 'sadaqah',
          String start = '2026-01',
          bool active = true,
          String record = ''}) =>
      MonthlyPlan(
          id: id,
          userId: 'u',
          recipient: id,
          amount: 100,
          currency: currency,
          kind: kind,
          zakatRecordId: record,
          startMonth: start,
          active: active,
          createdAt: DateTime(2026));
  test(
      '12 months cross years, keep currencies separate and exclude unavailable records and paused plans',
      () {
    final result = givingForecast(
        from: DateTime(2026, 11, 17),
        plans: [
          plan('extra'),
          plan('usd', currency: 'USD'),
          plan('zakat', kind: 'zakat', record: 'active'),
          plan('recycled', kind: 'zakat', record: 'deleted'),
          plan('wrong currency',
              currency: 'USD', kind: 'zakat', record: 'active'),
          plan('paused', active: false),
          plan('future', start: '2027-01'),
        ],
        recordAvailable: (id, currency) => id == 'active' && currency == 'EGP');
    expect(result.length, 12);
    expect(result.first.month, DateTime(2026, 11));
    expect(result.last.month, DateTime(2027, 10));
    expect(result.first.total('EGP'), 200);
    expect(result.first.total('USD'), 100);
    expect(result.first.zakat['USD'], isNull);
    expect(result[2].total('EGP'), 300);
    expect(result[2].sadaqah['EGP'], 200);
  });
  test(
      'retroactive Zakat keeps the actual date in its atomic tracker receipt, retry and undo',
      () async {
    final db = FakeFirebaseFirestore();
    final service = MonthlyService(database: db);
    final prior = DateTime(DateTime.now().year, DateTime.now().month - 2, 12);
    final p = plan('retro', kind: 'zakat', record: 'r', start: monthKey(prior));
    await db
        .doc('users/u/zakatRecords/r')
        .set({'isSubmitted': true, 'currency': 'EGP'});
    await service.savePlan(p);
    await service.markPaid(p, monthKey(prior), paidAt: prior);
    await service.markPaid(p, monthKey(prior), paidAt: prior);
    final receipts =
        (await db.collection('users/u/monthlyPayments').get()).docs;
    final ledger = (await db.collection('users/u/payments').get()).docs;
    expect(receipts, hasLength(1));
    expect(ledger, hasLength(1));
    expect(ledger.single.data()['date'], prior.millisecondsSinceEpoch);
    final receipt =
        MonthlyPayment.fromMap(receipts.single.id, receipts.single.data());
    expect(receipt.month, monthKey(prior));
    await expectLater(
        service.markPaid(p, monthKey(prior), paidAt: DateTime.now()),
        throwsFormatException);
    await service.undoPayment(receipt);
    expect((await db.collection('users/u/payments').get()).docs, isEmpty);
  });
}
