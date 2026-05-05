# Remix — Profile de Segurança

## Deteção
- `package.json` com `@remix-run/*`
- `remix.config.js` ou `vite.config.ts` com `@remix-run/dev`
- `app/root.tsx`

## Loaders e Actions — server-side

Tudo em `loader`/`action` corre no servidor. Tudo o resto pode ir para o client.

### Auth em loader
```typescript
// app/routes/admin._index.tsx
import { redirect, type LoaderFunctionArgs } from '@remix-run/node';
import { requireAdmin } from '~/lib/auth.server';

export async function loader({ request }: LoaderFunctionArgs) {
  await requireAdmin(request);  // redirect se não admin
  // ...
  return json({ users: await db.user.findMany() });
}
```

### Action com validação
```typescript
import { json, type ActionFunctionArgs } from '@remix-run/node';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

export async function action({ request }: ActionFunctionArgs) {
  const user = await requireUser(request);

  const formData = await request.formData();
  const parsed = schema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return json({ errors: parsed.error.flatten() }, { status: 400 });

  await db.user.create({ data: { ...parsed.data, ownerId: user.id } });
  return redirect('/users');
}
```

## CSRF
- Remix Forms usam POST + cookies → vulneráveis a CSRF se não houver proteção.
- **Soluções:**
  - `remix-utils` tem `CSRF` helper.
  - Verificar `Origin` header no action.
  - Custom token em form hidden field + cookie.

```typescript
// Verificação simples de Origin
export async function action({ request }: ActionFunctionArgs) {
  const origin = request.headers.get('Origin');
  const host = request.headers.get('Host');
  if (origin && !origin.endsWith(host)) {
    return new Response('CSRF', { status: 403 });
  }
  // ...
}
```

## Sessions (cookies)

```typescript
// app/sessions.server.ts
import { createCookieSessionStorage } from '@remix-run/node';

export const sessionStorage = createCookieSessionStorage({
  cookie: {
    name: 'sid',
    secrets: [process.env.SESSION_SECRET!],  // array para rotation
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 7,  // 1 semana
    path: '/',
  },
});
```

## XSS

Remix usa React → auto-escape. Cuidados:
```jsx
// BAD
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// GOOD
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userContent) }} />
```

## Headers — entry.server.tsx

```typescript
// app/entry.server.tsx
export default function handleRequest(req, status, headers, ctx) {
  headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('X-Frame-Options', 'SAMEORIGIN');
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  // ...
  return new Response(/* ... */);
}
```

## Common antipatterns

### Loaders devolvem TUDO
- Filtrar campos antes de `json()`.

### Actions sem auth
- Cada action deve verificar user.

### `useLoaderData` confia em data
- Data do loader é serializada — pode incluir info sensível se loader não filtrar.

### `useFetcher` sem token
- `Form` automatically submit, mas `useFetcher.submit` pode bypass CSRF.

### Resources Routes (sem UI) sem auth
- `app/routes/api.users.ts` exporta loader que devolve JSON — qualquer um chama.

### Cookies em loaders sem `httpOnly`
- `cookie()` factory aceita opts — verificar todas configuradas.

## Quick wins

- [ ] Remix 2+
- [ ] `npm audit` sem Críticos
- [ ] CSRF protection (origin check ou `remix-utils`)
- [ ] `requireUser`/`requireAdmin` em todos os loaders/actions privados
- [ ] DTOs filtrados em `json()` returns
- [ ] Validation com Zod em actions
- [ ] Session cookies com `httpOnly + secure + sameSite`
- [ ] Headers em `entry.server.tsx`
- [ ] `dangerouslySetInnerHTML` só com DOMPurify
- [ ] Resource routes (sem UI) com auth
- [ ] Rate limit em actions sensíveis
- [ ] `entry.server.tsx` não vaza stack em production errors
