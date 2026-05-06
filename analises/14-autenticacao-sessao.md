# Análise — Autenticação e Sessão

> Login é a porta da frente. Aqui descobre-se se está aberta, se tem fechadura fraca, ou se alguém deixou a chave debaixo do tapete.

## O que procurar

### Login
- Sem rate limit (brute force livre)
- Sem account lockout após N falhas
- Mensagens distintas para "user inexistente" vs "password errada" → user enumeration
- Tempo de resposta diferente para user válido vs inválido → timing oracle
- Login por GET (`?user=x&pass=y` em URLs/logs/referrer)
- HTTP em vez de HTTPS no formulário de login
- Sem CAPTCHA depois de N tentativas suspeitas

### Password policy
- Aceita passwords muito curtas (`< 8 chars`)
- Aceita passwords comuns (`password`, `123456`, `qwerty`)
- Sem verificação contra HaveIBeenPwned (opcional mas excelente)
- Limite máximo demasiado baixo (`< 64 chars` impede passphrases)
- Restrições estranhas (sem espaços, sem certos símbolos) que enfraquecem entropia

### MFA / 2FA
- Sem MFA para contas administrativas
- TOTP secret armazenado em plaintext na BD
- Códigos de backup não rotacionados após uso
- "Lembrar este dispositivo" sem expiração
- MFA bypass via reset password sem MFA challenge

### Sessão
- `session_id` previsível ou curto
- Sessão **não regenerada** após login (`session_regenerate_id(true)`)
- Sessão **não regenerada** após mudança de password
- Sessões eternas sem timeout
- Sem invalidação de sessões antigas após reset de password
- Cookies de sessão sem `Secure`, `HttpOnly`, `SameSite`
- Múltiplas sessões simultâneas sem aviso ao user

### Reset de password
- Token de reset previsível (timestamp, sequencial, MD5 de timestamp)
- Token sem expiração ou expiração demasiado longa (`> 1h`)
- Token reutilizável após uso
- Reset confirma se email existe (enumeração)
- Sem invalidação de sessões ativas após reset
- Link de reset enviado por HTTP

### Recuperação / "Esqueci-me"
- Perguntas de segurança fracas ("nome do meu cão") armazenadas em plaintext
- Reset baseado em SMS sem proteção SIM swap
- Reset por email sem rate limit (spam para vítima)

## Sinais de alarme

```php
// BAD — login sem proteção
add_action('wp_authenticate', function ($username, $password) {
    // ... só verifica password ...
});

// GOOD — com rate limit e lockout
add_filter('authenticate', function ($user, $username, $password) {
    if (empty($username)) return $user;

    $key = 'login_attempts_' . md5($_SERVER['REMOTE_ADDR'] . '|' . $username);
    $attempts = (int) get_transient($key);

    if ($attempts >= 5) {
        return new WP_Error('locked', 'Demasiadas tentativas. Tenta dentro de 15 min.');
    }

    if (is_wp_error($user) || !$user) {
        set_transient($key, $attempts + 1, 15 * MINUTE_IN_SECONDS);
        // Mensagem genérica — não revela se user existe
        return new WP_Error('failed', 'Credenciais inválidas.');
    }

    delete_transient($key);
    return $user;
}, 30, 3);
```

```php
// BAD — sessão não regenerada
function login($user) {
    $_SESSION['user_id'] = $user->ID;
}

// GOOD
function login($user) {
    session_regenerate_id(true); // novo ID, invalida o antigo
    $_SESSION['user_id'] = $user->ID;
    $_SESSION['login_time'] = time();
}
```

```php
// BAD — token reset previsível
$token = md5($user->ID . time());

// GOOD
$token = bin2hex(random_bytes(32));
update_user_meta($user->ID, '_pwd_reset_token', wp_hash($token));
update_user_meta($user->ID, '_pwd_reset_expires', time() + 30 * MINUTE_IN_SECONDS);
```

```php
// Após reset bem-sucedido
function on_password_reset($user) {
    // Invalidar TODAS as sessões deste user
    $sessions = WP_Session_Tokens::get_instance($user->ID);
    $sessions->destroy_all();

    // Limpar tokens de reset
    delete_user_meta($user->ID, '_pwd_reset_token');
    delete_user_meta($user->ID, '_pwd_reset_expires');
}
add_action('after_password_reset', 'on_password_reset');
```

```php
// Cookie de sessão correto
session_set_cookie_params([
    'lifetime' => 0,            // sessão de browser
    'path'     => '/',
    'domain'   => '',           // só este host
    'secure'   => true,         // só HTTPS
    'httponly' => true,         // JS não acede
    'samesite' => 'Lax',        // CSRF mitigation
]);
```

