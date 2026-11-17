const { readFileSync } = require('node:fs');
const { before, after, beforeEach, test } = require('node:test');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, getDoc, writeBatch, deleteField } = require('firebase/firestore');
let env;
const record = (submitted = false) => ({
  userId: 'alice', name: 'Zakat', currency: 'USD', hawlStartDate: 1600000000000,
  createdAt: 1600000000000, isHijriCalendar: false, cashLocal: 10000,
  foreignCash: [], goldEntries: [], goldPricePerGram24k: 100,
  totalWealth: 10000, nisabThreshold: 8500, zakatDue: 250,
  nisabMet: true, isSubmitted: submitted, submittedAt: submitted ? 1700000000000 : null
});
const payment = () => ({ userId: 'alice', zakatRecordId: 'r', amount: 10, name: 'Payment', recipient: 'Charity', date: 1700000000000, createdAt: 1700000000000 });
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-zakat-rules', firestore: {rules: readFileSync('firestore.rules', 'utf8')}});
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });
const alice = () => env.authenticatedContext('alice', {email: 'alice@example.com', email_verified: true}).firestore();
const ref = (db) => doc(db, 'users/alice/zakatRecords/r');
test('owner can save, edit and submit a draft', async () => {
  const r = ref(alice());
  await assertSucceeds(setDoc(r, record()));
  await assertSucceeds(updateDoc(r, {name: 'Edited'}));
  await assertSucceeds(updateDoc(r, {isSubmitted: true, submittedAt: 1700000000000}));
});
test('submitted records cannot be changed, unlocked or deleted', async () => {
  const r = ref(alice());
  await setDoc(r, record(true));
  await assertFails(updateDoc(r, {cashLocal: 1, isSubmitted: true}));
  await assertFails(updateDoc(r, {isSubmitted: false}));
  await assertFails(deleteDoc(r));
});
test('other accounts and signed-out clients cannot access financial records', async () => {
  await setDoc(ref(alice()), record());
  for (const db of [env.authenticatedContext('bob').firestore(), env.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(ref(db)));
    await assertFails(setDoc(ref(db), record()));
  }
});
test('reject invalid owner, negative values and missing submission prices', async () => {
  for (const patch of [{userId: 'bob'}, {cashLocal: -1}, {goldPricePerGram24k: 0, isSubmitted: true, submittedAt: 1700000000000}]) {
    await assertFails(setDoc(ref(alice()), {...record(), ...patch}));
  }
});
test('payments require an existing submitted record and positive finite amount', async () => {
  const db = alice(); const p = doc(db, 'users/alice/payments/p');
  await assertFails(setDoc(p, payment()));
  await setDoc(ref(db), record());
  await assertFails(setDoc(p, payment()));
  await updateDoc(ref(db), {isSubmitted: true, submittedAt: 1700000000000});
  await assertSucceeds(setDoc(p, payment()));
  for (const amount of [-1, 0, NaN, Infinity]) await assertFails(updateDoc(p, {amount}));
  await assertFails(updateDoc(p, {zakatRecordId: 'other'}));
  await assertSucceeds(updateDoc(p, {amount: 20}));
  await assertSucceeds(deleteDoc(p));
});

