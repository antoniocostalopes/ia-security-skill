# Análise — Endpoints Públicos (sem autenticação)

> Endpoints acessíveis a qualquer visitante anónimo. Por design ou por esquecimento. Esta categoria foca no que devem (e não devem) fazer.

## O que procurar

### Endpoints que **não deviam** estar públicos
- Endpoints administrativos sem auth check (`__return_true` no permission_callback, `permitAll()` em Spring, etc.)
- Endpoints de teste/dev esquecidos em produção (`/test/*`, `/dev/*`, `/debug/*`)
- Endpoints internos expostos (`/internal/*`, `/api/private/*`)
- Endpoints que **devolvem dados** sensíveis a anónimos
- Endpoints que **alteram estado** em nome de outros utilizadores

### Endpoints públicos por design — o que devem ter

Todos estes são **legitimamente** públicos: registo, login, search, contact form, newsletter signup, healthcheck. Mas precisam de:

1. **Rate limiting** (anti brute force, anti spam, anti DoS)
2. **CAPTCHA** após threshold (anti automation)
3. **Validação de input** estrita
4. **Sanitização do output** (anti XSS armazenado)
5. **Logging** de eventos suspeitos (rajadas, payloads inválidos)
6. **CORS restrito** se acedido por JS de outras origens

## Sinais de alarme por framework

### WordPress — `wp_ajax_nopriv_*`
```php
// BAD
add_action('wp_ajax_nopriv_remove_item', 'remove_item');
function remove_item() {
    wp_delete_post($_POST['id']);  // qualquer um apaga
}

// GOOD — endpoint genuinamente público (subscrever newsletter)
add_action('wp_ajax_subscribe', 'do_subscribe');
add_action('wp_ajax_nopriv_subscribe', 'do_subscribe');
function do_subscribe() {
    check_ajax_referer('subscribe_nonce', 'nonce');
    rate_limit('subscribe_' . $_SERVER['REMOTE_ADDR'], 5, 60);
    $email = sanitize_email($_POST['email']);
    if (!is_email($email)) wp_send_json_error('email_invalido');
    // ... gravar
    wp_send_json_success();
}
```

### Express (Node)
```javascript
// BAD
app.post('/api/orders/:id/cancel', (req, res) => {
  cancelOrder(req.params.id);  // qualquer um cancela qualquer encomenda
});

// GOOD — endpoint público com guards
app.post('/api/contact', rateLimit({ windowMs: 60_000, max: 5 }),
  body('email').isEmail(),
  body('message').isLength({ min: 10, max: 5000 }).escape(),
  async (req, res) => {
    if (req.body.honeypot) return res.status(204).end();  // bot trap
    await saveContact(req.body);
    res.status(201).end();
  }
);
```

### Spring Boot
```java
// BAD
@RestController
public class AdminController {
    @GetMapping("/admin/users")  // sem @PreAuthorize
    public List<User> all() { return userService.findAll(); }
}

// GOOD
@PreAuthorize("hasRole('ADMIN')")
@GetMapping("/admin/users")
public List<User> all() { return userService.findAll(); }
```

### Django
```python
# BAD
def admin_users(request):
    return JsonResponse(list(User.objects.values()), safe=False)
    # qualquer um lista users

# GOOD
@require_http_methods(["GET"])
@login_required
@user_passes_test(lambda u: u.is_staff)
def admin_users(request):
    return JsonResponse(list(User.objects.values('id', 'email')), safe=False)
```

### Flask / FastAPI
```python
# FastAPI — dependências para auth
from fastapi import Depends, HTTPException

async def require_admin(current_user = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(403)
    return current_user

@app.get('/admin/users', dependencies=[Depends(require_admin)])
def list_users(): ...
```

### .NET ASP.NET Core
```csharp
// BAD
[HttpGet("admin/users")]
public IActionResult ListUsers() => Ok(_db.Users.ToList());

// GOOD
[Authorize(Roles = "Admin")]
[HttpGet("admin/users")]
public IActionResult ListUsers() => Ok(_db.Users.Select(u => new { u.Id, u.Email }));
```

## Pergunta-chave para cada endpoint público

> *"O que acontece se um atacante anónimo enviar este request 1000× com parâmetros arbitrários?"*

