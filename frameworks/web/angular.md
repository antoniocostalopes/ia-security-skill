# Angular — Profile de Segurança

> Angular tem segurança built-in mais robusta que React/Vue. Auto-escape em templates, sanitização contextual, CSRF protection, AOT compilation. Mas tem antipatterns próprios.

## Deteção
- `package.json` com `@angular/core`
- `angular.json`
- `tsconfig.json` Angular-style

## Auto-escape (built-in)

Angular **escapa por default** em interpolations e bindings:
```html
<p>{{ userInput }}</p>            <!-- escaped -->
<div [innerHTML]="userHtml"></div> <!-- sanitizado por DomSanitizer -->
```

## DomSanitizer — bypass perigoso

```typescript
// BAD — bypass de sanitização
import { DomSanitizer } from '@angular/platform-browser';

@Component({...})
export class MyComponent {
  constructor(private sanitizer: DomSanitizer) {}

  unsafeHtml = this.sanitizer.bypassSecurityTrustHtml(userInput);  // !! XSS
  unsafeUrl = this.sanitizer.bypassSecurityTrustUrl(userUrl);      // !! Open redirect
  unsafeScript = this.sanitizer.bypassSecurityTrustScript(input);  // !! RCE
}

// GOOD — deixar Angular sanitizar
@Component({
  template: '<div [innerHTML]="content"></div>'
})
export class MyComponent {
  content = userInput;  // Angular sanitiza automaticamente
}
```

## HttpClient — CSRF protection

Angular tem **HttpXsrfModule** built-in:

```typescript
// app.module.ts
import { HttpClientXsrfModule } from '@angular/common/http';

@NgModule({
  imports: [
    HttpClientXsrfModule.withOptions({
      cookieName: 'XSRF-TOKEN',         // backend define este cookie
      headerName: 'X-XSRF-TOKEN',       // Angular envia automaticamente
    }),
  ],
})
```

Backend (Express, Spring, etc.) deve:
- Definir cookie `XSRF-TOKEN` em login (não-HttpOnly para JS ler)
- Validar header `X-XSRF-TOKEN` em mutations

## HTTP Interceptors

```typescript
// Auth interceptor
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  intercept(req: HttpRequest<any>, next: HttpHandler) {
    const token = this.auth.getToken();
    if (token) {
      req = req.clone({ setHeaders: { Authorization: `Bearer ${token}` } });
    }
    return next.handle(req);
  }
}
```

## Reactive Forms — validation

```typescript
import { FormBuilder, Validators } from '@angular/forms';

this.form = this.fb.group({
  email: ['', [Validators.required, Validators.email, Validators.maxLength(254)]],
  password: ['', [Validators.required, Validators.minLength(12)]],
  // role NÃO incluído — anti mass assignment via form
});
```

## Route Guards

```typescript
// CanActivate guard
@Injectable({ providedIn: 'root' })
export class AdminGuard implements CanActivate {
  constructor(private auth: AuthService, private router: Router) {}

  canActivate(): boolean | UrlTree {
    if (this.auth.user?.isAdmin) return true;
    return this.router.parseUrl('/');
  }
}

// Routes
{ path: 'admin', component: AdminComponent, canActivate: [AdminGuard] }
```

## Production build

```bash
ng build --configuration=production
# - AoT compilation (não JIT em runtime)
# - Tree shaking
# - Minification
# - Source maps off por default em prod
```

```json
// angular.json — verificar
"production": {
  "sourceMap": false,
  "namedChunks": false,
  "extractLicenses": true,
  "vendorChunk": false,
  "buildOptimizer": true,
  "optimization": true,
  "outputHashing": "all"
}
```

## Common antipatterns

### `bypassSecurityTrust*` com input do user
- Bypass do XSS protection.

### `[innerHTML]` com `DomSanitizer.bypassSecurityTrustHtml(input)`
- XSS armazenado.

### JIT em produção
- Compilação em runtime + DevTools acessíveis. AoT é default agora mas verificar.

### `ng serve` em produção
- Dev server sem otimização.

### `ngOnInit` com side effects sem cleanup
- Memory leak; não é vuln direta.

### Eager loading de tudo
- Bundle gigante. Lazy load routes.

### Routes sem guards
- Acesso direto a rotas que deviam ser protegidas.

### `HttpClient` sem `withCredentials` em CORS calls
- Cookies não enviados. CSRF / auth quebram.

### Strict mode off (`strictTemplates: false`)
- TypeScript checks fracos.

## Helpers built-in

| Necessidade | Use |
|---|---|
| Sanitization | `DomSanitizer` (com cuidado em bypass) |
| CSRF | `HttpClientXsrfModule` |
| Auth guard | `CanActivate`, `CanActivateChild`, `CanLoad` |
| Form validation | Reactive Forms + `Validators` |
| HTTP | `HttpClient` (não fetch direto) |
| Router | `Router.navigate` com URL paths (não window.location) |

## Quick wins

- [ ] Angular 17+
- [ ] `npm audit` sem Críticos
- [ ] AoT compilation ON em prod (default)
- [ ] Strict mode (`"strict": true`, `"strictTemplates": true`)
- [ ] Sem `bypassSecurityTrust*` com input do user
- [ ] `HttpClientXsrfModule` configurado
- [ ] HttpInterceptors para auth tokens
- [ ] Reactive Forms com Validators
- [ ] Route Guards em routes privadas
- [ ] Tokens em cookies HttpOnly (não localStorage)
- [ ] Source maps off em prod
- [ ] Lazy loading de routes
- [ ] CSP no servidor
- [ ] Sem `withCredentials: false` esquecido em CORS
- [ ] `ng build --configuration=production` (não dev)
