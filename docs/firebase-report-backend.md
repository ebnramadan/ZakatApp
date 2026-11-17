# Reliable report sending

The existing GitHub cron is best effort. A successful manual run proves the Gmail sender works; it does not prove scheduled jobs will start promptly. A retry in the app only updates Firestore, so it cannot itself wake GitHub Actions.

The prepared `mail` Firebase Functions codebase watches queued requests in Firestore. It sends only the changed account's report, rechecks consent and verification, preserves delivery receipts, and leases requests to handle duplicate events. Credentials come from Firebase Secret Manager, populated from the existing GitHub Gmail secrets. There are no client secrets or public unauthenticated send endpoints. Two Firebase scheduled handlers also deliver monthly reports at 09:00 UTC and monthly giving reminders at 08:00 UTC. New handlers remain inert until the server-only activation flag is set, so a partial deployment cannot race the current worker. After successful deployment, the workflow disables the three GitHub email workflows to avoid two systems processing the same queue. The deployment shares the report-workflow concurrency group to let existing email runs finish first. It then enables the Firebase sender and wakes the saved queue. Failed activation restores GitHub processing.

## Required setup

Firebase server functions require a billing-enabled/Blaze project. The workflow never enables billing or upgrades the plan. The current deployment account lacks server deployment permissions. In Google Cloud IAM for `zakat-app-36c58`, the service account associated with the existing GitHub deployment secret needs:

- Cloud Functions Admin
- Service Account User
- Secret Manager Admin
- Service Usage Admin
- Cloud Scheduler Admin

The workflow checks access before creating secrets or deploying anything. If Firebase reports an additional project-specific build or storage permission, grant only that named permission/role. It will refuse a project that cannot deploy functions; it does not attach a billing account.

After setup, run **Actions → Deploy Firebase report delivery**, first with Deploy off to check permissions, then on to deploy. Do not re-enable the GitHub email workers while the Firebase sender is active.

After deployment, the workflow wakes non-expired queued requests and expires requests older than 24 hours. A manual retry in the app also works: the Firestore event starts delivery without waiting for GitHub cron. Provider acceptance is shown in the profile; inbox placement is still controlled by the recipient's email provider.

`node scripts/build-mail-function.cjs` copies the shared, tested sender and translation catalog into the function package before deployment. `functions/lib` is generated. SMTP acceptance and a lost delivery receipt can still leave a retry ambiguous; no SMTP integration can promise exactly-once delivery in that failure window.
