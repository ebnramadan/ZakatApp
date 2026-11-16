import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
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
    if (changedAccount || user == null || !user.emailVerified) _profile = null;
    _isLoading = _profile == null && user != null && user.emailVerified;
    _notify();
    try {
      if (user != null && user.emailVerified) {
        final profile = await _loadOrCreateProfile(user);
        if (_disposed || generation != _generation) return;
        _profile = profile;
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
      await _auth.signOut();
    } catch (_) {
      _error = 'Sign out failed. Retry.';
      _notify();
    }
  }

  Future<bool> updateProfile(UserProfile updated) async {
    _error = null;
    try {
      await _fs.saveProfile(updated);
      if (_disposed || _user?.uid != updated.uid) return false;
      _profile = updated;
      _notify();
      return true;
    } catch (_) {
      _error = 'Profile could not be saved. Retry.';
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
