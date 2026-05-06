# IA Security Skill — v1.0

> *Por António Lopes · Open Source · MIT*

[![Open Source](https://img.shields.io/badge/Open%20Source-%E2%9D%A4-red.svg)](https://github.com/antoniocostalopes/ia-security-skill)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Cobertura](https://img.shields.io/badge/cobertura-universal-brightgreen)]()
[![PT](https://img.shields.io/badge/lang-pt--PT-green)]()

> 🌍 **Skill 100% open source** — usa, modifica, partilha. Construída pela comunidade, para a comunidade.

> **Hacker amigável** para **agentes de IA** — auditoria de segurança universal de código em **qualquer linguagem, framework e plataforma**, antes da entrega.

> *"Encontra agora o que um atacante encontrará depois — e mostra como fechar."*

## O que cobre

### 24 análises universais (qualquer projeto)
XSS · SQLi · CSRF · Permissões · REST API · Endpoints públicos · Uploads · Tokens · Exposição de dados · Query Builders/ORMs · Sanitização · Webhooks · Criptografia · Auth/Sessão · Hardening · Headers HTTP · Dependências/supply chain · Business logic/race conditions · Server-side injections (Cmd/LFI/SSTI/Deserialization/XXE) · Open Redirect/SSRF · DoS · Logging · APIs modernas (OAuth/GraphQL/WebSocket/API Top 10) · Email/SMS

> Plus 3 módulos meta: mindset do atacante, attack chains canónicos, técnicas de verificação.

### 18 linguagens
JavaScript/TypeScript · Python · PHP · Java · C#/.NET · Go · Ruby · Rust · Kotlin · Swift · Dart · C/C++ · Scala · Elixir · Shell/Bash · SQL · GraphQL · Solidity

### 34 frameworks
**PHP**: WordPress · Laravel · Symfony
**Node meta-frameworks**: Express · Fastify · NestJS · Next.js · Nuxt · Remix · SvelteKit · AdonisJS
**Frontend standalone**: React · Vue 3 · Angular · Astro · HTMX
**Python**: Django · Flask · FastAPI
**Java**: Spring Boot · Quarkus
**.NET**: ASP.NET Core · Blazor
**Outros**: Rails · Gin/Echo · Phoenix · Actix/Axum
**Runtimes**: Bun · Deno · Hono (edge)
**APIs**: REST/OpenAPI · GraphQL/Apollo · gRPC · tRPC

### Track Mobile completo (MASVS-aligned)
iOS Native · Android Native · React Native · Flutter · Xamarin/MAUI · Ionic/Cordova/Capacitor + Storage local · Network/Cert pinning · Deep links · WebView · Biometric · Anti-jailbreak/root · Reverse Engineering · Store distribution

### Outras áreas especializadas
Containers/Kubernetes · IaC (Terraform/CloudFormation) · AWS · GCP · Azure · CI/CD pipelines · ML/AI security · Web3/Smart contracts · IoT/Embedded · **Privacidade/Compliance** (GDPR/LGPD/CCPA/HIPAA/PCI-DSS)

## Instalação rápida — escolhe a tua IA

A skill funciona em **15+ IAs**. Para qualquer cliente, faz `git clone` primeiro:

```bash
git clone https://github.com/antoniocostalopes/ia-security-skill
cd ia-security-skill
```

Depois, escolhe o ficheiro adaptador adequado à tua IA:

| IA | Ficheiro adaptador | Setup |
|---|---|---|
| **Aider** | [`examples/configs/aider.conf.yml`](examples/configs/aider.conf.yml) | Copiar para `~/.aider.conf.yml` |
| **Claude Code** (CLI) | [`SKILL.md`](SKILL.md) | `cp -r . ~/.claude/skills/seguranca/` |
| **Claude.ai** (Projects) | Toda a pasta | Upload em Project Knowledge |
| **Continue.dev** | [`examples/configs/continue-config.json`](examples/configs/continue-config.json) | Merge no `~/.continue/config.json` |
| **Cursor** (legacy) | [`.cursorrules`](.cursorrules) | Copiar para a raiz do projeto |
| **Cursor** (moderno ≥0.43) | [`.cursor/rules/seguranca.mdc`](.cursor/rules/seguranca.mdc) | Copiar para `.cursor/rules/` no projeto |
| **GitHub Copilot Chat** | [`PROMPT-COMPACTO.md`](PROMPT-COMPACTO.md) | Copiar para `.github/copilot-instructions.md` |
| **ChatGPT Custom GPT** | [`PROMPT-COMPACTO.md`](PROMPT-COMPACTO.md) + [`bundles/`](bundles/) | Instructions + 1 bundle (20 files) |
| **Gemini / DeepSeek / Mistral / Qwen** | [`PROMPT.md`](PROMPT.md) | Colar como system prompt |
| **Windsurf** / **Codex CLI** | [`AGENTS.md`](AGENTS.md) | Copiar para a raiz do projeto |
| **Qualquer outra IA** | [`PROMPT-COMPACTO.md`](PROMPT-COMPACTO.md) | Colar como system prompt ou primeira mensagem |

**One-liner para Claude Code:**
```bash
curl -sSL https://raw.githubusercontent.com/antoniocostalopes/ia-security-skill/main/install.sh | bash
```

Para instruções detalhadas: **[INSTALL.md](INSTALL.md)**.

## Arquitetura — 3 camadas hierárquicas

A IA carrega o que precisa para o stack detetado. Não bloat por carregar tudo de uma vez.

```
1. Universal (sempre)        → analises/      (24 análises + 3 meta: mindset/chains/verificação)
2. Linguagem (per stack)     → linguagens/    (18 cartões + README)
3. Framework (per stack)     → frameworks/    (34 profiles + README)
+ Mobile (se aplicável)      → mobile/        (16 ficheiros MASVS + README)
+ Outras áreas (se relevante)→ outras-areas/  (10 domínios especializados + README)
```

## Output

Relatório visual em Markdown com:
- Score de segurança 0-100
- Nível de blindagem (Crítico → Blindado)
- Mapa de superfícies de ataque
- Attack chains (mínimo 3 combinações)
- Resumo executivo (cliente) + Resumo técnico (devs)
- Plano de correção em 4 fases
- Checklist final pré-produção

## Estrutura

```
seguranca/
├── README.md / INSTALL.md / CHANGELOG.md / LICENSE
├── CONTRIBUTING.md / SECURITY.md     ← guidelines comunidade
├── PROMPT.md                         ← system prompt universal (canónico)
├── PROMPT-COMPACTO.md                ← versão <8KB para clientes com limite
├── SKILL.md                          ← adaptador Claude Code
├── AGENTS.md                         ← adaptador Cursor / Windsurf / Codex
├── .cursorrules                      ← adaptador Cursor (legacy)
├── .cursor/rules/seguranca.mdc       ← adaptador Cursor (moderno ≥0.43)
├── install.sh
├── analises/                         ← 24 análises universais + 5 meta (mindset/chains/verificação/patterns/falsos-positivos)
├── linguagens/                       ← 18 cartões por linguagem
├── frameworks/
│   ├── web/                          ← 27 web frameworks (PHP, Node, Frontend standalone, Python, Java, .NET, Ruby, Go, Elixir, Rust)
│   ├── api/                          ← REST/OpenAPI, GraphQL/Apollo, gRPC, tRPC
│   └── runtime/                      ← Bun, Deno, Hono
├── mobile/                           ← 16 ficheiros MASVS
├── outras-areas/                     ← Containers, IaC, Cloud (AWS/GCP/Azure), CI/CD, ML, Web3, IoT, Privacidade/Compliance
├── examples/
│   ├── audit-example-node.md         ← few-shot Node.js
│   ├── audit-example-php-laravel.md  ← few-shot Laravel
│   ├── audit-example-python-django.md ← few-shot Django
│   ├── audit-example-mobile-flutter.md ← few-shot Flutter (banking)
│   ├── audit-example-web3-solidity.md ← few-shot Solidity
│   └── configs/                      ← templates Aider, Continue.dev
├── integracoes/                      ← pre-commit hook, GH Action, CLI wrapper, Semgrep
├── bundles/
│   └── chatgpt-knowledge.md          ← 9 bundles ChatGPT especializados (limit 20 files)
├── .github/                          ← CI workflows + issue/PR templates
└── relatorio/                        ← templates do output
```

**Total:** ~135 ficheiros, ~700 KB. Em runtime, IA carrega apenas 30-50 ficheiros conforme stack detetado.

## Tom

> *"Aqui qualquer um corre código no teu server. Mau, mas o fix são 3 linhas — vamos a isso."*

Hacker amigável: prestável, direto, honesto. Sem alarmismo teatral. Cada achado tem fix copy-paste.

## Quem é para

- **Developers** a auditar o seu próprio código antes de deploy
- **Tech leads** a fazer security review pré-merge
- **Agentes de IA** integrados em CI/CD ou IDE para análise contínua
- **Pentesters em modo white-box** com acesso ao código

## Quem **não** é para

- Pentesting de sistemas de terceiros sem autorização
- Compliance auditing formal (use ferramentas dedicadas)
- Resposta a incidente / forense (use SIEM)

## Cobertura OWASP

| OWASP | Cobertura |
|---|---|
| OWASP Top 10 (Web 2021) | ✓ 10/10 |
| OWASP API Security Top 10 (2023) | ✓ 10/10 |
| OWASP Top 10 LLM (2025) | ✓ via `outras-areas/ml-ai-security.md` |
| OWASP MASVS (Mobile) | ✓ track mobile completo |
| OWASP Top 10 IoT | ✓ via `outras-areas/iot-embedded.md` |

## Versão

**v1.1.0** — Detection performance + workflow integration. Adiciona patterns de deteção, anti-hallucination, self-review pass, confidence scoring, 4 examples adicionais (Laravel/Django/Flutter/Solidity), e integrações (pre-commit, GH Action, CLI, Semgrep hybrid).

**v1.0.0** — Release inicial pública.

Ver [CHANGELOG.md](CHANGELOG.md) para detalhes completos.

## Como contribuir

A skill é **open source** e contribuições são bem-vindas:

- 🐛 **Reportar bugs ou falsos positivos** — abrir issue em GitHub
- 💡 **Sugerir nova categoria/framework/linguagem** — abrir issue com proposta
- 🔧 **Pull requests** — ver [CONTRIBUTING.md](CONTRIBUTING.md) para guidelines
- 🛡️ **Reportar vulnerabilidades** na própria skill — ver [SECURITY.md](SECURITY.md)
- ⭐ **Star o repo** — ajuda outros a descobrir
- 📢 **Partilhar** — qualquer developer beneficia

## Autor e mantedor

**António Lopes**
GitHub: [@antoniocostalopes](https://github.com/antoniocostalopes)

Esta skill é mantida abertamente. Discussões, melhorias e novas ideias acontecem em GitHub Issues e Pull Requests.

## Licença

**MIT** — ver [LICENSE](LICENSE). Copyright © 2026 António Lopes.

✅ **Podes:** usar comercialmente, modificar, distribuir, usar em projetos privados
✅ **Tens que:** incluir o copyright + licença ao distribuir
❌ **Não podes:** responsabilizar o autor (sem garantia)

Uso destinado a **auditoria defensiva pré-entrega** de código próprio ou autorizado. Não usar para testar sistemas de terceiros sem autorização.
