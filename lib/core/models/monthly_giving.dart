import '../constants.dart';

String monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';
DateTime monthFromKey(String value) {
  if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
    throw const FormatException('Invalid month');
  }
  return DateTime(
      int.parse(value.substring(0, 4)), int.parse(value.substring(5, 7)));
}

class MonthlyPlan {
  final String id;
  final String userId;
  final String recipient;
  final double amount;
  final String currency;
  final String kind;
  final String zakatRecordId;
  final int reminderDay;
  final String startMonth;
  final bool active;
  final DateTime createdAt;
  MonthlyPlan(
      {required this.id,
      required this.userId,
      required this.recipient,
      required this.amount,
      required this.currency,
      this.kind = 'sadaqah',
      this.zakatRecordId = '',
      this.reminderDay = 1,
      required this.startMonth,
      this.active = true,
      required this.createdAt});
  void validate() {
    if (recipient.trim().isEmpty || recipient.length > 120) {
      throw const FormatException(
          'Enter a recipient name (up to 120 characters).');
    }
    if (!amount.isFinite || amount <= 0 || amount >= 1e15) {
      throw const FormatException('Enter a positive, finite monthly amount.');
    }
    if (!kCurrencies.containsKey(currency)) {
      throw const FormatException('Choose a supported currency.');
    }
    if (!['sadaqah', 'zakat'].contains(kind)) {
      throw const FormatException('Choose Sadaqah or Zakat.');
    }
    if (kind == 'zakat' && zakatRecordId.isEmpty) {
      throw const FormatException(
          'Choose the Zakat record this payment should reduce.');
    }
    if (reminderDay < 1 || reminderDay > 31) {
      throw const FormatException('Choose a reminder day from 1 to 31.');
    }
    monthFromKey(startMonth);
  }

  DateTime dueDate(String month) {
    final m = monthFromKey(month);
    final last = DateTime(m.year, m.month + 1, 0).day;
    return DateTime(m.year, m.month, reminderDay > last ? last : reminderDay);
  }

  bool dueIn(String month, DateTime now) =>
      active &&
      month.compareTo(startMonth) >= 0 &&
      !dueDate(month).isAfter(DateTime(now.year, now.month, now.day));
  factory MonthlyPlan.fromMap(String id, Map<String, dynamic> m) => MonthlyPlan(
      id: id,
      userId: m['userId'] as String,
      recipient: m['recipient'] as String,
      amount: (m['amount'] as num).toDouble(),
      currency: m['currency'] as String,
      kind: m['kind'] as String,
      zakatRecordId: m['zakatRecordId'] as String? ?? '',
      reminderDay: m['reminderDay'] as int,
      startMonth: m['startMonth'] as String,
      active: m['active'] as bool? ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int));
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'recipient': recipient.trim(),
        'amount': amount,
        'currency': currency,
        'kind': kind,
        'zakatRecordId': kind == 'zakat' ? zakatRecordId : '',
        'reminderDay': reminderDay,
        'startMonth': startMonth,
        'active': active,
        'createdAt': createdAt.millisecondsSinceEpoch
      };
  MonthlyPlan archived() =>
      MonthlyPlan.fromMap(id, {...toMap(), 'active': false});
}

class MonthlyPayment {
  final String id;
  final String userId;
  final String planId;
  final String month;
  final String recipient;
  final double amount;
  final String currency;
  final String kind;
  final String zakatRecordId;
  final DateTime paidAt;
  final DateTime createdAt;
  MonthlyPayment(
      {required this.id,
      required this.userId,
      required this.planId,
      required this.month,
      required this.recipient,
      required this.amount,
      required this.currency,
      required this.kind,
      this.zakatRecordId = '',
      required this.paidAt,
      required this.createdAt});
  static String receiptId(String planId, String month) => '${planId}_$month';
  String get ledgerId => 'monthly_$id';
  factory MonthlyPayment.fromMap(String id, Map<String, dynamic> m) =>
      MonthlyPayment(
          id: id,
          userId: m['userId'] as String,
          planId: m['planId'] as String,
          month: m['month'] as String,
          recipient: m['recipient'] as String,
          amount: (m['amount'] as num).toDouble(),
          currency: m['currency'] as String,
          kind: m['kind'] as String,
          zakatRecordId: m['zakatRecordId'] as String? ?? '',
          paidAt: DateTime.fromMillisecondsSinceEpoch(m['paidAt'] as int),
          createdAt:
              DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int));
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'planId': planId,
        'month': month,
        'recipient': recipient,
        'amount': amount,
        'currency': currency,
        'kind': kind,
        'zakatRecordId': kind == 'zakat' ? zakatRecordId : '',
        'paidAt': paidAt.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch
      };
}
