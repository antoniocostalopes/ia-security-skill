# Mindset do Atacante — Como um White Hat Pensa

> Este ficheiro define **como** auditar, não **o quê**. As 12 análises de categoria dizem-te o que procurar; este diz-te como pensar enquanto procuras.

## 1. As 4 perguntas para cada bloco de código

Para **cada função, endpoint, query ou template** que leres, perguntas, por esta ordem:

1. **Quem chega aqui?** (anónimo, autenticado, admin, sistema)
2. **O que controla o input?** (querystring, body, header, cookie, ficheiro, hostname, IP, timing)
3. **Para onde vai a saída?** (HTML, atributo, URL, JS, SQL, shell, eval, log, ficheiro, header HTTP, e-mail, BD, outro sistema)
4. **O que ganho se quebrar isto?** (RCE, leitura de DB, tomada de conta, info disclosure, DoS, pivot)

Se **as quatro respostas favorecerem o atacante**, há vulnerabilidade.

## 2. Cadeia de exploração (kill chain aplicada a código)

Vulnerabilidades raramente são úteis sozinhas. Auditas a **combinação**:

```
recon → identificação de superfície → input controlável → bypass de defesa →
execução → escalada de privilégio → persistência → exfiltração
```

Para cada achado, perguntas: *"isto sozinho é Médio, mas o que destranca?"* Um info disclosure (Médio) + user enumeration (Médio) + falta de rate limit (Médio) = **password spray viável (Crítico)**.

## 3. Recon como primeira fase

Antes de auditar código linha-a-linha:

### Mapa de ataque
- Lista **todas as entradas**: rotas web, REST, GraphQL, AJAX, webhooks, formulários, headers (User-Agent, Referer, X-Forwarded-For), cookies, parâmetros, ficheiros de upload, jobs cron, comandos CLI, message queues, SMTP inbound.
- Lista **todas as saídas**: respostas HTTP, redirects, e-mails enviados, chamadas a APIs externas, logs, ficheiros gerados, BD, cache, headers de resposta.
- Identifica o **trust boundary**: onde o input não confiável encontra código privilegiado.

### Stack fingerprinting
- Versões: WordPress (`/readme.html`, `?ver=` em assets), PHP (`X-Powered-By`), framework JS (bundles), DB (mensagens de erro).
- Plugins/temas instalados (paths em `/wp-content/`).
- CVEs conhecidos para essas versões.

### Discovery passivo
- `robots.txt`, `sitemap.xml`, `security.txt`.
- Headers de resposta (CSP, CORS, cookies).
- Diferenças de resposta para input válido vs inválido (oracle).

## 4. Princípios para pensar como atacante

### Assume tudo é controlável
- Headers `X-Forwarded-For`, `Host`, `Origin`, `Referer` são **input do utilizador**.
- `User-Agent` é input.
- IP do cliente atrás de proxy mal configurado é forjável.
- Cookies são editáveis.
- Order de campos em multipart/form-data é controlável.
- Tipos JSON são controláveis (`{"id": "1"}` vs `{"id": [1,2]}` vs `{"id": null}` vs `{"id": {"$ne": null}}`).

### Procura "edge cases" maliciosos
- Strings vazias, `null`, `undefined`, `0`, `false`, `[]`, `{}`.
- Strings muito longas (10MB).
- Unicode: zero-width, RTL override (U+202E), homoglyphs, normalização (NFC/NFD).
- Encoding duplo: `%2527` → `%27` → `'`.
- Null bytes: `file.php%00.jpg`.
- Path traversal: `../`, `..%2F`, `....//`, `..%c0%af`.
- Comments injetados: `/**/`, `--`, `#`, `<!---->`.
- Case variation onde a validação é case-sensitive: `SCRIPT` vs `script`.
- Whitespace alternativo: tab, vertical tab, form feed, non-breaking space.

### Trust nada
- Não confia em validação client-side (qualquer um remove com DevTools).
- Não confia em `Content-Type` enviado pelo cliente.
- Não confia em filename de upload.
- Não confia em `Origin` / `Referer` (forjáveis em pedidos não-browser).
- Não confia em "este endpoint só é chamado por X" (qualquer um chama).
- Não confia em obscuridade ("ninguém adivinha esta URL").

### Procura assimetrias
- Resposta diferente para user existente vs inexistente → enumeração.
- Tempo diferente para login válido vs inválido → timing oracle.
- Erro detalhado em ambiente X, genérico em Y → info disclosure parcial.
- Cache hit vs miss em endpoint personalizado → cache poisoning.

