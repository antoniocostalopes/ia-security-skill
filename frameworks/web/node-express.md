# Express (Node.js) — Profile de Segurança

## Deteção
- `package.json` com `express` em dependencies
- `app.use(express.X)` no código

## Setup mínimo seguro

```javascript
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cors = require('cors');

const app = express();

// 1. Trust proxy (se atrás de load balancer)
app.set('trust proxy', 1);  // 1 LB layer; ajustar

// 2. Security headers
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'https:'],
      objectSrc: ["'none'"],
    },
  },
}));

// 3. Body size limit
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: false, limit: '1mb' }));

// 4. CORS
app.use(cors({
  origin: ['https://app.meusite.tld'],
  credentials: true,
}));

// 5. Rate limit global
app.use(rateLimit({
  windowMs: 60_000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
}));

// 6. Cookie parser com signing
app.use(require('cookie-parser')(process.env.COOKIE_SECRET));
```

## Middleware order — CRÍTICO

```javascript
// CORRETO
app.use(helmet());                // 1. headers primeiro
app.use(rateLimit(...));          // 2. rate limit antes de processamento
app.use(express.json());          // 3. body parsing
app.use(authMiddleware);          // 4. auth
app.use('/api', apiRouter);       // 5. routes

// ERRADO
app.use('/api', apiRouter);       // routes registadas SEM auth
app.use(authMiddleware);          // auth nunca aplicada
```

## Auth com sessions (express-session)

```javascript
const session = require('express-session');
const RedisStore = require('connect-redis').default;

app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET,  // forte, único por instância
  name: 'sid',  // não usar 'connect.sid' (default revela Express)
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: true,        // HTTPS only
    sameSite: 'lax',
    maxAge: 1000 * 60 * 60 * 24,
  },
  rolling: true,  // renova expiração a cada request
}));

// Após login, regenerar session
req.session.regenerate(err => {
  if (err) return next(err);
  req.session.userId = user.id;
  req.session.save(err => {
    if (err) return next(err);
    res.redirect('/dashboard');
  });
});
```

## Auth com JWT (jose)

```javascript
const { jwtVerify, SignJWT } = require('jose');

// Sign
const token = await new SignJWT({ userId: user.id })
  .setProtectedHeader({ alg: 'HS256' })
  .setIssuedAt()
  .setIssuer('meusite.tld')
  .setAudience('meusite.tld')
  .setExpirationTime('15m')
  .sign(secret);

// Verify
try {
  const { payload } = await jwtVerify(token, secret, {
    issuer: 'meusite.tld',
    audience: 'meusite.tld',
  });
} catch {
  res.status(401).end();
}
```

## Validation — Zod

```javascript
const { z } = require('zod');

const UserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  age: z.number().int().min(13).max(120).optional(),
}).strict();  // rejeita extra fields

app.post('/users', (req, res) => {
  const parsed = UserSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);
  const data = parsed.data;
  // ...
});
```

## Common antipatterns

### `app.disable('x-powered-by')` esquecido
- helmet faz isto automaticamente. Sem helmet, adicionar.

### `bodyParser` sem limit
```javascript
// BAD
app.use(express.json());  // default 100kb mas...

// GOOD
app.use(express.json({ limit: '1mb' }));
```

### Routes registradas antes do auth
- Order matters em Express.

### `req.params` / `req.query` confiáveis
- Sempre validar tipo. `req.params.id` é string sempre.

### `res.send(req.query.x)`
- XSS reflected.

### Errors handlers que vazam info
```javascript
// BAD
app.use((err, req, res, next) => {
  res.status(500).json({ error: err.message, stack: err.stack });
});

// GOOD
app.use((err, req, res, next) => {
  console.error(err);  // log com correlation id
  res.status(500).json({ error: 'Internal Server Error', requestId: req.id });
});
```

### `eval` ou `Function()` para "configurar"
- Nunca. Usar lookup tables / Maps.

### `child_process.exec` para shell
- Substituir por `execFile` ou `spawn` com array.

### Sessions sem store persistente
- Default `MemoryStore` perde sessões em restart, vaza memória, não escala.

## Helpers

| Necessidade | Lib |
|---|---|
| Headers | `helmet` |
| Rate limit | `express-rate-limit` (com Redis store em prod) |
| Slow down (gradual delay) | `express-slow-down` |
| CORS | `cors` |
| Session | `express-session` + `connect-redis` |
| CSRF | `csurf` (descontinuado) → preferir double-submit cookie ou JWT |
| Cookies | `cookie-parser` |
| Compression | `compression` |
| Logger | `pino-http` (rápido), `morgan` |
| JWT | `jose` (preferida) ou `jsonwebtoken` v9+ |
| Validation | `zod`, `joi`, `yup`, `express-validator` |
| File upload | `multer` (com limits e file filter) |
| Sanitization | `dompurify` (HTML), `validator` (input) |

## Quick wins

- [ ] Express 4.20+ (várias CVEs patched recentes)
- [ ] `npm audit` sem Críticos/Altos
- [ ] `helmet` ativo
- [ ] `express-rate-limit` global + por endpoint sensível
- [ ] `express.json({ limit: '1mb' })`
- [ ] CORS com allowlist explícita
- [ ] Session com store persistente (Redis)
- [ ] Cookies com `httpOnly + secure + sameSite=lax`
- [ ] `req.session.regenerate()` após login
- [ ] Auth middleware antes de routes privadas
- [ ] Validation com Zod/Joi em todos os endpoints
- [ ] Body parser body limit
- [ ] Error handler que não vaza stack
- [ ] `trust proxy` corretamente configurado se atrás de LB
- [ ] HTTPS-only (`req.secure` ou redirect HTTP→HTTPS)
- [ ] `X-Powered-By` removido (helmet faz)
- [ ] Logs estruturados (pino) com sanitização de PII
- [ ] Multer com fileFilter, limits, e storage seguro
