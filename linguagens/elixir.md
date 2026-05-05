# Elixir / Erlang — Cartão de Segurança

> Erlang/Elixir é forte em concorrência segura por design (actor model, immutability). As vulnerabilidades vêm de áreas específicas: atom exhaustion, ETS, hot code reload, Phoenix patterns.

## Idiomas inseguros

### Atom exhaustion
```elixir
# BAD — String.to_atom de input
String.to_atom(user_input)  # cria atom novo se não existe
# Atoms NÃO são garbage collected → DoS por memória

# GOOD
String.to_existing_atom(user_input)
# rescues ArgumentError se não existe
```

### `:erlang.binary_to_term`
```elixir
# BAD — desserializa qualquer term, incluindo funcs anonymas
data = :erlang.binary_to_term(input)

# GOOD — :safe option (Erlang/OTP 22+)
data = :erlang.binary_to_term(input, [:safe])
# ainda assim, preferir JSON (Jason, Poison) sobre :erlang.term_to_binary
```

### Ecto raw queries
```elixir
# BAD
Ecto.Adapters.SQL.query!(Repo, "SELECT * FROM users WHERE name = '#{name}'", [])

# GOOD
Ecto.Adapters.SQL.query!(Repo, "SELECT * FROM users WHERE name = $1", [name])
# ou usar Ecto.Query (preferido)
from(u in User, where: u.name == ^name) |> Repo.all()
```

### Phoenix params em mass assignment
```elixir
# BAD — Repo.insert direto com params
def create(conn, %{"user" => user_params}) do
  user_params |> User.changeset() |> Repo.insert()
end
# Se changeset usar `cast(:all)` ou allowlist permissiva → mass assignment

# GOOD — changeset com allowlist explícita
def changeset(user, attrs) do
  user
  |> cast(attrs, [:name, :email])  # só estes campos
  |> validate_required([:name, :email])
  |> validate_format(:email, ~r/@/)
end
```

### `String.to_atom` em tags / keys
- Cada atom novo ocupa memória permanentemente.
- Pattern: `Map.new(input, fn {k, v} -> {String.to_atom(k), v} end)` → atom exhaustion.

### Phoenix — sem CSRF protection
```elixir
# BAD — pipeline sem :protect_from_forgery
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  # sem protect_from_forgery !
end

# GOOD
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
end
```

### Phoenix LiveView — assigns expostos no client
```elixir
# BAD — assign sensível visível no DOM HTML
def mount(_, _, socket) do
  {:ok, assign(socket, :api_token, get_token())}
end

# GOOD — assigns que não devem ir para client mantêm-se em socket privado
# O LiveView socket envia assigns serializados — não pôr secrets
```

### Hot code reload em produção
- Capacidade poderosa, mas se runtime aceita módulos via socket sem auth → RCE.
- Garantir que IEx remote shell tem cookie protegido.

### EPMD exposed
```bash
# EPMD (Erlang port mapper daemon) port 4369
# BAD — exposto na internet
netstat -tnlp | grep 4369

# GOOD — bind localhost ou firewall
ERL_EPMD_ADDRESS=127.0.0.1
```

### Cookie partilhado entre nodes
- Default cookie em `~/.erlang.cookie` — se atacante lê, controla cluster.
- `chmod 400` ao cookie. Cookie aleatório forte em produção.

## Helpers seguros

| Necessidade | Use |
|---|---|
| Random | `:crypto.strong_rand_bytes(32)` |
| Constant-time | `Plug.Crypto.secure_compare/2` (Phoenix) ou implementação manual |
| Password hashing | `Bcrypt.Elixir`, `Argon2.Elixir`, `Pbkdf2.Elixir` |
| HMAC | `:crypto.mac(:hmac, :sha256, key, data)` |
| JWT | `Joken` |
| HTTP client | `Finch`, `Req`, `HTTPoison` (com timeouts) |
| JSON | `Jason` (preferida sobre Poison) |
| Validation | `Ecto.Changeset`, `Vex` |

## Pitfalls específicos

### Plug.Conn manipulation
```elixir
# BAD — assumir que conn.params são strings
%{"id" => id} = conn.params
String.to_integer(id)  # crashes se não for string ou não numérico

# GOOD
case Map.get(conn.params, "id") do
  id when is_binary(id) ->
    case Integer.parse(id) do
      {n, ""} when n > 0 -> handle(n)
      _                  -> {:error, :invalid_id}
    end
  _ ->
    {:error, :missing_id}
end
```

### Phoenix `verified_routes` em vez de `Routes`
- Phoenix 1.7+ tem `~p` macro que valida routes em compile time.
- Migrar de `Routes.user_path(conn, :show, user)` para `~p"/users/#{user}"`.

### `with` clause expondo internals em error
```elixir
# BAD
case do_stuff() do
  {:error, %{detail: detail}} -> render(conn, "error", detail: detail)
  # detail pode conter SQL, paths, etc.
end

# GOOD — sanitizar
case do_stuff() do
  {:error, _reason} -> render(conn, "error", message: "Erro interno")
end
```

### Distributed Erlang sem TLS
- Default Erlang distribution é cleartext.
- Para produção multi-node: usar `inet_tls_dist` com certs.

## Bibliotecas comuns

- **Phoenix** — manter atualizado, ler security advisories
- **Ecto** — manter LTS
- **Plug** — manter LTS
- **Cowboy** — server HTTP, manter

## Quick wins

- [ ] Elixir 1.15+ / OTP 26+
- [ ] `mix hex.audit` (community plugin) ou `mix deps.audit`
- [ ] `sobelow` (SAST para Phoenix) na CI sem Highs
- [ ] Sem `String.to_atom` em input não confiável (usar `to_existing_atom`)
- [ ] `:erlang.binary_to_term` com `[:safe]` ou substituir por JSON
- [ ] Ecto changesets com `cast` allowlist explícita
- [ ] `:protect_from_forgery` no pipeline `:browser`
- [ ] `:put_secure_browser_headers` ativo
- [ ] `Plug.Crypto.secure_compare` em comparações
- [ ] `:crypto.strong_rand_bytes` para tokens
- [ ] Bcrypt/Argon2 para passwords
- [ ] EPMD em localhost / firewall
- [ ] `~/.erlang.cookie` em `chmod 400` com valor forte
- [ ] HTTP client com timeout explícito
- [ ] Distributed Erlang com TLS em produção
