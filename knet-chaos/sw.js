/* Offline shell; this worker owns only the Knet Chaos subdirectory. */
const VERSION = 'knet-chaos-20261016-2';
const FILES = [
  './', './index.html', './style.css', './app.js', './scene.js', './physics.js',
  './vendor/three.min.js', './assets/hero-bg.png', './assets/icon.svg',
  './assets/icon-180.png', './assets/icon-192.png', './assets/icon-512.png',
  './assets/icon-maskable.png', './manifest.webmanifest'
];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(VERSION).then(cache => cache.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith('knet-chaos-') && key !== VERSION).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin || !url.href.startsWith(self.registration.scope)) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).then(response => {
      if (response.ok) { const copy = response.clone(); caches.open(VERSION).then(cache => cache.put('./index.html', copy)); }
      return response;
    }).catch(() => caches.match('./index.html')));
    return;
  }
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request)));
});
