# tRPC — Profile de Segurança

> tRPC dá end-to-end type safety entre servidor e cliente — sem schemas separados. Mas type safety **não é authorization**. Cuidados próprios.

## Deteção
- `package.json` com `@trpc/server`, `@trpc/client`, `@trpc/react-query`
- `src/server/api/trpc.ts` ou similar

## Setup com auth context

```typescript
// server/api/trpc.ts
import { initTRPC, TRPCError } from '@trpc/server';
import { z } from 'zod';

export const createTRPCContext = async (opts) => {
  const session = await getSession(opts.req);
  return { session, db };
};

const t = initTRPC.context<typeof createTRPCContext>().create();

export const router = t.router;
export const publicProcedure = t.procedure;

// Auth middleware
const isAuthed = t.middleware(({ ctx, next }) => {
  if (!ctx.session?.user) {
    throw new TRPCError({ code: 'UNAUTHORIZED' });
  }
  return next({ ctx: { ...ctx, user: ctx.session.user } });
});

const isAdmin = t.middleware(({ ctx, next }) => {
  if (ctx.session?.user?.role !== 'admin') {
    throw new TRPCError({ code: 'FORBIDDEN' });
  }
  return next();
});

export const protectedProcedure = publicProcedure.use(isAuthed);
export const adminProcedure = protectedProcedure.use(isAdmin);
```

## Routers — auth granular

```typescript
// server/api/routers/user.ts
export const userRouter = router({
  // Público
  getPublic: publicProcedure
    .query(() => ({ message: 'Hello' })),

  // Autenticado
  getMe: protectedProcedure
    .query(({ ctx }) => ctx.user),

  // Admin
  listAll: adminProcedure
    .query(({ ctx }) => ctx.db.user.findMany()),

  // Com input validation
  update: protectedProcedure
    .input(z.object({
      id: z.string().uuid(),
      name: z.string().min(1).max(100),
    }))
    .mutation(async ({ input, ctx }) => {
      // Auth check granular (anti-IDOR)
      const existing = await ctx.db.user.findUnique({ where: { id: input.id } });
      if (existing?.ownerId !== ctx.user.id && ctx.user.role !== 'admin') {
        throw new TRPCError({ code: 'FORBIDDEN' });
      }
      return ctx.db.user.update({
        where: { id: input.id },
        data: { name: input.name },
      });
    }),
});
```

## Output sanitization

tRPC devolve **objetos completos** por default — sem DTO filtering automatic.

```typescript
// BAD — devolve User inteiro (passwordHash incluído)
getMe: protectedProcedure
  .query(({ ctx }) => ctx.db.user.findUnique({ where: { id: ctx.user.id } })),

// GOOD — Prisma select explícito
getMe: protectedProcedure
  .query(({ ctx }) => ctx.db.user.findUnique({
    where: { id: ctx.user.id },
    select: { id: true, name: true, email: true },  // explicit
  })),

// Ou .output() com schema (valida no envio)
getMe: protectedProcedure
  .output(z.object({
    id: z.string(),
    name: z.string(),
    email: z.string().email(),
  }))
  .query(/* ... */),
```

## CSRF
- tRPC sobre HTTP usa POST normalmente.
- Se autenticado por **cookies**, vulnerable a CSRF — adicionar token CSRF.
- Se autenticado por **Bearer token** em header, não vulnerável a CSRF clássico.

## Rate limiting

tRPC não tem rate limit built-in. Aplicar a nível HTTP:

```typescript
// Next.js API route com tRPC
import { createNextApiHandler } from '@trpc/server/adapters/next';
import rateLimit from 'next-rate-limit';

const limiter = rateLimit({ interval: 60_000, uniqueTokenPerInterval: 500 });

export default async function handler(req, res) {
  try {
    await limiter.check(res, 100, 'CACHE_TOKEN');
  } catch {
    return res.status(429).json({ error: 'rate limited' });
  }
  return createNextApiHandler({ router: appRouter, createContext })(req, res);
}
```

## Errors — não vazar internals

```typescript
import { initTRPC } from '@trpc/server';

const t = initTRPC.context<Context>().create({
  errorFormatter({ shape, error }) {
    return {
      ...shape,
      data: {
        ...shape.data,
        // BAD — devolve stack em prod
        // stack: error.stack,
      },
    };
  },
});
```

## Common antipatterns

### `publicProcedure` em route que devia ser autenticado
- `publicProcedure` = sem auth. Confirma cada route.

### Type safety confunde com authorization
- `input(z.object({ userId: z.string() }))` valida tipo, não permissão.
- Sempre verificar ownership/role no resolver.

### Devolver entidade Prisma direto
- Inclui campos sensíveis. Usar `select` ou `output` schema.

### `ctx.user.id` não verificado em mutation
- Atacante envia `userId` arbitrário se input aceita.

### Cliente confia em `ctx` server-side
- Cliente não vê `ctx`, mas se passas dados de `ctx` para input, atacante consegue manipular.

### Subscription sem auth
- WebSocket subscriptions também precisam de auth check.

### Sem rate limit
- Endpoint tRPC = endpoint HTTP normal, mesmo problema de DoS.

### Logging de inputs completos
- Pode incluir PII / passwords.

## tRPC + Next.js / SvelteKit / Solid

Seguir profile do framework correspondente para auth/sessão. tRPC adiciona type safety + procedures, mas auth backend é igual.

## Quick wins

- [ ] tRPC v10+
- [ ] `npm audit` sem Críticos
- [ ] Procedures separadas: `publicProcedure`, `protectedProcedure`, `adminProcedure`
- [ ] Cada route com a procedure adequada (default protected)
- [ ] `input(z.object({...}))` em todas as mutations
- [ ] `select` Prisma ou `output` schema para filtrar response
- [ ] Ownership/role check granular em mutations (anti-IDOR)
- [ ] Rate limiting na camada HTTP (Next/Express middleware)
- [ ] CSRF protection se auth via cookies
- [ ] `errorFormatter` sem stack em produção
- [ ] Subscriptions com auth
- [ ] Logs sem inputs completos (sanitização)
- [ ] Plus: ver profile do framework host (Next.js, SvelteKit, etc.)
