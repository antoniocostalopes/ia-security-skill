# Análise — DoS e Resource Limits

> Não é só sobre atacantes a martelar o servidor. Um cliente legítimo a enviar um regex catastrófico, ou um JSON profundo, pode pôr o serviço offline. Esta categoria fecha a porta para muitos "ops, o site caiu".

## O que procurar

### 1. ReDoS (Regular Expression DoS)

Regex com backtracking exponencial — input malicioso de 50 chars trava CPU por minutos.

#### Padrões perigosos
```regex
^(a+)+$              # input: "aaaaaaaaaaaaaaaaX"
^(.*)+$
^(\w+\s?)*$
^([a-zA-Z]+)*$
(a|aa)+
(.+)+
```

#### Sinais de alarme
```javascript
// BAD — Node email validation regex famoso por ReDoS
const re = /^([a-zA-Z0-9._%-]+)+@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})$/;
re.test(userEmail);  // input "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!" trava CPU

// GOOD — usar lib validada
const validator = require('validator');
validator.isEmail(userEmail);
```

```python
# BAD
import re
if re.match(r'^(.*)*$', input):  # catastrophic
    ...

# GOOD — usar re2 (Google) que não tem backtracking
import re2  # pip install pyre2
re2.match(pattern, input)
```

#### Linguagens "imunes" a ReDoS
- **Go** (`regexp` package usa RE2 — sem backtracking)
- **Rust** (`regex` crate usa NFA)
- **Java** (com `java.util.regex` desde Java 9 tem timeout opcional)

#### Mitigação universal
- Usar engines RE2-based (Go regex, Rust regex, Python `re2`, Node `re2`).
- Timeout em regex (Java `Matcher` com cancelamento via thread, etc.).
- Limitar comprimento do input antes de aplicar regex (se max 100 chars, ReDoS não acontece).
- Validar com parsers específicos (`isEmail`, `URL.parse`) em vez de regex caseiros.

### 2. Decompression Bombs (Zip Bomb / Image Bomb)

Ficheiro pequeno (~kB) que descomprime para gigabytes.

#### Padrões a verificar
- Upload aceita `.zip`/`.tar.gz` e descomprime sem limite.
- Upload aceita imagens e processa com ImageMagick/Pillow sem limite.
- Aceita XML/JSON sem limite de profundidade.
- Aceita SVG (XML + zip if compressed).

```python
# BAD
import zipfile
with zipfile.ZipFile(uploaded) as z:
    z.extractall('/tmp/')

# GOOD
MAX_SIZE = 100 * 1024 * 1024  # 100 MB
total = 0
with zipfile.ZipFile(uploaded) as z:
    for info in z.infolist():
        total += info.file_size
        if total > MAX_SIZE:
            raise ValueError("Zip bomb suspeito")
        if info.file_size / max(info.compress_size, 1) > 100:
            raise ValueError("Compression ratio suspeito")
    z.extractall('/tmp/')
```

```python
# BAD — Pillow
from PIL import Image
img = Image.open(uploaded)
img.load()  # 1MB JPEG pode descomprimir para 100GB

# GOOD
Image.MAX_IMAGE_PIXELS = 89_478_485  # ~268MB descomprimido (3 bytes/pixel)
img = Image.open(uploaded)
img.verify()  # ou img.load() em try/except DecompressionBombError
```

```javascript
// Node — sharp com limit
const sharp = require('sharp');
sharp(uploaded, { limitInputPixels: 268_000_000 }).resize(800).toFile(out);
```

### 3. Deep JSON / XML

Parser fica em estado pathológico com input profundamente aninhado.

```python
# Python — json é imune por default (RecursionError protege)
# YAML pode ser problema
import yaml
yaml.safe_load(input)  # safe_load, não load

# XML — usar defusedxml
from defusedxml import ElementTree as ET
```

```javascript
// Node — JSON.parse é OK, mas se usares libs de XML/YAML
const yaml = require('js-yaml');
yaml.load(input, { schema: yaml.JSON_SCHEMA });  // limita tipos

// Para JSON gigante
// Limitar via Express
app.use(express.json({ limit: '1mb' }));
```

### 4. Unbounded queries / paginação

Query devolve "tudo" sem paginação → DB e memória esgotam.

```javascript
// BAD
const users = await User.findAll();  // 10M users em memória

// GOOD
const { page = 1, limit = 50 } = req.query;
const realLimit = Math.min(parseInt(limit), 100);  // cap server-side
const users = await User.findAll({
  limit: realLimit,
  offset: (page - 1) * realLimit,
});
```

```sql
-- BAD — REST API permite ?per_page=99999
GET /api/users?per_page=99999

-- GOOD — cap server-side
SELECT * FROM users LIMIT LEAST(?, 100);
```

