# Análise — XSS (Cross-Site Scripting)

## O que procurar

### Reflected / Stored
- `echo`, `print`, `printf` recebendo input do utilizador sem escape.
- `$_GET`, `$_POST`, `$_REQUEST`, `$_COOKIE`, `$_SERVER` impressos diretamente.
- WordPress: variáveis impressas sem `esc_html()`, `esc_attr()`, `esc_url()`, `esc_textarea()`, `wp_kses()`.
- Conteúdo da BD impresso sem escape (XSS armazenado).

### DOM-based (JavaScript)
- `element.innerHTML = userInput`
- `document.write(...)`
- `eval(...)`, `new Function(...)`, `setTimeout("string")`
- `location.href = userInput` sem validação de scheme
- `$(selector).html(userInput)` em jQuery
- React: `dangerouslySetInnerHTML={{__html: x}}`
- Vue: `v-html="x"`
- Angular: `[innerHTML]="x"` sem `DomSanitizer`
- Handlebars: `{{{ x }}}` (triple braces)

### Contextos múltiplos
- Variável usada em HTML **e** em atributo **e** em JS — exige escape **por contexto**.
- Atributos `href`, `src`, `style`, `on*` (event handlers).
- URLs com scheme `javascript:`, `data:`.

## Sinais de alarme

```php
<!-- BAD -->
<div><?php echo $_GET['msg']; ?></div>
<a href="<?= $url ?>">link</a>
<script>var x = "<?= $name ?>";</script>

<!-- GOOD -->
<div><?php echo esc_html($_GET['msg']); ?></div>
<a href="<?php echo esc_url($url); ?>">link</a>
<script>var x = <?php echo wp_json_encode($name); ?>;</script>
```

```js
// BAD
el.innerHTML = data.title;
$('#x').html(input);

// GOOD
el.textContent = data.title;
$('#x').text(input);
```

## Quick wins (faz isto antes de entregar)

- [ ] Listar todos os `echo`/`print`/template renders com input do user — escapar contextualmente
- [ ] `innerHTML` substituído por `textContent` onde possível
- [ ] `dangerouslySetInnerHTML` / `v-html` / `[innerHTML]` apenas com sanitizer (DOMPurify)
- [ ] Atributos `href`/`src` com input → validar scheme (HTTP/HTTPS only)
- [ ] CSP definido no servidor (`default-src 'self'` mínimo)
- [ ] Auto-escape ativo nos templates (Jinja, Twig, ERB, Razor — todos têm por default)
- [ ] Linter SAST (ESLint security plugin, Bandit, Brakeman) na CI
- [ ] Sem `eval`/`Function()`/`setTimeout("string")` com input
- [ ] Plus: ver `linguagens/<lang>.md` para idiomas específicos

## Falsos positivos
- Output de funções já seguras: `wp_kses_post()`, `the_content()` (já filtra), constantes.
- Variáveis já escapadas a montante (verifica fluxo).
- Strings literais sem interpolação.

## Correções por contexto

| Contexto | Função WP | Equivalente genérico |
|---|---|---|
| Texto HTML | `esc_html()` | `htmlspecialchars($x, ENT_QUOTES, 'UTF-8')` |
| Atributo HTML | `esc_attr()` | `htmlspecialchars($x, ENT_QUOTES, 'UTF-8')` |
| URL | `esc_url()` | filtro + parse_url + allowlist scheme |
| JavaScript | `wp_json_encode()` | `json_encode($x, JSON_HEX_TAG\|JSON_HEX_AMP\|JSON_HEX_APOS\|JSON_HEX_QUOT)` |
| HTML rico permitido | `wp_kses($x, $allowed)` | HTMLPurifier |
| Textarea | `esc_textarea()` | `htmlspecialchars` |

## Severidade típica
- Reflected XSS em página pública: **Alto**
- Stored XSS visível por admin/users: **Crítico**
- DOM XSS exigindo interação complexa: **Médio**
- XSS apenas para o próprio utilizador (self-XSS): **Baixo**
