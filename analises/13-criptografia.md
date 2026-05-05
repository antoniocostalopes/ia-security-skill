# Análise — Criptografia

> Aqui é onde se descobre que o sistema está a guardar passwords como MD5 e a "encriptar" com base64. A boa notícia: quase tudo se arranja em poucas linhas.

## O que procurar

### Hashing de passwords
- `md5()`, `sha1()`, `sha256()` para passwords — **não** são hashes de password, são *digest functions*
- `crypt()` sem salt explícito ou com salt fraco
- Iterações baixas em PBKDF2 (`< 100k`)
- Falta de salt único por user
- Comparação de hashes com `==` (timing attack)

### JWT
- `alg: none` aceito pelo verificador
- `RS256 → HS256` confusion (chave pública usada como segredo)
- Segredo HMAC fraco (`secret`, `password`, `123456`, default da lib)
- Sem validação de `exp`, `iss`, `aud`, `nbf`
- Token guardado em `localStorage` em apps com XSS possível
- `kid` injection (header `kid` aponta para ficheiro arbitrário)

### Encriptação simétrica
- ECB mode (padrões visíveis)
- CBC sem MAC (padding oracle)
- IV reutilizado / IV previsível / IV constante
- Hardcoded keys
- Confundir encoding (base64) com encriptação
- AES-128-ECB, DES, 3DES, RC4, Blowfish em código novo

### Random / tokens
- `rand()`, `mt_rand()`, `Math.random()` para tokens de segurança
- `uniqid()` como token (timestamp-based, previsível)
- Tokens curtos (< 16 bytes de entropia)

### TLS / certificados
- `verify_ssl => false` em chamadas HTTP
- `CURLOPT_SSL_VERIFYPEER => false`
- Aceitar certificados auto-assinados em produção

## Sinais de alarme

```php
// BAD — passwords
$hash = md5($password);
$hash = sha1($password . 'salt_fixo');
if ($db_hash == md5($_POST['password'])) { ... }

// GOOD
$hash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
// ou em WordPress
$hash = wp_hash_password($password);

if (password_verify($_POST['password'], $db_hash)) { ... }
// ou em WordPress
if (wp_check_password($_POST['password'], $db_hash, $user_id)) { ... }
```

```php
// BAD — tokens
$token = md5(time() . rand());
$reset_code = substr(md5(uniqid()), 0, 8);

// GOOD
$token = bin2hex(random_bytes(32));   // 64 chars hex, 256 bits
$reset_code = wp_generate_password(32, false);
```

```php
// BAD — encriptação
$cipher = openssl_encrypt($data, 'AES-128-ECB', $key);
$cipher = openssl_encrypt($data, 'AES-256-CBC', $key, 0, '0000000000000000');

// GOOD — AEAD (autentica + encripta)
$iv = random_bytes(12); // 96 bits para GCM
$cipher = openssl_encrypt($data, 'AES-256-GCM', $key, OPENSSL_RAW_DATA, $iv, $tag);
$payload = base64_encode($iv . $tag . $cipher);

// Decriptar
$raw = base64_decode($payload);
$iv = substr($raw, 0, 12);
$tag = substr($raw, 12, 16);
$cipher = substr($raw, 28);
$plain = openssl_decrypt($cipher, 'AES-256-GCM', $key, OPENSSL_RAW_DATA, $iv, $tag);
```

```php
// BAD — comparação de hash
if ($expected == $received) { ... }

// GOOD — constante no tempo
if (hash_equals($expected, $received)) { ... }
```

```js
// BAD
const token = Math.random().toString(36);

// GOOD
const buf = new Uint8Array(32);
crypto.getRandomValues(buf);
const token = Array.from(buf, b => b.toString(16).padStart(2, '0')).join('');
```

## JWT — checklist rápido

```php
use Firebase\JWT\JWT;
use Firebase\JWT\Key;

// Validar
try {
    $payload = JWT::decode(
        $token,
        new Key(getenv('JWT_SECRET'), 'HS256') // alg explícito, não inferir
    );
    if (($payload->iss ?? '') !== 'https://meusite.tld') throw new Exception('iss');
    if (($payload->aud ?? '') !== 'meu-app')              throw new Exception('aud');
    if (($payload->exp ?? 0) < time())                    throw new Exception('exp');
} catch (Exception $e) {
    http_response_code(401);
    exit;
}
```

## Quick wins (faz isto antes de entregar)

- [ ] Substituir todos os `md5()`/`sha1()` em passwords por `password_hash` / `wp_hash_password`
- [ ] Substituir `rand()`/`mt_rand()`/`uniqid()` para tokens por `random_bytes()` / `wp_generate_password()`
- [ ] Adicionar `hash_equals()` em todas as comparações de hash/token
- [ ] Forçar `alg` explícito em JWT verifications (nunca inferir do header)
- [ ] Verificar `exp`, `iss`, `aud` em JWTs
- [ ] Trocar `AES-*-ECB` ou `AES-*-CBC` (sem MAC) por `AES-256-GCM`
- [ ] Confirmar `sslverify => true` em todas as chamadas HTTP outbound

## Falsos positivos
- `md5()` para checksums não-segurança (cache keys, ETags) — OK
- `crypt()` em código legacy com salt válido — verificar antes de declarar mau
- Tokens curtos para coisas não sensíveis (ex.: ID de tracking) — OK

## Severidade — em linguagem honesta
- **Crítico:** passwords em MD5/SHA1, JWT `alg:none` aceito, hardcoded encryption key partilhada com cliente
- **Alto:** ECB mode com dados sensíveis, comparação de tokens com `==`, RNG fraco para password reset
- **Médio:** PBKDF2 com poucas iterações, falta de validação `exp` em JWT
- **Baixo:** Cipher suites antigas suportadas mas com TLS 1.3 disponível
