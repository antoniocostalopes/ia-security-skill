# Blazor — Profile de Segurança

> Blazor Server e Blazor WASM têm modelos de segurança diferentes. Server roda no servidor (mais seguro mas escalabilidade); WASM roda no browser (todo o código + lógica visível).

## Blazor Server vs WASM

| Aspeto | Blazor Server | Blazor WASM |
|---|---|---|
| Onde roda | Servidor | Browser |
| Visibilidade do código | Privado | Público (download .dll) |
| Auth tokens | Server side | Storage local (XSS risk) |
| State | SignalR connection | Browser memory |
| Secrets em código | OK (server) | NUNCA |

## Blazor WASM — secrets

```csharp
// BAD — código WASM no browser, qualquer um vê
public class ApiClient {
    private const string ApiKey = "sk_live_secret";  // !!
}

// GOOD — proxy via servidor
// Frontend WASM → API server (autenticado) → API externa (com secret server-side)
```

## Auth em Blazor Server

```csharp
// Program.cs
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(opt => {
        opt.Cookie.HttpOnly = true;
        opt.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        opt.Cookie.SameSite = SameSiteMode.Lax;
        opt.SlidingExpiration = true;
        opt.ExpireTimeSpan = TimeSpan.FromHours(1);
    });

builder.Services.AddCascadingAuthenticationState();
```

```razor
@* Component *@
<AuthorizeView>
    <Authorized>
        <p>Bem-vindo @context.User.Identity?.Name</p>
    </Authorized>
    <NotAuthorized>
        <p>Tens que fazer login</p>
    </NotAuthorized>
</AuthorizeView>

@* Páginas com [Authorize] *@
@page "/admin"
@attribute [Authorize(Roles = "Admin")]
```

## XSS em Blazor

Blazor escapa por default em `@variable`. Cuidados:
```razor
@* Escapado *@
<p>@userInput</p>

@* NÃO escapado — perigoso *@
@((MarkupString)userHtml)

@* GOOD com sanitização *@
@((MarkupString)Sanitizer.Sanitize(userHtml))
```

## Common antipatterns (Blazor Server)

### SignalR connection sem auth
- Default: SignalR usa auth do utilizador. Mas custom hubs podem esquecer.

### Long-running connections sem cleanup
- Blazor Server mantém estado por circuit. Memory leak se componentes não dispose.

### Secrets em `appsettings.json` carregado pelo WASM
- WASM faz fetch a `_framework/blazor.boot.json` — qualquer config embedded é pública.

### Auth state cached
- `AuthenticationStateProvider` pode cachear state stale após logout.

### `JSRuntime.InvokeAsync` com input não validado
- JS interop pode ser usado para chamar funções browser arbitrárias.

## Quick wins

- [ ] Blazor WASM **nunca** com secrets
- [ ] Auth via Cookies (Server) ou OIDC (WASM)
- [ ] `[Authorize]` em pages e components privados
- [ ] `<AuthorizeView>` para UI condicional
- [ ] `MarkupString` apenas com HTML sanitizado
- [ ] SignalR hubs com `[Authorize]`
- [ ] Cookies seguros
- [ ] HTTPS forçado
- [ ] CSP definido
- [ ] WASM apps usam API server-side para operações sensíveis
- [ ] Disposal correto de componentes (evita memory leak)
