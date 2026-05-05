# Análise — Headers HTTP de Segurança

> Quick wins puros. Cinco linhas de config = aumento direto de score em qualquer scanner. Faz isto antes de entregar.

## O que procurar

### Headers em falta (importantes)

| Header | Para quê |
|---|---|
| `Strict-Transport-Security` | Força HTTPS — impede downgrade |
| `Content-Security-Policy` | Limita o que o browser executa — defesa anti-XSS |
| `X-Content-Type-Options: nosniff` | Impede MIME sniffing |
| `X-Frame-Options` ou `frame-ancestors` em CSP | Anti-clickjacking |
| `Referrer-Policy` | Controla o que vaza no `Referer` |
| `Permissions-Policy` | Desativa APIs sensíveis (geo, mic, camera) |

### Headers que vazam info (devem ser removidos)

- `Server: Apache/2.4.41 (Ubuntu)` — versão do servidor
- `X-Powered-By: PHP/7.4.3` — versão do PHP
- `X-AspNet-Version`, `X-AspNetMvc-Version`
- `X-Generator: WordPress 6.0.1` (e `<meta name="generator">`)

### Headers HTTPS / TLS

- HSTS ausente ou `max-age` baixo (`< 6 meses`)
- Sem `includeSubDomains` (deixa subdomínios vulneráveis)
- Sem `preload` (não está na lista do browser)
- HTTPS não forçado (sem redirect 301 de HTTP→HTTPS)

### Cookies (atributos)

- Sem `Secure` (cookie envia em HTTP)
- Sem `HttpOnly` (JS lê cookies de sessão)
- `SameSite` ausente ou `None` sem `Secure`
- Cookies de sessão com `Domain=.dominio.com` sem necessidade (partilha entre subdomínios)

### CORS

- `Access-Control-Allow-Origin: *` em endpoints com auth/cookies
- `Access-Control-Allow-Credentials: true` com `Origin` reflectido
- `Access-Control-Allow-Methods: *` em endpoints sensíveis

### Cache de respostas sensíveis

- Resposta autenticada com `Cache-Control: public`
- Sem `Cache-Control: no-store` em respostas com PII
- Sem `Vary: Cookie` em respostas que dependem de auth

## Receita rápida — Apache

```apache
<IfModule mod_headers.c>
  # HTTPS forçado
  Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"

  # Anti-MIME sniffing
  Header always set X-Content-Type-Options "nosniff"

  # Anti-clickjacking
  Header always set X-Frame-Options "SAMEORIGIN"

  # Referrer
  Header always set Referrer-Policy "strict-origin-when-cross-origin"

  # Permissions
  Header always set Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=()"

  # CSP — ajustar a cada projeto (ver secção CSP abaixo)
  Header always set Content-Security-Policy "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'; script-src 'self'; object-src 'none'; frame-ancestors 'self'; base-uri 'self'; form-action 'self'"

  # Esconder versões
  Header always unset X-Powered-By
  Header always unset Server
</IfModule>

# HTTP → HTTPS
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteCond %{HTTPS} off
  RewriteRule ^(.*)$ https://%{HTTP_HOST}/$1 [R=301,L]
</IfModule>
```

## Receita rápida — Nginx

```nginx
# HTTPS forçado
server {
    listen 80;
    server_name meusite.tld;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name meusite.tld;

    server_tokens off;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=()" always;
    add_header Content-Security-Policy "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'; script-src 'self'; object-src 'none'; frame-ancestors 'self'; base-uri 'self'; form-action 'self'" always;

    # Esconder header Server (requer mod ngx_headers_more)
    more_clear_headers Server;
}
```

## Receita — WordPress (via filtro)

Se não tens acesso a config de servidor:

```php
add_action('send_headers', function () {
    if (is_admin()) return;

    header('Strict-Transport-Security: max-age=31536000; includeSubDomains; preload');
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: SAMEORIGIN');
    header('Referrer-Policy: strict-origin-when-cross-origin');
    header('Permissions-Policy: geolocation=(), microphone=(), camera=(), payment=()');
    header_remove('X-Powered-By');
});

// Remover meta generator
remove_action('wp_head', 'wp_generator');

// Remover ?ver= de scripts/styles
add_filter('style_loader_src', fn($src) => remove_query_arg('ver', $src));
add_filter('script_loader_src', fn($src) => remove_query_arg('ver', $src));
```

## CSP — guia prático

CSP é o mais poderoso e o mais chato de configurar. Estratégia em 3 passos:

