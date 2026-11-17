# Web push giving reminders (Firebase Spark)

Web Push uses a dedicated `/push-worker.js` registered under `/push-scope/`, separate from Flutter’s asset-cache worker. It works without Firebase Functions, Blaze, SMTP, or a new paid service. VAPID keys are generated once by the trusted GitHub worker: the private key stays in server-only `_system/webPushKeys`; only the public key is published at `appConfig/push`. Never print the private key or subscription endpoints in logs.

Profile offers opt-in per device, separate monthly/Zakat preferences, optional recipient names (off by default), a local test notification, and an off button. Names can appear on the lock screen when opted in; amounts never appear. On iOS 16.4+ the site must be added to the Home Screen and opened from that icon before enabling notifications. Permission is requested only from the user’s tap.

## Frequency and eligibility

`.github/workflows/push-reminders.yml` checks hourly at minute 17. One combined digest is allowed per device every four days, during 09:00–20:00 in its saved timezone (at most two per rolling week). Checks may run late on GitHub; there is no exact-minute guarantee. Monthly reminders include only active, started, unpaid commitments whose reminder day has arrived, clamped to month-end. Linked Zakat records must be submitted, active and in the same currency.

Zakat uses the selected default record (or the same submitted/newest fallback as the app), actual linked payments and the next Umm al-Qura lunar-year anniversary. Below-Nisab, draft, fully paid and recycled records do not produce Zakat reminders. The week before Hawl completion uses preparation wording; due records use respectful giving-for-Allah wording. No reminder marks anything paid or transfers money.

## Lifecycle and privacy

Verified accounts own private `pushSubscriptions` documents. Subscription URLs are restricted to recognized HTTPS push-provider hosts to prevent server-side requests to arbitrary endpoints. Delivery leases and accepted timestamps are server-controlled and suppress concurrent runs. Expired endpoints (404/410) are removed. Reset clears subscriptions/receipts and unsubscribes this browser. Sign-out disables the service worker before unsubscribing; the worker also checks the last authenticated UID and local opt-in state, so queued messages for a previous account cannot show its names after an account switch.

Notification clicks open `/?open=monthly` or `/?open=tracker`. A dedicated worker scope prevents asset-cache replacement. The worker stores only session/preferences in its IndexedDB; financial records remain in private Firestore collections.

## Deployment and scheduler verification

Merging the worker triggers a dry run that provisions keys using the existing Firestore service account. Manual workflow runs default to dry-run. Only a genuine `schedule` event writes `appConfig/push.scheduledAt`; manual checks never claim automatic scheduling is operational. The profile shows unconfirmed scheduling when no recent genuine run exists. This matters because this repository previously had no observed schedule events; the owner has now changed the default branch to `main`, and genuine scheduled runs are being checked after that repair. Do not claim closed-app automatic delivery is verified from a manual invocation alone.

Validation includes provider allowlisting, consent/privacy, lunar dates, paid/paused/recycled exclusions, concurrent leases, four-day spacing, expired tokens, service-worker stale-account rejection, and Firestore ownership/private-key rules. A real Chromium service-worker push event was tested after stopping/restarting the worker: IndexedDB session restoration, Arabic notification display, name masking, and stale-account suppression passed. This browser event injection does not prove remote push-provider transport or scheduled delivery. The profile’s test button confirms the local notification channel; it is not a remote delivery receipt.
