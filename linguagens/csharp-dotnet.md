# C# / .NET — Cartão de Segurança

## APIs perigosas

| API | Risco |
|---|---|
| `Process.Start(string)` (com input) | Command injection |
| `BinaryFormatter` | Deserialization RCE (deprecated em .NET 5+) |
| `LosFormatter`, `ObjectStateFormatter` | RCE (legacy ASP.NET) |
| `XmlSerializer` (sem `KnownTypes`) | RCE em alguns casos |
| `JavaScriptSerializer` (sem type binder) | RCE |
| `NewtonsoftJson` com `TypeNameHandling.All` | Deserialization RCE |
| `XmlDocument.LoadXml(input)` (sem `XmlResolver = null`) | XXE |
| `Type.GetType(input)` + `Activator.CreateInstance` | RCE |
| `Assembly.Load(bytes)` | RCE |
| `SqlCommand("..."+ input)` | SQLi |
| `WebClient.Download(input)`, `HttpClient.GetAsync(input)` | SSRF |
| `Path.Combine(base, input)` sem check | Path traversal |

## Idiomas inseguros

### `string.Equals` em segurança (timing)
```csharp
// BAD
if (expectedToken == receivedToken) ...

// GOOD — constant-time (System.Security.Cryptography)
if (CryptographicOperations.FixedTimeEquals(expected, received)) ...
```

### `Random` para tokens
```csharp
// BAD
var token = new Random().Next();   // previsível

// GOOD
using var rng = RandomNumberGenerator.Create();
var bytes = new byte[32];
rng.GetBytes(bytes);
var token = Convert.ToHexString(bytes);
```

### Passwords com `SHA256`
```csharp
// BAD
using var sha = SHA256.Create();
var hash = sha.ComputeHash(Encoding.UTF8.GetBytes(password));

// GOOD — usar PasswordHasher (ASP.NET Identity) ou BCrypt.Net
var hasher = new PasswordHasher<User>();
var hash = hasher.HashPassword(user, password);
var result = hasher.VerifyHashedPassword(user, hash, providedPassword);
```

### EF Core `FromSqlRaw` com interpolação
```csharp
// BAD
context.Users.FromSqlRaw($"SELECT * FROM Users WHERE Name = '{name}'");

// GOOD
context.Users.FromSqlRaw("SELECT * FROM Users WHERE Name = {0}", name);
context.Users.FromSqlInterpolated($"SELECT * FROM Users WHERE Name = {name}");  // safe
context.Users.Where(u => u.Name == name);  // melhor
```

### Mass assignment em ASP.NET
```csharp
// BAD — bind direto
[HttpPost]
public IActionResult Update([FromBody] User user) {
    _db.Users.Update(user);
    _db.SaveChanges();
    return Ok();
}

// GOOD — DTO + AutoMapper ou manual mapping
public class UpdateUserDto {
    public string Name { get; set; }
    public string Bio { get; set; }
    // sem Role, Id, etc.
}

[HttpPost]
public async Task<IActionResult> Update([FromBody] UpdateUserDto dto) {
    var user = await _db.Users.FindAsync(currentUserId);
    user.Name = dto.Name;
    user.Bio = dto.Bio;
    await _db.SaveChangesAsync();
    return Ok();
}
```

### `[Authorize]` ausente
```csharp
// BAD
[HttpGet("admin/users")]
public IActionResult AdminUsers() => Ok(_db.Users);

// GOOD
[Authorize(Roles = "Admin")]
[HttpGet("admin/users")]
public IActionResult AdminUsers() => Ok(_db.Users.Select(u => new { u.Id, u.Email }));
```

### CORS `AllowAnyOrigin` + `AllowCredentials`
```csharp
// BAD
app.UseCors(b => b.AllowAnyOrigin().AllowCredentials());

// GOOD
app.UseCors(b => b
    .WithOrigins("https://app.meusite.tld")
    .AllowCredentials()
    .WithMethods("GET", "POST")
    .WithHeaders("Content-Type", "Authorization")
);
```

