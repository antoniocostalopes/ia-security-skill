# Rust — Cartão de Segurança

> Rust elimina classes inteiras de bugs (UAF, double-free, data races) por design. Mas há áreas onde ainda precisas de cuidado: `unsafe`, deserialização, dependencies, e logic bugs (que Rust não evita).

## APIs perigosas

| API | Risco |
|---|---|
| `unsafe { ... }` blocks | Memory safety bypass — auditar cada uso |
| `std::process::Command` com input | Command injection |
| `serde` deserialization de input não confiável (sem schema) | DoS / RCE em alguns serializers |
| `format!` com pattern controlled | Format injection (raro) |
| `mem::transmute` | Type confusion |
| `Box::leak`, `Box::from_raw` | Memory leaks / UB |
| `std::fs::read(path)` com input | Path traversal |
| `reqwest::get(url)` com input | SSRF |
| `.unwrap()`, `.expect()` em handlers HTTP | DoS via panic |
| `#[derive(Deserialize)]` sem `#[serde(deny_unknown_fields)]` | Mass assignment |

## Idiomas inseguros

### `unwrap()` em código de produção
```rust
// BAD
let user = db.find(id).unwrap();  // panic se None
let value = parse_int(input).unwrap();  // panic se mal formatado

// GOOD
let user = db.find(id).ok_or(Error::NotFound)?;
let value = parse_int(input).map_err(|_| Error::BadRequest)?;
```

### `Command::new` com `sh -c`
```rust
// BAD
Command::new("sh").arg("-c").arg(format!("ping {}", host)).output();

// GOOD
Command::new("ping").arg("-c").arg("1").arg(host).output();
```

### `format!` em SQL
```rust
// BAD
sqlx::query(&format!("SELECT * FROM users WHERE id = {}", id))

// GOOD — sqlx macros (compile-time check!)
sqlx::query!("SELECT * FROM users WHERE id = $1", id)
    .fetch_one(&pool).await?;
```

### `unsafe` impl
```rust
// Auditar cada `unsafe`:
unsafe fn dangerous(ptr: *mut u8) {
    *ptr = 0;  // ← UB se ptr inválido
}

// Cada `unsafe` deve ter:
// SAFETY: <invariante que justifica este uso>
```

### Deserialização sem `deny_unknown_fields`
```rust
// BAD — campos extra silenciosamente ignorados
#[derive(Deserialize)]
struct UpdateUser {
    name: String,
    bio: String,
}
// Atacante: { "name": "x", "bio": "y", "role": "admin" } — `role` ignorado mas...
// se mais tarde adicionas `role` como field opcional, atacante já estava a passar

// GOOD
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct UpdateUser { ... }
```

### Comparação de tokens (timing)
```rust
// BAD
if expected == received { ... }

// GOOD — subtle crate
use subtle::ConstantTimeEq;
if expected.ct_eq(received).into() { ... }
```

### Random para tokens
```rust
// BAD — fastrand, rand::thread_rng com `next_u32`
use rand::Rng;
let token: u32 = rand::thread_rng().gen();

// GOOD — getrandom (CSPRNG)
use rand::rngs::OsRng;
use rand::RngCore;
let mut bytes = [0u8; 32];
OsRng.fill_bytes(&mut bytes);
let token = hex::encode(bytes);
```

### Passwords
```rust
// BAD — sha256 não é password hash
use sha2::{Sha256, Digest};
let hash = Sha256::digest(password.as_bytes());

// GOOD — argon2 ou bcrypt
use argon2::{password_hash::SaltString, Argon2, PasswordHasher};
let salt = SaltString::generate(&mut OsRng);
let hash = Argon2::default().hash_password(password.as_bytes(), &salt)?.to_string();
```

### Path traversal
```rust
// BAD
let full = base.join(user_input);

// GOOD
use std::path::PathBuf;
let mut full = base.to_path_buf();
let safe = PathBuf::from(user_input);
for component in safe.components() {
    if matches!(component, std::path::Component::ParentDir) {
        return Err(Error::PathTraversal);
    }
    full.push(component);
}
let canonical = full.canonicalize()?;
if !canonical.starts_with(base) {
    return Err(Error::PathTraversal);
}
```

