import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakat_app/core/providers/auth_provider.dart';
import 'package:zakat_app/core/services/auth_service.dart';
import 'package:zakat_app/core/services/firestore_service.dart';

class TestProviderInfo extends fb.UserInfo {
  TestProviderInfo(String provider)
      : super.fromJson({
          'providerId': provider,
          'uid': 'identity',
          'email': 'owner@example.com',
          'isAnonymous': false,
          'isEmailVerified': true
        });
}

// Firebase Auth test doubles intentionally record mutable call state.
// ignore: must_be_immutable
class SecurityUser extends MockUser {
  final List<String> events = [];
  bool rejectReauth = false;
  SecurityUser(String provider, {bool verified = true})
      : super(
            uid: 'same-user',
            email: 'owner@example.com',
            isEmailVerified: verified,
            providerData: [TestProviderInfo(provider)]);
  @override
  Future<fb.UserCredential> reauthenticateWithCredential(
      fb.AuthCredential? credential) {
    events.add('reauth-password');
    if (rejectReauth) throw fb.FirebaseAuthException(code: 'wrong-password');
    return super.reauthenticateWithCredential(credential);
  }

  @override
  Future<fb.UserCredential> reauthenticateWithPopup(fb.AuthProvider provider) {
    events.add('reauth-google');
    if (rejectReauth) throw fb.FirebaseAuthException(code: 'user-mismatch');
    return super.reauthenticateWithCredential(
        fb.GoogleAuthProvider.credential(idToken: 'test'));
  }

  @override
  Future<fb.UserCredential> linkWithPopup(fb.AuthProvider provider) {
    events.add('link-google');
    return super.linkWithProvider(provider);
  }

  @override
  Future<fb.UserCredential> linkWithCredential(fb.AuthCredential credential) {
    events.add('link-password');
    return super.linkWithCredential(credential);
  }
}

void main() {
  test('unverified email accounts cannot load or create a financial profile',
      () async {
    final db = FakeFirebaseFirestore();
    final firebase = MockFirebaseAuth(
        mockUser: SecurityUser('password', verified: false), signedIn: true);
    final auth = AuthProvider(
        auth: AuthService(auth: firebase),
        store: FirestoreService(database: db));
    await Future<void>.delayed(Duration.zero);
    expect(auth.user, isNotNull);
    expect(auth.isVerified, isFalse);
    expect(auth.profile, isNull);
    expect((await db.collection('users').get()).docs, isEmpty);
    auth.dispose();
  });
  test('linking Google requires password ownership first and keeps the UID',
      () async {
    final user = SecurityUser('password');
    final firebase = MockFirebaseAuth(mockUser: user, signedIn: true);
    await AuthService(auth: firebase).linkGoogle(password: 'current-password');
    expect(user.events, ['reauth-password', 'link-google']);
    expect(firebase.currentUser!.uid, 'same-user');
  });
  test('failed reauthentication never attempts a Google link', () async {
    final user = SecurityUser('password')..rejectReauth = true;
    final service =
        AuthService(auth: MockFirebaseAuth(mockUser: user, signedIn: true));
    await expectLater(service.linkGoogle(password: 'incorrect'),
        throwsA(isA<fb.FirebaseAuthException>()));
    expect(user.events, ['reauth-password']);
  });
  test('adding a password requires Google ownership first and keeps the UID',
      () async {
    final user = SecurityUser('google.com');
    final firebase = MockFirebaseAuth(mockUser: user, signedIn: true);
    await AuthService(auth: firebase).addPassword('long-secure-passphrase');
    expect(user.events, ['reauth-google', 'link-password']);
    expect(firebase.currentUser!.uid, 'same-user');
  });
  test('unverified identities cannot change sign-in methods', () async {
    final user = SecurityUser('password', verified: false);
    final service =
        AuthService(auth: MockFirebaseAuth(mockUser: user, signedIn: true));
    await expectLater(
        service.linkGoogle(password: 'correct'), throwsStateError);
    expect(user.events, isEmpty);
  });
  test(
      'Google popup linking needs a recent password confirmation in the provider',
      () async {
    final user = SecurityUser('password');
    final auth = AuthProvider(
        auth:
            AuthService(auth: MockFirebaseAuth(mockUser: user, signedIn: true)),
        store: FirestoreService(database: FakeFirebaseFirestore()));
    await Future<void>.delayed(Duration.zero);
    expect(await auth.connectGoogle(), isFalse);
    expect(user.events, isEmpty);
    expect(await auth.confirmPassword('current-password'), isTrue);
    expect(await auth.connectGoogle(), isTrue);
    expect(user.events, ['reauth-password', 'link-google']);
    expect(auth.user!.uid, 'same-user');
    auth.dispose();
  });
  test('saving two settings together does not overwrite another preference',
      () async {
    final db = FakeFirebaseFirestore();
    final auth = AuthProvider(
        auth: AuthService(
            auth: MockFirebaseAuth(
                mockUser: SecurityUser('password'), signedIn: true)),
        store: FirestoreService(database: db));
    await Future<void>.delayed(Duration.zero);
    final results = await Future.wait([
      auth.updateProfileFields(monthlyDefaultKind: 'zakat'),
      auth.updateProfileFields(monthlyEmailReminders: true)
    ]);
    expect(results, [true, true]);
    final saved = (await db.doc('users/same-user').get()).data()!;
    expect(saved['monthlyDefaultKind'], 'zakat');
    expect(saved['monthlyEmailReminders'], isTrue);
    auth.dispose();
  });
}
