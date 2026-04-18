class UserProfile {
  final String uid;
  String displayName;
  String email;
  String? photoUrl;
  String currency;
  List<String> shareRecipients;
  String shareFrequency; // 'weekly' | 'monthly' | 'yearly'

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.currency = 'USD',
    this.shareRecipients = const [],
    this.shareFrequency = 'yearly',
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      currency: map['currency'] as String? ?? 'USD',
      shareRecipients: List<String>.from(map['shareRecipients'] as List? ?? []),
      shareFrequency: map['shareFrequency'] as String? ?? 'yearly',
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'currency': currency,
        'shareRecipients': shareRecipients,
        'shareFrequency': shareFrequency,
      };

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    String? currency,
    List<String>? shareRecipients,
    String? shareFrequency,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      currency: currency ?? this.currency,
      shareRecipients: shareRecipients ?? this.shareRecipients,
      shareFrequency: shareFrequency ?? this.shareFrequency,
    );
  }
}
