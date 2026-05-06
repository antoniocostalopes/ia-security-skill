# Desktop — Apps Desktop com Webview

> Track para apps desktop modernos baseados em webview. Carregar quando há manifests específicos do framework.

## Quando carregar

| Manifesto | Framework | Profile |
|---|---|---|
| `package.json` com `electron` | Electron | `electron.md` |
| `Cargo.toml` com `tauri` ou `tauri.conf.json` | Tauri | `tauri.md` |
| `wails.json` ou `go.mod` com wails/v2 | Wails | `wails.md` |

## Mindset comum

- **Renderer/webview ≠ confiável** mesmo no teu app — qualquer XSS pode escalar
- **IPC entre frontend e backend** = canal de privilege escalation
- **Auto-updates** são vetor de supply chain — assinar sempre
- **Permissions de SO** (filesystem, network, microphone) merecem allowlist mínima

## Análises universais ainda aplicam

XSS no renderer · Sanitização · CSP · Headers HTTP (para webview content) · Tokens · Auth · Dependências (npm + cargo + go.mod cruzados)

## Cross-references

- [`../linguagens/javascript-typescript.md`](../linguagens/javascript-typescript.md) — frontend
- [`../linguagens/rust.md`](../linguagens/rust.md) — Tauri backend
- [`../linguagens/go.md`](../linguagens/go.md) — Wails backend
- [`../analises/16-headers-http.md`](../analises/16-headers-http.md) — CSP em webview
