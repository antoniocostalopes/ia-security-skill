# Bundles para ChatGPT Custom GPT

> ChatGPT Custom GPT limita Knowledge a **20 ficheiros**. Como a skill total tem ~110 ficheiros, oferecemos **bundles especializados** — escolhe o que match ao teu uso.

## Configuração comum (todos os bundles)

### Instructions (campo de 8000 chars)
Cola conteúdo de **`PROMPT-COMPACTO.md`** (~5800 chars).

### Description
*"Hacker amigável que ajuda developers a blindar código antes da entrega. Auditoria universal de segurança."*

### Knowledge
Carrega 20 ficheiros conforme bundle escolhido abaixo.

---

## Bundle 1 — **Universal Web** (default, recomendado)

Para audit de aplicações web genéricas, qualquer linguagem.

```
1.  analises/xss.md
2.  analises/sql-injection.md
3.  analises/csrf.md
4.  analises/permissoes.md
5.  analises/rest-api.md
6.  analises/endpoints-publicos.md
7.  analises/uploads.md
8.  analises/tokens.md
9.  analises/exposicao-dados.md
10. analises/query-builders-orm.md
11. analises/sanitizacao.md
12. analises/webhooks-integracoes.md
13. analises/13-criptografia.md
14. analises/14-autenticacao-sessao.md
15. analises/15-configuracao-hardening.md
16. analises/16-headers-http.md
17. analises/17-dependencias.md
18. analises/19-injection-server-side.md
19. analises/20-open-redirect-ssrf.md
20. relatorio/template.md
```

> Mindset, attack chains, business-logic, DoS, logging, APIs modernas, email — tudo já está inline em PROMPT-COMPACTO.md.

---

## Bundle 2 — **Mobile**

Para audit de apps móveis (iOS, Android, RN, Flutter).

```
1.  analises/14-autenticacao-sessao.md
2.  analises/13-criptografia.md
3.  analises/16-headers-http.md
4.  analises/17-dependencias.md
5.  mobile/00-mindset-mobile.md
6.  mobile/00-masvs-mapping.md
7.  mobile/ios-native.md
8.  mobile/android-native.md
9.  mobile/react-native.md
10. mobile/flutter.md
11. mobile/armazenamento-local.md
12. mobile/comunicacao-rede.md
13. mobile/deeplinks-intents.md
14. mobile/webview.md
15. mobile/biometria-secure-enclave.md
16. mobile/jailbreak-root-tampering.md
17. mobile/reverse-engineering.md
18. mobile/store-distribution.md
19. relatorio/template.md
20. relatorio/checklist-producao.md
```

---

## Bundle 3 — **Cloud / DevOps**

Para audit de IaC, containers, pipelines, cloud configs.

```
1.  analises/13-criptografia.md
2.  analises/15-configuracao-hardening.md
3.  analises/17-dependencias.md
4.  analises/22-logging-monitoring.md
5.  analises/tokens.md
6.  outras-areas/containers-k8s.md
7.  outras-areas/iac-terraform.md
8.  outras-areas/cloud-aws.md
9.  outras-areas/cloud-gcp.md
10. outras-areas/cloud-azure.md
11. outras-areas/ci-cd-pipelines.md
12. linguagens/shell-bash.md
13. frameworks/api/rest-openapi.md
14. analises/20-open-redirect-ssrf.md
15. analises/permissoes.md
16. relatorio/template.md
17. relatorio/checklist-producao.md
18. relatorio/score-blindagem.md
19. analises/00-tecnicas-verificacao.md
20. analises/00-attack-chains.md
```

---

## Bundle 4 — **Node.js Full-Stack** (Express/Next/Nest)

Para apps Node end-to-end.

```
1.  analises/xss.md
2.  analises/sql-injection.md
3.  analises/csrf.md
4.  analises/permissoes.md
5.  analises/13-criptografia.md
6.  analises/14-autenticacao-sessao.md
7.  analises/16-headers-http.md
8.  analises/17-dependencias.md
9.  analises/19-injection-server-side.md
10. analises/20-open-redirect-ssrf.md
11. analises/23-api-modernas.md
12. linguagens/javascript-typescript.md
13. linguagens/sql.md
14. frameworks/web/node-express.md
15. frameworks/web/node-nextjs.md
16. frameworks/web/node-nestjs.md
17. frameworks/api/graphql-apollo.md
18. relatorio/template.md
19. relatorio/checklist-producao.md
20. relatorio/score-blindagem.md
```

---

## Bundle 5 — **Python Full-Stack** (Django/Flask/FastAPI)

