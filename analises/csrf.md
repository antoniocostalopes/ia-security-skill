# Análise — CSRF (Cross-Site Request Forgery)

## O que procurar

### WordPress
- Formulários sem `wp_nonce_field('action', 'nome')`.
- Handlers sem `check_admin_referer()` / `check_ajax_referer()` / `wp_verify_nonce()`.
- Hooks `admin_post_*`, `wp_ajax_*`, `wp_ajax_nopriv_*` sem verificação de nonce.
- Endpoints REST sem `permission_callback` que valide nonce ou capability.

### Genérico
- Endpoints state-changing (POST/PUT/DELETE/PATCH) que mudam estado **sem** token CSRF.
- Endpoints state-changing aceitando GET (`?action=delete&id=42`).
- Cookies de sessão sem `SameSite=Lax|Strict`.
- APIs com auth por cookie sem header custom (`X-Requested-With`) validado.
- Falta de verificação de `Origin` / `Referer` em formulários sensíveis.

## Sinais de alarme

```php
// BAD
add_action('admin_post_delete_user', 'do_delete');
function do_delete() {
    wp_delete_user($_POST['user_id']); // sem nonce, sem capability
}

// GOOD
add_action('admin_post_delete_user', 'do_delete');
function do_delete() {
    if (!current_user_can('delete_users')) wp_die('Sem permissão');
    check_admin_referer('delete_user_' . $_POST['user_id']);
    wp_delete_user(absint($_POST['user_id']));
}

// Form
<form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
  <?php wp_nonce_field('delete_user_' . $user_id); ?>
  <input type="hidden" name="action" value="delete_user">
  <input type="hidden" name="user_id" value="<?php echo (int)$user_id; ?>">
  <button>Apagar</button>
</form>
```

```php
// AJAX
add_action('wp_ajax_save_settings', function () {
    check_ajax_referer('save_settings_nonce'); // valida nonce
    if (!current_user_can('manage_options')) wp_send_json_error('forbidden', 403);
    // ...
});
```

## REST API
```php
register_rest_route('myplugin/v1', '/settings', [
    'methods'  => 'POST',
    'callback' => 'save_settings',
    'permission_callback' => function () {
        return current_user_can('manage_options'); // nonce verificado pelo core se enviado em X-WP-Nonce
    },
]);
```

## Defesa em SPAs / APIs modernas
- **Double-submit cookie** ou **synchronizer token**.
- **SameSite=Lax** (default em browsers modernos) bloqueia a maioria dos ataques cross-site.
- Header custom (`X-Requested-With: XMLHttpRequest`) validado server-side.
- Verificação de `Origin` contra allowlist.

## Quick wins (faz isto antes de entregar)

- [ ] CSRF middleware ativo no framework (Express csurf alternative, Django CsrfViewMiddleware, Rails protect_from_forgery, Spring Security CSRF, Laravel `@csrf`)
- [ ] Cookies de sessão com `SameSite=Lax` (mínimo) ou `Strict`
- [ ] Cookies de sessão com `Secure + HttpOnly`
- [ ] Endpoints state-changing rejeitam GET (apenas POST/PUT/DELETE/PATCH)
- [ ] WordPress: `wp_nonce_field()` em todos os forms + `check_admin_referer()` nos handlers
- [ ] APIs com cookies validam `Origin`/`Referer` header contra allowlist
- [ ] APIs Bearer-only podem dispensar CSRF (mas precisam proteção XSS robusta)
- [ ] Webhooks externos excluídos de CSRF mas validam HMAC signature
- [ ] Plus: ver `frameworks/web/<framework>.md` para implementação específica

## Falsos positivos
- Endpoints **read-only** (GET sem efeitos colaterais) não precisam de CSRF.
- APIs com auth **stateless** (Bearer JWT em header) **não** são vulneráveis a CSRF clássico (mas verificar XSS para roubar o token).
- Endpoints de login podem dispensar nonce, mas devem ter rate limiting.

## Severidade típica
- Ação destrutiva sem CSRF (delete user, change email/password): **Crítico**
- Mudar configuração de plugin: **Alto**
- Ação reversível com pouco impacto: **Médio**
