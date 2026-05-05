# Symfony — Profile de Segurança

## Deteção
- `composer.json` com `symfony/framework-bundle` ou `symfony/runtime`
- `bin/console` na raiz
- `config/packages/security.yaml`

## Security bundle — config principal

```yaml
# config/packages/security.yaml
security:
    password_hashers:
        App\Entity\User: 'auto'  # Argon2 ou Bcrypt
    providers:
        app_user_provider:
            entity: { class: App\Entity\User, property: 'email' }
    firewalls:
        main:
            lazy: true
            provider: app_user_provider
            form_login:
                login_path: app_login
                check_path: app_login
                enable_csrf: true
            logout:
                path: app_logout
            remember_me:
                secret: '%kernel.secret%'
                lifetime: 604800
                path: /
                secure: true
                httponly: true
                samesite: lax
    access_control:
        - { path: ^/admin, roles: ROLE_ADMIN }
        - { path: ^/profile, roles: IS_AUTHENTICATED_FULLY }
```

## Authorization — Voters
```php
// Em controller
$this->denyAccessUnlessGranted('ROLE_ADMIN');
$this->denyAccessUnlessGranted('edit', $post);

// Voter custom
class PostVoter extends Voter {
    protected function supports(string $attribute, $subject): bool {
        return in_array($attribute, ['edit', 'delete'])
            && $subject instanceof Post;
    }
    protected function voteOnAttribute(string $attribute, $subject, TokenInterface $token): bool {
        $user = $token->getUser();
        if (!$user instanceof User) return false;
        return $subject->getAuthor()->getId() === $user->getId();
    }
}
```

## Doctrine — queries

Coberto em `analises/query-builders-orm.md`. Symfony usa Doctrine.

```php
// BAD
$em->createQuery("SELECT u FROM User u WHERE u.name = '$name'");

// GOOD
$em->createQuery("SELECT u FROM User u WHERE u.name = :name")
   ->setParameter('name', $name);

// QueryBuilder
$qb->where('u.name = :name')->setParameter('name', $name);

// Native SQL
$em->getConnection()->prepare('SELECT * FROM users WHERE name = ?')
   ->executeQuery([$name]);
```

## Twig — XSS auto-escape

```twig
{# Auto-escaped #}
{{ user.name }}

{# Não escaped — perigoso #}
{{ user.bio|raw }}

{# Escaping por contexto #}
{{ value|escape('html') }}
{{ value|escape('html_attr') }}
{{ value|escape('js') }}
{{ value|escape('css') }}
{{ value|escape('url') }}
```

## CSRF
- `enable_csrf: true` em form_login.
- Forms tipo: `csrf_protection: true` (default).
- API routes: usar JWT/OAuth (sem CSRF tokens).

```php
// Em controller, validar manualmente
if (!$this->isCsrfTokenValid('action', $request->request->get('_token'))) {
    throw new InvalidCsrfTokenException();
}
```

## Validation — Constraints
```php
use Symfony\Component\Validator\Constraints as Assert;

class UserDto {
    #[Assert\NotBlank]
    #[Assert\Length(max: 100)]
    public string $name;

    #[Assert\NotBlank]
    #[Assert\Email]
    public string $email;

    #[Assert\Choice(['user', 'guest'])]  // role nunca admin via input
    public string $role;
}

// Controller
$violations = $validator->validate($dto);
if (count($violations) > 0) { /* ... */ }
```

## File uploads

```php
use Symfony\Component\Validator\Constraints\File;

#[Assert\File(maxSize: '5M', mimeTypes: ['image/jpeg', 'image/png'])]
public ?UploadedFile $avatar = null;

// Slug name + storage seguro
$slugger = new AsciiSlugger();
$safeName = $slugger->slug(pathinfo($file->getClientOriginalName(), PATHINFO_FILENAME));
$file->move($uploadDir, $safeName . '-' . uniqid() . '.' . $file->guessExtension());
```

## Common antipatterns

### `dev` env exposto
- `app_dev.php` em produção → debug toolbar, profiler.
- Symfony 4+ usa env var `APP_ENV`.

### Profiler em produção
- `framework.profiler.enabled: true` em prod = info disclosure brutal.

### `lazy: false` em firewall
- Carrega user em todas as requests, mesmo públicas → performance + leakage potencial.

### `access_control` mal ordenado
- Regras processadas em ordem; primeira match wins. Mais específica primeiro.

### Twig `|raw` sem necessidade
- XSS armazenado se input vai para BD e depois é renderizado.

### `serializer` com tipos genéricos
```php
// BAD
$obj = $serializer->deserialize($json, 'array', 'json');

// GOOD — tipo específico + groups
$obj = $serializer->deserialize($json, UserDto::class, 'json',
    ['groups' => 'user:write']);
```

### `EventListener` com priority alta a fazer auth check
- Executa antes do firewall — pode duplicar verificações ou bypass.

## Helpers úteis

| Necessidade | Use |
|---|---|
| Random | `Symfony\Component\String\ByteString::fromRandom(32)` |
| Password hashing | `UserPasswordHasherInterface` (auto algorithm) |
| HMAC | `hash_hmac` PHP nativo |
| URL signing | `UriSigner` |
| CSRF | `CsrfTokenManager` |
| Encryption | `Symfony\Component\Crypto` ou Sodium nativo |

## Quick wins

- [ ] Symfony 6.4 LTS ou 7.x
- [ ] PHP 8.2+
- [ ] `composer audit` sem Críticos
- [ ] `APP_ENV=prod` e `APP_DEBUG=0` em produção
- [ ] Profiler **off** em prod
- [ ] `password_hashers: auto` (Argon2)
- [ ] CSRF ativo em forms
- [ ] Voters para autorização granular
- [ ] DTOs + validation constraints (sem expor entities diretamente)
- [ ] `access_control` cobre todas as áreas privadas
- [ ] `same_site: lax` em remember_me e session cookies
- [ ] Twig auto-escape ativo (default)
- [ ] Sem `|raw` salvo HTML pré-sanitizado
- [ ] Doctrine queries parametrizadas (sempre `:param` ou `?`)
- [ ] Form types com `csrf_protection: true` (default)
- [ ] Logs com Monolog handlers que sanitizam PII
- [ ] Webhooks Symfony Mercure/Notifier com signature verification
- [ ] `framework.trusted_proxies` configurado se atrás de load balancer
- [ ] `framework.trusted_hosts` para mitigar Host header injection
