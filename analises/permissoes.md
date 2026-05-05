# Análise — Falhas de Permissão / Autorização

## O que procurar

### WordPress capabilities
- Ações administrativas sem `current_user_can($cap)`.
- Uso de `is_user_logged_in()` quando é necessária capability específica.
- Uso de `is_admin()` como verificação de permissão (é apenas contexto, **não** auth!).
- Capability errada para a ação (ex.: `read` para apagar posts).

### IDOR (Insecure Direct Object Reference)
- Acesso a recursos via ID sem verificar ownership:
  - `get_post($_GET['id'])` sem confirmar que pertence ao utilizador
  - `get_user_meta($_GET['user_id'], ...)` sem validação
- APIs REST que devolvem qualquer ID sem checks
- Download de ficheiros: `?file=42` sem verificar dono

### Privilege escalation
- Parâmetros controláveis pelo cliente que afetam permissões:
  - `role`, `user_level`, `is_admin`, `capabilities` em formulários
  - Mass assignment (`update_user_meta($id, $_POST['meta_key'], ...)`)
- Funções `wp_update_user()`, `wp_insert_user()` com array vindo direto do POST
- Reset de password sem invalidar sessão antiga

### REST API
- `permission_callback => '__return_true'` em rota não trivial
- `permission_callback` ausente (warning silencioso, mas funciona)
- Capability check apenas no callback principal (não na permission)

## Sinais de alarme

```php
// BAD — sem verificação
add_action('wp_ajax_delete_post', function() {
    wp_delete_post($_POST['id']);
});

// BAD — apenas verifica login
if (is_user_logged_in()) {
    wp_delete_post($_POST['id']);
}

// BAD — IDOR
$post = get_post(absint($_GET['id']));
echo $post->post_content; // qualquer um vê qualquer post

// GOOD
add_action('wp_ajax_delete_post', function() {
    check_ajax_referer('delete_post');
    $id = absint($_POST['id']);
    if (!current_user_can('delete_post', $id)) {
        wp_send_json_error('forbidden', 403);
    }
    wp_delete_post($id, true);
    wp_send_json_success();
});
```

```php
// REST
register_rest_route('app/v1', '/orders/(?P<id>\d+)', [
    'methods'  => 'GET',
    'callback' => 'get_order',
    'permission_callback' => function ($req) {
        $order = get_post((int)$req['id']);
        return $order
            && (int)$order->post_author === get_current_user_id();
    },
]);
```

```php
// Mass assignment — BAD
wp_update_user($_POST); // pode incluir 'role' => 'administrator'

// GOOD
wp_update_user([
    'ID'           => get_current_user_id(),
    'display_name' => sanitize_text_field($_POST['display_name']),
    'user_email'   => sanitize_email($_POST['user_email']),
]);
```

## Capabilities WordPress (referência rápida)

> Para outros frameworks ver `frameworks/web/<framework>.md` — Laravel Gates, Django Permissions, Spring `@PreAuthorize`, Rails CanCan, etc.

| Ação | Capability |
|---|---|
| Gerir opções | `manage_options` |
| Editar plugin | `edit_plugins` |
| Apagar utilizadores | `delete_users` |
| Editar post de outro | `edit_others_posts` |
| Publicar | `publish_posts` |
| Upload | `upload_files` |

## Quick wins (faz isto antes de entregar)

- [ ] Listar **todos** os endpoints/handlers e confirmar auth + authz check explícito em cada um
- [ ] Authorization framework usado consistentemente (Pundit/CanCan/Gates/Policies/Voters/`@PreAuthorize`)
- [ ] Object-level checks (ownership) em todos os recursos identificáveis por ID
- [ ] DTOs por endpoint (não bind direto para entidade — anti mass assignment)
- [ ] Allowlist de campos editáveis em update endpoints (`role`, `is_admin` **nunca** no allowlist público)
- [ ] Reset de password invalida sessões antigas
- [ ] Mudança de email/role notifica utilizador via email
- [ ] Tests anti-IDOR para cada endpoint que aceita ID
- [ ] Plus: ver `analises/23-api-modernas.md` para BOLA/BOPLA/BFLA (OWASP API Top 10)

## Falsos positivos
- Endpoints públicos por design (formulário de contacto, busca pública).
- Capability check feito num middleware/hook anterior (verifica fluxo).
- Validação por nonce + ownership implícito (ex.: o nonce só é gerado para o dono).

## Severidade típica
- IDOR em API que devolve PII de outros: **Crítico**
- Privilege escalation para admin: **Crítico**
- Falta de capability em ação administrativa: **Alto**
- Falta de check num endpoint info-disclosure menor: **Médio**
