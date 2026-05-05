# Análise — Webhooks, APIs e Integrações

## O que procurar

### Webhooks recebidos (inbound)

#### Sem verificação de assinatura
- Endpoint que aceita qualquer POST e atua (cobrar, criar conta, marcar pago).
- Assinatura HMAC ausente ou não verificada.
- Comparação não constante (`==` em vez de `hash_equals`).

```php
// BAD
add_action('rest_api_init', function() {
    register_rest_route('x/v1', '/webhook/stripe', [
        'methods' => 'POST',
        'callback' => function($req) {
            $event = $req->get_json_params();
            if ($event['type'] === 'payment_intent.succeeded') {
                mark_paid($event['data']['object']['metadata']['order_id']);
            }
        },
        'permission_callback' => '__return_true',
    ]);
});

// GOOD — verificar assinatura Stripe
register_rest_route('x/v1', '/webhook/stripe', [
    'methods' => 'POST',
    'callback' => 'handle_stripe',
    'permission_callback' => '__return_true',
]);

function handle_stripe(WP_REST_Request $req) {
    $payload   = $req->get_body();
    $signature = $req->get_header('stripe_signature');
    $secret    = getenv('STRIPE_WEBHOOK_SECRET');

    try {
        $event = \Stripe\Webhook::constructEvent($payload, $signature, $secret);
    } catch (Exception $e) {
        return new WP_Error('invalid_sig', 'invalid', ['status' => 400]);
    }
    // processar $event
}
```

#### Sem proteção replay
- Aceitar o mesmo `event_id` várias vezes.
- Sem janela de timestamp (atacante captura e reenvia).

```php
// Idempotência
$event_id = $event->id;
if (get_transient("webhook_seen_$event_id")) {
    return new WP_REST_Response(['ok' => true], 200); // já processado
}
set_transient("webhook_seen_$event_id", 1, DAY_IN_SECONDS);

// Janela timestamp (5 min)
if (abs(time() - $event->created) > 300) {
    return new WP_Error('stale', 'stale', ['status' => 400]);
}
```

#### Trust no payload
- Confiar em `amount`, `currency`, `email` que vêm no webhook sem reconfirmar com a API.
- Atacante pode forjar valores se assinatura for fraca.

```php
// MELHOR — re-fetch da API com o ID do evento
$intent = \Stripe\PaymentIntent::retrieve($event->data->object->id);
if ($intent->status === 'succeeded' && $intent->amount === $expected) {
    mark_paid(...);
}
```

### Integrações outbound (chamadas a APIs externas)

#### SSRF (Server-Side Request Forgery)
- URLs vindas do utilizador usadas em chamadas server-side:
  - `wp_remote_get($_POST['url'])`
  - `curl_init($input)`
  - `file_get_contents($url)` com `allow_url_fopen`
- Permitem aceder a metadados cloud (`http://169.254.169.254`), redes internas, `file://`, `gopher://`.

```php
// BAD
$response = wp_remote_get($_POST['url']);

// GOOD — validar e allowlist
function safe_fetch($url) {
    if (!wp_http_validate_url($url)) return false;
    $parts = wp_parse_url($url);
    if (!in_array($parts['scheme'] ?? '', ['http', 'https'], true)) return false;

    // Bloquear IPs internos
    $ip = gethostbyname($parts['host']);
    if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) === false) {
        return false;
    }

    return wp_remote_get($url, ['timeout' => 5, 'redirection' => 0]);
}
```

#### SSL/TLS
- `verify_ssl => false` em chamadas wp_remote_*.
- `CURLOPT_SSL_VERIFYPEER => false` em curl.
- Aceitar certificados auto-assinados em produção.

```php
// BAD
wp_remote_post($url, ['sslverify' => false]);

// GOOD (default, mas explícito)
wp_remote_post($url, ['sslverify' => true]);
```

#### Credenciais
- Mesma API key dev/staging/prod.
- Credenciais commitadas (ver `tokens.md`).
- Tokens com escopo demasiado largo (admin quando bastava read).

#### Rate limit / timeout
- Sem timeout (pode travar requests do user).
- Sem retry com backoff exponencial.
- Sem circuit breaker (continuar a martelar API caída).

```php
wp_remote_post($url, [
    'timeout'     => 5,
    'redirection' => 3,
    'sslverify'   => true,
    'headers'     => ['Authorization' => 'Bearer ' . getenv('API_TOKEN')],
]);
```

#### Validação da resposta
- Confiar no payload da API externa sem validar (XSS armazenado).
- Não verificar status code antes de usar `body`.

### XML-RPC / SOAP / Legacy
- XXE (XML External Entity): `libxml_disable_entity_loader(true)` ou usar `LIBXML_NOENT` corretamente.
- SOAP com WSDL externa controlável → SSRF.

### GraphQL
- Introspection ativa em produção (revela schema).
- Sem rate limit por complexidade de query (deep nesting DoS).
- Falta de auth por field.

## Headers de webhook a verificar

| Provedor | Header | Como verificar |
|---|---|---|
| Stripe | `Stripe-Signature` | `\Stripe\Webhook::constructEvent` |
| GitHub | `X-Hub-Signature-256` | `hash_hmac('sha256', $body, $secret)` |
| Slack | `X-Slack-Signature` + `X-Slack-Request-Timestamp` | sha256 de `v0:ts:body` |
| Twilio | `X-Twilio-Signature` | SDK |
| WooCommerce | `X-WC-Webhook-Signature` | base64(hmac sha256) |
| Mailgun | `signature.signature` | hmac sha256 de `ts.token` |

## Comparação constante
```php
// BAD — vulnerável a timing attack
if ($expected === $received) { ... }

// GOOD
if (hash_equals($expected, $received)) { ... }
```

## Quick wins (faz isto antes de entregar)

### Webhooks recebidos
- [ ] Verificação de assinatura HMAC obrigatória (com `hash_equals` / `crypto.timingSafeEqual` — comparação constante)
- [ ] Janela de timestamp (±5 min) para anti-replay
- [ ] Idempotência via `event_id` deduplication
- [ ] Re-fetch de dados críticos (montante, status) via API do provider — não confiar só no payload
- [ ] Resposta 200 mesmo para eventos duplicados (provider re-tenta se 4xx/5xx)
- [ ] Logs com `event_id` para audit trail

### Integrações outbound
- [ ] HTTP client com **timeout** explícito (3-5s connect, 10-30s read)
- [ ] `sslverify` / `verify=true` sempre (nunca `false` em prod)
- [ ] URLs vindas do user → allowlist + bloqueio de IPs privados (anti-SSRF)
- [ ] Não seguir redirects automaticamente em código SSRF-prone
- [ ] Credenciais por env var ou Vault, **diferentes** por ambiente (dev/staging/prod)
- [ ] Retry com backoff exponencial + circuit breaker (não martelar API caída)
- [ ] Tokens com escopo mínimo (read-only se write não necessário)
- [ ] Plus: ver `analises/20-open-redirect-ssrf.md` para SSRF avançado

## Falsos positivos
- Webhooks internos numa rede privada com mTLS já fazem parte da auth.
- Endpoints expostos mas que apenas registam para análise (sem efeito) podem ser mais permissivos.

## Severidade típica
- Webhook de pagamento sem assinatura: **Crítico**
- SSRF com acesso a metadados cloud: **Crítico**
- `sslverify => false` em produção: **Alto**
- Sem proteção replay em ação reversível: **Médio**
- Sem timeout: **Baixo** (DoS)
- GraphQL introspection em produção: **Médio**
