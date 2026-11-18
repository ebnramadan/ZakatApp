// Every trigger drains the same work. GitHub retains only one pending run per
// concurrency group, so a replacement must not discard a different mail task.
const {sendReminders, createSender} = require('./monthly-reminders.cjs');
const {sendProgressSheets} = require('./monthly-progress-sheet.cjs');

async function sendDeliveryTest(options, makeSender = createSender) {
  const account = await options.auth.getUserByEmail(options.testEmail);
  if (!account.emailVerified || account.disabled || !account.email) {
    throw new Error('Delivery test requires an enabled, verified account.');
  }
  if (options.dryRun) return;
  const sender = await makeSender(options);
  await sender.send(account.email, {
    subject: 'Zakat Tracker · Email delivery test',
    text: 'Your Zakat Tracker email sender is working. This test contains no financial information. Monthly reminders use your saved preferences; progress sheets go only to the recipients you save in Profile → Monthly progress sheet.\n\nMay Allah accept your giving.\nhttps://ztracker.web.app',
  }, 'delivery-test-' + require('node:crypto').randomUUID());
  (options.log || console.log)('Delivery test accepted by the email provider; address omitted.');
}

async function deliverEmail(options, handlers = {sendReminders, sendProgressSheets}) {
  const failures = [];
  const hour = (options.now || new Date()).getUTCHours();
  const tasks = [
    ['requested sheets', () => handlers.sendProgressSheets({...options, manualOnly: true})],
    ...(hour >= 9 ? [['scheduled sheets', () => handlers.sendProgressSheets({...options, manualOnly: false})]] : []),
    ...(hour >= 8 ? [['monthly reminders', () => handlers.sendReminders(options)]] : []),
  ];
  for (const [task, send] of tasks) {
    try { await send(); }
    catch (_) {
      failures.push(task);
      (options.log || console.log)(`Email task failed: ${task}; account details omitted.`);
    }
  }
  if (failures.length) throw new Error('Email delivery incomplete: ' + failures.join(', '));
}

if (require.main === module) {
  const {initializeApp, applicationDefault} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  const {getAuth} = require('firebase-admin/auth');
  initializeApp({credential: applicationDefault(), projectId: 'zakat-app-36c58'});
  const options = {db: getFirestore(), auth: getAuth(), now: new Date(),
    smtpUser: process.env.REMINDER_SMTP_USER,
    smtpPassword: process.env.REMINDER_SMTP_APP_PASSWORD,
    apiKey: process.env.RESEND_API_KEY, from: process.env.REMINDER_FROM,
    appUrl: 'https://ztracker.web.app', dryRun: process.argv.includes('--dry-run'),
    testEmail: process.env.TEST_EMAIL?.trim(),
  };
  (async () => {
    if (options.testEmail) await sendDeliveryTest(options);
    await deliverEmail(options);
  })().catch(() => {console.error('Email delivery failed. Check configuration and verified-account settings; private details omitted.'); process.exitCode = 1;});
}
module.exports = {deliverEmail, sendDeliveryTest};
