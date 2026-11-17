# Monthly giving (شهريات) and verified accounts

## Account access

Google is the primary sign-in/sign-up choice. Email registration is an explicit alternative and sends Firebase's standard verification link. The auth gate and database rules both require a verified email before financial access. Existing email/password users keep their UID and records but must verify if they have not already done so.

Profile → Account security supports:

- Adding a password to the existing verified Google email after fresh Google reauthentication.
- Connecting Google to an existing verified password account after confirming its password, followed by a separate Google-popup gesture (including Safari).
- Resetting the password by email.

Linking preserves the Firebase UID and record paths. An identity that already belongs to a separate Firebase account is not silently merged, deleted, or allowed to overwrite financial data. Such a collision gets a clear message; migrating two independent financial histories requires a separate explicit migration.

## Monthly commitments versus actual payments

A recipient plan contains a name, monthly amount, currency, reminder day, start month, classification and optional Zakat record. New recipients use the profile default of Sadaqah or Zakat. Individual plans can override it.

A commitment is not a transfer or a paid amount. When the user confirms a payment, a snapshot is saved under `users/{uid}/monthlyPayments/{planId}_{YYYY-MM}`. This deterministic ID makes repeat clicks/retries safe.

- Sadaqah creates only a monthly receipt. It never changes Zakat totals.
- Zakat requires a submitted record in the same currency. The monthly receipt and `payments/monthly_{receiptId}` ledger entry are written atomically.
- Tracker shows those entries as managed in شهريات. Its edit/delete controls are disabled for them. The database rules require both financial views to agree.
- Undo removes the monthly receipt and its Zakat entry together.
- Editing or pausing a plan never rewrites paid history. Pausing stops upcoming commitments/reminders; historical paid months remain visible.
- Future months can be reviewed but cannot be marked paid. Amounts in different currencies are shown separately.
- Reminder day 29, 30 or 31 is clamped to the last valid day in shorter months.

There is no automatic exchange conversion between monthly commitments and Zakat records.

## Email reminders

The daily GitHub Actions job checks at approximately 08:00 UTC. Scheduled Actions can be delayed; this is not a precise alarm service. In-app due reminders remain available independently.

Email reminders are opt-in in شهريات → Settings or Profile → Monthly giving preferences. They are sent only to the account's current verified Firebase Auth email, not an editable address from a profile document. Disabled/unverified accounts are skipped.

The job combines currently due, unpaid, not-yet-reminded plans into one digest for the user. Paid plans and already-sent plan/month pairs are skipped. It records accepted sends in server-only `reminderDeliveries`. Resend also receives an idempotency key; Gmail receives a stable Message-ID. A network failure between external acceptance and recording delivery can still require reconciliation; external email delivery is not a database transaction.

Messages include recipient names, amounts, currencies and classification; the opt-in UI discloses this. They never record a payment automatically. Turning reminders off excludes the account from later runs.

### Sender option A: Gmail (no purchased sending domain)

Prefer a dedicated Gmail sender account. Enable Google 2-Step Verification, then create an app password at https://myaccount.google.com/apppasswords. If the account's policy does not offer app passwords, use an approved sending service instead; do not weaken its security policy.

Add these repository secrets at https://github.com/ebnramadan/ZakatApp/settings/secrets/actions:

- `REMINDER_SMTP_USER`: the dedicated Gmail address.
- `REMINDER_SMTP_APP_PASSWORD`: its Google app password, not the normal account password.

Gmail transport uses TLS and verifies the SMTP connection before sending. Gmail's sending limits still apply.

### Sender option B: Resend

Add `RESEND_API_KEY` and `REMINDER_FROM` (a bare sender address on a verified Resend sending domain). Resend's shared onboarding sender is not suitable for unrestricted production recipients. Configure only the intended sender; if both methods are configured, Gmail takes precedence.

Never put keys or passwords in chat, workflow YAML, issues, or source control. Only GitHub Actions receives the secrets.

### Required Google permissions

The existing deployment service account needs:

- Firebase Hosting Admin and Service Usage Consumer (existing Hosting deployment).
- Firebase Rules Admin (deploy the new verification/monthly rules before the new web app).
- Cloud Datastore User (read opted-in plans/payments and record delivery receipts).
- Firebase Authentication Viewer (check current verified recipient identities and authorized domains).

These do not require granting Owner or Editor. The preflight checks permissions without logging account addresses or financial data.

## Local browser testing without production data

```sh
npm ci
npx firebase emulators:start --project demo-zakat-app --only auth,firestore
flutter run -d web-server --web-port 8765 --dart-define=USE_FIREBASE_EMULATORS=true
```

The emulator flag is accepted only in debug builds. It uses `demo-zakat-app`, not the live project. Browser QA can register disposable accounts, inspect local OOB verification links, and test record/receipt/ledger integration without sending real email or creating live financial data.

## Installation and URLs

The installed app is named **Zakat Tracker**. The manifest has standalone display, branded normal/maskable icons, and an opaque 180×180 Apple touch icon. The free `ztracker.web.app` Hosting site is reserved in the original Firebase project; `zakat-app-36c58.web.app` remains available.

Before using the new URL, add `ztracker.web.app` and `ztracker.firebaseapp.com` under Firebase Authentication → Settings → Authorized domains. Deployment checks this rather than publishing a broken Google-login URL.

On iOS use Share → Add to Home Screen. Existing saved shortcuts may need to be removed and added again to pick up the new icon/name cached by iOS.
