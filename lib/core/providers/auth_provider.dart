import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final _auth = AuthService();
  final _fs = FirestoreService();

  User? _user;
  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _auth.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      await _loadOrCreateProfile(user);
    } else {
      _profile = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadOrCreateProfile(User user) async {
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
    _profile = profile;
  }

  Future<void> signInWithGoogle() => _wrap(_auth.signInWithGoogle);
  Future<void> signInWithApple() => _wrap(_auth.signInWithApple);

  Future<void> signInWithEmail(String email, String password) =>
      _wrap(() => _auth.signInWithEmail(email, password));

  Future<void> registerWithEmail(String email, String password) =>
      _wrap(() => _auth.registerWithEmail(email, password));

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordReset(email);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _profile = null;
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile updated) async {
    await _fs.saveProfile(updated);
    _profile = updated;
    notifyListeners();
  }

  Future<void> _wrap(Future<dynamic> Function() fn) async {
    _error = null;
    try {
      await fn();
    } on FirebaseAuthException catch (e) {
      _error = _humanize(e.code);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
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
    notifyListeners();
  }
}