const plan = (kind='zakat') => ({userId:'alice',recipient:'Family',amount:100,currency:'USD',kind,zakatRecordId:kind==='zakat'?'r':'',reminderDay:31,startMonth:'2024-01',active:true,createdAt:1700000000000});
const receipt = (kind='zakat') => ({userId:'alice',planId:'p',month:'2026-11',recipient:'Family',amount:100,currency:'USD',kind,zakatRecordId:kind==='zakat'?'r':'',paidAt:1700000000000,createdAt:1700000000000});
const ledger = () => ({...payment(), amount:100,recipient:'Family',source:'monthly',monthlyPaymentId:'p_2026-11'});
test('unverified accounts cannot access records or create a financial profile', async () => {
  const db = env.authenticatedContext('alice', {email:'alice@example.com',email_verified:false}).firestore();
  await assertFails(setDoc(ref(db),record()));
  await assertFails(getDoc(ref(db)));
  await assertFails(setDoc(doc(db,'users/alice'),{displayName:'Alice',email:'alice@example.com',currency:'USD'}));
});
test('profile email must belong to the verified Firebase identity', async () => {
  const profile = doc(alice(),'users/alice');
  await assertFails(setDoc(profile,{displayName:'Alice',email:'someone-else@example.com',currency:'USD',monthlyEmailReminders:true}));
  await assertSucceeds(setDoc(profile,{displayName:'Alice',email:'alice@example.com',currency:'USD',monthlyEmailReminders:true,monthlyDefaultKind:'sadaqah'}));
});
test('monthly Zakat receipt and ledger must be created and deleted together', async () => {
  const db = alice(); await setDoc(ref(db),record(true));
  await setDoc(doc(db,'users/alice/monthlyPlans/p'),plan());
  const receiptRef = doc(db,'users/alice/monthlyPayments/p_2026-11');
  const ledgerRef = doc(db,'users/alice/payments/monthly_p_2026-11');
  await assertFails(setDoc(receiptRef,receipt()));
  await assertFails(setDoc(ledgerRef,ledger()));
  const batch = writeBatch(db); batch.set(receiptRef,receipt()); batch.set(ledgerRef,ledger());
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(ledgerRef,{amount:200}));
  await assertFails(deleteDoc(ledgerRef)); await assertFails(deleteDoc(receiptRef));
  const undo = writeBatch(db); undo.delete(receiptRef); undo.delete(ledgerRef);
  await assertSucceeds(undo.commit());
});
test('monthly Sadaqah cannot create a Zakat ledger entry', async () => {
  const db = alice(); await setDoc(ref(db),record(true));
  await setDoc(doc(db,'users/alice/monthlyPlans/p'),plan('sadaqah'));
  const receiptRef = doc(db,'users/alice/monthlyPayments/p_2026-11');
  const ledgerRef = doc(db,'users/alice/payments/monthly_p_2026-11');
  const bad = writeBatch(db); bad.set(receiptRef,receipt('sadaqah')); bad.set(ledgerRef,ledger());
  await assertFails(bad.commit());
  await assertSucceeds(setDoc(receiptRef,receipt('sadaqah')));
  await assertFails(setDoc(ledgerRef,ledger()));
});
test('monthly links require matching currency and protected ownership', async () => {
  const db = alice(); await setDoc(ref(db),record(true));
  await assertFails(setDoc(doc(db,'users/alice/monthlyPlans/p'),{...plan(),currency:'EGP'}));
  await assertFails(setDoc(doc(db,'users/alice/monthlyPlans/p'),{...plan(),userId:'bob'}));
  await assertSucceeds(setDoc(doc(db,'users/alice/monthlyPlans/p'),plan()));
  await assertFails(deleteDoc(doc(db,'users/alice/monthlyPlans/p')));
});

test('profile language accepts Arabic and English and rejects unsupported values', async () => {
  const profile = doc(alice(), 'users/alice');
  const fields = {displayName:'Alice',email:'alice@example.com',currency:'EGP'};
  await assertSucceeds(setDoc(profile, fields));
  await assertSucceeds(updateDoc(profile, {language:'ar'}));
  await assertSucceeds(updateDoc(profile, {language:'en'}));
  await assertFails(updateDoc(profile, {language:'invalid'}));
});

test('submitted records can be recycled and restored, with immutable financial data and a fixed 60-day window', async () => {
  const db=alice(), r=ref(db), deletedAt=Date.now(), purgeAt=deletedAt+60*86400000;
  await setDoc(r,record(true));
  await assertFails(updateDoc(r,{deletedAt,purgeAt,cashLocal:1}));
  await assertFails(updateDoc(r,{deletedAt,purgeAt:purgeAt+1}));
  await assertSucceeds(updateDoc(r,{deletedAt,purgeAt}));
  await assertFails(updateDoc(r,{purgeAt:purgeAt+86400000}));
  await assertFails(updateDoc(r,{cashLocal:1}));
  await assertFails(setDoc(doc(db,'users/alice/payments/new'),payment()));
  await assertFails(setDoc(doc(db,'users/alice/monthlyPlans/p'),plan()));
  await assertFails(deleteDoc(r));
  await assertSucceeds(updateDoc(r,{deletedAt:deleteField(),purgeAt:deleteField()}));
  await assertSucceeds(setDoc(doc(db,'users/alice/payments/new'),payment()));
});
test('expired records cannot be restored and recycled payment history cannot be changed or deleted', async () => {
  const db=alice(), r=ref(db), p=doc(db,'users/alice/payments/p');
  await setDoc(r,record(true)); await setDoc(p,payment());
  const removedAt=Date.now();
  await updateDoc(r,{deletedAt:removedAt,purgeAt:removedAt+60*86400000});
  await assertFails(updateDoc(p,{amount:50})); await assertFails(deleteDoc(p));
  await env.withSecurityRulesDisabled(async ctx => {
    await updateDoc(ref(ctx.firestore()),{deletedAt:Date.now()-61*86400000,purgeAt:Date.now()-86400000});
  });
  await assertFails(updateDoc(r,{deletedAt:deleteField(),purgeAt:deleteField()}));
});

test('monthly receipts and ledger cannot be created or undone while the parent record is recycled', async () => {
 const db=alice(), r=ref(db);
 await setDoc(r,record(true));await setDoc(doc(db,'users/alice/monthlyPlans/p'),plan());
 const at=Date.now();await updateDoc(r,{deletedAt:at,purgeAt:at+60*86400000});
 const rec=doc(db,'users/alice/monthlyPayments/p_2026-11'), pay=doc(db,'users/alice/payments/monthly_p_2026-11');
 const blocked=writeBatch(db);blocked.set(rec,receipt());blocked.set(pay,ledger());await assertFails(blocked.commit());
 await updateDoc(r,{deletedAt:deleteField(),purgeAt:deleteField()});
 const accepted=writeBatch(db);accepted.set(rec,receipt());accepted.set(pay,ledger());await assertSucceeds(accepted.commit());
 const again=Date.now();await updateDoc(r,{deletedAt:again,purgeAt:again+60*86400000});
 const undo=writeBatch(db);undo.delete(rec);undo.delete(pay);await assertFails(undo.commit());
});

