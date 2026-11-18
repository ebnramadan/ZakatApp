import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'app_notification.dart';
import 'notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;
  NotificationProvider({NotificationService? service})
      : _service = service ?? NotificationService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  int _generation = 0;
  bool _disposed = false;
  Timer? _deadline;
  bool loading = false, loadingOlder = false, hasMore = false;
  String? error;
  List<AppNotification> _recent = [], _older = [];
  DocumentSnapshot? _cursor;
  List<AppNotification> get items {
    final merged = {
      for (final n in _older) n.id: n,
      for (final n in _recent) n.id: n
    };
    return merged.values.toList()..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  bool get hasUnread => items.any((n) => n.readAt == null);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void load(String uid, {bool force = false}) {
    if (_disposed || (_uid == uid && _sub != null && !force)) return;
    final generation = ++_generation;
    _sub?.cancel();
    _uid = uid;
    _recent = [];
    _older = [];
    _cursor = null;
    _deadline?.cancel();
    _deadline = Timer(const Duration(seconds: 10), () {
      if (_disposed || generation != _generation || !loading) return;
      loading = false;
      error = 'Notifications could not load. Please retry.';
      _notify();
    });
    loading = true;
    loadingOlder = false;
    error = null;
    hasMore = false;
    _sub = _service.recent(uid).listen((snapshot) {
      if (_disposed || generation != _generation) return;
      final nextIds = snapshot.docs.map((d) => d.id).toSet();
      if (_older.isNotEmpty || loadingOlder) {
        _older.addAll(_recent.where((n) => !nextIds.contains(n.id)));
      }
      _recent = snapshot.docs
          .map((d) => AppNotification.fromMap(d.id, d.data()))
          .toList();
      if (_older.isEmpty) {
        _cursor = snapshot.docs.isEmpty ? null : snapshot.docs.last;
        hasMore = snapshot.docs.length == 50;
      }
      _deadline?.cancel();
      loading = false;
      error = null;
      _notify();
    }, onError: (_) {
      if (_disposed || generation != _generation) return;
      _deadline?.cancel();
      loading = false;
      error = 'Notifications could not load. Please retry.';
      _notify();
    });
    _notify();
  }

  Future<void> loadOlder() async {
    if (loadingOlder || !hasMore || _cursor == null || _uid == null) return;
    final generation = _generation;
    loadingOlder = true;
    error = null;
    _notify();
    try {
      final page = await _service.older(_uid!, _cursor!);
      if (_disposed || generation != _generation) return;
      _older.addAll(
          page.docs.map((d) => AppNotification.fromMap(d.id, d.data())));
      if (page.docs.isNotEmpty) {
        _cursor = page.docs.last;
      }
      hasMore = page.docs.length == 50;
    } catch (_) {
      if (generation == _generation) {
        error = 'Notifications could not load. Please retry.';
      }
    }
    if (generation == _generation) {
      loadingOlder = false;
      _notify();
    }
  }

  Future<void> markRead(AppNotification item) async {
    if (_uid == null || item.readAt != null) return;
    final generation = _generation;
    try {
      await _service.markRead(_uid!, item.id);
      if (_disposed || generation != _generation) return;
      _recent = _recent.map((n) => n.id == item.id ? n.read() : n).toList();
      _older = _older.map((n) => n.id == item.id ? n.read() : n).toList();
      _notify();
    } catch (_) {
      /* A navigation action can still open while read status is offline. */
    }
  }

  Future<void> markIdRead(String id) async {
    if (_uid == null) return;
    try {
      await _service.markRead(_uid!, id);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _sub?.cancel();
    _deadline?.cancel();
    super.dispose();
  }
}
