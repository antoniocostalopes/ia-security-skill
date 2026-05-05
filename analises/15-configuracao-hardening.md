# Análise — Configuração e Hardening

> Esta é a categoria com melhor retorno por minuto investido. 30 minutos a fechar config = 80% das hipóteses de invasão fechadas.

## O que procurar

### `wp-config.php`
- `WP_DEBUG = true` em produção
- `WP_DEBUG_DISPLAY = true` (mostra erros ao visitante)
- `WP_DEBUG_LOG = true` sem direcionar para fora do webroot
- `SCRIPT_DEBUG = true` (carrega versões não-minificadas, info de paths)
- Falta de `DISALLOW_FILE_EDIT` (admin pode editar plugins/temas pelo dashboard)
- Falta de `DISALLOW_FILE_MODS` (impede instalação de plugins via dashboard)
- Salts default ou em branco (`AUTH_KEY`, `SECURE_AUTH_KEY`, `LOGGED_IN_KEY`, `NONCE_KEY` + 4 salts)
- Credenciais BD em plaintext num ficheiro versionado
- `DB_PASSWORD` partilhada entre dev/staging/prod
- `WP_HOME` / `WP_SITEURL` sem HTTPS forçado
- Falta de `FORCE_SSL_ADMIN`

### `php.ini` / `.user.ini`
- `display_errors = On` em produção
- `display_startup_errors = On`
- `expose_php = On` (header `X-Powered-By: PHP/...`)
- `allow_url_fopen = On` desnecessário (facilita SSRF)
- `allow_url_include = On` (CRÍTICO — RFI)
- `enable_dl = On` (carrega extensões dinamicamente)
- `open_basedir` ausente (PHP pode ler `/etc/passwd`)
- `disable_functions` permissivo (`exec`, `shell_exec`, `system`, `passthru`, `proc_open`, `eval` deviam estar desativadas se não usadas)
- `session.cookie_secure = 0`
- `session.cookie_httponly = 0`
- `session.cookie_samesite` vazio
- `session.use_strict_mode = 0`
- `upload_max_filesize` excessivo (DoS por disco)
- `post_max_size` excessivo
- `max_execution_time` muito alto

### Apache `.htaccess`
- Sem bloqueio de ficheiros sensíveis (`.env`, `wp-config.php.bak`, `composer.lock`)
- Sem bloqueio de execução PHP em `/uploads/`
- `Options +Indexes` (listagem de diretórios)
- Sem `ServerSignature Off`
- Sem desativação de XML-RPC (se não usado)

### Nginx
- `autoindex on` em locations sensíveis
- Falta de `location ~ /\. { deny all; }`
- `server_tokens on` (revela versão)
- Falta de bloqueio para `wp-config.php` em locations PHP
- Permitir execução PHP em `/wp-content/uploads/`

### Permissões de ficheiros
- `wp-config.php` com permissões 644 ou mais permissivas (deve ser 440 ou 400)
- Diretórios com 777 (mau hábito de "fix the upload error")
- `/wp-content/uploads/` com permissões de execução
- `.git/` no webroot com permissões web-readable

### Acessos web indevidos
- `wp-config.php`, `.env`, `.git/`, `.svn/`, `composer.json`, `composer.lock`, `package.json`
- `/wp-content/debug.log` acessível
- `/wp-includes/` listável
- `/readme.html`, `/license.txt`, `/wp-admin/install.php`
- Backups: `*.sql`, `*.sql.gz`, `*.tar.gz`, `wp-config.php.bak`, `wp-config.php~`
- `/phpinfo.php`, `/info.php`, `/test.php` esquecidos

## `wp-config.php` — recomendado para produção

```php
// Debug — tudo desligado em prod
define('WP_DEBUG', false);
define('WP_DEBUG_DISPLAY', false);
define('WP_DEBUG_LOG', false);
define('SCRIPT_DEBUG', false);
@ini_set('display_errors', 0);

// Segurança
define('DISALLOW_FILE_EDIT', true);   // bloqueia editor de plugins/temas
define('DISALLOW_FILE_MODS', true);   // bloqueia instalações via dashboard
define('FORCE_SSL_ADMIN', true);      // HTTPS obrigatório no /wp-admin
define('WP_AUTO_UPDATE_CORE', 'minor'); // atualizações de segurança automáticas

// Salts — gerar em https://api.wordpress.org/secret-key/1.1/salt/
// (NUNCA usar os do exemplo — gerar novos por instância)
define('AUTH_KEY',         '...64 chars random...');
define('SECURE_AUTH_KEY',  '...64 chars random...');
define('LOGGED_IN_KEY',    '...64 chars random...');
define('NONCE_KEY',        '...64 chars random...');
define('AUTH_SALT',        '...64 chars random...');
define('SECURE_AUTH_SALT', '...64 chars random...');
define('LOGGED_IN_SALT',   '...64 chars random...');
define('NONCE_SALT',       '...64 chars random...');

// Credenciais por env (não hardcoded)
define('DB_PASSWORD', getenv('DB_PASSWORD'));

// Cookies
define('COOKIE_DOMAIN', $_SERVER['HTTP_HOST'] ?? '');

// Limitar revisões (BD mais limpa)
define('WP_POST_REVISIONS', 5);

// Trash auto-purge
define('EMPTY_TRASH_DAYS', 30);
```

