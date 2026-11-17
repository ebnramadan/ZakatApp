const { readFileSync } = require('node:fs');
const { before, after, beforeEach, test } = require('node:test');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, getDoc, writeBatch } = require('firebase/firestore');
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
  env = await initializeTestEnvironment({projectId: 'demo-zakat-app', firestore: {rules: readFileSync('firestore.rules', 'utf8')}});
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
