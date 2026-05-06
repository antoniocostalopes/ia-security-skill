# Patterns de Deteção — Regex e Keywords Literais

> Para cada categoria, padrões **literais** que a IA deve procurar com `grep`/regex mental. Reduz "esqueci-me de procurar X" e força sistematização. Usar em conjunto com a análise contextual (não substituir).

## Como usar

Quando aplicas uma análise, **primeiro corres mentalmente os patterns abaixo**, depois aplicas a lente contextual do `analises/<categoria>.md`. Isto garante que padrões clássicos não escapam.

> **Importante:** match de pattern **não é** vulnerabilidade confirmada — é "candidato a inspecionar". Aplica `analises/00-falsos-positivos-comuns.md` antes de reportar.

## 1. XSS

```regex
# Output não escapado em PHP
echo\s+\$_(GET|POST|REQUEST|COOKIE|SERVER)
print\s+\$_(GET|POST|REQUEST)
echo\s+\$\w+\s*;.*<.*>          # echo de var em contexto HTML
<\?=\s*\$_(GET|POST|REQUEST)

# JS DOM
\.innerHTML\s*=
\.outerHTML\s*=
document\.write\s*\(
\.insertAdjacentHTML
$$selector$$\.html\(

# Frameworks
dangerouslySetInnerHTML
v-html\s*=
\[innerHTML\]\s*=
\{\{\{[^}]+\}\}\}                # Handlebars triple braces

# Atributos perigosos
href\s*=\s*["']?\$\{?[a-zA-Z]
src\s*=\s*["']?\$\{?[a-zA-Z]
javascript:\s*\w
data:text/html
```

## 2. SQL Injection

