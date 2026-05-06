# Browser Extensions — Segurança

> Manifest v3 (Chrome/Edge/Firefox) e Safari Web Extensions. Lente: extensão é código privilegiado a correr em todo o browser do utilizador — qualquer falha = comprometimento total.

## Quando carregar

- `manifest.json` na raiz do projeto
- `manifest_version: 3` (atual padrão Chrome/Edge desde 2024)
- Pastas típicas: `background/`, `content_scripts/`, `popup/`, `options/`

## Mindset

- **Privilégio escalado:** content scripts injetados em todas as páginas que casam com `matches` têm acesso ao DOM completo
- **Background = service worker** (não persistente em MV3) — não podes confiar em estado em memória
- **Mensagens entre contextos** (popup ↔ background ↔ content script) são canal de ataque
- **Permissions excessivas** revistas pela Chrome Web Store mas aprovadas se justificadas
- **Atualizações silenciosas** — extensão pode mudar comportamento sem o user reinstalar

## 8 categorias de vulnerabilidades

### 1. Permissions over-broad

**BAD** — manifest.json:
```json
{
  "permissions": ["<all_urls>", "tabs", "storage", "cookies"],
  "host_permissions": ["*://*/*"]
}
```

**GOOD** — pedir só o necessário, com `activeTab` em vez de `<all_urls>`:
```json
{
  "permissions": ["activeTab", "storage"],
  "host_permissions": ["https://api.minha-app.com/*"],
  "optional_permissions": ["downloads"]
}
```

`activeTab` só dá acesso à tab atual quando o user clica no ícone — muito mais seguro.

### 2. Content scripts vulneráveis a XSS da página

**BAD** — content script faz `innerHTML` com dados da página:
```javascript
const userInput = document.querySelector('#search').value;
extensionUI.innerHTML = `<div>Resultado: ${userInput}</div>`;
```

**GOOD** — sanitizar ou usar `textContent`:
```javascript
const userInput = document.querySelector('#search').value;
const div = document.createElement('div');
div.textContent = `Resultado: ${userInput}`;
extensionUI.appendChild(div);
```

Lembra: tudo o que o user injeta numa página normal pode ser refletido para o teu content script.

### 3. Message passing sem origin/sender validation

**BAD** — background aceita qualquer mensagem:
```javascript
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.action === 'getCookies') {
    chrome.cookies.getAll({ domain: msg.domain }, sendResponse);
  }
  return true;
});
```

Qualquer página comprometida pode mandar `chrome.runtime.sendMessage` se conhecer o ID da extensão (público).

**GOOD** — validar `sender.url` e/ou usar `externally_connectable` restrito:
```javascript
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (!sender.tab || !sender.url?.startsWith('https://minha-app.com')) {
    return false;
  }
  if (msg.action === 'getCookies' && ALLOWED_DOMAINS.includes(msg.domain)) {
    chrome.cookies.getAll({ domain: msg.domain }, sendResponse);
  }
  return true;
});
```

E em manifest.json:
```json
{
  "externally_connectable": {
    "matches": ["https://minha-app.com/*"]
  }
}
```

### 4. CSP da extensão fraca ou bypassed

**BAD** — manifest.json com CSP relaxado:
```json
{
  "content_security_policy": {
    "extension_pages": "script-src 'self' 'unsafe-eval'; object-src 'self'"
  }
}
```

`'unsafe-eval'` permite `eval()` e `new Function()` — porta aberta para RCE via injeção.

**GOOD** — CSP estrita (default em MV3):
```json
{
  "content_security_policy": {
    "extension_pages": "script-src 'self'; object-src 'self'"
  }
}
```

### 5. Storage de secrets em `chrome.storage.local`

**BAD** — armazenar API keys ou tokens em plain:
```javascript
chrome.storage.local.set({ apiKey: 'sk_live_PLACEHOLDER_xxx' });
```

`chrome.storage.local` não é encriptado. Qualquer outra extensão com `storage` permission lê o teu storage? Não — é per-extension. Mas malware com acesso ao perfil Chrome (filesystem) lê tudo.

**GOOD** — secrets via OAuth flow + tokens curtos. Para casos onde precisas de armazenar localmente, usa Web Crypto API com chave derivada do user (passphrase, biometric) — mas reconhece os limites.

### 6. Web Accessible Resources expostos demais

**BAD** — manifest.json:
```json
{
  "web_accessible_resources": [{
    "resources": ["*"],
    "matches": ["<all_urls>"]
  }]
}
```

