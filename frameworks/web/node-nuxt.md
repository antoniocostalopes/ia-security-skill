# Nuxt 3 — Profile de Segurança

## Deteção
- `package.json` com `nuxt`
- `nuxt.config.ts`
- `server/` directory (Nitro server)

## Server (Nitro) vs Client

Como Next.js, separa servidor e cliente. Variables expostas via `runtimeConfig`.

```typescript
// nuxt.config.ts
export default defineNuxtConfig({
  runtimeConfig: {
    apiSecret: process.env.API_SECRET,  // server-only
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE,  // exposto ao client
    },
  },
});
```

```vue
<!-- Server / Composables — pode aceder tudo -->
<script setup>
const config = useRuntimeConfig();
console.log(config.apiSecret);  // só server-side
console.log(config.public.apiBase);  // ambos
</script>
```

## Server routes (`server/api/*`)

```typescript
// server/api/users.post.ts
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

export default defineEventHandler(async (event) => {
  // Auth
  const user = await requireAuth(event);
  if (!user.isAdmin) throw createError({ statusCode: 403 });

  // Validation
  const body = await readValidatedBody(event, schema.parse);

  // Action
  return await db.user.create({ data: { ...body, ownerId: user.id } });
});
```

## Middleware (server e client)

### Server middleware
```typescript
// server/middleware/auth.ts
export default defineEventHandler(async (event) => {
  const url = getRequestURL(event);
  if (url.pathname.startsWith('/api/admin')) {
    const user = await getUser(event);
    if (!user?.isAdmin) throw createError({ statusCode: 403 });
  }
});
```

### Route middleware (client)
```typescript
// middleware/admin.ts
export default defineNuxtRouteMiddleware((to) => {
  const user = useUser();
  if (!user.value?.isAdmin) return navigateTo('/login');
});

// pages/admin/index.vue
definePageMeta({ middleware: ['admin'] });
```

## XSS — Vue templates

```vue
<!-- Auto-escaped -->
<div>{{ userInput }}</div>

<!-- BAD — v-html sem sanitização -->
<div v-html="userHtml"></div>

<!-- GOOD -->
<div v-html="DOMPurify.sanitize(userHtml)"></div>
```

## Headers

```typescript
// nuxt.config.ts — usar @nuxtjs/security ou rotas custom
export default defineNuxtConfig({
  modules: ['nuxt-security'],
  security: {
    headers: {
      contentSecurityPolicy: {
        'default-src': ["'self'"],
        'script-src': ["'self'", "'nonce-{{nonce}}'"],
      },
      strictTransportSecurity: { maxAge: 31536000, includeSubdomains: true, preload: true },
      xFrameOptions: 'SAMEORIGIN',
      xContentTypeOptions: 'nosniff',
      referrerPolicy: 'strict-origin-when-cross-origin',
    },
    rateLimiter: { tokensPerInterval: 100, interval: 'minute' },
  },
});
```

## Common antipatterns

### `runtimeConfig.public.X` com secrets
- `public` é exposto ao cliente. Verificar.

### `useFetch`/`$fetch` com URL controlada por user
- SSRF se chamado em server-side com URL do user.

### Server routes sem auth check
- Cada `defineEventHandler` deve verificar auth se aplicável.

### Plugins client-side com secrets
- Qualquer `plugins/*.client.ts` está no bundle final.

### `useState` com dados sensíveis
- `useState` em SSR é serializado para client via `__NUXT__` payload.
- Não pôr secrets ou PII de outros users.

### `navigateTo` com URL externa
- Open redirect.
- `navigateTo('/safe-path')` ok; `navigateTo(userInput)` perigoso.

## Helpers Nitro

```typescript
// Útil para auth
const user = await getUserSession(event);
await requireUserSession(event);  // throws se não autenticado

// Cookies
setCookie(event, 'session', value, {
  httpOnly: true, secure: true, sameSite: 'lax', maxAge: 86400
});

// CSRF (manual ou via plugin)
import { useCsrf } from '#imports';
```

## Quick wins

- [ ] Nuxt 3.x (Nuxt 2 EOL)
- [ ] `npm audit` sem Críticos
- [ ] `runtimeConfig` separa secret server vs `public`
- [ ] Server routes com auth check
- [ ] `readValidatedBody` com Zod
- [ ] `nuxt-security` module
- [ ] CSP definido
- [ ] HSTS via headers
- [ ] Cookies com `httpOnly + secure + sameSite`
- [ ] `v-html` sempre com DOMPurify
- [ ] Rate limit em endpoints sensíveis
- [ ] `navigateTo` com URLs validadas
- [ ] `useState` sem secrets
- [ ] Plugins client-side sem secrets
- [ ] Source maps off em prod (`sourcemap: { server: false, client: false }`)
