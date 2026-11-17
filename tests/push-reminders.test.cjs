const {test}=require('node:test');
const assert=require('node:assert/strict');
const {GAP,localDay,validSubscription,lunarEnd,selectReminder,run}=require('../scripts/push-reminders.cjs');
const now=new Date('2026-11-17T10:00:00Z');
const subscription={userId:'u',endpoint:'https://web.push.apple.com/test-endpoint',keys:{p256dh:'A'.repeat(87),auth:'A'.repeat(22)},monthly:true,zakat:true,showNames:false,timeZone:'Africa/Cairo'};
const plan=(id,patch={})=>({id,recipient:'Family '+id,amount:100,currency:'EGP',kind:'sadaqah',startMonth:'2026-01',reminderDay:1,active:true,...patch});
const record={id:'r',isSubmitted:true,nisabMet:true,totalWealth:10000,createdAt:1,hawlStartDate:Date.parse('2024-03-11T12:00:00Z'),currency:'EGP'};
const options=patch=>({profile:{language:'ar',defaultRecordId:'r'},subscription,plans:[],records:[],now,...patch});
test('only recognized HTTPS push-provider endpoints and valid key shapes are accepted',()=>{
 assert.equal(validSubscription(subscription),true);
 for(const endpoint of ['http://web.push.apple.com/token','https://127.0.0.1/token','https://fcm.googleapis.com.evil.example/token','https://user@fcm.googleapis.com/token','https://fcm.googleapis.com:4433/token'])assert.equal(validSubscription({...subscription,endpoint}),false);
 assert.equal(validSubscription({...subscription,keys:{p256dh:'short',auth:'bad'}}),false);
});
test('local day respects timezone and lunar Hawl follows Umm al-Qura rather than a Gregorian year',()=>{
 assert.equal(localDay(new Date('2026-01-31T23:00:00Z'),'Africa/Cairo').month,'2026-02');
 assert.equal(lunarEnd(Date.parse('2024-03-11T12:00:00Z'),'Africa/Cairo'),'2025-03-01');
 assert.equal(selectReminder(options({plans:[plan('p')],now:new Date('2026-11-17T23:00:00Z')})),null);
});
test('monthly digest excludes paid, future, paused and recycled-record recipients',()=>{
 const message=selectReminder(options({plans:[plan('due'),plan('paid'),plan('future',{startMonth:'2027-01'}),plan('paused',{active:false}),plan('deleted',{kind:'zakat',zakatRecordId:'r'})],monthlyPayments:[{planId:'paid',month:'2026-11'}],records:[{...record,deletedAt:1}]}));
 assert.equal(message.kind,'monthly');assert.match(message.body,/Family due/);
 for(const skipped of ['paid','future','paused','deleted'])assert.equal(message.body.includes('Family '+skipped),false);
 assert.equal(message.genericBody.includes('Family'),false);
});
test('short months clamp reminders and never mark an unpaid plan paid',()=>{
 const message=selectReminder(options({plans:[plan('p',{reminderDay:31})],now:new Date('2026-02-28T10:00:00Z')}));
 assert.equal(message.kind,'monthly');
});
test('Zakat only uses the default active record, respects actual payments and below-Nisab records',()=>{
 const message=selectReminder(options({records:[record]}));
 assert.equal(message.kind,'zakat');assert.match(message.body,/لله/);
 for(const change of [{records:[{...record,nisabMet:false}]},{records:[{...record,isSubmitted:false}]},{records:[{...record,deletedAt:1}]},{records:[record],payments:[{zakatRecordId:'r',amount:250}]}])assert.equal(selectReminder(options(change)),null);
 assert.equal(selectReminder(options({records:[record],payments:[{zakatRecordId:'other',amount:250}]})).kind,'zakat');
});
test('one combined reminder respects per-device opt-outs and reset status',()=>{
 const both=selectReminder(options({records:[record],plans:[plan('p')]}));assert.equal(both.kind,'monthly');assert.match(both.body,/زكاة/);
 assert.equal(selectReminder(options({records:[record],plans:[plan('p')],subscription:{...subscription,monthly:false,zakat:false}})),null);
 assert.equal(selectReminder(options({records:[record],profile:{resetInProgress:true}})),null);
});
function memory(seed) {
 const state=new Map(Object.entries(seed).map(([k,v])=>[k,structuredClone(v)]));let lock=Promise.resolve();
 function ref(path) {
  const result={path,id:path.split('/').at(-1),get:async()=>({id:path.split('/').at(-1),ref:result,exists:state.has(path),data:()=>structuredClone(state.get(path))}),set:async(data,opts)=>state.set(path,opts?.merge?{...state.get(path),...structuredClone(data)}:structuredClone(data)),delete:async()=>state.delete(path),collection:name=>collection(path+'/'+name)};
  Object.defineProperty(result,'parent',{get:()=>collection(path.split('/').slice(0,-1).join('/'))});return result;
 }
 function collection(path) {
  const result={id:path.split('/').at(-1),doc:id=>ref(path+'/'+id),get:async()=>({docs:await Promise.all([...state.keys()].filter(k=>k.startsWith(path+'/')&&!k.slice(path.length+1).includes('/')).map(k=>ref(k).get()))}),where:(field,op,value)=>({get:async()=>({docs:(await result.get()).docs.filter(d=>d.data()[field]===value)})})};
  Object.defineProperty(result,'parent',{get:()=>path.includes('/')?ref(path.split('/').slice(0,-1).join('/')):null});return result;
 }
 const db={doc:ref,collection,collectionGroup:name=>({get:async()=>({docs:await Promise.all([...state.keys()].filter(k=>k.split('/').at(-2)===name).map(k=>ref(k).get()))})}),runTransaction:fn=>{const task=lock.then(()=>fn({get:r=>r.get(),set:(r,d)=>r.set(d)}));lock=task.catch(()=>{});return task;}};
 return {db,state};
}
function fixture(patch={}) {
 const {db,state}=memory({'users/u':{language:'ar',defaultRecordId:'r'},'users/u/pushSubscriptions/device':subscription,'users/u/monthlyPlans/p':plan('p'),...patch});
 const messages=[];const webPush={generateVAPIDKeys:()=>({publicKey:'test-public',privateKey:'test-private'}),setVapidDetails:()=>{},sendNotification:async(s,payload)=>{messages.push(JSON.parse(payload));return {statusCode:201};}};
 return {db,state,messages,webPush,auth:{getUser:async()=>({emailVerified:true,disabled:false})},now,log:()=>{}};
}
test('server sends encrypted-provider payload with no names unless opted in; keys remain server-only',async()=>{
 const f=fixture();await run({...f,scheduled:true});
 assert.equal(f.messages.length,1);assert.equal(f.messages[0].uid,'u');assert.equal(f.messages[0].body.includes('Family'),false);
 assert.equal(f.state.get('appConfig/push').privateKey,undefined);assert.equal(f.state.get('_system/webPushKeys').privateKey,'test-private');
 assert.equal(f.state.get('appConfig/push').scheduledAt,now.getTime());
});
test('overlapping runs and retries produce one reminder, then wait four days',async()=>{
 const f=fixture();await Promise.all([run(f),run(f)]);assert.equal(f.messages.length,1);
 await run({...f,now:new Date(now.getTime()+3*86400000)});assert.equal(f.messages.length,1);
 await run({...f,now:new Date(now.getTime()+GAP)});assert.equal(f.messages.length,2);
});
test('paid months, unverified accounts and dry runs do not send; manual runs do not claim scheduler readiness',async()=>{
 for(const patch of [{dryRun:true},{auth:{getUser:async()=>({emailVerified:false})}}]) {
  const f=fixture();await run({...f,...patch});assert.equal(f.messages.length,0);assert.equal(f.state.get('appConfig/push').scheduledAt,undefined);
 }
 const paid=fixture({'users/u/monthlyPayments/p_2026-11':{planId:'p',month:'2026-11'}});await run(paid);assert.equal(paid.messages.length,0);
});
test('expired subscriptions are removed and failures do not count as accepted',async()=>{
 const f=fixture();f.webPush.sendNotification=async()=>{throw {statusCode:410};};
 await assert.rejects(run(f));assert.equal(f.state.has('users/u/pushSubscriptions/device'),false);
 assert.equal(f.state.get('users/u/pushDeliveries/device').status,'failed');
});

test('service worker hides names and rejects stale-account notifications even if an old endpoint is queued',async()=>{
 const vm=require('node:vm'),{readFileSync}=require('node:fs');
 const handlers={},shown=[];let state={uid:'u',enabled:true,monthly:true,zakat:true,showNames:false};
 const context=vm.createContext({self:{addEventListener:(kind,fn)=>handlers[kind]=fn,registration:{showNotification:async(title,options)=>shown.push(options)}},URL});
 vm.runInContext(readFileSync('web/push-worker.js','utf8'),context);
 context.readState=()=>state;
 vm.runInContext('stateStore = async () => readState()',context);
 const deliver=async message=>{let work;handlers.push({data:{json:()=>message},waitUntil:p=>work=p});await work;};
 const payload={uid:'u',kind:'monthly',title:'Giving',body:'Private recipient',genericBody:'Monthly giving is due',language:'ar'};
 await deliver(payload);assert.equal(shown[0].body,'Monthly giving is due');assert.equal(shown[0].dir,'rtl');
 state={...state,uid:'other'};await deliver(payload);assert.equal(shown.length,1);
 state={...state,uid:'u',enabled:false};await deliver(payload);assert.equal(shown.length,1);
});
