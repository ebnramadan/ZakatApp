import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth;
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      return _auth.signInWithPopup(GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'}));
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256(rawNonce);
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    return _auth.signInWithCredential(oauthCredential);
  }

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> registerWithEmail(
      String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await credential.user!.sendEmailVerification();
    return credential;
  }

  Future<void> sendVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in first.');
    if (!user.emailVerified) await user.sendEmailVerification();
  }

  Future<void> refreshUser() async {
    await _auth.currentUser?.reload();
    await _auth.currentUser?.getIdToken(true);
  }

  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError('Verify your email before changing sign-in methods.');
    }
    if (user.providerData.any((p) => p.providerId == 'password')) {
      if (password == null || password.isEmpty) {
        throw StateError('Enter your current password to confirm ownership.');
      }
      await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password));
    } else if (user.providerData.any((p) => p.providerId == 'google.com')) {
      await user.reauthenticateWithPopup(GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'}));
    } else {
      throw StateError(
          'Sign in again with your original provider before changing account security.');
    }
  }

  Future<void> linkGoogle({required String password}) async {
    await reauthenticate(password: password);
    await _auth.currentUser!.linkWithPopup(GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'}));
    await refreshUser();
  }

  Future<void> linkGoogleAfterConfirmation() async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError('Verify your account before connecting Google.');
    }
    await user.linkWithPopup(GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'}));
    await refreshUser();
  }

  Future<void> addPassword(String password) async {
    if (password.length < 10) {
      throw StateError('Use at least 10 characters for your password.');
    }
    await reauthenticate();
    final user = _auth.currentUser!;
    await user.linkWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password));
    await refreshUser();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {/* Firebase session is already closed. */}
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
