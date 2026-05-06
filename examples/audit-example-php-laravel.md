# Exemplo de Auditoria — Laravel 10

> Few-shot reference para IAs auditarem apps Laravel.

## Input — código submetido

```
my-shop/
├── composer.json
├── .env (não commitado, mas existe)
├── routes/web.php
├── app/Http/Controllers/
│   ├── ProductController.php
│   └── UserController.php
└── app/Models/User.php
```

### `routes/web.php`
```php
<?php
use App\Http\Controllers\{ProductController, UserController};

Route::get('/products', [ProductController::class, 'search']);
Route::any('/users/{id}', [UserController::class, 'update']);
Route::get('/admin/raw-sql', [ProductController::class, 'adminQuery']);
```

### `app/Http/Controllers/ProductController.php`
```php
<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use DB;

class ProductController extends Controller {
    public function search(Request $request) {
        $name = $request->input('name');
        $products = DB::select("SELECT * FROM products WHERE name LIKE '%$name%'");
        return view('search', compact('products'));
    }

    public function adminQuery(Request $request) {
        $sql = $request->input('sql');
        return DB::select($sql);
    }
}
```

### `app/Http/Controllers/UserController.php`
```php
<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use App\Models\User;

class UserController extends Controller {
    public function update(Request $request, $id) {
        $user = User::find($id);
        $user->update($request->all());
        return response()->json($user);
    }
}
```

### `.env` (excerpt — committed acidentalmente)
```
APP_KEY=base64:notARealKeyButHardcoded123==
DB_PASSWORD=root
STRIPE_SECRET=sk_live_PLACEHOLDER_xxx
```

---

## Output — Relatório esperado da skill

```markdown
# Relatório de Segurança — my-shop

**Data:** 2026-05-06
**Auditor:** IA Security Skill v1.0.0
**Stack:** Laravel 10 · MySQL · PHP 8.x
**Ficheiros analisados:** 4

---

## 1. Score de Segurança

```
Score: 0/100
[░░░░░░░░░░░░░░░░░░░░] 0%
```

**Nível de blindagem:** **Crítico — NÃO PUBLICAR**

| Severidade | Quantidade | Peso unitário | Subtotal |
|---|---:|---:|---:|
| Crítico | 4 | -20 | -80 |
| Alto    | 3 | -10 | -30 |
| Médio   | 1 |  -4 | -4 |
| Baixo   | 1 |  -1 | -1 |
| **Total** | **9** | | **-115 (cap a 0)** |

---

## 2. Resumo para o Cliente

A app tem 4 buracos críticos: dois permitem roubo da BD inteira, um permite que qualquer pessoa se torne admin, e o `.env` com credenciais reais foi commitado por engano. **Não publicar.** Os fixes são bem conhecidos do ecossistema Laravel — meio dia de trabalho.

---

## 3. Resumo Técnico

Padrões clássicos de Laravel mal usado: `DB::select()` com concatenação direta, `$request->all()` em `update()` sem Form Request (mass assignment), endpoint admin a aceitar SQL raw do utilizador (?!), `Route::any` em endpoint state-changing. Falta CSRF protection em rota POST, falta middleware auth em endpoints sensíveis. `.env` foi committed — secret de produção comprometido. Migração rápida: Form Requests + Eloquent fluent + `auth` middleware + revogar/rotacionar secrets.

---

## 4. Mapa de Superfícies de Ataque

| # | Superfície | Localização | Auth | Exposição | Risco |
|---|---|---|---|---|---|
| 1 | GET /products | routes/web.php:4 | Nenhuma | Pública | Crítico |
| 2 | ANY /users/{id} | routes/web.php:5 | Nenhuma | Pública | Crítico |
| 3 | GET /admin/raw-sql | routes/web.php:6 | Nenhuma | Pública | Crítico |

---

## 5. Vetores Prováveis e Attack Chains

### Vetor 1 — Dump completo da BD (Crítico, 95% conf.)
- **Encadeia:** C1 (SQLi search) + C3 (admin/raw-sql sem auth)
- **Passos:**
  1. `GET /products?name=' UNION SELECT 1,2,3,4,5 FROM users--`
  2. Ou diretamente: `GET /admin/raw-sql?sql=SELECT * FROM users`
- **Tempo:** 30 segundos · **Skill:** baixa · **Detect:** sem logs

### Vetor 2 — Tornar-se admin (Crítico, 95% conf.)
- **Encadeia:** C2 (mass assignment) + ausência de auth
- **Passos:**
  1. `POST /users/123` com `{"role":"admin","is_super":true}`
  2. `update($request->all())` aceita tudo
