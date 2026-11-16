import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/monthly_giving.dart';
import '../services/monthly_service.dart';

class MonthlyProvider extends ChangeNotifier {
  final MonthlyService service;
  MonthlyProvider({MonthlyService? store})
      : service = store ?? MonthlyService();
  List<MonthlyPlan> plans = [];
  List<MonthlyPayment> payments = [];
  bool loading = false;
  bool busy = false;
  bool emailReady = false;
  String? error;
  String? _uid;
  bool _disposed = false;
  bool _plansLoaded = false;
  bool _paymentsLoaded = false;
  Timer? _clock;
  String _today = DateTime.now().toIso8601String().substring(0, 10);
  int _generation = 0;
  StreamSubscription<List<MonthlyPlan>>? _plans;
  StreamSubscription<List<MonthlyPayment>>? _payments;
  StreamSubscription<bool>? _readiness;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void load(String uid, {bool force = false}) {
    if (_uid == uid && !force) return;
    _uid = uid;
    final generation = ++_generation;
    _plansLoaded = false;
    _paymentsLoaded = false;
    _clock ??= Timer.periodic(const Duration(minutes: 1), (_) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (today != _today) {
        _today = today;
        _notify();
      }
    });
    _plans?.cancel();
    _payments?.cancel();
    _readiness?.cancel();
    plans = [];
    payments = [];
    loading = true;
    error = null;
    void failed(Object e) {
      if (_disposed || generation != _generation) return;
      loading = false;
      error =
          'Monthly giving could not be loaded. Check your connection and retry.';
      _notify();
    }

    _plans = service.plans(uid).listen((data) {
      if (_disposed || generation != _generation) return;
      plans = data;
      _plansLoaded = true;
      loading = !(_plansLoaded && _paymentsLoaded);
      _notify();
    }, onError: failed);
    _payments = service.payments(uid).listen((data) {
      if (_disposed || generation != _generation) return;
      payments = data;
      _paymentsLoaded = true;
      loading = !(_plansLoaded && _paymentsLoaded);
      _notify();
    }, onError: failed);
    _readiness = service.emailReadiness().listen((ready) {
      emailReady = ready;
      _notify();
    }, onError: (Object e) {
      emailReady = false;
      _notify();
    });
  }

  List<MonthlyPayment> forMonth(String month) =>
      payments.where((p) => p.month == month).toList();
  MonthlyPayment? paid(String planId, String month) {
    final found = payments.where((p) => p.planId == planId && p.month == month);
    return found.isEmpty ? null : found.first;
  }

  int dueCount(DateTime now) => plans
      .where((p) =>
          p.dueIn(monthKey(now), now) && paid(p.id, monthKey(now)) == null)
      .length;
  Future<bool> _perform(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e) {
      error = e is FormatException
          ? e.message
          : 'Could not save this change. Your data is unchanged; please retry.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> save(MonthlyPlan plan) => _perform(() => service.savePlan(plan));
  Future<bool> markPaid(MonthlyPlan plan, String month) =>
      _perform(() => service.markPaid(plan, month));
  Future<bool> undo(MonthlyPayment payment) =>
      _perform(() => service.undoPayment(payment));
  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    _generation++;
    _plans?.cancel();
    _payments?.cancel();
    _readiness?.cancel();
    super.dispose();
  }
}