## Mensagem de login — fazer bem

| Situação | NÃO digas | Diz |
|---|---|---|
| User não existe | "User não encontrado" | "Credenciais inválidas" |
| Password errada | "Password errada" | "Credenciais inválidas" |
| Conta bloqueada | "Conta bloqueada por 15 min" | "Credenciais inválidas" *(opção: avisar **só por email**)* |
| User existe mas sem confirmar email | "Confirma o teu email" | "Credenciais inválidas" *(enviar confirmação se aplicável)* |

A consistência é o que mata enumeração.

## Quick wins (faz isto antes de entregar)

- [ ] Rate limit em login (5 tentativas / 15 min por IP+user)
- [ ] Lockout temporário de conta após N falhas
- [ ] Mesma mensagem genérica para todas as falhas de login
- [ ] `session_regenerate_id(true)` após login bem-sucedido
- [ ] Cookies de sessão com `Secure + HttpOnly + SameSite=Lax`
- [ ] Tokens de reset por `random_bytes(32)`, expiração 30 min, single-use
- [ ] Invalidação de sessões após reset de password
- [ ] MFA obrigatório para admins
- [ ] Password mínima 12 chars, sem máximo abaixo de 64
- [ ] HTTPS obrigatório no formulário de login

## Falsos positivos
- Sites internos atrás de VPN com IP allowlist podem dispensar rate limit *(mas não devem)*
- "Lembrar-me" prolongado em apps de baixo risco — aceitável com cookie HttpOnly+Secure

## Severidade — em linguagem honesta
- **Crítico:** sem rate limit + user enumeration + sem MFA admin → spray viável
- **Crítico:** reset de password com token previsível
- **Alto:** sessão não regenerada após login (fixation)
- **Alto:** mensagens distintas em login (enumeração)
- **Médio:** sem MFA para users normais
- **Médio:** cookies sem `SameSite`
- **Baixo:** password policy aceita 8 chars (preferir 12)

---

## Federated Identity — SAML, OIDC, JWKS

Para apps enterprise com SSO. Separado da auth padrão acima porque os erros são diferentes.

### OIDC / OAuth 2.0 — pegadas críticas

#### 1. State parameter ausente (CSRF em OAuth flow)

**BAD:**
```javascript
res.redirect(`https://accounts.google.com/o/oauth2/v2/auth?client_id=${ID}&redirect_uri=${REDIRECT}&response_type=code&scope=openid+email`);
```

Sem `state`, atacante força user a fazer login com a sua própria conta atacante (account takeover via login CSRF).

**GOOD:**
```javascript
const state = crypto.randomBytes(32).toString('hex');
req.session.oauthState = state;
res.redirect(`https://accounts.google.com/o/oauth2/v2/auth?client_id=${ID}&redirect_uri=${REDIRECT}&response_type=code&scope=openid+email&state=${state}&nonce=${nonce}`);

// No callback:
if (req.query.state !== req.session.oauthState) {
  return res.status(400).send('Invalid state');
}
```

#### 2. Nonce ausente em OIDC (replay)

`nonce` no auth request → ID token contém-no → app valida.

```javascript
const nonce = crypto.randomBytes(32).toString('hex');
req.session.oidcNonce = nonce;
// ... include nonce in /authorize URL

// On token receipt:
const decoded = jwt.decode(idToken);
if (decoded.nonce !== req.session.oidcNonce) {
  throw new Error('Invalid nonce');
}
```

#### 3. PKCE ausente (public clients)

Apps mobile/SPA são "public clients" sem secret. PKCE protege contra interception:

```javascript
const codeVerifier = crypto.randomBytes(32).toString('base64url');
const codeChallenge = crypto.createHash('sha256').update(codeVerifier).digest('base64url');

// No auth request:
const url = `${AUTH_URL}?...&code_challenge=${codeChallenge}&code_challenge_method=S256`;

// No token request:
const tokenRes = await fetch(TOKEN_URL, {
  method: 'POST',
  body: new URLSearchParams({
    code, code_verifier: codeVerifier, redirect_uri, client_id
  })
});
```

#### 4. JWKS validation incorreta

JWKS = JSON Web Key Set, endpoint do IdP com chaves públicas para verificar JWTs.

**BAD** — fetch JWKS uma vez, cache forever:
```javascript
const jwks = await fetch('https://issuer/.well-known/jwks.json').then(r => r.json());
// nunca mais atualiza
```

IdP rota chaves periodicamente. Cache stale → tokens novos rejeitados ou (pior) tokens com chave revogada aceites.

**GOOD** — usar biblioteca com refresh:
```javascript
import jwksClient from 'jwks-rsa';