test('sharing preferences validate consent, email count and monthly date',async()=>{
 const profile=doc(alice(),'users/alice'),base={displayName:'Alice',email:'alice@example.com',currency:'EGP'};
 await assertSucceeds(setDoc(profile,{...base,sharingEnabled:true,shareDay:31,shareRecipients:['trusted@example.com']}));
 for(const patch of [{shareDay:32},{shareRecipients:[]},{shareRecipients:['not-an-email']},{shareRecipients:['bad space@example.com']},{shareRecipients:['bad\n@example.com']},{shareRecipients:Array(6).fill('a@example.com')}])await assertFails(updateDoc(profile,patch));
 await assertFails(updateDoc(profile,{resetInProgress:true}));
});
test('app reset hard deletes require the exact verified email, its own UID, a fresh sign-in, and a reset flag',async()=>{
 const at=Math.floor(Date.now()/1000),email='ebnramadan@gmail.com';
 await env.withSecurityRulesDisabled(async ctx=>{const db=ctx.firestore();await setDoc(doc(db,'users/tester'),{displayName:'Tester',email,currency:'USD'});await setDoc(doc(db,'users/tester/zakatRecords/r'),{...record(true),userId:'tester'});await setDoc(doc(db,'users/tester/payments/p'),{...payment(),userId:'tester'});});
 const fresh=env.authenticatedContext('tester',{email,email_verified:true,auth_time:at}).firestore();
 const stale=env.authenticatedContext('tester',{email,email_verified:true,auth_time:at-600}).firestore();
 const profile=doc(fresh,'users/tester'),r=doc(fresh,'users/tester/zakatRecords/r');
 await assertFails(deleteDoc(r));await assertFails(updateDoc(doc(stale,'users/tester'),{resetInProgress:true}));
 await assertSucceeds(updateDoc(profile,{resetInProgress:true,sharingEnabled:false,monthlyEmailReminders:false}));
 await assertFails(deleteDoc(doc(stale,'users/tester/zakatRecords/r')));
 await assertFails(deleteDoc(doc(alice(),'users/tester/zakatRecords/r')));
 await assertSucceeds(deleteDoc(r));await assertSucceeds(deleteDoc(doc(fresh,'users/tester/payments/p')));
 await assertSucceeds(setDoc(profile,{displayName:'Tester',email,currency:'USD',onboardingCompleted:false,resetInProgress:false}));
});
test('manual sheet requests require saved recipients, server time, rate limits, and cannot forge sent status',async()=>{
 const db=alice(),profile=doc(db,'users/alice'),at=Date.now();
 await setDoc(profile,{displayName:'Alice',email:'alice@example.com',currency:'EGP',shareRecipients:['trusted@example.com'],sharingEnabled:false});
 const request={id:'manual-request-123456',status:'queued',requestedAt:at,recipients:['trusted@example.com']};
 await assertFails(updateDoc(profile,{sheetRequest:{...request,status:'sent'}}));
 await assertFails(updateDoc(profile,{sheetRequest:{...request,recipients:['not-saved@example.com']}}));
 await assertSucceeds(updateDoc(profile,{sheetRequest:request}));
 await assertFails(updateDoc(profile,{sheetRequest:{...request,id:'different-request-123'}}));
 await env.withSecurityRulesDisabled(async ctx=>updateDoc(doc(ctx.firestore(),'users/alice'),{'sheetRequest.status':'sent'}));
 await assertFails(updateDoc(profile,{sheetRequest:{...request,id:'different-request-123'}}));
});
test('delayed requests retry with the same id and recipients, and cancellation cannot forge delivery',async()=>{
 const profile=doc(alice(),'users/alice'),at=Date.now(),old={id:'retry-request-123456',status:'queued',requestedAt:at-660000,recipients:['trusted@example.com']};
 await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),'users/alice'),{displayName:'Alice',email:'alice@example.com',currency:'EGP',shareRecipients:['trusted@example.com'],sheetRequest:old}));
 await assertFails(updateDoc(profile,{sheetRequest:{...old,id:'new-request-123456',requestedAt:at}}));
 await assertFails(updateDoc(profile,{sheetRequest:{...old,recipients:['new@example.com'],requestedAt:at}}));
 await assertSucceeds(updateDoc(profile,{sheetRequest:{...old,requestedAt:at}}));
 await assertFails(updateDoc(profile,{sheetRequest:{...old,requestedAt:at+1}}));
 await assertSucceeds(updateDoc(profile,{'sheetRequest.status':'cancelled'}));
 await assertFails(updateDoc(profile,{'sheetRequest.status':'sent'}));
});
