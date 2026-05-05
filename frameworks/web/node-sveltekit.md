# SvelteKit — Profile de Segurança

## Deteção
- `package.json` com `@sveltejs/kit`
- `svelte.config.js`
- `src/routes/` directory

## Server vs Client

- `+page.server.ts`, `+layout.server.ts`, `+server.ts` → server-only.
- `+page.ts`, `+layout.ts` → universal (cuidado com secrets).
- `+page.svelte` → client após hydration.

```typescript
// src/lib/secrets.server.ts ← `.server.` extension força server-only
export const apiSecret = process.env.API_SECRET;
```

## Load functions

```typescript
// +page.server.ts
import { error, redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
  if (!locals.user) throw redirect(302, '/login');
  if (!locals.user.isAdmin) throw error(403, 'forbidden');

  return {
    users: await db.user.findMany({
      select: { id: true, name: true, email: true },  // explicit
    }),
  };
};
```

## Form actions

```typescript
// +page.server.ts
import { fail } from '@sveltejs/kit';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

export const actions = {
  create: async ({ request, locals }) => {
    if (!locals.user) return fail(401);

    const formData = Object.fromEntries(await request.formData());
    const parsed = schema.safeParse(formData);
    if (!parsed.success) return fail(400, { errors: parsed.error.flatten() });

    await db.user.create({ data: { ...parsed.data, ownerId: locals.user.id } });
    return { success: true };
  },
};
```

## CSRF

SvelteKit tem CSRF protection **built-in** desde v1.0:
```typescript
// svelte.config.js
const config = {
  kit: {
    csrf: {
      checkOrigin: true,  // default true — verifica Origin em POST
    },
  },
};
```
- Para webhooks externos (que não enviam Origin matching), criar `+server.ts` específico ou desativar para esse endpoint.

## API endpoints (`+server.ts`)

```typescript
// src/routes/api/users/+server.ts
import { json, error } from '@sveltejs/kit';

export async function POST({ request, locals }) {
  if (!locals.user) throw error(401);

  const data = await request.json();
  // validation, action, response
  return json({ id: 1 });
}
```

## Hooks

```typescript
// src/hooks.server.ts
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  // Auth — popular event.locals.user
  const sessionId = event.cookies.get('sid');
  event.locals.user = sessionId ? await getUserBySession(sessionId) : null;

  // Headers
  const response = await resolve(event);
  response.headers.set('X-Frame-Options', 'SAMEORIGIN');
  response.headers.set('Content-Security-Policy', "default-src 'self'");
  return response;
};
```

## Cookies

```typescript
event.cookies.set('sid', token, {
  path: '/',
  httpOnly: true,
  secure: true,
  sameSite: 'lax',
  maxAge: 60 * 60 * 24 * 7,
});
```

## XSS — Svelte templates

```svelte
<!-- Auto-escape -->
<div>{userInput}</div>

<!-- BAD — @html sem sanitização -->
{@html userHtml}

<!-- GOOD -->
{@html DOMPurify.sanitize(userHtml)}
```

## Common antipatterns

### `+page.ts` (universal load) com secrets
- Roda no servidor E no cliente (após hydration).
- Sempre `+page.server.ts` para queries com auth.

### Forms sem `use:enhance`
- Funcionam como POST normal. CSRF protection ainda aplica (built-in), mas UX é pior.

### `csrf.checkOrigin: false` global
- Desativa proteção. Apenas para endpoints específicos.

### Endpoints `+server.ts` sem auth
- Sem hooks ou check explícito → endpoint público.

### `redirect(303, untrustedURL)`
- Open redirect. Validar.

### `error(500, err.message)` direto
- Vaza info. Logar internamente, devolver mensagem genérica.

## Quick wins

- [ ] SvelteKit 2+
- [ ] `npm audit` sem Críticos
- [ ] Loaders/actions sensíveis em `+page.server.ts` (não `+page.ts`)
- [ ] Auth check via hook em `event.locals`
- [ ] CSRF (`checkOrigin: true`) ativo
- [ ] Cookies com `httpOnly + secure + sameSite`
- [ ] Validation com Zod em actions/server endpoints
- [ ] Headers de segurança em `hooks.server.ts`
- [ ] `@html` só com DOMPurify
- [ ] Rate limit em endpoints sensíveis (manual ou via lib)
- [ ] Files com `.server.` extension para secrets
- [ ] Error handler que não vaza stack
