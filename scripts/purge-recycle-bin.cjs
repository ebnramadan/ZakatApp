const {FieldPath} = require('firebase-admin/firestore');
const DAY = 86400000;
function expired(data, now) {
  return Number.isSafeInteger(data.deletedAt) && Number.isSafeInteger(data.purgeAt)
    && data.purgeAt === data.deletedAt + 60 * DAY && data.purgeAt <= now;
}
async function purgeRecycleBin(db, {now = Date.now(), apply = false, log = console.log} = {}) {
  let cursor, checked = 0, eligible = 0, removed = 0;
  const commit = async (operations) => {
    for (let i = 0; i < operations.length; i += 400) {
      const batch = db.batch();
      for (const [ref, fields] of operations.slice(i, i + 400)) {
        if (fields) batch.update(ref, fields); else batch.delete(ref);
      }
      await batch.commit();
    }
  };
  while (true) {
    let query = db.collectionGroup('zakatRecords').orderBy(FieldPath.documentId()).limit(200);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      if (!/^users\/[^/]+\/zakatRecords\/[^/]+$/.test(doc.ref.path)) continue;
      checked++;
      if (!expired(doc.data(), now)) continue;
      eligible++;
      if (!apply) continue;
      // At expiry clients cannot restore or mutate the record. Recheck before cleanup.
      const fresh = await doc.ref.get();
      if (!fresh.exists || !expired(fresh.data(), now)) continue;
      const base = doc.ref.parent.parent;
      const plans = await base.collection('monthlyPlans').where('zakatRecordId', '==', doc.id).get();
      await commit(plans.docs.map(d => [d.ref, {active: false}]));
      for (const collection of ['payments', 'monthlyPayments']) {
        // Delete bounded pages so large payment histories do not exceed write limits.
        while (true) {
          const children = await base.collection(collection).where('zakatRecordId', '==', doc.id).limit(400).get();
          if (children.empty) break;
          await commit(children.docs.map(d => [d.ref, null]));
        }
      }
      await db.recursiveDelete(doc.ref);
      removed++;
    }
    cursor = page.docs[page.docs.length - 1];
  }
  log(`${apply ? 'Cleanup' : 'Dry run'}: ${checked} records checked; ${eligible} expired; ${removed} permanently removed.`);
  return {checked, eligible, removed};
}
if (require.main === module) {
  const {initializeApp, applicationDefault} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  initializeApp({credential: applicationDefault(), projectId: 'zakat-app-36c58'});
  purgeRecycleBin(getFirestore(), {apply: process.argv.includes('--apply')})
    .catch(e => {console.error('Recycle cleanup failed:', e.code || 'unknown'); process.exitCode = 1;});
}
module.exports = {purgeRecycleBin, expired};
