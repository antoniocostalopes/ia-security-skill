# Wails — Segurança

> Apps desktop com Go backend + Webview frontend. Mais leve que Electron, expõe métodos Go ao frontend via binding automático. Pegada similar a Tauri mas em Go.

## Quando carregar

- `wails.json` na raiz
- `go.mod` com `github.com/wailsapp/wails/v2`
- Estrutura típica: `frontend/`, `app.go`, `main.go`

## Mindset

- **Métodos Go expostos automaticamente** ao frontend via reflection — toda function pública na app struct é chamável
- **Nenhuma allowlist por default** — depende do dev escolher o que expõe
- **CSP via assets server** — definir manualmente
- **Auto-updater não built-in** (vs Tauri) — deves implementar ou usar third-party

## 5 categorias

### 1. Métodos Go expõem privilege

**BAD** — `app.go`:
```go
type App struct {
    ctx context.Context
}

func (a *App) ReadFile(path string) (string, error) {
    data, err := os.ReadFile(path)
    return string(data), err
}

func (a *App) ExecCommand(cmd string) (string, error) {
    out, err := exec.Command("sh", "-c", cmd).Output()
    return string(out), err
}
```

`ExecCommand` é disponibilizado ao frontend automaticamente. Frontend comprometido → RCE local.

**GOOD** — não expor APIs perigosas. Validar todos os inputs:
```go
func (a *App) ReadDoc(filename string) (string, error) {
    if strings.ContainsAny(filename, "/\\..") {
        return "", errors.New("invalid filename")
    }
    appDir, _ := os.UserConfigDir()
    safePath := filepath.Join(appDir, "meu-app", "docs", filename)

    cleanPath, err := filepath.Abs(safePath)
    if err != nil || !strings.HasPrefix(cleanPath, filepath.Join(appDir, "meu-app", "docs")) {
        return "", errors.New("path traversal blocked")
    }

    data, err := os.ReadFile(cleanPath)
    return string(data), err
}
```

### 2. Funções privadas expostas por engano

Wails expõe **todos** os métodos exportados (capitalized). Função interna com nome capitalizado fica acessível ao frontend.

**BAD**:
```go
func (a *App) AdminBypass(token string) bool {
    return token == os.Getenv("MASTER_TOKEN")  // pensavas ser internal
}
```

**GOOD** — usar lowercase para internas:
```go
func (a *App) adminBypass(token string) bool {
    return token == os.Getenv("MASTER_TOKEN")
}

// Métodos expostos: só ações deliberadas
func (a *App) Login(username, password string) (bool, error) { ... }
```

### 3. Eventos sem validação

```go
runtime.EventsOn(ctx, "save-action", func(args ...interface{}) {
    if len(args) > 0 {
        path := args[0].(string)
        os.WriteFile(path, []byte("data"), 0644)
    }
})
```

Frontend manda `EventsEmit("save-action", "/etc/passwd")`. Sem validação.

**FIX:**
```go
runtime.EventsOn(ctx, "save-action", func(args ...interface{}) {
    if len(args) == 0 {
        return
    }
    filename, ok := args[0].(string)
    if !ok || strings.ContainsAny(filename, "/\\..") {
        return
    }
    safePath := filepath.Join(appDir, "docs", filename)
    os.WriteFile(safePath, []byte("data"), 0644)
})
```

### 4. CSP ausente / asset handling

**BAD** — `wails.json` ou frontend sem CSP:
```html
<!DOCTYPE html>
<html>
<head><title>App</title></head>
<body>...</body>
</html>
```

**GOOD** — CSP via meta tag (frontend) e/ou middleware Go:
```html
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self'; script-src 'self'; connect-src 'self' https://api.minha-app.com">
```

### 5. Auto-updater inseguro (third-party)

Sem updater built-in, devs costumam usar `equinox-io/equinox`, `sanbornm/go-selfupdate` ou implementar via `github.com/minio/selfupdate`. Verificar:
- HTTPS endpoint
- Signature verification (Ed25519, GPG)
- Path traversal no update zip
- Permissions do binário substituído

**Pattern correto** (com selfupdate):
```go
import "github.com/minio/selfupdate"

func doUpdate(url string, publicKey ed25519.PublicKey) error {
    resp, err := http.Get(url)
    if err != nil { return err }
    defer resp.Body.Close()

    return selfupdate.Apply(resp.Body, selfupdate.Options{
        PublicKey: publicKey,
        // signature verification automática
    })
}
```

## Quick wins

- [ ] Auditar todos os métodos exportados em `app.go` (capital first letter)
- [ ] Mover métodos internos para lowercase ou struct privada
- [ ] Validar todos os inputs (paths, sizes, types) nos métodos Go
- [ ] Path traversal protection com `filepath.Abs` + prefix check
- [ ] CSP em `index.html` ou via assets handler
- [ ] HTTPS para todos os endpoints externos
- [ ] Auto-updater com signature verification
- [ ] Sem `os/exec` exposto ao frontend
- [ ] Devtools desabilitados em produção (`-tags production` no build)
- [ ] Wails version recente

## Falsos positivos

- Métodos `Get*` que retornam dados estáticos da app — OK
- Eventos com payload simples (string) e sem side-effect filesystem — OK
- Métodos privados (lowercase) — não expostos, ignorar

## Severidade típica

- **Crítico** — `ExecCommand` ou similar exposto, métodos que escrevem filesystem sem validação, auto-updater sem signing
- **Alto** — métodos privados acidentalmente exportados, eventos sem validação
- **Médio** — CSP ausente, devtools em release
- **Baixo** — Wails version 1-2 versions atrás

## Cross-references

- [`electron.md`](electron.md), [`tauri.md`](tauri.md) — comparar
- [`../linguagens/go.md`](../linguagens/go.md)
- [`../analises/19-injection-server-side.md`](../analises/19-injection-server-side.md) — command injection

## Recursos

- [Wails Security](https://wails.io/docs/guides/security/)
- [Wails v2 Bindings](https://wails.io/docs/howdoesitwork/)
