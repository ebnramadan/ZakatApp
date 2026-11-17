import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../platform/push_platform.dart' as platform;
import '../platform/device_timezone_stub.dart'
    if (dart.library.html) '../platform/device_timezone_web.dart' as clock;

class PushService {
  FirebaseFirestore get db => FirebaseFirestore.instance;
  String get support => platform.pushSupport;
  String get permission => platform.pushPermission;
  String _id(Map<String, dynamic> subscription) => sha256
      .convert(utf8.encode(subscription['endpoint'] as String))
      .toString();
  Future<Map<String, dynamic>> configuration() async =>
      (await db
              .doc('appConfig/push')
              .get()
              .timeout(const Duration(seconds: 10)))
          .data() ??
      {};
  Future<Map<String, dynamic>?> settings(String uid) async {
    final subscription = await platform.currentPushSubscription();
    if (subscription == null) return null;
    return (await db
            .doc('users/$uid/pushSubscriptions/${_id(subscription)}')
            .get()
            .timeout(const Duration(seconds: 10)))
        .data();
  }

  Future<void> enable(String uid, String publicKey,
      {required bool monthly,
      required bool zakat,
      required bool showNames}) async {
    final subscription = await platform.subscribePush(publicKey);
    final ref = db.doc('users/$uid/pushSubscriptions/${_id(subscription)}');
    try {
      final old = await ref.get().timeout(const Duration(seconds: 10));
      final now = DateTime.now().millisecondsSinceEpoch;
      await ref.set({
        'userId': uid,
        'endpoint': subscription['endpoint'],
        'keys': subscription['keys'],
        'monthly': monthly,
        'zakat': zakat,
        'showNames': showNames,
        'timeZone': clock.deviceTimeZone() ?? 'UTC',
        'createdAt': old.data()?['createdAt'] ?? now,
        'updatedAt': now
      }).timeout(const Duration(seconds: 10));
      await platform.syncPushSession(uid, preferences: {
        'enabled': true,
        'monthly': monthly,
        'zakat': zakat,
        'showNames': showNames
      });
    } catch (_) {
      await platform.syncPushSession(uid, preferences: {'enabled': false});
      rethrow;
    }
  }

  Future<void> disable(String uid) async {
    await platform.syncPushSession(uid, preferences: {'enabled': false});
    final subscription = await platform.currentPushSubscription();
    try {
      if (subscription != null) {
        await db
            .doc('users/$uid/pushSubscriptions/${_id(subscription)}')
            .delete()
            .timeout(const Duration(seconds: 3));
      }
    } finally {
      await platform.unsubscribePush().timeout(const Duration(seconds: 3));
    }
  }

  static Future<void> beforeSignOut(String? uid) async {
    if (!kIsWeb || uid == null) return;
    try {
      await PushService().disable(uid);
    } catch (_) {}
  }

  static Future<void> syncSession(String? uid) => platform.syncPushSession(uid);
  Future<void> showTest(String title, String body) =>
      platform.showPushTest(title, body);
}
