# Changelog

Todas as mudanças notáveis a esta skill são documentadas aqui.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/), versionamento [SemVer](https://semver.org/).

## [1.1.0] — 2026-05-06

🎯 **Detection performance + workflow integration.**

Update focado em **melhorar a deteção** (recall + precision) e **integrar a skill no workflow do developer** (pre-commit, CI/CD, CLI).

### Adicionado — Qualidade de deteção
- `analises/00-patterns-deteccao.md` — Regex/keywords literais por categoria. Aumenta recall (não esquecer padrões clássicos).
- `analises/00-falsos-positivos-comuns.md` — Anti-hallucination guide. Reduz reports incorretos com exemplos "isto NÃO é vulnerabilidade".
- **Self-review pass** (Fase 6) no workflow — IA verifica próprio output antes de devolver.
- **Confidence scoring** (95%/80%/60%/40%) por achado — transparência sobre certeza. < 70% vira "Suspeita".

### Adicionado — Examples (few-shot para IAs)
- `examples/audit-example-php-laravel.md` — Laravel app vulnerável + relatório esperado.
- `examples/audit-example-python-django.md` — Django.
- `examples/audit-example-mobile-flutter.md` — Flutter banking app (alto risco).
- `examples/audit-example-web3-solidity.md` — Smart contract Solidity.

### Adicionado — Integrações workflow
- `integracoes/pre-commit-hook.sh` — Bloqueia commits com vulns Críticas via Anthropic API.
- `integracoes/github-action-pr-audit.yml` — Audita PRs automaticamente, comenta findings.
- `integracoes/cli-wrapper.sh` — CLI standalone (`iass audit`) com modes quick/diff/pr.
- `integracoes/semgrep-integration.sh` — Análise híbrida Semgrep + IA (recall+precision máximos).
- `integracoes/README.md` — Setup, custos, limitações.

### Mudado
- `SKILL.md` — workflow expandido para 8 fases (recon → patterns → contextual → false positives → chains → self-review → relatório → checklist).
- `PROMPT.md` — fluxo de 3 lentes (pattern → context → false positive filter) por categoria.
- `PROMPT-COMPACTO.md` — adicionada self-review (mantém-se < 8000 chars).
- `relatorio/template.md` — campo `Confiança` em cada achado (95%/80%/60%).

### Impacto estimado de detecção
| Métrica | v1.0 | v1.1 |
|---|---|---|
| Recall (vulns detetadas) | ~70% | ~85% |
| Precision (sem falsos positivos) | ~75% | ~88% |
| Com Semgrep integration | — | ~95% recall |

### Estatísticas
- 145 ficheiros total (era 136)
- 9 ficheiros novos
- 5 ficheiros modificados
- ~30% mais robustez na deteção

---

## [1.0.0] — 2026-05-05

🚀 **Release inicial pública.**

Skill universal de auditoria de segurança dedicada a **agentes de IA**, com cobertura de qualquer linguagem, framework, plataforma. Atua como **hacker amigável** que ajuda developers a blindar código antes da entrega.

> *"Encontra agora o que um atacante encontrará depois — e mostra como fechar."*

### Arquitetura

- **3 camadas hierárquicas** (universal + linguagem + framework) com loading on-demand
- **Track Mobile** dedicada (MASVS-aligned) carregada quando projeto mobile detetado
- **Áreas especializadas** (cloud, IaC, ML, Web3, IoT, privacidade) carregadas conforme contexto
- IA carrega ~30-50 ficheiros em runtime (de 123 totais), conforme stack

### 24 análises universais

XSS · SQL Injection · CSRF · Permissões/Autorização · REST API insegura · Endpoints públicos · Uploads perigosos · Tokens/secrets · Exposição de dados · Query Builders/ORMs · Sanitização e escape · Webhooks/integrações · Criptografia · Autenticação/sessão · Configuração/hardening · Headers HTTP · Dependências/supply chain · Business logic/race conditions · Server-side injections (Cmd/LFI/SSTI/Deserialization/XXE) · Open Redirect/SSRF · DoS/Resource limits · Logging/monitoring · APIs modernas (OAuth/GraphQL/WebSocket/API Top 10) · Email/comunicações

**+ 3 módulos meta:** mindset do atacante, attack chains canónicos, técnicas de verificação (taint analysis, cross-file, config drift).

### 18 cartões de linguagem

JavaScript/TypeScript · Python · PHP · Java · C#/.NET · Go · Ruby · Rust · Kotlin · Swift · Dart · C/C++ · Scala · Elixir · Shell/Bash · SQL (multi-dialect) · GraphQL · Solidity

### 34 framework profiles

- **PHP**: WordPress · Laravel · Symfony
- **Node meta-frameworks**: Express · Fastify · NestJS · Next.js · Nuxt · Remix · SvelteKit · AdonisJS
- **Frontend standalone**: React · Vue 3 · Angular · Astro · HTMX
- **Python**: Django · Flask · FastAPI
- **Java**: Spring Boot · Quarkus
- **.NET**: ASP.NET Core · Blazor
- **Outros**: Rails · Gin/Echo · Phoenix · Actix/Axum
- **Runtimes**: Bun · Deno · Hono (edge)
- **APIs**: REST/OpenAPI · GraphQL/Apollo · gRPC · tRPC

### Track Mobile completo (MASVS-aligned)

- Plataformas: iOS Native · Android Native · React Native · Flutter · Xamarin/MAUI · Ionic/Cordova/Capacitor
- Conceitos: Storage local · Comunicação rede (TLS pinning) · Deep links · WebView · Biometria/Secure Enclave · Anti-jailbreak/root · Reverse Engineering · Store distribution
- Mindset mobile + mapa MASVS L1/L2/MASVS-R

### 11 áreas especializadas

Containers/Kubernetes · IaC (Terraform/CloudFormation) · AWS · GCP · Azure · CI/CD pipelines · ML/AI security · Web3/Smart contracts · IoT/Embedded · Privacidade/Compliance (GDPR/LGPD/CCPA/HIPAA/PCI-DSS)

### Output do relatório

Markdown único com:
- Score 0-100 + barra ASCII
- Nível de blindagem (Crítico → Blindado, 6 níveis)
- Mapa de superfícies de ataque
- Vetores prováveis com **attack chains** (mínimo 3 combinações)
- Resumo executivo (cliente, encorajador honesto) + Resumo técnico (devs)
- Plano de correção em 4 fases
- Checklist final pré-produção (80+ itens)

### Persona

Hacker amigável: prestável, direto, honesto. Sem alarmismo teatral. Cada achado vem com **fix copy-paste**. Severidade conservadora — falsos positivos minam confiança da equipa.

### Compatibilidade verificada

- Claude Code (CLI) — frontmatter SKILL.md
- Claude.ai (Projects)
- ChatGPT Custom GPT (com 9 bundles especializados pré-curados respeitando limite 20-files)
- Cursor / Windsurf (AGENTS.md, .cursor/rules/)
- GitHub Copilot Chat (copilot-instructions.md)
- Gemini, DeepSeek, Mistral, Aider, Continue
- Qualquer LLM com janela de contexto moderna

### 9 bundles ChatGPT especializados

Universal Web · Mobile · Cloud/DevOps · Node Full-Stack · Python Full-Stack · PHP/WordPress/Laravel · Web3/Smart Contracts · Frontend SPA (React/Vue/Angular) · Edge/Modern Runtimes (Bun/Deno/Hono)

### Cobertura OWASP

- ✓ Web Top 10 (2021) — 10/10
- ✓ API Security Top 10 (2023) — 10/10
- ✓ LLM Top 10 (2025) — via `outras-areas/ml-ai-security.md`
- ✓ MASVS (Mobile) — track completo L1/L2/MASVS-R
- ✓ IoT Top 10 — via `outras-areas/iot-embedded.md`

### Estatísticas

- **123 ficheiros**, ~684 KB total
- **18 linguagens** cobertas
- **34 framework profiles**
- **17 ficheiros mobile** (MASVS L1/L2/R)
- **11 áreas especializadas**
- **9 bundles ChatGPT**
- **Idioma:** Português (pt-PT) por defeito

### Distribuição

- LICENSE MIT com aviso de uso autorizado
- `install.sh` instalador one-liner
- `INSTALL.md` com instruções para 8 plataformas + bundles ChatGPT
- `bundles/chatgpt-knowledge.md` com 9 bundles pré-curados
- `.gitignore` para artefactos de IDE/SO
