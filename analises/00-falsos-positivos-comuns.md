# Falsos Positivos Comuns — Anti-Hallucination

> Para evitar reportar como vulnerabilidade o que **parece** mas **não é**. Aplicar **antes** de classificar achado como Crítico/Alto.

## Princípio

A IA tende a sobrereportar (better safe than sorry mindset). Mas falsos positivos custam confiança. **Para cada candidato a achado, percorre estes filtros antes de o adicionar ao relatório.**

## 1. XSS — falsos positivos

### Não é XSS:

```javascript
// ❌ Strings literais — não há input
const greeting = "Hello world";
el.innerHTML = greeting;

// ❌ Já passou por sanitizer
import DOMPurify from 'dompurify';
el.innerHTML = DOMPurify.sanitize(input);

// ❌ React/Vue/Angular auto-escapam
<p>{userInput}</p>           // React escapa
<p>{{ userInput }}</p>       // Vue escapa
<p>{{ userInput }}</p>       // Angular escapa

// ❌ textContent é seguro
el.textContent = userInput;

// ❌ Numero/booleano (não string) não é XSS
const n = parseInt(input);
el.innerHTML = n;            // n é number, não pode injetar JS
```

```php
// ❌ Já passou por escape
echo esc_html($_GET['x']);
echo htmlspecialchars($_POST['y']);

// ❌ Constante / variável estática
echo 'static content';
echo SITE_NAME;
```

## 2. SQL Injection — falsos positivos

```javascript
// ❌ Já parametrizado
db.query('SELECT * FROM users WHERE id = $1', [id]);
db.execute('SELECT * FROM x WHERE name = ?', [name]);

// ❌ ORM com builder (não raw)
User.findOne({ where: { id: userId } });
User.findByPk(id);

// ❌ Prepared statement
const stmt = db.prepare('SELECT * FROM x WHERE y = ?');
stmt.get(value);
```

```php
// ❌ wpdb->prepare correto
$wpdb->get_results($wpdb->prepare("SELECT * FROM x WHERE id = %d", $id));

// ❌ Variável já castada
$id = (int) $_GET['id'];
$wpdb->query("SELECT * FROM x WHERE id = $id");  // OK porque (int) força integer

// ❌ absint/intval garantem int
$id = absint($_POST['id']);
"... WHERE id = $id"  // OK
```

## 3. CSRF — falsos positivos

```javascript
// ❌ API com Bearer token (sem cookies) — sem CSRF risk
fetch('/api/x', { headers: { Authorization: `Bearer ${token}` } });

// ❌ Endpoint read-only (GET sem efeitos colaterais)
app.get('/api/posts', listPosts);

// ❌ SameSite=Strict cookies já protegem em modern browsers
res.cookie('session', x, { sameSite: 'strict' });
```

```php
// ❌ check_admin_referer presente algures no flow (mesmo se não na função)
// Verificar middleware/hook anterior antes de reportar
add_action('init', 'verify_csrf_globally');
add_action('admin_post_x', 'handler');  // protegido pelo init
```

## 4. Permissões / IDOR — falsos positivos

```php
// ❌ Capability check noutro local do mesmo flow
function delete_post() {
    // capability já verificada no init/middleware
    wp_delete_post($_POST['id']);
}

// ❌ Filtro por owner aplicado a montante
$query->where('user_id', auth()->id())->find($_POST['id']);
```

```javascript
// ❌ Middleware global de auth + ownership já garante
app.use(requireAuth);
app.use(checkOwnership);
app.delete('/posts/:id', deletePost);  // protegido pelos middlewares

// ❌ ID está dentro de scope do user (sub-resource)
GET /users/me/posts/:id  // me garante ownership
```

## 5. Tokens hardcoded — falsos positivos

```javascript
// ❌ Comentário/docs com exemplo
// Example: const API_KEY = "AKIAEXAMPLE..."

// ❌ Test fixture
const TEST_TOKEN = "ghp_test_token_for_unit_tests";

// ❌ Placeholder em template
const API_KEY = process.env.API_KEY || "REPLACE_ME";

// ❌ Public key (Stripe pk_live_ é público por design)
const STRIPE_PUBLISHABLE = "pk_live_...";  // OK
```