const client = jwksClient({
  jwksUri: 'https://issuer/.well-known/jwks.json',
  cache: true,
  cacheMaxAge: 600000,  // 10 min
  rateLimit: true,
  jwksRequestsPerMinute: 5
});

function verifyToken(token) {
  return new Promise((resolve, reject) => {
    jwt.verify(token, getKey, {
      algorithms: ['RS256'],  // CRITICAL — não aceitar HS256 quando usas RSA
      issuer: 'https://issuer',
      audience: 'my-app'
    }, (err, decoded) => err ? reject(err) : resolve(decoded));
  });
}

function getKey(header, callback) {
  client.getSigningKey(header.kid, (err, key) => {
    callback(err, key?.getPublicKey());
  });
}
```

#### 5. Algorithm confusion (HS256 vs RS256)

**Atacante envia JWT com `alg: HS256`** assinado com a public key do issuer (que é... pública). App config'd para verificar com mesma public key como HMAC secret = aceita.

**Mitigação:**
- **Sempre** especificar algoritmos esperados em `jwt.verify(token, key, { algorithms: ['RS256'] })`
- Bibliotecas modernas (`jose`, `jsonwebtoken` recente) bloqueiam por default

#### 6. None algorithm

`{"alg": "none"}` — JWT sem signature. Bibliotecas antigas aceitavam.

**Fix:** atualizar libs + sempre passar `algorithms: [...]`.

#### 7. Open redirect via redirect_uri

**BAD** — IdP retorna ao `redirect_uri` do request:
```
GET /callback?redirect_uri=https://evil.com&code=xxx
```

App processa code mas redireciona user para `evil.com`.

**Fix:**
- IdP deve ter allowlist exata de `redirect_uri` (não pattern matching)
- App não interpola `redirect_uri` em redirects pós-login

### SAML — pegadas críticas

#### 1. XML Signature Wrapping (XSW)

Atacante move/envolve elementos XML do assertion mantendo signature válida.

**Mitigação:**
- Bibliotecas modernas (`@auth0/passport-saml`, `OneLogin php-saml`) têm proteções
- Verificar com `xmlsec1` ou ferramenta dedicada
- Não escrever validação SAML à mão

#### 2. SAML signature verification ausente

```python
# BAD — só decode, sem verify
parsed = parse_xml(saml_response)
user = parsed.find('NameID').text
```

**FIX:** sempre verificar signature contra IdP cert.

#### 3. Replay attacks

Assertions devem ter:
- `NotOnOrAfter` validado
- `OneTimeUse` ou `InResponseTo` cross-check
- App tracks IDs já consumidos (cache curto)

#### 4. Open IdP (any origin pode iniciar SP-initiated)

Atacante força user a logar como atacante (login CSRF). Mitigação: verificar `RelayState` e bind a session original.

### Quick wins federated

- [ ] OAuth state parameter sempre presente + verified
- [ ] OIDC nonce em apps que aceitam ID tokens
- [ ] PKCE para mobile/SPA (S256 method)
- [ ] JWKS com cache + refresh + rate limit
- [ ] `algorithms: [...]` explícito em todas `jwt.verify`
- [ ] Issuer + audience validation em JWTs
- [ ] `redirect_uri` allowlist exata no IdP config
- [ ] SAML response signature verified
- [ ] SAML assertion replay tracking
- [ ] Sem aceitar `alg: none`
- [ ] Bibliotecas SAML/OIDC mantidas (CVEs frequentes)
- [ ] IdP config audited periodicamente (allowed redirect URIs, scopes)

### Falsos positivos federated

- App backend-confidential client sem PKCE (usa client_secret) — OK
- JWT `HS256` legítimo se app gera + verifica com mesma secret (não usa público)
- Cache JWKS curto durante migration entre IdPs — temporário aceitável

### Severidade federated

- **Crítico:** SAML sem signature verification, JWT `alg: none` aceite, algorithm confusion possível
- **Alto:** OAuth sem state (login CSRF), JWKS sem refresh
- **Alto:** SAML XSW exploitable
- **Médio:** PKCE ausente em mobile, redirect_uri pattern em vez de exato
- **Baixo:** nonce ausente em flow não-OIDC

### Cross-references federated

- [`permissoes.md`](permissoes.md)
- [`../outras-areas/multi-tenant-saas.md`](../outras-areas/multi-tenant-saas.md) — IdP por tenant
- [`tokens.md`](tokens.md) — JWT storage
