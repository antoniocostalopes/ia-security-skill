# Go Web Frameworks (Gin, Echo, Fiber, stdlib) — Profile de Segurança

## Deteção
- `go.mod` com `github.com/gin-gonic/gin`, `github.com/labstack/echo`, `github.com/gofiber/fiber`
- `import "net/http"` (stdlib)

## Setup mínimo seguro (Gin)

```go
package main

import (
    "github.com/gin-gonic/gin"
    "github.com/gin-contrib/secure"
    "github.com/gin-contrib/cors"
    "github.com/ulule/limiter/v3"
    "time"
)

func main() {
    r := gin.Default()
    r.SetTrustedProxies([]string{"10.0.0.0/8"})  // se atrás de LB

    // Security headers
    r.Use(secure.New(secure.Config{
        SSLRedirect:           true,
        STSSeconds:            31536000,
        STSIncludeSubdomains:  true,
        STSPreload:            true,
        FrameDeny:             true,
        ContentTypeNosniff:    true,
        BrowserXssFilter:      true,
        ReferrerPolicy:        "strict-origin-when-cross-origin",
        ContentSecurityPolicy: "default-src 'self'",
    }))

    // CORS
    r.Use(cors.New(cors.Config{
        AllowOrigins:     []string{"https://app.meusite.tld"},
        AllowMethods:     []string{"GET", "POST", "PUT", "DELETE"},
        AllowHeaders:     []string{"Authorization", "Content-Type"},
        AllowCredentials: true,
        MaxAge:           12 * time.Hour,
    }))

    // Rate limit
    rate, _ := limiter.NewRateFromFormatted("100-M")
    store := /* memory ou redis store */
    instance := limiter.New(store, rate)
    r.Use(/* middleware do limiter */)

    // Auth middleware
    auth := r.Group("/")
    auth.Use(AuthMiddleware())
    auth.GET("/profile", profileHandler)

    // Server with timeouts
    srv := &http.Server{
        Addr:              ":8080",
        Handler:           r,
        ReadHeaderTimeout: 5 * time.Second,
        ReadTimeout:       10 * time.Second,
        WriteTimeout:      10 * time.Second,
        IdleTimeout:       60 * time.Second,
    }
    srv.ListenAndServe()
}
```

## Auth — JWT (golang-jwt)

```go
import "github.com/golang-jwt/jwt/v5"

type Claims struct {
    UserID int    `json:"user_id"`
    Role   string `json:"role"`
    jwt.RegisteredClaims
}

func AuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        tokenStr := strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer ")
        token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
            if t.Method != jwt.SigningMethodHS256 {  // alg explícito!
                return nil, errors.New("bad alg")
            }
            return []byte(jwtSecret), nil
        })
        if err != nil || !token.Valid {
            c.AbortWithStatusJSON(401, gin.H{"error": "unauthorized"})
            return
        }
        claims := token.Claims.(*Claims)
        if claims.Issuer != "meusite.tld" {
            c.AbortWithStatusJSON(401, gin.H{"error": "bad iss"})
            return
        }
        c.Set("userID", claims.UserID)
        c.Set("role", claims.Role)
        c.Next()
    }
}
```

## Validation — go-playground/validator

```go
type CreateUserDto struct {
    Name  string `json:"name" binding:"required,min=1,max=100"`
    Email string `json:"email" binding:"required,email"`
}

func createUser(c *gin.Context) {
    var dto CreateUserDto
    if err := c.ShouldBindJSON(&dto); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }
    // dto validado
}
```

## ORM (GORM / sqlx / sqlc)

Coberto em `analises/query-builders-orm.md` e `linguagens/go.md`.

## Echo equivalente

```go
import "github.com/labstack/echo/v4"
import "github.com/labstack/echo/v4/middleware"

e := echo.New()
e.Use(middleware.Secure())
e.Use(middleware.Recover())
e.Use(middleware.RateLimiter(middleware.NewRateLimiterMemoryStore(100)))
e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
    AllowOrigins: []string{"https://app.meusite.tld"},
    AllowCredentials: true,
}))
```

## Fiber

```go
import "github.com/gofiber/fiber/v2"
import "github.com/gofiber/fiber/v2/middleware/helmet"
import "github.com/gofiber/fiber/v2/middleware/limiter"
import "github.com/gofiber/fiber/v2/middleware/cors"

app := fiber.New(fiber.Config{
    BodyLimit:    1 * 1024 * 1024,  // 1MB
    ReadTimeout:  10 * time.Second,
    WriteTimeout: 10 * time.Second,
})
app.Use(helmet.New())
app.Use(limiter.New(limiter.Config{Max: 100}))
app.Use(cors.New(cors.Config{AllowOrigins: "https://app.meusite.tld"}))
```

## stdlib `net/http`

```go
mux := http.NewServeMux()
mux.HandleFunc("/api/users", authMiddleware(usersHandler))

srv := &http.Server{
    Addr:              ":8080",
    Handler:           mux,
    ReadHeaderTimeout: 5 * time.Second,
    ReadTimeout:       10 * time.Second,
    WriteTimeout:      10 * time.Second,
    IdleTimeout:       60 * time.Second,
    MaxHeaderBytes:    1 << 14,  // 16KB
}
srv.ListenAndServe()
```

## Common antipatterns

### `gin.Default()` em prod
- Logger e Recovery middleware ativos. OK por default mas verificar:
- Logger pode logar PII em request body.

### `c.Bind` sem `binding` tags
- Sem validation.

### `c.JSON(http.StatusOK, user)` com user inteiro
- Expõe campos sensíveis. Usar DTO.

### Sem timeouts no `http.Server`
- Vulnerable to Slowloris.

### `ShouldBind` que aceita query string + body misturados
- Mass assignment via query.

### Middleware order errado
- Auth depois de routes sensíveis.

### `gin.H{"error": err.Error()}` direto
- Vaza interno. Logar internamente, devolver mensagem genérica.

### `r.Run(":8080")` sem TLS
- Apenas para dev. Produção atrás de reverse proxy ou `RunTLS`.

## Quick wins

- [ ] Go 1.21+
- [ ] `govulncheck` na CI
- [ ] Server com timeouts explícitos
- [ ] `SetTrustedProxies` configurado se atrás de LB
- [ ] Auth middleware aplicado a routes privadas
- [ ] DTOs com `binding` tags
- [ ] DTOs separados de structs DB (sem `Password string`)
- [ ] CORS com origins específicos
- [ ] Rate limit
- [ ] Headers de segurança (helmet/secure)
- [ ] HTTPS via reverse proxy ou `RunTLS`
- [ ] JWT com alg explícito + verify exp/iss/aud
- [ ] BCrypt para passwords
- [ ] `crypto/subtle.ConstantTimeCompare` em segurança
- [ ] Logging sem PII
- [ ] Errors handler que não vaza interno
- [ ] `database/sql` ou ORM com queries parametrizadas