```
1.  analises/xss.md
2.  analises/sql-injection.md
3.  analises/csrf.md
4.  analises/permissoes.md
5.  analises/13-criptografia.md
6.  analises/14-autenticacao-sessao.md
7.  analises/16-headers-http.md
8.  analises/17-dependencias.md
9.  analises/19-injection-server-side.md
10. analises/20-open-redirect-ssrf.md
11. analises/23-api-modernas.md
12. linguagens/python.md
13. linguagens/sql.md
14. frameworks/web/python-django.md
15. frameworks/web/python-flask.md
16. frameworks/web/python-fastapi.md
17. frameworks/api/rest-openapi.md
18. relatorio/template.md
19. relatorio/checklist-producao.md
20. relatorio/score-blindagem.md
```

---

## Bundle 6 — **PHP/WordPress/Laravel**

```
1.  analises/xss.md
2.  analises/sql-injection.md
3.  analises/csrf.md
4.  analises/permissoes.md
5.  analises/query-builders-orm.md
6.  analises/sanitizacao.md
7.  analises/13-criptografia.md
8.  analises/14-autenticacao-sessao.md
9.  analises/15-configuracao-hardening.md
10. analises/16-headers-http.md
11. analises/17-dependencias.md
12. analises/uploads.md
13. analises/tokens.md
14. linguagens/php.md
15. frameworks/web/php-wordpress.md
16. frameworks/web/php-laravel.md
17. frameworks/web/php-symfony.md
18. relatorio/template.md
19. relatorio/checklist-producao.md
20. relatorio/score-blindagem.md
```

---

## Bundle 8 — **Frontend SPA** (React/Vue/Angular standalone)

Para apps SPA puras com backend separado.

```
1.  analises/xss.md
2.  analises/csrf.md
3.  analises/permissoes.md
4.  analises/13-criptografia.md
5.  analises/14-autenticacao-sessao.md
6.  analises/16-headers-http.md
7.  analises/17-dependencias.md
8.  analises/20-open-redirect-ssrf.md
9.  analises/23-api-modernas.md
10. linguagens/javascript-typescript.md
11. frameworks/web/react-standalone.md
12. frameworks/web/vue-standalone.md
13. frameworks/web/angular.md
14. frameworks/api/rest-openapi.md
15. frameworks/api/graphql-apollo.md
16. frameworks/api/trpc.md
17. analises/sanitizacao.md
18. relatorio/template.md
19. relatorio/checklist-producao.md
20. relatorio/score-blindagem.md
```

---

## Bundle 9 — **Edge / Modern Runtimes** (Bun/Deno/Hono/Cloudflare Workers)

```
1.  analises/13-criptografia.md
2.  analises/14-autenticacao-sessao.md
3.  analises/17-dependencias.md
4.  analises/20-open-redirect-ssrf.md
5.  analises/23-api-modernas.md
6.  linguagens/javascript-typescript.md
7.  linguagens/sql.md
8.  frameworks/runtime/bun.md
9.  frameworks/runtime/deno.md
10. frameworks/runtime/hono.md
11. frameworks/api/rest-openapi.md
12. frameworks/api/graphql-apollo.md
13. frameworks/api/trpc.md
14. outras-areas/ci-cd-pipelines.md
15. analises/22-logging-monitoring.md
16. analises/16-headers-http.md
17. analises/permissoes.md
18. relatorio/template.md
19. relatorio/checklist-producao.md
20. relatorio/score-blindagem.md
```

---

## Bundle 7 — **Web3 / Smart Contracts**

```
1.  analises/13-criptografia.md
2.  analises/14-autenticacao-sessao.md
3.  analises/17-dependencias.md
4.  analises/18-business-logic-race.md
5.  analises/22-logging-monitoring.md
6.  linguagens/solidity.md
7.  outras-areas/web3-smart-contracts.md
8.  outras-areas/ci-cd-pipelines.md
9.  analises/00-mindset-atacante.md
10. analises/00-attack-chains.md
11. analises/00-tecnicas-verificacao.md
12. analises/permissoes.md
13. analises/20-open-redirect-ssrf.md
14. linguagens/javascript-typescript.md
15. frameworks/web/node-nextjs.md
16. analises/16-headers-http.md
17. analises/23-api-modernas.md
18. relatorio/template.md
19. relatorio/checklist-producao.md
20. relatorio/score-blindagem.md
```

## Para utilizadores de outras IAs

Se usas Claude Code, Cursor, Windsurf, Copilot, Gemini, ou qualquer LLM com janela de contexto generosa, **ignora estes bundles** — carrega a pasta inteira (~123 ficheiros). A IA carrega o que precisa em runtime.

## Verificação

Após configurar Custom GPT, pede:
> *"Qual é o lema desta skill?"*

Resposta esperada:
> *"Encontra agora o que um atacante encontrará depois — e mostra como fechar."*
