import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _db;
  NotificationService({FirebaseFirestore? database})
      : _db = database ?? FirebaseFirestore.instance;
  Query<Map<String, dynamic>> _query(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('sentAt', descending: true);
  Stream<QuerySnapshot<Map<String, dynamic>>> recent(String uid) =>
      _query(uid).limit(50).snapshots();
  Future<QuerySnapshot<Map<String, dynamic>>> older(
          String uid, DocumentSnapshot last) =>
      _query(uid).startAfterDocument(last).limit(50).get();
  Future<void> markRead(String uid, String id) => _db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .doc(id)
      .update({'readAt': DateTime.now().millisecondsSinceEpoch});
}