## 5. Ferramentas mentais (o que cada ferramenta encontraria)

Mesmo sem correr ferramentas, **simula** o que encontrariam:

| Ferramenta | O que procura — usa esta lente ao ler o código |
|---|---|
| **Burp Suite Intruder** | Endpoints sem rate limit, parâmetros fuzzáveis |
| **sqlmap** | Pontos de injeção em qualquer parâmetro que toca em SQL |
| **ffuf / dirsearch** | Endpoints/ficheiros não documentados expostos |
| **nuclei** | CVEs conhecidos por versão de plugin/lib |
| **Nikto** | Misconfigurations clássicas (`.git`, `phpinfo`, `xmlrpc`) |
| **WPScan** | Plugins/temas vulneráveis, user enum, weak passwords |
| **OWASP ZAP** | XSS, SQLi, headers de segurança |
| **Semgrep / CodeQL** | Padrões SAST (taint tracking) |
| **TruffleHog / Gitleaks** | Secrets em código e histórico git |
| **Bandit / Brakeman** | Padrões inseguros por linguagem |

## 6. Técnicas de bypass que tens de assumir que o atacante conhece

### Bypass de filtros / WAF
- Encoding: URL, double URL, HTML entity, Unicode, hex, base64.
- Case variation onde aplicável.
- Comentários SQL: `SE/**/LECT`, `UNION/*!50000*/SELECT`.
- Concatenação: `'admin' = 'ad'+'min'` (SQL Server), `CONCAT('ad','min')` (MySQL).
- Wildcards: `%`, `_`, `*`.
- Funções alternativas: `0x61646d696e` (hex), `CHAR(97,100,...)`, `CHR(97)`.
- Quebra de keywords: `SELECT` → `SEL/**/ECT` → `%53ELECT`.
- HTTP Parameter Pollution: `?id=1&id=2` (servidor escolhe um, WAF analisa outro).
- HTTP Request Smuggling: `Content-Length` vs `Transfer-Encoding`.
- Method override: `X-HTTP-Method-Override: PUT` em POST.
- Verb tampering: usar `HEAD` em vez de `GET` se config só protege `GET`.

### Bypass de sanitização
- **Mutation XSS**: input passa sanitizer mas o parser HTML do browser muta para algo perigoso (`<noscript><p title="</noscript><img src=x onerror=alert(1)>">`).
- **Double encoding**: `%2527` → sanitizer decodifica uma vez para `%27`, depois `urldecode` decodifica para `'`.
- **Unicode normalization**: `ﬁle` (U+FB01) normaliza para `file` depois da check.
- **Character truncation**: input cortado pelo DB (`VARCHAR(20)`) após validação no PHP.
- **Null byte**: `safe.php\0.exe` (linguagens C-based).
- **Polyglot payloads**: válidos em múltiplos contextos (HTML+JS+CSS).

### Bypass de autenticação
- **JWT alg confusion**: `alg: none`, `RS256 → HS256` usando chave pública como segredo.
- **JWT kid injection**: `kid` aponta para `/dev/null` ou ficheiro previsível.
- **Session fixation**: forçar session ID antes do login.
- **Race condition no login**: 1000 requests paralelos para bypass de rate limit.
- **OAuth state parameter** ausente → CSRF na ligação de conta.
- **Password reset token** previsível (timestamp, sequencial, baixa entropia).

### Bypass de autorização
- **IDOR via parameter pollution**: `?user_id=1&user_id=2`.
- **HTTP method**: `GET /admin/delete` falha mas `POST` ou `DELETE` passa.
- **Path traversal em IDs**: `?id=../admin/123`.
- **JSON type confusion**: `{"role": "user"}` vs `{"role": ["user", "admin"]}`.
- **Mass assignment com nested**: `{"user": {"role": "admin"}}` quando só esperam `{"name": "x"}`.
- **Cookie tampering**: `is_admin=true`, `role=admin` em cookies não assinados.

### Race conditions (TOCTOU — Time of Check, Time of Use)
- Verificar saldo → debitar (com requests paralelos pode-se gastar 2x).
- Validar ficheiro → mover (atacante substitui entre os dois passos).
- Verificar unicidade de email → criar user (race cria duplicado).
- Code de uso único validado, depois consumido (race usa 2x).
- **Mitigação:** locks, transações atómicas, `SELECT ... FOR UPDATE`, `INSERT ... ON DUPLICATE`, idempotency keys.

