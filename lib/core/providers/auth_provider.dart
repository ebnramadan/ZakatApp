import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../platform/device_currency.dart';
import '../services/push_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth;
  final FirestoreService _fs;

  StreamSubscription<User?>? _subscription;
  bool _disposed = false;
  int _generation = 0;
  User? _user;
  UserProfile? _profile;
  bool _isLoading = true;
  bool _busy = false;
  bool _resetting = false;
  int dataRevision = 0;
  String _deviceLanguage = 'en';
  String get language => _profile?.language ?? _deviceLanguage;
  Future<void> _loadDeviceLanguage() async {
    try {
      final p = await SharedPreferences.getInstance();
      _deviceLanguage = p.getString('language') == 'ar' ? 'ar' : 'en';
      await _auth.setLanguage(_deviceLanguage);
      _notify();
    } catch (_) {}
  }

  Future<void> _saveDeviceLanguage(String value) async {
    _deviceLanguage = value;
    try {
      await _auth.setLanguage(value);
      final p = await SharedPreferences.getInstance();
      await p.setString('language', value);
    } catch (_) {}
  }

  bool get canResetAccount =>
      isVerified && _user?.email == 'ebnramadan@gmail.com';
  String? _error;
  DateTime? _verificationSentAt;
  DateTime? _passwordConfirmedAt;
  String? _passwordConfirmedUid;
  bool get hasRecentPasswordProof =>
      _passwordConfirmedUid == _user?.uid &&
      _passwordConfirmedAt != null &&
      DateTime.now().difference(_passwordConfirmedAt!) <
          const Duration(minutes: 2);
  bool get isVerified => _user?.emailVerified ?? false;
  bool get hasGoogle =>
      _user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
  bool get hasPassword =>
      _user?.providerData.any((p) => p.providerId == 'password') ?? false;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get busy => _busy;
  String? get error => _error;

  AuthProvider({AuthService? auth, FirestoreService? store})
      : _auth = auth ?? AuthService(),
        _fs = store ?? FirestoreService() {
    _loadDeviceLanguage();
    _subscription =
        _auth.authStateChanges.listen(_onAuthStateChanged, onError: (Object e) {
      _error = 'Authentication connection failed. Retry signing in.';
      _isLoading = false;
      _notify();
    });
  }

  Future<void> _onAuthStateChanged(User? user) async {
    final generation = ++_generation;
    final changedAccount = _user?.uid != user?.uid;
    _user = user;
    PushService.syncSession(user?.emailVerified == true ? user?.uid : null);
    if (_resetting && !changedAccount) return;
    if (changedAccount || user == null || !user.emailVerified) _profile = null;
    _isLoading = _profile == null && user != null && user.emailVerified;
    _notify();
    try {
      if (user != null && user.emailVerified) {
        final profile = await _loadOrCreateProfile(user);
        if (_disposed || generation != _generation) return;
        _profile = profile;
        _saveDeviceLanguage(profile.language);
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _error = 'Could not load your profile. Check your connection and retry.';
    }
    if (_disposed || generation != _generation) return;
    _isLoading = false;
    _notify();
  }

  Future<void> retryProfile() => _onAuthStateChanged(_auth.currentUser);

  Future<UserProfile> _loadOrCreateProfile(User user) async {
    var profile = await _fs.getProfile(user.uid);
    if (profile == null) {
      profile = UserProfile(
        uid: user.uid,
        displayName: user.displayName ?? user.email?.split('@').first ?? 'User',
        email: user.email ?? '',
        language: _deviceLanguage,
        currency: suggestedDeviceCurrency(),
        photoUrl: user.photoURL,
      );
      await _fs.saveProfile(profile);
    }
    if (profile.email != (user.email ?? '')) {
      profile = profile.copyWith(email: user.email ?? '');
      await _fs.saveProfile(profile);
    }
    return profile;
  }

  Future<void> signInWithGoogle() => _wrap(_auth.signInWithGoogle);
  Future<void> signInWithApple() => _wrap(_auth.signInWithApple);

  Future<void> signInWithEmail(String email, String password) =>
      _wrap(() => _auth.signInWithEmail(email, password));

  Future<void> registerWithEmail(String email, String password) =>
      _wrap(() async {
        await _auth.registerWithEmail(email, password);
        _verificationSentAt = DateTime.now();
      });

  Future<bool> sendVerification() async {
    if (_verificationSentAt != null &&
        DateTime.now().difference(_verificationSentAt!) <
            const Duration(seconds: 60)) {
      _error =
          'Please wait a minute before requesting another verification email.';
      _notify();
      return false;
    }
    return _wrap(() async {
      await _auth.sendVerification();
      _verificationSentAt = DateTime.now();
    });
  }

  Future<bool> checkVerification() => _wrap(() async {
        await _auth.refreshUser();
        await _onAuthStateChanged(_auth.currentUser);
        if (!isVerified) {
          throw StateError(
              'Your email is not verified yet. Open the link in your inbox, then check again.');
        }
      });

  Future<bool> linkGoogle(String password) =>
      _wrap(() => _auth.linkGoogle(password: password));
  Future<bool> confirmPassword(String password) => _wrap(() async {
        await _auth.reauthenticate(password: password);
        _passwordConfirmedUid = _user!.uid;
        _passwordConfirmedAt = DateTime.now();
      });

  Future<bool> connectGoogle() {
    if (!hasRecentPasswordProof) {
      _error =
          'Please confirm your current password again before connecting Google.';
      _notify();
      return Future.value(false);
    }
    return _wrap(() async {
      await _auth.linkGoogleAfterConfirmation();
      _passwordConfirmedAt = null;
    });
  }

  Future<bool> addPassword(String password) =>
      _wrap(() => _auth.addPassword(password));

  Future<bool> sendPasswordReset(String email) async {
    try {
      _error = null;
      await _auth.sendPasswordReset(email);
      return true;
    } catch (e) {
      _error = e.toString();
      _notify();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await PushService.beforeSignOut(_user?.uid);
      await _auth.signOut();
    } catch (_) {
      _error = 'Sign out failed. Retry.';
      _notify();
    }
  }

  int _preferenceRevision = 0;
  final Map<String, int> _fieldRevision = {};
  Future<bool> resetAppData({String? password}) => _wrap(() async {
        if (!canResetAccount) {
          throw StateError('Reset is unavailable for this account.');
        }
        final user = _user!;
        _resetting = true;
        try {
          await _auth.reauthenticate(password: password);
          await _auth.refreshUser();
          final fresh = UserProfile(
              uid: user.uid,
              currency: suggestedDeviceCurrency(),
              displayName: user.displayName ?? user.email!.split('@').first,
              email: user.email!,
              photoUrl: user.photoURL);
          await PushService.beforeSignOut(user.uid);
          await _fs.resetAppData(fresh);
          _profile = fresh;
          dataRevision++;
        } catch (_) {
          _profile = await _fs.getProfile(user.uid);
          rethrow;
        } finally {
          _resetting = false;
        }
      });

  Stream<Map<String, dynamic>?> get sheetRequestStream =>
      _user == null ? const Stream.empty() : _fs.sheetRequestStream(_user!.uid);
  Future<bool> sendProgressSheetNow() async {
    if (_user == null ||
        !isVerified ||
        _profile == null ||
        _profile!.shareRecipients.isEmpty) return false;
    try {
      await _fs.requestProgressSheet(
          _user!.uid, const Uuid().v4(), _profile!.shareRecipients);
      return true;
    } catch (_) {
      _error =
          'Could not queue the sheet. Check your recipients, connection, and try again in one minute.';
      _notify();
      return false;
    }
  }

  Future<bool> retryProgressSheet(String id) async {
    if (_user == null || !isVerified) return false;
    try {
      await _fs.retryProgressSheet(_user!.uid, id);
      return true;
    } catch (_) {
      _error = 'Could not retry. Check your saved recipients and try again.';
      _notify();
      return false;
    }
  }

  Future<bool> cancelProgressSheet(String id) async {
    if (_user == null || !isVerified) return false;
    try {
      await _fs.cancelProgressSheet(_user!.uid, id);
      return true;
    } catch (_) {
      _error = 'The request changed. Refresh its status and try again.';
      _notify();
      return false;
    }
  }

  Future<bool> updateProfileFields(
      {String? displayName,
      String? currency,
      String? language,
      String? defaultRecordId,
      bool? onboardingCompleted,
      bool? sharingEnabled,
      List<String>? shareRecipients,
      int? shareDay,
      String? monthlyDefaultKind,
      bool? monthlyEmailReminders}) async {
    final current = _profile;
    if (current == null) return false;
    final fields = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (currency != null) 'currency': currency,
      if (language != null) 'language': language,
      if (defaultRecordId != null) 'defaultRecordId': defaultRecordId,
      if (onboardingCompleted != null)
        'onboardingCompleted': onboardingCompleted,
      if (sharingEnabled != null) 'sharingEnabled': sharingEnabled,
      if (shareRecipients != null) 'shareRecipients': shareRecipients,
      if (shareDay != null) 'shareDay': shareDay,
      if (monthlyDefaultKind != null) 'monthlyDefaultKind': monthlyDefaultKind,
      if (monthlyEmailReminders != null)
        'monthlyEmailReminders': monthlyEmailReminders,
    };
    if (language != null) _deviceLanguage = language;
    final revision = ++_preferenceRevision;
    for (final field in fields.keys) {
      _fieldRevision[field] = revision;
    }
    _profile =
        UserProfile.fromMap(current.uid, {...current.toMap(), ...fields});
    _error = null;
    _notify();
    try {
      await _fs.updateProfileFields(current.uid, fields);
      if (language != null) _saveDeviceLanguage(language);
      return !_disposed && _user?.uid == current.uid;
    } catch (_) {
      if (_disposed || _user?.uid != current.uid) return false;
      if (language != null) _deviceLanguage = current.language;
      final rollback = _profile!.toMap();
      for (final field in fields.keys) {
        if (_fieldRevision[field] == revision) {
          rollback[field] = current.toMap()[field];
        }
      }
      _profile = UserProfile.fromMap(current.uid, rollback);
      _error = 'This setting could not be saved. Please retry.';
      _notify();
      return false;
    }
  }

  Future<bool> _wrap(Future<dynamic> Function() fn) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    _notify();
    try {
      await fn();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _humanize(e.code);
      _notify();
      return false;
    } catch (e) {
      _error = e.toString().replaceFirst('Bad state: ', '');
      _notify();
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  String _humanize(String code) {
    const map = {
      'credential-already-in-use':
          'This Google account already belongs to a separate app account. Sign in to that account to review its data; it cannot be linked here without a secure data migration.',
      'account-exists-with-different-credential':
          'Sign in with your existing method first, then connect Google in Profile → Account security.',
      'provider-already-linked': 'This sign-in method is already connected.',
      'user-mismatch':
          'Choose the Google account already connected to this profile to confirm ownership.',
      'popup-closed-by-user':
          'The Google window was closed. Try again when ready.',
      'popup-blocked': 'Allow pop-ups for this site to continue with Google.',
      'invalid-credential':
          'The email or password is incorrect. Try again or reset your password.',
      'requires-recent-login':
          'For your security, sign in again before changing sign-in methods.',
      'user-not-found': 'No account found with this email.',
      'wrong-password': 'Incorrect password.',
      'email-already-in-use': 'An account already exists with this email.',
      'invalid-email': 'Please enter a valid email address.',
      'weak-password': 'Password must be at least 6 characters.',
      'too-many-requests': 'Too many attempts. Please try again later.',
      'network-request-failed': 'Network error. Check your connection.',
    };
    return map[code] ?? 'Authentication failed. Please try again.';
  }

  void clearError() {
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _subscription?.cancel();
    super.dispose();
  }
}
