const {test}=require('node:test');const assert=require('node:assert/strict');const ExcelJS=require('exceljs');
const {eligible,buildWorkbook,sendProgressSheets}=require('../scripts/monthly-progress-sheet.cjs');
const now=new Date('2026-02-28T09:00:00Z');
test('monthly sheet dates clamp month end, require opt-in, and reject reset/invalid settings',()=>{
 const base={sharingEnabled:true,shareDay:31,shareRecipients:['trusted@example.com']};
 assert.equal(eligible(base,now),true);assert.equal(eligible({...base,resetInProgress:true},now),false);
 for(const patch of [{sharingEnabled:false},{shareDay:0},{shareDay:32},{shareRecipients:[]},{shareRecipients:['bad\n@example.com']}])assert.equal(eligible({...base,...patch},now),false);
});
test('workbook has useful tabs, separates currencies and Sadaqah, excludes recycled history, and stores text as text',async()=>{
 const data={records:[{id:'r',name:'=SUM(1,2)',currency:'EGP',totalWealth:10000,nisabMet:true,isSubmitted:true,hawlStartDate:1},{id:'trash',name:'Hidden',deletedAt:1,isSubmitted:true,totalWealth:99999,currency:'EGP'}],payments:[{zakatRecordId:'r',amount:100,date:1,recipient:'Family'},{zakatRecordId:'trash',amount:999,date:1}],monthlyPayments:[{kind:'sadaqah',month:'2026-02',currency:'USD',amount:20,recipient:'Friend',paidAt:1}],defaultRecordId:'r'};
 const buffer=await buildWorkbook(data,now), book=new ExcelJS.Workbook();await book.xlsx.load(buffer);
 assert.equal(book.worksheets.length,5);
 const records=book.getWorksheet('Zakat records');assert.equal(records.rowCount,2);assert.equal(records.getCell('A2').value,'=SUM(1,2)');assert.equal(records.getCell('F2').value,250);assert.equal(records.getCell('H2').value,150);
 assert.equal(book.getWorksheet('Zakat payments').rowCount,2);
 const overview=book.getWorksheet('Overview');assert.equal(overview.getCell('A2').value,'EGP');assert.equal(overview.getCell('E2').value,0);assert.equal(overview.getCell('A3').value,'USD');assert.equal(overview.getCell('E3').value,20);
});
test('scheduler dry run sends nothing; actual sends attach sheets and dedupe each recipient monthly',async()=>{
 assert.ok(process.env.FIRESTORE_EMULATOR_HOST,'Use emulators only');
 const {initializeApp,deleteApp}=require('firebase-admin/app'),{getFirestore}=require('firebase-admin/firestore');
 const app=initializeApp({projectId:'demo-progress-sharing'},'progress-sharing-test'),db=getFirestore(app);let sent=0;
 const user=db.doc('users/u'), settings={sharingEnabled:true,shareDay:31,shareRecipients:['trusted@example.com']};
 const transport={verify:async()=>{},sendMail:async message=>{assert.equal(message.to,'trusted@example.com');assert.ok(Buffer.isBuffer(message.attachments[0].content));sent++;return {messageId:'accepted',rejected:[]};}};
 const options={db,auth:{getUser:async()=>({emailVerified:true,email:'owner@example.com'})},now,smtpUser:'sender@gmail.com',smtpPassword:'fake',smtpTransport:transport,log:()=>{}};
 try{
  await db.recursiveDelete(db.collection('users'));await user.set(settings);
  await sendProgressSheets({...options,dryRun:true});assert.equal(sent,0);assert.equal((await user.collection('shareDeliveries').get()).size,0);
  await sendProgressSheets(options);await sendProgressSheets(options);assert.equal(sent,1);assert.equal((await user.collection('shareDeliveries').get()).size,1);
  await user.update({shareRecipients:['new@example.com'],resetInProgress:true});await sendProgressSheets(options);assert.equal(sent,1);
  await user.update({resetInProgress:false});await sendProgressSheets({...options,auth:{getUser:async()=>({emailVerified:false})}});assert.equal(sent,1);
 }finally{await db.recursiveDelete(db.collection('users'));await deleteApp(app);}
});
