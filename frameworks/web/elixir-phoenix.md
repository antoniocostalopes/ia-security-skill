# Phoenix (Elixir) — Profile de Segurança

## Deteção
- `mix.exs` com `{:phoenix, ...}`
- `lib/<app>_web/`
- `config/config.exs`

## endpoint.ex — config

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # Session
  @session_options [
    store: :cookie,
    key: "_my_app_key",
    signing_salt: "...",
    same_site: "Lax",
    secure: true,
    http_only: true,
    max_age: 60 * 60 * 24 * 7
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  plug Plug.Static, ...
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["*/*"], json_decoder: Phoenix.json_library()
  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MyAppWeb.Router
end
```

## Router — pipelines

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery       # CSRF
    plug :put_secure_browser_headers  # Headers padrão
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug MyAppWeb.RequireAuth
  end

  pipeline :admin do
    plug MyAppWeb.RequireAuth
    plug MyAppWeb.RequireAdmin
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :auth, :admin]
    live "/admin/users", AdminUserLive
  end
end
```

## Ecto — changesets (anti mass assignment)

```elixir
defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :email, :string
    field :role, :string, default: "user"
    field :password_hash, :string
    field :password, :string, virtual: true
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])  # ALLOWLIST — sem :role
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:email, max: 254)
    |> unique_constraint(:email)
  end

  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :role])  # admin pode mudar role
    |> validate_required([:name, :email])
    |> validate_inclusion(:role, ["user", "admin"])
  end
end
```

## Ecto queries — coberto em `linguagens/elixir.md`

## LiveView — segurança

```elixir
defmodule MyAppWeb.UserLive do
  use MyAppWeb, :live_view

  def mount(_params, session, socket) do
    case session["user_id"] do
      nil -> {:ok, redirect(socket, to: ~p"/login")}
      id  ->
        user = Accounts.get_user!(id)
        # NÃO assignar dados sensíveis em socket público (vão no payload)
        {:ok, assign(socket, current_user: user)}
    end
  end

  def handle_event("update", %{"user" => params}, socket) do
    # Authorize ownership
    case Accounts.update_user(socket.assigns.current_user, params) do
      {:ok, user} -> {:noreply, assign(socket, current_user: user)}
      {:error, cs} -> {:noreply, assign(socket, changeset: cs)}
    end
  end
end
```

## Phoenix Token (signed/encrypted)

```elixir
# Sign
token = Phoenix.Token.sign(MyAppWeb.Endpoint, "user_id_salt", user.id)

# Verify (com expiry)
case Phoenix.Token.verify(MyAppWeb.Endpoint, "user_id_salt", token, max_age: 3600) do
  {:ok, user_id} -> ...
  {:error, _}    -> :unauthorized
end
```

## Common antipatterns

### `protect_from_forgery` esquecido em pipeline `:browser`
- CSRF aberto.

### Pipeline `:browser` aplicado a webhooks externos
- Webhook fails CSRF check porque não envia token.
- Para webhooks usar pipeline `:api` + verificação HMAC.

### `String.to_atom` em params
- Atom exhaustion.

### `cast(:all)` em changeset
- Mass assignment.

### LiveView assigns sensíveis
- Tudo em assigns vai serializado para client. Não pôr secrets ou PII de outros users.

### `redirect(to: params["next"])`
- Open redirect.

### Phoenix.HTML em vez de HEEx
- HEEx (`~H`) é mais seguro (auto-escape contextual).

### Channels sem auth
```elixir
# BAD
def join("admin:" <> _, _, socket), do: {:ok, socket}

# GOOD
def join("admin:" <> _, _, socket) do
  if socket.assigns.user.admin?, do: {:ok, socket}, else: {:error, %{reason: "forbidden"}}
end
```

## Quick wins

- [ ] Phoenix 1.7+
- [ ] Elixir 1.15+, OTP 26+
- [ ] `mix deps.audit` (community plugin) ou `mix sobelow` na CI
- [ ] Pipeline `:browser` com `:protect_from_forgery` e `:put_secure_browser_headers`
- [ ] Session com `secure: true, http_only: true, same_site: "Lax"`
- [ ] Ecto changesets com `cast` allowlist explícita
- [ ] Auth plug em pipelines de routes privadas
- [ ] LiveView assigns sem secrets
- [ ] Channels com auth check no `join`
- [ ] Phoenix.Token para tokens de uso curto (não JWT manual)
- [ ] HEEx (`~H`) em vez de strings de HTML
- [ ] Webhook endpoints fora do pipeline `:browser` (sem CSRF, com HMAC)
- [ ] HTTPS forçado (atrás de proxy ou `force_ssl: true` em endpoint)
- [ ] `redirect(to: ...)` com URL validada
