// 站点已移除 PWA。此前安装过 Service Worker 的浏览器会定期检查 /sw.js 更新，
// 这里提供一个自我注销的版本：清空 Workbox 缓存、注销自身并刷新已打开的页面。
// 若直接删除该文件（404），浏览器不会注销旧 Service Worker，读者会一直看到旧缓存。
self.addEventListener("install", () => self.skipWaiting());

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.map((key) => caches.delete(key)));
      await self.registration.unregister();
      const clients = await self.clients.matchAll({ type: "window" });
      clients.forEach((client) => client.navigate(client.url));
    })(),
  );
});
