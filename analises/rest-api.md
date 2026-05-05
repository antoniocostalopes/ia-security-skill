# Análise — REST API Insegura

## O que procurar

### Autenticação e autorização
- `permission_callback => '__return_true'` em rotas não públicas.
- Rotas sem `permission_callback` definida (default permissivo varia).
- Auth fraca: Basic Auth sobre HTTP, query string com token.
- JWT com `alg: none`, segredo fraco, sem validação de `exp`/`iss`/`aud`.
- API keys passadas em URL (acabam em logs e referrers).

### Rate limiting
- Endpoints sem rate limit (login, OTP, search, password reset).
- Sem proteção contra enumeração (resposta diferente para user existente vs. não).

### CORS
- `Access-Control-Allow-Origin: *` em endpoints autenticados.
- `Access-Control-Allow-Credentials: true` com origin wildcard (browsers bloqueiam, mas é red flag).
- Reflexão do `Origin` sem allowlist.

### Mass assignment
- Endpoints que aceitam o body inteiro e fazem `update($body)` sem filtrar campos.

### Verbose errors
- Stack traces, query SQL, paths absolutos em respostas de erro.
- `WP_DEBUG_DISPLAY = true` em produção.

### Versionamento
- Endpoints `v1` legacy ainda expostos quando há `v2` corrigido.
- Sem deprecation policy.

### HTTP method confusion
- Endpoints state-changing aceitando GET.
- Falta de validação de método (`if ($_SERVER['REQUEST_METHOD'] === 'POST')`).

### Information disclosure
- `/wp-json/wp/v2/users` lista users (e usernames para brute force).
- Paginação sem limite máximo (`?per_page=100000`).
- Filtros que devolvem campos sensíveis (`?_fields=*`).

## Sinais de alarme

```php
// BAD
register_rest_route('x/v1', '/data', [
    'methods'  => 'GET',
    'callback' => 'get_data',
    'permission_callback' => '__return_true', // público sem necessidade
]);

// BAD — devolve user_pass
register_rest_route('x/v1', '/me', [
    'methods'  => 'GET',
    'callback' => function() {
        return get_user_by('id', get_current_user_id()); // inclui user_pass
    },
    'permission_callback' => 'is_user_logged_in',
]);

// GOOD
register_rest_route('x/v1', '/me', [
    'methods'  => 'GET',
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

```php
// Restringir /wp-json/wp/v2/users a admins
add_filter('rest_endpoints', function($endpoints) {
    if (isset($endpoints['/wp/v2/users'])) {
        unset($endpoints['/wp/v2/users']);
    }
    if (isset($endpoints['/wp/v2/users/(?P<id>[\d]+)'])) {
        unset($endpoints['/wp/v2/users/(?P<id>[\d]+)']);
    }
    return $endpoints;
});
```

## Rate limiting (exemplo simples com transients)
```php
function check_rate_limit($key, $max = 10, $window = 60) {
    $count = (int) get_transient("rl_$key");
    if ($count >= $max) wp_send_json_error('rate_limited', 429);
    set_transient("rl_$key", $count + 1, $window);
}
```

## Headers recomendados
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=()
```

## Quick wins (faz isto antes de entregar)

- [ ] Listar **todos** os endpoints e confirmar auth: cada um precisa de auth check explícito (ou ser intencionalmente público)
- [ ] Rate limiting global + agressivo em login/reset/search
- [ ] CORS com allowlist específica (sem `*` em endpoints autenticados)
- [ ] DTOs por endpoint — não devolver entidades inteiras (sem `password`, `internal_*`)
- [ ] Mass assignment bloqueado (allowlist explícita de campos aceitos)
- [ ] HTTP method explícito (não aceitar GET para state-changing)
- [ ] Paginação com `max_per_page` cap server-side
- [ ] Verbose errors **off** em produção
- [ ] Versioning: rotas legacy desativadas ou explicitamente marcadas
- [ ] Headers de segurança (HSTS, CSP, X-Content-Type-Options) — ver `analises/16-headers-http.md`
- [ ] Plus: ver `analises/23-api-modernas.md` para OAuth/GraphQL/WebSocket

## Falsos positivos
- Endpoints de busca/leitura pública (catálogo, blog) podem ser `__return_true`.
- CORS `*` em APIs **públicas read-only sem cookies** é aceitável.
- `WP_DEBUG` em ambiente de dev.

## Severidade típica
- Endpoint admin sem auth: **Crítico**
- Mass assignment levando a privilege escalation: **Crítico**
- CORS misconfigurado em endpoint autenticado: **Alto**
- Falta de rate limit em login: **Alto**
- User enumeration via REST: **Médio**
- Verbose errors: **Médio**
