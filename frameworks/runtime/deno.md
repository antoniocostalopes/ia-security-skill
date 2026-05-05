# Deno — Profile de Segurança

> Deno tem **permissions model nativo** — apps começam sem permissões e exigem flags explícitas. Modelo de segurança fundamentalmente diferente de Node.

## Deteção
- `deno.json` / `deno.jsonc`
- `deno.lock`
- `import_map.json`
- Imports via URL (`https://deno.land/...` ou JSR)

## Permissions — o que torna Deno diferente

```bash
# BAD — --allow-all (= sem segurança)
deno run --allow-all server.ts

# GOOD — permissions específicas
deno run \
  --allow-net=api.meusite.tld:443 \
  --allow-read=./data,./config \
  --allow-env=DATABASE_URL,API_KEY \
  --allow-write=./logs \
  server.ts
```

### Flags
| Flag | Uso |
|---|---|
| `--allow-net=host:port` | Network específico |
| `--allow-read=path` | Read filesystem específico |
| `--allow-write=path` | Write filesystem específico |
| `--allow-env=VAR1,VAR2` | Env vars específicas |
| `--allow-run=cmd` | Subprocess específicos |
| `--allow-sys` | Info do sistema |
| `--allow-ffi` | FFI (perigoso) |
| `--deny-*` | Override explícito |

## Imports via URL — supply chain

```typescript
// Deno core philosophy: imports via URL
import { serve } from "https://deno.land/std@0.220.0/http/server.ts";

// PINNING obrigatório (versão fixa)
// BAD — sem pinning
import { x } from "https://deno.land/std/http/server.ts";  // sempre latest

// GOOD — versão pinned + integrity
import { serve } from "https://deno.land/std@0.220.0/http/server.ts";
```

```json
// import_map.json — centralizar versões
{
  "imports": {
    "$std/": "https://deno.land/std@0.220.0/",
    "oak": "https://deno.land/x/oak@v17.1.4/mod.ts"
  }
}
```

```bash
# deno.lock — verificar integridade
deno cache --lock=deno.lock --lock-write deps.ts
```

## JSR (modern Deno registry)

```typescript
// jsr — alternativa a deno.land/x, com versioning melhor
import { serve } from "jsr:@std/http@0.220.0";
```

JSR é mais robusto em supply chain (versioning semântico, scoped packages, audit).

## HTTP server (`Deno.serve`)

```typescript
Deno.serve({ port: 3000 }, async (req) => {
  const url = new URL(req.url);

  // Auth
  const auth = req.headers.get("Authorization");
  if (!auth && url.pathname.startsWith("/api/private")) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Headers
  if (url.pathname === "/api/data") {
    return new Response(JSON.stringify({ data: "..." }), {
      headers: {
        "Content-Type": "application/json",
        "Strict-Transport-Security": "max-age=31536000",
        "X-Content-Type-Options": "nosniff",
      },
    });
  }
  return new Response("Not found", { status: 404 });
});
```

## Frameworks Deno

- **Oak** — middleware-based (similar Express)
- **Fresh** — full-stack (similar Next.js)
- **Hono** — universal (corre em Deno, Bun, Node, edge)
- **Aleph.js** — full-stack React

## SQL com Deno

```typescript
// postgres deno driver
import { Pool } from "https://deno.land/x/postgres@v0.19.3/mod.ts";

const pool = new Pool({
  database: "mydb",
  hostname: "localhost",
  password: Deno.env.get("DB_PASSWORD"),
  user: "myuser",
}, 10);

// BAD
client.queryArray(`SELECT * FROM users WHERE name = '${name}'`);

// GOOD
client.queryArray("SELECT * FROM users WHERE name = $1", [name]);
```

## File I/O — sempre com permission

```typescript
// Deno.readTextFile requer --allow-read
const config = await Deno.readTextFile("./config.json");

// Path validation ainda necessária
import { resolve, SEP } from "https://deno.land/std@0.220.0/path/mod.ts";

const base = resolve("./data");
const target = resolve(base, userInput);
if (!target.startsWith(base + SEP)) {
  throw new Error("path traversal");
}
```

## Common antipatterns

### `--allow-all` em produção
- Anula o permissions model. Especificar permissions necessárias.

### Imports URL sem versão pinned
- Atacante compromete módulo → todos os deploys afetados.

### Sem `deno.lock` commitado
- Builds não reproduzíveis.

### `eval` / `Function()` com input
- Mesma classe que Node.

### Subprocess sem `--allow-run` específico
- `--allow-run` sem args = qualquer comando.

### `Deno.env.get` sem `--allow-env=VAR_NAME`
- App pode ler env vars de outros processes (em theory, mas Deno limita).

### FFI sem auditoria
- `--allow-ffi` = bypass do permissions model. C library com bugs = bugs do Deno.

## Quick wins

- [ ] Deno 2.x (recente)
- [ ] Permissions específicas (sem `--allow-all`)
- [ ] Imports URL com versão pinned ou via import_map.json
- [ ] `deno.lock` commitado
- [ ] `deno cache --lock=deno.lock` para verificar integridade
- [ ] Migrar para JSR onde possível (melhor supply chain)
- [ ] Subprocess com `--allow-run=specific-cmd`
- [ ] Env vars com `--allow-env=VAR1,VAR2`
- [ ] Headers de segurança em `Deno.serve` responses
- [ ] SQL queries parametrizadas
- [ ] Path validation em filesystem operations
- [ ] Error handler que não vaza stack
- [ ] Sem `eval`/`Function()` com input
- [ ] Sem `--allow-ffi` salvo necessidade clara e código auditado
- [ ] Plus: ver `linguagens/javascript-typescript.md`
