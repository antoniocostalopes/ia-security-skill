# PHP — Cartão de Segurança

## Funções e APIs perigosas

| API | Risco |
|---|---|
| `eval()`, `assert()` (com string), `create_function()` | RCE |
| `exec`, `shell_exec`, `system`, `passthru`, `proc_open`, `popen`, `` ` `` | Command injection |
| `unserialize()` | Deserialization RCE |
| `include`, `include_once`, `require`, `require_once` (com input) | LFI/RFI |
| `file_get_contents($url)`, `fopen($url)` (com `allow_url_fopen=On`) | SSRF/RFI |
| `extract($_REQUEST)` | Variable pollution |
| `parse_str` sem 2º arg | Variable pollution |
| `preg_replace` com modifier `/e` | RCE (deprecated mas legacy) |
| `mail()` direto com input | Header injection |
| `unserialize()` em sessão personalizada | RCE |

## Idiomas inseguros

### Type juggling
```php
// BAD — comparações fracas
'0e123456' == '0e789012'   // true (ambos são float 0)
'1abc' == 1                // true em PHP < 8 (cast string→int)
'admin' == 0               // true em PHP < 8 (cast)
in_array('1', [1, 2, 3])   // true (loose)

// GOOD — sempre estrito
'0e123' === '0e789'        // false
in_array('1', [1, 2, 3], true)
strcmp($a, $b) === 0
hash_equals($a, $b)        // constant-time
```

### `==` em hashes (timing attack + type juggling)
```php
// BAD
if ($db_hash == $user_hash) ...

// GOOD
if (hash_equals($db_hash, $user_hash)) ...
```

### `null`/`false`/empty confusion
```php
// BAD
if (strpos($haystack, 'admin')) ...  // 0 → false → não entra

// GOOD
if (strpos($haystack, 'admin') !== false) ...
// ou
if (str_contains($haystack, 'admin')) ...  // PHP 8+
```

### Sessão sem regeneração
```php
// BAD
session_start();
$_SESSION['user'] = $user;

// GOOD após login
session_start();
session_regenerate_id(true);  // novo ID, invalida o antigo
$_SESSION['user'] = $user;
```

### `magic_quotes_gpc` (legacy)
- Removido em PHP 5.4+. Mas código legacy pode assumir slashes automáticos. Verificar.

### SuperGlobals trust
```php
// BAD
$_SERVER['HTTP_HOST']    // vem do header Host (manipulável)
$_SERVER['HTTP_REFERER'] // manipulável
$_SERVER['REMOTE_ADDR']  // OK se não estás atrás de proxy
$_SERVER['HTTP_X_FORWARDED_FOR'] // manipulável (a menos que confies no proxy)
```

### File uploads — `$_FILES`
```php
// BAD — só verificar extensão
if (substr($filename, -4) === '.jpg') ...  // attacker.jpg.php passa

// GOOD
$mime = mime_content_type($_FILES['x']['tmp_name']);
$allowed = ['image/jpeg' => 'jpg', 'image/png' => 'png'];
if (!isset($allowed[$mime])) wp_die('tipo não permitido');
```

## Helpers seguros (stdlib + Composer comuns)

| Necessidade | Use |
|---|---|
| Random | `random_bytes(32)`, `random_int(0, 1000)` |
| Constant-time compare | `hash_equals($a, $b)` |
| Password hashing | `password_hash($pwd, PASSWORD_BCRYPT)` + `password_verify` |
| HMAC | `hash_hmac('sha256', $msg, $key)` |
| URL parsing | `parse_url()` |
| Path safety | `realpath()` + check de prefix |
| HTML escape | `htmlspecialchars($s, ENT_QUOTES \| ENT_SUBSTITUTE, 'UTF-8')` |
| Shell escape | `escapeshellarg()` (preferir array no `proc_open`) |
| Email validation | `filter_var($e, FILTER_VALIDATE_EMAIL)` |
| URL validation | `filter_var($u, FILTER_VALIDATE_URL)` |
| HTML purification | `HTMLPurifier` (evitar `strip_tags` para sanitização) |
| JWT | `firebase/php-jwt`, `lcobucci/jwt` |
| HTTP client | `Guzzle` (cuidar de `verify => true`, `timeout`) |

## Pitfalls específicos

### `unserialize` magic methods
- Mesmo objetos "inocentes" podem ter `__wakeup`, `__destruct`, `__toString` que são chamados.
- Gadget chains permitem RCE com classes da própria app/framework.
- **Substitui por `json_decode`**.

### `include` com extensão automática
```php
// BAD — PHP < 5.3 com null byte: ?page=admin%00.txt
include $_GET['page'] . '.php';

// GOOD — allowlist
$allowed = ['home', 'about'];
$page = in_array($_GET['page'], $allowed, true) ? $_GET['page'] : 'home';
include "pages/$page.php";
```

### `register_globals` (deprecated mas...)
- Removido em PHP 5.4. Código antigo pode assumir vars de `$_REQUEST` em escopo global.

### `parse_str` sem 2º arg
```php
// BAD
parse_str($_SERVER['QUERY_STRING']);  // injeta vars no escopo

// GOOD
parse_str($_SERVER['QUERY_STRING'], $vars);
```

### Sessões personalizadas com `unserialize`
- `session.serialize_handler = 'php'` ou `'php_serialize'` — usar `unserialize` internamente.
- Se sessão for editável (via cookies + segredo fraco), atacante constrói gadget chain.

### `preg_replace` com `/e`
```php
// REMOVIDO em PHP 7
preg_replace('/(\w+)/e', 'strtolower("$1")', $input);

// GOOD
preg_replace_callback('/(\w+)/', fn($m) => strtolower($m[1]), $input);
```

## Bibliotecas comuns com vulns

- **`PHPMailer` < 5.2.20** → RCE via mail header
- **`Symfony` < 5.4 LTS** → atualizar para LTS atual
- **`Laravel` < 9.x** → atualizar para LTS
- **`WordPress` core** → manter latest, com plugins atualizados
- **`Smarty` < 4.x** → SSTI

## Quick wins

- [ ] `composer audit` sem Críticos/Altos
- [ ] PHP 8.1+ (versões antigas EOL)
- [ ] `display_errors=Off`, `expose_php=Off`, `allow_url_include=Off` em prod
- [ ] `===` e `hash_equals` em comparações de segurança
- [ ] `random_bytes` para tokens (não `mt_rand`/`uniqid`)
- [ ] `password_hash` para passwords (não `md5`/`sha1`/`crypt`)
- [ ] `filter_var` para validação básica
- [ ] Sem `unserialize` de input não confiável
- [ ] Sem `include` com input dinâmico
- [ ] `session_regenerate_id(true)` após login
- [ ] PSR-7/PSR-15 middleware para auth/CSRF se aplicável
- [ ] PHPStan/Psalm com level alto na CI
