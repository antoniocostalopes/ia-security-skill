# ASP.NET Core — Profile de Segurança

## Deteção
- `.csproj` com `Microsoft.AspNetCore.App`
- `Program.cs` / `Startup.cs`
- `appsettings.json`

## Program.cs — setup mínimo seguro

```csharp
var builder = WebApplication.CreateBuilder(args);

// HTTPS
builder.Services.AddHttpsRedirection(opt => opt.HttpsPort = 443);
builder.Services.AddHsts(opt => {
    opt.Preload = true;
    opt.IncludeSubDomains = true;
    opt.MaxAge = TimeSpan.FromDays(365);
});

// Auth
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt => {
        opt.TokenValidationParameters = new() {
            ValidateIssuer = true, ValidIssuer = "meusite.tld",
            ValidateAudience = true, ValidAudience = "meusite.tld",
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
        };
    });

builder.Services.AddAuthorization(options => {
    options.AddPolicy("AdminOnly", p => p.RequireRole("Admin"));
});

// CORS
builder.Services.AddCors(opt => opt.AddPolicy("default",
    p => p.WithOrigins("https://app.meusite.tld")
          .WithMethods("GET", "POST", "PUT", "DELETE")
          .WithHeaders("Authorization", "Content-Type")
          .AllowCredentials()));

// Rate limit (.NET 7+)
builder.Services.AddRateLimiter(opt => {
    opt.AddFixedWindowLimiter("api", o => {
        o.PermitLimit = 100;
        o.Window = TimeSpan.FromMinutes(1);
    });
});

// Anti-forgery (CSRF)
builder.Services.AddAntiforgery(o => o.HeaderName = "X-XSRF-TOKEN");

var app = builder.Build();

app.UseHttpsRedirection();
app.UseHsts();
app.UseCors("default");
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

// Headers via middleware
app.Use(async (ctx, next) => {
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    ctx.Response.Headers["X-Frame-Options"] = "SAMEORIGIN";
    ctx.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    ctx.Response.Headers["Permissions-Policy"] = "geolocation=(), microphone=()";
    ctx.Response.Headers["Content-Security-Policy"] = "default-src 'self'";
    await next();
});

app.MapControllers().RequireRateLimiting("api");
app.Run();
```

## Authorization

```csharp
[ApiController]
[Route("api/[controller]")]
[Authorize]  // todo o controller exige auth
public class UsersController : ControllerBase {

    [HttpGet]
    [Authorize(Policy = "AdminOnly")]
    public ActionResult<IEnumerable<UserDto>> List() { ... }

    [HttpGet("{id}")]
    public async Task<ActionResult<UserDto>> Get(int id) {
        var user = await db.Users.FindAsync(id);
        if (user == null) return NotFound();

        // Ownership check
        if (user.Id != GetCurrentUserId() && !User.IsInRole("Admin"))
            return Forbid();

        return UserDto.From(user);
    }
}
```

## DTOs — anti mass assignment

```csharp
// BAD
[HttpPost]
public async Task<ActionResult<User>> Create([FromBody] User user) { ... }

// GOOD
public record CreateUserDto(
    [Required, StringLength(100)] string Name,
    [Required, EmailAddress] string Email
);

[HttpPost]
public async Task<ActionResult<UserDto>> Create([FromBody] CreateUserDto dto) {
    if (!ModelState.IsValid) return BadRequest(ModelState);
    var user = new User { Name = dto.Name, Email = dto.Email };
    db.Users.Add(user);
    await db.SaveChangesAsync();
    return UserDto.From(user);
}
```

## EF Core queries

Coberto em `linguagens/csharp-dotnet.md`.

## Common antipatterns

### `[AllowAnonymous]` esquecido em controller que devia ser autenticado
```csharp
// BAD — controller inteiro public
public class UsersController : ControllerBase { }

// Esquecimento de [Authorize]
```

### `app.UseDeveloperExceptionPage()` em produção
- Stack traces.

### `app.UseRouting()` antes de `app.UseAuthentication()`
- Order matters.

### Antiforgery token desativado em forms
- CSRF aberto.

### `IConfiguration["ConnectionString"]` sem encriptação
- Production usar Azure Key Vault, AWS Secrets Manager, etc.

### Identity sem password policy
- Default é fraco. Configurar:
```csharp
services.Configure<IdentityOptions>(opt => {
    opt.Password.RequiredLength = 12;
    opt.Password.RequireDigit = true;
    opt.Password.RequireUppercase = true;
    opt.Lockout.MaxFailedAccessAttempts = 5;
    opt.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
});
```

### CORS com `AllowAnyOrigin` + cookies
- Browser bloqueia mas é red flag.

### Swagger UI em produção
```csharp
if (app.Environment.IsDevelopment()) {
    app.UseSwagger();
    app.UseSwaggerUI();
}
```

## Quick wins

- [ ] .NET 8 LTS
- [ ] `dotnet list package --vulnerable` sem Críticos
- [ ] HTTPS forçado + HSTS
- [ ] Auth scheme configurado (JWT/Cookies/Identity)
- [ ] `[Authorize]` no controller, `[AllowAnonymous]` apenas onde explícito
- [ ] DTOs separados de Entities
- [ ] `[Required]`, `[StringLength]`, `[EmailAddress]` em DTOs
- [ ] EF Core com queries parametrizadas
- [ ] CSRF (`AddAntiforgery`) em forms
- [ ] CORS com origins específicos
- [ ] Rate limiter ativo
- [ ] Headers de segurança
- [ ] Identity com password policy strong + lockout
- [ ] Swagger off em production
- [ ] Secrets via env / Key Vault
- [ ] `UseDeveloperExceptionPage` apenas em Development
- [ ] Logging com Serilog / NLog sem PII
