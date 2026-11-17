class UserProfile {
  final String uid;
  String displayName;
  String email;
  String? photoUrl;
  String currency;
  String language;
  String get monthlyGivingLabel =>
      language == 'ar' ? 'شهريات' : 'Monthly Giving';
  List<String> shareRecipients;
  String monthlyDefaultKind;
  bool monthlyEmailReminders;
  String shareFrequency; // 'weekly' | 'monthly' | 'yearly'

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.currency = 'USD',
    this.language = 'en',
    this.monthlyDefaultKind = 'sadaqah',
    this.monthlyEmailReminders = false,
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
      language: map['language'] == 'ar' ? 'ar' : 'en',
      monthlyDefaultKind:
          map['monthlyDefaultKind'] == 'zakat' ? 'zakat' : 'sadaqah',
      monthlyEmailReminders: map['monthlyEmailReminders'] == true,
      shareRecipients: List<String>.from(map['shareRecipients'] as List? ?? []),
      shareFrequency: map['shareFrequency'] as String? ?? 'yearly',
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'currency': currency,
        'language': language,
        'monthlyDefaultKind': monthlyDefaultKind,
        'monthlyEmailReminders': monthlyEmailReminders,
        'shareRecipients': shareRecipients,
        'shareFrequency': shareFrequency,
      };

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? monthlyDefaultKind,
    bool? monthlyEmailReminders,
    String? photoUrl,
    String? currency,
    String? language,
    List<String>? shareRecipients,
    String? shareFrequency,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      currency: currency ?? this.currency,
      language: language ?? this.language,
      monthlyDefaultKind: monthlyDefaultKind ?? this.monthlyDefaultKind,
      monthlyEmailReminders:
          monthlyEmailReminders ?? this.monthlyEmailReminders,
      shareRecipients: shareRecipients ?? this.shareRecipients,
      shareFrequency: shareFrequency ?? this.shareFrequency,
    );
  }
}
