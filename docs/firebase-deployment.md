# Enable GitHub deployment to the existing Firebase site

Project/site: `zakat-app-36c58`  
Primary URL: https://ztracker.web.app (in the same project)
Previous URL retained: https://zakat-app-36c58.web.app

The workflow now deploys the reviewed Firestore rules first, then the web build to the primary ztracker site and the two previous Hosting sites. It does not replace the Firebase project, change accounts, or delete financial records. The new rules are required for verification gating and the monthly-giving collections; do not deploy the new web UI against the old rules.

## One-time setup by the project owner

1. Open [Google Cloud service accounts](https://console.cloud.google.com/iam-admin/serviceaccounts?project=zakat-app-36c58). Create a dedicated service account named `github-zakat-hosting` in this existing project.
2. Grant it **Firebase Hosting Admin** (`roles/firebasehosting.admin`) and **Service Usage Consumer** (`roles/serviceusage.serviceUsageConsumer`) on `zakat-app-36c58`. Also add **Firebase Rules Admin**, **Cloud Datastore User**, and **Firebase Authentication Viewer** for the new verification rules and reminder job. Do not grant Owner or Editor.
3. Open that service account → **Keys** → **Add key** → **Create new key** → **JSON**. Download the file. If your organization disables service-account keys, use Workload Identity Federation instead; do not change organization policy just to create a key.
4. Open [this repository's Actions secrets](https://github.com/ebnramadan/ZakatApp/settings/secrets/actions), choose **New repository secret**, and enter:
   - Name: `FIREBASE_SERVICE_ACCOUNT_ZAKAT_APP_36C58`
   - Secret: the complete contents of the downloaded JSON file.
5. Save the secret. Never paste the JSON into chat, an issue, a workflow, or source control. Keep the downloaded key securely and revoke/rotate it if exposed.
6. Merge the reviewed [PR #2](https://github.com/ebnramadan/ZakatApp/pull/2) so the workflow is present on the default branch. The default branch is currently `claude/zakat-app-build-0NR5K`.

The secret grants the GitHub runner access; it does not sign the assistant's local Firebase CLI into your Google account. Only trusted maintainers should be allowed to change production workflows.

## Deploy

After setup, merging web changes into the default branch automatically validates, builds and deploys them to the existing live site. You can also open **Actions → Deploy web to Firebase → Run workflow** and select the desired trusted branch. Do not run a fork or unreviewed code with production credentials.

The job runs the analyzer and tests before creating a release web build. It uses the repository's locked Firebase CLI, authenticates through the GitHub secret, and runs:

```sh
firebase deploy --project zakat-app-36c58 --only firestore:rules --non-interactive
firebase deploy --project zakat-app-36c58 --only hosting --non-interactive
```

Its summary records the source commit and live URL. The HTTP check establishes that Hosting responds; it does not replace an authenticated browser smoke test of login, calculations, drafts and payments.

Until the secret is configured, deployment exits with a clear setup error. A successful Flutter build alone does not mean the site was deployed.

## Rollback

Use the existing Firebase Hosting site's release history to roll back to a previous release, or manually deploy a previously reviewed source revision using the workflow. The site and domain remain the same.

## Without downloaded keys

Workload Identity Federation can replace the JSON secret with GitHub OIDC and short-lived credentials. It requires a Google identity pool/provider restricted to this repository and production branch, a service-account binding, and `id-token: write` in the workflow. Configure that trust relationship before changing the authentication step; the current workflow deliberately expects the documented JSON secret.

Add the new Hosting domains in Firebase Authentication → Settings → Authorized domains before deployment. For Gmail/Resend sender setup, see [monthly giving](monthly-giving.md).

The previous zakat-tracker.web.app and zakat-app-36c58.web.app sites remain deployed. All addresses use the same Firebase Auth/Firestore project. Browser sign-in storage belongs to each origin, so users may need to sign in again on the new address; this does not create a separate financial account.
