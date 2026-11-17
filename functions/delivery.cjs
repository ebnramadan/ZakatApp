// Separate from the Firebase wrapper so isolation, event retries and leases can be tested.
async function processQueuedReport({before,after,uid},{db,auth,send,now=Date.now}) {
  const request=after?.sheetRequest;
  if(!request || request.status!=='queued' || after.resetInProgress || !/^[\w-]{16,80}$/.test(request.id))return;
  if(before?.sheetRequest?.id===request.id && before.sheetRequest.requestedAt===request.requestedAt && before.sheetRequest.status==='queued')return;
  const user=db.doc(`users/${uid}`),lock=user.collection('mailLocks').doc(request.id),at=now();
  const claimed=await db.runTransaction(async tx=>{
    const [current,lease]=await Promise.all([tx.get(user),tx.get(lock)]);
    const fresh=current.data()?.sheetRequest;
    if(current.data()?.resetInProgress || fresh?.id!==request.id || fresh?.requestedAt!==request.requestedAt || fresh?.status!=='queued')return false;
    if((lease.data()?.leaseUntil||0)>at)throw new Error('delivery-in-progress');
    tx.set(lock,{leaseUntil:at+180000,requestedAt:request.requestedAt});return true;
  });
  if(!claimed)return;
  try {await send({db,auth,userId:uid,manualOnly:true});}
  finally {await db.runTransaction(async tx=>{const lease=await tx.get(lock);if(lease.data()?.requestedAt===request.requestedAt)tx.set(lock,{leaseUntil:0,requestedAt:request.requestedAt,finishedAt:now()});});}
}
module.exports={processQueuedReport};
