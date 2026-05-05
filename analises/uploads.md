# Análise — Uploads Perigosos

## O que procurar

### Validação fraca
- Apenas extensão verificada (`.endsWith('.jpg')`).
- Apenas Content-Type verificado (forjável pelo cliente).
- Falta de verificação por **magic bytes** (`finfo_file`, `mime_content_type`).
- WordPress: ausência de `wp_check_filetype_and_ext()`.

### Localização perigosa
- Upload para diretório **com execução PHP** (`/wp-content/uploads/` por default permite, mas plugins podem desativar).
- Upload para dentro do webroot sem `.htaccess` / config a bloquear execução.
- Upload acessível com URL previsível.

### Path traversal
- Nome de ficheiro vindo do cliente sem sanitização: `../../wp-config.php`.
- Falta de `sanitize_file_name()` / `basename()`.

### Polyglots e SVG
- SVG aceito sem sanitização (pode conter `<script>` → XSS).
- HTML/XML aceito como "imagem".
- Polyglot GIF89a + PHP.

### Limites
- Sem limite de tamanho (DoS por disco cheio).
- Sem limite de número de uploads por user/IP.
- Sem `max_file_uploads`, `upload_max_filesize`.

### Race conditions
- Validar e mover em passos separados sem lock.

## Padrão correto (exemplo WordPress)

> Equivalente em outros stacks: ver `frameworks/web/<framework>.md` (Laravel Storage, Django File uploads, Express Multer, Spring MultipartResolver, Rails Active Storage).

```php
function handle_upload() {
    if (!current_user_can('upload_files')) wp_die();
    check_admin_referer('upload_nonce');

    if (empty($_FILES['file']) || !is_uploaded_file($_FILES['file']['tmp_name'])) {
        wp_die('upload inválido');
    }

    // Tamanho
    if ($_FILES['file']['size'] > 5 * 1024 * 1024) {
        wp_die('ficheiro demasiado grande');
    }

    // Nome seguro
    $name = sanitize_file_name(basename($_FILES['file']['name']));

    // Magic bytes + extensão (WP combina ambos)
    $check = wp_check_filetype_and_ext(
        $_FILES['file']['tmp_name'],
        $name
    );
    $allowed = ['jpg' => 'image/jpeg', 'png' => 'image/png', 'pdf' => 'application/pdf'];
    if (!$check['ext'] || !isset($allowed[$check['ext']]) || $allowed[$check['ext']] !== $check['type']) {
        wp_die('tipo não permitido');
    }

    // Filtros adicionais
    add_filter('upload_mimes', fn() => $allowed);

    // Mover via API WP (não move_uploaded_file direto)
    require_once ABSPATH . 'wp-admin/includes/file.php';
    $result = wp_handle_upload($_FILES['file'], ['test_form' => false]);
    if (isset($result['error'])) wp_die($result['error']);

    // Anexar à mediateca
    $attach_id = wp_insert_attachment([
        'post_mime_type' => $result['type'],
        'post_title'     => pathinfo($name, PATHINFO_FILENAME),
        'post_status'    => 'inherit',
    ], $result['file']);

    wp_send_json_success(['url' => wp_get_attachment_url($attach_id)]);
}
```

## Bloquear execução em `/uploads/`

`.htaccess` (Apache):
```apache
<FilesMatch "\.(php|phtml|phar|pl|py|jsp|asp|sh|cgi)$">
  Require all denied
</FilesMatch>
```

Nginx:
```nginx
location ~* /uploads/.*\.(php|phtml|phar|pl|py|jsp)$ {
  deny all;
  return 403;
}
```

## SVG seguro
- Recusar por defeito.
- Se necessário, usar **enshrined/svg-sanitize** ou plugin "Safe SVG".
- Nunca inline em HTML sem sanitização.

## Quick wins (faz isto antes de entregar)

- [ ] Validação por **magic bytes** (libmagic / `file --mime-type`), nunca só por extensão ou Content-Type
- [ ] Allowlist de tipos MIME aceites (não denylist)
- [ ] Limite de tamanho explícito server-side (não confiar só em `MAX_FILE_SIZE`)
- [ ] Nome de ficheiro normalizado: regex strict ou random UUID — **nunca** path do user
- [ ] Diretório de upload **fora** do webroot, ou com execução de scripts bloqueada (`.htaccess`/Nginx)
- [ ] SVG: rejeitar por defeito ou sanitizar com biblioteca dedicada (não strip_tags)
- [ ] Rate limit por user/IP (anti-flood)
- [ ] Antivirus scan em pipeline (ClamAV) para uploads públicos
- [ ] Storage externo (S3/GCS) com bucket privado + URLs assinadas (não public-read)
- [ ] Plus: ver `analises/21-dos-resource-limits.md` para zip/decompression bombs

## Falsos positivos
- Endpoints de upload **autenticados como admin** com âmbito limitado podem ter validação mais leve.
- Uploads para storage externo (S3) com bucket bem configurado mitigam execução, mas ainda exigem validação.

## Severidade típica
- Upload de PHP com execução: **Crítico** (RCE)
- SVG com `<script>` armazenado: **Crítico** (stored XSS)
- Path traversal em nome: **Crítico**
- Validação só por extensão: **Alto**
- Sem limite de tamanho: **Médio**
- Sem rate limit: **Médio**
