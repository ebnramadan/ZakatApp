// ⚠️  PLACEHOLDER — Replace with your actual Firebase config.
//
// Run:  flutterfire configure
// in the project root after setting up your Firebase project.
// That command will overwrite this file automatically.
//
// Manual setup:
// 1. Create a Firebase project at https://console.firebase.google.com
// 2. Enable Authentication (Google, Apple, Email/Password)
// 3. Enable Firestore Database (start in production mode)
// 4. Register your Android, iOS, and Web apps
// 5. Run: dart pub global activate flutterfire_cli && flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  // ─── Replace each value below with those from your Firebase console ───────

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    authDomain: 'REPLACE_ME.firebaseapp.com',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME.appspot.com',
    iosClientId: 'REPLACE_ME',
    iosBundleId: 'com.zakatapp.app',
  );
}
