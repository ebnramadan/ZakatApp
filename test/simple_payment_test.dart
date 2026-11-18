import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/models/payment.dart';

void main() {
  test(
      'legacy manual names combine with one space and survive an edit without duplication',
      () {
    final old = Payment(
        id: 'p',
        zakatRecordId: 'r',
        userId: 'u',
        amount: 100,
        name: ' Family support ',
        recipient: ' Ahmed ',
        date: DateTime(2025),
        createdAt: DateTime(2025));
    final loaded = Payment.fromMap('p', old.toMap());
    expect(loaded.displayName, 'Family support Ahmed');
    loaded.name = loaded.displayName;
    loaded.recipient = '';
    final again = Payment.fromMap('p', loaded.toMap());
    expect(again.displayName, 'Family support Ahmed');
    expect(again.amount, 100);
    expect(again.date, old.date);
  });
  test(
      'one empty name leaves no extra space; monthly names do not duplicate recipient',
      () {
    Payment payment(String name, String recipient,
            {String source = 'manual'}) =>
        Payment(
            id: 'p',
            zakatRecordId: 'r',
            userId: 'u',
            amount: 100,
            name: name,
            recipient: recipient,
            source: source,
            date: DateTime(2025),
            createdAt: DateTime(2025));
    expect(payment('', 'Ahmed').displayName, 'Ahmed');
    expect(payment('Family', '').displayName, 'Family');
    expect(payment('Monthly Ahmed', 'Ahmed', source: 'monthly').displayName,
        'Ahmed');
  });
}
