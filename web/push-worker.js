/* Separate scope from Flutter's asset-cache worker. No Firebase billing or SDK required. */
'use strict';
const DB = 'ztracker-push-session';
let sessionQueue = Promise.resolve();
function stateStore(mode, action) {
  return new Promise((resolve, reject) => {
    const open = indexedDB.open(DB, 1);
    open.onupgradeneeded = () => open.result.createObjectStore('state');
    open.onerror = () => reject(open.error);
    open.onsuccess = () => {
      const db = open.result, tx = db.transaction('state', mode), store = tx.objectStore('state');
      const request = action(store); let result;
      request.onsuccess = () => { result = request.result; };
      tx.oncomplete = () => { db.close(); resolve(result); };
      tx.onerror = () => { db.close(); reject(tx.error); };
    };
  });
}
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
self.addEventListener('message', event => {
  if (event.data?.type !== 'push-session') return;
  sessionQueue = sessionQueue.catch(() => {}).then(async () => {
    const old = await stateStore('readonly', s => s.get('session'));
    const next = old?.uid === event.data.uid ? {...old, ...event.data} : {enabled: false, ...event.data};
    await stateStore('readwrite', s => s.put(next, 'session'));
    if (!next.enabled || old?.uid !== next.uid) {
      for (const notification of await self.registration.getNotifications()) {
        // A device test is not a reminder opt-in; retain it for the same account.
        if (old?.uid !== next.uid || notification.tag !== 'ztracker-test') notification.close();
      }
    }
    event.ports[0]?.postMessage({ok: true});
  });
  event.waitUntil(sessionQueue);
});
self.addEventListener('push', event => event.waitUntil((async () => {
  const state = await stateStore('readonly', s => s.get('session'));
  let message;
  try { message = event.data?.json(); } catch (_) { return; }
  if (!state?.enabled || !message || message.uid !== state.uid ||
      (message.kind === 'monthly' && !state.monthly) || (message.kind === 'zakat' && !state.zakat)) return;
  await self.registration.showNotification(message.title, {
    body: state.showNames ? message.body : message.genericBody,
    icon: '/icons/zakat-v4-192.png', badge: '/icons/zakat-v4-192.png',
    lang: message.language === 'ar' ? 'ar' : 'en', dir: message.language === 'ar' ? 'rtl' : 'ltr',
    tag: 'ztracker-giving-reminder', renotify: false,
    data: {target: message.kind === 'monthly' ? 'monthly' : 'tracker'},
  });
})()));
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const target = event.notification.data?.target === 'monthly' ? 'monthly' : 'tracker';
    const url = new URL('/?open=' + target, self.location.origin).href;
    const clients = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    const client = clients.find(c => new URL(c.url).origin === self.location.origin);
    if (client) { await client.navigate(url); await client.focus(); }
    else await self.clients.openWindow(url);
  })());
});