```regex
# Concatenação
"SELECT.*"\s*\+\s*\$
"SELECT.*\$\{[^}]+\}"
f"SELECT.*\{[^}]+\}"
'SELECT.*' \. \$
"INSERT.*"\s*\+
"UPDATE.*"\s*\+

# WordPress $wpdb
\$wpdb->query\s*\([^)]*\$
\$wpdb->get_(var|row|results|col)\s*\([^,)]*\$[^,)]*\)
\$wpdb->prepare\s*\([^,]*'%s'

# ORM raw
DB::raw\s*\(
->whereRaw\s*\(\s*["']
->selectRaw\s*\(\s*["']
sequelize\.query\s*\(\s*`.*\$\{
session\.execute\s*\(\s*f"
text\s*\(\s*f"
FromSqlRaw\s*\(\s*\$"
.Raw\s*\(\s*fmt\.Sprintf
```

## 3. Comando OS / Shell

```regex
# PHP
exec\s*\(\s*[^)]*\$
shell_exec\s*\(
system\s*\(\s*[^)]*\$
passthru\s*\(
proc_open\s*\(
popen\s*\(
`[^`]*\$[^`]*`                   # backticks com var

# Python
os\.system\s*\(
os\.popen\s*\(
subprocess\.\w+\s*\([^)]*shell\s*=\s*True
commands\.\w+\s*\(

# Node
child_process\.exec\s*\(
\.exec\s*\(\s*[`'"][^`'"]*\$\{
spawn\s*\([^)]*shell:\s*true

# Java
Runtime\.getRuntime\(\)\.exec\s*\(
ProcessBuilder\s*\([^)]*\+

# Go
exec\.Command\s*\(\s*"sh"\s*,\s*"-c"
```

## 4. Path Traversal / LFI / RFI

```regex
# PHP
include\s*\(\s*\$_(GET|POST|REQUEST)
require\s*\(\s*\$_(GET|POST|REQUEST)
include\s+\$\w+\s*\.\s*\.php
file_get_contents\s*\(\s*\$_

# Python
open\s*\(\s*[^,)]*\+
open\s*\(\s*f"[^"]*\{
open\s*\(\s*request\.

# Node
fs\.readFile\s*\(\s*req\.
res\.sendFile\s*\(\s*req\.
fs\.createReadStream\s*\(\s*req\.

# Path patterns
\.\.[/\\]
%2e%2e
%c0%af
\\\\\\\\
```

## 5. Server-Side Template Injection (SSTI)

```regex
# Render com input
render_template_string\s*\(\s*[^,)]*\$
Template\s*\(\s*\$
Template\s*\(\s*request\.
\.render\s*\(\s*request\.

# Test payloads que devem trigger
\{\{\s*7\s*\*\s*7\s*\}\}
\$\{\s*7\s*\*\s*7\s*\}
\<%=\s*7\s*\*\s*7\s*%\>
@\(\s*7\s*\*\s*7\s*\)
```

## 6. Deserialization

```regex
# PHP
unserialize\s*\(\s*\$_
unserialize\s*\(\s*base64_decode
unserialize\s*\(\s*\$_(COOKIE|REQUEST|POST|GET)

# Python
pickle\.loads\s*\(
marshal\.loads\s*\(
yaml\.load\s*\([^)]*Loader\s*=\s*Loader  # yaml.load sem safe_load

# Java
ObjectInputStream\s*\(
\.readObject\s*\(\s*\)

# Ruby
Marshal\.load\s*\(
YAML\.load\s*\(

# .NET
BinaryFormatter\b
LosFormatter\b
JavaScriptSerializer\b
```

## 7. XXE (XML)

```regex
# PHP — sem disable_entity_loader (legacy)
new\s+DOMDocument\s*\(\s*\)
->loadXML\s*\(
simplexml_load_string\s*\([^,)]*\$

# Python — sem defusedxml
from\s+xml\.etree\s+import
xml\.etree\.ElementTree\.parse
lxml\.etree\.parse                # sem resolve_entities=False

# Java
DocumentBuilderFactory\.newInstance\s*\(\s*\)  # sem features de bloqueio
```

## 8. SSRF

```regex
# HTTP fetches com input
wp_remote_(get|post|head)\s*\(\s*\$_
file_get_contents\s*\(\s*['"]?http
fopen\s*\(\s*\$_

# Python
requests\.(get|post|put|delete)\s*\(\s*[^,)]*request\.
urllib\.request\.urlopen\s*\(\s*request\.

# Node
fetch\s*\(\s*req\.
axios\.\w+\s*\(\s*req\.
http\.get\s*\(\s*req\.

# Java
URL\(\s*[^)]*request\.
HttpClient\.send.*request\.

# Cloud metadata targets (IPs a procurar em allowlists)
169\.254\.169\.254
metadata\.google\.internal
metadata\.azure\.com
fd00:ec2::254
```

## 9. Open Redirect

```regex
# PHP
header\s*\(\s*['"]Location:.*\$_
wp_redirect\s*\(\s*\$_

# Python
redirect\s*\(\s*request\.
return\s+redirect\s*\([^)]*request\.

# Node
res\.redirect\s*\(\s*req\.
res\.location\s*\(\s*req\.

# Backend agnóstico — query params suspeitos
[?&]next=
[?&]redirect=
[?&]return=
[?&]url=
[?&]continue=
[?&]return_to=
```

## 10. Hardcoded Secrets

```regex
# AWS
AKIA[0-9A-Z]{16}
aws_secret_access_key\s*=\s*["'][^"']{40}

# Stripe
sk_live_[0-9a-zA-Z]{24,}
pk_live_[0-9a-zA-Z]{24,}
whsec_[0-9a-zA-Z]{24,}

# GitHub
gh[ps]_[A-Za-z0-9]{36}
github_pat_[A-Za-z0-9_]{82}

# Google
AIza[0-9A-Za-z_\-]{35}
ya29\.[0-9A-Za-z_\-]+

# Slack
xox[baprs]-[A-Za-z0-9-]+

# JWT (assinado, não fragmento)
eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+

# OpenAI
sk-[A-Za-z0-9]{48}

# Generic API key patterns
api[_-]?key\s*[:=]\s*["'][^"']{16,}
secret\s*[:=]\s*["'][^"']{16,}
password\s*[:=]\s*["'][^"']{6,}

# WordPress salts (defaults nunca substituídos)
'put your unique phrase here'
```

## 11. Crypto fraco

```regex
# Hashing fraco
md5\s*\(.*password
sha1\s*\(.*password
hashlib\.(md5|sha1)\s*\(

# Encryption fraca
'AES-\d+-ECB'
"AES-\d+-ECB"
DES_(encrypt|decrypt)
'des-ede-cbc'

# RNG fraco para crypto
mt_rand\s*\(
rand\s*\(
Math\.random\(\)
Random\(\)\.next                 # Java/C# Random (não SecureRandom)

# Comparação não-constante
expected\s*===?\s*received       # se contexto é hash/token
expected\.equals\s*\(            # Java em hashes
```

## 12. JWT misuso

```regex
# alg none aceito
algorithms\s*=\s*\[?\s*['"]?(none|HS256|RS256)
verify_alg\s*=\s*False
jwt\.decode\s*\([^,)]+\)         # sem algorithms parameter

# Secret fraco
'secret'
'password'
"secret"
"changeme"
'your-secret-here'
```

## 13. CSRF ausente

```regex
# WordPress
add_action\s*\(\s*['"]wp_ajax_nopriv_  # sem check_ajax_referer logo abaixo
add_action\s*\(\s*['"]admin_post_       # sem check_admin_referer

# Express
app\.(post|put|delete)\s*\(.*req\.body  # sem csurf middleware

# Django
@csrf_exempt

# Flask
@app\.route.*methods.*POST       # se sem CSRFProtect global
```

## 14. Mass Assignment

```regex
# PHP
\$user->save\s*\(\s*\$_(POST|REQUEST|GET)
wp_update_user\s*\(\s*\$_(POST|REQUEST)
->update\s*\(\s*\$request->all\(\)
->fill\s*\(\s*\$request->all\(\)

# Node
\.update\s*\(\s*req\.body\s*\)
\.create\s*\(\s*req\.body\s*\)
Object\.assign\s*\([^,]+,\s*req\.body

# Python Django
form\.save\s*\(\)                # sem fields explícitos
User\.objects\.create\s*\(\*\*request\.

# Ruby Rails
User\.update\s*\(\s*params\[
\.permit!                        # strong_params permit ALL
```

## 15. Race Conditions / TOCTOU

```regex
# Check-then-act
if\s*\(\s*[^)]*exists\s*\)[\s\S]{0,200}\.create
if\s*\(\s*\!?[^)]*used[\s\S]{0,200}\.update.*used
if\s*\(\s*balance.*>=[\s\S]{0,200}-=

# Sem lock
SELECT[\s\S]{0,200}WHERE[\s\S]{0,200}UPDATE  # sem FOR UPDATE
findOne[\s\S]{0,200}save                     # sem transação

# WordPress transients (usados como lock — mau pattern)
get_transient[\s\S]{0,200}set_transient
```

## 16. Cookies inseguros

```regex
# Sem flags
setcookie\s*\([^)]+\)            # verificar args 5 (secure) e 6 (httponly)
session\.cookie_secure\s*=\s*0
SESSION_COOKIE_SECURE\s*=\s*False

# Cookies em JS para tokens
document\.cookie\s*=
localStorage\.setItem\s*\(\s*['"](token|jwt|auth|session)
sessionStorage\.setItem\s*\(\s*['"](token|jwt|auth|session)
```

## 17. Headers inseguros / CORS

```regex
# CORS aberto
Access-Control-Allow-Origin:\s*\*[\s\S]{0,100}Access-Control-Allow-Credentials:\s*true
allow_origins\s*=\s*\[?["']\*
origin:\s*['"]?\*['"]?,\s*credentials:\s*true

# Headers faltando (procurar AUSÊNCIA destes em config)
Strict-Transport-Security
X-Content-Type-Options
X-Frame-Options
Content-Security-Policy
```

## 18. Upload inseguro

```regex
# Validação só por extensão
\$_FILES\[[^\]]+\]\['name'\][\s\S]{0,200}\.endsWith\s*\(\s*['"]\.
substr\s*\(\s*\$filename\s*,\s*-

# Move sem validação
move_uploaded_file\s*\(\s*\$_FILES
\.move\s*\(\s*[^)]+\$_FILES

# Path traversal em filename
\$_FILES\[[^\]]+\]\['name'\][\s\S]{0,200}save_path
```

## 19. Logging com PII

```regex
# Logging de payload completo
logger\.\w+\s*\(\s*[^)]*request\.body
log\.\w+\s*\(\s*[^)]*req\.body
console\.log\s*\(\s*[^)]*req\.body
print\s*\(\s*[^)]*request\.json
error_log\s*\(\s*print_r\s*\(\s*\$_

# Tokens em logs
\.info\s*\([^)]*token
\.debug\s*\([^)]*password
\.error\s*\([^)]*Authorization
```

## 20. Email Header Injection

```regex
mail\s*\(\s*\$_(POST|GET|REQUEST)
->setSubject\s*\(\s*\$_
->setTo\s*\(\s*\$_
\\r\\n.*[Bb]cc:                  # CRLF injection patterns
%0[ad]
```

## Como aplicar isto

1. Para cada categoria que estás a auditar, **percorre os patterns** mentalmente
2. Para cada match, anota localização (`ficheiro:linha`)
3. **Aplica `00-falsos-positivos-comuns.md`** para descartar matches enganadores
4. **Para os que sobram, aplica análise contextual** do `analises/<categoria>.md`
5. Reporta achados confirmados

## Princípio

> Pattern matching dá **recall** (não esqueces clássicos).
> Análise contextual dá **precision** (não reportas falsos positivos).
> **Combinas as duas** para qualidade.
