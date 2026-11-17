const {test} = require('node:test');
const assert = require('node:assert/strict');
const {duePlans, dueDate, composeMessage} = require('../scripts/monthly-reminders.cjs');
const now = new Date('2026-02-28T08:00:00Z');
const plan = (id, patch={}) => ({id, recipient:'A recipient', amount:100, currency:'USD', kind:'sadaqah', reminderDay:31, startMonth:'2026-01', active:true, ...patch});
test('due reminders clamp month-end and skip future, paused, paid and already-reminded recipients', () => {
  const plans = [plan('due'),plan('paid'),plan('sent'),plan('paused',{active:false}),plan('future',{startMonth:'2026-03'})];
  const due = duePlans(plans, [{planId:'paid',month:'2026-02'}], [{planId:'sent',month:'2026-02',status:'sent'}], now);
  assert.deepEqual(due.map(p=>p.id),['due']);
  assert.equal(dueDate(plan('p'), now),28);
});
test('a new month generates a new reminder without counting last month as paid', () => {
  const due = duePlans([plan('p',{reminderDay:1})],[{planId:'p',month:'2026-01'}],[{planId:'p',month:'2026-01',status:'sent'}],now);
  assert.equal(due.length,1);
});
test('message separates Zakat/Sadaqah, does not combine currencies, and offers an opt out', () => {
  const message = composeMessage([plan('s'),plan('z',{kind:'zakat',currency:'EGP',amount:500})], now, 'https://zakat-app-36c58.web.app');
  assert.match(message.text,/USD 100.00 \(Sadaqah\)/);
  assert.match(message.text,/EGP 500.00 \(Zakat\)/);
  assert.match(message.text,/turn off email reminders/);
  assert.match(message.text,/does not transfer money/);
});

const {sendReminders}=require('../scripts/monthly-reminders.cjs');
function memoryStore({plans=[],payments=[],deliveries=[],records={}}={}) {
 const state={plans,payments,deliveries,ready:false};
 const snapshot=items=>({docs:items.map(d=>({id:d.id,data:()=>d}))});
 const base={collection(name){
   const rows=()=>name==='monthlyPlans'?state.plans:name==='monthlyPayments'?state.payments:state.deliveries;
   return {get:async()=>snapshot(rows()),where:(field,op,value)=>({get:async()=>snapshot(rows().filter(r=>r[field]===value))}),doc:id=>({name,id,get:async()=>({exists:records[id]!=null,data:()=>records[id]})})};
 }};
 const db={
  collection:()=>({where:()=>({get:async()=>snapshot([{id:'u',monthlyEmailReminders:true,email:'untrusted-profile@example.com'}])}),doc:()=>base}),
  batch:()=>{const writes=[];return {set:(ref,data)=>writes.push({ref,data}),commit:async()=>{for(const {ref,data} of writes)state.deliveries.push({id:ref.id,...data});}};},
  doc:()=>({set:async data=>{state.ready=data.enabled===true;}}),
 };
 return {db,state};
}
test('email delivery uses verified Firebase Auth address and records deduplication receipts',async()=>{
 const {db,state}=memoryStore({plans:[plan('p')]});
 const calls=[];
 const options={db,auth:{getUser:async()=>({email:'verified-owner@example.com',emailVerified:true,disabled:false})},now,apiKey:'test-key',from:'sender@example.com',appUrl:'https://zakat-tracker.web.app',log:()=>{},fetchImpl:async(url,request)=>{calls.push(JSON.parse(request.body));return {ok:true,json:async()=>({id:'accepted-email'})};}};
 await sendReminders(options); await sendReminders(options);
 assert.equal(calls.length,1);
 assert.deepEqual(calls[0].to,['verified-owner@example.com']);
 assert.equal(state.deliveries[0].status,'sent');
 assert.equal(state.ready,true);
});
test('unverified or disabled accounts never receive reminder emails',async()=>{
 for(const account of [{email:'u@example.com',emailVerified:false},{email:'u@example.com',emailVerified:true,disabled:true}]){
  const {db}=memoryStore({plans:[plan('p')]});let sent=false;
  await sendReminders({db,auth:{getUser:async()=>account},now,apiKey:'test-key',from:'sender@example.com',appUrl:'https://zakat-tracker.web.app',log:()=>{},fetchImpl:async()=>{sent=true;throw Error('Must not send');}});
  assert.equal(sent,false);
 }
});
test('a rejected email is not marked sent and is eligible for a later retry',async()=>{
 const {db,state}=memoryStore({plans:[plan('p')]});
 await assert.rejects(sendReminders({db,auth:{getUser:async()=>({email:'u@example.com',emailVerified:true})},now,apiKey:'test-key',from:'sender@example.com',appUrl:'https://zakat-tracker.web.app',log:()=>{},fetchImpl:async()=>({ok:false,status:429})}));
 assert.equal(state.deliveries.length,0);
 assert.equal(state.ready,false);
});
test('Gmail transport uses the dedicated sender and only the verified recipient',async()=>{
 const {db,state}=memoryStore({plans:[plan('p')]});let verified=0;let delivered;
 const smtpTransport={verify:async()=>{verified++;},sendMail:async message=>{delivered=message;return {messageId:'smtp-accepted',rejected:[]};}};
 await sendReminders({db,auth:{getUser:async()=>({email:'verified@example.com',emailVerified:true})},now,smtpUser:'sender@gmail.com',smtpPassword:'test-app-password',smtpTransport,appUrl:'https://zakat-tracker.web.app',log:()=>{}});
 assert.equal(verified,1);
 assert.equal(delivered.from,'sender@gmail.com');
 assert.equal(delivered.to,'verified@example.com');
 assert.equal(state.deliveries[0].status,'sent');
});

test('Zakat email reminders skip recycled and missing records and resume after restoration',async()=>{
 const records={r:{isSubmitted:true,currency:'USD',deletedAt:123}};
 const {db}=memoryStore({plans:[plan('p',{kind:'zakat',zakatRecordId:'r'})],records});
 let sent=0;
 const options={db,auth:{getUser:async()=>({email:'verified@example.com',emailVerified:true})},now,apiKey:'key',from:'sender@example.com',appUrl:'https://zakat-tracker.web.app',log:()=>{},fetchImpl:async()=>{sent++;return {ok:true,json:async()=>({id:'accepted'})};}};
 await sendReminders(options);assert.equal(sent,0);
 delete records.r.deletedAt;
 await sendReminders(options);assert.equal(sent,1);
});
