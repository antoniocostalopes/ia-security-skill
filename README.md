# IA Security Skill — para Claude Code

> *Por António Lopes · Open Source · MIT*

[![Open Source](https://img.shields.io/badge/Open%20Source-%E2%9D%A4-red.svg)](https://github.com/antoniocostalopes/ia-security-skill)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue)]()
[![Claude Code](https://img.shields.io/badge/Claude%20Code-native-purple)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![PT](https://img.shields.io/badge/lang-pt--PT-green)]()

> **Skill nativa do Claude Code** para auditoria de segurança defensiva pré-entrega — qualquer linguagem, framework, plataforma. Pensa como invasor, age como defensor, devolve fixes copy-paste.

> *"Encontra agora o que um invasor encontrará depois — e mostra como fechar."*

## Instalação — 1 comando

```bash
git clone https://github.com/antoniocostalopes/ia-security-skill ~/.claude/skills/seguranca
```

Pronto. **Zero configuração por projeto, zero ficheiros copiados para os teus repos.** O Claude Code deteta a skill automaticamente em qualquer pasta onde corras `claude`.

## Uso — 1 frase

Dentro de qualquer projeto:

```bash
cd ~/projetos/o-meu-projeto
claude
> audita este projeto
```

Em ~30 segundos recebes um relatório Markdown com score, attack chains, achados detalhados e fixes copy-paste.

Frases equivalentes que ativam a skill:
- *"audita este projeto"*
- *"faz security review"*
- *"audita src/ antes do deploy"*
- *"vê se este código tem vulnerabilidades"*
- *"usa a skill seguranca em [path]"*

## O que cobre

### 24 análises universais (sempre carregadas)
XSS · SQLi · CSRF · Permissões · REST API · Endpoints públicos · Uploads · Tokens · Exposição de dados · Query Builders/ORMs · Sanitização · Webhooks · Criptografia · Auth/Sessão · Hardening · Headers HTTP · Dependências/supply chain · Business logic/race conditions · Server-side injections (Cmd/LFI/SSTI/Deserialization/XXE) · Open Redirect/SSRF · DoS · Logging · APIs modernas (OAuth/GraphQL/WebSocket) · Email/SMS

> Plus 5 módulos meta: mindset do invasor, attack chains canónicos, técnicas de verificação, patterns de deteção, falsos positivos comuns.

### 18 linguagens
JavaScript/TypeScript · Python · PHP · Java · C#/.NET · Go · Ruby · Rust · Kotlin · Swift · Dart · C/C++ · Scala · Elixir · Shell/Bash · SQL · GraphQL · Solidity

### 34 frameworks
**PHP**: WordPress · Laravel · Symfony
**Node**: Express · Fastify · NestJS · Next.js · Nuxt · Remix · SvelteKit · AdonisJS
**Frontend**: React · Vue 3 · Angular · Astro · HTMX
**Python**: Django · Flask · FastAPI
**Java**: Spring Boot · Quarkus
**.NET**: ASP.NET Core · Blazor
**Outros**: Rails · Gin/Echo · Phoenix · Actix/Axum
**Runtimes**: Bun · Deno · Hono
**APIs**: REST/OpenAPI · GraphQL/Apollo · gRPC · tRPC

### Track Mobile (MASVS-aligned)
iOS Native · Android Native · React Native · Flutter · Xamarin/MAUI · Ionic/Cordova/Capacitor + Storage local · Network/Cert pinning · Deep links · WebView · Biometric · Anti-jailbreak/root · Reverse Engineering · Store distribution

### Outras áreas
Containers/Kubernetes · IaC (Terraform/CloudFormation) · AWS · GCP · Azure · CI/CD pipelines · ML/AI security · Web3/Smart contracts · IoT/Embedded · Privacidade/Compliance (GDPR/LGPD/CCPA/HIPAA/PCI-DSS)

## Como funciona

O Claude Code lê o frontmatter de [`SKILL.md`](SKILL.md) e ativa a skill quando o teu pedido bate com a descrição (ex: *"audita"*, *"security review"*, *"vulnerabilidades"*).

A skill executa um workflow em 7 fases:

1. **Reconhecimento** — lê manifests (`package.json`, `composer.json`, `requirements.txt`, `Info.plist`, `Dockerfile`, etc.) para detetar stack
2. **Análise universal** — 24 categorias aplicadas a qualquer projeto
3. **Análise específica** — carrega só os ficheiros de [`linguagens/`](linguagens/) e [`frameworks/`](frameworks/) relevantes
4. **Attack chains** — combina achados (mínimo 3 cadeias) para escalar severidade
5. **Self-review** — confidence scoring (95%/80%/60%/40%) e filtragem de falsos positivos
6. **Score & blindagem** — fórmula em [`relatorio/score-blindagem.md`](relatorio/score-blindagem.md)
7. **Relatório** — template fixo em [`relatorio/template.md`](relatorio/template.md)

### Carregamento hierárquico — 3 camadas

A IA carrega só o que precisa (não bloat por carregar tudo):

```
1. Universal (sempre)        → analises/      (24 análises + 5 meta)
2. Linguagem (per stack)     → linguagens/    (1-3 ficheiros)
3. Framework (per stack)     → frameworks/    (1-3 ficheiros)
+ Mobile (se aplicável)      → mobile/        (até 16 ficheiros MASVS)
+ Outras áreas (se relevante)→ outras-areas/  (containers, IaC, cloud, etc.)
```

Em runtime: 15-50 ficheiros ativos conforme stack.

## Output

Relatório Markdown único com:

- **Score 0-100** + nível de blindagem (Crítico → Blindado)
- **Mapa de superfícies de ataque** (entry points, trust boundaries)
- **Attack chains** (mínimo 3 cadeias de exploração)
- **Resumo executivo** (cliente) + **Resumo técnico** (devs)
- **Achados detalhados** com severidade, ficheiro:linha, código vulnerável, exploração, **fix copy-paste**, confidence
- **Plano de correção em 4 fases** (Críticos agora → Hardening tarde)
- **Checklist pré-produção**

Ver exemplos reais:
- [Node.js / Express](examples/audit-example-node.md)
- [PHP / Laravel](examples/audit-example-php-laravel.md)
- [Python / Django](examples/audit-example-python-django.md)
- [Mobile / Flutter](examples/audit-example-mobile-flutter.md)
- [Web3 / Solidity](examples/audit-example-web3-solidity.md)

## Estrutura

```
seguranca/
├── SKILL.md                  ← entry point (frontmatter Claude Code)
├── README.md / USAGE.md / INSTALL.md
├── CHANGELOG.md / CONTRIBUTING.md / SECURITY.md / LICENSE
├── analises/                 ← 24 análises + 5 meta (mindset/chains/verificação/patterns/falsos-positivos)
├── linguagens/               ← 18 cartões por linguagem
├── frameworks/
│   ├── web/                  ← 27 web frameworks
│   ├── api/                  ← REST/GraphQL/gRPC/tRPC
│   └── runtime/              ← Bun, Deno, Hono
├── mobile/                   ← 16 ficheiros MASVS-aligned
├── outras-areas/             ← Containers, IaC, Cloud, CI/CD, ML, Web3, IoT, Privacidade
├── examples/                 ← 5 exemplos de auditorias completas
├── relatorio/                ← templates de output (score, template, checklist)
├── commands/                 ← slash commands opcionais (/audita, /audita-rapido, /audita-diff)
├── agents/                   ← subagent opcional (auditor-seguranca)
└── .github/                  ← CI workflows + issue/PR templates
```

## Atualizar

```bash
cd ~/.claude/skills/seguranca && git pull
```

## Tom

> *"Aqui qualquer um corre código no teu server. Mau, mas o fix são 3 linhas — vamos a isso."*

Direto, prestável, honesto. Sem alarmismo teatral. Cada achado tem fix copy-paste. Severidade conservadora — falsos positivos minam confiança.

## Quem é para

- **Developers** que usam Claude Code e querem auditar o próprio código antes do deploy
- **Tech leads** a fazer security review pré-merge dentro do Claude Code
- **Equipas** que adotaram Claude Code como agente principal e querem segurança como capacidade nativa

## Quem **não** é para

- Pentesting de sistemas de terceiros sem autorização
- Compliance auditing formal (usar ferramentas dedicadas)
- Resposta a incidente / forense (usar SIEM)
- Quem **não** usa Claude Code (esta skill é específica do Claude Code; para outras IAs, garfa o repo e adapta)

## Cobertura OWASP

| OWASP | Cobertura |
|---|---|
| OWASP Top 10 (Web 2021) | 10/10 |
| OWASP API Security Top 10 (2023) | 10/10 |
| OWASP Top 10 LLM (2025) | via [`outras-areas/ml-ai-security.md`](outras-areas/ml-ai-security.md) |
| OWASP MASVS (Mobile) | track mobile completo |
| OWASP Top 10 IoT | via [`outras-areas/iot-embedded.md`](outras-areas/iot-embedded.md) |

## Versão

**v1.0.0** — Release inicial pública. Skill nativa Claude Code com 24 análises universais, 18 linguagens, 34 frameworks, track mobile MASVS, áreas especializadas, self-review pass, confidence scoring e 5 examples reais.

Ver [CHANGELOG.md](CHANGELOG.md) para detalhes.

## Como contribuir

Contribuições são bem-vindas:

- **Reportar bugs ou falsos positivos** — abrir issue
- **Sugerir nova categoria/framework/linguagem** — abrir issue com proposta
- **Pull requests** — ver [CONTRIBUTING.md](CONTRIBUTING.md)
- **Reportar vulnerabilidades** na própria skill — ver [SECURITY.md](SECURITY.md)
- **Star o repo** — ajuda outros developers Claude Code a descobrir

## Autor

**António Lopes**
GitHub: [@antoniocostalopes](https://github.com/antoniocostalopes)

## Licença

**MIT** — ver [LICENSE](LICENSE). Copyright © 2026 António Lopes.

Uso destinado a **auditoria defensiva pré-entrega** de código próprio ou autorizado. Não usar para testar sistemas de terceiros sem autorização.
