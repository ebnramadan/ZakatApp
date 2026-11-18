{{flutter_js}}
{{flutter_build_config}}

// Start the app immediately. Updating Flutter's offline cache must not hold
// the first screen behind a service-worker activation/network timeout.
const zakatRelease = {{flutter_service_worker_version}};
const zakatEntry = _flutter.buildConfig.builds.find(build => build.mainJsPath)?.mainJsPath;
if (zakatEntry) {
  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath) build.mainJsPath += '?app=' + zakatRelease;
  }
  let usedCachedEntry = false;
  window.addEventListener('error', event => {
    if (!usedCachedEntry && event.target?.tagName === 'SCRIPT' && event.target.src?.includes(zakatEntry + '?app=')) {
      usedCachedEntry = true;
      const cached = document.createElement('script');
      cached.src = zakatEntry;
      cached.onerror = () => window.zakatStartup?.fail();
      document.head.appendChild(cached);
    }
  }, true);
}
window.addEventListener('flutter-first-frame', () => {
  if (zakatRelease && 'serviceWorker' in navigator) {
    const updateCache = async () => {
      try {
        const registration = await navigator.serviceWorker.register('flutter_service_worker.js?v=' + zakatRelease);
        const worker = registration?.installing || registration?.waiting || registration?.active;
        if (worker && worker.state !== 'activated') {
          await new Promise(resolve => {
            const timeout = setTimeout(resolve, 10000);
            worker.addEventListener('statechange', () => {
              if (worker.state === 'activated' || worker.state === 'redundant') { clearTimeout(timeout); resolve(); }
            });
          });
        }
        // Preserve offline engine/font availability on the first visit too:
        // those resources loaded before the asset worker could intercept them.
        if (!worker || worker.state !== 'activated' || !window.caches || !window.performance) return;
        const cache = await caches.open('flutter-app-cache');
        const assets = new Set(performance.getEntriesByType('resource').map(entry => entry.name)
          .filter(name => { const url = new URL(name); return url.origin === location.origin && (url.pathname.includes('/canvaskit/') || url.pathname.includes('/assets/fonts/')); }));
        await Promise.allSettled([...assets].map(async url => {
          if (await cache.match(url)) return;
          const response = await fetch(url, {cache: 'force-cache'});
          if (response.ok) await cache.put(url, response);
        }));
      } catch (_) {}
    };
    if ('requestIdleCallback' in window) window.requestIdleCallback(updateCache, {timeout: 3000});
    else setTimeout(updateCache, 0);
  }
}, {once: true});
_flutter.loader.load({
  config: {canvasKitBaseUrl: 'canvaskit/'},
  onEntrypointLoaded: async engineInitializer => {
    window.zakatStartup?.complete(1);
    try {
      const runner = await engineInitializer.initializeEngine();
      window.zakatStartup?.complete(2);
      await runner.runApp();
    } catch (_) {
      window.zakatStartup?.fail();
    }
  }
});
