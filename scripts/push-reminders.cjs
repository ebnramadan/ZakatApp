'use strict';
const crypto = require('node:crypto');
const DAY = 86400000;
const GAP = 4 * DAY; // One combined digest, at most twice in any seven days, per device.
function localDay(now, timeZone = 'UTC') {
  try {
    const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {timeZone, year:'numeric', month:'2-digit', day:'2-digit', hour:'2-digit', hourCycle:'h23'}).formatToParts(now).map(p=>[p.type,p.value]));
    return {key:`${parts.year}-${parts.month}-${parts.day}`, month:`${parts.year}-${parts.month}`, day:Number(parts.day), hour:Number(parts.hour), year:Number(parts.year), monthNumber:Number(parts.month)};
  } catch (_) { return localDay(now, 'UTC'); }
}
function validSubscription(s) {
  if (!s || !['monthly','zakat','showNames'].every(k=>typeof s[k]==='boolean') || typeof s.timeZone!=='string') return false;
  try {
    const u = new URL(s.endpoint);
    const host = ['fcm.googleapis.com','updates.push.services.mozilla.com','web.push.apple.com'].includes(u.hostname) || /^[a-z0-9-]+\.notify\.windows\.com$/.test(u.hostname);
    return u.protocol==='https:' && !u.username && !u.password && !u.port && host && u.pathname.length>1 &&
      /^[A-Za-z0-9_-]{87}$/.test(s.keys?.p256dh) && /^[A-Za-z0-9_-]{22}$/.test(s.keys?.auth);
  } catch (_) { return false; }
}
function lunarEnd(start, timeZone) {
  if (!Number.isFinite(start)) return null;
  try {
    const fmt = new Intl.DateTimeFormat('en-u-ca-islamic-umalqura-nu-latn', {timeZone, year:'numeric',month:'numeric',day:'numeric'});
    const hijri = date => Object.fromEntries(fmt.formatToParts(date).filter(p=>['year','month','day'].includes(p.type)).map(p=>[p.type,Number(p.value)]));
    const h = hijri(new Date(start)); let match;
    for (let days=350;days<=357;days++) {
      const candidate=new Date(start+days*DAY), d=hijri(candidate);
      if(d.year===h.year+1 && d.month===h.month && d.day<=h.day && (!match || d.day>match.day)) match={day:d.day,key:localDay(candidate,timeZone).key};
    }
    return match?.key || null;
  } catch (_) { return null; }
}
function selectReminder({profile, subscription:s, plans=[], monthlyPayments=[], records=[], payments=[], now=new Date()}) {
  if (profile.resetInProgress || !validSubscription(s)) return null;
  const local=localDay(now,s.timeZone);
  // Daytime delivery. The hourly scheduler can catch up after a delayed run.
  if(local.hour<9 || local.hour>=20) return null;
  const active=records.filter(r=>r.deletedAt==null), byId=new Map(active.map(r=>[r.id,r]));
  const paid=new Set(monthlyPayments.filter(p=>p.month===local.month).map(p=>p.planId));
  const last=new Date(Date.UTC(local.year,local.monthNumber,0)).getUTCDate();
  const due=s.monthly ? plans.filter(p=>p.active===true && p.startMonth<=local.month && p.reminderDay>=1 && p.reminderDay<=31 && Math.min(p.reminderDay,last)<=local.day && !paid.has(p.id) &&
    typeof p.recipient==='string' && p.recipient.trim() && p.recipient.length<=120 && Number.isFinite(p.amount) && p.amount>0 &&
    (p.kind==='sadaqah' || (p.kind==='zakat' && byId.get(p.zakatRecordId)?.isSubmitted===true && byId.get(p.zakatRecordId)?.currency===p.currency))) : [];
  const sorted=active.slice().sort((a,b)=>(b.createdAt||0)-(a.createdAt||0));
  const current=byId.get(profile.defaultRecordId) || sorted.find(r=>r.isSubmitted) || sorted[0];
  let zakatDue=false, zakatSoon=false;
  if(s.zakat && current?.isSubmitted && current.nisabMet && Number.isFinite(current.totalWealth)) {
    const target=current.totalWealth*.025, given=payments.filter(p=>p.zakatRecordId===current.id && Number.isFinite(p.amount)).reduce((sum,p)=>sum+p.amount,0);
    const end=lunarEnd(current.hawlStartDate,s.timeZone);
    if(target>given && end) {
      zakatDue=end<=local.key;
      const days=(Date.parse(end)-Date.parse(local.key))/DAY;
      zakatSoon=days>0 && days<=7;
    }
  }
  const ar=profile.language==='ar';
  if(due.length) {
    const names=due.slice(0,3).map(p=>p.recipient.trim()).join(ar?'، ':', ') + (due.length>3 ? (ar?' وغيرهم':' and others') : '');
    const genericBody=ar?'افتكر شهرياتك المستحقة. النية لله، وربنا يتقبّل منك. لو دفعت، سجّل الدفعة.':'Your monthly giving is due. Give for Allah, and record payments after you give.';
    let body=ar?`${names} مستنيين خيرك. لو دفعت، سجّل الدفعة. ربنا يتقبّل منك.`:`${names} are waiting for your kindness. If you already gave, record the payment. May Allah accept it.`;
    const extra=zakatDue ? (ar?' ولسه فيه زكاة في سجلك الأساسي؛ النية لله.':' Your default Zakat record also has giving left. Renew your intention for Allah.') : '';
    return {kind:'monthly',language:ar?'ar':'en',title:ar?'شهرياتك · خطوة خير لله':'Monthly giving · A step of kindness',body:body+extra,genericBody:genericBody+extra};
  }
  if(zakatDue || zakatSoon) {
    const body=ar ? (zakatDue?'النية لله. كمّل زكاة مالك، وقرّب لله بعطائك. ربنا يتقبّل منك ويبارك لك.':'حوْل زكاتك قرب يكمّل. جدّد النية لله وجهّز عطائك بهدوء.') : (zakatDue?'Give for Allah. Continue your Zakat, and may Allah accept your giving and bless your wealth.':'Your Zakat Hawl is nearly complete. Renew your intention for Allah and prepare your giving.');
    return {kind:'zakat',language:ar?'ar':'en',title:ar?'زكاتك · النية لله':'Your Zakat · For Allah',body,genericBody:body};
  }
  return null;
}
async function bootstrap(db, webPush) {
  const ref=db.doc('_system/webPushKeys');
  const keys=await db.runTransaction(async tx=>{
    const snapshot=await tx.get(ref);
    if(snapshot.exists)return snapshot.data();
    const generated=webPush.generateVAPIDKeys();
    tx.set(ref,generated);return generated;
  });
  await db.doc('appConfig/push').set({publicKey:keys.publicKey,configured:true,schedule:'Up to twice weekly, during daytime'}, {merge:true});
  return keys;
}
async function run({db,auth,webPush,now=new Date(),dryRun=false,scheduled=false,log=console.log}) {
  const keys=await bootstrap(db,webPush);
  webPush.setVapidDetails('https://ztracker.web.app/',keys.publicKey,keys.privateKey);
  let sent=0,failed=0;
  const snapshot=await db.collectionGroup('pushSubscriptions').get();
  for (const doc of snapshot.docs) {
    const base=doc.ref.parent.parent;
    if(!base || base.parent.id!=='users' || !validSubscription(doc.data()))continue;
    const s=doc.data(), local=localDay(now,s.timeZone);
    if(local.hour<9 || local.hour>=20 || (!s.monthly&&!s.zakat))continue;
    const receipt=base.collection('pushDeliveries').doc(doc.id), lease=crypto.randomUUID();
    try {
      const previous=(await receipt.get()).data();
      if(previous?.sentAt>now.getTime()-GAP || previous?.leaseUntil>now.getTime())continue;
      const account=await auth.getUser(base.id);
      if(!account.emailVerified || account.disabled)continue;
      const [profile,records,payments,plans,monthly]=await Promise.all([base.get(),base.collection('zakatRecords').get(),base.collection('payments').get(),base.collection('monthlyPlans').get(),base.collection('monthlyPayments').where('month','==',local.month).get()]);
      const rows=s=>s.docs.map(d=>({id:d.id,...d.data()}));
      const message=selectReminder({profile:profile.data()||{},subscription:s,records:rows(records),payments:rows(payments),plans:rows(plans),monthlyPayments:rows(monthly),now});
      if(!message)continue;
      if(dryRun)continue;
      const claimed=await db.runTransaction(async tx=>{
        const [old,latest,user]=await Promise.all([tx.get(receipt),tx.get(doc.ref),tx.get(base)]);
        const state=old.data();
        if(!latest.exists || JSON.stringify(latest.data())!==JSON.stringify(s) || user.data()?.resetInProgress || user.data()?.language!==profile.data()?.language || user.data()?.defaultRecordId!==profile.data()?.defaultRecordId || state?.sentAt>now.getTime()-GAP || state?.leaseUntil>now.getTime())return false;
        tx.set(receipt,{...state,lease,leaseUntil:now.getTime()+10*60000});return true;
      });
      if(!claimed)continue;
      try {
        // Browser push tokens and private recipient data never appear in workflow logs.
        const response=await webPush.sendNotification({endpoint:s.endpoint,keys:s.keys},JSON.stringify({...message,body:s.showNames?message.body:message.genericBody,uid:base.id}),{TTL:3600,urgency:'normal',timeout:15000});
        if(response.statusCode<200 || response.statusCode>=300)throw Object.assign(new Error('Push provider rejected the request'),{statusCode:response.statusCode});
        await receipt.set({sentAt:now.getTime(),leaseUntil:0,status:'accepted',kind:message.kind});sent++;
      } catch(e) {
        if([404,410].includes(e.statusCode))await doc.ref.delete();
        await receipt.set({leaseUntil:0,status:'failed',failedAt:now.getTime()},{merge:true});failed++;
      }
    } catch(_) {failed++;}
  }
  await db.doc('appConfig/push').set({lastCheckedAt:now.getTime(),...(scheduled?{scheduledAt:now.getTime()}:{} )},{merge:true});
  log(`Push check complete: ${sent} accepted, ${failed} failed. No account details logged.`);
  if(failed)throw new Error('Some push subscriptions could not be processed; private details omitted.');
}
if(require.main===module) {
 const {initializeApp,applicationDefault}=require('firebase-admin/app');
 const {getFirestore}=require('firebase-admin/firestore');const {getAuth}=require('firebase-admin/auth');
 initializeApp({credential:applicationDefault(),projectId:'zakat-app-36c58'});
 run({db:getFirestore(),auth:getAuth(),webPush:require('web-push'),dryRun:process.argv.includes('--dry-run'),scheduled:process.env.GITHUB_EVENT_NAME==='schedule'}).catch(()=>{console.error('Push reminder check failed. No credentials or private subscription data logged.');process.exitCode=1;});
}
module.exports={GAP,localDay,validSubscription,lunarEnd,selectReminder,bootstrap,run};
