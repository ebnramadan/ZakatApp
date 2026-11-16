const { readFileSync } = require('node:fs');
const { before, after, beforeEach, test } = require('node:test');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, getDoc } = require('firebase/firestore');
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
const alice = () => env.authenticatedContext('alice').firestore();
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