### 5. Loops sem fim / recursão sem limite

```python
# BAD — recursão sem profundidade máxima
def parse_tree(node):
    if 'children' in node:
        for c in node['children']:
            parse_tree(c)  # JSON aninhado profundo trava
```

```python
# GOOD
def parse_tree(node, depth=0, max_depth=20):
    if depth > max_depth:
        raise ValueError("Tree too deep")
    if 'children' in node:
        for c in node['children']:
            parse_tree(c, depth + 1, max_depth)
```

### 6. File handles / connection pools sem limite

```python
# BAD
def fetch(url):
    return requests.get(url)  # cria nova connection sempre

# GOOD
import requests
session = requests.Session()
adapter = requests.adapters.HTTPAdapter(pool_connections=10, pool_maxsize=20)
session.mount('http://', adapter)
session.mount('https://', adapter)
```

### 7. Memory bombs em parsers

```python
# BAD — pandas lê CSV inteiro para memória
df = pd.read_csv(uploaded_file)

# GOOD — chunked
for chunk in pd.read_csv(uploaded_file, chunksize=10000):
    process(chunk)
```

### 8. Falta de timeouts

Sem timeouts em:
- HTTP outbound (chamadas a APIs externas)
- DB queries
- File operations
- Subprocess execution
- WebSocket connections
- Background jobs

Cada um pode ficar pendurado para sempre, esgotando workers.

```javascript
// BAD
const data = await fetch(url);

// GOOD
const data = await fetch(url, { signal: AbortSignal.timeout(5000) });
```

```python
# BAD
response = requests.get(url)

# GOOD
response = requests.get(url, timeout=(3, 10))  # connect, read
```

### 9. Sem rate limit em endpoints custosos

| Endpoint | Custo | Risco sem rate limit |
|---|---|---|
| `/login` | DB + bcrypt | Brute force / DoS |
| `/password-reset` | Email + DB | Spam / enum |
| `/search` | Full-text scan | DoS via queries pesadas |
| `/export` | Generate PDF/XLSX | DoS via memória |
| `/api/upload` | Disk I/O | DoS por disco |
| `/api/process` | CPU intensivo (image resize, etc.) | DoS |

### 10. Background jobs sem limite de concorrência

```javascript
// BAD — Bull queue sem limit
new Queue('processing').process(async (job) => { ... });
// 1000 jobs pendentes = 1000 workers em paralelo

// GOOD
new Queue('processing').process(5, async (job) => { ... });  // max 5 paralelos
```

## Receita rápida — rate limit (Node + Express)

```javascript
const rateLimit = require('express-rate-limit');

// Login: 5 por 15 min
app.post('/login', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: 'Demasiadas tentativas',
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => `${req.ip}_${req.body.email}`,
}), loginHandler);

// API geral
app.use('/api', rateLimit({
  windowMs: 60 * 1000,
  max: 100,
}));
```

```python
# Flask + Flask-Limiter
from flask_limiter import Limiter
limiter = Limiter(key_func=lambda: request.remote_addr, app=app)

@app.route('/login', methods=['POST'])
@limiter.limit('5 per 15 minutes')
def login(): ...
```

## Quick wins (faz isto antes de entregar)

- [ ] Listar regex no código — substituir caseiros por libs validadas (validator, `email-validator`, etc.)
- [ ] Aplicar `Pillow.MAX_IMAGE_PIXELS` ou `sharp limitInputPixels`
- [ ] Validar zip uploads com size + ratio check
- [ ] `express.json({ limit: '1mb' })` ou equivalente noutros frameworks
- [ ] Timeout em **todos** os HTTP outbound (3-5 seg connect, 10-30 read)
- [ ] Timeout em DB queries lentas
- [ ] Cap de `per_page` server-side em endpoints paginados (`min(req, 100)`)
- [ ] Rate limit em login, reset, search, export, upload
- [ ] Concurrency limit em background queues
- [ ] Memory limits em containers (`--memory=512m` para evitar OOM kill global)

## Falsos positivos
- Regex aplicado a strings com `maxLength` validado a montante — risco baixo
- Endpoints internos sem exposição externa (atrás de VPN) — rate limit menos crítico (mas ainda recomendado)
- Background jobs em queues isoladas com worker pool dedicado — concurrency limit menos urgente

## Severidade — em linguagem honesta
- **Alto:** ReDoS em endpoint público com CPU shared (1 user trava o site)
- **Alto:** Decompression bomb permitida em upload público
- **Alto:** Sem rate limit em login (combina com brute force)
- **Médio:** Falta de timeout em HTTP outbound (ataque indireto)
- **Médio:** Paginação sem cap (1 user pesado afeta DB)
- **Baixo:** Regex caseiro com input já restringido a 50 chars
