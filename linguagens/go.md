# Go — Cartão de Segurança

## APIs perigosas

| API | Risco |
|---|---|
| `os/exec.Command("sh", "-c", input)` | Command injection |
| `text/template` (sem escape em HTML context) | XSS — usar `html/template` |
| `encoding/gob` com input não confiável | Deserialization (limitado) |
| `database/sql` com `fmt.Sprintf` | SQLi |
| `net/http.Get(userURL)` | SSRF |
| `os.Open(userPath)`, `os.ReadFile(userPath)` | Path traversal |
| `archive/zip.Reader` sem size check | Zip bomb |
| `net/http` server sem timeouts default | DoS |
| `unsafe` package (em geral) | Memory safety |
| `reflect` com input | Bypass de type system |

## Idiomas inseguros

### `text/template` em vez de `html/template`
```go
// BAD — text/template não escapa HTML
import "text/template"
t, _ := template.New("x").Parse("<h1>{{.Name}}</h1>")
t.Execute(w, struct{ Name string }{userInput})

// GOOD
import "html/template"
t, _ := template.New("x").Parse("<h1>{{.Name}}</h1>")
t.Execute(w, struct{ Name string }{userInput})
// .Name é escapado no contexto HTML
```

### `fmt.Sprintf` em SQL
```go
// BAD
db.Query(fmt.Sprintf("SELECT * FROM users WHERE id = %d", id))

// GOOD
db.Query("SELECT * FROM users WHERE id = $1", id)  // postgres
db.Query("SELECT * FROM users WHERE id = ?", id)   // mysql
```

### `exec.Command("sh", "-c", ...)`
```go
// BAD
exec.Command("sh", "-c", "ping " + host).Run()

// GOOD
exec.Command("ping", "-c", "1", host).Run()
```

### HTTP server sem timeouts
```go
// BAD — vulnerable a Slowloris
http.ListenAndServe(":8080", handler)

// GOOD
srv := &http.Server{
    Addr:              ":8080",
    Handler:           handler,
    ReadHeaderTimeout: 5 * time.Second,
    ReadTimeout:       10 * time.Second,
    WriteTimeout:      10 * time.Second,
    IdleTimeout:       60 * time.Second,
}
srv.ListenAndServe()
```

### HTTP client sem timeout
```go
// BAD
http.Get(url)  // pode ficar pendurado para sempre

// GOOD
client := &http.Client{Timeout: 10 * time.Second}
client.Get(url)
```

### `crypto/rand` vs `math/rand`
```go
// BAD — math/rand é previsível
import "math/rand"
token := rand.Int63()

// GOOD
import "crypto/rand"
b := make([]byte, 32)
rand.Read(b)
token := hex.EncodeToString(b)
```

### Comparação de tokens (timing)
```go
// BAD
if expected == received { ... }

// GOOD
import "crypto/subtle"
if subtle.ConstantTimeCompare([]byte(expected), []byte(received)) == 1 { ... }
```

### Path traversal
```go
// BAD
http.ServeFile(w, r, r.URL.Query().Get("file"))

// GOOD
base, _ := filepath.Abs("/var/data")
target, err := filepath.Abs(filepath.Join(base, r.URL.Query().Get("file")))
if err != nil || !strings.HasPrefix(target, base+string(filepath.Separator)) {
    http.Error(w, "forbidden", 403)
    return
}
http.ServeFile(w, r, target)
```

### Goroutine leaks com context
```go
// BAD — goroutine sem cancelamento
go longRunningTask()

// GOOD
ctx, cancel := context.WithTimeout(req.Context(), 5*time.Second)
defer cancel()
go func() {
    select {
    case <-ctx.Done():
        return
    case result := <-doWork(ctx):
        // ...
    }
}()
```

### SQL `database/sql` com `Scan` + nullable
- Cuidar com `sql.NullString`/`NullInt64` — passar para JSON pode expor estrutura interna.

### JSON tags expondo demais
```go
// BAD — json:"role" expõe via API
type User struct {
    ID       int    `json:"id"`
    Email    string `json:"email"`
    Password string `json:"password"`  // !!
    Role     string `json:"role"`
}

// GOOD — separar DTO
type UserDTO struct {
    ID    int    `json:"id"`
    Email string `json:"email"`
}
```

## Helpers seguros (stdlib + popular libs)

| Necessidade | Use |
|---|---|
| Random | `crypto/rand` |
| Constant-time compare | `crypto/subtle.ConstantTimeCompare` |
| Password hashing | `golang.org/x/crypto/bcrypt`, `golang.org/x/crypto/argon2` |
| HMAC | `crypto/hmac` |
| URL parsing | `net/url.Parse` + validation de scheme |
| Path safety | `filepath.Abs` + `strings.HasPrefix(target, base)` |
| HTML escape | `html/template` (auto), ou `html.EscapeString` |
| Shell escape | Lista de args em `exec.Command` |
| JWT | `github.com/golang-jwt/jwt/v5` |
| HTTP client | `net/http` com `Client{Timeout}` ou `httptrace` |
| Validation | `github.com/go-playground/validator/v10` |
| ORM | `gorm`, `sqlx`, `sqlc` (preferir `sqlc` por type safety) |

## Pitfalls específicos

### `html/template` com `template.HTML`
```go
// BAD — template.HTML é "trust me" — XSS se input é controlado
t.Execute(w, template.HTML(userInput))

// GOOD — só usar template.HTML para HTML que CRIASTE, não input
```

### `regexp` em Go é seguro a ReDoS
- Go usa RE2 — sem backtracking. Imune a ReDoS.

### `sync.Map` vs map+mutex
- Race conditions silenciosas se acederes a `map` sem lock.
- `go run -race` em testes para detetar.

### `defer` em loops
```go
// BAD — N files abertos antes de close
for _, file := range files {
    f, _ := os.Open(file)
    defer f.Close()  // só fecha quando função retorna
}

// GOOD
for _, file := range files {
    func() {
        f, _ := os.Open(file)
        defer f.Close()
        // ...
    }()
}
```

### `context.Background()` vs request context
- Em handlers, usar `r.Context()` para que cancelamentos propaguem.

## Bibliotecas comuns com vulns

- **`golang.org/x/crypto`** — manter atualizado
- **`gin-gonic/gin`** — várias CVEs históricas, atualizar
- **`gorilla/websocket`** — atualizar
- **`net/http`** stdlib — sempre Go atualizado
- **`gorm`** — verificar SQLi em métodos `Raw`

## Quick wins

- [ ] Go 1.21+ (versões antigas EOL)
- [ ] `govulncheck` na CI
- [ ] `crypto/rand` para tokens (não `math/rand`)
- [ ] `crypto/subtle.ConstantTimeCompare` em segurança
- [ ] `bcrypt`/`argon2` para passwords
- [ ] HTTP server com timeouts explícitos
- [ ] HTTP client com `Timeout` explícito
- [ ] `html/template` em handlers HTML
- [ ] `database/sql` com placeholders (`$1`, `?`), nunca `Sprintf`
- [ ] `exec.Command` com lista de args, não `sh -c`
- [ ] `go run -race` em CI para detetar races
- [ ] DTOs separados das structs internas (não expor `password`)
