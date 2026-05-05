# HTMX — Profile de Segurança

> HTMX traz hipermedia para HTML moderno. Server renderiza fragments HTML, cliente faz swaps via `hx-*` attributes. Modelo de ameaça mais próximo de server-rendered tradicional do que SPA — mas com algumas peculiaridades.

## Deteção
- `package.json` com `htmx.org` ou tag `<script src="...htmx...">`
- HTML com atributos `hx-get`, `hx-post`, `hx-swap`, etc.

## Modelo de ameaça

- **Server renderiza HTML** — XSS é problema **server-side** (template injection no backend).
- **Cada `hx-*` é HTTP request** — todas as defesas web normais aplicam (CSRF, auth, etc.).
- **`hx-swap` substitui DOM** — fragmento devolvido pode incluir JS se backend gerar.
- **Atributos `hx-*` são processed pelo HTMX** — input do user em atributos = potencial control hijack.

## XSS — server-side é a defesa

```python
# Flask/Jinja — auto-escape ON
@app.route('/comment', methods=['POST'])
def add_comment():
    text = request.form['text']  # input do user
    # Render template — Jinja2 escapa automaticamente
    return render_template('comment_fragment.html', text=text)
```

```html
<!-- comment_fragment.html -->
<div class="comment">
  {{ text }}  {# escaped automaticamente #}
</div>
```

## CSRF — sempre obrigatório

HTMX faz POST/PUT/DELETE — vulneráveis a CSRF.

```html
<!-- Adicionar token CSRF a TODAS as requests HTMX -->
<head>
  <script src="htmx.min.js"></script>
  <meta name="csrf-token" content="{{ csrf_token() }}">
  <script>
    document.body.addEventListener('htmx:configRequest', (event) => {
      event.detail.headers['X-CSRF-Token'] =
        document.querySelector('meta[name="csrf-token"]').content;
    });
  </script>
</head>
```

Backend valida `X-CSRF-Token` como qualquer endpoint web normal.

## `hx-vals` com input do user — perigoso

```html
<!-- BAD — atacante controla `userId` -->
<button hx-post="/follow" hx-vals='{"userId": "{{ user.id }}"}'>Follow</button>
<!-- Se user.id não escapado: hx-vals='{"userId": "1", "role": "admin"}' -->

<!-- GOOD — escape obrigatório -->
<button hx-post="/follow" hx-vals='{"userId": {{ user.id|tojson }}}'>Follow</button>
```

## `hx-trigger` com expressões

```html
<!-- BAD — expressão JS controlada por user -->
<div hx-trigger="{{ user_input }}">  <!-- pode injetar trigger arbitrário -->

<!-- GOOD — trigger fixo -->
<div hx-trigger="click">
```

## `hx-on` — JavaScript inline

```html
<!-- hx-on:event="JS code" — executa JS inline -->
<button hx-on:click="alert('hi')">Click</button>

<!-- Cuidado se conteúdo do atributo vem de input -->
```

CSP precisa de permitir `'unsafe-inline'` ou `'unsafe-hashes'` para `hx-on:*` funcionar. Considera:
- Substituir `hx-on:*` por event listeners externos
- Ou aceitar `'unsafe-inline'` como trade-off (HTMX por design usa inline)

## `hx-headers` / `hx-include` — token leakage

```html
<!-- BAD — token incluído em request HTMX vai ficar visível em network tab -->
<button hx-post="/api"
        hx-headers='{"Authorization": "Bearer {{ token }}"}'>
```

Preferir cookies HttpOnly (mesmo que para apps SPA).

## Out-of-band swaps (`hx-swap-oob`)

```html
<!-- Backend devolve múltiplos fragments numa só response -->
<!-- BAD — fragment OOB pode substituir DOM noutro lado da página -->
<div id="notification" hx-swap-oob="true">
  Hello {{ user.name }}  <!-- escape obrigatório -->
</div>
```

Backend deve sanitizar tudo, mesmo OOB.

## Server-Sent Events (SSE) e WebSockets

```html
<div hx-ext="sse" sse-connect="/events">
  <div sse-swap="message">Loading...</div>
</div>
```

- Validar `Origin` em SSE/WS server.
- Auth no handshake.
- Rate limit por connection.

## Common antipatterns

### Templates sem auto-escape
- Confirmar Jinja/ERB/Razor/Blade auto-escape ativo.

### `|safe` / `raw` / `Html.Raw` em conteúdo do user
- XSS armazenado.

### CSRF token em meta tag mas não enviado
- Listener `htmx:configRequest` esquecido.

### Endpoints HTMX devolvem HTML mas também aceitam JSON
- Inconsistência — atacante pode trocar Content-Type.

### `hx-confirm` como única validação
- "Are you sure?" client-side. Backend deve revalidar.

### Redirecionamento via `HX-Redirect` header sem validar
- Open redirect.

### `hx-swap="innerHTML"` em containers críticos
- Fragment malicioso pode injetar conteúdo.

## Quick wins

- [ ] HTMX 1.9+ ou 2.x
- [ ] Templates com auto-escape ON
- [ ] CSRF token em todas as requests HTMX (configRequest listener)
- [ ] `hx-vals` com input sempre `|tojson` ou equivalente
- [ ] `hx-trigger` fixos, não dinâmicos
- [ ] Tokens em cookies HttpOnly (não em `hx-headers`)
- [ ] Endpoints HTMX devolvem **só** HTML (não JSON misturado)
- [ ] Validação server-side, mesmo se houver `hx-confirm`
- [ ] CSP cuidadosa com `hx-on:*` (precisa `'unsafe-inline'`)
- [ ] Rate limit em endpoints (mesmo padrão que web normal)
- [ ] `HX-Redirect` validado contra allowlist
- [ ] SSE/WS com auth no handshake e Origin check
