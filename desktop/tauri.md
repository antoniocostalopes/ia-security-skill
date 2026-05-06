# Tauri — Segurança

> Apps desktop com Rust backend + Webview frontend (sem Chromium completo). Mais seguro que Electron por design mas tem pegadas próprias: allowlist de APIs, IPC commands, CSP.

## Quando carregar

- `Cargo.toml` com `tauri =` em `dependencies`
- `tauri.conf.json` na raiz
- `src-tauri/` folder

## Mindset

- **Frontend (webview) ≠ Rust backend** — comunicam via IPC commands explícitos
- **Allowlist de APIs** controla exatamente quais features Tauri o frontend pode chamar
- **CSP forte por default** — mais restrito que Electron
- **Capabilities (Tauri 2.x)** — fine-grained permissions por window/origin
- **Updates assinados** — built-in via `tauri-updater`

## 6 categorias

### 1. Allowlist over-broad

**BAD** — `tauri.conf.json`:
```json
{
  "tauri": {
    "allowlist": {
      "all": true
    }
  }
}
```

`all: true` desliga qualquer restrição. Frontend pode aceder a `fs`, `shell`, `process` sem limites.

**GOOD** — allowlist mínima:
```json
{
  "tauri": {
    "allowlist": {
      "all": false,
      "fs": {
        "readFile": true,
        "scope": ["$APPDATA/docs/*"]
      },
      "shell": {
        "open": true,
        "scope": [{ "name": "open-https", "cmd": "open", "args": ["https://*"] }]
      }
    }
  }
}
```

### 2. Tauri 2.x capabilities sem origin restriction

**BAD** — `src-tauri/capabilities/main.json`:
```json
{
  "permissions": ["fs:default", "shell:default", "process:default"],
  "windows": ["main"]
}
```

Sem `local`/`remote` distinction, sem `urls` filter.

**GOOD** — capabilities específicas com origin:
```json
{
  "identifier": "main-capability",
  "windows": ["main"],
  "remote": {
    "urls": ["https://api.minha-app.com"]
  },
  "permissions": [
    "fs:read-files",
    {
      "identifier": "fs:scope",
      "allow": [{ "path": "$APPDATA/docs/**" }]
    }
  ]
}
```

### 3. Commands sem validação no Rust

**BAD** — `src-tauri/src/main.rs`:
```rust
#[tauri::command]
fn save_file(path: String, content: String) -> Result<(), String> {
    std::fs::write(path, content).map_err(|e| e.to_string())
}
```

Frontend comprometido escreve em qualquer path.

**GOOD** — validar dentro de userData:
```rust
use std::path::PathBuf;
use tauri::Manager;

#[tauri::command]
fn save_file(app: tauri::AppHandle, filename: String, content: String) -> Result<(), String> {
    if filename.contains("..") || filename.contains('/') || filename.contains('\\') {
        return Err("Invalid filename".into());
    }
    let app_dir = app.path().app_data_dir().map_err(|e| e.to_string())?;
    let safe_path: PathBuf = app_dir.join("docs").join(&filename);
    std::fs::create_dir_all(safe_path.parent().unwrap()).map_err(|e| e.to_string())?;
    std::fs::write(&safe_path, content).map_err(|e| e.to_string())?;
    Ok(())
}
```

### 4. CSP relaxada

**BAD** — `tauri.conf.json`:
```json
{
  "tauri": {
    "security": {
      "csp": null
    }
  }
}
```

**GOOD** — CSP estrita:
```json
{
  "tauri": {
    "security": {
      "csp": "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://api.minha-app.com"
    }
  }
}
```

### 5. dangerousRemoteDomainIpcAccess (Tauri 1.x)

**BAD**:
```json
{
  "tauri": {
    "security": {
      "dangerousRemoteDomainIpcAccess": [{
        "domain": "*",
        "windows": ["main"],
        "enableTauriAPI": true
      }]
    }
  }
}
```

`domain: "*"` permite que **qualquer site remoto** chame APIs Tauri se carregado no webview. Equivalente catastrófico ao `nodeIntegration: true` do Electron.

**GOOD** — não usar este field. Carregar só conteúdo local. Se precisares de domínio remoto específico:
```json
{
  "domain": "minha-app.com",
  "windows": ["main"],
  "enableTauriAPI": false,
  "plugins": []
}
```

### 6. Update endpoint sem signing pubkey

**BAD** — `tauri.conf.json`:
```json
{
  "updater": {
    "active": true,
    "endpoints": ["https://updates.meu-app.com/{{target}}/{{current_version}}"]
  }
}
```

Sem `pubkey` — qualquer atacante MITM injeta update malicioso.

**GOOD**:
```json
{
  "updater": {
    "active": true,
    "endpoints": ["https://updates.meu-app.com/{{target}}/{{current_version}}"],
    "pubkey": "dW50cnVzdGVkIGNvbW1lbnQ6IG1pbmlzaWduIHB1YmxpYyBrZXk6..."
  }
}
```

Gerar pubkey com `tauri signer generate`. Updates não assinados são rejeitados.

## Quick wins

- [ ] `allowlist.all: false` (ou capabilities específicas em Tauri 2.x)
- [ ] APIs e scopes mínimos (fs scope ao userData, shell scope com regex)
- [ ] Commands validam todos os inputs (paths, schemes, sizes)
- [ ] CSP definida e estrita
- [ ] Sem `dangerousRemoteDomainIpcAccess` ou apenas com domínios específicos
- [ ] Updater com `pubkey` configurado
- [ ] HTTPS-only para todos os endpoints externos
- [ ] Webview só carrega `dist/index.html` local (não URLs remotos)
- [ ] `withGlobalTauri: false` se não precisares (reduz superfície)
- [ ] Tauri version recente (CVEs)

## Falsos positivos

- Allowlist com `all: false` mas vários módulos ativos — OK se cada módulo tem scope
- `shell.open` com scope a permitir abrir browser para HTTPS externos — design intencional

## Severidade típica

- **Crítico** — `dangerousRemoteDomainIpcAccess: "*"`, command sem validação que escreve filesystem, updater sem pubkey
- **Alto** — `allowlist.all: true`, CSP ausente
- **Médio** — fs scope demasiado largo, shell scope com `cmd: "*"`
- **Baixo** — withGlobalTauri ativado quando não usado

## Cross-references

- [`electron.md`](electron.md) — comparar arquitetura
- [`../linguagens/rust.md`](../linguagens/rust.md)
- [`../analises/16-headers-http.md`](../analises/16-headers-http.md) — CSP
- [`../analises/17-dependencias.md`](../analises/17-dependencias.md) — supply chain (cargo + npm)

## Recursos

- [Tauri Security](https://v2.tauri.app/security/)
- [Tauri 2.0 Capabilities](https://v2.tauri.app/security/capabilities/)
