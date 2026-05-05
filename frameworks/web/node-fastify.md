# Fastify (Node.js) — Profile de Segurança

## Deteção
- `package.json` com `fastify`
- `fastify.register(...)` no código

## Setup mínimo seguro

```javascript
const fastify = require('fastify')({
  logger: true,
  trustProxy: 1,
  bodyLimit: 1048576,  // 1MB
});

await fastify.register(require('@fastify/helmet'));
await fastify.register(require('@fastify/cors'), {
  origin: ['https://app.meusite.tld'],
  credentials: true,
});
await fastify.register(require('@fastify/rate-limit'), {
  max: 100,
  timeWindow: '1 minute',
});
await fastify.register(require('@fastify/cookie'), {
  secret: process.env.COOKIE_SECRET,
  parseOptions: { httpOnly: true, secure: true, sameSite: 'lax' },
});
```

## Schema validation — built-in (JSON Schema)

```javascript
const userSchema = {
  body: {
    type: 'object',
    additionalProperties: false,  // strict
    required: ['name', 'email'],
    properties: {
      name: { type: 'string', minLength: 1, maxLength: 100 },
      email: { type: 'string', format: 'email' },
    },
  },
};

fastify.post('/users', { schema: userSchema }, async (req, reply) => {
  // req.body já validado
});
```

> Schema é a melhor parte do Fastify — validação automática + serialização rápida.

## Auth — JWT plugin

```javascript
await fastify.register(require('@fastify/jwt'), {
  secret: process.env.JWT_SECRET,
  sign: { expiresIn: '15m' },
});

// Decorator para preHandler
fastify.decorate('authenticate', async (req, reply) => {
  try { await req.jwtVerify(); }
  catch { reply.code(401).send({ error: 'unauthorized' }); }
});

// Aplicar
fastify.get('/profile', { preHandler: [fastify.authenticate] },
  async (req) => req.user
);
```

## Auth — sessions

```javascript
await fastify.register(require('@fastify/session'), {
  secret: process.env.SESSION_SECRET,  // 32+ chars
  cookie: { secure: true, httpOnly: true, sameSite: 'lax', maxAge: 86400_000 },
  store: redisStore,  // sem store = MemoryStore (não usar em prod)
});
```

## Common antipatterns

### `additionalProperties: true` (default em algumas versões)
- Permite mass assignment. Sempre `false`.

### Schema só em `body`, não em `query`/`params`
- Atacante mete payloads em outras zonas.

### `preHandler` esquecido em rotas
- Sem `preHandler: [authenticate]` → endpoint público.

### `reply.send(error)` direto
- Pode vazar stack trace. Usar `reply.code(500).send({ error: '...' })`.

### Plugin order
- Plugins encapsulam scope. `await fastify.register(plugin)` antes das rotas que usam.

### `bodyLimit` default = 1MB
- OK por default; se aumentado, justificar.

## Helpers / plugins

| Necessidade | Plugin |
|---|---|
| Headers | `@fastify/helmet` |
| Rate limit | `@fastify/rate-limit` |
| CORS | `@fastify/cors` |
| Cookies | `@fastify/cookie` |
| Session | `@fastify/session` |
| JWT | `@fastify/jwt` |
| OAuth | `@fastify/oauth2` |
| Multipart | `@fastify/multipart` (com `limits`) |
| Static | `@fastify/static` (com `prefix` e `decorateReply: false`) |
| WebSocket | `@fastify/websocket` |
| GraphQL | `mercurius` |

## Quick wins

- [ ] Fastify 4+
- [ ] `npm audit` sem Críticos
- [ ] Schema validation em **todos** os routes (body, query, params, headers se aplicável)
- [ ] `additionalProperties: false` em todos os schemas
- [ ] `@fastify/helmet` registado
- [ ] `@fastify/rate-limit` registado
- [ ] `@fastify/cors` com allowlist
- [ ] `preHandler` de auth nas rotas privadas
- [ ] Cookies com `httpOnly + secure + sameSite`
- [ ] JWT com `expiresIn` curto + refresh tokens
- [ ] `trustProxy` configurado se atrás de LB
- [ ] `bodyLimit` adequado
- [ ] Multipart com limits (fileSize, files, fields)
- [ ] Error handler global que não vaza stack
- [ ] Logger sem PII em production
- [ ] Health check sem detalhes
