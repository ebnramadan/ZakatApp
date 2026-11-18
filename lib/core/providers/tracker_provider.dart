import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/payment.dart';
import '../models/confirmed_payments.dart';
import '../models/zakat_record.dart';
import '../services/firestore_service.dart';

class TrackerProvider extends ChangeNotifier {
  final FirestoreService _fs;
  TrackerProvider({FirestoreService? store})
      : _fs = store ?? FirestoreService();
  bool _disposed = false;
  String? _pendingPaymentId;
  int _selection = 0;
  final _confirmed = ConfirmedPayments();

  ZakatRecord? _selectedRecord;
  List<Payment> _payments = [];
  StreamSubscription<List<Payment>>? _sub;
  bool _loading = false;
  String? _error;

  ZakatRecord? get selectedRecord => _selectedRecord;
  List<Payment> get payments => _payments;
  bool get loading => _loading;
  String? get error => _error;

  double get totalPaid => _payments.fold(0.0, (s, p) => s + p.amount);
  double get totalDue => _selectedRecord?.estimatedZakat ?? 0;
  double get remaining => (totalDue - totalPaid).clamp(0.0, double.infinity);

  void selectRecord(String uid, ZakatRecord record, {bool force = false}) {
    final same =
        _selectedRecord?.id == record.id && _selectedRecord?.userId == uid;
    if (same && !force) return;
    _selection++;
    if (!same) {
      _pendingPaymentId = null;
      _payments = [];
      _confirmed.clear();
    }
    _error = null;
    _selectedRecord = record;
    _sub?.cancel();
    final selection = _selection;
    _sub = _fs.paymentsStream(uid, record.id).listen((list) {
      if (_disposed || selection != _selection) return;
      _payments = _confirmed.merge(list, acknowledge: true);
      _notify();
    }, onError: (Object e) {
      if (_disposed || selection != _selection) return;
      _error = 'Could not load payments. Check your connection.';
      _notify();
    });
    _notify();
  }

  void clearSelection() {
    _selection++;
    _sub?.cancel();
    _selectedRecord = null;
    _payments = [];
    _confirmed.clear();
    _error = null;
    _notify();
  }

  void reload() {
    final record = _selectedRecord;
    if (record == null) return;
    selectRecord(record.userId, record, force: true);
  }

  Future<Payment?> addPayment({
    required String uid,
    required double amount,
    required String name,
    required DateTime date,
    required String recipient,
  }) async {
    if (_loading) return null;
    final selection = _selection;
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
      if (_disposed || selection != _selection) return null;
      _confirmed.save(payment);
      _payments = _confirmed.merge(_payments);
      _pendingPaymentId = null;
      return payment;
    } catch (e) {
      if (!_disposed && selection == _selection) {
        _error = 'Failed to save payment.';
      }
      return null;
    } finally {
      _loading = false;
      _notify();
    }
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
      final selection = _selection;
      await _fs.updatePayment(updated);
      if (_disposed || selection != _selection) return;
      _confirmed.save(updated);
      _payments = _confirmed.merge(_payments);
      _notify();
    } catch (e) {
      _error = 'Failed to update payment.';
      _notify();
    }
  }

  Future<void> deletePayment(String uid, String paymentId) async {
    _error = null;
    try {
      final selection = _selection;
      await _fs.deletePayment(uid, paymentId);
      if (_disposed || selection != _selection) return;
      _confirmed.delete(paymentId);
      _payments = _confirmed.merge(_payments);
      _notify();
    } catch (e) {
      _error = 'Failed to delete payment.';
      _notify();
    }
  }

  List<Payment> search(String query) {
    if (query.isEmpty) return _payments;
    final q = query.toLowerCase();
    return _payments
        .where((p) => p.displayName.toLowerCase().contains(q))
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
