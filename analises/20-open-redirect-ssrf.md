# Análise — Open Redirect, SSRF e Cross-Origin

> URLs controladas pelo utilizador são uma das classes mais perigosas. Open Redirect parece "Baixo" sozinho mas combina-se em Críticos (OAuth theft, phishing). SSRF abre porta a infraestrutura interna.

## 1. Open Redirect

Endpoint redireciona para URL fornecida pelo utilizador sem validar destino.

### Sinais de alarme

```javascript
// BAD — Express
app.get('/redirect', (req, res) => {
  res.redirect(req.query.url);
});
// /redirect?url=https://evil.tld

// GOOD — allowlist
const allowedHosts = ['app.meusite.tld', 'api.meusite.tld'];
app.get('/redirect', (req, res) => {
  try {
    const url = new URL(req.query.url);
    if (!allowedHosts.includes(url.hostname)) {
      return res.status(400).send('invalid redirect');
    }
    res.redirect(url.toString());
  } catch {
    res.status(400).send('invalid url');
  }
});
```

```python
# BAD — Flask
return redirect(request.args.get('next'))

# GOOD
from urllib.parse import urlparse
def is_safe_url(target):
    ref_url = urlparse(request.host_url)
    test_url = urlparse(urljoin(request.host_url, target))
    return (test_url.scheme in ('http', 'https')
            and ref_url.netloc == test_url.netloc)

if not is_safe_url(next_url):
    return abort(400)
return redirect(next_url)
```

```php
// BAD
header('Location: ' . $_GET['url']);

// GOOD
$allowed_hosts = ['meusite.tld', 'app.meusite.tld'];
$url = filter_var($_GET['url'], FILTER_VALIDATE_URL);
if (!$url) die('invalid');
$parts = parse_url($url);
if (!in_array($parts['host'] ?? '', $allowed_hosts, true)) die('forbidden');
header('Location: ' . $url);
```

### Variantes que escapam validação ingénua
- `//evil.tld` (protocol-relative — herda http/https)
- `/\evil.tld` (alguns parsers tratam como `evil.tld`)
- `https://safe.tld@evil.tld` (basic auth — alguns redirect handlers usam o `@`)
- `https://safe.tld.evil.tld` (subdomain spoofing se validação for `endsWith`)
- `javascript:alert(1)` (XSS via `Location`)
- `data:text/html,<script>...</script>`

### Validação correta
```python
# Validar componentes individualmente
parsed = urlparse(url)
if parsed.scheme not in ('http', 'https'):
    reject()
if parsed.hostname not in ALLOWED_HOSTS:
    reject()
if parsed.username or parsed.password:
    reject()
```

## 2. Server-Side Request Forgery (SSRF)

Aplicação faz request a URL controlada pelo utilizador → atacante força requests a redes internas, cloud metadata, ou serviços não expostos.

### Funções perigosas

| Linguagem | Funções |
|---|---|
| PHP | `file_get_contents($url)`, `curl_exec`, `wp_remote_get`, `Guzzle` |
| Python | `requests.get`, `urllib.request.urlopen`, `httpx.get` |
| Node | `fetch`, `axios.get`, `http.get`, `request` |
| Java | `URL.openConnection`, `HttpClient.send` |
| Ruby | `Net::HTTP.get`, `open(url)`, `URI.open` |
| Go | `http.Get`, `http.Client.Do` |
| .NET | `HttpClient.GetAsync`, `WebRequest.Create` |

### Targets típicos do atacante
- **Cloud metadata**: `http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>` (AWS)
- **GCP metadata**: `http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token`
- **Azure metadata**: `http://169.254.169.254/metadata/identity/oauth2/token`
- **Redes internas**: `127.0.0.1:6379` (Redis), `127.0.0.1:11211` (Memcached), `127.0.0.1:9200` (Elasticsearch)
- **Serviços admin**: `http://internal-admin.local`, `http://10.0.0.1`
- **Schemes alternativos**: `file:///etc/passwd`, `gopher://`, `dict://`, `ftp://`

### Defesa correta (allowlist + DNS rebinding mitigation)

```python
import ipaddress, socket
from urllib.parse import urlparse

ALLOWED_HOSTS = {'api.parceiro.tld', 'webhook.outro.tld'}
BLOCKED_RANGES = [
    ipaddress.ip_network('10.0.0.0/8'),
    ipaddress.ip_network('172.16.0.0/12'),
    ipaddress.ip_network('192.168.0.0/16'),
    ipaddress.ip_network('127.0.0.0/8'),
    ipaddress.ip_network('169.254.0.0/16'),  # cloud metadata + link-local
    ipaddress.ip_network('::1/128'),
    ipaddress.ip_network('fc00::/7'),
]

def is_safe_url(url):
    parsed = urlparse(url)
    if parsed.scheme not in ('http', 'https'):
        return False
    if parsed.hostname not in ALLOWED_HOSTS:
        return False
    # Resolver e verificar IP (mitigação parcial DNS rebinding)
    try:
        ip = ipaddress.ip_address(socket.gethostbyname(parsed.hostname))
        for blocked in BLOCKED_RANGES:
            if ip in blocked:
                return False
    except (socket.gaierror, ValueError):
        return False
    return True

# Uso
if not is_safe_url(user_url):
    raise ValueError("URL not allowed")
response = requests.get(user_url, timeout=5, allow_redirects=False)
```

```javascript
// Node — wrapper seguro
const dns = require('dns').promises;
const ipaddr = require('ipaddr.js');

async function safeFetch(url, allowlist) {
  const u = new URL(url);
  if (!['http:', 'https:'].includes(u.protocol)) throw new Error('bad scheme');
  if (!allowlist.includes(u.hostname)) throw new Error('not allowed');

  const { address } = await dns.lookup(u.hostname);
  const ip = ipaddr.parse(address);
  if (ip.range() !== 'unicast') throw new Error('private IP');

  return fetch(url, { redirect: 'manual', signal: AbortSignal.timeout(5000) });
}
```

