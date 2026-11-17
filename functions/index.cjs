const functions=require('firebase-functions/v1');
const {initializeApp}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
const {getAuth}=require('firebase-admin/auth');
const {processQueuedReport}=require('./delivery.cjs');
const {sendProgressSheets}=require('./lib/scripts/monthly-progress-sheet.cjs');
initializeApp();
const firebaseMailEnabled=async()=> (await getFirestore().doc('_system/reportDelivery').get()).data()?.mode==='firebase';
exports.deliverProgressSheet=functions.region('us-central1').runWith({
  secrets:['REMINDER_SMTP_USER','REMINDER_SMTP_APP_PASSWORD'],
  timeoutSeconds:120,memory:'512MB',maxInstances:3,failurePolicy:true
}).firestore.document('users/{uid}').onWrite(async(change,context)=>{if(!await firebaseMailEnabled())return null;return processQueuedReport({
  before:change.before.data(),after:change.after.data(),uid:context.params.uid
},{db:getFirestore(),auth:getAuth(),send:options=>sendProgressSheets({...options,
  smtpUser:process.env.REMINDER_SMTP_USER,smtpPassword:process.env.REMINDER_SMTP_APP_PASSWORD
})});});
const senderOptions=()=>({smtpUser:process.env.REMINDER_SMTP_USER,smtpPassword:process.env.REMINDER_SMTP_APP_PASSWORD});
exports.deliverScheduledProgressSheets=functions.region('us-central1').runWith({secrets:['REMINDER_SMTP_USER','REMINDER_SMTP_APP_PASSWORD'],timeoutSeconds:540,memory:'512MB',maxInstances:1}).pubsub.schedule('0 9 * * *').timeZone('UTC').onRun(async()=>await firebaseMailEnabled()?sendProgressSheets({db:getFirestore(),auth:getAuth(),...senderOptions()}):null);
exports.deliverGivingReminders=functions.region('us-central1').runWith({secrets:['REMINDER_SMTP_USER','REMINDER_SMTP_APP_PASSWORD'],timeoutSeconds:540,memory:'512MB',maxInstances:1}).pubsub.schedule('0 8 * * *').timeZone('UTC').onRun(async()=>await firebaseMailEnabled()?require('./lib/scripts/monthly-reminders.cjs').sendReminders({db:getFirestore(),auth:getAuth(),appUrl:'https://ztracker.web.app',...senderOptions()}):null);