## `.htaccess` — bloco recomendado (raiz WP)

```apache
# Server signature off
ServerSignature Off
ServerTokens Prod

# Bloquear listagem de diretórios
Options -Indexes

# Bloquear ficheiros sensíveis
<FilesMatch "(^\.|\.env|\.bak|\.swp|\.sql|\.sql\.gz|\.tar\.gz|wp-config\.php\.bak|composer\.json|composer\.lock|package\.json|package-lock\.json|yarn\.lock|debug\.log|error_log|readme\.html|readme\.txt|license\.txt)$">
  Require all denied
</FilesMatch>

# Bloquear acesso a wp-config
<Files wp-config.php>
  Require all denied
</Files>

# Bloquear .git, .svn
RedirectMatch 404 /\.git
RedirectMatch 404 /\.svn
RedirectMatch 404 /\.hg

# Desativar XML-RPC (se não usado)
<Files xmlrpc.php>
  Require all denied
</Files>

# Headers de segurança (também ver headers-http.md)
<IfModule mod_headers.c>
  Header set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
  Header set X-Content-Type-Options "nosniff"
  Header set X-Frame-Options "SAMEORIGIN"
  Header set Referrer-Policy "strict-origin-when-cross-origin"
  Header set Permissions-Policy "geolocation=(), microphone=(), camera=()"
  Header always unset X-Powered-By
</IfModule>

# Bloquear execução PHP em /uploads/
<Directory /var/www/wp-content/uploads>
  <FilesMatch "\.(php|phtml|phar|pl|py|jsp|asp|sh|cgi)$">
    Require all denied
  </FilesMatch>
</Directory>
```

## Nginx — bloco equivalente

```nginx
server_tokens off;

# Esconder ficheiros dotfiles
location ~ /\.(?!well-known) { deny all; }

# Bloquear ficheiros sensíveis
location ~* \.(env|bak|swp|sql|sql\.gz|tar\.gz|log)$ { deny all; }
location = /wp-config.php { deny all; }
location = /readme.html { deny all; }
location = /xmlrpc.php { deny all; }
location ~* /(composer\.(json|lock)|package(-lock)?\.json|yarn\.lock)$ { deny all; }

# Bloquear execução PHP em /uploads/
location ~* /wp-content/uploads/.*\.(php|phtml|phar|pl|py|jsp)$ {
    deny all;
}

# Headers
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

## `php.ini` — recomendações

```ini
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php/error.log     ; fora do webroot

expose_php = Off
allow_url_fopen = Off                  ; mitiga SSRF
allow_url_include = Off                ; CRÍTICO

session.cookie_secure = 1
session.cookie_httponly = 1
session.cookie_samesite = "Lax"
session.use_strict_mode = 1

upload_max_filesize = 10M
post_max_size = 12M
max_execution_time = 30

; Desativar funções perigosas se a app não as usa
disable_functions = exec,shell_exec,system,passthru,proc_open,popen,eval,assert
```

## Permissões de ficheiros

```bash
# Owner correto (ajustar para o user do PHP)
chown -R www-data:www-data /var/www/html/

# Diretórios: 755
find /var/www/html/ -type d -exec chmod 755 {} \;

# Ficheiros: 644
find /var/www/html/ -type f -exec chmod 644 {} \;

# wp-config.php: o mais restritivo possível
chmod 440 /var/www/html/wp-config.php
```

## Quick wins (faz isto antes de entregar)

- [ ] `WP_DEBUG_DISPLAY = false`, `WP_DEBUG_LOG = false`
- [ ] `DISALLOW_FILE_EDIT = true`, `DISALLOW_FILE_MODS = true`
- [ ] Gerar salts novos via `https://api.wordpress.org/secret-key/1.1/salt/`
- [ ] `display_errors = Off`, `expose_php = Off` no php.ini
- [ ] `allow_url_include = Off`
- [ ] Bloquear `.env`, `wp-config.php.bak`, `.git/`, `*.sql` via .htaccess/nginx
- [ ] Bloquear execução PHP em `/wp-content/uploads/`
- [ ] `wp-config.php` com permissões `440`
- [ ] Apagar `readme.html`, `license.txt`, `phpinfo.php`, `install.php` esquecidos
- [ ] Confirmar HSTS, X-Frame-Options, X-Content-Type-Options nos headers
- [ ] Desativar XML-RPC se não usado

## Falsos positivos
- `WP_DEBUG = true` em ambiente de **dev** (verificar `WP_ENV` ou domínio)
- `display_errors = On` em **dev** local
- `XML-RPC` necessário para Jetpack, app móvel WP, alguns CRMs

## Severidade — em linguagem honesta
- **Crítico:** `wp-config.php.bak` exposto via HTTP, `.git/` exposto, `allow_url_include = On`
- **Alto:** `WP_DEBUG_DISPLAY = true` em prod, salts default, listagem de diretórios
- **Médio:** falta `DISALLOW_FILE_EDIT`, headers verbose (`X-Powered-By`)
- **Baixo:** `readme.html` acessível (info disclosure mínima)
