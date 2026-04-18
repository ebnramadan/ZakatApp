import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/payment.dart';
import '../models/zakat_record.dart';
import '../services/firestore_service.dart';

class TrackerProvider extends ChangeNotifier {
  final _fs = FirestoreService();
  final _uuid = const Uuid();

  ZakatRecord? _selectedRecord;
  List<Payment> _payments = [];
  List<String> _payeeNames = [];
  StreamSubscription<List<Payment>>? _sub;
  bool _loading = false;
  String? _error;

  ZakatRecord? get selectedRecord => _selectedRecord;
  List<Payment> get payments => _payments;
  List<String> get payeeNames => _payeeNames;
  bool get loading => _loading;
  String? get error => _error;

  double get totalPaid => _payments.fold(0.0, (s, p) => s + p.amount);
  double get totalDue => _selectedRecord?.zakatDue ?? 0;
  double get remaining => (totalDue - totalPaid).clamp(0.0, double.infinity);

  void selectRecord(String uid, ZakatRecord record) {
    if (_selectedRecord?.id == record.id) return;
    _selectedRecord = record;
    _sub?.cancel();
    _sub = _fs.paymentsStream(uid, record.id).listen((list) {
      _payments = list;
      notifyListeners();
    });
    _loadPayeeNames(uid);
    notifyListeners();
  }

  Future<void> _loadPayeeNames(String uid) async {
    _payeeNames = await _fs.previousPayeeNames(uid);
    notifyListeners();
  }

  Future<void> addPayment({
    required String uid,
    required double amount,
    required String name,
    required DateTime date,
    required String recipient,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final payment = Payment(
        id: '',
        zakatRecordId: _selectedRecord!.id,
        userId: uid,
        amount: amount,
        name: name,
        date: date,
        recipient: recipient,
        createdAt: DateTime.now(),
      );
      await _fs.addPayment(payment);
      await _loadPayeeNames(uid);
    } catch (e) {
      _error = 'Failed to save payment.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> updatePayment(Payment updated) async {
    _error = null;
    try {
      await _fs.updatePayment(updated);
    } catch (e) {
      _error = 'Failed to update payment.';
      notifyListeners();
    }
  }

  Future<void> deletePayment(String uid, String paymentId) async {
    _error = null;
    try {
      await _fs.deletePayment(uid, paymentId);
    } catch (e) {
      _error = 'Failed to delete payment.';
      notifyListeners();
    }
  }

  List<Payment> search(String query) {
    if (query.isEmpty) return _payments;
    final q = query.toLowerCase();
    return _payments
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.recipient.toLowerCase().contains(q))
        .toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
