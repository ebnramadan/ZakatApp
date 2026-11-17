import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/services/firestore_service.dart';

void main() {
  test(
      'retry preserves identity and recipients; fresh or completed requests cannot retry or cancel',
      () async {
    final db = FakeFirebaseFirestore();
    final service = FirestoreService(database: db);
    final user = db.doc('users/u');
    final old = {
      'id': 'same-request-123456',
      'status': 'queued',
      'requestedAt': DateTime.now()
          .subtract(const Duration(minutes: 11))
          .millisecondsSinceEpoch,
      'recipients': ['trusted@example.com']
    };
    await user.set({'sheetRequest': old});
    await service.retryProgressSheet('u', 'same-request-123456');
    final retried = (await user.get()).data()!['sheetRequest'] as Map;
    expect(retried['id'], old['id']);
    expect(retried['recipients'], old['recipients']);
    expect(retried['requestedAt'], greaterThan(old['requestedAt'] as int));
    await expectLater(service.retryProgressSheet('u', 'same-request-123456'),
        throwsStateError);
    await service.cancelProgressSheet('u', 'same-request-123456');
    expect((await user.get()).data()!['sheetRequest']['status'], 'cancelled');
    await user.update({'sheetRequest.status': 'sent'});
    await expectLater(service.retryProgressSheet('u', 'same-request-123456'),
        throwsStateError);
    await expectLater(service.cancelProgressSheet('u', 'same-request-123456'),
        throwsStateError);
  });
}
