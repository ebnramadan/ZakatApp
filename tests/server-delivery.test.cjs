const {test}=require('node:test'),assert=require('node:assert/strict');
const {processQueuedReport}=require('../functions/delivery.cjs');
const {sendProgressSheets}=require('../scripts/monthly-progress-sheet.cjs');
test('Firestore sender isolates the requesting user and duplicate events share a lease',async()=>{
 assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
 const {initializeApp,deleteApp}=require('firebase-admin/app'),{getFirestore}=require('firebase-admin/firestore');
 const app=initializeApp({projectId:'demo-server-delivery'},'server-delivery'),db=getFirestore(app);
 const request={id:'server-request-123456',status:'queued',requestedAt:Date.now(),recipients:['trusted@example.com']};
 const after={shareRecipients:request.recipients,sheetRequest:request};let sent=0,unlock,started;
 const start=new Promise(r=>started=r),gate=new Promise(r=>unlock=r);
 const auth={getUser:async()=>({emailVerified:true})};
 const deps={db,auth,send:async options=>{started();await gate;return sendProgressSheets({...options,smtpUser:'sender@gmail.com',smtpPassword:'fake',smtpTransport:{verify:async()=>{},sendMail:async()=>{sent++;return{messageId:'accepted',rejected:[]};}},log:()=>{}});}};
 try{
 await db.recursiveDelete(db.collection('users'));await db.doc('users/u').set(after);await db.doc('users/other').set(after);
 const first=processQueuedReport({after,uid:'u'},deps);await start;
 await assert.rejects(processQueuedReport({after,uid:'u'},deps),/delivery-in-progress/);
 unlock();await first;assert.equal(sent,1);
 assert.equal((await db.doc('users/other').get()).data().sheetRequest.status,'queued');
 await processQueuedReport({after,uid:'u'},deps);assert.equal(sent,1);
 assert.equal((await db.doc('users/u/mailLocks/server-request-123456').get()).data().leaseUntil,0);
 }finally{unlock?.();await db.recursiveDelete(db.collection('users'));await deleteApp(app);}
});
test('unrelated profile updates never trigger another send',async()=>{
 const after={sheetRequest:{id:'server-request-123456',status:'queued',requestedAt:1}};
 await processQueuedReport({before:after,after,uid:'u'},{db:null,send:()=>{throw Error('must not send');}});
});
