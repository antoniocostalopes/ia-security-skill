# Attack Chains — Como Vulnerabilidades Pequenas se Tornam Críticas

> Bug bounty hunters de topo ganham mais por **chains** do que por bugs isolados. Esta lente é obrigatória na auditoria.

## Princípio

Severidade isolada engana. **Combinas achados** que individualmente são Médio/Baixo e descobres que somados dão Crítico.

> Regra: se 2+ achados se cruzam, escreve uma **attack chain** no relatório, mesmo que cada um seja Baixo.

## Chains clássicos

### Chain 1 — Account Takeover por enumeração + spray
```
[Médio] /wp-json/wp/v2/users devolve usernames a anónimos
   +
[Médio] Login sem rate limit
   +
[Baixo] Mensagem "password incorreta para X" (vs "user não existe")
   =
[Crítico] Password spraying viável → takeover de qualquer conta com password fraca
```

### Chain 2 — Self-XSS → Account Takeover
```
[Baixo] Self-XSS no perfil do user (só o próprio vê)
   +
[Médio] CSRF na função "alterar email do perfil"
   =
[Alto] Atacante força vítima a abrir URL → CSRF altera email → reset password → takeover
```

### Chain 3 — IDOR + Info Disclosure → PII massiva
```
[Médio] IDOR em GET /api/users/{id} (devolve nome+email se autenticado)
   +
[Baixo] User IDs sequenciais (1, 2, 3, ...)
   =
[Crítico] Scrape completo da base de utilizadores
```

### Chain 4 — Open Redirect → OAuth token theft
```
[Baixo] Open redirect em ?next=URL
   +
[Médio] OAuth callback usa o mesmo parâmetro
   =
[Crítico] Atacante captura token OAuth → tomada de conta
```

### Chain 5 — Upload + Path Traversal → RCE
```
[Médio] Upload sem validação de magic bytes (aceita PHP renomeado)
   +
[Baixo] Diretório de upload servido com execução PHP
   +
[Baixo] Nome de ficheiro não sanitizado permite ../
   =
[Crítico] Upload de webshell em path arbitrário → RCE
```

### Chain 6 — SSRF + Cloud Metadata → cloud takeover
```
[Médio] wp_remote_get($_POST['url']) sem validação de IP
   +
[Baixo] App corre em EC2/GCE com role IAM
   =
[Crítico] SSRF para 169.254.169.254 → roubo de credenciais cloud → takeover de infra
```

### Chain 7 — Verbose error + SQLi blind → DB dump
```
[Baixo] WP_DEBUG_DISPLAY revela queries SQL em erros
   +
[Médio] SQLi blind num parâmetro pouco usado
   =
[Alto] Erros confirmam injeção rapidamente → dump completo da BD
```

### Chain 8 — Stored XSS de admin → supply chain
```
[Médio] Stored XSS apenas executável por admin (campo "notas internas")
   +
[Baixo] Admin tem permissão para editar plugins
   =
[Crítico] Atacante submete conteúdo malicioso → admin abre → XSS executa edit_plugins → backdoor permanente
```

### Chain 9 — CSRF + Mass Assignment → privilege escalation
```
[Médio] CSRF no endpoint /profile/update
   +
[Médio] wp_update_user($_POST) sem allowlist de campos
   =
[Crítico] Atacante força admin a abrir URL → CSRF muda role do atacante para admin
```

### Chain 10 — Webhook sem assinatura + idempotency fraca → fraude
```
[Médio] Webhook de pagamento sem validação HMAC
   +
[Médio] Marca pago apenas com base no payload
   +
[Baixo] Sem deduplicação de event_id
   =
[Crítico] Atacante forja webhooks → marca encomendas como pagas
```

### Chain 11 — Race condition em código de cupão
```
[Baixo] Cupão "10% único por user" verificado antes de usar
   +
[Médio] Sem lock/transação atómica
   =
[Alto] 100 requests paralelos usam o mesmo cupão 100x → perda financeira
```

### Chain 12 — Subdomain takeover + cookie partilhado
```
[Médio] Subdomínio antigo aponta para serviço descontinuado (ex.: Heroku app eliminada)
   +
[Baixo] Cookies de sessão definidos para .dominio.com (todo o domínio)
   =
[Crítico] Atacante reclama subdomínio → recebe cookies de sessão → takeover
```

### Chain 13 — Reset password + race + email enumeration
```
[Baixo] Reset password sem rate limit
   +
[Baixo] Token de reset com 6 dígitos (10^6 = 1M combinações)
   +
[Médio] Endpoint "esqueci-me" confirma se email existe
   =
[Alto] Brute force de token em ~minutos para alvos confirmados
```

### Chain 14 — Cache poisoning via header → XSS para todos
```
[Médio] Cache HTTP com chaves baseadas só em URL+Cookie
   +
[Baixo] App reflete X-Forwarded-Host em meta tags sem escape
   =
[Crítico] Atacante envia 1 request → resposta envenenada cacheada → XSS servido a todos
```

### Chain 15 — XXE em upload de SVG → leitura de wp-config
```
[Médio] Upload de SVG aceito sem sanitização
   +
[Baixo] Parser XML do plugin tem entidades externas habilitadas
   =
[Crítico] SVG com XXE → leitura de /var/www/wp-config.php → DB credentials
```

## Como integrar no relatório

Na secção **Previsão de Vetores Prováveis**, em vez de listar achados isolados:

```markdown
## 5. Previsão de Vetores Prováveis

### Vetor 1 — Password Spraying (Crítico)
Encadeia: A2 (REST users exposto) + A4 (sem rate limit) + B3 (mensagens login distintas)
1. Atacante extrai 200 usernames via /wp-json/wp/v2/users
2. Tenta top-100 passwords contra cada
3. Mensagens distintas confirmam contas com password fraca
4. Takeover de qualquer conta vulnerável
*Tempo:* horas. *Skill:* baixo. *Detect:* logs de login (se existirem).

### Vetor 2 — RCE via Upload + Path Traversal (Crítico)
Encadeia: C1 (validação só por extensão) + B2 (sem .htaccess no /uploads/)
...
```

## Heurística para descobrir chains

Ao rever achados, faz **cross-reference**:

| Se tens isto... | Procura isto... | Possível chain |
|---|---|---|
| Info disclosure | Falta de rate limit | Enumeração + brute force |
| XSS armazenado | Permissões largas para admin | Privilege escalation |
| CSRF | Mass assignment | Auth changes silenciosas |
| SSRF | Cloud / serviços internos | Cloud takeover |
| Open redirect | OAuth / SAML | Token theft |
| IDOR | IDs sequenciais | Scrape massivo |
| Upload fraco | Execução no diretório | RCE |
| Webhook fraco | Operações financeiras | Fraude |
| Race condition | Operações idempotentes assumidas | Duplicate spend |
| Subdomain takeover | Cookies wide-scope | Session theft |

## Regra final

> **Nunca devolvas um relatório sem pelo menos tentar 3 chains.** Mesmo que não encontres, demonstra que pensaste o suficiente. Se encontras, são quase sempre o achado de maior impacto do report.
