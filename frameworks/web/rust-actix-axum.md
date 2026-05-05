# Rust Web (Actix, Axum, Rocket) — Profile de Segurança

## Deteção
- `Cargo.toml` com `actix-web`, `axum`, `rocket`, `warp`, `tide`

## Axum — setup mínimo seguro

```rust
use axum::{Router, middleware, Extension};
use tower_http::{cors::CorsLayer, trace::TraceLayer, limit::RequestBodyLimitLayer};
use std::time::Duration;

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/api/users", get(list_users).post(create_user))
        .layer(middleware::from_fn(auth_middleware))
        .layer(RequestBodyLimitLayer::new(1024 * 1024))  // 1MB
        .layer(CorsLayer::new()
            .allow_origin("https://app.meusite.tld".parse::<HeaderValue>().unwrap())
            .allow_credentials(true)
            .allow_methods(["GET", "POST", "PUT", "DELETE"])
            .allow_headers(["Authorization", "Content-Type"]))
        .layer(TraceLayer::new_for_http())
        .layer(Extension(db_pool))
        .into_make_service();

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
}
```

## Validation — validator + serde

```rust
use serde::Deserialize;
use validator::Validate;

#[derive(Deserialize, Validate)]
#[serde(deny_unknown_fields)]
struct CreateUser {
    #[validate(length(min = 1, max = 100))]
    name: String,
    #[validate(email)]
    email: String,
}

async fn create_user(Json(payload): Json<CreateUser>) -> Result<Json<User>, AppError> {
    payload.validate().map_err(|e| AppError::Validation(e.to_string()))?;
    // ...
}
```

## Auth — JWT (jsonwebtoken)

```rust
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation, Algorithm};

#[derive(Serialize, Deserialize)]
struct Claims {
    sub: String,
    iss: String,
    aud: String,
    exp: usize,
}

async fn auth_middleware(req: Request, next: Next) -> Result<Response, StatusCode> {
    let token = req.headers().get("Authorization")
        .and_then(|h| h.to_str().ok())
        .and_then(|h| h.strip_prefix("Bearer "))
        .ok_or(StatusCode::UNAUTHORIZED)?;

    let mut validation = Validation::new(Algorithm::HS256);
    validation.set_issuer(&["meusite.tld"]);
    validation.set_audience(&["meusite.tld"]);

    let token_data = decode::<Claims>(token, &DecodingKey::from_secret(SECRET), &validation)
        .map_err(|_| StatusCode::UNAUTHORIZED)?;

    let mut req = req;
    req.extensions_mut().insert(token_data.claims);
    Ok(next.run(req).await)
}
```

## SQL — sqlx (compile-time check)

```rust
// BAD
sqlx::query(&format!("SELECT * FROM users WHERE id = {}", id))

// GOOD — macro valida em compile time
let user = sqlx::query_as!(User,
    "SELECT id, name, email FROM users WHERE id = $1", id
).fetch_one(&pool).await?;
```

## Actix-web equivalente

```rust
use actix_web::{web, App, HttpServer, middleware as mw};
use actix_cors::Cors;

HttpServer::new(|| {
    App::new()
        .wrap(mw::DefaultHeaders::new()
            .add(("Strict-Transport-Security", "max-age=31536000; includeSubDomains"))
            .add(("X-Content-Type-Options", "nosniff"))
            .add(("X-Frame-Options", "SAMEORIGIN"))
            .add(("Content-Security-Policy", "default-src 'self'")))
        .wrap(Cors::default()
            .allowed_origin("https://app.meusite.tld")
            .allowed_methods(vec!["GET", "POST"]))
        .wrap(mw::Compress::default())
        .app_data(web::JsonConfig::default().limit(1024 * 1024))
        .service(/* routes */)
})
.bind("0.0.0.0:8080")?
.run()
.await
```

## Common antipatterns

### `unwrap()` em handlers
```rust
// BAD — panic crash o worker
async fn handler(Path(id): Path<i32>) -> Json<User> {
    let user = db.find(id).await.unwrap();
    Json(user)
}

// GOOD — Result
async fn handler(Path(id): Path<i32>) -> Result<Json<User>, AppError> {
    let user = db.find(id).await?;
    Ok(Json(user))
}
```

### `Json<UserStruct>` direto sem `deny_unknown_fields`
- Mass assignment via campos extra.

### Sem timeouts em HTTP client / DB
- Já coberto em `linguagens/rust.md`.

### `tracing` com `body` completo
- Logs com PII / secrets.

### `axum::response::Json<serde_json::Value>` genérico
- Sem schema, qualquer coisa passa.

### Auth middleware aplicado depois das routes
- Order matters em layers Tower.

## Quick wins

- [ ] Rust stable recente (edition 2021+)
- [ ] `cargo audit` sem Críticos
- [ ] Sem `unwrap()`/`expect()` em handlers — usar `Result + ?`
- [ ] `#[serde(deny_unknown_fields)]` em DTOs de input
- [ ] `validator` derive em DTOs
- [ ] sqlx macros (`query!`, `query_as!`) para compile-time check
- [ ] Auth middleware aplicado a routes privadas
- [ ] Body limit explícito
- [ ] CORS com origins específicos
- [ ] Headers de segurança via middleware
- [ ] JWT com alg explícito + iss/aud/exp validados
- [ ] `argon2`/`bcrypt` para passwords
- [ ] `getrandom`/`OsRng` para tokens
- [ ] Timeouts em HTTP clients e DB
- [ ] Tracing sem body / sem Authorization headers
- [ ] Graceful shutdown configurado
