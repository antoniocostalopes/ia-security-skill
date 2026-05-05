# Bun — Profile de Segurança

> Bun é runtime JavaScript/TypeScript alternativo a Node.js. APIs próprias (`Bun.serve`, `Bun.password`, `Bun.spawn`) com diferenças de comportamento. Mais rápido, mas ainda menos battle-tested.

## Deteção
- `bun.lockb` (binary lockfile)
- `package.json` com scripts a usar `bun`
- `Bunfile.toml` (raro)

## `Bun.serve` — HTTP server nativo

```typescript
// Setup com headers de segurança
const server = Bun.serve({
  port: 3000,
  async fetch(req) {
    const url = new URL(req.url);

    // Auth
    const authHeader = req.headers.get('Authorization');
    const user = await verifyAuth(authHeader);
    if (!user && url.pathname.startsWith('/api/private')) {
      return new Response('Unauthorized', { status: 401 });
    }

    // Routes
    if (url.pathname === '/api/data') {
      return Response.json({ data: '...' }, {
        headers: {
          'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'SAMEORIGIN',
        },
      });
    }
    return new Response('Not found', { status: 404 });
  },
  error(error) {
    console.error(error);
    return new Response('Server error', { status: 500 });
    // NÃO devolver `error.stack` em prod
  },
});
```

## `Bun.password` — password hashing (built-in)

```typescript
// BCrypt (default) or Argon2id
const hash = await Bun.password.hash(plainPassword, {
  algorithm: 'argon2id',
  memoryCost: 19456,
  timeCost: 2,
});

const valid = await Bun.password.verify(plainPassword, hash);
```

## `Bun.spawn` / `Bun.spawnSync` — process spawn

```typescript
// BAD — shell command com input
Bun.spawn(['sh', '-c', `ping ${host}`]);

// GOOD — array de args
Bun.spawn(['ping', '-c', '1', host]);

// Com timeout
const proc = Bun.spawn(['ping', '-c', '1', host], {
  timeout: 5000,
});
```

## SQLite nativo (`bun:sqlite`)

```typescript
import { Database } from 'bun:sqlite';
const db = new Database('mydb.sqlite');

// BAD
db.query(`SELECT * FROM users WHERE name = '${name}'`).all();

// GOOD
db.query('SELECT * FROM users WHERE name = $name').all({ $name: name });
```

## File I/O (`Bun.file`)

```typescript
// BAD — path traversal
const file = Bun.file(`/var/data/${userInput}`);
const content = await file.text();

// GOOD
import { resolve, sep } from 'path';
const base = resolve('/var/data');
const target = resolve(base, userInput);
if (!target.startsWith(base + sep)) throw new Error('path traversal');
const file = Bun.file(target);
```

## WebSockets

```typescript
const server = Bun.serve({
  fetch(req, server) {
    if (server.upgrade(req, { data: { user: getUserFromReq(req) } })) {
      return;  // upgraded
    }
    return new Response('Upgrade failed', { status: 500 });
  },
  websocket: {
    open(ws) {
      // Auth check
      if (!ws.data.user) ws.close(1008, 'unauthorized');
    },
    message(ws, message) {
      // Validar payload
      if (typeof message === 'string' && message.length > 1024) {
        ws.close(1009, 'message too large');
      }
      // ...
    },
  },
});
```

## Common antipatterns

### `Bun.write(userPath, content)` sem validação
- Path traversal.

### `Bun.spawn` com `stdin` não controlado
- Command injection se input chega a stdin de tool perigosa.

### Sem `error()` handler em `Bun.serve`
- Default error handler pode revelar stack.

### `Bun.deepEquals` em comparação de tokens
- Não constant-time. Usar `crypto.subtle.timingSafeEqual` ou implementação manual.

### Sem timeout em `fetch`
- Bun fetch implementa AbortController. Usar `AbortSignal.timeout(5000)`.

### `bun install` sem `--frozen-lockfile` em CI
- Pode atualizar pacotes silenciosamente.

### `bun.lockb` não commitado
- Builds não reproduzíveis. Commit obrigatório.

### `Bun.env` com secrets em código
- Mesma classe que `process.env`. Não pôr defaults com secrets em código.

## Diferenças vs Node

- `Bun.password` em vez de `bcrypt` package
- `Bun.spawn` em vez de `child_process`
- `bun:sqlite` em vez de `better-sqlite3`
- `Bun.file` em vez de `fs.promises.readFile`
- `Bun.serve` em vez de `http.createServer` / Express
- WebSocket nativo em vez de `ws` package

A maioria das libs Node funciona no Bun (compatibility layer), mas APIs nativas são mais rápidas.

## Quick wins

- [ ] Bun 1.x (mais recente)
- [ ] `bun.lockb` commitado
- [ ] `bun audit` (se disponível) ou `bun install --frozen-lockfile` em CI
- [ ] `Bun.password.hash` com argon2id
- [ ] `Bun.spawn` com array de args (não shell)
- [ ] `bun:sqlite` queries parametrizadas
- [ ] Path validation em `Bun.file` / `Bun.write`
- [ ] Headers de segurança em `Bun.serve` responses
- [ ] WebSocket com auth no `open` + payload validation
- [ ] Timeouts em todos os `fetch` outbound
- [ ] Error handler customizado em `Bun.serve` (sem stack em prod)
- [ ] Plus: ver `linguagens/javascript-typescript.md`
