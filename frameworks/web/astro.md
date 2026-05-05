# Astro — Profile de Segurança

> Astro é content-focused, ships zero JS por default. Combina SSR + ilhas (componentes hidratados). Modelo de ameaça mais próximo de SSR tradicional do que SPA.

## Deteção
- `package.json` com `astro`
- `astro.config.mjs`
- `src/pages/` directory

## Server vs Client (Islands)

Por default, Astro renderiza tudo no server e ships zero JS. Componentes interativos ("ilhas") usam client directives:

```astro
<!-- Server-only — sem JS no client -->
<MyComponent />

<!-- Hidratada no client -->
<MyComponent client:load />     <!-- Carrega imediato -->
<MyComponent client:idle />     <!-- Carrega quando idle -->
<MyComponent client:visible />  <!-- Carrega quando visible -->
<MyComponent client:only="react" />  <!-- Apenas client -->
```

> **Implicação:** menos client-side JS = menor superfície XSS. Use server-side rendering quando possível.

## Variáveis de ambiente

```bash
# .env
PUBLIC_API_URL=https://api.meusite.tld   # PUBLIC_* vai para client
SECRET_API_KEY=sk_live_xxx                # sem PUBLIC_ = só server
```

```astro
---
// Server-side (frontmatter)
const apiKey = import.meta.env.SECRET_API_KEY;  // OK
---

<script>
  // Client-side
  console.log(import.meta.env.SECRET_API_KEY);  // undefined no client (bom)
  console.log(import.meta.env.PUBLIC_API_URL);  // visível
</script>
```

## API endpoints (`src/pages/api/`)

```typescript
// src/pages/api/users.ts
import type { APIRoute } from 'astro';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

export const POST: APIRoute = async ({ request, cookies, locals }) => {
  // Auth check
  const session = cookies.get('session')?.value;
  if (!session) return new Response('Unauthorized', { status: 401 });

  // Validation
  const body = await request.json();
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    return new Response(JSON.stringify(parsed.error), { status: 400 });
  }

  // Action
  // ...
  return new Response(JSON.stringify({ ok: true }), {
    status: 201,
    headers: { 'Content-Type': 'application/json' },
  });
};
```

## Middleware

```typescript
// src/middleware.ts
import type { MiddlewareHandler } from 'astro';

export const onRequest: MiddlewareHandler = async (context, next) => {
  // Auth
  const session = context.cookies.get('session')?.value;
  context.locals.user = session ? await getUser(session) : null;

  // Headers
  const response = await next();
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-Frame-Options', 'SAMEORIGIN');
  response.headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  return response;
};
```

## XSS — `set:html`

```astro
---
const userContent = await fetchContent();
---

<!-- Auto-escaped -->
<p>{userContent}</p>

<!-- BAD — set:html sem sanitização -->
<div set:html={userContent}></div>

<!-- GOOD -->
<div set:html={DOMPurify.sanitize(userContent)}></div>
```

## Form actions (Astro 4+)

```typescript
// src/actions/index.ts
import { defineAction } from 'astro:actions';
import { z } from 'astro:schema';

export const server = {
  createPost: defineAction({
    accept: 'form',
    input: z.object({
      title: z.string().min(1).max(200),
      content: z.string().max(10000),
    }),
    handler: async (input, context) => {
      const user = context.locals.user;
      if (!user) throw new Error('Unauthorized');
      // ...
    },
  }),
};
```

## Common antipatterns

### `set:html` sem sanitização
- XSS direto.

### `client:only` sem motivo
- Bypass de SSR. Pode introduzir hydration mismatch.

### `define:vars` com secrets
- `define:vars={{ apiKey: SECRET }}` injecta no script tag → público.

### Endpoints API sem auth check
- Cada `src/pages/api/*` é endpoint público por default.

### Output mode SSG quando precisa SSR
- Pré-rendering com dados sensíveis = info disclosure.

### Middleware ausente em routes que precisam auth
- Sem middleware central, esquece-se em cada page.

### Adapter mal configurado
- `output: 'server'` em deploy estático = não funciona.

## Quick wins

- [ ] Astro 4+
- [ ] `npm audit` sem Críticos
- [ ] Variáveis sensíveis sem prefix `PUBLIC_`
- [ ] Endpoints API com auth check
- [ ] Middleware para headers de segurança
- [ ] Validation com Zod (built-in via `astro:schema`)
- [ ] `set:html` apenas com DOMPurify
- [ ] `client:*` directives apenas onde necessário (preferir server-rendered)
- [ ] Cookies com flags adequadas em `cookies.set`
- [ ] Form actions usadas (Astro 4+)
- [ ] Output mode (`static` vs `server` vs `hybrid`) intencional
- [ ] Adapter (Node/Vercel/Netlify) configurado para o deploy real
- [ ] Source maps off em prod
- [ ] CSP via middleware
