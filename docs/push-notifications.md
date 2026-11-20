# Web push giving reminders (Firebase Spark)

Web Push uses a dedicated `/push-worker.js` registered under `/push-scope/`, separate from Flutter’s asset-cache worker. It works without Firebase Functions, Blaze, SMTP, or a new paid service. VAPID keys are generated once by the trusted GitHub worker: the private key stays in server-only `_system/webPushKeys`; only the public key is published at `appConfig/push`. Never print the private key or subscription endpoints in logs.

Profile offers opt-in per device, separate daily-duaa and monthly/Zakat preferences, recipient names (on by default for new setup; existing choices are preserved), a local test notification, and an off button. Names can appear on the lock screen when opted in; amounts never appear. On iOS 16.4+ the site must be added to the Home Screen and opened from that icon before enabling notifications. Permission is requested only from the user’s tap.

## Frequency and eligibility

`.github/workflows/push-reminders.yml` checks every 15 minutes, offset from the top of the hour. One combined duaa/reminder is allowed per device per local calendar day, during 10:00–20:00 in its saved timezone. Daily duaa defaults on unless explicitly disabled; legacy subscriptions without the preference also default on. Duaa rotates daily, and due unpaid monthly recipients rotate when several qualify. Checks may run late on GitHub; there is no exact-minute guarantee. Monthly reminders include only active, started, unpaid commitments whose reminder day has arrived, clamped to month-end. Linked Zakat records must be submitted, active and in the same currency.

Zakat uses the selected default record (or the same submitted/newest fallback as the app), actual linked payments and the next Umm al-Qura lunar-year anniversary. Below-Nisab, draft, fully paid and recycled records do not produce Zakat reminders. The week before Hawl completion uses preparation wording; due records use respectful giving-for-Allah wording. No reminder marks anything paid or transfers money.

## Lifecycle and privacy

Verified accounts own private `pushSubscriptions` documents. Subscription URLs are restricted to recognized HTTPS push-provider hosts to prevent server-side requests to arbitrary endpoints. Delivery leases and accepted timestamps are server-controlled and suppress concurrent runs. Expired endpoints (404/410) are removed. Reset clears subscriptions, delivery receipts and notification history, and unsubscribes this browser. Sign-out disables the service worker before unsubscribing; the worker also checks the last authenticated UID and local opt-in state, so queued messages for a previous account cannot show its names after an account switch.

Notification clicks use same-origin action links: `/?open=monthly&plan=...&month=...&notification=...`, `/?open=tracker&record=...&notification=...`, or Home for a duaa. Inbox rows use the same routing. Monthly links identify a recipient by ID and preserve the original month; Zakat links use an isolated tracker without changing the default record. Opening an action never records a payment. Consumed parameters are removed while retaining browser history state, preventing replay on later launches. A dedicated worker scope prevents asset-cache replacement. The worker stores only session/preferences in its IndexedDB; financial records remain in private Firestore collections.

## Notification history

The bell on Home, Tracker, Monthly and Profile opens the private inbox and shows an unread dot. Recent items stream in pages of 50, with older pages available on demand. Tapping an item marks it read and opens its action. Paid, paused, missing and recycled targets are handled without silently redirecting to another recipient or record.

Only the trusted sender creates `users/{uid}/notifications/{id}`, after push-provider acceptance. Acceptance is not proof that a banner was displayed. Verified owners may read their inbox and change only `readAt`; message text and action targets remain server-controlled. A deterministic user/day/action document avoids duplicate inbox entries from multiple devices. History starts with this feature: older push receipts do not contain the original message text and cannot be reconstructed. Local device-test notifications are not remote delivery receipts and do not create inbox messages.

## Deployment and scheduler verification

Merging the worker triggers a dry run that provisions keys using the existing Firestore service account. Manual workflow runs default to dry-run. Only a genuine `schedule` event writes `appConfig/push.scheduledAt`; manual checks never claim automatic scheduling is operational. The profile distinguishes an unconfirmed scheduler from delayed checks. Genuine scheduled runs have been observed on the default `main` branch, but GitHub can delay subsequent runs. Do not claim closed-app automatic delivery is verified from a manual invocation alone.

Validation includes provider allowlisting, consent/privacy, lunar dates, paid/paused/recycled exclusions, concurrent leases, local-day deduplication, daily-duaa opt-outs, expired tokens, service-worker stale-account rejection, safe action links, paginated history, and Firestore ownership/private-key rules. A real Chromium service-worker push event was tested after stopping/restarting the worker: IndexedDB session restoration, Arabic notification display, name masking, and stale-account suppression passed. This browser event injection does not prove remote push-provider transport or scheduled delivery. The profile’s test button confirms the local notification channel; it is not a remote delivery receipt.

## Device test and setup recovery

**Send test notification** is visible before reminder activation, including while settings load or fail. It requests OS permission from the tap, registers the dedicated push worker if needed, and displays a local test; it never subscribes the user to reminders or creates a financial payment. The page distinguishes this device-channel test from automatic remote reminder delivery.

Public VAPID/readiness configuration loads through the unauthenticated Firestore REST endpoint, independently of the authenticated SDK WebChannel, with an existing SDK-cache fallback for offline users. Private saved preferences remain authenticated and cannot be overwritten when their lookup fails. Retry clears stale errors. Worker lookup requires the exact push scope so a fresh install cannot mistake Flutter’s root cache worker for the notification worker.

Daily/action notifications use distinct notification tags. Retries retain the same tag and do not re-alert. Push delivery requests high urgency and a six-hour expiry window; provider acceptance still does not prove an OS displayed an alert. Signing in restores this device's saved preferences if local worker storage was cleared, with an account/verification check before applying them. The worker waits for queued account changes before reading privacy state.

English duaas include the Arabic prayer alongside the English meaning; Arabic mode shows Arabic only. The inbox formats known older prayers using the current app language without rewriting stored history. Startup prayers follow the same rule.
