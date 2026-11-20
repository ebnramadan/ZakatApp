const {test}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const bootstrap=readFileSync('web/flutter_bootstrap.js','utf8').replace('{{flutter_js}}','').replace('{{flutter_build_config}}','').replace('{{flutter_service_worker_version}}',JSON.stringify('release-qa'));
test('app starts before offline-cache registration and updates cache after the first frame',async()=>{
 const events={},stages=[],registered=[],scripts=[];let options,idle;
 const context=vm.createContext({window:{zakatStartup:{complete:n=>stages.push(n)},addEventListener:(type,fn)=>events[type]=fn,requestIdleCallback:fn=>idle=fn},navigator:{serviceWorker:{register:url=>{registered.push(url);return Promise.resolve()}}},document:{createElement:()=>({}),head:{appendChild:s=>scripts.push(s)}},_flutter:{buildConfig:{builds:[{mainJsPath:'main.dart.js'}]},loader:{load:value=>options=value}},setTimeout:fn=>fn()});
 vm.runInContext(bootstrap,context);
 assert.equal(registered.length,0);assert.equal(options.serviceWorkerSettings,undefined);
 assert.equal(options.config.canvasKitBaseUrl,'canvaskit/');
 await options.onEntrypointLoaded({initializeEngine:async()=>({runApp:async()=>stages.push('run')})});
 assert.deepEqual(stages,[1,2,'run']);assert.equal(registered.length,0);
 events['flutter-first-frame']();idle();assert.equal(registered.length,1);
 assert.match(registered[0],/release-qa/);
 assert.equal(context._flutter.buildConfig.builds[0].mainJsPath,'main.dart.js?app=release-qa');
 // An offline/stale-worker visit still has a cached, unversioned entrypoint fallback.
 events.error({target:{tagName:'SCRIPT',src:'https://example.com/main.dart.js?app=release-qa'}});
 assert.equal(scripts[0].src,'main.dart.js');
 events.error({target:{tagName:'SCRIPT',src:'https://example.com/main.dart.js?app=release-qa'}});
 assert.equal(scripts.length,1);
});
for(const ar of [false,true]){
 test(`startup progress changes only on completed milestones and rotates duaa (${ar?'Arabic':'English'})`,()=>{
  const html=readFileSync('web/index.html','utf8');
  const script=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]).find(s=>s.includes('window.zakatStartup ='));
  assert.ok(script);
  const nodes=new Map(),events={};let rotate,stopped=false;
  const node=id=>{if(!nodes.has(id))nodes.set(id,{setAttribute(){},remove(){this.removed=true}});return nodes.get(id)};
  const context=vm.createContext({window:{addEventListener:(kind,fn)=>events[kind]=fn},document:{getElementById:node},localStorage:{getItem:()=>JSON.stringify(ar?'ar':'en')},setInterval:fn=>{rotate=fn;return 1},clearInterval:()=>stopped=true,setTimeout:()=>2,clearTimeout(){}});
  vm.runInContext(script,context);
  assert.equal(node('startup-progress').value,0);
  const initial=node('startup-duaa').textContent;
  assert.match(initial,/اللهم/);
  assert.equal(initial.includes('O Allah'),!ar);
  rotate();assert.notEqual(node('startup-duaa').textContent,initial);
  assert.equal(node('startup-progress').value,0);
  context.window.zakatStartup.complete(2);assert.equal(node('startup-progress').value,2);
  assert.match(node('startup-percent').textContent,ar?/٥٠٪/:/50%/);
  context.window.zakatStartup.complete(1);assert.equal(node('startup-progress').value,2);
  context.window.zakatStartup.complete(4);assert.equal(node('startup-progress').value,4);
  events['flutter-first-frame']();assert.equal(stopped,true);assert.equal(node('app-loading').removed,true);
 });
}
test('first-visit background caching keeps engine/fonts but never private API responses',async()=>{
 const events={},stored=[],fetched=[];let idle;
 const context=vm.createContext({window:{addEventListener:(type,fn)=>events[type]=fn,requestIdleCallback:fn=>idle=fn,caches:{},performance:{}},navigator:{serviceWorker:{register:async()=>({active:{state:'activated'}})}},document:{createElement:()=>({}),head:{appendChild(){}}},_flutter:{buildConfig:{builds:[{mainJsPath:'main.dart.js'}]},loader:{load(){}}},caches:{open:async()=>({match:async()=>null,put:async url=>stored.push(url)})},performance:{getEntriesByType:()=>[
  {name:'https://ztracker.web.app/canvaskit/canvaskit.wasm'},
  {name:'https://ztracker.web.app/assets/assets/fonts/Inter-400.ttf'},
  {name:'https://ztracker.web.app/users/u/notifications'},
  {name:'https://firestore.googleapis.com/private'}
 ]},location:{origin:'https://ztracker.web.app'},URL,fetch:async(url,options)=>{assert.equal(options.cache,'force-cache');fetched.push(url);return {ok:true}},setTimeout,clearTimeout});
 vm.runInContext(bootstrap,context);events['flutter-first-frame']();await idle();
 assert.equal(stored.length,2);assert.deepEqual(stored,fetched);
 assert.equal(stored.some(url=>url.includes('notifications')||url.includes('firestore')),false);
});
