# Extensions — Browser Extensions Security

> Track para extensões de browser (Chrome, Edge, Firefox, Safari). Carregar quando há `manifest.json` na raiz com `manifest_version: 2 ou 3`.

## Quando carregar

A IA carrega esta pasta quando deteta:
- `manifest.json` na raiz com campo `manifest_version`
- Estrutura típica: `background/`, `content_scripts/`, `popup/`, `options/`
- Build target: `chrome://`, `moz-extension://`, `safari-web-extension://`

## Ficheiros

| Ficheiro | Cobre |
|---|---|
| `browser-extension-security.md` | Manifest v3, message passing, content scripts, CSP, permissions, web_accessible_resources |

## Cross-references

- Análises universais ainda aplicam: XSS, sanitização, tokens, headers
- Para cartões de linguagem: [`../linguagens/javascript-typescript.md`](../linguagens/javascript-typescript.md)
