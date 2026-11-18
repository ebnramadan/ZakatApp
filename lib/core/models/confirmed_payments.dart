import 'package:flutter/foundation.dart';
import 'payment.dart';

/// Bridge confirmed writes until the independent live query catches up.
class ConfirmedPayments {
  final Map<String, Payment> _writes = {};
  final Set<String> _deletes = {};

  void save(Payment payment) {
    _deletes.remove(payment.id);
    _writes[payment.id] = payment;
  }

  void delete(String id) {
    _writes.remove(id);
    _deletes.add(id);
  }

  void clear() {
    _writes.clear();
    _deletes.clear();
  }

  List<Payment> merge(List<Payment> snapshot, {bool acknowledge = false}) {
    final values = {for (final p in snapshot) p.id: p};
    if (acknowledge) {
      _writes.removeWhere((id, payment) {
        final saved = values[id];
        if (saved == null) return false;
        // Transaction retries preserve the original creation time.
        final a = payment.toMap()..remove('createdAt');
        final b = saved.toMap()..remove('createdAt');
        return mapEquals(a, b);
      });
      _deletes.removeWhere((id) => !values.containsKey(id));
    }
    values.addAll(_writes);
    for (final id in _deletes) {
      values.remove(id);
    }
    return values.values.toList()
      ..sort((a, b) {
        final date = b.date.compareTo(a.date);
        return date != 0 ? date : b.createdAt.compareTo(a.createdAt);
      });
  }
}
