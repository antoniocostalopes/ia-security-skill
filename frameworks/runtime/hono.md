# Hono — Profile de Segurança

> Hono é framework HTTP universal — corre em Bun, Deno, Node.js, Cloudflare Workers, Vercel Edge, AWS Lambda. Foco em performance e edge runtimes.

## Deteção
- `package.json` com `hono`
- `import { Hono } from 'hono'`
- Deploy target: Cloudflare Workers, Vercel, Deno Deploy, etc.

## Setup mínimo seguro

```typescript
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { secureHeaders } from 'hono/secure-headers';
import { csrf } from 'hono/csrf';
import { logger } from 'hono/logger';
import { compress } from 'hono/compress';

const app = new Hono();

// Headers de segurança
app.use('*', secureHeaders({
  contentSecurityPolicy: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],
  },
  strictTransportSecurity: 'max-age=31536000; includeSubDomains',
  xFrameOptions: 'SAMEORIGIN',
  xContentTypeOptions: 'nosniff',
  referrerPolicy: 'strict-origin-when-cross-origin',
}));

// CORS
app.use('/api/*', cors({
  origin: ['https://app.meusite.tld'],
  credentials: true,
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

// CSRF
app.use('/api/*', csrf({ origin: 'https://app.meusite.tld' }));

// Logger
app.use('*', logger());
```

## Auth — JWT middleware

```typescript
import { jwt } from 'hono/jwt';

app.use('/api/private/*', jwt({
  secret: process.env.JWT_SECRET!,
  alg: 'HS256',
  cookie: 'token',  // ou header Authorization
}));

app.get('/api/private/me', (c) => {
  const payload = c.get('jwtPayload');
  return c.json({ user: payload.sub });
});
```

## Validation — Zod (com `@hono/zod-validator`)

```typescript
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
}).strict();

app.post('/api/users',
  zValidator('json', schema),
  async (c) => {
    const data = c.req.valid('json');  // typed + validated
    // ...
    return c.json({ ok: true });
  }
);
```

## Rate limiting (em edge)

```typescript
// Cloudflare Workers KV / Durable Objects
import { Hono } from 'hono';

app.use('/api/*', async (c, next) => {
  const ip = c.req.header('CF-Connecting-IP') || 'unknown';
  const key = `rate:${ip}`;
  const count = await c.env.RATELIMIT_KV.get(key);
  if (count && parseInt(count) > 100) {
    return c.json({ error: 'rate limited' }, 429);
  }
  await c.env.RATELIMIT_KV.put(key, String((parseInt(count || '0') + 1)), { expirationTtl: 60 });
  await next();
});
```

## Edge-specific concerns

### Cloudflare Workers
- Sem filesystem — apenas HTTP, KV, R2, D1
- Limite de CPU time (10ms-30s conforme plan)
- Sem `process.env` — env vars via `c.env`
- Sem `setTimeout` long-running

### Vercel Edge
- Limite de memória (~128MB)
- Tempo de execução limitado
- Subset de Node APIs

### Deno Deploy
- V8 isolates
- Permissions model do Deno

## Common antipatterns

### `c.env` com secrets em wrangler.toml committed
```toml
# wrangler.toml — secrets NÃO devem estar aqui
[vars]
API_KEY = "sk_live_xxx"  # !!

# GOOD — usar wrangler secret put
# $ wrangler secret put API_KEY
```

### Sem CSRF em apps com cookies
- Hono/edge frequentemente usado para APIs JSON, mas se autenticado por cookies precisa CSRF.

### `setTimeout` long-running em Workers
- Worker termina antes — request leak.

### Logging com PII em ambientes serverless
- Logs vão para CloudWatch / Datadog / etc. — verificar retention + redaction.

### Bundle gigante
- Workers/edge têm size limits. Bundle deve ser < 1MB típico.

### CORS `origin: '*'` com credentials
- Browser bloqueia mas é red flag.

## Quick wins

- [ ] Hono 4+
- [ ] `npm audit` sem Críticos
- [ ] `secureHeaders` middleware
- [ ] `cors` com origin allowlist
- [ ] `csrf` se cookies usados
- [ ] `jwt` middleware ou auth equivalente
- [ ] `@hono/zod-validator` em todos os endpoints com input
- [ ] Schema strict (`additionalProperties: false`)
- [ ] Rate limiting (KV / Durable Objects / serverless solution)
- [ ] Secrets via `wrangler secret put` ou env do platform (não committed)
- [ ] Bundle size monitoring
- [ ] Errors handler customizado (sem stack em prod)
- [ ] Plus: ver `linguagens/javascript-typescript.md` e profile do runtime (Bun/Deno se aplicável)
