# Next.js — Profile de Segurança

## Deteção
- `package.json` com `next`
- `next.config.js`
- `pages/` ou `app/` directories

## Server vs Client — distinção crítica

Next.js mistura código servidor e cliente. Fácil vazar secrets ao cliente.

### Variáveis de ambiente
```javascript
// BAD — acessível no cliente! (prefixo NEXT_PUBLIC_)
NEXT_PUBLIC_STRIPE_SECRET=sk_live_...  // !! exposto

// GOOD
STRIPE_SECRET=sk_live_...              // só servidor
NEXT_PUBLIC_STRIPE_PUBLISHABLE=pk_...  // ok, public por design
```

```javascript
// Server Component / API Route — pode usar tudo
export default async function Page() {
  const secret = process.env.STRIPE_SECRET;  // OK
}

// Client Component ('use client') — só NEXT_PUBLIC_
'use client';
const key = process.env.NEXT_PUBLIC_API_KEY;  // OK
const secret = process.env.STRIPE_SECRET;     // undefined no cliente
```

## App Router — Server Components / Actions

### Server Actions
```typescript
// BAD — sem auth check
'use server';
export async function deleteUser(id: string) {
  await db.user.delete({ where: { id } });
}

// GOOD
'use server';
import { auth } from '@/auth';

export async function deleteUser(id: string) {
  const session = await auth();
  if (!session?.user?.isAdmin) throw new Error('Unauthorized');

  // Validar ownership ou role
  await db.user.delete({ where: { id } });
}
```

### Server Components — data leakage
```typescript
// BAD — passa o user inteiro para client
export default async function Page() {
  const user = await db.user.findUnique({ where: { id: userId } });
  return <ClientComponent user={user} />;  // inclui passwordHash, etc.
}

// GOOD — DTO
export default async function Page() {
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { id: true, name: true, email: true },  // explicit
  });
  return <ClientComponent user={user} />;
}
```

### `dangerouslySetInnerHTML`
```jsx
// BAD
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// GOOD — sanitizar primeiro
import DOMPurify from 'isomorphic-dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userContent) }} />
```

## API Routes (`pages/api/*` ou `app/api/*`)

```typescript
// app/api/users/route.ts
import { NextResponse } from 'next/server';
import { auth } from '@/auth';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1).max(100),
});

export async function POST(req: Request) {
  // 1. Auth
  const session = await auth();
  if (!session) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  // 2. Validation
  const body = await req.json();
  const parsed = schema.safeParse(body);
  if (!parsed.success) return NextResponse.json({ error: parsed.error }, { status: 400 });

  // 3. Action com permissão
  const user = await db.user.create({
    data: { ...parsed.data, ownerId: session.user.id },
  });

  return NextResponse.json(user);
}
```

## Middleware

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import { auth } from '@/auth';

export default async function middleware(req: NextRequest) {
  const session = await auth();
  const isAdmin = req.nextUrl.pathname.startsWith('/admin');

  if (isAdmin && !session?.user?.isAdmin) {
    return NextResponse.redirect(new URL('/login', req.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/admin/:path*', '/api/admin/:path*'],
};
```

## Headers — `next.config.js`

```javascript
module.exports = {
  async headers() {
    return [{
      source: '/(.*)',
      headers: [
        { key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains; preload' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
        { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        { key: 'Permissions-Policy', value: 'geolocation=(), microphone=(), camera=()' },
        { key: 'Content-Security-Policy', value: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; ..." },
      ],
    }];
  },
};
```

## Image / Link safety

```jsx
// next/image — atenção a domains
// next.config.js
images: {
  remotePatterns: [
    { protocol: 'https', hostname: 'cdn.meusite.tld' },
  ],
}
// SEM isto, qualquer domínio passa → SSRF via Image Optimizer
```

## Common antipatterns

### `getServerSideProps` que devolve TUDO da BD
- Filtrar campos antes de devolver props.

### Server Actions sem auth
- Action é uma RPC — qualquer client a pode chamar com IDs arbitrários.

### `revalidatePath` / `revalidateTag` sem validação
- Atacante pode forçar invalidação de cache.

### `next.config.js` com `output: 'standalone'` mas secrets em build
- Build inclui env vars `NEXT_PUBLIC_*` no bundle. Verificar bundle.

### `Image` com `unoptimized: true`
- Bypassa otimização e validação. Apenas para casos específicos.

### Cookies (`cookies()` do `next/headers`)
- Definir `httpOnly + secure + sameSite + maxAge` sempre.

### CSRF em Server Actions
- Server Actions têm proteção CSRF interna (Next 14+) mas **só** para origens iguais.
- Para callbacks externos, usar API Route com verificação custom.

### Source maps em produção
```javascript
// next.config.js
module.exports = {
  productionBrowserSourceMaps: false,  // default false; manter assim
};
```

## Helpers comuns

| Necessidade | Package |
|---|---|
| Auth | `next-auth` v5 / `auth.js`, `clerk`, `lucia-auth` |
| Validation | `zod` (ecossistema padrão) |
| ORM | `Prisma`, `Drizzle` |
| Rate limit | `@upstash/ratelimit` (edge-friendly) |
| HTML sanitize | `isomorphic-dompurify` |
| Headers | inline em `next.config.js` ou `middleware.ts` |

## Quick wins

- [ ] Next.js 14+ (preferir App Router em código novo)
- [ ] `npm audit` sem Críticos
- [ ] Auditar **todos** os `process.env.*` no client (`use client` files) — sem secrets
- [ ] Server Actions com auth check explícito
- [ ] DTOs explícitos em `select` do Prisma/Drizzle (sem expor passwordHash)
- [ ] `dangerouslySetInnerHTML` só com DOMPurify
- [ ] Headers de segurança no `next.config.js`
- [ ] `images.remotePatterns` com allowlist (não `domains: ['*']`)
- [ ] Middleware aplica auth em `/admin/*` e `/api/admin/*`
- [ ] Cookies com `httpOnly + secure + sameSite`
- [ ] Rate limit em API Routes sensíveis
- [ ] Validation com Zod em todas as API Routes e Server Actions
- [ ] `revalidate*` calls com auth/verification
- [ ] CSP cuidadosa (Next gera muito inline JS — pode precisar de nonces)
- [ ] `next-auth`/`auth.js` com session callback que filtra campos
