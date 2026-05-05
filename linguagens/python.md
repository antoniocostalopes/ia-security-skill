# Python — Cartão de Segurança

## Funções e APIs perigosas

| API | Risco |
|---|---|
| `eval(code)`, `exec(code)`, `compile(code)` | RCE |
| `os.system(cmd)`, `os.popen(cmd)` | Command injection |
| `subprocess.*(cmd, shell=True)` | Command injection |
| `pickle.loads(data)`, `marshal.loads(data)` | Deserialization RCE |
| `yaml.load(s)` (sem `safe_load`/`Loader=SafeLoader`) | RCE |
| `xml.etree.ElementTree.parse(file)` (em Python < 3.7.1 sem mitigação) | XXE |
| `xml.dom.minidom`, `xml.sax`, `lxml` (sem `resolve_entities=False`) | XXE |
| `__import__(userInput)` | RCE / imports arbitrários |
| `getattr(obj, userInput)` | Acesso a métodos privados |
| `open(userPath)` | Path traversal |
| `requests.get(userURL)` | SSRF |
| `urllib.request.urlopen(userURL)` | SSRF |
| `tempfile.mktemp()` (deprecated) | TOCTOU race | usa `mkstemp()` |

## Idiomas inseguros

### `assert` em produção
```python
# BAD — assert é removido com python -O
def authorize(user):
    assert user.is_admin, "Access denied"
    return True

# GOOD
def authorize(user):
    if not user.is_admin:
        raise PermissionError("Access denied")
    return True
```

### String formatting com input não confiável
```python
# BAD — injeta no formato
log.info("User: " + user_input)             # OK
log.info(f"User: {user_input}")              # OK
log.info("User: %s" % user_input)            # OK
log.info(user_input)                         # se user_input contém "%s" → erro

# Format string injection
"hello {0.__class__.__init__.__globals__}".format(some_obj)  # acede internals
```

### `urllib3` sem verificação SSL
```python
# BAD
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
urllib3.PoolManager(cert_reqs='CERT_NONE')

# GOOD
http = urllib3.PoolManager(
    cert_reqs='CERT_REQUIRED',
    ca_certs=certifi.where(),
)
```

### Mutáveis como argumento default
```python
# BAD — partilhado entre chamadas
def add_user(user, group=[]):
    group.append(user)
    return group
add_user('alice')  # ['alice']
add_user('bob')    # ['alice', 'bob']  ← surpresa

# GOOD
def add_user(user, group=None):
    if group is None:
        group = []
    group.append(user)
    return group
```

### Comparação de hashes
```python
# BAD
if expected == received: ...  # timing attack

# GOOD
import hmac
if hmac.compare_digest(expected, received): ...
```

### `random` para segurança
```python
# BAD — Mersenne Twister, previsível
import random
token = ''.join(random.choices(string.ascii_letters, k=32))

# GOOD
import secrets
token = secrets.token_urlsafe(32)
token_hex = secrets.token_hex(32)
```

## Helpers seguros (stdlib)

| Necessidade | Use |
|---|---|
| Random tokens | `secrets.token_urlsafe(32)` / `secrets.token_hex(32)` |
| Constant-time compare | `hmac.compare_digest(a, b)` |
| HMAC | `hmac.new(key, msg, hashlib.sha256).hexdigest()` |
| Password hashing | `passlib` (`bcrypt` ou `argon2`) — **não** `hashlib.sha256` |
| URL parsing | `urllib.parse.urlparse` |
| Path safety | `os.path.realpath` + check |
| HTML escape | `html.escape(s, quote=True)` |
| Shell quote | `shlex.quote(s)` (mas preferir lista de args) |
| YAML load | `yaml.safe_load(s)` (sempre) |
| XML parse seguro | `defusedxml.ElementTree` |
| JSON Web Tokens | `pyjwt` ou `python-jose` (ambos OK) |

## Pitfalls específicos

### `subprocess` corretamente
```python
# Sempre lista de args, nunca shell=True com input
subprocess.run(['ls', '-l', user_dir], check=True, timeout=5)

# Se shell=True for inevitável (raro)
import shlex
subprocess.run(f"echo {shlex.quote(user_input)}", shell=True)
```

### `requests` corretamente
```python
# Timeout obrigatório
requests.get(url, timeout=(3, 10))  # connect, read

# SSL verification
requests.get(url, verify=True)  # default, mas confirmar não está False

# Não seguir redirects em SSRF-prone code
requests.get(url, allow_redirects=False, timeout=5)
```

### Django ORM `.extra()` e `.raw()`
```python
# BAD
Model.objects.extra(where=[f"name = '{name}'"])
Model.objects.raw(f"SELECT * FROM x WHERE name = '{name}'")

# GOOD
Model.objects.filter(name=name)
Model.objects.raw("SELECT * FROM x WHERE name = %s", [name])
```

### Flask debug mode
```python
# BAD — debug=True em produção expõe Werkzeug debugger (RCE via console)
app.run(debug=True)

# GOOD — controlado por env
app.run(debug=os.environ.get('FLASK_ENV') == 'development')
```

### FastAPI Depends com mutables
- Cuidado com objetos partilhados entre requests sem locks adequados.

## Bibliotecas comuns com vulns

- **`PyYAML` < 5.1** → `yaml.load` default era unsafe
- **`Pillow`** — várias CVEs históricas em parsers de imagem (manter atualizado)
- **`lxml`** — XXE se mal configurado
- **`Jinja2`** — SSTI se template é input do user
- **`Flask` < 2.3** — várias
- **`Django` < 4.2 LTS** — atualizar para LTS atual
- **`requests` < 2.32** — várias issues de SSL/redirect

## Quick wins

- [ ] `bandit` (SAST) corre na CI sem Highs/Mediums
- [ ] `pip-audit` ou `safety check` sem Críticos
- [ ] `secrets` em vez de `random` para tokens
- [ ] `hmac.compare_digest` em todas as comparações de hash/token
- [ ] `defusedxml` em vez de `xml.*` direto
- [ ] `passlib` para passwords
- [ ] `shell=False` em todos os `subprocess`
- [ ] `verify=True` em todos os `requests`
- [ ] `timeout` em todos os HTTP outbound
- [ ] Sem `assert` para autorização
- [ ] `DEBUG=False` em produção (Django/Flask)
