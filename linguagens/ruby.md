# Ruby — Cartão de Segurança

## APIs perigosas

| API | Risco |
|---|---|
| `eval`, `instance_eval`, `class_eval`, `module_eval` | RCE |
| `send`, `public_send` com nome de método controlado | Method invocation arbitrária |
| `system`, `exec`, `` ` `` (backticks), `IO.popen`, `Open3.*` | Command injection |
| `Marshal.load`, `Marshal.restore` | Deserialization RCE |
| `YAML.load` (sem `safe_load`) | RCE |
| `Kernel.open(input)` | Command exec se input começa com `|` |
| `URI.open(input)` (substituto de `open-uri`) | SSRF + idem `|` issue |
| `File.read(input)`, `IO.read(input)` | Path traversal |
| `ERB` com input | SSTI |
| `Object.const_get(input)` | Acesso arbitrário |
| `define_method(input, ...)` | Definição arbitrária |
| `method_missing` com input | Bypass de métodos |

## Idiomas inseguros

### `send` para chamar métodos
```ruby
# BAD
user.send(params[:method])
# params[:method] = 'destroy' → apaga user

# GOOD — allowlist
ALLOWED = %w[name email update_password]
method = params[:method]
raise unless ALLOWED.include?(method)
user.public_send(method)
```

### `Kernel.open` com `|`
```ruby
# BAD
content = open(params[:url]).read
# params[:url] = '|whoami' → executa comando

# GOOD — usar Net::HTTP ou URI explícito
require 'net/http'
uri = URI.parse(params[:url])
raise unless %w[http https].include?(uri.scheme)
content = Net::HTTP.get(uri)
```

### Mass assignment em Rails
```ruby
# BAD — Strong Parameters não usado
def update
  @user.update(params[:user])  # role: 'admin' passa
end

# GOOD
def update
  @user.update(user_params)
end

private

def user_params
  params.require(:user).permit(:name, :email, :bio)  # role NÃO incluído
end
```

### SQL com interpolação
```ruby
# BAD
User.where("name = '#{params[:name]}'")
User.find_by_sql("SELECT * FROM users WHERE name = '#{params[:name]}'")

# GOOD
User.where(name: params[:name])
User.where("name = ?", params[:name])
User.where("name = :name", name: params[:name])
```

### `find_by_X` dinâmico (deprecated)
- Já removido em Rails 4+. Mas código legacy pode usar `User.find_by_role!('admin')`.

### `redirect_to` com input
```ruby
# BAD — open redirect
redirect_to params[:next]

# GOOD
redirect_to params[:next], allow_other_host: false  # Rails 7+
# ou validar URL
```

### CSRF disabled em controller
```ruby
# BAD — esquecido em controller que devia ter
class ApiController < ApplicationController
  skip_before_action :verify_authenticity_token  # !!
end

# GOOD
# CSRF deve estar ON. Para APIs com tokens, usar:
class ApiController < ApplicationController
  protect_from_forgery with: :null_session  # ou autenticar via token
end
```

### Comparação de hashes
```ruby
# BAD
expected == received

# GOOD — Rails fornece
ActiveSupport::SecurityUtils.secure_compare(expected, received)

# ou Ruby stdlib (3.2+)
require 'openssl'
OpenSSL.fixed_length_secure_compare(expected, received)
```

### Random para tokens
```ruby
# BAD
rand(1_000_000)

# GOOD
SecureRandom.hex(32)
SecureRandom.urlsafe_base64(32)
SecureRandom.uuid
```

## Helpers seguros (stdlib + Rails)

| Necessidade | Use |
|---|---|
| Random | `SecureRandom.hex(32)` / `SecureRandom.urlsafe_base64(32)` |
| Constant-time compare | `ActiveSupport::SecurityUtils.secure_compare` |
| Password hashing | `BCrypt::Password.create(pwd)` (Rails `has_secure_password`) |
| HMAC | `OpenSSL::HMAC.hexdigest('SHA256', key, data)` |
| URL parsing | `URI.parse` + validação de scheme |
| Path safety | `File.expand_path` + check de prefix |
| HTML escape | Rails ERB faz auto-escape; `ERB::Util.html_escape` |
| Shell escape | `Shellwords.escape` (preferir lista de args em `Open3.capture3`) |
| JWT | `jwt` gem |
| YAML | `YAML.safe_load` (Ruby 3.1+ é default seguro) |
| Anti-XSS | Rails ERB auto-escape; `raw`/`html_safe` raramente |
| Anti-CSRF | `protect_from_forgery` (default em Rails) |

## Pitfalls específicos do Rails

### `permit!` sem allowlist
```ruby
# BAD
params.require(:user).permit!  # tudo passa

# GOOD
params.require(:user).permit(:name, :email)
```

### `before_action :authenticate_user!` esquecido
```ruby
# Rails default: tudo público se não declarares
class AdminController < ApplicationController
  # SEM before_action — qualquer um acede
end

# GOOD
class AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
end
```

### `request.host` vs `request.original_url`
- `request.host` aceita Host header → manipulável (Host header injection).
- Validar contra allowlist antes de usar em emails/redirects.

### YAML em arquivos de config
- `YAML.load_file('config.yml')` — em Ruby < 3.1 era inseguro.
- Cuidado se config vem de utilizador (raro mas existe).

### `to_yaml` / `to_json` com objetos com `to_s`
- Objetos custom podem expor mais do que esperas via `inspect`.

## Bibliotecas comuns com vulns

- **Rails** — manter LTS atualizado, ler security advisories
- **Devise** — várias CVEs históricas, manter atualizado
- **Nokogiri** — XXE se mal usado, manter atualizado
- **Sidekiq Web UI** — sem auth por default, proteger
- **Rack** stdlib — vulns ocasionais

## Quick wins

- [ ] Ruby 3.2+ (versões antigas EOL)
- [ ] Rails LTS atual
- [ ] `bundle audit` sem Críticos
- [ ] `brakeman` (SAST) na CI sem Highs
- [ ] `SecureRandom` em todos os tokens
- [ ] `BCrypt`/`has_secure_password` em passwords
- [ ] Strong Parameters em todos os controllers que escrevem
- [ ] CSRF protection ativo (não desativar globalmente)
- [ ] `before_action :authenticate_user!` em todos os controllers privados
- [ ] `redirect_to allow_other_host: false`
- [ ] `secure_compare` em comparações de tokens
- [ ] Sidekiq Web UI atrás de auth
- [ ] `YAML.safe_load` ou Ruby 3.1+ default
