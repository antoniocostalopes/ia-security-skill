# Análise — APIs Modernas (OAuth, GraphQL, WebSocket, OWASP API Top 10)

> Consolidação de padrões específicos das APIs modernas. Os antipatterns aqui são distintos das APIs REST clássicas — merecem o seu módulo.

## 1. OAuth 2.0 / OIDC

Protocolo complexo. A maioria dos bugs vem de **shortcuts** na implementação.

### Padrões perigosos

#### `state` parameter ausente
```
# BAD — sem state
GET /oauth/authorize?response_type=code&client_id=X&redirect_uri=...

# GOOD — state aleatório, single-use, ligado à sessão
GET /oauth/authorize?response_type=code&client_id=X&redirect_uri=...&state=<random_csrf_token>
```
Sem `state` = CSRF na ligação de conta (atacante liga a sua conta OAuth à conta da vítima).

#### `redirect_uri` validation fraca
```javascript
// BAD — startsWith permite https://app.tld.evil.com
if (redirect_uri.startsWith('https://app.tld')) accept();

// GOOD — comparação exacta com allowlist
const ALLOWED = ['https://app.tld/callback', 'https://app.tld/oauth-cb'];
if (!ALLOWED.includes(redirect_uri)) reject();
```

#### PKCE ausente em clientes públicos
- SPAs e apps móveis devem usar **PKCE** (`code_challenge`/`code_verifier`).
- Sem PKCE, intercept do `code` permite trocar por token.

#### Token storage inseguro
- **Bad:** `localStorage` (acessível a XSS).
- **Bom:** cookie `HttpOnly + Secure + SameSite`, ou mantido em memória + refresh token em cookie.

#### Implicit flow em código novo
- **Não usar** Implicit flow (`response_type=token`). Foi deprecated. Usar Authorization Code + PKCE.

#### `scope` excessivo
- App pede `read_all repos write_user` quando só precisa de `read_user`. Princípio do menor privilégio.

#### Refresh token sem rotação
- Mesmo refresh token reutilizável N vezes — se comprometido, atacante mantém acesso indefinidamente.
- **Solução:** rotação a cada uso. Se o mesmo refresh token é usado 2× → revogar tudo (deteção de roubo).

#### Validação de ID token (OIDC)
```javascript
// Para cada ID token recebido, validar:
- assinatura JWT contra JWKS do provider
- iss = expected issuer
- aud = teu client_id
- exp > now
- nonce = nonce que enviaste no auth request
- alg corresponde ao esperado (não none, não confusion)
```

## 2. GraphQL

### Padrões perigosos

#### Introspection ativa em produção
```graphql
# Atacante consulta:
{ __schema { types { name fields { name } } } }
# → mapa completo do schema, incluindo mutations admin
```
Desativar `introspection` em produção (Apollo: `introspection: false`).

#### Sem query complexity / depth limit
```graphql
# Atacante envia query de profundidade exponencial
{ user(id: 1) { friends { friends { friends { friends { ... } } } } } }
# → DoS por CPU/DB
```
Mitigação:
```javascript
const depthLimit = require('graphql-depth-limit');
const costAnalysis = require('graphql-cost-analysis');

new ApolloServer({
  validationRules: [
    depthLimit(7),
    costAnalysis({ maximumCost: 1000 }),
  ],
});
```

#### Batching attacks
GraphQL permite batching. Atacante envia 1000 mutations num só request.
- Limite de batch size.
- Rate limit por **operations**, não por requests.

#### Field-level authorization
```graphql
type User {
  id: ID
  email: String
  ssn: String  # ← devolvido a quem? só ao próprio?
}
```
Cada field deve ter resolver com check de auth. Não basta auth no nível da query.

#### Mass assignment via mutations
```graphql
# BAD
mutation { updateUser(id: 1, input: {name: "x", role: "admin"}) }
# Se input type aceita role → privilege escalation

# GOOD — input separado por contexto
input UpdateUserSelfInput { name: String, email: String }   # sem role
input UpdateUserAdminInput { name: String, role: Role }     # admin only
```

#### Error message leakage
GraphQL devolve erros detalhados. Em produção, manter genérico:
```javascript
new ApolloServer({
  formatError: (err) => {
    if (process.env.NODE_ENV === 'production' && !err.extensions?.code === 'BAD_USER_INPUT') {
      return new Error('Internal server error');
    }
    return err;
  },
});
```

## 3. WebSocket

### Padrões perigosos

#### Sem auth no handshake
```javascript
// BAD
io.on('connection', (socket) => {
  socket.on('admin-command', handleAdmin);  // qualquer um conecta e envia
});

// GOOD
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  const user = verifyJWT(token);
  if (!user) return next(new Error('unauthorized'));
  socket.user = user;
  next();
});

io.on('connection', (socket) => {
  socket.on('admin-command', (data) => {
    if (socket.user.role !== 'admin') return;
    handleAdmin(data);
  });
});
```

#### Origin não validado
```javascript
// BAD
const wss = new WebSocketServer({ port: 8080 });

// GOOD
const wss = new WebSocketServer({
  port: 8080,
  verifyClient: ({ origin }) => ALLOWED_ORIGINS.includes(origin),
});
```
Sem origin check → qualquer site pode abrir WS para o teu serviço com cookies da vítima (Cross-Site WebSocket Hijacking).

