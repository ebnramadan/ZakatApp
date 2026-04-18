class Payment {
  final String id;
  final String zakatRecordId;
  final String userId;
  double amount;
  String name;
  DateTime date;
  String recipient;
  DateTime createdAt;

  Payment({
    required this.id,
    required this.zakatRecordId,
    required this.userId,
    required this.amount,
    required this.name,
    required this.date,
    this.recipient = '',
    required this.createdAt,
  });

  factory Payment.fromMap(String id, Map<String, dynamic> m) => Payment(
        id: id,
        zakatRecordId: m['zakatRecordId'] as String,
        userId: m['userId'] as String,
        amount: (m['amount'] as num).toDouble(),
        name: m['name'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        recipient: m['recipient'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );

  Map<String, dynamic> toMap() => {
        'zakatRecordId': zakatRecordId,
        'userId': userId,
        'amount': amount,
        'name': name,
        'date': date.millisecondsSinceEpoch,
        'recipient': recipient,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}
