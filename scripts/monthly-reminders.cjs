const crypto = require('node:crypto');

function monthKey(now) { return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`; }
function dueDate(plan, now) {
  const last = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0)).getUTCDate();
  return Math.min(plan.reminderDay, last);
}
function duePlans(plans, payments, deliveries, now) {
  const month = monthKey(now);
  const paid = new Set(payments.filter(p => p.month === month).map(p => p.planId));
  const sent = new Set(deliveries.filter(d => d.month === month && d.status === 'sent').map(d => d.planId));
  return plans.filter(p => p.active === true && p.startMonth <= month &&
    p.reminderDay >= 1 && p.reminderDay <= 31 && dueDate(p, now) <= now.getUTCDate() && !paid.has(p.id) && !sent.has(p.id));
}
function composeMessage(plans, now, appUrl, language='en') {
  const month = monthKey(now);
  const lines = plans.map(p => { const digits = new Intl.NumberFormat('en', {style:'currency',currency:p.currency}).resolvedOptions().maximumFractionDigits; return `• ${p.recipient}: ${p.currency} ${Number(p.amount).toFixed(digits)} (${p.kind === 'zakat' ? 'Zakat' : 'Sadaqah'})`; });
  if(language==='ar')return {
    subject:`تذكير بالعطاء الشهري · ${month}`,
    text:`تذكير لطيف بعطائك الشهري:\n\n${plans.map(p=>`• ${p.recipient}: ${p.currency} ${Number(p.amount).toFixed(new Intl.NumberFormat('en',{style:'currency',currency:p.currency}).resolvedOptions().maximumFractionDigits)} (${p.kind==='zakat'?'زكاة':'صدقة'})`).join('\n')}\n\nافتح متتبع الزكاة لتسجيل ما دفعته بالفعل:\n${appUrl}\n\nهذا تذكير وليس تحويلًا ماليًا، ولا تُسجّل أي دفعة تلقائيًا. لإيقاف هذه الرسائل، عطّل تذكيرات البريد من إعدادات الشهريات.`
  };
  return {
    subject: `Your monthly giving reminder · ${month}`,
    text: `A gentle reminder for your monthly giving:\n\n${lines.join('\n')}\n\nOpen Zakat Tracker to mark payments you have already made:\n${appUrl}\n\nThis reminder does not transfer money or count anything as paid. If you already gave, record it in شهريات.\n\nTo stop these emails, turn off email reminders in شهريات → Settings.`,
  };
}
async function createSender({apiKey, from, smtpUser, smtpPassword, smtpTransport, fetchImpl = fetch}) {
  const emailPattern = /^[^<>\s@]+@[^<>\s@]+\.[^<>\s@]+$/;
  if (smtpUser && smtpPassword) {
    if (!emailPattern.test(smtpUser)) throw new Error('REMINDER_SMTP_USER must be a Gmail email address.');
    const transport = smtpTransport || require('nodemailer').createTransport({host:'smtp.gmail.com',port:465,secure:true,
      auth:{user:smtpUser,pass:smtpPassword.replace(/\s/g,'')},connectionTimeout:15000,greetingTimeout:10000,socketTimeout:20000});
    await transport.verify();
    return {ready:true,send:async(to,message,key)=>{
      const result=await transport.sendMail({from:smtpUser,to,subject:message.subject,text:message.text,attachments:message.attachments,messageId:`<${key}@zakat-tracker.web.app>`});
      if(result.rejected?.length || !result.messageId) throw new Error('SMTP provider did not accept this reminder.');
      return result.messageId;
    }};
  }
  if (!apiKey || !from || !emailPattern.test(from)) throw new Error('Configure a verified Resend sender or Gmail SMTP app-password secrets.');
  return {ready:false,send:async(to,message,key)=>{
    const response=await fetchImpl('https://api.resend.com/emails',{method:'POST',
      headers:{Authorization:`Bearer ${apiKey}`,'Content-Type':'application/json','Idempotency-Key':key},
      body:JSON.stringify({from,to:[to],subject:message.subject,text:message.text,attachments:message.attachments?.map(a=>({filename:a.filename,content:Buffer.from(a.content).toString('base64')}))})});
    if(!response.ok) throw new Error(`Email provider returned HTTP ${response.status}`);
    const result=await response.json();
    if(!result.id) throw new Error('Email provider did not confirm delivery acceptance.');
    return result.id;
  }};
}
async function sendReminders({db, auth, fetchImpl = fetch, now = new Date(), apiKey, from, smtpUser, smtpPassword, smtpTransport, appUrl, dryRun = false, log = console.log}) {
  if (!/^https:\/\/[a-z0-9-]+\.web\.app\/?$/.test(appUrl)) throw new Error('Use the configured Firebase Hosting URL.');
  const sender=await createSender({apiKey,from,smtpUser,smtpPassword,smtpTransport,fetchImpl});
  const users = await db.collection('users').where('monthlyEmailReminders', '==', true).get();
  let sentCount = 0;
  let failed = 0;
  for (const userDoc of users.docs) {
    try {
      if (userDoc.data().resetInProgress === true) continue;
      // Never send to a client-supplied address without checking Firebase Auth ownership.
      const account = await auth.getUser(userDoc.id);
      if (!account.emailVerified || account.disabled || !account.email) continue;
      const base = db.collection('users').doc(userDoc.id);
      const month = monthKey(now);
      const [plansSnapshot, paymentsSnapshot, deliveriesSnapshot] = await Promise.all([
        base.collection('monthlyPlans').get(),
        base.collection('monthlyPayments').where('month', '==', month).get(),
        base.collection('reminderDeliveries').where('month', '==', month).get(),
      ]);
      const map = s => s.docs.map(d => ({id: d.id, ...d.data()}));
      let due = duePlans(map(plansSnapshot), map(paymentsSnapshot), map(deliveriesSnapshot), now)
        .filter(p => Number.isFinite(p.amount) && p.amount > 0 && p.amount < 1e15 && typeof p.recipient === 'string' && p.recipient.length <= 120 && /^[A-Z]{3}$/.test(p.currency) && ['zakat', 'sadaqah'].includes(p.kind));
      const allowed = [];
      for (const plan of due) {
        if (plan.kind === 'zakat') {
          const record = await base.collection('zakatRecords').doc(plan.zakatRecordId).get();
          if (!record.exists || record.data().deletedAt != null || record.data().isSubmitted !== true || record.data().currency !== plan.currency) continue;
        }
        allowed.push(plan);
      }
      due = allowed;
      if (!due.length) continue;
      if (dryRun) { log(`Would send one digest for ${due.length} due commitments (account identity omitted).`); continue; }
      const message = composeMessage(due, now, appUrl, userDoc.data().language);
      const digest = crypto.createHash('sha256').update(`${userDoc.id}:${month}:${due.map(p => p.id).sort().join(',')}`).digest('hex');
      const providerId = await sender.send(account.email,message,`monthly-${digest}`);
      const batch = db.batch();
      for (const plan of due) batch.set(base.collection('reminderDeliveries').doc(`${plan.id}_${month}`), {planId: plan.id, month, status: 'sent', acceptedAt: now.getTime(), providerId});
      await batch.commit();
      sentCount++;
    } catch (e) {
      failed++;
      // No recipient names, financial amounts, tokens or email addresses in workflow logs.
      log(`A reminder could not be processed: ${e.code || e.message}`);
    }
  }
  if (!dryRun && (sentCount > 0 || sender.ready)) await db.doc('appConfig/reminders').set({enabled: true, checkedAt: now.getTime(), schedule: '08:00 UTC daily'}, {merge: true});
  log(`${dryRun ? 'Dry run' : 'Reminder run'} complete: ${sentCount} email digests accepted; ${failed} accounts failed.`);
  if (failed) throw new Error('Some reminders failed. Check sender setup and service-account permissions before retrying.');
  return {sentCount, failed};
}
if (require.main === module) {
  const {initializeApp, applicationDefault} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  const {getAuth} = require('firebase-admin/auth');
  initializeApp({credential: applicationDefault(), projectId: 'zakat-app-36c58'});
  sendReminders({db: getFirestore(), auth: getAuth(), apiKey: process.env.RESEND_API_KEY,
    from: process.env.REMINDER_FROM, smtpUser:process.env.REMINDER_SMTP_USER, smtpPassword:process.env.REMINDER_SMTP_APP_PASSWORD, appUrl: 'https://zakat-tracker.web.app',
    dryRun: process.argv.includes('--dry-run')}).catch(e => { console.error(e.message); process.exitCode = 1; });
}
module.exports = {monthKey, dueDate, duePlans, composeMessage, sendReminders, createSender};
