# Ionic / Cordova / Capacitor — Segurança

> Apps híbridas (HTML+JS dentro de WebView). **Toda a superfície XSS web aplica-se**, plus problemas mobile-specific.

## Architecture risks

- App é WebView a renderizar HTML/JS local + remoto.
- XSS no conteúdo carregado = RCE potencial via plugin bridge.
- File:// URI tem privilégios elevados.

## XSS = RCE em apps híbridas

```javascript
// XSS num app híbrido pode chamar plugins nativos
// ex.: cordova-plugin-camera, file system, contacts
document.body.innerHTML = userContent;  // se tem <script>, executa

// E pode invocar:
window.cordova.exec(success, error, 'File', 'readAsText', [path]);
// → ler ficheiros locais arbitrários
```

> XSS em apps híbridas é Crítico, não só Alto.

## Configuração — Capacitor

```typescript
// capacitor.config.ts
const config: CapacitorConfig = {
  appId: 'com.meusite.app',
  webDir: 'dist',
  server: {
    androidScheme: 'https',  // não http
    cleartext: false,         // bloqueia HTTP
    allowNavigation: ['*.meusite.tld'],  // allowlist
  },
  plugins: {
    SplashScreen: { launchAutoHide: true },
  },
};
```

## Configuração — Cordova / Ionic

```xml
<!-- config.xml -->
<access origin="https://api.meusite.tld" />
<allow-navigation href="https://meusite.tld/*" />
<allow-intent href="https://*/*" />

<!-- Content Security Policy -->
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self' 'unsafe-inline';
  connect-src 'self' https://api.meusite.tld;
  img-src 'self' data: https:;
" />
```

## File:// URI

```javascript
// BAD — carregar conteúdo arbitrário do filesystem
webView.loadUrl('file:///' + userPath);

// GOOD — usar paths sandbox
webView.loadUrl('file:///android_asset/index.html');
```

## Storage — secure

```typescript
// BAD — localStorage / IndexedDB (plain)
localStorage.setItem('token', jwt);

// GOOD — Capacitor Secure Storage Plugin
import { SecureStoragePlugin } from 'capacitor-secure-storage-plugin';
await SecureStoragePlugin.set({ key: 'token', value: jwt });

// Ou Ionic Identity Vault (premium)
import { IdentityVault } from '@ionic-enterprise/identity-vault';
```

## Plugin permissions — minimizar

Cada Capacitor/Cordova plugin instalado é attack surface. Auditar `package.json`:
```json
{
  "dependencies": {
    "@capacitor/camera": "^5.0.0",
    "@capacitor/contacts": "^5.0.0",  // realmente preciso?
    "@capacitor/filesystem": "^5.0.0"
  }
}
```

## Common antipatterns

### `innerHTML = userInput`
- XSS → bridge nativo → RCE.

### `eval` / `new Function` no JS
- Mesma classe de risco que XSS.

### CSP `'unsafe-inline'` + `'unsafe-eval'`
- Default em muitos templates Ionic. Tentar restringir.

### `cordova.plugins.X` sem validação
- Bridge calls sem validation de input.

### Aceitar deep links sem verificar origem
- App link / URI scheme handler aberto.

### Web content de servidor sem validação no servidor
- Backend deve sanitizar antes de devolver para WebView.

### Mixed content (HTTP em HTTPS)
- WebView pode bloquear, mas confirmar config.

### `cleartext: true` em produção
- Permite HTTP.

## Quick wins

- [ ] Capacitor 5+ (ou Cordova com manutenção ativa)
- [ ] CSP no `index.html`/`config.xml` restritiva
- [ ] `allowNavigation` allowlist específica
- [ ] `cleartext: false`
- [ ] Secure storage plugin para tokens (não localStorage)
- [ ] Plugins minimizados (cada um auditar)
- [ ] Backend sanitiza output devolvido para WebView
- [ ] `npm audit` sem Críticos (incluindo plugins Capacitor/Cordova)
- [ ] Deep links validados
- [ ] Mixed content disabled
- [ ] HTTPS forçado para todas as APIs
- [ ] Cert pinning (plugin de pinning)
- [ ] Bundle minified + sem source maps em prod
- [ ] **XSS é Crítico** — aplicar sanitização de output rigorosa
