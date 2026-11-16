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
    _user = user;
    _profile = null;
    _isLoading = true;
    _notify();
    try {
      if (user != null) {
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
    return profile;
  }

  Future<void> signInWithGoogle() => _wrap(_auth.signInWithGoogle);
  Future<void> signInWithApple() => _wrap(_auth.signInWithApple);

  Future<void> signInWithEmail(String email, String password) =>
      _wrap(() => _auth.signInWithEmail(email, password));

  Future<void> registerWithEmail(String email, String password) =>
      _wrap(() => _auth.registerWithEmail(email, password));

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

  Future<void> _wrap(Future<dynamic> Function() fn) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _notify();
    try {
      await fn();
    } on FirebaseAuthException catch (e) {
      _error = _humanize(e.code);
      _notify();
    } catch (e) {
      _error = e.toString();
      _notify();
    } finally {
      _busy = false;
      _notify();
    }
  }

  String _humanize(String code) {
    const map = {
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
