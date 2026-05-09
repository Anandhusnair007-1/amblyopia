/* global workbox */
// Workbox-powered SW:
// - Cache first: static assets (JS/CSS/fonts/icons)
// - Network first: /api/* calls
// - Offline fallback: /offline.html
// - Background sync queue: "sync-sessions" for session + result POSTs

importScripts("https://storage.googleapis.com/workbox-cdn/releases/6.5.4/workbox-sw.js");

const OFFLINE_URL = "/offline.html";

// If Workbox fails to load (very restricted networks), keep the app usable.
if (!self.workbox) {
  self.addEventListener("fetch", (event) => {
    const req = event.request;
    if (req.mode === "navigate") {
      event.respondWith(fetch(req).catch(() => caches.match(OFFLINE_URL)));
    }
  });
} else {
  workbox.setConfig({ debug: false });

  // Precache minimal shell.
  workbox.precaching.precacheAndRoute(
    [
      { url: "/", revision: null },
      { url: "/manifest.json", revision: null },
      { url: "/icon-192.svg", revision: null },
      { url: "/icon-512.svg", revision: null },
      { url: OFFLINE_URL, revision: null },
    ],
    { ignoreURLParametersMatching: [/.*/] }
  );

  // SPA navigation: network-first, fallback to offline page.
  workbox.routing.registerRoute(
    ({ request }) => request.mode === "navigate",
    new workbox.strategies.NetworkFirst({
      cacheName: "html-pages",
      networkTimeoutSeconds: 5,
      plugins: [
        new workbox.expiration.ExpirationPlugin({
          maxEntries: 20,
          maxAgeSeconds: 60 * 60 * 24 * 7,
        }),
      ],
    })
  );

  // API: network-first for GETs.
  workbox.routing.registerRoute(
    ({ url, request }) => url.pathname.startsWith("/api/") && request.method === "GET",
    new workbox.strategies.NetworkFirst({
      cacheName: "api-get",
      networkTimeoutSeconds: 6,
    })
  );

  // Background sync: queue failed session/result POSTs.
  const syncSessions = new workbox.backgroundSync.BackgroundSyncPlugin("sync-sessions", {
    maxRetentionTime: 24 * 60, // minutes
  });

  // Session create
  workbox.routing.registerRoute(
    ({ url, request }) => url.pathname === "/api/sessions" && request.method === "POST",
    new workbox.strategies.NetworkOnly({ plugins: [syncSessions] }),
    "POST"
  );

  // Result submit
  workbox.routing.registerRoute(
    ({ url, request }) =>
      /^\/api\/sessions\/[^/]+\/results$/.test(url.pathname) && request.method === "POST",
    new workbox.strategies.NetworkOnly({ plugins: [syncSessions] }),
    "POST"
  );

  // Static assets cache-first.
  workbox.routing.registerRoute(
    ({ request, url }) =>
      request.destination === "script" ||
      request.destination === "style" ||
      request.destination === "font" ||
      request.destination === "image" ||
      url.pathname.startsWith("/static/"),
    new workbox.strategies.CacheFirst({
      cacheName: "static-assets",
      plugins: [
        new workbox.expiration.ExpirationPlugin({
          maxEntries: 200,
          maxAgeSeconds: 60 * 60 * 24 * 30,
        }),
      ],
    })
  );

  // Offline fallback for navigation requests if NetworkFirst fails.
  workbox.routing.setCatchHandler(async ({ event }) => {
    if (event.request && event.request.mode === "navigate") {
      return caches.match(OFFLINE_URL);
    }
    return Response.error();
  });
}
