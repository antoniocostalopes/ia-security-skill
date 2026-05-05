# Flask — Profile de Segurança

## Deteção
- `from flask import Flask`
- `app = Flask(__name__)`
- `requirements.txt` com `flask`

## Setup mínimo seguro

```python
from flask import Flask
from flask_talisman import Talisman
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

app = Flask(__name__)
app.config.update(
    SECRET_KEY=os.environ['SECRET_KEY'],
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SECURE=True,
    SESSION_COOKIE_SAMESITE='Lax',
    PERMANENT_SESSION_LIFETIME=86400,
    MAX_CONTENT_LENGTH=1 * 1024 * 1024,  # 1MB
)

# Headers + HTTPS
Talisman(app, content_security_policy={
    'default-src': "'self'",
    'script-src': ["'self'"],
    'style-src': ["'self'", "'unsafe-inline'"],
})

# Rate limit
limiter = Limiter(app=app, key_func=get_remote_address,
                  default_limits=["200/hour"])
```

## Auth

Flask sem auth nativo — usar `flask-login` ou JWT.

```python
from flask_login import LoginManager, login_required, current_user

login_manager = LoginManager(app)
login_manager.login_view = 'auth.login'

@app.route('/profile')
@login_required
def profile():
    return render_template('profile.html', user=current_user)
```

## CSRF — Flask-WTF

```python
from flask_wtf.csrf import CSRFProtect
csrf = CSRFProtect(app)

# Templates
{{ form.csrf_token }}  # WTForms
# ou
<input name="csrf_token" value="{{ csrf_token() }}">
```

## Validation — Flask-WTF / Marshmallow / Pydantic

```python
from marshmallow import Schema, fields, validate

class UserSchema(Schema):
    name = fields.Str(required=True, validate=validate.Length(min=1, max=100))
    email = fields.Email(required=True)

@app.post('/users')
def create_user():
    try:
        data = UserSchema().load(request.json)
    except ValidationError as e:
        return jsonify(e.messages), 400
    # ...
```

## SQL — SQLAlchemy

Coberto em `analises/query-builders-orm.md`.

```python
# BAD
db.session.execute(text(f"SELECT * FROM users WHERE name = '{name}'"))

# GOOD
db.session.execute(text("SELECT * FROM users WHERE name = :name"), {'name': name})
User.query.filter_by(name=name).first()
```

## Templates — Jinja2

Auto-escape ativo por default em Flask.
```jinja
{# Auto-escaped #}
{{ user.name }}

{# Raw — perigoso #}
{{ user.bio | safe }}
```

## Common antipatterns

### `app.run(debug=True)` em produção
- Werkzeug debugger expõe console interativo (RCE via PIN brute force).

### Sem `SECRET_KEY` configurado
- Sessions não funcionam de forma segura.

### `render_template_string(user_input)`
- SSTI direto. Sempre template ficheiro com variáveis.

### `make_response(f"Hello {request.args['name']}")`
- XSS reflected.

### `redirect(request.args.get('next'))`
- Open redirect. Validar.

### Endpoints sem auth
- Flask não tem auth por default. Cada `@route` pode estar aberto.

### Blueprint sem prefix de auth
- Esquecer `@login_required` em rotas individuais.

## Helpers

| Necessidade | Lib |
|---|---|
| Auth | `flask-login`, `flask-jwt-extended`, `authlib` |
| CSRF | `flask-wtf` |
| Forms | `flask-wtf` (WTForms) |
| Validation | `marshmallow`, `pydantic`, `flask-pydantic` |
| ORM | `flask-sqlalchemy`, `sqlalchemy` direto |
| Migrations | `flask-migrate` (alembic) |
| Rate limit | `flask-limiter` |
| Headers | `flask-talisman` |
| Sessions server-side | `flask-session` (Redis backend) |
| CORS | `flask-cors` (com allowlist) |

## Quick wins

- [ ] Flask 3+
- [ ] `pip-audit` sem Críticos
- [ ] `app.run(debug=False)` em produção
- [ ] `SECRET_KEY` via env var, único por ambiente
- [ ] `flask-talisman` para headers + HTTPS
- [ ] `flask-limiter` para rate limit
- [ ] `flask-wtf` CSRF protection
- [ ] Cookies com `HTTPONLY + SECURE + SAMESITE`
- [ ] Validation com Marshmallow/Pydantic em todos os endpoints
- [ ] `@login_required` em endpoints privados (criar wrapper se DRY)
- [ ] Sem `render_template_string` com input
- [ ] `redirect` com URL validada (allowlist ou path-relative)
- [ ] SQLAlchemy queries parametrizadas
- [ ] `flask-session` com Redis em prod (não filesystem)
- [ ] `flask-cors` com origins específicos
- [ ] Logging estruturado (structlog) com sanitização
