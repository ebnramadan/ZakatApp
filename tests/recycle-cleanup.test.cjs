const {test} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {purgeRecycleBin} = require('../scripts/purge-recycle-bin.cjs');
test('cleanup respects the 60-day boundary, removes only linked history, pauses plans and retries safely', async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  const app=initializeApp({projectId:'demo-recycle-cleanup'},'recycle-cleanup-test');
  const db=getFirestore(app), now=Date.now(), day=86400000;
  const old={deletedAt:now-60*day,purgeAt:now};
  const refs={expired:db.doc('users/a/zakatRecords/old'),valid:db.doc('users/a/zakatRecords/recent'),active:db.doc('users/b/zakatRecords/active')};
  try {
    await db.recursiveDelete(db.collection('users'));
    await Promise.all([refs.expired.set(old),refs.valid.set({deletedAt:now-59*day,purgeAt:now+day}),refs.active.set({currency:'USD'}),
      db.doc('users/a/payments/p').set({zakatRecordId:'old',amount:200}),
      db.doc('users/a/payments/keep').set({zakatRecordId:'recent',amount:100}),
      db.doc('users/a/monthlyPayments/m').set({zakatRecordId:'old',kind:'zakat'}),
      db.doc('users/a/monthlyPayments/s').set({zakatRecordId:'',kind:'sadaqah'}),
      db.doc('users/a/monthlyPlans/plan').set({zakatRecordId:'old',active:true})]);
    assert.deepEqual(await purgeRecycleBin(db,{now,log:()=>{}}),{checked:3,eligible:1,removed:0});
    assert.equal((await refs.expired.get()).exists,true);
    assert.deepEqual(await purgeRecycleBin(db,{now,apply:true,log:()=>{}}),{checked:3,eligible:1,removed:1});
    assert.equal((await refs.expired.get()).exists,false);
    assert.equal((await db.doc('users/a/payments/p').get()).exists,false);
    assert.equal((await db.doc('users/a/monthlyPayments/m').get()).exists,false);
    assert.equal((await db.doc('users/a/monthlyPlans/plan').get()).data().active,false);
    for(const ref of [refs.valid,refs.active,db.doc('users/a/payments/keep'),db.doc('users/a/monthlyPayments/s')])assert.equal((await ref.get()).exists,true);
    assert.deepEqual(await purgeRecycleBin(db,{now,apply:true,log:()=>{}}),{checked:2,eligible:0,removed:0});
  } finally {await db.recursiveDelete(db.collection('users'));await deleteApp(app);}
});