#### Sem rate limit por mensagem
1 cliente envia 10000 msgs/seg → DoS.

#### Payloads sem validação de tamanho
```javascript
// Express + ws
const wss = new WebSocketServer({
  maxPayload: 1 * 1024 * 1024,  // 1MB
});
```

#### Broadcast indiscriminado
```javascript
// BAD — mensagem de A vai para todos
socket.on('msg', (data) => {
  io.emit('msg', data);  // sem auth, sem filtragem
});

// GOOD — só para a sala/destinatário correto
socket.on('msg', (data) => {
  if (!canSendTo(socket.user, data.roomId)) return;
  io.to(data.roomId).emit('msg', { from: socket.user.id, text: sanitize(data.text) });
});
```

## 4. OWASP API Security Top 10 (2023)

### API1 — BOLA (Broken Object Level Authorization)
Como IDOR. `GET /api/users/123/avatar` devolve avatar do user 123 sem confirmar que o caller é dono ou tem permissão.
- **Sempre validar ownership** ou role no callback.

### API2 — Broken Authentication
Já coberto em `14-autenticacao-sessao.md`.

### API3 — BOPLA (Broken Object Property Level Authorization)
- **Excessive Data Exposure**: API devolve campos a mais (`user.password_hash`, `user.created_at` quando devia ser só `user.name`).
- **Mass Assignment**: API aceita campos a mais (`PATCH /user {role: 'admin'}`).

```javascript
// BAD
app.patch('/user/:id', (req, res) => {
  await User.update(req.params.id, req.body);  // body inteiro
});

// GOOD — allowlist explícita
app.patch('/user/:id', async (req, res) => {
  const allowed = ['name', 'bio', 'avatar'];
  const updates = Object.fromEntries(
    Object.entries(req.body).filter(([k]) => allowed.includes(k))
  );
  await User.update(req.params.id, updates);
});
```

### API4 — Unrestricted Resource Consumption
Sem rate limit, sem paginação cap. Já coberto em `21-dos-resource-limits.md`.

### API5 — BFLA (Broken Function Level Authorization)
- Endpoint admin acessível por user normal por chamada direta.
- `/api/admin/users` sem check de role.

### API6 — Unrestricted Access to Sensitive Business Flows
- Webhook de checkout chamado direto sem passar pelo flow normal.
- Endpoint "claim referral bonus" sem rate limit por user.

### API7 — SSRF
Já coberto em `20-open-redirect-ssrf.md`.

### API8 — Security Misconfiguration
Já coberto em `15-configuracao-hardening.md` e `16-headers-http.md`.

### API9 — Improper Inventory Management
- Endpoints `v1` legacy ainda expostos quando `v2` corrigido.
- Endpoints de teste/staging acessíveis em produção.
- API gateway sem inventário do que está exposto.

### API10 — Unsafe Consumption of APIs
- App confia em respostas de API externa (XSS armazenado, deserialization).
- Sem validar schema de resposta.

## Quick wins (faz isto antes de entregar)

### OAuth
- [ ] `state` parameter aleatório single-use em todos os flows
- [ ] `redirect_uri` validation por allowlist exata
- [ ] PKCE em SPAs e apps móveis
- [ ] Tokens em cookie HttpOnly+Secure+SameSite (não localStorage)
- [ ] Rotação de refresh tokens, deteção de reuso
- [ ] Validação completa de ID tokens (assinatura, iss, aud, exp, nonce)

### GraphQL
- [ ] Introspection desativado em produção
- [ ] Depth limit (5-7 normalmente)
- [ ] Cost analysis / complexity limit
- [ ] Batch size limit
- [ ] Field-level auth em campos sensíveis
- [ ] Input types separados por contexto (admin vs user)
- [ ] Error sanitization em produção

### WebSocket
- [ ] Auth no handshake (token via `Sec-WebSocket-Protocol` ou first message)
- [ ] Origin validation
- [ ] Rate limit por message
- [ ] Max payload size
- [ ] Broadcast com filtragem de destinatários

### API Top 10
- [ ] BOLA: ownership check em todos os endpoints `/x/:id`
- [ ] BOPLA: allowlist de campos em update endpoints
- [ ] BFLA: role check em endpoints admin
- [ ] Inventário de endpoints expostos vs. ativos vs. legacy

## Falsos positivos
- API GraphQL **interna** (não exposta) pode ter introspection ativa
- WebSocket entre serviços internos com mTLS pode dispensar auth no handshake
- Endpoints admin com IP allowlist no firewall (defesa em profundidade)

## Severidade — em linguagem honesta
- **Crítico:** OAuth `redirect_uri` permissivo + sem `state` → roubo de tokens / takeover
- **Crítico:** BFLA — endpoint admin acessível por user normal
- **Crítico:** Mass assignment via GraphQL/REST com `role` no body
- **Alto:** GraphQL sem depth/cost limit em produção
- **Alto:** WebSocket sem auth no handshake / sem origin
- **Alto:** Refresh tokens sem rotação
- **Médio:** Introspection GraphQL ativa em produção
- **Médio:** Tokens OAuth em localStorage (combina com XSS)
