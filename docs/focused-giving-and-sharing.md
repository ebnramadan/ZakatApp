# Focused giving and monthly progress sharing

## Default record and dashboard
Profile `defaultRecordId` is the shared source for dashboard and tracker selection. Records offers Set as default; opening another record also makes it current. If the saved default is missing/recycled, use the newest submitted record, then the newest draft. Submitted calculations and payment links never change when switching. A draft default sends the user to finalize it, not another record's ledger.

The dashboard contains one record, relevant actions, and recent giving. Monthly Zakat actions match that record; Sadaqah actions are independent. Payments against other records do not reduce its balance. Next-step recipient actions open a filtered monthly list. Sadaqah appears in recent giving without entering the Zakat balance.

## Picker and gold behavior
Currencies can be searched by ISO code or currency name. Long record/day selectors are searchable; short choices use simple selectors. EGP is always labeled EGP, including amounts and input prefixes.

The gold input remains a pure 24K reference price. Changing carat or grams immediately updates the effective per-gram rate and gold value. Purity is applied once, in the shared calculation model. Changing record currency warns when amounts exist, does not convert amounts, and clears/refetches gold and foreign-exchange quotes.

## Onboarding and celebrations
New account profiles start a three-step welcome flow with currency and navigation-language choices. Existing profiles without the onboarding flag are treated as already onboarded. Profile's Getting started can review it again. Reset restarts onboarding.

A short crescent/star animation and original duʿā appear after successful calculation submission or recorded giving. The calculation message says the plan is ready; it never claims Zakat has been paid. Payment messages are for confirmed actual giving. Animations are finite and honor reduced-motion settings. Editing/undo does not celebrate.

## Monthly progress sheets
The previous shareFrequency field was inert and no sender existed. New behavior is explicit opt-in using sharingEnabled, shareDay (1–31) and up to five shareRecipients. Old preferences alone cannot send emails.

`.github/workflows/monthly-progress-sheet.yml` runs at 09:00 UTC daily using the existing verified sender secrets. It sends on/after the chosen day, clamped to month-end. Each verified, enabled account's recipients get one sheet per month, with server-only shareDeliveries receipts and stable provider message IDs. Changed/disabled consent and reset flags are rechecked before sending. Email/provider acceptance followed by a lost receipt can still make an SMTP retry ambiguous; this is not an exactly-once delivery guarantee.

Excel attachments include Overview, Zakat records, Zakat payments, Monthly commitments and Monthly payments. Currencies stay separate. Recycling excludes related financial history; drafts are labeled. Zakat calculated amounts are targets, not claims that Hawl is complete. Sadaqah is separate. All user strings are stored as worksheet strings, not executable formulas. Attachments are snapshots that can be opened in Excel or imported into Google Sheets, not live Google Sheets and not account access. Copies already emailed cannot be revoked. No invitations or test sheets are sent during development; integration tests use a fake SMTP transport and demo Firestore.

## Restricted app-data reset
Only the verified Firebase identity ebnramadan@gmail.com can reset its own UID, and Firestore requires authentication within five minutes plus resetInProgress. The Profile button asks for RESET and fresh password/Google confirmation. It does not execute automatically.

The reset first disables sharing/reminders and locks normal financial writes, deletes all current app collections (including bin and delivery history) in bounded batches, then replaces preferences with a fresh profile. Firebase Auth, Google linking and password credentials remain intact. Provider/navigation data is disposed through a reset revision key. An interrupted reset is resumable from a dedicated recovery page after another fresh sign-in. Other accounts' data is untouched. This is intentionally permanent app-data removal, not recycle-bin deletion or deletion of the sign-in account.

The daily sharing and cleanup workflows need to remain enabled; GitHub may disable schedules in inactive public repositories. Operators should monitor run history.