Qualquer página injeta os teus scripts/assets via URL `chrome-extension://<id>/...`.

**GOOD** — específico:
```json
{
  "web_accessible_resources": [{
    "resources": ["icons/logo.png", "fonts/inter.woff2"],
    "matches": ["https://minha-app.com/*"]
  }]
}
```

### 7. Content script remoto / dynamic code

**BAD** — fetch script remoto e `eval`:
```javascript
const code = await fetch('https://my-cdn.com/payload.js').then(r => r.text());
new Function(code)();
```

Bloqueado em MV3 por default (CSP). Mas alguns ainda usam workarounds via `chrome.scripting.executeScript` com `world: 'MAIN'` que viola o spirit.

**GOOD** — todo código JS empacotado na extensão. Atualizações via Chrome Web Store, não via runtime fetch.

### 8. Permissions com `<all_urls>` + `cookies`/`webRequest`

Combinação clássica que permite ler cookies de qualquer site → roubo de sessão silencioso. Chrome Web Store fica suspicious. Justifica explicitamente no listing ou refatora arquitetura para não precisar.

## Manifest V3 specifics

### Service worker em vez de background page

```javascript
// background.js (MV3)
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', () => self.clients.claim());

chrome.runtime.onMessage.addListener(handler);
```

Sem `<script src=...>` em background HTML. Sem `XMLHttpRequest`, usa `fetch`. Sem `setTimeout` em períodos longos — service worker é matado após ~30s de idle.

### Declarative net request (substitui webRequest blocking)

```json
{
  "permissions": ["declarativeNetRequest"],
  "declarative_net_request": {
    "rule_resources": [{
      "id": "ruleset_1",
      "enabled": true,
      "path": "rules.json"
    }]
  }
}
```

Mais seguro que webRequest porque rules são declarativas (não código arbitrário a tocar em cada request).

## Quick wins — Manifest

- [ ] `manifest_version: 3`
- [ ] `permissions` minimalista (sem `<all_urls>` se evitável)
- [ ] `host_permissions` específicos por domínio
- [ ] CSP da extensão sem `'unsafe-eval'` ou `'unsafe-inline'`
- [ ] `web_accessible_resources` com `matches` restrito (não `<all_urls>`)
- [ ] `externally_connectable` definido se aceitas mensagens de páginas web
- [ ] `optional_permissions` para features avançadas (user opt-in)
- [ ] `content_scripts.matches` específicos, sem wildcards excessivos

## Quick wins — Código

- [ ] Validar `sender.url` em todos os `onMessage` listeners
- [ ] Sem `innerHTML` com user input em UI da extensão
- [ ] Sem `eval`, `new Function`, `setTimeout(string)`
- [ ] Sem fetch de código remoto e execução
- [ ] Storage não armazena secrets em plain
- [ ] HTTPS-only para todas as fetch (sem `http://`)
- [ ] Subresource Integrity em scripts externos (se obrigatórios)
- [ ] Errors capturados e não enviados para servidores third-party com PII

## Falsos positivos comuns

- **`<all_urls>` numa extensão de blocklist/anti-malware** — legítimo, justificado no listing
- **`activeTab` + `scripting.executeScript`** — padrão MV3 normal, não é vuln
- **Storage não encriptado** — aceitável se não há secrets sensíveis
- **`web_accessible_resources` para fonts/imagens** — legítimo

## Severidade típica

- **Crítico** — message passing sem validação + permissions amplas (cross-site scripting global, cookie theft)
- **Alto** — `'unsafe-eval'` em CSP da extensão, fetch dinâmico de código
- **Médio** — over-broad permissions, web_accessible_resources com `<all_urls>`
- **Baixo** — falta de SRI, optional permissions ausentes

## Cross-references

- [`../analises/xss.md`](../analises/xss.md) — XSS aplicável a popup/options pages
- [`../analises/16-headers-http.md`](../analises/16-headers-http.md) — CSP geral
- [`../linguagens/javascript-typescript.md`](../linguagens/javascript-typescript.md) — JS pitfalls
- [`../analises/tokens.md`](../analises/tokens.md) — armazenamento de tokens

## Recursos

- [Chrome Extensions: MV3 Security](https://developer.chrome.com/docs/extensions/mv3/intro/)
- [Mozilla Add-ons Security](https://extensionworkshop.com/documentation/develop/build-a-secure-extension/)
