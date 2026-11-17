import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/payment.dart';
import '../models/zakat_record.dart';
import '../services/firestore_service.dart';

class TrackerProvider extends ChangeNotifier {
  final FirestoreService _fs;
  TrackerProvider({FirestoreService? store})
      : _fs = store ?? FirestoreService();
  bool _disposed = false;
  String? _pendingPaymentId;
  int _selection = 0;

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
  double get totalDue => _selectedRecord?.estimatedZakat ?? 0;
  double get remaining => (totalDue - totalPaid).clamp(0.0, double.infinity);

  void selectRecord(String uid, ZakatRecord record) {
    if (_selectedRecord?.id == record.id) return;
    _selection++;
    _pendingPaymentId = null;
    _payments = [];
    _payeeNames = [];
    _error = null;
    _selectedRecord = record;
    _sub?.cancel();
    final selection = _selection;
    _sub = _fs.paymentsStream(uid, record.id).listen((list) {
      if (_disposed || selection != _selection) return;
      _payments = list;
      _notify();
    }, onError: (Object e) {
      _error = 'Could not load payments. Check your connection.';
      _notify();
    });
    _loadPayeeNames(uid);
    _notify();
  }

  void clearSelection() {
    _selection++;
    _sub?.cancel();
    _selectedRecord = null;
    _payments = [];
    _payeeNames = [];
    _error = null;
    _notify();
  }

  void reload() {
    final record = _selectedRecord;
    if (record == null) return;
    _selectedRecord = null;
    selectRecord(record.userId, record);
  }

  Future<void> _loadPayeeNames(String uid) async {
    final selection = _selection;
    try {
      final names = await _fs.previousPayeeNames(uid);
      if (_disposed || selection != _selection) return;
      _payeeNames = names;
      _notify();
    } catch (_) {
      /* Suggestions are optional; payment success is independent. */
    }
  }

  Future<void> addPayment({
    required String uid,
    required double amount,
    required String name,
    required DateTime date,
    required String recipient,
  }) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      if (!amount.isFinite ||
          amount <= 0 ||
          _selectedRecord?.currency == null ||
          _selectedRecord!.userId != uid) {
        throw const FormatException('Invalid payment');
      }
      _pendingPaymentId ??= const Uuid().v4();
      final payment = Payment(
        id: _pendingPaymentId!,
        zakatRecordId: _selectedRecord!.id,
        userId: uid,
        amount: amount,
        name: name,
        date: date,
        recipient: recipient,
        createdAt: DateTime.now(),
      );
      await _fs.addPayment(payment);
      _pendingPaymentId = null;
      await _loadPayeeNames(uid);
    } catch (e) {
      _error = 'Failed to save payment.';
    }
    _loading = false;
    _notify();
  }

  Future<void> updatePayment(Payment updated) async {
    _error = null;
    try {
      if (updated.isMonthly) {
        throw const FormatException('Manage this payment in شهريات.');
      }
      if (!updated.amount.isFinite || updated.amount <= 0) {
        throw const FormatException('Invalid amount');
      }
      await _fs.updatePayment(updated);
    } catch (e) {
      _error = 'Failed to update payment.';
      _notify();
    }
  }

  Future<void> deletePayment(String uid, String paymentId) async {
    _error = null;
    try {
      await _fs.deletePayment(uid, paymentId);
    } catch (e) {
      _error = 'Failed to delete payment.';
      _notify();
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
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _selection++;
    _sub?.cancel();
    super.dispose();
  }
}
