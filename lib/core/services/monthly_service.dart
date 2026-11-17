import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/monthly_giving.dart';

class MonthlyService {
  final FirebaseFirestore db;
  MonthlyService({FirebaseFirestore? database})
      : db = database ?? FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      db.collection('users').doc(uid);
  Stream<List<MonthlyPlan>> plans(String uid) =>
      _user(uid).collection('monthlyPlans').snapshots().map((s) => s.docs
          .map((d) => MonthlyPlan.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) =>
            a.recipient.toLowerCase().compareTo(b.recipient.toLowerCase())));
  Stream<List<MonthlyPayment>> payments(String uid) =>
      _user(uid).collection('monthlyPayments').snapshots().map((s) =>
          s.docs.map((d) => MonthlyPayment.fromMap(d.id, d.data())).toList());
  Stream<bool> emailReadiness() => db
      .doc('appConfig/reminders')
      .snapshots()
      .map((s) => s.data()?['enabled'] == true);
  Future<void> savePlan(MonthlyPlan plan) async {
    plan.validate();
    if (plan.kind == 'zakat') {
      final record = await _user(plan.userId)
          .collection('zakatRecords')
          .doc(plan.zakatRecordId)
          .get();
      if (record.data()?['deletedAt'] != null ||
          record.data()?['isSubmitted'] != true ||
          record.data()?['currency'] != plan.currency) {
        throw const FormatException(
            'Choose a submitted Zakat record in the same currency.');
      }
    }
    await _user(plan.userId)
        .collection('monthlyPlans')
        .doc(plan.id)
        .set(plan.toMap());
  }

  /// Both records change atomically. A deterministic ID prevents duplicate clicks/retries.
  Future<void> markPaid(MonthlyPlan plan, String month,
      {DateTime? paidAt}) async {
    plan.validate();
    monthFromKey(month);
    final now = DateTime.now();
    if (month.compareTo(plan.startMonth) < 0 ||
        month.compareTo(monthKey(now)) > 0) {
      throw const FormatException(
          'Choose a month from the start of this commitment through the current month.');
    }
    final selectedMonth = monthFromKey(month);
    final date = paidAt ??
        (month == monthKey(now)
            ? now
            : DateTime(selectedMonth.year, selectedMonth.month + 1, 0));
    if (monthKey(date) != month) {
      throw const FormatException(
          'Choose a payment date within the selected month.');
    }
    if (date.isAfter(now)) {
      throw const FormatException('A future payment cannot be marked paid.');
    }
    final receipt = MonthlyPayment(
        id: MonthlyPayment.receiptId(plan.id, month),
        userId: plan.userId,
        planId: plan.id,
        month: month,
        recipient: plan.recipient,
        amount: plan.amount,
        currency: plan.currency,
        kind: plan.kind,
        zakatRecordId: plan.zakatRecordId,
        paidAt: date,
        createdAt: now);
    final ref =
        _user(plan.userId).collection('monthlyPayments').doc(receipt.id);
    await db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) return;
      if (plan.kind == 'zakat') {
        final record = await tx.get(_user(plan.userId)
            .collection('zakatRecords')
            .doc(plan.zakatRecordId));
        if (record.data()?['deletedAt'] != null ||
            record.data()?['isSubmitted'] != true ||
            record.data()?['currency'] != plan.currency) {
          throw const FormatException(
              'The selected Zakat record must be submitted and use the same currency.');
        }
      }
      tx.set(ref, receipt.toMap());
      if (receipt.kind == 'zakat') {
        tx.set(_user(plan.userId).collection('payments').doc(receipt.ledgerId),
            ledgerData(receipt));
      }
    });
  }

  static Map<String, dynamic> ledgerData(MonthlyPayment receipt) => {
        'userId': receipt.userId,
        'zakatRecordId': receipt.zakatRecordId,
        'amount': receipt.amount,
        'name': 'شهريات · ${receipt.month}',
        'recipient': receipt.recipient,
        'date': receipt.paidAt.millisecondsSinceEpoch,
        'createdAt': receipt.createdAt.millisecondsSinceEpoch,
        'source': 'monthly',
        'monthlyPaymentId': receipt.id,
      };
  Future<void> undoPayment(MonthlyPayment payment) async {
    final batch = db.batch();
    batch.delete(
        _user(payment.userId).collection('monthlyPayments').doc(payment.id));
    if (payment.kind == 'zakat') {
      batch.delete(
          _user(payment.userId).collection('payments').doc(payment.ledgerId));
    }
    await batch.commit();
  }
}
