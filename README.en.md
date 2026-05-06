# IA Security Skill — for Claude Code

> *By António Lopes · Open Source · MIT*

[![Open Source](https://img.shields.io/badge/Open%20Source-%E2%9D%A4-red.svg)](https://github.com/antoniocostalopes/ia-security-skill)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue)]()
[![Claude Code](https://img.shields.io/badge/Claude%20Code-native-purple)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![EN](https://img.shields.io/badge/lang-EN-blue)]()

> 🇵🇹 [Versão em Português](README.md)

> **Native Claude Code skill** for defensive pre-delivery security auditing — any language, framework, or platform. Thinks like an attacker, acts like a defender, returns copy-paste fixes.

## Install — 1 command

```bash
git clone https://github.com/antoniocostalopes/ia-security-skill ~/.claude/skills/seguranca
```

Done. **Zero per-project configuration. Zero files copied into your repos.** Claude Code detects the skill automatically in any directory where you run `claude`.

## Use — 1 phrase

Inside any project:

```bash
cd ~/projects/my-project
claude
> audit this project
```

In ~30 seconds you get a Markdown report with a score, attack chains, detailed findings, and copy-paste fixes.

Equivalent phrases that activate the skill:
- *"audit this project"*
- *"do a security review"*
- *"audit src/ before deploy"*
- *"check this code for vulnerabilities"*
- *"use the security skill on [path]"*

## What it covers

### 24 universal analyses (always loaded)
XSS · SQLi · CSRF · Broken access control · Insecure REST API · Public endpoints · Dangerous uploads · Token leakage · Data exposure · Query builders/ORMs · Sanitisation · Webhooks · Cryptography · Auth/Session · Hardening · HTTP headers · Dependencies/supply chain · Business logic/race conditions · Server-side injections (Cmd/LFI/SSTI/Deserialization/XXE) · Open Redirect/SSRF · DoS · Logging · Modern APIs (OAuth/GraphQL/WebSocket) · Email/SMS

> Plus 5 meta modules: attacker mindset, canonical attack chains, verification techniques, detection patterns, common false positives.

### 18 languages
JavaScript/TypeScript · Python · PHP · Java · C#/.NET · Go · Ruby · Rust · Kotlin · Swift · Dart · C/C++ · Scala · Elixir · Shell/Bash · SQL · GraphQL · Solidity

### 34 frameworks
**PHP**: WordPress · Laravel · Symfony
**Node**: Express · Fastify · NestJS · Next.js · Nuxt · Remix · SvelteKit · AdonisJS
**Frontend**: React · Vue 3 · Angular · Astro · HTMX
**Python**: Django · Flask · FastAPI
**Java**: Spring Boot · Quarkus
**.NET**: ASP.NET Core · Blazor
**Other**: Rails · Gin/Echo · Phoenix · Actix/Axum
**Runtimes**: Bun · Deno · Hono
**APIs**: REST/OpenAPI · GraphQL/Apollo · gRPC · tRPC

### Mobile track (MASVS-aligned)
iOS Native · Android Native · React Native · Flutter · Xamarin/MAUI · Ionic/Cordova/Capacitor + Local storage · Network/Cert pinning · Deep links · WebView · Biometric · Anti-jailbreak/root · Reverse Engineering · Store distribution

### Desktop apps
Electron · Tauri · Wails — IPC security, renderer isolation, contextIsolation, allowlist, auto-update signing

### Browser extensions
Chrome · Firefox · Safari — Manifest v3, content scripts, message passing, CSP, permissions, web_accessible_resources

### Specialised areas
**Infrastructure:** Containers/Kubernetes · Container runtime (Falco/AppArmor/seccomp/gVisor) · Service mesh (Istio/Linkerd mTLS) · IaC (Terraform/CloudFormation) · CI/CD pipelines

**Cloud:** AWS · GCP · Azure

**Identity & DNS:** DNS/DNSSEC (subdomain takeover, CAA, AXFR, rebinding) · Email infrastructure (SPF/DKIM/DMARC/BIMI/MTA-STS/TLS-RPT)

**Web platforms:** WebAssembly (WASI, imports/exports, side-channel) · Service workers/PWA (cache poisoning, push auth)

**Architecture:** Multi-tenant SaaS (tenant isolation, RLS, cross-tenant IDOR)

**AI/ML/Web3:** LLM agent security (OWASP LLM Top 10, prompt injection, tool use) · ML/AI security · Web3/Smart contracts

**Verticals:** Game security (anti-cheat, IAP validation, server-authoritative) · IoT/Embedded

**Advanced crypto:** Post-quantum crypto (ML-KEM/ML-DSA, hybrids, migration roadmap)

**Compliance:** Privacy/Compliance (GDPR/LGPD/CCPA/HIPAA/PCI-DSS)

## How it works

Claude Code reads the frontmatter in [`SKILL.md`](SKILL.md) and activates the skill when your prompt matches the description (e.g. *"audit"*, *"security review"*, *"vulnerabilities"*).

The skill runs a 7-phase workflow:

1. **Reconnaissance** — reads manifests (`package.json`, `composer.json`, `requirements.txt`, `Info.plist`, `Dockerfile`, `manifest.json`, `tauri.conf.json`, `wails.json`, `*.tf`, `*.sol`, etc.) to detect the stack
2. **Universal analysis** — 24 categories applied to any project
3. **Specific analysis** — loads only the relevant files from [`linguagens/`](linguagens/) and [`frameworks/`](frameworks/)
4. **Attack chains** — combines findings (minimum 3 chains) to escalate severity
5. **Self-review** — confidence scoring (95%/80%/60%/40%) and false positive filtering
6. **Score & hardening level** — formula in [`relatorio/score-blindagem.md`](relatorio/score-blindagem.md)
7. **Report** — fixed template from [`relatorio/template.md`](relatorio/template.md)

### Hierarchical loading — 3 layers

The skill loads only what it needs for the detected stack:

```
1. Universal (always)       → analises/      (24 analyses + 5 meta)
2. Language (per stack)     → linguagens/    (1-3 files)
3. Framework (per stack)    → frameworks/    (1-3 files)
+ Mobile (if applicable)    → mobile/        (up to 16 MASVS files)
+ Desktop (if applicable)   → desktop/       (Electron / Tauri / Wails)
+ Extensions (if applicable)→ extensions/    (Browser extensions MV3)
+ Other areas (if relevant) → outras-areas/  (21 specialised domains)
```

At runtime: 15–50 active files depending on the stack.

## Output

A single Markdown report containing:

- **Score 0–100** + hardening level (Critical → Hardened)
- **Attack surface map** (entry points, trust boundaries)
- **Attack chains** (minimum 3 exploitation chains)
- **Executive summary** (client) + **Technical summary** (devs)
- **Detailed findings** with severity, file:line, vulnerable code, exploitation, **copy-paste fix**, confidence
- **4-phase remediation plan** (Criticals now → Hardening at the end)
- **Pre-production checklist**

Real examples:
- [Node.js / Express](examples/audit-example-node.md)
- [PHP / Laravel](examples/audit-example-php-laravel.md)
- [Python / Django](examples/audit-example-python-django.md)
- [Mobile / Flutter](examples/audit-example-mobile-flutter.md)
- [Web3 / Solidity](examples/audit-example-web3-solidity.md)

## Structure

```
seguranca/
├── SKILL.md                  ← entry point (Claude Code frontmatter)
├── README.md / README.en.md / USAGE.md / INSTALL.md
├── CHANGELOG.md / CONTRIBUTING.md / SECURITY.md / LICENSE
├── analises/                 ← 24 analyses + 5 meta
├── linguagens/               ← 18 language cards
├── frameworks/
│   ├── web/                  ← 27 web frameworks
│   ├── api/                  ← REST/GraphQL/gRPC/tRPC
│   └── runtime/              ← Bun, Deno, Hono
├── mobile/                   ← 16 MASVS-aligned files
├── desktop/                  ← Electron, Tauri, Wails
├── extensions/               ← Browser extensions (Manifest v3)
├── outras-areas/             ← 21 specialised domains
├── examples/                 ← 5 complete audit examples
├── relatorio/                ← output templates (score, template, checklist)
├── commands/                 ← optional slash commands (/audita, /audita-rapido, /audita-diff)
├── agents/                   ← optional subagent (auditor-seguranca)
└── .github/                  ← CI workflows + issue/PR templates
```

## Update

```bash
cd ~/.claude/skills/seguranca && git pull
```

## Optional extras

### Slash commands `/audita*`

Deterministic shortcuts `/audita`, `/audita-rapido`, `/audita-diff`:

```bash
mkdir -p ~/.claude/commands
cp ~/.claude/skills/seguranca/commands/audita*.md ~/.claude/commands/
```

See [`commands/README.md`](commands/README.md).

### Subagent `auditor-seguranca`

For composed workflows (audit → apply fixes → re-audit) or to isolate the long report from the main context:

```bash
mkdir -p ~/.claude/agents
cp ~/.claude/skills/seguranca/agents/auditor-seguranca.md ~/.claude/agents/
```

See [`agents/README.md`](agents/README.md).

## Tone

> *"Anyone can run code on your server right here. Bad, but the fix is 3 lines — let's do it."*

Direct, helpful, honest. No theatrical alarmism. Every finding has a copy-paste fix. Conservative severity — false positives erode team trust.

## Who it's for

- **Developers** using Claude Code who want to audit their own code before deploy
- **Tech leads** doing pre-merge security review inside Claude Code
- **Teams** that adopted Claude Code as their primary agent and want security as a native capability

## Who it's **not** for

- Pentesting third-party systems without authorisation
- Formal compliance auditing (use dedicated tools)
- Incident response / forensics (use SIEM)
- Anyone **not** using Claude Code (this skill is Claude Code-specific; for other AI tools, fork the repo and adapt)

## OWASP coverage

| OWASP | Coverage |
|---|---|
| OWASP Top 10 (Web 2021) | 10/10 |
| OWASP API Security Top 10 (2023) | 10/10 |
| OWASP Top 10 for LLM (2025) | via [`outras-areas/llm-agent-security.md`](outras-areas/llm-agent-security.md) + [`outras-areas/ml-ai-security.md`](outras-areas/ml-ai-security.md) |
| OWASP MASVS (Mobile) | full mobile track |
| OWASP Top 10 IoT | via [`outras-areas/iot-embedded.md`](outras-areas/iot-embedded.md) |

## Version

**v1.0.0** — Initial public release. Native Claude Code skill with 24 universal analyses, 18 languages, 34 frameworks, mobile track (MASVS), desktop (Electron/Tauri/Wails), browser extensions (MV3), 21 specialised areas (including LLM agents, service mesh, DNS, email infra, multi-tenant SaaS, WebAssembly, PWA, games, post-quantum crypto), self-review pass, confidence scoring, and 5 real audit examples. 155 .md files.

See [CHANGELOG.md](CHANGELOG.md) for full details.

## Contributing

Contributions are welcome:

- **Report bugs or false positives** — open an issue
- **Suggest a new category/framework/language** — open an issue with a proposal
- **Pull requests** — see [CONTRIBUTING.md](CONTRIBUTING.md)
- **Report vulnerabilities** in the skill itself — see [SECURITY.md](SECURITY.md)
- **Star the repo** — helps other Claude Code developers discover it

## Author

**António Lopes**
GitHub: [@antoniocostalopes](https://github.com/antoniocostalopes)

## Licence

**MIT** — see [LICENSE](LICENSE). Copyright © 2026 António Lopes.

Intended for **defensive pre-delivery auditing** of your own or authorised code. Do not use to test third-party systems without authorisation.
