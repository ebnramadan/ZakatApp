# Focused giving and monthly progress sharing

## Default record and dashboard
Profile `defaultRecordId` is the shared source for dashboard and tracker selection. Records offers Set as default; opening another record also makes it current. If the saved default is missing/recycled, use the newest submitted record, then the newest draft. Submitted calculations and payment links never change when switching. A draft default sends the user to finalize it, not another record's ledger.

The dashboard contains one record, relevant actions, and recent giving. Monthly Zakat actions match that record; Sadaqah actions are independent. Payments against other records do not reduce its balance. Next-step recipient actions open a filtered monthly list. Sadaqah appears in recent giving without entering the Zakat balance.

## Picker and gold behavior
Currencies can be searched by ISO code or currency name. Long record/day selectors are searchable; short choices use simple selectors. EGP is always labeled EGP, including amounts and input prefixes.

The gold input remains a pure 24K reference price. Changing carat or grams immediately updates the effective per-gram rate and gold value. Purity is applied once, in the shared calculation model. Changing record currency warns when amounts exist, does not convert amounts, and clears/refetches gold and foreign-exchange quotes.

## Onboarding and celebrations
New account profiles start a three-step welcome flow with currency and whole-app language choices. Existing profiles without the onboarding flag are treated as already onboarded. Profile's Getting started can review it again. Reset restarts onboarding.

A short crescent/star animation and original duʿā appear after successful calculation submission or recorded giving. The calculation message says the plan is ready; it never claims Zakat has been paid. Payment messages are for confirmed actual giving. Animations are finite and honor reduced-motion settings. Editing/undo does not celebrate.

## Monthly progress sheets
The previous shareFrequency field was inert and no sender existed. New behavior is explicit opt-in using sharingEnabled, shareDay (1–31) and up to five shareRecipients. Old preferences alone cannot send emails.

`.github/workflows/monthly-progress-sheet.yml` runs at 09:00 UTC daily using the existing verified sender secrets. It sends on/after the chosen day, clamped to month-end. Each verified, enabled account's recipients get one sheet per month, with server-only shareDeliveries receipts and stable provider message IDs. Changed/disabled consent and reset flags are rechecked before sending. Email/provider acceptance followed by a lost receipt can still make an SMTP retry ambiguous; this is not an exactly-once delivery guarantee.

Excel attachments include Overview, Zakat records, Zakat payments, Monthly commitments and Monthly payments. Currencies stay separate. Recycling excludes related financial history; drafts are labeled. Zakat calculated amounts are targets, not claims that Hawl is complete. Sadaqah is separate. All user strings are stored as worksheet strings, not executable formulas. Attachments are snapshots that can be opened in Excel or imported into Google Sheets, not live Google Sheets and not account access. Copies already emailed cannot be revoked. No invitations or test sheets are sent during development; integration tests use a fake SMTP transport and demo Firestore.

## Restricted app-data reset
Only the verified Firebase identity ebnramadan@gmail.com can reset its own UID, and Firestore requires authentication within five minutes plus resetInProgress. The Profile button asks for RESET and fresh password/Google confirmation. It does not execute automatically.

The reset first disables sharing/reminders and locks normal financial writes, deletes all current app collections (including bin and delivery history) in bounded batches, then replaces preferences with a fresh profile. Firebase Auth, Google linking and password credentials remain intact. Provider/navigation data is disposed through a reset revision key. An interrupted reset is resumable from a dedicated recovery page after another fresh sign-in. Other accounts' data is untouched. This is intentionally permanent app-data removal, not recycle-bin deletion or deletion of the sign-in account.

The daily sharing and cleanup workflows need to remain enabled; GitHub may disable schedules in inactive public repositories. Operators should monitor run history.

## Manual reports and localization

Profile → Progress sharing → Send now queues a report independently of the monthly schedule or sharing toggle. Recipients must first be saved. The requested-progress-sheets workflow processes requests every five minutes (GitHub scheduling can be delayed), using the existing SMTP secrets. The UI shows queued, accepted, or failed status. A request snapshots recipients, rechecks current consent, expires after 24 hours, and has separate delivery receipts from scheduled reports. Client requests are rate limited and cannot forge completion. Dry runs do not send or change status. No SMTP connection is opened for an empty queue.

Arabic preferences apply immediately, including onboarding, forms, date formatting, emails, and right-to-left Excel workbooks. Currency codes and personal names remain unchanged. Translation source is assets/translations/ar.json; regenerate the Dart catalog with python3 scripts/generate-localizations.py.

## Delivery recovery and mobile settings

GitHub schedule triggers are best effort, not an immediate delivery service. A request still waiting after ten minutes now shows a delayed state instead of an indefinitely disabled button. Retry preserves its ID, recipients, and delivery receipts; changing saved recipients requires cancelling and creating a new request. Cancellation is rechecked before sending, but cannot retract mail already accepted by the provider. Failed requests can retry with the same delivery history. The worker cancels requests for unverified/disabled accounts and also runs when its delivery code is deployed. The schedule is staggered away from the busiest minute boundaries. For guaranteed low-latency delivery, this free scheduled worker would need to be replaced with an authenticated server endpoint.

Mobile profile uses a compact identity header, grouped preferences, a report card with status and recovery, and a separate security screen. Navigation uses single-line labels, filled selected icons, and a 64px bar with safe-area padding. Bundled static Inter and Noto Sans Arabic weights make typography consistent across browsers; system text scaling remains enabled.

## iPhone setup and branding

Deletion now uses a scrollable warning with explicit Cancel/Move actions, without a text challenge. Focus is cleared before opening the dialog. The shell hides bottom tabs while the keyboard is visible, uses CSS safe-area insets as a Safari fallback, and keeps form actions above the home indicator. Material text inputs use 16px text to avoid unwanted iOS focus zoom while ordinary body copy stays compact.

Calculation setup keeps currency and Hawl start visible. More details contains Nisab pricing, Hijri display, and calculation assumptions; missing gold pricing opens that section before continuing. Arabic copy uses Egyptian wording while preserving religious terminology and duʿā. The sheikh-giving icon uses cream and warm brown; startup uses matching giving artwork in HTML and Flutter, with warm cream surfaces and reduced-motion support. Zakat/Sadaqah celebrations reveal a heart rising from open hands and keep the Arabic duʿā with its translation. iOS may retain an installed home-screen icon until the shortcut is added again.

Submitting below Nisab saves a submitted record with zero calculated Zakat. Submitting a new record selects it as the default; existing records and payments stay independent.

## iOS login-data recovery

Dashboard loading has an initial snapshot deadline. A silent first attempt reconnects the Firestore transport once without clearing cache or pending writes. A second stalled attempt becomes a retry state instead of an unbounded spinner; late snapshots may still recover. Retry is available during loading, and stream errors take precedence over another pending stream. Subscription generations prevent old callbacks from replacing a newer load. Resuming the app retries pending/failed account loads; monthly data also has a bounded initial wait.

Bottom navigation has a 64px content area. Real CSS/Flutter safe-area insets are retained. Installed modern iPhones get a 34px portrait / 21px landscape fallback only when Safari reports no inset; normal browser tabs, older phones, tablets, and Android do not get that fallback.