```php
// ❌ Constante definida via env
define('SECRET', getenv('SECRET'));  // a string visível é só nome

// ❌ Valor é "example", "your-key-here", etc.
define('API_KEY', 'your-api-key-here');  // placeholder, não secret real
```

## 6. Hardening / Configuração — falsos positivos

```php
// ❌ DEBUG=true em ambiente de dev
if (getenv('APP_ENV') === 'development') {
    define('WP_DEBUG', true);
}

// ❌ display_errors em ficheiro de dev específico
// ficheiro: php-dev.ini (não php.ini)
```

```javascript
// ❌ Debug logging gated
if (process.env.NODE_ENV !== 'production') {
    console.log(req.body);  // só em dev
}
```

## 7. Dependências / Supply chain — falsos positivos

```json
// ❌ Versão pinned em devDependencies (não vai para prod)
"devDependencies": {
  "old-test-lib": "1.0.0"  // só para tests, não shipped
}

// ❌ CVE em sub-dep mas call path não atingível
// Verificar se a função vulnerável é realmente chamada
```

## 8. Sanitização — falsos positivos

```php
// ❌ Já sanitizado a montante
function process($input) {
    // $input vem de função que já chamou sanitize_text_field
    update_post_meta($id, 'x', $input);
}

// ❌ Helper que faz escape internamente
the_content();        // já filtra e escapa
the_title();          // idem
get_the_excerpt();    // idem
```

## 9. SSRF / Open Redirect — falsos positivos

```python
# ❌ Allowlist já validada
ALLOWED = ['/dashboard', '/profile', '/home']
if redirect_url in ALLOWED:
    return redirect(redirect_url)  # safe

# ❌ Redirect para mesma origem
parsed = urlparse(redirect_url)
if parsed.netloc == request.host:
    return redirect(redirect_url)  # same-origin OK
```

```javascript
// ❌ HTTP client a hostname hardcoded (sem input)
fetch('https://api.minha-empresa.com/data');  // não há input do user
```

## 10. Headers HTTP — falsos positivos

```nginx
# ❌ Headers definidos no servidor (não na app) — pode estar OK
# Verificar config nginx/apache antes de reportar "missing HSTS"
```

```javascript
// ❌ helmet middleware aplicado globalmente
app.use(helmet());  // adiciona X-Frame, X-Content-Type, HSTS, etc.
// → não reportes individualmente como missing
```

## Padrões gerais que NÃO são vulnerabilidade

| Aparece como... | Mas não é se... |
|---|---|
| `SELECT ... + variable` | variable é resultado de `parseInt`/`(int)`/cast |
| `eval(...)` | ... é JSON.parse equivalente em linguagem que não tem JSON nativa |
| `system(...)` | comando é hardcoded, sem input do user |
| `unserialize(...)` | data vem de cache/queue interno (atacante não controla) |
| `setcookie(name, value)` | cookie não é session token (ex.: language preference) |
| Falta de `csrf_token` | endpoint é GET ou usa Bearer auth sem cookies |
| `localStorage` | armazena dados não-sensíveis (theme, language) |
| `permitAll()` | endpoint é genuinamente público (health check, login form) |

## Heurística do Self-Doubt

**Antes de adicionar achado Crítico/Alto, pergunta:**

1. **"Vejo todo o flow ou só parte?"** Se vejo só parte → reportar como Médio com nota "verificar fluxo completo"
2. **"Existe sanitization noutro layer (middleware, framework)?"** Se possível → Médio com nota
3. **"Atacante consegue **chegar** a este código?"** Se requer auth admin → reduz severidade
4. **"O input vem realmente do utilizador?"** Se vem de fonte interna confiável → não é vuln
5. **"Estou a confundir API design com vulnerabilidade?"** (ex.: endpoint que é público por design)

**Se 2+ destas geram dúvida → marcar como "Suspeita — requer verificação manual" em vez de Crítico/Alto.**

## Output adjustment

Para achados onde aplicaste filtros mas mantiveste:
```
- Severidade: Crítico (95% conf.)  ← alta confiança após filtros
- Severidade: Alto (70% conf.)     ← confiança média, requer review
- Severidade: Suspeita              ← incerto, listar mas não bloquear deploy
```

## Regra final

> **Falso positivo gritante mina a credibilidade da skill mais do que falso negativo.**
>
> Quando em dúvida, **reduz severidade ou marca como suspeita**. O developer agradece.