- **Tempo:** 1 minuto · **Skill:** baixa

### Vetor 3 — Comprometimento total via .env (Crítico, 100% conf.)
- **Encadeia:** C4 (.env commitado) + clone público do repo
- **Passos:**
  1. Clone do repo público
  2. Lê `.env` → tem `STRIPE_SECRET`, `DB_PASSWORD`, `APP_KEY`
  3. Acede infraestrutura
- **Tempo:** segundos · **Detect:** zero

---

## 6. Achados Detalhados

### Críticos

#### C1. SQL Injection em search
- **Categoria:** SQL Injection
- **Confiança:** **95%**
- **Localização:** `app/Http/Controllers/ProductController.php:9`
- **Código vulnerável:**
  ```php
  $name = $request->input('name');
  $products = DB::select("SELECT * FROM products WHERE name LIKE '%$name%'");
  ```
- **Explicação:** Concatenação de input em raw query. `?name=' UNION SELECT...` extrai dados de qualquer tabela.
- **Exploração:** `GET /products?name=%27%20UNION%20SELECT%20password,1,1,1,1%20FROM%20users--`
- **Correção:**
  ```php
  use Illuminate\Support\Str;

  public function search(Request $request) {
      $name = $request->validate(['name' => 'required|string|max:100'])['name'];
      $escaped = '%' . Str::of($name)->replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_']) . '%';
      $products = Product::where('name', 'like', $escaped)->get();  // Eloquent + bindings
      return view('search', compact('products'));
  }
  ```

#### C2. Mass Assignment em UserController
- **Categoria:** Permissões / Mass Assignment
- **Confiança:** **95%**
- **Localização:** `app/Http/Controllers/UserController.php:9`
- **Código vulnerável:**
  ```php
  public function update(Request $request, $id) {
      $user = User::find($id);
      $user->update($request->all());
  ```
- **Explicação:** `$request->all()` aceita qualquer campo. `{"role":"admin"}` torna qualquer user admin. Plus: sem auth, sem ownership.
- **Exploração:** `POST /users/1` com body `{"role":"admin","email_verified_at":"2026-01-01"}`
- **Correção:**
  ```php
  // Form Request: app/Http/Requests/UpdateUserRequest.php
  class UpdateUserRequest extends FormRequest {
      public function authorize(): bool {
          return $this->user()->id === (int)$this->route('id');
      }
      public function rules(): array {
          return [
              'name'  => 'string|max:100',
              'email' => 'email|unique:users,email,' . $this->route('id'),
          ];
      }
  }

  // Controller
  public function update(UpdateUserRequest $request, $id) {
      $user = User::findOrFail($id);
      $user->update($request->validated());
      return response()->json($user->only(['id', 'name', 'email']));
  }

  // routes
  Route::middleware('auth')->put('/users/{id}', [UserController::class, 'update']);
  ```

#### C3. Endpoint /admin/raw-sql aceita SQL arbitrário
- **Categoria:** SQL Injection / Exposição
- **Confiança:** **100%**
- **Localização:** `app/Http/Controllers/ProductController.php:14`
- **Código vulnerável:**
  ```php
  public function adminQuery(Request $request) {
      $sql = $request->input('sql');
      return DB::select($sql);
  }
  ```
- **Explicação:** Endpoint executa qualquer SQL do utilizador. Sem auth. Game over imediato.
- **Exploração:** `GET /admin/raw-sql?sql=SELECT * FROM users`
- **Correção:** **Eliminar este endpoint completamente.** Se admin precisa de queries ad-hoc, usar tool externa (TablePlus, phpMyAdmin restrito por IP). Nunca expor query interface a HTTP.

#### C4. `.env` commitado com secrets de produção
- **Categoria:** Tokens / Secrets
- **Confiança:** **100%**
- **Localização:** `.env`
- **Código vulnerável:**
  ```
  APP_KEY=base64:notARealKeyButHardcoded123==
  DB_PASSWORD=root
  STRIPE_SECRET=sk_live_PLACEHOLDER_xxx
  ```
- **Explicação:** Stripe live secret + DB password no histórico Git. Se repo for público (ou ficar), comprometido.
- **Correção:**
  ```bash
  # 1. Rotacionar TUDO imediatamente:
  #    - Novo APP_KEY: php artisan key:generate
  #    - Stripe: revogar key, gerar nova
  #    - DB: mudar password
  # 2. Adicionar .env ao .gitignore (se não está)
  echo ".env" >> .gitignore
  # 3. Remover do histórico
  git filter-repo --path .env --invert-paths --force
  # 4. Force push (ou começar repo do zero)
  # 5. Notificar equipa do incident
  ```

