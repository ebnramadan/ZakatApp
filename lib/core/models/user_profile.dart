class UserProfile {
  final String uid;
  String displayName,
      email,
      currency,
      language,
      monthlyDefaultKind,
      defaultRecordId;
  String? photoUrl;
  List<String> shareRecipients;
  bool monthlyEmailReminders, sharingEnabled, onboardingCompleted;
  int shareDay;
  bool resetInProgress;
  String get monthlyGivingLabel =>
      language == 'ar' ? 'شهريات' : 'Monthly Giving';
  UserProfile(
      {required this.uid,
      required this.displayName,
      required this.email,
      this.photoUrl,
      this.currency = 'USD',
      this.language = 'en',
      this.monthlyDefaultKind = 'sadaqah',
      this.monthlyEmailReminders = false,
      this.defaultRecordId = '',
      this.shareRecipients = const [],
      this.sharingEnabled = false,
      this.shareDay = 1,
      this.resetInProgress = false,
      this.onboardingCompleted = false});
  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) =>
      UserProfile(
          uid: uid,
          displayName: map['displayName'] as String? ?? '',
          email: map['email'] as String? ?? '',
          photoUrl: map['photoUrl'] as String?,
          currency: map['currency'] as String? ?? 'USD',
          language: map['language'] == 'ar' ? 'ar' : 'en',
          monthlyDefaultKind:
              map['monthlyDefaultKind'] == 'zakat' ? 'zakat' : 'sadaqah',
          monthlyEmailReminders: map['monthlyEmailReminders'] == true,
          defaultRecordId: map['defaultRecordId'] as String? ?? '',
          shareRecipients:
              List<String>.from(map['shareRecipients'] as List? ?? []),
          sharingEnabled: map['sharingEnabled'] == true,
          shareDay: map['shareDay'] as int? ?? 1,
          resetInProgress: map['resetInProgress'] == true,
          onboardingCompleted: map['onboardingCompleted'] != false);
  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'photoUrl': photoUrl,
        'currency': currency,
        'language': language,
        'monthlyDefaultKind': monthlyDefaultKind,
        'monthlyEmailReminders': monthlyEmailReminders,
        'defaultRecordId': defaultRecordId,
        'shareRecipients': shareRecipients,
        'sharingEnabled': sharingEnabled,
        'shareDay': shareDay,
        'resetInProgress': resetInProgress,
        'onboardingCompleted': onboardingCompleted
      };
  UserProfile copyWith(
          {String? displayName,
          String? email,
          String? photoUrl,
          String? currency,
          String? language,
          String? monthlyDefaultKind,
          bool? monthlyEmailReminders,
          String? defaultRecordId,
          List<String>? shareRecipients,
          bool? sharingEnabled,
          int? shareDay,
          bool? onboardingCompleted}) =>
      UserProfile.fromMap(uid, {
        ...toMap(),
        if (displayName != null) 'displayName': displayName,
        if (email != null) 'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (currency != null) 'currency': currency,
        if (language != null) 'language': language,
        if (monthlyDefaultKind != null)
          'monthlyDefaultKind': monthlyDefaultKind,
        if (monthlyEmailReminders != null)
          'monthlyEmailReminders': monthlyEmailReminders,
        if (defaultRecordId != null) 'defaultRecordId': defaultRecordId,
        if (shareRecipients != null) 'shareRecipients': shareRecipients,
        if (sharingEnabled != null) 'sharingEnabled': sharingEnabled,
        if (shareDay != null) 'shareDay': shareDay,
        if (onboardingCompleted != null)
          'onboardingCompleted': onboardingCompleted
      });
}
