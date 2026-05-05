# Análise — Vazamento de Tokens / Secrets

## O que procurar

### Hardcoded
- Strings que parecem chaves/tokens em código:
  - AWS: `AKIA[0-9A-Z]{16}`, `aws_secret_access_key`
  - Google: `AIza[0-9A-Za-z\-_]{35}`
  - Stripe: `sk_live_[0-9a-zA-Z]{24,}`, `pk_live_...`, `whsec_...`
  - GitHub: `ghp_[A-Za-z0-9]{36}`, `github_pat_...`
  - Slack: `xox[baprs]-[A-Za-z0-9-]+`
  - JWT: `eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+`
  - SendGrid: `SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}`
  - Twilio: `SK[0-9a-fA-F]{32}`
  - OpenAI: `sk-[A-Za-z0-9]{48}`
- WordPress: `define('SECURE_AUTH_KEY', 'abc...')` em ficheiros versionados.
- API keys em **JS frontend** (visíveis a qualquer visitante).
- DB credentials em comentários ou ficheiros de config commitados.

### Em logs / erros
- `error_log($payload)` com tokens no payload.
- Stack traces enviados ao Sentry/Logflare incluindo headers `Authorization`.
- WordPress `WP_DEBUG_LOG = true` em produção a logar tudo.

### Em URLs / referrers
- `?api_key=...`, `?token=...`, `?reset=...` em GET — vai para logs do webserver, browser history, Referer header.

### Acessibilidade web
- `.env`, `wp-config.php`, `config.php` no webroot sem bloqueio.
- `.git/`, `.svn/`, `.hg/` acessíveis via HTTP.
- Backups: `*.sql`, `*.sql.gz`, `backup.zip`, `wp-config.php.bak`, `wp-config.php~`.
- `composer.lock`, `package-lock.json`, `yarn.lock` (info de versões).
- `.DS_Store`, `Thumbs.db`.
- `phpinfo()` em ficheiros de teste.

### JWT
- `alg: none` aceito.
- Segredo fraco (`secret`, `password`, default).
- Sem validação de `exp`, `iss`, `aud`.
- Token guardado em `localStorage` (vulnerável a XSS) — preferir cookie `HttpOnly`.

### Sessão
- `session_id` previsível.
- Sem regeneração após login (`session_regenerate_id`).
- Cookies sem `Secure` / `HttpOnly` / `SameSite`.

## Sinais de alarme

```php
// BAD
define('STRIPE_SECRET', 'sk_live_AbCdE...');
$key = 'AKIAIOSFODNN7EXAMPLE';
echo "<script>const apiKey = 'sk-...';</script>";

// GOOD
define('STRIPE_SECRET', getenv('STRIPE_SECRET'));
// ou via wp-config.php fora do repo
```

```bash
# .gitignore deve conter no mínimo
.env
.env.*
wp-config.php
*.sql
*.sql.gz
*.bak
*.swp
.DS_Store
/wp-content/uploads/
```

```apache
# .htaccess raiz — bloquear ficheiros sensíveis
<FilesMatch "(^\.|\.env|\.bak|\.swp|wp-config\.php\.bak|composer\.json|composer\.lock)$">
  Require all denied
</FilesMatch>

RedirectMatch 404 /\.git
RedirectMatch 404 /\.svn
```

```nginx
location ~ /\.(?!well-known) { deny all; }
location ~* \.(env|bak|swp|sql|sql\.gz)$ { deny all; }
location = /wp-config.php { deny all; }
```

## Verificar exposição
```bash
# Procurar secrets no histórico git
git log -p | grep -iE 'api[_-]?key|secret|password|token'

# Verificar .env servido
curl -I https://site.tld/.env
curl -I https://site.tld/.git/config
```

## Quick wins (faz isto antes de entregar)

- [ ] Correr secret scanner (gitleaks, TruffleHog, GitHub Secret Scanning) na CI **e** no histórico
- [ ] Rotacionar **imediatamente** qualquer secret que tenha sido committed (mesmo que removido)
- [ ] Todos os secrets em env vars / Vault / Secrets Manager — **zero** hardcoded
- [ ] `.env`, `wp-config.php`, `.git/`, `*.sql`, `*.bak` bloqueados via servidor (Apache/Nginx)
- [ ] Tokens **nunca** em URLs (sempre em headers ou body POST)
- [ ] JWT com `alg` explícito + `exp`/`iss`/`aud` validados
- [ ] JWT em cookies HttpOnly (não localStorage)
- [ ] Logs sanitizados (sem `Authorization` headers, sem payloads completos)
- [ ] Cookies de sessão com `Secure + HttpOnly + SameSite`
- [ ] Plus: ver `analises/22-logging-monitoring.md` para sanitização de logs

## Falsos positivos
- Strings que parecem keys mas são exemplos em comentários (`// e.g. AKIAEXAMPLE`).
- Constantes definidas a partir de `getenv()` (a string visível é só o nome).
- Tokens públicos por design (ex.: Stripe `pk_live_...` é frontend ok).

## Severidade típica
- Secret de produção hardcoded e commitado: **Crítico**
- `wp-config.php` ou `.env` acessível via HTTP: **Crítico**
- `.git/` exposto: **Crítico**
- Token em URL/log: **Alto**
- Cookie sem `Secure`/`HttpOnly`: **Médio**
- Backup `.sql.bak` exposto: **Crítico**
