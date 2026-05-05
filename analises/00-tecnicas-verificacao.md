# Técnicas de Verificação

> Como auditar mais profundamente, não só o quê auditar. Sem estas técnicas a skill é uma checklist; com elas, é uma auditoria a sério.

## 1. Taint Analysis (source → sink)

Para cada input não confiável (**source**), traça o caminho até onde é usado (**sink**). Se atravessa o código sem sanitização adequada → vulnerabilidade.

### Sources comuns
- `request.body`, `request.query`, `request.params`, `request.headers`, `request.cookies` (Express, Flask, Spring, etc.)
- `$_GET`, `$_POST`, `$_REQUEST`, `$_COOKIE`, `$_SERVER` (PHP)
- `os.environ`, `sys.argv`, file reads de fontes externas
- Mensagens de queues/Kafka/Redis se vêm de produtores não confiáveis
- Resposta de APIs externas

### Sinks perigosos
| Sink | Risco |
|---|---|
| `eval`, `exec`, `compile`, `Function()` | RCE |
| `system`, `exec`, `spawn`, `subprocess` | Command injection |
| `db.query(string)`, `cursor.execute(string)` | SQLi |
| `innerHTML`, `document.write`, `dangerouslySetInnerHTML` | XSS |
| `template.render(user_data)` | SSTI |
| `unserialize`, `pickle.loads`, `ObjectInputStream` | Deserialization RCE |
| `fs.readFile(path)`, `open(path)`, `include()`, `require()` | LFI/RFI |
| `http.get(url)`, `fetch(url)`, `urllib.request` | SSRF |
| `redirect(url)` | Open Redirect |
| `setHeader('Location', x)` | CRLF + Open Redirect |
| `mail.send(headers)` | Email Header Injection |

### Como aplicar mentalmente
Para cada sink encontrado: *"De onde vem este parâmetro? É controlável pelo utilizador? Foi sanitizado no caminho?"*

## 2. Cross-file analysis

Vulnerabilidades reais espalham-se por múltiplos ficheiros. Não basta auditar ficheiro a ficheiro.

### Padrões a procurar
- Helper que sanitiza chamado em A.js, mas em B.js o mesmo input chega ao sink **sem** passar pelo helper.
- Função "trusted" exportada que assume input já validado, mas chamada por route que não valida.
- Middleware de auth aplicado a `/admin/*` mas rota `/admin/legacy` registada antes do middleware.
- Validação no controller mas serviço de baixo nível também aceita input direto via outra rota.

### Como aplicar
Para cada validação que vês, pergunta: *"Quem mais chama esta função? Todos validam antes?"*

## 3. Config drift detection

Comparar configurações entre ambientes — encontra esquecimentos típicos.

### Comparações úteis
- `wp-config-dev.php` vs `wp-config.php` (prod)
- `.env.example` vs `.env`
- `appsettings.Development.json` vs `appsettings.Production.json`
- `application.yml` profiles dev vs prod

### Red flags típicos
- DEBUG=true em prod
- API endpoints de teste (`/test/*`, `/dev/*`) ainda ativos
- CORS aberto em prod (esquecido de dev)
- Credenciais default não substituídas
- Logging verboso ainda ativo
- Rate limit desligado em prod (deixado de teste)

## 4. DB schema audit

A BD pode introduzir vulns invisíveis no código.

### O que verificar
- **Tipo demasiado curto**: `email VARCHAR(20)` quando código valida 100 chars → truncation bypass.
- **Sem índice** em campos de auth → enumeração via timing.
- **Sem UNIQUE constraint** em `email` → duplicate accounts via race.
- **Default values** em colunas booleanas (`is_admin BOOLEAN DEFAULT FALSE` está OK; `BOOLEAN DEFAULT TRUE` é mau).
- **NULLABLE** em campos de segurança (`password_hash NULL` permite contas sem password).
- **Sem foreign key** em ownership (`posts.user_id` sem FK → IDOR mais fácil).
- **Charset `latin1`** em vez de `utf8mb4` → ataques via emojis/null bytes.

