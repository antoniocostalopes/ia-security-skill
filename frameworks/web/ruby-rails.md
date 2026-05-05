# Ruby on Rails — Profile de Segurança

## Deteção
- `Gemfile` com `rails`
- `config/application.rb`
- `config/routes.rb`

## Config — production

```ruby
# config/environments/production.rb
config.force_ssl = true
config.session_store :cookie_store, key: '_app_session', secure: true, httponly: true, same_site: :lax

# config/initializers/secure_headers.rb
SecureHeaders::Configuration.default do |config|
  config.csp = {
    default_src: %w('self'),
    script_src: %w('self'),
    style_src: %w('self' 'unsafe-inline'),
    img_src: %w('self' data: https:),
    object_src: %w('none'),
    frame_ancestors: %w('self'),
  }
  config.hsts = { max_age: 31_536_000, include_subdomains: true, preload: true }
  config.x_frame_options = 'SAMEORIGIN'
  config.x_content_type_options = 'nosniff'
  config.referrer_policy = 'strict-origin-when-cross-origin'
end
```

## Auth — Devise (mais comum) / has_secure_password

```ruby
# Modelo
class User < ApplicationRecord
  has_secure_password  # bcrypt built-in
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }
end

# Devise config
devise :database_authenticatable, :registerable, :recoverable, :rememberable,
       :validatable, :lockable, :timeoutable, :trackable
```

```ruby
# Lockable + rate limit (rack-attack)
# config/initializers/rack_attack.rb
class Rack::Attack
  throttle('logins/email', limit: 5, period: 15.minutes) do |req|
    req.params['email'] if req.path == '/users/sign_in' && req.post?
  end
end
```

## Strong Parameters (anti mass assignment)

```ruby
class UsersController < ApplicationController
  def update
    @user = User.find(params[:id])
    authorize @user  # Pundit ou similar
    @user.update(user_params)
  end

  private

  def user_params
    # ALLOWLIST explícita
    params.require(:user).permit(:name, :email, :bio)
    # SEM :role, :admin, etc.
  end
end
```

## Authorization — Pundit ou CanCanCan

```ruby
# Pundit policy
class PostPolicy < ApplicationPolicy
  def update?
    record.user_id == user.id || user.admin?
  end
end

# Controller
class PostsController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def update
    @post = Post.find(params[:id])
    authorize @post  # raises Pundit::NotAuthorizedError
    @post.update(post_params)
  end
end
```

## ActiveRecord queries

Coberto em `linguagens/ruby.md`. Resumo:
```ruby
# BAD
User.where("name = '#{name}'")

# GOOD
User.where(name: name)
User.where("name = ?", name)
```

## CSRF
- `protect_from_forgery with: :exception` ativo em `ApplicationController` por default.
- Para APIs com tokens: `protect_from_forgery with: :null_session` (não desativar).

## Views — XSS

```erb
<%# Auto-escaped %>
<%= user.name %>

<%# Raw — perigoso %>
<%= raw user.bio %>
<%== user.bio %>

<%# HTML safe (input já validado) %>
<%= sanitize user.bio, tags: %w[p br strong em a], attributes: %w[href] %>
```

## File uploads — Active Storage

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end

# Validation
validates :avatar, content_type: ['image/jpeg', 'image/png'],
                   size: { less_than: 5.megabytes }
```

```ruby
# Active Storage URL signing automatic
url_for(@user.avatar)  # signed URL com expiry
```

## Common antipatterns

### `Rails.application.config.consider_all_requests_local = true` em prod
- Mostra stack traces a qualquer um.

### Sem `before_action :authenticate_user!`
- Esquecido em controller → tudo público.

### `params.require(:user).permit!` (com `!`)
- Permite tudo. Allowlist explícita sempre.

### `redirect_to params[:next]`
- Open redirect (Rails 7+ tem `allow_other_host: false` default).

### `eval`, `send` com input
- RCE / acesso arbitrário.

### `Marshal.load` / `YAML.load` (não `safe_load`)
- Deserialization RCE.

### `Sidekiq Web UI` sem auth
```ruby
# config/routes.rb
require 'sidekiq/web'
Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  ActiveSupport::SecurityUtils.secure_compare(user, ENV['SIDEKIQ_USER']) &
  ActiveSupport::SecurityUtils.secure_compare(password, ENV['SIDEKIQ_PASS'])
end
mount Sidekiq::Web => '/sidekiq'
```

### `Rails.cache` sem isolamento por user
- Cache key sem `user.id` → cache poisoning entre users.

### N+1 queries em endpoints públicos
- DoS por DB load.

## Quick wins

- [ ] Rails LTS atual (7.1+)
- [ ] Ruby 3.2+
- [ ] `bundle audit check --update` sem Críticos
- [ ] `brakeman` na CI sem Highs
- [ ] `force_ssl = true` em prod
- [ ] HSTS, X-Frame-Options, CSP configurados (secure_headers gem)
- [ ] Cookies seguros
- [ ] `authenticate_user!` em controllers privados
- [ ] Strong Parameters allowlist explícita (sem `permit!`)
- [ ] Pundit/CanCan para autorização granular
- [ ] `has_secure_password` ou Devise para passwords (bcrypt)
- [ ] Rack::Attack para rate limit em login/reset
- [ ] CSRF protection ativo
- [ ] Sanitize em qualquer `raw` output
- [ ] Active Storage com validation
- [ ] Sidekiq Web UI atrás de auth
- [ ] `secure_compare` em comparações de tokens
- [ ] SecureRandom para tokens
- [ ] Sem `Marshal.load` / `YAML.load` de input