## 7. Vetores modernos a verificar (além das 12 categorias)

### Server-Side Template Injection (SSTI)
- Input em templates Twig/Smarty/Blade/Jinja/Handlebars renderizados server-side.
- Payload teste: `{{7*7}}` → se devolver `49`, há SSTI → potencial RCE.

### Deserialização insegura
- PHP `unserialize($_POST['data'])` → RCE via gadget chains (POP chains).
- Python `pickle.loads(user_input)` → RCE.
- Java `ObjectInputStream` → RCE.
- Node `node-serialize`, `serialize-javascript` mal usados.
- **Mitigação:** JSON em vez de serialização nativa, allowlist de classes.

### Prototype Pollution (JS)
- `Object.assign(target, JSON.parse(userInput))` permite poluir `Object.prototype`.
- `lodash.merge`, `jQuery.extend(true, ...)` em versões antigas.
- Pode escalar para RCE em apps Node.

### NoSQL Injection
- MongoDB: `{"username": {"$ne": null}, "password": {"$ne": null}}` → bypass login.
- Aceitar JSON em vez de string e usar diretamente em query.

### XXE (XML External Entity)
- Parser XML com entidades externas habilitadas.
- Payload: `<!ENTITY xxe SYSTEM "file:///etc/passwd">`.
- SVG, DOCX, XLSX, SOAP, RSS feeds.
- **Mitigação:** `libxml_disable_entity_loader(true)` (PHP < 8), evitar parser XML para input não confiável.

### SSRF avançado
- DNS rebinding: hostname resolve para `127.0.0.1` no segundo lookup.
- Cloud metadata: `http://169.254.169.254/latest/meta-data/iam/` (AWS), `http://metadata.google.internal/` (GCP).
- Smuggling via redirects: app valida URL inicial, segue redirect para interno.
- Schemes alternativos: `gopher://`, `dict://`, `file://`, `ftp://`.

### HTTP Request Smuggling
- Discrepância entre proxy e backend na interpretação de `Content-Length` vs `Transfer-Encoding`.
- Permite request poisoning, cache poisoning, bypass de auth do proxy.

### Cache Poisoning
- Headers não-key (`X-Forwarded-Host`, `X-Forwarded-Scheme`) refletidos em respostas cacheadas.
- Atacante envia request com header malicioso → cache devolve a outros utilizadores.

### Web Cache Deception
- `/account.php/nonexistent.css` — backend devolve `account.php`, cache trata como `.css` estático.

### Open Redirect → escalada
- `?redirect=https://evil.tld` parece "Baixo", mas combina com OAuth → roubo de token.

### CSRF avançado
- **SameSite=Lax bypass** via top-level GET com efeitos colaterais.
- **JSON CSRF** via form com `enctype=text/plain`.
- **Cross-origin via `<script>`** se resposta JSONP está disponível.

### CRLF Injection
- Headers HTTP injetáveis: `?lang=en%0d%0aSet-Cookie:%20admin=true`.

### Email Header Injection
- `mail($_POST['to'], ...)` com `to = "victim@x\nBcc: attacker@y"`.

## 8. Pensar em "blast radius"

Para cada achado pergunta:

- **Quanto vale isto?** (data sensitivity, quantos users afetados, valor monetário).
- **Quão perto está de "game over"?** (RCE, DB dump, takeover de admin).
- **Que detect/log existe?** (silencioso vs ruidoso).
- **Quão reversível é o dano?** (e-mail enviado, dinheiro transferido, dado público — irreversíveis).

## 9. Honestidade técnica

- Se não tens evidência, marca como **suspeita** — não inflas a severidade.
- Se exigência de exploração for muito alta (cadeia improvável), nota isso.
- Se já existe defesa em camada anterior (WAF, framework), reduz severidade.
- Se o utilizador é **admin a auditar admin**, contexto importa: admin-on-admin XSS é menos grave que público→admin.

## 10. Output: pensa em quem lê

- **Cliente** quer saber: "posso publicar?" Resposta: sim/não/condicional.
- **Tech lead** quer saber: "o que priorizar?" Resposta: lista ordenada por risco × esforço.
- **Developer junior** quer saber: "como é que arranjo?" Resposta: código corrigido, copy-paste.
- **Auditor externo** quer saber: "isto é defendível?" Resposta: rationale + CWE/CVSS.

Cobre os quatro no relatório.
