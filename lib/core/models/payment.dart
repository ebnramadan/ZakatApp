class Payment {
  final String id;
  final String zakatRecordId;
  final String userId;
  final String source;
  final String? monthlyPaymentId;
  bool get isMonthly => source == 'monthly';
  double amount;
  String name;
  DateTime date;
  String recipient;
  DateTime createdAt;

  Payment({
    required this.id,
    required this.zakatRecordId,
    required this.userId,
    this.source = 'manual',
    this.monthlyPaymentId,
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
        source: m['source'] as String? ?? 'manual',
        monthlyPaymentId: m['monthlyPaymentId'] as String?,
        amount: (m['amount'] as num).toDouble(),
        name: m['name'] as String? ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        recipient: m['recipient'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      );

  Map<String, dynamic> toMap() => {
        'zakatRecordId': zakatRecordId,
        'userId': userId,
        'source': source,
        if (monthlyPaymentId != null) 'monthlyPaymentId': monthlyPaymentId,
        'amount': amount,
        'name': name,
        'date': date.millisecondsSinceEpoch,
        'recipient': recipient,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}
