// Magana PWA service worker: the app's screens load offline; the API never comes from cache.
// scripts/build-web.sh fills in VERSION and PRECACHE after `flutter build web`.
// Valid JavaScript before the build fills it in (debug builds): an empty precache.
const VERSION = 'dev';
const PRECACHE = [/*__MAGANA_PRECACHE__*/];
const CACHE = `magana-${VERSION}`;

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((k) => k.startsWith('magana-') && k !== CACHE).map((k) => caches.delete(k)),
      ))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  const scope = new URL(self.registration.scope);
  // The API (outside /app/) and other sites go straight to the network, never cached:
  // when the server can't be reached, the app says so out loud.
  if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) return;

  if (request.mode === 'navigate') {
    // Pages: the newest when online, the cached app when not.
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(new URL('index.html', scope), copy));
          return response;
        })
        .catch(() => caches.match(new URL('index.html', scope))),
    );
    return;
  }
  // App files: from the cache, else the network (and keep a copy).
  event.respondWith(
    caches.match(request, { ignoreSearch: true }).then((hit) => hit || fetch(request).then((response) => {
      if (response.ok) {
        const copy = response.clone();
        caches.open(CACHE).then((cache) => cache.put(request, copy));
      }
      return response;
    })),
  );
});