### `DateTime.Parse` com input não validado
- Pode aceitar formatos inesperados, depender de culture.
- Preferir `DateTime.TryParseExact` com `CultureInfo.InvariantCulture`.

### `Uri` parsing com validação fraca
```csharp
// BAD
var uri = new Uri(userInput);
// permite file://, gopher://, schemes inesperados

// GOOD
if (!Uri.TryCreate(userInput, UriKind.Absolute, out var uri)
    || (uri.Scheme != "http" && uri.Scheme != "https")) {
    return BadRequest();
}
```

## Helpers seguros (stdlib + ASP.NET)

| Necessidade | Use |
|---|---|
| Random | `RandomNumberGenerator.GetBytes(n)` |
| Constant-time compare | `CryptographicOperations.FixedTimeEquals(a, b)` |
| Password hashing | `IPasswordHasher<T>` (Identity), `BCrypt.Net-Next`, `Konscious.Security.Cryptography.Argon2` |
| HMAC | `new HMACSHA256(key)` |
| URL parsing | `Uri.TryCreate` com validation de scheme |
| Path safety | `Path.GetFullPath` + check de `StartsWith(base)` |
| HTML escape | `HtmlEncoder.Default.Encode(s)` (`System.Text.Encodings.Web`) |
| Shell escape | Argumentos como propriedades em `ProcessStartInfo`, não string |
| JWT | `Microsoft.IdentityModel.Tokens` / `System.IdentityModel.Tokens.Jwt` |
| Anti-XSS | Razor faz auto-escape; `@Html.Raw(x)` raramente |
| Anti-CSRF | `[ValidateAntiForgeryToken]`, `IAntiforgery` (default em Razor Pages/MVC) |

## Pitfalls específicos

### `JsonConvert` com `TypeNameHandling.All`
```csharp
// BAD — RCE via $type
var settings = new JsonSerializerSettings {
    TypeNameHandling = TypeNameHandling.All
};
JsonConvert.DeserializeObject(input, settings);

// GOOD
var settings = new JsonSerializerSettings {
    TypeNameHandling = TypeNameHandling.None  // default
};
```

### `BinaryFormatter` deprecated
- `.NET 5+` warns; `.NET 7+` requer opt-in.
- **Substituir por** `System.Text.Json` ou `MessagePack`.

### `ViewState` (Web Forms legacy)
- Sem MAC validation → tampering.
- Sem encryption → leitura.
- Aplicar `ViewStateUserKey` + `enableViewStateMac="true"`.

### `Server.MapPath` com input
```csharp
// BAD
var path = Server.MapPath("~/uploads/" + filename);  // path traversal

// GOOD
var safe = Path.GetFileName(filename);  // remove path components
var full = Path.Combine(uploadsDir, safe);
```

## Bibliotecas comuns com vulns

- **Newtonsoft.Json** com `TypeNameHandling != None` → deserialization
- **System.Text.Json** com `[JsonConverter]` custom mal escrito
- **EF < 6.x** → SQLi em alguns casos
- **ASP.NET Web Forms** → ViewState/EventValidation issues legacy
- **NLog**, **Serilog** — verificar se sinks externos têm input não sanitizado

## Quick wins

- [ ] .NET 8 LTS ou superior
- [ ] `dotnet list package --vulnerable` sem Críticos
- [ ] `IPasswordHasher` ou BCrypt para passwords
- [ ] `RandomNumberGenerator` para tokens
- [ ] `CryptographicOperations.FixedTimeEquals` em comparações
- [ ] DTOs por endpoint (sem expor entidades EF)
- [ ] `[Authorize]` em todos os endpoints sensíveis
- [ ] CORS com `WithOrigins` específicos
- [ ] CSRF (`[ValidateAntiForgeryToken]`) em forms
- [ ] HTTPS forçado (`UseHttpsRedirection`, HSTS)
- [ ] Sem `BinaryFormatter`, `LosFormatter`, `JavaScriptSerializer`
- [ ] EF Core com queries parametrizadas (não `FromSqlRaw` com interpolação)
- [ ] `XmlReaderSettings.DtdProcessing = Prohibit` em XML parsing