Cenários:
- **Dados sensíveis na resposta** → data leak
- **Cria recurso** (account, order, comment) → spam
- **Envia email/SMS** → custos / spam para vítimas
- **Chama API externa cara** → fraude de custos (cloud bill shock)
- **Operação cara em CPU/DB** → DoS
- **Modifica dados de outros users** → sabotagem
- **Confirma existência de algo** (email, username) → enumeração
- **Resposta varia em tempo** → timing oracle

Se algum desses for "mau" → tens problema.

## Defesa em camadas para endpoints públicos

### Camada 1 — Validação de input
```javascript
// Schema strict
const schema = z.object({
  email: z.string().email().max(254),
  message: z.string().min(10).max(5000),
  // honeypot field — bots preenchem, humanos não
  website: z.string().max(0),
});
```

### Camada 2 — Rate limit por IP + por user (se identificável)
```javascript
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: (req) => req.body?.email ? 3 : 10,  // mais restrito por email
  keyGenerator: (req) => `${req.ip}_${req.body?.email || ''}`,
});
```

### Camada 3 — CAPTCHA / proof-of-work após N falhas
- hCaptcha, reCAPTCHA, Cloudflare Turnstile.
- Ou proof-of-work simples (Argon2 challenge no cliente).

### Camada 4 — Honeypot fields
```html
<!-- Campo escondido, bots preenchem -->
<input type="text" name="website" style="display:none" tabindex="-1" autocomplete="off">
```
```javascript
if (req.body.website) {
  res.status(204).end();  // pretende sucesso, ignora silenciosamente
  return;
}
```

### Camada 5 — Log e alerta para padrões suspeitos
- Mais de 50 requests/min de mesmo IP → alert.
- Payloads inválidos consistentes → alert (varredura).
- Países fora do mercado-alvo → flag.

## Padrões específicos comuns

### Form de contacto
- Sanitizar antes de gravar (anti XSS armazenado).
- Não usar input do user diretamente em headers de email enviado (header injection).
- Rate limit por IP + por email.
- Honeypot.

### Newsletter signup
- Double opt-in (link de confirmação por email).
- Rate limit.
- Não confirmar se email existe (`"Verifica o teu email"` para qualquer input válido).

### Login
- Já coberto em `14-autenticacao-sessao.md`.

### Search
- Cap de comprimento de query.
- Cap de resultados.
- Sem refletir input em respostas sem escape.

### Health check
- `/healthz` ou `/readyz` — devolver status 200/503, **não** versão, **não** detalhes internos.
- Versão em endpoint separado autenticado se necessário.

```javascript
// BAD
app.get('/health', (req, res) => res.json({
  status: 'ok',
  version: pkg.version,
  db: dbStatus,
  redis: redisStatus,
  env: process.env.NODE_ENV,
}));

// GOOD
app.get('/healthz', (req, res) => res.status(200).end());
```

## Quick wins (faz isto antes de entregar)

- [ ] Listar **todos** os endpoints sem auth (grep por `permitAll`, `__return_true`, `is_user_logged_in()` ausente, `@AllowAnonymous`)
- [ ] Para cada um, confirmar que está documentado como público intencional
- [ ] Aplicar rate limit a todos os públicos
- [ ] CAPTCHA em endpoints de criação (signup, contact)
- [ ] Honeypot em forms públicos
- [ ] Validação de schema strict
- [ ] Sanitização do output (anti XSS armazenado se conteúdo vai para BD)
- [ ] Health check minimalista
- [ ] Apagar endpoints de teste/dev que não devem ir para prod
- [ ] CORS restrito se acedido cross-origin por JS

## Falsos positivos
- Health checks (`/healthz`) sem auth — OK desde que minimalistas
- API GraphQL pública com endpoints `Query` read-only e auth nas mutations — OK
- Static assets (`/css`, `/js`, `/images`) sem auth — OK por definição

## Severidade — em linguagem honesta
- **Crítico:** endpoint admin público (operação privilegiada sem auth)
- **Crítico:** endpoint público que devolve PII de outros users
- **Crítico:** endpoint público que envia SMS/email arbitrário (cost attack)
- **Alto:** endpoint público sem rate limit em ação que cria recursos
- **Alto:** endpoint público que confirma existência de email/username (enumeração)
- **Médio:** endpoints de teste em produção (info disclosure)
- **Médio:** health check verboso
- **Baixo:** CORS aberto em endpoint público read-only
