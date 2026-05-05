# Análise — Exposição de Dados

## O que procurar

### PII em respostas
- Endpoints que devolvem `user_pass`, `user_activation_key`, `session_tokens`.
- `/wp-json/wp/v2/users` exposto a anónimos (revela usernames → brute force).
- APIs com `_fields=*` ou sem filtro de campos.
- Respostas que incluem emails, telefones, moradas, NIF, dados bancários sem necessidade.

### Mensagens de erro verbose
- `WP_DEBUG_DISPLAY = true` em produção.
- `display_errors = On` em php.ini.
- Stack traces, paths absolutos, queries SQL em respostas HTTP.
- Versões de software em headers (`X-Powered-By`, `Server`, meta `generator`).

### Listagem de diretórios
- `Options +Indexes` em Apache.
- `autoindex on` em Nginx.
- `/wp-content/uploads/2024/` listável.

### Endpoints WordPress sensíveis
- `/xmlrpc.php` — usado para brute force amplificado e DDoS.
- `/wp-cron.php` — pode ser invocado externamente.
- `/?author=1`, `/?author=2` — enumera usernames via redirect.
- `/wp-json/wp/v2/users` — lista users.
- `/readme.html` — versão do WP.
- `/wp-includes/`, `/wp-content/plugins/<plugin>/readme.txt` — versões.

### Logs e backups expostos
- `/error_log`, `/php_errors.log`, `/debug.log` no webroot.
- `wp-content/debug.log` acessível.
- Backups em `/backup/`, `/dump.sql`, `/db.sql`.

### Source maps / sourcecode
- `.map` files em produção (revela código original e estrutura).
- `.tsx`/`.vue`/`.jsx` servidos diretamente (mau servidor).

### Headers que vazam info
- `Server: Apache/2.4.41 (Ubuntu)` — versão.
- `X-Powered-By: PHP/7.4.3` — versão.
- `<meta name="generator" content="WordPress 6.0.1">` — versão.

## Sinais de alarme

```php
// BAD — devolve tudo
register_rest_route('x/v1', '/me', [
    'callback' => fn() => get_user_by('id', get_current_user_id()),
    'permission_callback' => 'is_user_logged_in',
]);
// Inclui user_pass, user_activation_key

// GOOD — campos explícitos
register_rest_route('x/v1', '/me', [
    'callback' => function() {
        $u = wp_get_current_user();
        return [
            'id'    => $u->ID,
            'name'  => $u->display_name,
            'email' => $u->user_email,
        ];
    },
    'permission_callback' => 'is_user_logged_in',
]);
```

## Mitigações específicas WordPress

> Equivalentes noutros stacks ver `frameworks/web/<framework>.md` — cada framework tem padrões próprios de remover meta tags, restringir endpoints introspectivos, esconder versões.

```php
// Remover meta generator
remove_action('wp_head', 'wp_generator');

// Esconder versão em scripts/styles
add_filter('style_loader_src', 'remove_ver');
add_filter('script_loader_src', 'remove_ver');
function remove_ver($src) {
    return remove_query_arg('ver', $src);
}

// Bloquear enumeração ?author=N
add_action('init', function() {
    if (!is_admin() && isset($_GET['author'])) {
        wp_die('forbidden', 403);
    }
});

// Desativar XML-RPC se não usado
add_filter('xmlrpc_enabled', '__return_false');

// Restringir REST users a admin
add_filter('rest_endpoints', function($e) {
    if (isset($e['/wp/v2/users']))                         unset($e['/wp/v2/users']);
    if (isset($e['/wp/v2/users/(?P<id>[\d]+)']))           unset($e['/wp/v2/users/(?P<id>[\d]+)']);
    return $e;
});
```

```php
// wp-config.php produção
define('WP_DEBUG', false);
define('WP_DEBUG_DISPLAY', false);
define('WP_DEBUG_LOG', false);
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', true);
@ini_set('display_errors', 0);
```

```apache
# Bloquear listagem
Options -Indexes

# Bloquear ficheiros sensíveis
<FilesMatch "(readme\.html|readme\.txt|license\.txt|debug\.log|error_log|wp-config\.php\.bak)$">
  Require all denied
</FilesMatch>
```

## Headers a remover/definir
```
# Remover
X-Powered-By
Server (ou versão)

# Adicionar
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin
Content-Security-Policy: default-src 'self'
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

## Quick wins (faz isto antes de entregar)

- [ ] DTOs/serializers em todos os endpoints (sem expor entidade direta)
- [ ] Camposlists explícitos no select (Prisma, EF Core, Eloquent, etc.) — sem `SELECT *`
- [ ] Listagem de utilizadores apenas para admins (nunca pública)
- [ ] Listagem de diretórios desativada (`Options -Indexes` / `autoindex off`)
- [ ] Headers `X-Powered-By` / `Server` minimizados ou removidos
- [ ] Meta tags `generator` removidas
- [ ] `phpinfo()`, `info.php`, `test.php`, `readme.html`, `license.txt` removidos
- [ ] DEBUG/verbose mode **off** em produção (todos os frameworks)
- [ ] Source maps `.map` não publicados em produção
- [ ] Logs (`debug.log`, `error_log`) fora do webroot
- [ ] Endpoints introspectivos (GraphQL introspection, Swagger UI) desativados ou autenticados
- [ ] Plus: ver `analises/22-logging-monitoring.md` para PII em logs

## Falsos positivos
- Dados públicos por design (catálogo, blog, autor de post público).
- `wp_get_current_user()->user_email` para o **próprio user** é aceitável (com auth).

## Severidade típica
- `user_pass` ou hashes em resposta REST: **Crítico**
- `wp-config.php` ou `.env` exposto: **Crítico**
- `debug.log` com queries/PII: **Alto**
- Enumeração de users via REST/`?author=`: **Médio**
- Versões em headers: **Baixo**
- `xmlrpc.php` ativo sem necessidade: **Médio**
