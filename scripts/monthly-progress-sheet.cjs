const ExcelJS = require('exceljs');
const arabic=require('../assets/translations/ar.json');
const crypto = require('node:crypto');
const {createSender, monthKey} = require('./monthly-reminders.cjs');
const emailPattern = /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/;
const amount = v => Number.isFinite(v) && v >= 0 ? v : 0;
const date = v => Number.isFinite(v) ? new Date(v).toISOString().slice(0,10) : '';
function eligible(profile, now) {
  const last = new Date(Date.UTC(now.getUTCFullYear(),now.getUTCMonth()+1,0)).getUTCDate();
  return profile.sharingEnabled === true && profile.resetInProgress !== true && Number.isInteger(profile.shareDay)
    && profile.shareDay >= 1 && profile.shareDay <= 31 && now.getUTCDate() >= Math.min(profile.shareDay,last)
    && Array.isArray(profile.shareRecipients) && profile.shareRecipients.length >= 1 && profile.shareRecipients.length <= 5
    && profile.shareRecipients.every(e => typeof e === 'string' && e.length <= 254 && emailPattern.test(e));
}
async function buildWorkbook({records=[],payments=[],plans=[],monthlyPayments=[],owner='Zakat Tracker',defaultRecordId='',language='en'}, now) {
  const ar=language==='ar',t=s=>ar?(arabic[s]||s):s;
  const workbook = new ExcelJS.Workbook();workbook.creator='Zakat Tracker';workbook.created=now;
  const active=records.filter(r=>r.deletedAt==null), submitted=active.filter(r=>r.isSubmitted===true);
  const ids=new Set(submitted.map(r=>r.id)), names=new Map(active.map(r=>[r.id,r.name]));
  const ledger=payments.filter(p=>ids.has(p.zakatRecordId));
  const receipts=monthlyPayments.filter(p=>p.kind==='sadaqah'||ids.has(p.zakatRecordId));
  const paid=new Map();for(const p of ledger)paid.set(p.zakatRecordId,(paid.get(p.zakatRecordId)||0)+amount(p.amount));
  const totals=new Map();
  for(const r of submitted){const code=r.currency||'Unspecified';if(!totals.has(code))totals.set(code,{calculated:0,given:0,remaining:0,sadaqah:0});const t=totals.get(code), target=r.nisabMet===true?amount(r.totalWealth)*.025:0, given=paid.get(r.id)||0;t.calculated+=target;t.given+=given;t.remaining+=Math.max(0,target-given);}
  for(const p of receipts.filter(p=>p.kind==='sadaqah'&&p.month===monthKey(now))){if(!totals.has(p.currency))totals.set(p.currency,{calculated:0,given:0,remaining:0,sadaqah:0});totals.get(p.currency).sadaqah+=amount(p.amount);}
  function table(name, headers, rows) {
    const sheet=workbook.addWorksheet(t(name),{views:[{state:'frozen',ySplit:1,rightToLeft:ar}]});
    sheet.columns=headers.map(header=>({header:t(header),key:header,width:header.includes('Amount')||header.includes('Remaining')?21:26}));
    for(const row of rows)sheet.addRow(row.map((value,index)=>['Default','Status','Source','Type','This month'].includes(headers[index])&&typeof value==='string'?t(value):value));
    sheet.getRow(1).eachCell(c=>{c.font={bold:true,color:{argb:'FFFFFFFF'}};c.fill={type:'pattern',pattern:'solid',fgColor:{argb:'FF146356'}};c.alignment={vertical:'middle',wrapText:true};});
    sheet.getRow(1).height=32;sheet.autoFilter={from:{row:1,column:1},to:{row:Math.max(1,rows.length+1),column:headers.length}};
    sheet.eachRow((row,index)=>{if(index>1)row.eachCell(cell=>{if(typeof cell.value==='number'){let digits=2;const code=row.getCell(headers.indexOf('Currency')+1).value;if(typeof code==='string'&&/^[A-Z]{3}$/.test(code))digits=new Intl.NumberFormat('en',{style:'currency',currency:code}).resolvedOptions().maximumFractionDigits;cell.numFmt='#,##0'+(digits?'.'+'0'.repeat(digits):'');}cell.alignment={vertical:'top',wrapText:true};});});
    return sheet;
  }
  const overview=table('Overview',['Currency','Calculated Zakat','Given toward Zakat','Remaining calculated Zakat','Sadaqah given this month'],[...totals].sort().map(([c,t])=>[c,t.calculated,t.given,t.remaining,t.sadaqah]));
  overview.addRow([]);overview.addRow([t('Prepared for'),owner]);overview.addRow([t('Snapshot (UTC)'),now.toISOString()]);
  overview.addRow([t('How to read'),ar?'مبالغ الزكاة أهداف محسوبة وليست إقرارًا باكتمال الحول. راجع كل سجل في التطبيق. لا تُخصم الصدقة من الزكاة، وتُستبعد السجلات الموجودة في سلة المحذوفات.':'Zakat figures are calculated targets, not a ruling that Hawl is complete. Check each record in the app. Sadaqah never reduces Zakat. Recycled records are excluded.']);
  table('Zakat records',['Record','Default','Status','Currency','Hawl start (UTC)','Calculated Zakat','Given','Remaining','Progress'],active.map(r=>{const target=r.isSubmitted&&r.nisabMet?amount(r.totalWealth)*.025:0, given=paid.get(r.id)||0;return [String(r.name||''),r.id===defaultRecordId?'Yes':'',r.isSubmitted?'Submitted':'Draft',r.currency||'Unspecified',date(r.hawlStartDate),target,given,Math.max(0,target-given),target>0?Math.min(1,given/target):0];}));
  workbook.getWorksheet(t('Zakat records')).getColumn(9).numFmt='0.0%';
  table('Zakat payments',['Record','Date (UTC)','Recipient','Payment name','Currency','Amount','Source'],ledger.sort((a,b)=>b.date-a.date).map(p=>[names.get(p.zakatRecordId)||'',date(p.date),String(p.recipient||''),String(p.name||''),submitted.find(r=>r.id===p.zakatRecordId)?.currency||'Unspecified',amount(p.amount),p.source==='monthly'?'Monthly giving':'Manual']));
  const commitments=table('Monthly commitments',['Recipient','Type','Currency','Amount per month','Reminder day','Status','Zakat record','Given this month','This month'],plans.filter(p=>p.kind==='sadaqah'||ids.has(p.zakatRecordId)).map(p=>[String(p.recipient||''),p.kind==='zakat'?'Zakat':'Sadaqah',p.currency,amount(p.amount),p.reminderDay,p.active?'Active':'Paused',names.get(p.zakatRecordId)||'',amount(receipts.find(r=>r.planId===p.id&&r.month===monthKey(now))?.amount),receipts.some(r=>r.planId===p.id&&r.month===monthKey(now))?'Paid':!p.active?'Paused':p.startMonth>monthKey(now)?'Not started':'Not yet paid']));
  commitments.getColumn(5).numFmt='0';
  table('Monthly payments',['Month','Paid date (UTC)','Recipient','Type','Currency','Amount','Zakat record'],receipts.sort((a,b)=>b.paidAt-a.paidAt).map(p=>[p.month,date(p.paidAt),String(p.recipient||''),p.kind==='zakat'?'Zakat':'Sadaqah',p.currency,amount(p.amount),names.get(p.zakatRecordId)||'']));
  return Buffer.from(await workbook.xlsx.writeBuffer());
}
async function requestStatus(db, ref, id, status, completedAt) {
  await db.runTransaction(async tx=>{const fresh=(await tx.get(ref)).data();if(fresh?.sheetRequest?.id===id)tx.update(ref,{'sheetRequest.status':status,...(completedAt?{'sheetRequest.completedAt':completedAt}:{})});});
}
async function sendProgressSheets({db,auth,now=new Date(),dryRun=false,manualOnly=false,log=console.log,...senderOptions}) {
  let sender;
  const users=await db.collection('users').where(manualOnly?'sheetRequest.status':'sharingEnabled','==',manualOnly?'queued':true).get();
  let sent=0,failed=0,eligibleAccounts=0;
  for(const user of users.docs){let requestId;try{
    const profile=user.data();const request=profile.sheetRequest;requestId=request?.id;
    const valid=(p)=>eligible({...p,sharingEnabled:true,shareDay:1},now);
    if(manualOnly){if(!request||request.status!=='queued')continue;if(request.requestedAt<now.getTime()-86400000){if(!dryRun)await requestStatus(db,user.ref,requestId,'failed');continue;}if(!valid(profile)){if(!dryRun)await requestStatus(db,user.ref,requestId,'cancelled');continue;}}
    else if(!eligible(profile,now))continue;
    const account=await auth.getUser(user.id);if(!account.emailVerified||account.disabled){if(manualOnly&&!dryRun)await requestStatus(db,user.ref,requestId,'cancelled');continue;}
    eligibleAccounts++;
    const recipients=[...new Set((manualOnly?request.recipients:profile.shareRecipients).map(e=>e.toLowerCase()))].filter(e=>profile.shareRecipients.map(e=>e.toLowerCase()).includes(e));
    const pending=[];
    for(const email of recipients){const key=`${manualOnly?'manual_'+request.id:monthKey(now)}_${crypto.createHash('sha256').update(email).digest('hex')}`,ref=user.ref.collection('shareDeliveries').doc(key);if(!(await ref.get()).exists)pending.push({email,key,ref});}
    if(!pending.length){if(manualOnly&&!dryRun)await requestStatus(db,user.ref,requestId,recipients.length?'sent':'cancelled');continue;}
    if(dryRun){log(`Would send ${pending.length} monthly progress sheet(s); account and recipients omitted.`);continue;}
    sender ??= await createSender(senderOptions);
    const [r,p,plans,m]=await Promise.all(['zakatRecords','payments','monthlyPlans','monthlyPayments'].map(name=>user.ref.collection(name).get()));
    const rows=s=>s.docs.map(d=>({id:d.id,...d.data()}));
    const content=await buildWorkbook({records:rows(r),payments:rows(p),plans:rows(plans),monthlyPayments:rows(m),owner:account.displayName||'Account owner',defaultRecordId:profile.defaultRecordId,language:profile.language},now);
    if(content.length>15*1024*1024)throw new Error('sheet-too-large');
    let completed=recipients.length-pending.length;
    for(const recipient of pending){
      // Recheck consent immediately before each external send, including reset/recipient changes.
      const fresh=(await user.ref.get()).data();
      if(!(manualOnly?valid(fresh)&&fresh.sheetRequest?.id===request.id&&fresh.sheetRequest?.status==='queued':eligible(fresh,now))||!fresh.shareRecipients.map(e=>e.toLowerCase()).includes(recipient.email))continue;
      const key=crypto.createHash('sha256').update(`${user.id}:${recipient.key}`).digest('hex');
      const providerId=await sender.send(recipient.email,{subject:`${profile.language==='ar'?'تقرير العطاء الشهري':'Monthly giving progress'} · ${monthKey(now)}`,
        text:profile.language==='ar'?`اختار ${account.displayName||'مستخدم متتبع الزكاة'} مشاركة تقرير عطائه معك.\n\nيتضمن ملف Excel المرفق سجلات الزكاة والدفعات والشهريات والصدقة، وهو نسخة وليس دخولًا مباشرًا للحساب. تظل العملات منفصلة، ويجب مراجعة الحول قبل أداء الزكاة.\n\nيمكن لصاحب الحساب إيقاف المشاركة من الملف الشخصي ← تقرير التقدم الشهري.`:`${account.displayName||'A Zakat Tracker user'} has chosen to share this progress sheet with you.\n\nThe attached Excel workbook is a snapshot of Zakat records, recorded payments, and monthly Zakat/Sadaqah giving. It is not live account access. Amounts stay in their original currencies; estimates must be checked against Hawl.\n\nSent with the account owner's monthly sharing preference. The owner can stop future sharing in Profile → Monthly progress sheet.`,
        attachments:[{filename:`zakat-progress-${monthKey(now)}.xlsx`,content,contentType:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'}]},`progress-${key}`);
      await recipient.ref.set({month:monthKey(now),status:'sent',acceptedAt:now.getTime(),providerId});sent++;completed++;
    }
    if(manualOnly){const fresh=(await user.ref.get()).data();if(fresh.sheetRequest?.id===request.id)await requestStatus(db,user.ref,requestId,completed?'sent':'cancelled',now.getTime());}
  }catch(_){if(manualOnly&&!dryRun)await requestStatus(db,user.ref,requestId,'failed');failed++;log('A progress-sheet account could not be processed; details omitted.');}}
  log(`${dryRun?'Dry run':'Progress sharing'} complete: ${eligibleAccounts} eligible accounts; ${sent} sheets accepted; ${failed} failed.`);
  if(failed)throw new Error('Some progress sheets failed. Check workflow configuration.');
  return {sent,failed,eligibleAccounts};
}
if(require.main===module){const {initializeApp,applicationDefault}=require('firebase-admin/app');const {getFirestore}=require('firebase-admin/firestore');const {getAuth}=require('firebase-admin/auth');initializeApp({credential:applicationDefault(),projectId:'zakat-app-36c58'});
  sendProgressSheets({db:getFirestore(),auth:getAuth(),smtpUser:process.env.REMINDER_SMTP_USER,smtpPassword:process.env.REMINDER_SMTP_APP_PASSWORD,apiKey:process.env.RESEND_API_KEY,from:process.env.REMINDER_FROM,dryRun:process.argv.includes('--dry-run'),manualOnly:process.argv.includes('--requests')}).catch(()=>{console.error('Monthly progress sharing failed.');process.exitCode=1;});}
module.exports={eligible,buildWorkbook,sendProgressSheets};