### Passo 1 — Modo report-only
```
Content-Security-Policy-Report-Only: default-src 'self'; report-uri /csp-report
```
Vês o que quebraria sem quebrar nada. Iteras durante 1-2 semanas.

### Passo 2 — Política base
```
default-src 'self';
img-src 'self' data: https:;
style-src 'self' 'unsafe-inline';        ← idealmente sem 'unsafe-inline', mas WP usa muito inline
script-src 'self';                       ← se possível, sem 'unsafe-inline' nem 'unsafe-eval'
font-src 'self' data:;
connect-src 'self';
object-src 'none';                       ← bloqueia Flash/Java legacy
frame-ancestors 'self';                  ← anti-clickjacking
base-uri 'self';                         ← anti-base tag injection
form-action 'self';
upgrade-insecure-requests;
```

### Passo 3 — Apertar
- Trocar `'unsafe-inline'` em scripts por **nonces** ou **hashes**
- Listar CDNs específicos em vez de wildcards
- Usar `report-to` para receber violações

### CSP com nonce em WordPress
```php
add_filter('script_loader_tag', function ($tag, $handle) {
    $nonce = wp_create_nonce('csp_script');
    return str_replace('<script ', '<script nonce="' . esc_attr($nonce) . '" ', $tag);
}, 10, 2);

add_action('send_headers', function () use (&$nonce) {
    $nonce = wp_create_nonce('csp_script');
    header("Content-Security-Policy: script-src 'self' 'nonce-{$nonce}'; ...");
});
```

## Cookies — receita

```php
// PHP genérico
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => true,
    'httponly' => true,
    'samesite' => 'Lax',
]);

// Para cookies custom
setcookie('preferencia', $valor, [
    'expires' => time() + 86400,
    'path' => '/',
    'secure' => true,
    'httponly' => true,
    'samesite' => 'Strict', // mais restrito para preferências
]);
```

```php
// WordPress — forçar Secure em cookies de auth
add_filter('secure_auth_cookie', '__return_true');
add_filter('secure_logged_in_cookie', '__return_true');
```

## CORS — receita correta

```php
// BAD — open CORS em endpoint autenticado
add_action('rest_api_init', function () {
    remove_filter('rest_pre_serve_request', 'rest_send_cors_headers');
    add_filter('rest_pre_serve_request', function ($value) {
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Credentials: true');
        return $value;
    });
});

// GOOD — allowlist
add_filter('rest_pre_serve_request', function ($value) {
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    $allowed = ['https://app.meusite.tld', 'https://staging.meusite.tld'];

    if (in_array($origin, $allowed, true)) {
        header("Access-Control-Allow-Origin: $origin");
        header('Access-Control-Allow-Credentials: true');
        header('Vary: Origin');
    }
    return $value;
});
```

## Verificar (ferramentas online)

- **securityheaders.com** — score A+ é a meta
- **observatory.mozilla.org** — análise mais completa
- **csp-evaluator.withgoogle.com** — análise específica de CSP

Antes de entregar, corre o site nestas 3 ferramentas. Score A+ no SecurityHeaders + B+ no Observatory é referência decente.

## Quick wins (faz isto antes de entregar)

- [ ] HSTS com `max-age=31536000; includeSubDomains`
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `X-Frame-Options: SAMEORIGIN` (ou `frame-ancestors` em CSP)
- [ ] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] `Permissions-Policy` mínimo (`geolocation=(), microphone=(), camera=()`)
- [ ] CSP em modo report-only para começar
- [ ] Remover `X-Powered-By`, `Server`, `<meta generator>`
- [ ] Cookies sensíveis com `Secure + HttpOnly + SameSite`
- [ ] HTTPS forçado por redirect 301
- [ ] Score A+ em securityheaders.com

## Falsos positivos
- HSTS em ambiente de dev local (HTTP) — não pôr
- CSP `'unsafe-inline'` em sites WP que usam muito inline — aceitável como fase 1, mas marcar para refactor
- `X-Frame-Options` ausente em página que **precisa** de ser embedável (ex.: widget)

## Severidade — em linguagem honesta
- **Alto:** sem HSTS num site que aceita login (downgrade attack)
- **Alto:** CSP ausente num site com user-generated content (XSS sem mitigação)
- **Médio:** sem X-Frame-Options (clickjacking)
- **Médio:** cookies de sessão sem `Secure`/`HttpOnly`
- **Baixo:** `X-Powered-By` exposto