```go
// Go
func safeGet(rawURL string, allowed []string) (*http.Response, error) {
    u, err := url.Parse(rawURL)
    if err != nil || (u.Scheme != "http" && u.Scheme != "https") {
        return nil, errors.New("invalid scheme")
    }
    if !slices.Contains(allowed, u.Hostname()) {
        return nil, errors.New("host not allowed")
    }
    ips, err := net.LookupIP(u.Hostname())
    if err != nil { return nil, err }
    for _, ip := range ips {
        if ip.IsPrivate() || ip.IsLoopback() || ip.IsLinkLocalUnicast() {
            return nil, errors.New("private IP")
        }
    }
    client := &http.Client{
        Timeout: 5 * time.Second,
        CheckRedirect: func(req *http.Request, via []*http.Request) error {
            return http.ErrUseLastResponse  // não seguir redirects
        },
    }
    return client.Get(rawURL)
}
```

### Cuidados adicionais
- **Não seguir redirects** automaticamente (atacante usa redirect para `127.0.0.1` após validação inicial).
- **Timeout obrigatório** — sem ele, atacante pode usar SSRF para DoS.
- **DNS rebinding**: validar IP **e** voltar a resolver no momento do request, ou usar HTTP client que faz só uma resolução.
- **Não devolver corpo da resposta** ao utilizador (data exfiltration via SSRF).

## 3. CORS Misconfiguration

CORS define quem pode aceder a recursos via JS. Mal configurado = origin malicioso lê dados autenticados.

### Padrões perigosos

```
# BAD — reflete qualquer origin com credentials
Access-Control-Allow-Origin: <whatever client sent>
Access-Control-Allow-Credentials: true
```

```javascript
// BAD — Express
app.use(cors({ origin: '*', credentials: true }));  // browsers rejeitam, mas é red flag

// BAD — reflete origin sem allowlist
app.use(cors({ origin: (origin, cb) => cb(null, true), credentials: true }));

// GOOD
const ALLOWED = ['https://app.meusite.tld', 'https://staging.meusite.tld'];
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || ALLOWED.includes(origin)) cb(null, true);
    else cb(new Error('CORS not allowed'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
```

### Bypass de allowlist comum
- `https://app.meusite.tld.evil.tld` (sufixo) — se validação é `origin.endsWith('app.meusite.tld')` → bypass.
- `https://evil-app.meusite.tld` (prefixo do subdomínio) — se valida `*.meusite.tld` permissivo.
- `null` origin (vem de iframes sandboxed, redirect, file://) → atacante força, alguns servers permitem.

### CORS check correto
- **Comparação exata** com lista, não `endsWith`/`startsWith`/regex permissiva.
- **Vary: Origin** sempre que o response varia por Origin (senão cache poisoning).
- **Não usar wildcard com credentials** (browsers já bloqueiam, mas é sinal de má config).

## 4. PostMessage Cross-Origin

Browser-side: `window.postMessage` é canal cross-origin. Mal usado = XSS cross-frame.

```javascript
// BAD — recebe sem validar origin
window.addEventListener('message', (event) => {
  document.body.innerHTML = event.data;  // qualquer parent/iframe injeta
});

// GOOD
const TRUSTED = 'https://app.meusite.tld';
window.addEventListener('message', (event) => {
  if (event.origin !== TRUSTED) return;
  // validar payload schema
  if (typeof event.data !== 'object' || !event.data.type) return;
  // tratar só tipos conhecidos
  switch (event.data.type) {
    case 'resize': handleResize(event.data.height); break;
    default: return;
  }
});
```

## 5. DNS Rebinding

Atacante controla DNS do seu domínio. Browser/server resolve `evil.tld` → IP público inicialmente, depois resolve novamente → `127.0.0.1`. App valida primeira resolução, faz request à segunda.

### Mitigação
- HTTP client que faz **uma única resolução DNS** por request.
- Validar **IP final** antes de cada request, não só hostname.
- Usar libraries como `python-restricted-resolver`, `axios-better-stacktrace`.

## Quick wins (faz isto antes de entregar)

- [ ] Listar todos os `redirect`/`Location` no código — adicionar allowlist
- [ ] Listar todos os HTTP clients que aceitam URL do user — wrappear com `safeFetch`/`safeGet`
- [ ] Configurar CORS com allowlist explícita (sem `*` ou regex)
- [ ] `Vary: Origin` em respostas que variam
- [ ] PostMessage handlers verificam `event.origin`
- [ ] HTTP clients com timeout obrigatório
- [ ] HTTP clients sem follow redirects automático em SSRF-prone code
- [ ] Bloqueio de IPs privados/loopback/link-local em chamadas outbound

## Falsos positivos
- Redirect para path relativo do mesmo site (`/dashboard`) — OK sem allowlist se validares scheme
- HTTP outbound a hostnames hardcoded (sem input do user) — OK
- CORS `*` em API **pública read-only sem cookies** — aceitável (mas marcar)

## Severidade — em linguagem honesta
- **Crítico:** SSRF com acesso a cloud metadata → roubo de credenciais cloud
- **Crítico:** SSRF que devolve corpo da resposta ao utilizador (data exfiltration)
- **Alto:** Open Redirect em fluxo OAuth → roubo de token
- **Alto:** CORS reflete origin com `Allow-Credentials: true`
- **Médio:** Open Redirect simples (phishing)
- **Médio:** PostMessage handler sem origin check
