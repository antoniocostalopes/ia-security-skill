# Changelog

Todas as mudanças notáveis a esta skill são documentadas aqui.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/), versionamento [SemVer](https://semver.org/).

## [1.0.0] — 2026-05-06

**Release inicial pública.**

Skill nativa do Claude Code para auditoria de segurança defensiva pré-entrega. Funciona em qualquer projeto Claude Code com `git clone` único para `~/.claude/skills/seguranca/` — zero configuração por projeto, zero ficheiros copiados para repos.

> *"Encontra agora o que um atacante encontrará depois — e mostra como fechar."*

### Arquitetura

- **3 camadas hierárquicas** (universal + linguagem + framework) com loading on-demand
- **Track Mobile** dedicada (MASVS-aligned) carregada quando projeto mobile detetado
- **Áreas especializadas** (cloud, IaC, ML, Web3, IoT, privacidade) carregadas conforme contexto
- IA carrega 15-50 ficheiros em runtime conforme stack (de ~135 totais)

### Workflow em 7 fases

1. Reconhecimento (lê manifests e deteta stack)
2. Análise universal (24 categorias)
3. Análise específica por linguagem/framework
4. Attack chains (mínimo 3 cadeias)
5. Self-review com confidence scoring (95%/80%/60%/40%)
6. Cálculo de score & blindagem
7. Geração do relatório + checklist pré-produção

### 24 análises universais

XSS · SQL Injection · CSRF · Permissões/Autorização · REST API insegura · Endpoints públicos · Uploads perigosos · Tokens/secrets · Exposição de dados · Query Builders/ORMs · Sanitização e escape · Webhooks/integrações · Criptografia · Autenticação/sessão · Configuração/hardening · Headers HTTP · Dependências/supply chain · Business logic/race conditions · Server-side injections (Cmd/LFI/SSTI/Deserialization/XXE) · Open Redirect/SSRF · DoS/Resource limits · Logging/monitoring · APIs modernas (OAuth/GraphQL/WebSocket/API Top 10) · Email/comunicações

**+ 5 módulos meta:** mindset do atacante, attack chains canónicos, técnicas de verificação (taint analysis, cross-file, config drift), patterns de deteção (regex/keywords literais), falsos positivos comuns (anti-hallucination).

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

### 10 áreas especializadas

Containers/Kubernetes · IaC (Terraform/CloudFormation) · AWS · GCP · Azure · CI/CD pipelines · ML/AI security · Web3/Smart contracts · IoT/Embedded · Privacidade/Compliance (GDPR/LGPD/CCPA/HIPAA/PCI-DSS)

### 5 examples reais (few-shot)

- `examples/audit-example-node.md` — Node.js / Express
- `examples/audit-example-php-laravel.md` — Laravel app vulnerável + relatório esperado
- `examples/audit-example-python-django.md` — Django
- `examples/audit-example-mobile-flutter.md` — Flutter banking app
- `examples/audit-example-web3-solidity.md` — Smart contract Solidity

### Output do relatório

Markdown único com:

- Score 0-100 + nível de blindagem (Crítico → Blindado, 6 níveis)
- Mapa de superfícies de ataque
- Attack chains (mínimo 3 cadeias de exploração)
- Resumo executivo (cliente) + Resumo técnico (devs)
- Achados detalhados com severidade, ficheiro:linha, código vulnerável, exploração, **fix copy-paste**, confidence
- Plano de correção em 4 fases
- Checklist pré-produção

### Cobertura OWASP

- Web Top 10 (2021) — 10/10
- API Security Top 10 (2023) — 10/10
- LLM Top 10 (2025) — via `outras-areas/ml-ai-security.md`
- MASVS (Mobile) — track completo L1/L2/MASVS-R
- IoT Top 10 — via `outras-areas/iot-embedded.md`

### Tom

Direto, prestável, honesto. Sem alarmismo teatral. Cada achado vem com fix copy-paste. Severidade conservadora — falsos positivos minam confiança da equipa.

### Distribuição

- Licença MIT com aviso de uso autorizado
- Instalação `git clone` único para `~/.claude/skills/seguranca/`
- `INSTALL.md` com instruções macOS/Linux/Windows
- `USAGE.md` com 5 cenários típicos + FAQ
- `.gitignore` para artefactos de IDE/SO
- CI/CD GitHub Actions valida estrutura, cross-references, frontmatter, duplicados, tamanho
