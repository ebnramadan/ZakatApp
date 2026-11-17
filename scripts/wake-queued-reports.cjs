// One-time activation bridge: only requests explicitly queued within the last day.
const {initializeApp,applicationDefault}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
(async()=>{
 initializeApp({credential:applicationDefault(),projectId:'zakat-app-36c58'});
 const db=getFirestore(),requests=await db.collection('users').where('sheetRequest.status','==','queued').limit(500).get();let woken=0;
 for(const doc of requests.docs){const activated=await db.runTransaction(async tx=>{
   const profile=(await tx.get(doc.ref)).data(),request=profile?.sheetRequest;
   if(profile?.resetInProgress||request?.status!=='queued')return;
   if(typeof request.requestedAt!=='number'||Date.now()-request.requestedAt>86400000){tx.update(doc.ref,{'sheetRequest.status':'failed'});return;}
   tx.update(doc.ref,{'sheetRequest.requestedAt':Math.max(Date.now(),request.requestedAt+1)});return true;
 });if(activated)woken++;}
 console.log(`Activated ${woken} queued report requests; account details omitted.`);
})().catch(()=>{console.error('Could not activate queued reports. Retry from the app after backend deployment.');process.exitCode=1;});
