# Dashboard, navigation, and recycle bin

The dashboard is the signed-in landing page. Five destinations are always available: Dashboard, Records, Tracker, Monthly Giving, Profile. The shell uses bottom navigation below 900px and a labeled navigation rail above it. The saved Arabic preference translates navigation labels and the monthly title; existing financial forms are not fully translated.

## Dashboard financial meaning

Only active, submitted records contribute. Every currency has its own summary. Completed-Hawl obligations and remaining balances are separate from future estimates. Remaining balances are clamped per record before summing, so an overpayment on one record never pays another. Sadaqah does not enter the Zakat ledger. Payment streams must load successfully before balances are displayed. Recent payments refer to their original records.

## Record removal and recovery

Both drafts and submitted records can be moved to the recycle bin through Record actions or the tracker toolbar. The warning describes linked payments, monthly commitments, and the 60-day window. A success snackbar offers Undo. The bin is available from Records and Profile.

Records remain in their original paths with `deletedAt` and `purgeAt` integer timestamps. Only those two fields change during removal/restoration. The 60-day duration is 5,184,000,000 milliseconds. Submitted financial fields stay locked. Retrying removal never extends retention. Restore requires server time strictly before purgeAt. The client cannot hard-delete records, extend the deadline, or change a recycled record's financial values.

Payment history remains intact during the window. Payments and monthly Zakat receipts cannot be created, edited or undone against recycled records. Such commitments remain visible as unavailable, can be relinked by editing, and stop generating email reminders. Restoring the record makes its history and linked commitments available again. Paused recipients can be found through Include paused recipients.

## Permanent cleanup

`.github/workflows/recycle-bin-cleanup.yml` runs daily at 03:00 UTC, independent of the website being open. A manual run defaults to a read-only dry run. The worker rechecks expiry, pauses associated monthly plans, removes linked manual/monthly ledger payments and monthly receipts in bounded batches, then recursively deletes the expired record. Other records and Sadaqah receipts are preserved. Retrying a partially completed run is safe. Monthly plans are retained paused so users can relink a recurring recipient rather than losing the commitment.

The restore window ends at exactly 60 days. Physical removal happens in the next successful daily cleanup, normally within 24 hours afterward. GitHub Actions schedules may be delayed. GitHub can also disable scheduled workflows in public repositories after 60 days without repository activity; keep the scheduled workflows enabled and monitor their run history when operating the service. The app explains this daily cleanup behavior. Do not use Firestore TTL on only the parent document: it would leave related collections behind.

## Validation

Flutter tests cover per-currency aggregation, estimates, overpayments, exclusion of recycled records, confirmation cancellation, undo/restore and retention boundaries. Emulator rule tests check account ownership, immutable amounts, fixed deadlines, disabled writes against recycled records, and rejected expired restores. Backend tests cover cleanup dependencies and reminder suppression/resumption. Browser QA uses demo Firebase emulators, never production financial fixtures.