### Comando útil
```sql
-- MySQL — listar colunas pequenas em tabelas sensíveis
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'meu_db'
  AND CHARACTER_MAXIMUM_LENGTH < 50
  AND COLUMN_NAME IN ('email', 'username', 'role');
```

## 5. Migration script audit

Migrations alteram schema em produção — security implications muitas vezes ignoradas.

### O que procurar
- **Migrations destrutivas** sem backup automático (`DROP TABLE`, `TRUNCATE`).
- **Migrations longas** que bloqueiam tabela em produção (downtime).
- **Adicionar coluna NOT NULL sem DEFAULT** em tabela grande → falha em prod.
- **Index online** vs offline (Postgres `CREATE INDEX CONCURRENTLY` necessário).
- **Migrations a executar SQL com input dinâmico** (raras mas existem).
- **Rollback** ausente ou incorreto.

## 6. Cron / background jobs

Jobs correm com privilégios elevados, fora do request lifecycle — auth muitas vezes esquecida.

### O que procurar
- Endpoint do cron exposto sem auth (`/cron/run`, `/wp-cron.php` chamado externamente).
- Jobs assumem dados de input sem validar (vêm de queue não confiável).
- Race conditions em jobs paralelos (mesmo job executado 2x).
- Jobs sem timeout → consumo infinito de recursos.
- Logs de jobs com PII sem redação.
- Retries sem backoff exponencial → DoS contra serviço externo.

## 7. Test generation (anti-regressão)

Para cada vulnerabilidade encontrada, **gera um teste** que falha até o fix ser aplicado. Garante que a vuln não volta.

### Exemplo (qualquer linguagem com framework de testes)
```javascript
// Para um achado de "endpoint sem auth"
test('GET /admin/users requires authentication', async () => {
  const res = await request(app).get('/admin/users');
  expect(res.status).toBe(401); // ou 403
});

// Para um achado de SQLi corrigido
test('search endpoint resists SQL injection', async () => {
  const res = await request(app).get(`/search?q=${encodeURIComponent("'; DROP TABLE users; --")}`);
  expect(res.status).toBe(200);
  // confirma que tabela ainda existe
  const users = await db.query('SELECT COUNT(*) FROM users');
  expect(users.rowCount).toBeGreaterThan(0);
});
```

## 8. Documentação vs código (drift)

A documentação afirma uma coisa, o código faz outra → assunção de segurança quebrada.

### Exemplos típicos
- Docs: *"Endpoint X requer admin"* — código: `permission_callback => '__return_true'`
- Docs: *"Tokens expiram em 30 min"* — código: `exp = now() + 86400`
- Docs: *"Rate limit 100/min"* — código: sem rate limit
- README: *"HTTPS only"* — código aceita HTTP em endpoints

## 9. Contract validation (OpenAPI/Swagger vs implementação)

Se o projeto tem OpenAPI/Swagger spec, **compara com implementação**:
- Endpoint na spec mas não implementado, ou inverso (shadow endpoints).
- Schema de input da spec vs validação real do código.
- `securitySchemes` definido mas não aplicado em endpoints.
- Status codes documentados vs reais.

## 10. Cobertura de testes em paths críticos

Auth, payment, file upload, password reset — paths críticos devem ter testes. **Sem testes = mais probabilidade de regressão de segurança.**

### Como verificar mentalmente
Para cada finding crítico/alto, pergunta:
- *"Há teste que cobre este caminho?"*
- *"Se sim, porquê não detetou a vuln?"*
- *"Se não, o fix vem com teste?"*

## Aplicação no workflow

Quando auditas, aplica estas técnicas em paralelo com a análise por categoria:

1. Mapeia sources e sinks → encontra vulns que listings não encontram.
2. Cross-file → encontra vulns que análise por ficheiro perde.
3. Config drift → encontra "esqueci-me de ligar X em prod".
4. DB schema → encontra vulns no layer de dados.
5. Cron / jobs → encontra superfícies escondidas.
6. Para cada finding, propõe teste anti-regressão.
