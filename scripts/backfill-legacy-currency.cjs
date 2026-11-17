// Explicit one-time repair: only missing base currencies become EGP.
// All existing financial fields and known currencies are preserved.
const {initializeApp, applicationDefault} = require('firebase-admin/app');
const {getFirestore, FieldPath} = require('firebase-admin/firestore');
async function backfill(db, {apply = false, log = console.log} = {}) {
  let cursor;
  let checked = 0;
  let missing = 0;
  let updated = 0;
  do {
    let query = db.collectionGroup('zakatRecords').orderBy(FieldPath.documentId()).limit(200);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      // Only actual account records, including old records without userId.
      if (!/^users\/[^/]+\/zakatRecords\/[^/]+$/.test(doc.ref.path)) continue;
      checked++;
      if (doc.data().currency != null) continue;
      missing++;
      if (apply) {
        const changed = await db.runTransaction(async tx => {
          const current = await tx.get(doc.ref);
          if (!current.exists || current.data().currency != null) return false;
          tx.update(doc.ref, {currency: 'EGP'});
          return true;
        });
        if (changed) updated++;
      }
    }
    cursor = page.docs[page.docs.length - 1];
  } while (true);
  log(`${apply ? 'Applied' : 'Dry run'}: ${checked} records checked; ${missing} missing currencies; ${updated} updated to EGP.`);
  return {checked, missing, updated};
}
if (require.main === module) {
  initializeApp({credential: applicationDefault(), projectId: 'zakat-app-36c58'});
  backfill(getFirestore(), {apply: process.argv.includes('--apply')})
    .catch(e => { console.error('Currency repair failed:', e.code || 'unknown'); process.exitCode = 1; });
}
module.exports = {backfill};
