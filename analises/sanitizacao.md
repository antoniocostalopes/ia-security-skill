# Análise — Sanitização e Escape

## Conceitos (não confundir)

| | Sanitização | Escape |
|---|---|---|
| **Quando** | Na **entrada** (input) | Na **saída** (output) |
| **Para quê** | Limpar/normalizar antes de gravar | Tornar seguro no contexto de output |
| **Exemplo** | `sanitize_email()` | `esc_html()` |

> **Regra de ouro:** sanitiza ao entrar, escapa ao sair, valida sempre.

## Funções por framework — referência

> Para padrões específicos por linguagem ver `linguagens/<lang>.md`. Para funções específicas por framework ver `frameworks/web/<framework>.md`. Abaixo, **WordPress** como exemplo concreto + tabela genérica no fim.

### Sanitização (input) — WordPress

| Função | Para |
|---|---|
| `sanitize_text_field($x)` | Texto single-line genérico |
| `sanitize_textarea_field($x)` | Texto multi-line |
| `sanitize_email($x)` | Email |
| `sanitize_url($x)` / `esc_url_raw($x)` | URL para gravar |
| `sanitize_key($x)` | Slugs, keys (`a-z0-9_-`) |
| `sanitize_title($x)` | Slugs URL-safe |
| `sanitize_file_name($x)` | Nome de ficheiro |
| `sanitize_user($x)` | Username |
| `sanitize_hex_color($x)` | Cor `#RRGGBB` |
| `absint($x)` / `intval($x)` | Inteiro positivo / inteiro |
| `floatval($x)` | Float |
| `wp_kses($x, $allowed_tags)` | HTML restrito |
| `wp_kses_post($x)` | HTML como `post_content` |

### Escape (output) — WordPress

| Função | Contexto |
|---|---|
| `esc_html($x)` | Texto dentro de tags HTML |
| `esc_attr($x)` | Valor de atributo HTML |
| `esc_url($x)` | URL em `href`, `src` |
| `esc_js($x)` | String inline em JS (legacy — preferir `wp_json_encode`) |
| `esc_textarea($x)` | Conteúdo de `<textarea>` |
| `esc_xml($x)` | XML |
| `wp_json_encode($x)` | Serialização para JS/JSON |
| `wp_kses_post($x)` | HTML como `post_content` (output) |

## Erros típicos

### 1. Sanitizar para output
```php
// BAD — sanitize_text_field não escapa < >
echo sanitize_text_field($_GET['name']);

// GOOD
echo esc_html($_GET['name']);
```

### 2. Escapar para input (gravar)
```php
// BAD — esc_html guarda entidades HTML na BD
update_post_meta($id, 'note', esc_html($_POST['note']));

// GOOD
update_post_meta($id, 'note', sanitize_text_field(wp_unslash($_POST['note'])));
```

### 3. Esquecer `wp_unslash`
```php
// WordPress adiciona slashes a $_POST/$_GET (legacy magic_quotes-like)
// BAD
$x = sanitize_text_field($_POST['x']); // \"texto\" passa para BD

// GOOD
$x = sanitize_text_field(wp_unslash($_POST['x'])); // "texto"
```

### 4. Escape errado no contexto
```php
// BAD — atributo escapado como HTML
<input value="<?php echo esc_html($x); ?>">
// `"` em $x quebra o atributo

// GOOD
<input value="<?php echo esc_attr($x); ?>">
```

### 5. URL sem `esc_url`
```php
// BAD
<a href="<?php echo $url; ?>">link</a>
// $url = 'javascript:alert(1)' → XSS

// GOOD
<a href="<?php echo esc_url($url); ?>">link</a>
```

### 6. JS inline sem encode JSON
```php
// BAD — esc_js só escapa para single-quote string
<script>var name = '<?php echo esc_js($name); ?>';</script>

// MELHOR
<script>var name = <?php echo wp_json_encode($name); ?>;</script>
```

### 7. `wp_kses` mal configurado
```php
// BAD — permite tudo
echo wp_kses($html, []); // strip total
echo wp_kses_post($html); // permite `<script>` em alguns casos? não, mas verificar

// GOOD — allowlist explícita
echo wp_kses($html, [
    'a' => ['href' => true, 'title' => true, 'rel' => true],
    'br' => [], 'p' => [], 'strong' => [], 'em' => [],
]);
```

### 8. Validar vs. sanitizar
- **Sanitizar** transforma silenciosamente.
- **Validar** rejeita se inválido — preferir validação para campos críticos.

```php
$email = sanitize_email($_POST['email']);
if (!is_email($email)) wp_send_json_error('email_invalido');

$id = absint($_POST['id']);
if ($id <= 0) wp_send_json_error('id_invalido');

$url = esc_url_raw($_POST['url']);
if (!wp_http_validate_url($url)) wp_send_json_error('url_invalida');
```

### Genérico — qualquer linguagem

| Contexto | PHP | JavaScript | Python | Java |
|---|---|---|---|---|
| HTML body | `htmlspecialchars($x, ENT_QUOTES, 'UTF-8')` | `el.textContent = x` | `html.escape(x, quote=True)` | `StringEscapeUtils.escapeHtml4(x)` |
| Atributo | `htmlspecialchars` | `el.setAttribute(...)` | `html.escape` | idem |
| URL | `urlencode($x)` + scheme allowlist | `encodeURIComponent(x)` | `urllib.parse.quote(x)` | `URLEncoder.encode(x, "UTF-8")` |
| JS string | `json_encode($x, JSON_HEX_TAG\|JSON_HEX_AMP\|JSON_HEX_APOS\|JSON_HEX_QUOT)` | `JSON.stringify(x)` | `json.dumps(x)` | `ObjectMapper.writeValueAsString(x)` |
| HTML rico | `HTMLPurifier` | `DOMPurify.sanitize(x)` | `bleach.clean(x)` | `OWASP HTML Sanitizer` |

## Quick wins (faz isto antes de entregar)

- [ ] Auto-escape ativo nos templates (Jinja, Twig, ERB, Razor, Blade — todos têm por default)
- [ ] **Sanitizar input** ao gravar (regras por campo)
- [ ] **Escapar output** ao renderizar (por contexto: HTML/Attr/URL/JS)
- [ ] **Validar** campos críticos (rejeitar inválido) em vez de só sanitizar (transformar)
- [ ] HTML rico de utilizador → biblioteca dedicada (DOMPurify/HTMLPurifier/bleach), nunca regex caseiro
- [ ] WordPress: `wp_unslash()` antes de sanitizar inputs ($_POST/$_GET)
- [ ] CSP definido como segunda camada (caso escape falhe)
- [ ] Tests para inputs com chars problemáticos: `<script>`, `'"`, `&`, emojis, RTL, null bytes
- [ ] Plus: ver `linguagens/<lang>.md` para helpers específicos da linguagem

## Falsos positivos
- Variáveis manifestamente literais (constantes, valores hardcoded).
- Variáveis já passadas por escape em camada anterior (ex.: `the_content()` já filtra).
- Strings de configuração interna que nunca tocam input.

## Severidade típica
- Output não escapado de input público → XSS armazenado: **Crítico**
- Output não escapado de input próprio (self): **Baixo**
- Sanitização ausente em campo gravado: **Médio** (depende do uso a jusante)
- Escape errado de contexto (HTML em atributo): **Alto**
