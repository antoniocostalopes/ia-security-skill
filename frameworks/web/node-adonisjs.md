# AdonisJS — Profile de Segurança

> AdonisJS é full-stack TypeScript framework Node.js (estilo Laravel mas para TS). Inclui ORM, auth, validation, mailer, etc.

## Deteção
- `package.json` com `@adonisjs/core`
- `ace` CLI
- `start/routes.ts`, `app/`

## Auth — built-in

```typescript
// config/auth.ts
import { defineConfig } from '@adonisjs/auth';
import { sessionGuard, sessionUserProvider } from '@adonisjs/auth/session';

export default defineConfig({
  default: 'web',
  guards: {
    web: sessionGuard({
      useRememberMeTokens: false,
      provider: sessionUserProvider({ model: () => import('#models/user') }),
    }),
    api: tokenGuard({...}),  // API tokens
  },
});
```

```typescript
// Controller
export default class UsersController {
  async show({ auth, response }: HttpContext) {
    if (!await auth.use('web').check()) {
      return response.unauthorized()
    }
    const user = auth.use('web').user!;
    // ...
  }
}
```

## Middleware — route protection

```typescript
// start/routes.ts
import router from '@adonisjs/core/services/router';
import { middleware } from './kernel.js';

router.group(() => {
  router.get('/dashboard', '#controllers/dashboard_controller.show');
}).use(middleware.auth());

router.group(() => {
  router.get('/admin', '#controllers/admin_controller.index');
}).use([middleware.auth(), middleware.role('admin')]);
```

## Validation — VineJS (built-in)

```typescript
import vine from '@vinejs/vine';

const createUserValidator = vine.compile(
  vine.object({
    name: vine.string().minLength(1).maxLength(100),
    email: vine.string().email(),
    password: vine.string().minLength(12),
  })
);

// Controller
async store({ request }: HttpContext) {
  const data = await request.validateUsing(createUserValidator);
  // data já validado
}
```

## Lucid ORM

```typescript
// BAD
const users = await db.rawQuery(`SELECT * FROM users WHERE name = '${name}'`);

// GOOD
const users = await db.rawQuery('SELECT * FROM users WHERE name = ?', [name]);

// MELHOR — query builder ou Lucid Models
const users = await User.query().where('name', name);
```

## CSRF (built-in via Shield)

```typescript
// config/shield.ts
import { defineConfig } from '@adonisjs/shield';

export default defineConfig({
  csrf: {
    enabled: true,
    exceptRoutes: ['/api/webhooks/*'],  // exclude webhooks
    enableXsrfCookie: true,
  },
  contentSecurityPolicy: {
    directives: {
      defaultSrc: [`'self'`],
      scriptSrc: [`'self'`],
    },
  },
  hsts: { enabled: true, maxAge: '180 days' },
  xFrame: { enabled: true, action: 'SAMEORIGIN' },
  noSniff: { enabled: true },
});
```

## Edge templates — XSS

```edge
{{-- Auto-escaped --}}
{{ user.name }}

{{-- Raw — perigoso --}}
{{{ user.bio }}}

{{-- GOOD se HTML controlado --}}
{{{ html.sanitize(user.bio) }}}
```

## File uploads (Drive)

```typescript
import drive from '@adonisjs/drive/services/main';

async upload({ request }: HttpContext) {
  const file = request.file('avatar', {
    size: '2mb',
    extnames: ['jpg', 'png'],
  });

  if (!file?.isValid) return response.badRequest(file?.errors);

  const filename = `${cuid()}.${file.extname}`;
  await file.moveToDisk(`avatars/${filename}`);
  // Drive valida + storage
}
```

## Mail — header injection

```typescript
// Vine validates email format, mas:
// BAD — passar input não validado para subject
mail.send((message) => {
  message.subject(request.input('subject'))  // CRLF injection se mal validado
});

// GOOD — validar e sanitizar
const safeSubject = request.input('subject', '').replace(/[\r\n]/g, '');
```

## Common antipatterns

### `request.body()` direto sem validator
- Mass assignment / aceita qualquer estrutura.

### `auth.use().check()` sem await
- Returns Promise, sempre truthy.

### Sem `middleware.auth()` em route group
- Acessível a qualquer um.

### Shield desativado globally
- CSRF off, sem CSP, sem HSTS.

### `db.rawQuery` com interpolation
- SQLi.

### Sem rate limit em login
- Brute force.

### `node ace serve --watch` em prod
- Dev server.

## Quick wins

- [ ] AdonisJS 6.x
- [ ] `npm audit` sem Críticos
- [ ] Auth guards configurados
- [ ] `middleware.auth()` em rotas privadas
- [ ] Validators (Vine) em todos os endpoints com input
- [ ] DTOs implícitos via validators (anti mass assignment)
- [ ] Lucid Models / Query Builder (não rawQuery com interpolation)
- [ ] Shield (CSRF + CSP + HSTS) ativo
- [ ] Edge templates auto-escape (default)
- [ ] Drive uploads com size + extension validation
- [ ] Rate limiter (Limiter) em endpoints sensíveis
- [ ] Headers de segurança via Shield
- [ ] Cookies seguros (config/app.ts)
- [ ] Email validation antes de send
- [ ] `node ace build` para produção (não `serve`)
- [ ] Plus: ver `linguagens/javascript-typescript.md`
