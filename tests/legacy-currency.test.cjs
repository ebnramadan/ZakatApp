const {test} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {backfill} = require('../scripts/backfill-legacy-currency.cjs');
test('legacy repair preserves amounts, known currencies and other accounts; retries are harmless', async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Run only against the Firestore emulator');
  const app = initializeApp({projectId: 'demo-legacy-currency'}, 'legacy-repair-test');
  const db = getFirestore(app);
  try {
    await db.recursiveDelete(db.collection('users'));
    const missing = {name:'Old record',isSubmitted:true,zakatDue:95000,totalWealth:3800000,createdAt:123};
    const nullCurrency = {...missing,currency:null};
    const known = {...missing,currency:'USD'};
    const a = db.doc('users/a/zakatRecords/old');
    const b = db.doc('users/b/zakatRecords/old');
    const c = db.doc('users/b/zakatRecords/known');
    const p = db.doc('users/a/payments/existing');
    const payment = {amount:20000,zakatRecordId:'old',name:'Zakat Phase1'};
    await Promise.all([a.set(missing),b.set(nullCurrency),c.set(known),p.set(payment)]);
    const options = {log:()=>{}};
    assert.deepEqual(await backfill(db,options),{checked:3,missing:2,updated:0});
    assert.deepEqual((await a.get()).data(),missing);
    assert.deepEqual(await backfill(db,{...options,apply:true}),{checked:3,missing:2,updated:2});
    assert.deepEqual((await a.get()).data(),{...missing,currency:'EGP'});
    assert.deepEqual((await b.get()).data(),{...nullCurrency,currency:'EGP'});
    assert.deepEqual((await c.get()).data(),known);
    assert.deepEqual((await p.get()).data(),payment);
    assert.deepEqual(await backfill(db,{...options,apply:true}),{checked:3,missing:0,updated:0});
  } finally {
    await db.recursiveDelete(db.collection('users'));
    await deleteApp(app);
  }
});
