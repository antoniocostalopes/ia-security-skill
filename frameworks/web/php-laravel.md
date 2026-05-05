# Laravel — Profile de Segurança

## Deteção
- `composer.json` com `laravel/framework`
- `artisan` na raiz
- `bootstrap/app.php`

## Auth — Laravel built-in

### Guards e providers
```php
// config/auth.php
'guards' => [
    'web'  => ['driver' => 'session',   'provider' => 'users'],
    'api'  => ['driver' => 'sanctum',   'provider' => 'users'],
],
```

### Middleware auth
```php
// routes/web.php
Route::middleware(['auth'])->group(function () {
    Route::get('/dashboard', DashboardController::class);
});

Route::middleware(['auth', 'verified', 'role:admin'])->group(function () {
    Route::get('/admin', AdminController::class);
});
```

### Gates e Policies (authorization)
```php
// AuthServiceProvider
Gate::define('update-post', fn(User $u, Post $p) => $u->id === $p->user_id);

// Controller
$this->authorize('update-post', $post);
// ou
abort_unless(Gate::allows('update-post', $post), 403);

// Policy class
php artisan make:policy PostPolicy --model=Post
// PostPolicy
public function update(User $user, Post $post): bool {
    return $user->id === $post->user_id;
}
// uso
$this->authorize('update', $post);  // Laravel deteta a policy
```

## Mass Assignment

```php
// BAD — sem $fillable
class User extends Model { /* sem $fillable definido */ }
User::create($request->all());  // role, is_admin etc. passam

// GOOD — allowlist
class User extends Model {
    protected $fillable = ['name', 'email', 'password'];
    protected $guarded = ['id', 'role', 'is_admin'];
}

// MELHOR — usar Form Request
php artisan make:request StoreUserRequest

class StoreUserRequest extends FormRequest {
    public function authorize(): bool {
        return $this->user()->can('create-user');
    }
    public function rules(): array {
        return [
            'name'  => 'required|string|max:255',
            'email' => 'required|email|unique:users',
            'password' => 'required|string|min:12',
        ];
    }
}

public function store(StoreUserRequest $request) {
    User::create($request->validated());  // só campos validated
}
```

## SQL Injection — Eloquent / Query Builder

```php
// BAD
DB::select("SELECT * FROM users WHERE name = '$name'");
User::whereRaw("name = '$name'");

// GOOD
DB::select('SELECT * FROM users WHERE name = ?', [$name]);
User::where('name', $name)->get();
User::whereRaw('name = ?', [$name]);  // bindings = OK
```

## XSS — Blade

```blade
{{-- Auto-escaped --}}
{{ $userInput }}

{{-- NÃO escaped (perigoso) --}}
{!! $userInput !!}

{{-- Atributo --}}
<div data-name="{{ $name }}">

{{-- HTML rico (controlled) --}}
{!! Purifier::clean($userHtml) !!}  {{-- mews/purifier --}}
```

## CSRF
- `VerifyCsrfToken` middleware ativo por default em rotas `web`.
- API routes (Sanctum, Passport) não usam CSRF (auth via token).
- Excluir rotas: `protected $except = ['/webhooks/*']` em `VerifyCsrfToken`.
- Form: `@csrf` directive.

## Storage / File Uploads
```php
// Validation
$request->validate([
    'avatar' => 'required|image|mimes:jpg,png|max:2048|dimensions:max_width=2000',
]);

// Store seguro (random name, sem path do user)
$path = $request->file('avatar')->store('avatars', 'public');
// Storage::disk('s3')->put(...) para storage externo
```

## Authentication helpers
```php
Auth::attempt(['email' => $email, 'password' => $password], $remember = false);
Auth::user();
Auth::logout();

// Hashing
Hash::make($password);
Hash::check($plain, $hash);

// Rate limit (built-in)
RateLimiter::for('login', fn(Request $r) =>
    Limit::perMinute(5)->by($r->email . '|' . $r->ip())
);
```

## Encryption helpers
```php
encrypt($value);  // AES-256-CBC com HMAC
decrypt($value);  // throws DecryptException

// HMAC
hash_hmac('sha256', $data, config('app.key'));

// Comparison constant-time
hash_equals($expected, $received);
```

## Common antipatterns

### `Route::any()` — aceita todos os métodos
```php
// BAD
Route::any('/admin/delete', DeleteController::class);  // GET passa

// GOOD
Route::delete('/admin/{id}', ...);  // método específico
```

### `protected $guarded = []` (vazio = tudo permitido)
- Equivalente a sem proteção. Sempre allowlist.

### `Sanctum` SPA sem domain configurado
- `SANCTUM_STATEFUL_DOMAINS` deve listar domínios SPA.
- Sem isso, CSRF não protege.

### `APP_DEBUG=true` em produção
- Stack traces, queries, env vars expostos via Whoops.

### Telescope / Horizon expostos sem auth
- `Telescope::auth()` ou `gate('viewTelescope')` obrigatório.
- Mesmo para `Horizon`.

### `php artisan serve` em produção
- Single-threaded, debug. Usar nginx + php-fpm ou Octane.

### Migrations destrutivas em prod
- `php artisan migrate:fresh` apaga BD inteira. Bloquear em prod.

### `url()` com input não validado
```php
// BAD
return redirect($request->url);  // open redirect

// GOOD
return redirect($request->url, 302, [], false /* secure */);
// ou usar redirect()->intended() / route()
```

## Quick wins

- [ ] Laravel 11+ (versões antigas EOL)
- [ ] PHP 8.2+
- [ ] `composer audit` sem Críticos/Altos
- [ ] `APP_DEBUG=false` e `APP_ENV=production` em prod
- [ ] `APP_KEY` gerado por instância (não shared)
- [ ] Form Requests para validation (não validar inline)
- [ ] `$fillable` definido em todos os Models (não `$guarded = []`)
- [ ] Policies para todas as resources
- [ ] `@csrf` em todos os forms
- [ ] Sanctum/Passport com domínios configurados
- [ ] Rate limit em login, register, password-reset
- [ ] `Hash::make()` para passwords (Bcrypt default — confirmar cost ≥ 12)
- [ ] `hash_equals` em comparações de tokens
- [ ] `encrypt()`/`decrypt()` em vez de openssl manual
- [ ] HTTPS forçado (`URL::forceScheme('https')`)
- [ ] HSTS via middleware
- [ ] Telescope / Horizon com auth gate
- [ ] Logs sem PII (`Log::info()` cuidadoso com payloads)
- [ ] Queue jobs idempotentes (anti-replay)
- [ ] Storage com `'public'` disk fora do webroot acessível direto
