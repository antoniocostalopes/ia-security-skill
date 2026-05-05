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
