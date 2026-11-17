import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/zakat_record.dart';
import '../models/payment.dart';

class FirestoreService {
  final FirebaseFirestore _db;
  FirestoreService({FirebaseFirestore? database})
      : _db = database ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _users() => _db.collection('users');
  CollectionReference<Map<String, dynamic>> _records(String uid) =>
      _users().doc(uid).collection('zakatRecords');
  CollectionReference<Map<String, dynamic>> _payments(String uid) =>
      _users().doc(uid).collection('payments');

  // ─── Profile ───────────────────────────────────────────────────────────────

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _users().doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(uid, doc.data()!);
  }

  Future<void> saveProfile(UserProfile profile) =>
      _users().doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));

  Future<void> updateProfileFields(String uid, Map<String, dynamic> fields) =>
      _users().doc(uid).set(fields, SetOptions(merge: true));

  // ─── Zakat Records ─────────────────────────────────────────────────────────

  Stream<List<ZakatRecord>> recordsStream(String uid) {
    return _records(uid).orderBy('createdAt', descending: true).snapshots().map(
        (snap) =>
            snap.docs.map((d) => ZakatRecord.fromMap(d.id, d.data())).toList());
  }

  Future<String> saveRecord(ZakatRecord record) async {
    if (record.id.isEmpty) {
      final ref = await _records(record.userId).add(record.toMap());
      return ref.id;
    } else {
      await _records(record.userId).doc(record.id).set(record.toMap());
      return record.id;
    }
  }

  /// A stable ID and transaction make retries safe even after a lost response.
  Future<ZakatRecord> submitRecord(ZakatRecord record) async {
    final ref = _records(record.userId).doc(record.id);
    return _db.runTransaction((transaction) async {
      final previous = await transaction.get(ref);
      if (previous.data()?['deletedAt'] != null) {
        throw const FormatException(
            'Restore this record from the recycle bin first.');
      }
      if (previous.exists && previous.data()?['isSubmitted'] == true) {
        return ZakatRecord.fromMap(previous.id, previous.data()!);
      }
      transaction.set(ref, record.toMap());
      return record;
    });
  }

  Future<void> recycleRecord(String uid, String id) async {
    final ref = _records(uid).doc(id);
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw const FormatException('Record no longer exists.');
      if (doc.data()?['deletedAt'] != null) return;
      final now = DateTime.now();
      tx.update(ref, {
        'deletedAt': now.millisecondsSinceEpoch,
        'purgeAt': now.add(const Duration(days: 60)).millisecondsSinceEpoch
      });
    });
  }

  Future<void> restoreRecord(String uid, String id) async {
    final ref = _records(uid).doc(id);
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw const FormatException('Record no longer exists.');
      final data = doc.data()!;
      if (data['deletedAt'] == null) return;
      if (data['purgeAt'] is! int ||
          DateTime.now().millisecondsSinceEpoch >= data['purgeAt']) {
        throw const FormatException('The 60-day restore window has ended.');
      }
      tx.update(ref,
          {'deletedAt': FieldValue.delete(), 'purgeAt': FieldValue.delete()});
    });
  }

  Stream<List<Payment>> allPaymentsStream(String uid) => _payments(uid)
      .snapshots()
      .map((s) => s.docs.map((d) => Payment.fromMap(d.id, d.data())).toList());

  // ─── Payments ──────────────────────────────────────────────────────────────

  Stream<List<Payment>> paymentsStream(String uid, String recordId) {
    return _payments(uid)
        .where('zakatRecordId', isEqualTo: recordId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Payment.fromMap(d.id, d.data())).toList());
  }

  Future<List<String>> previousPayeeNames(String uid) async {
    final snap = await _payments(uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    final names = snap.docs
        .map((d) => d.data()['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    return names;
  }

  Future<String> addPayment(Payment payment) async {
    final ref = _payments(payment.userId).doc(payment.id);
    await _db.runTransaction((transaction) async {
      final previous = await transaction.get(ref);
      final data = payment.toMap();
      if (previous.exists) data['createdAt'] = previous.data()!['createdAt'];
      transaction.set(ref, data);
    });
    return ref.id;
  }

  Future<void> updatePayment(Payment payment) =>
      _payments(payment.userId).doc(payment.id).set(payment.toMap());

  Future<void> deletePayment(String uid, String paymentId) =>
      _payments(uid).doc(paymentId).delete();
}
