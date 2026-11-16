# ZakatApp

Flutter app for calculating Zakat on local cash, foreign cash and gold, then recording payments made outside the app. Supports guided and single-page entry, saved drafts, immutable submitted records, and Firebase accounts.

## Calculation policy

- Nisab: 85 grams of 24K gold. Gold holdings are valued at weight × 24K price × carat / 24 (24K, 21K or 18K).
- Rate: 2.5% for a lunar year. The Hijri switch changes presentation only; it does not select a solar-year rate.
- Hawl ends on the following Hijri-year anniversary using the package's Umm al-Qura calendar, clamping a missing day 30 to the last day of that month. Local moon-sighting dates may differ.
- Before the anniversary, the result is an estimate and recorded payments are advances. At/after the anniversary, the same eligible balance is shown as due. The app assumes the entered wealth stayed eligible for the Hawl; it does not reconstruct balance history.
- Only cash and gold are supported. No debt deductions, silver-based Nisab, shares, inventory or jewelry exemptions are applied. These are explicit scope limits, not inferred religious rulings.
- Live gold: Gold API `/price/XAU`, USD per troy ounce, divided by 31.1035. Quotes older than four days are rejected, allowing market closures. FX: ExchangeRate-API open USD rates. These third-party services may be unavailable or rate-limited; verified manual entry is supported. Data is cached for 30 minutes. Historical Hawl dates do not trigger historical market quotes.
- Each record stores its base currency, prices/rates, manual override flags and a price/rate update timestamp. Changing profile currency affects new records only. Submitted records retain their original amounts and currency.

## Local setup

The checked-in Firebase options are placeholders. The app displays a setup message until configured; no real backend or credentials are supplied by this repository.

1. Install **Flutter 3.24.5 / Dart 3.5.4**, Java 17, and Android SDK 35 with Build Tools 34.0.0 and NDK 26.1.10909125. The lockfile records the tested dependency set. iOS requires macOS, Xcode and CocoaPods.
2. Run `flutter pub get`.
3. Create/select a Firebase project; enable Firestore and Email/Password, Google, and Apple authentication as needed.
4. Run `dart pub global activate flutterfire_cli`, then `flutterfire configure` for Android, iOS and web. Use application/bundle ID `com.zakatapp.app`. This replaces `lib/firebase_options.dart`; do not commit private signing material.
5. Deploy the included rules and indexes to your selected project: `firebase deploy --project YOUR_PROJECT --only firestore`.
6. For Google Android sign-in register debug/release SHA fingerprints and use the generated `google-services.json` and Google Services Gradle setup supplied by FlutterFire. For iOS add `GoogleService-Info.plist`, its reversed client ID URL scheme, and the Apple Sign In capability to the signing team. For web authorize the hosting/local development domains in Firebase Authentication.
7. Run `flutter run -d chrome` or `flutter run` with an Android/iOS device.

The restored Android project uses Gradle 8.7 / AGP 8.6.1. Release signing must be configured with your own keystore; release builds are not signed with a debug key. iOS deployment target is 13.0; signing and social login require your Apple/Firebase accounts.

## Using it

1. Sign in, then select the default currency in Profile.
2. Choose New Calculation → Guided Wizard or One-Pager. Both edit the same model and use the same calculator.
3. Enter the Hawl date, a valid Nisab gold price, and your cash/gold. Foreign entries require a valid positive conversion rate even when entered manually.
4. Save a draft to resume it from the Calculator tab. Leaving a form offers saving or leaving without the latest changes. Inputs are retained after a failed save.
5. Review and submit. Submission locks the asset snapshot. A failed/lost network response can be retried without creating another record.
6. Tracker opens the saved record. Add/edit/delete payment logs, search by payment name/recipient, and switch records. Amounts always use the record's currency. Future-dated payments are not recorded as paid.

Summary sharing is **not implemented** and is explicitly marked unavailable. Previously stored sharing preferences do not send anything. Payments are logs, not transfers. An erroneous submitted record cannot be edited: create a clearly named replacement calculation and use that replacement for subsequent tracking; old payment logs are not automatically transferred.

## Existing data and migration

Older records did not store a base currency. The UI labels these amounts “currency unknown” and prevents adding payments to those submitted records. It never guesses a currency from today's profile settings or silently converts historical amounts.

Before deploying to an existing database, back it up and explicitly verify each legacy record's original currency. A project administrator can backfill `currency` using the Firebase console/Admin SDK; client rules intentionally do not permit changing submitted snapshots. Existing draft records can be resumed and assigned their original currency in the form. Do not bulk-assign the user's current profile currency unless independently verified.

Stored `zakatDue` is the calculation at submission time. Tracker derives the current estimate/due display from the immutable eligible total and lunar anniversary, so an advance estimate can mature without rewriting a locked record.

## Verification

```sh
flutter pub get
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
```

The Firebase rules tests use a local demo project, never production:

```sh
# Node 22 and Java 17+
npm ci
npm run test:rules
```

Tests cover Nisab boundaries, purity and FX calculations, lunar anniversary, invalid prices, currency preservation, price request races, failed/idempotent submission, draft resumption, payment selection, profile sign-out, both form modes, record locking, account ownership and payment validation. CI repeats analysis, tests, web and Android debug builds, and the Firestore emulator checks. Live Firebase auth and iOS signing still require project/device verification.

Firestore rules enforce ownership, submission immutability, bounded numeric fields and payment linkage. The financial calculation runs on the client for personal records; the rules are not a server-side audit of every nested asset or the user's religious eligibility.
