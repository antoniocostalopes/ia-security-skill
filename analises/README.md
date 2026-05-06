# Análises — Vulnerabilidades Universais

> 24 análises de vulnerabilidades aplicáveis a qualquer projeto + 5 módulos meta (mindset, chains, técnicas, patterns, falsos positivos). A IA carrega estes ficheiros conforme as regras de loading em [`../SKILL.md`](../SKILL.md).

## Loading

| Ficheiro | Quando carregar | Tamanho |
|---|---|---|
| `00-mindset-atacante.md` | **Sempre** (define lente analítica) | 12 KB |
| `00-attack-chains.md` | Sempre (skip se auditar 1 ficheiro só) | 6 KB |
| `00-tecnicas-verificacao.md` | **Sempre** (taint analysis, cross-file, config drift) | 7 KB |
| `00-patterns-deteccao.md` | **Sempre** (regex/keywords concretos por categoria) | 9 KB |
| `00-falsos-positivos-comuns.md` | **Sempre** (anti-hallucination) | 8 KB |

Categorias específicas — carregar **só as relevantes** ao tipo de projeto:

| # | Ficheiro | Categoria | Carregar quando |
|---|---|---|---|
| 1 | `xss.md` | XSS | Output HTML/JS, templating, frontend |
| 2 | `sql-injection.md` | SQL Injection | Acesso a base de dados (raw queries, ORMs com escape mode) |
| 3 | `csrf.md` | CSRF | Endpoints autenticados que mutam estado (POST/PUT/DELETE) |
| 4 | `permissoes.md` | Falhas de permissão | Há autenticação ou múltiplos roles |
| 5 | `rest-api.md` | REST API insegura | API REST exposta |
| 6 | `endpoints-publicos.md` | Endpoints públicos | Endpoints sem auth (signup, contact, etc.) |
| 7 | `uploads.md` | Uploads perigosos | Aceita ficheiros do utilizador |
| 8 | `tokens.md` | Vazamento de tokens | Lida com API keys, JWTs, secrets |
| 9 | `exposicao-dados.md` | Exposição de dados | PII, dados de cartão, healthcare |
| 10 | `query-builders-orm.md` | Query builders/ORMs | Usa Prisma, Eloquent, ActiveRecord, Sequelize, SQLAlchemy, JPA, etc. |
| 11 | `sanitizacao.md` | Sanitização e escape | Aceita input do utilizador |
| 12 | `webhooks-integracoes.md` | Webhooks/integrações | Recebe ou envia webhooks |
| 13 | `13-criptografia.md` | Criptografia | Encripta/desencripta, hash de passwords, signing |
| 14 | `14-autenticacao-sessao.md` | Auth/sessão | Login, sessões, JWTs, OAuth |
| 15 | `15-configuracao-hardening.md` | Configuração/hardening | **Sempre** (config files, env, secrets) |
| 16 | `16-headers-http.md` | Headers HTTP | Servidor web ou API HTTP |
| 17 | `17-dependencias.md` | Dependências/supply chain | Tem manifests (`package.json`, `composer.json`, etc.) |
| 18 | `18-business-logic-race.md` | Business logic / race | Tem fluxos de negócio (checkout, payment, voting) |
| 19 | `19-injection-server-side.md` | Server-side injections (Cmd/LFI/SSTI/Deserialization/XXE) | Server-side dinâmico |
| 20 | `20-open-redirect-ssrf.md` | Open Redirect / SSRF | Redirects ou fetch de URLs do utilizador |
| 21 | `21-dos-resource-limits.md` | DoS / resource limits | Endpoints públicos ou processamento pesado |
| 22 | `22-logging-monitoring.md` | Logging / monitoring | **Sempre** (audit trail, observabilidade) |
| 23 | `23-api-modernas.md` | APIs modernas (OAuth/GraphQL/WebSocket) | OAuth, GraphQL, WebSocket, gRPC |
| 24 | `24-email-comunicacao.md` | Email / comunicações | Envia emails, SMS, push notifications |

## Estrutura típica de cada ficheiro

Cada análise segue:
1. **O que procurar** — patterns concretos
2. **Sinais de alarme** — code smells e palavras-chave
3. **Quick wins** — checklist 8-10 itens
4. **Falsos positivos** — quando NÃO é vulnerabilidade
5. **Severidade típica** — em linguagem honesta

## Cross-references

Análises usam linguagem agnóstica. Para específico de linguagem ver [`../linguagens/`](../linguagens/) e específico de framework ver [`../frameworks/`](../frameworks/).