### `panic!` em handlers
```rust
// BAD — actix-web handler com panic
async fn handler() -> Result<HttpResponse> {
    let x = something().unwrap();  // panic crash o worker thread
    Ok(HttpResponse::Ok().finish())
}

// GOOD — Result + ? operator
async fn handler() -> Result<HttpResponse, Error> {
    let x = something()?;
    Ok(HttpResponse::Ok().finish())
}
```

### HTTP client sem timeout
```rust
// BAD
let client = reqwest::Client::new();

// GOOD
let client = reqwest::Client::builder()
    .timeout(std::time::Duration::from_secs(10))
    .connect_timeout(std::time::Duration::from_secs(3))
    .redirect(reqwest::redirect::Policy::limited(3))
    .build()?;
```

## Helpers seguros (crates comuns)

| Necessidade | Crate |
|---|---|
| Random | `getrandom`, `rand` com `OsRng` |
| Constant-time compare | `subtle` |
| Password hashing | `argon2`, `bcrypt`, `scrypt` |
| HMAC | `hmac` (com `sha2`) |
| URL parsing | `url::Url` |
| Path safety | `std::path` + `canonicalize()` + check |
| HTML escape | `askama_escape`, `v_htmlescape`, ou framework template engine |
| JWT | `jsonwebtoken` |
| HTTP client | `reqwest` (com timeouts!) |
| Validation | `validator` derive |
| SQL | `sqlx` (compile-time check de queries), `diesel` (type-safe ORM) |
| Crypto primitives | `RustCrypto` (`aes-gcm`, `chacha20poly1305`, `sha2`) |

## Pitfalls específicos

### `cargo audit` deve correr
```bash
cargo install cargo-audit
cargo audit
```

### Dependencies em `Cargo.toml`
- `*` ou `latest` → não pinned. Sempre versões específicas ou caret (`"^1.2.3"`).

### `Send`/`Sync` violations
- Compilador apanha, mas se usares `unsafe impl Send`, podes introduzir data race.

### `serde_json` com tipos genéricos
```rust
// BAD — aceita qualquer JSON
let v: serde_json::Value = serde_json::from_str(input)?;
// processa sem schema

// GOOD — struct específica + validation
#[derive(Deserialize, Validate)]
#[serde(deny_unknown_fields)]
struct UserInput {
    #[validate(email)]
    email: String,
    #[validate(length(min = 1, max = 100))]
    name: String,
}
let user: UserInput = serde_json::from_str(input)?;
user.validate()?;
```

### `dbg!` deixado em produção
- `dbg!(x)` imprime para stderr. Em prod, leakea info nos logs.

### `tokio` task spawn sem join
- Tasks órfãs continuam a correr — possível leak.

## Bibliotecas comuns com vulns

- **`time` < 0.2.23** → segfault
- **`smallvec` < 1.6.1** → buffer overflow
- **`actix-web`** — verificar versão (várias CVEs históricas em pre-1.0)
- **`tokio`** — manter atualizado

## Quick wins

- [ ] Edition 2021+, rustc estável recente
- [ ] `cargo audit` na CI sem Críticos
- [ ] `cargo clippy -- -D warnings` na CI
- [ ] Cada `unsafe` com comentário `// SAFETY:`
- [ ] Sem `unwrap`/`expect` em handlers HTTP — usar `?`
- [ ] `argon2`/`bcrypt` para passwords (não `sha256`)
- [ ] `getrandom`/`OsRng` para tokens
- [ ] `subtle::ConstantTimeEq` em comparações de segurança
- [ ] `#[serde(deny_unknown_fields)]` em DTOs de input
- [ ] `validator` ou similar em DTOs
- [ ] `sqlx::query!` macros (compile-time check)
- [ ] Timeouts em `reqwest::Client`