### Altos

#### A1. CSRF disabled implicitamente em /users/{id}
- **Categoria:** CSRF
- **Confiança:** **80%**
- **Localização:** `routes/web.php:5`
- **Código vulnerável:** `Route::any('/users/{id}', ...)` aceita POST, mas Laravel só protege CSRF se rota está em grupo `web` middleware. `Route::any` no top-level pode escapar.
- **Correção:** Mover para `Route::middleware(['web', 'auth'])->group(...)` e usar `Route::put` específico.

#### A2. `Route::any` aceita GET para state-changing
- **Categoria:** REST API insegura / HTTP method confusion
- **Confiança:** **90%**
- **Localização:** `routes/web.php:5`
- **Código vulnerável:** `Route::any('/users/{id}', ...)` aceita GET, POST, PUT, DELETE.
- **Correção:**
  ```php
  Route::middleware(['auth'])->group(function () {
      Route::put('/users/{id}', [UserController::class, 'update']);
  });
  ```

#### A3. Resposta /users/{id} expõe modelo inteiro
- **Categoria:** Exposição de dados
- **Confiança:** **80%**
- **Localização:** `app/Http/Controllers/UserController.php:11`
- **Código vulnerável:** `return response()->json($user)` devolve modelo User direto (inclui `password`, `remember_token`).
- **Correção:** Adicionar `protected $hidden = ['password', 'remember_token']` no Model + usar `UserResource` (API Resource) com fields explícitos.

### Médios

#### M1. Sem rate limiting global
- **Categoria:** DoS / Auth
- **Confiança:** **80%**
- **Localização:** `routes/web.php`
- **Correção:** `Route::middleware('throttle:60,1')->group(...)` + throttle agressivo em endpoints sensíveis.

### Baixos

#### B1. Composer / Laravel versions não declaradas explicitamente
- **Categoria:** Dependências
- **Confiança:** **60%**
- **Localização:** `composer.json`
- **Correção:** Pinning explícito + `composer audit` na CI.

---

## 7. Plano de Correção por Fases

### Fase 1 — Imediata (4-6h) · BLOQUEIA DEPLOY
- [ ] **C4** — Rotacionar STRIPE_SECRET, DB_PASSWORD, APP_KEY (1h)
- [ ] **C4** — Remover .env do git history + .gitignore (30 min)
- [ ] **C3** — Eliminar endpoint /admin/raw-sql (15 min)
- [ ] **C1** — Substituir DB::select por Eloquent + escape (1h)
- [ ] **C2** — Form Request para UserController + auth middleware (2h)

### Fase 2 — Curto prazo (1-2 dias)
- [ ] **A1, A2** — Refazer routes/web.php com grupos middleware
- [ ] **A3** — User Resource + `$hidden` no Model
- [ ] **M1** — Throttle middleware global

### Fase 3 — Hardening
- [ ] **B1** — Pin versions + composer audit na CI
- [ ] Logs estruturados sem PII
- [ ] Tests de regressão de segurança

### Fase 4 — Contínuo
- [ ] CI: composer audit + Larastan + PHP CS Fixer
- [ ] Pre-commit hook para gitleaks
- [ ] Auditoria trimestral

---

## 8. Checklist Final Antes de Produção

- [ ] `.env` no .gitignore + rotacionado
- [ ] Form Requests em todos os endpoints com input
- [ ] `auth` middleware em todos os endpoints privados
- [ ] Eloquent ORM (não `DB::select` com strings)
- [ ] CSRF protection ativa
- [ ] Throttle middleware
- [ ] User Resources (não expor Eloquent direto)
- [ ] composer audit sem Críticos/Altos
- [ ] Logs sem PII
- [ ] HTTPS forçado (`URL::forceScheme('https')`)
- [ ] Cookies `secure` + `httponly` + `same_site`

---

## 9. Recomendações Adicionais

- **Adoptar Larastan/PHPStan** com level 8+ — apanha mass assignment estaticamente
- **Pre-commit hook** com gitleaks (detecta secrets antes de commit)
- **Sentry** para crash reporting (sem PII)
- **Health check** endpoint sem detalhes
- **Pen-test externo** após Fase 1+2
```
