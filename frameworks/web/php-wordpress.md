# WordPress — Profile de Segurança

## Deteção
- `wp-config.php`, `wp-content/`, `wp-includes/`
- `composer.json` com `roots/wordpress` ou `johnpbloch/wordpress`

## Auth & Capabilities

### Sistema de capabilities (não roles diretamente)
```php
// BAD — verificar role
if ($user->roles[0] === 'administrator') { ... }

// GOOD — verificar capability
if (current_user_can('manage_options')) { ... }
if (current_user_can('edit_post', $post_id)) { ... }
```

### Capabilities standard
| Capability | Para |
|---|---|
| `read` | qualquer logged-in |
| `edit_posts` | autor de posts |
| `publish_posts` | publicar |
| `edit_others_posts` | editar de outros |
| `manage_options` | gerir settings (admin) |
| `delete_users` | apagar utilizadores |
| `upload_files` | upload media |
| `edit_plugins` | editar plugin code (perigoso) |

### Nonces para CSRF
```php
// Form
<form method="post">
    <?php wp_nonce_field('save_settings_action', '_wpnonce'); ?>
    ...
</form>

// Handler
if (!check_admin_referer('save_settings_action')) wp_die();

// AJAX
check_ajax_referer('my_action_nonce', 'nonce');

// REST API — automático se cliente envia X-WP-Nonce
```

## REST API custom routes

```php
register_rest_route('myplugin/v1', '/items/(?P<id>\d+)', [
    'methods'  => 'GET',
    'callback' => 'get_item',
    'permission_callback' => function ($req) {
        return current_user_can('edit_posts');  // NUNCA __return_true
    },
    'args' => [
        'id' => [
            'validate_callback' => fn($v) => is_numeric($v) && $v > 0,
            'sanitize_callback' => 'absint',
        ],
    ],
]);
```

## `$wpdb` (queries)

Coberto em `analises/query-builders-orm.md`. Resumo:
- Sempre `$wpdb->prepare()` com placeholders.
- `%s` (string com aspas auto), `%d` (int), `%f` (float), `%i` (identificador WP 6.2+).
- `$wpdb->esc_like()` em `LIKE`.

## Sanitização e escape

| Necessidade | Função |
|---|---|
| Texto input single-line | `sanitize_text_field()` |
| Texto input multi-line | `sanitize_textarea_field()` |
| Email input | `sanitize_email()` |
| URL input (gravar) | `esc_url_raw()` |
| Slug | `sanitize_key()`, `sanitize_title()` |
| Inteiro positivo | `absint()` |
| HTML restrito | `wp_kses($s, $allowed_tags)` |
| Output HTML body | `esc_html()` |
| Output atributo HTML | `esc_attr()` |
| Output URL | `esc_url()` |
| Output JS string | `wp_json_encode()` |

Sempre `wp_unslash()` antes de sanitizar `$_POST`/`$_GET`.

## Hooks — secure usage

### Actions / Filters
```php
add_action('init', 'my_handler');
function my_handler() {
    // Roda em CADA request — cuidar com performance e auth
    if (!is_admin()) return;  // limitar contexto
}
```

### `admin_post_*`
```php
add_action('admin_post_my_action', 'do_action');
function do_action() {
    if (!current_user_can('manage_options')) wp_die('forbidden', 403);
    check_admin_referer('my_action_nonce');
    // ... fazer
    wp_redirect(admin_url('options-general.php?page=mypage'));
    exit;
}
```

### `wp_ajax_*` vs `wp_ajax_nopriv_*`
Coberto em `analises/endpoints-publicos.md`.

## Common antipatterns

### `__return_true` em `permission_callback`
Crítico — endpoint público sem necessidade.

### `add_filter('rest_authentication_errors', '__return_true')`
Desativa autenticação REST inteira.

### `define('DISALLOW_FILE_EDIT', false)` em produção
Permite edição de plugins/temas pelo dashboard (RCE para admin compromised).

### Hardcoded `wp-config.php` keys
```php
// BAD — defaults inalterados
define('AUTH_KEY', 'put your unique phrase here');

// GOOD — gerar em https://api.wordpress.org/secret-key/1.1/salt/
```

### Plugin updates desativados
- `define('AUTOMATIC_UPDATER_DISABLED', true)` deixa CVEs por anos.
- Pelo menos `define('WP_AUTO_UPDATE_CORE', 'minor')` para security patches.

### `xmlrpc.php` ativo sem necessidade
- Ataque de amplificação para brute force (`system.multicall`).

### `/wp-json/wp/v2/users` exposto a anónimos
- Enumeração de usernames → brute force focado.
- Restringir via filtro (ver `analises/exposicao-dados.md`).

### Plugins nulled
- Praticamente garantido ter backdoor.

### Multisite super_admin sem 2FA
- Compromete network inteira.

## Helpers de segurança nativos

| Função | Para |
|---|---|
| `wp_create_nonce($action)` | Gerar nonce |
| `wp_verify_nonce`, `check_admin_referer`, `check_ajax_referer` | Verificar |
| `current_user_can` | Capability check |
| `wp_get_current_user` | User atual |
| `wp_set_password` / `wp_check_password` | Password hashing (PHPass-based) |
| `wp_generate_password($n)` | Random string |
| `wp_hash($x, $scheme)` | HMAC-SHA1 com salts |
| `sanitize_*`, `esc_*` | Já listadas acima |
| `wp_safe_redirect($url)` | Redirect com allowlist (homewards-only por default) |

## Quick wins

- [ ] WordPress core na última versão estável
- [ ] Plugins/temas todos atualizados, sem nulled
- [ ] `WP_DEBUG = false`, `WP_DEBUG_DISPLAY = false`, `WP_DEBUG_LOG = false` em prod
- [ ] `DISALLOW_FILE_EDIT = true`, `DISALLOW_FILE_MODS = true`
- [ ] Salts gerados (não defaults)
- [ ] Permission_callback definido em **todos** os REST routes (nunca `__return_true` salvo razão clara)
- [ ] Nonces em todos os formulários POST e AJAX state-changing
- [ ] `current_user_can()` em todas as ações privilegiadas
- [ ] `xmlrpc.php` desativado se não usado (Jetpack, app móvel, alguns CRMs precisam)
- [ ] `/wp-json/wp/v2/users` restrito a admin
- [ ] 2FA para admins (Two Factor, miniOrange, etc.)
- [ ] WAF (Wordfence, Sucuri, Cloudflare)
- [ ] Rate limit no `/wp-login.php` e `/wp-login.php?action=lostpassword`
- [ ] Backups automáticos regulares (UpdraftPlus, BackWPup, ou snapshot do hosting)
- [ ] `readme.html`, `license.txt`, `phpinfo.php` removidos
- [ ] `wp-config.php` com permissões 440
- [ ] Bloqueio web de `wp-config.php`, `.env`, `*.sql.bak`, `.git/`
