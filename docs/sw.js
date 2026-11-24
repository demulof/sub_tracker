// Service Worker：把 app 本身的檔案存在手機上，沒有網路也能開啟。
// 策略：先用快取的版本（開啟很快），同時在背景下載新版，下次開啟就是新版。
// 修改檔案清單時記得把 VERSION 加 1，讓舊快取被清掉。
const VERSION = 'v1';
const CACHE = `sub-tracker-${VERSION}`;
const SHELL = [
  './',
  './index.html',
  './styles.css',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/apple-touch-icon.png',
  './js/app.js',
  './js/billing.js',
  './js/cloud.js',
  './js/config.js',
  './js/ics.js',
  './js/model.js',
  './js/rates.js',
  './js/store.js',
  './js/suggestions.js',
  './js/ui.js',
  './js/views/editor.js',
  './js/views/home.js',
  './js/views/login.js',
  './js/views/settings.js',
  './js/views/stats.js',
  './vendor/firebase.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k.startsWith('sub-tracker-') && k !== CACHE).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);
  // 只處理自己網站的 GET；Firebase、匯率 API 等外部連線一律直接走網路。
  if (req.method !== 'GET' || url.origin !== self.location.origin) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const key = req.mode === 'navigate' ? './index.html' : req;
    const cached = await cache.match(key, { ignoreSearch: true });
    const network = fetch(req).then((res) => {
      if (res.ok && res.type === 'basic') cache.put(key, res.clone());
      return res;
    }).catch(() => null);
    if (cached) {
      event.waitUntil(network);
      return cached;
    }
    return (await network) ?? new Response('目前離線，請連上網路後再試。', {
      status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    });
  })());
});
