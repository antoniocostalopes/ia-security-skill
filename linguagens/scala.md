# Scala — Cartão de Segurança

> Scala corre na JVM. Tudo em `java.md` aplica-se. Este cartão cobre o **delta Scala** + frameworks comuns (Play, Akka, http4s).

## Idiomas inseguros

### `.get` em `Option`
```scala
// BAD
val user = users.headOption.get  // throws se None

// GOOD
val user = users.headOption.getOrElse(throw NotFoundException())
// ou
users.headOption match {
  case Some(u) => u
  case None    => throw NotFoundException()
}
```

### `.get` em `Try`
```scala
// BAD
val result = Try(parseInt(input)).get

// GOOD
Try(parseInt(input)) match {
  case Success(n) => n
  case Failure(e) => throw BadRequest(e.getMessage)
}
```

### `.asInstanceOf`
```scala
// BAD
val user = obj.asInstanceOf[User]  // ClassCastException

// GOOD
obj match {
  case u: User => u
  case _       => throw InvalidType()
}
```

### Implicits que mudam comportamento
- Implicits podem fazer pickup silencioso de conversores inseguros (ex.: implicit conversion de `String` para `URL` que aceita schemes maus).
- Auditar `implicit def` em scope.

### `Future` sem ExecutionContext explícito
- Pode usar `global` por default → starvation se task longa.
- Sempre passar `ExecutionContext` apropriado.

### Macros
- Macros executam **em compile time**. Macro mal-intencionada num pacote pode RCE durante build.
- Auditar dependências macro-heavy.

## Helpers seguros (stdlib + Scala libs)

| Necessidade | Use |
|---|---|
| Random | `scala.util.Random.nextBytes` ou `java.security.SecureRandom` |
| Constant-time | `MessageDigest.isEqual` (Java) |
| Password | `BCrypt`, `Argon2` (Java libs) |
| HTTP | `sttp`, `http4s`, `akka-http` (com timeouts!) |
| JSON | `circe`, `json4s` (Circe é mais type-safe) |
| Validation | `cats-data Validated`, `refined` (refined types) |
| ORM | `Slick` (type-safe), `Quill`, `Doobie` |

## Pitfalls específicos

### Play Framework — CSRF
- Play tem `CSRFFilter` por default. Confirmar não desativado.
- `play.filters.disabled += "play.filters.csrf.CSRFFilter"` é red flag.

### Play — `request.body.asJson`
```scala
// BAD — sem schema, tudo passa
def update = Action(parse.json) { request =>
  val name = (request.body \ "name").as[String]  // throws se ausente
  val role = (request.body \ "role").asOpt[String]  // mass assignment se aceitas
  ...
}

// GOOD — case class + Reads
case class UpdateUser(name: String, bio: Option[String])
implicit val reads: Reads[UpdateUser] = Json.reads[UpdateUser]

def update = Action(parse.json[UpdateUser]) { request =>
  val data = request.body
  // só name e bio passam — role nem aparece
}
```

### Akka HTTP — extração sem validação
```scala
// BAD
path("users" / IntNumber) { id =>
  complete(getUser(id))  // sem auth check
}

// GOOD
path("users" / IntNumber) { id =>
  authenticateOAuth2("realm", authenticator) { user =>
    if (user.canAccess(id)) complete(getUser(id))
    else complete(StatusCodes.Forbidden)
  }
}
```

### Slick raw queries
```scala
// BAD
sql"""SELECT * FROM users WHERE name = '#$name'""".as[User]

// GOOD — interpolação $ em vez de #$ é safe (parametriza)
sql"""SELECT * FROM users WHERE name = $name""".as[User]
```

### Implicits para auth
```scala
// BAD — confiar que implicit User está sempre presente
def adminAction(implicit user: User) = {
  if (user.isAdmin) doStuff()
}

// GOOD — explicit + check no router
```

## Bibliotecas comuns

- **Play Framework** — manter LTS atualizado
- **Akka** — verificar licença Akka >= 2.7 (BSL agora)
- **Cats** / **ZIO** — type-safe, encorajadas
- **Circe** — JSON type-safe
- **Refined** — refined types para validação compile-time

## Quick wins

- [ ] Scala 3.x ou Scala 2.13.x mais recente
- [ ] `sbt-dependency-check` (OWASP) na CI
- [ ] Sem `.get` em `Option`/`Try`/`Either` — usar pattern matching
- [ ] Sem `.asInstanceOf` — usar pattern matching
- [ ] Implicits explicitamente documentados
- [ ] Case classes para DTOs (sem mass assignment)
- [ ] `circe` ou `Json.reads[T]` para parse JSON
- [ ] `ExecutionContext` explícito em `Future`
- [ ] Slick com `sql"... $param ..."` (sem `#$`)
- [ ] CSRF filter ativo em Play
- [ ] HTTP clients com timeouts
