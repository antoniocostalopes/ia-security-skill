# Checklist Final Antes de Produção

> Marcar tudo antes de `git push` para a branch de produção.

## Inputs e Outputs
- [ ] Todos os inputs (`$_GET`, `$_POST`, `$_REQUEST`, `$_COOKIE`, headers) sanitizados na entrada
- [ ] Todos os outputs escapados no contexto correto (HTML / Atributo / URL / JS)
- [ ] `wp_unslash()` aplicado antes de sanitizar inputs WordPress
- [ ] `wp_kses()` com allowlist explícita (sem `[]` vazio em campos que aceitam HTML)
- [ ] Nenhum `echo $_GET[...]` direto no código

## SQL e `$wpdb`
- [ ] Todas as queries dinâmicas usam `$wpdb->prepare()` ou prepared statements equivalentes
- [ ] Placeholders corretos (`%s` sem aspas extra, `%d` para inteiros)
- [ ] `$wpdb->esc_like()` em queries `LIKE`
- [ ] Identificadores (tabela/coluna) por allowlist ou `%i` (WP 6.2+)
- [ ] Sem `DB::raw()` / `whereRaw` com input não validado

## Autenticação e Autorização
- [ ] `current_user_can($cap)` em **todas** as ações privilegiadas
- [ ] `wp_nonce_field()` em todos os formulários POST
- [ ] `check_admin_referer()` / `check_ajax_referer()` em todos os handlers
- [ ] `permission_callback` definido em **todas** as rotas REST
- [ ] Verificação de ownership em acesso por ID (anti-IDOR)
- [ ] Mass assignment bloqueado (sem `wp_update_user($_POST)` direto)
- [ ] Sessão regenerada após login
- [ ] Reset de password invalida tokens anteriores

## REST / AJAX / Webhooks
- [ ] Rate limiting ativo em login, password reset, OTP, search
- [ ] CORS restrito a origens conhecidas (não `*` em endpoints autenticados)
- [ ] Webhooks verificam assinatura HMAC com `hash_equals()` (comparação constante)
- [ ] Webhooks têm proteção contra replay (timestamp ±5 min + idempotência)
- [ ] Webhooks de pagamento re-validam montante via API antes de marcar pago
- [ ] Sem `wp_ajax_nopriv_*` a executar ações privilegiadas
- [ ] Endpoints state-changing rejeitam GET

## Uploads
- [ ] Validação por **magic bytes** (`finfo` / `wp_check_filetype_and_ext`), não só extensão
- [ ] Diretório de upload sem execução PHP (`.htaccess` / regra Nginx)
- [ ] Limite de tamanho aplicado server-side
- [ ] Nome de ficheiro normalizado (`sanitize_file_name`, sem path traversal)
- [ ] SVG bloqueado ou sanitizado com `enshrined/svg-sanitize`
- [ ] Rate limit por user/IP

## Secrets e Credenciais
- [ ] Sem credenciais hardcoded no código
- [ ] `.env` / `wp-config.php` fora do webroot **ou** bloqueados por servidor
- [ ] `.git/`, `.svn/`, `.hg/` inacessíveis via HTTP
- [ ] Backups (`*.sql`, `*.bak`) fora do webroot
- [ ] API keys em variáveis de ambiente (`getenv()`)
- [ ] Diferentes credenciais por ambiente (dev/staging/prod)
- [ ] Rotação documentada para keys expostas

## Exposição de Dados
- [ ] `WP_DEBUG = false` em produção
- [ ] `WP_DEBUG_DISPLAY = false`
- [ ] `WP_DEBUG_LOG = false` (ou direcionado para fora do webroot)
- [ ] `display_errors = Off` em php.ini
- [ ] `DISALLOW_FILE_EDIT = true`
- [ ] `DISALLOW_FILE_MODS = true` (se não fizeres updates pelo dashboard)
- [ ] `xmlrpc.php` desativado se não usado
- [ ] `/wp-json/wp/v2/users` restrito ou desativado
- [ ] Enumeração `?author=N` bloqueada
- [ ] `readme.html`, `license.txt` removidos ou bloqueados
- [ ] Listagem de diretórios desativada (`Options -Indexes`)
- [ ] Sem `phpinfo()` em ficheiros de teste

## HTTP Headers
- [ ] HTTPS forçado (redirect 301)
- [ ] `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
- [ ] `Content-Security-Policy` definido (mínimo `default-src 'self'`)
- [ ] `X-Frame-Options: SAMEORIGIN` ou `frame-ancestors` em CSP
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] `Permissions-Policy` (geo/mic/camera) restritivo
- [ ] Header `X-Powered-By` removido
- [ ] Header `Server` minimizado
- [ ] Meta `generator` removido

## Cookies
- [ ] `Secure` flag em todos os cookies sensíveis
- [ ] `HttpOnly` em cookies de sessão
- [ ] `SameSite=Lax` (mínimo) em cookies de sessão
- [ ] Tempo de expiração razoável

## Dependências
- [ ] `composer audit` / `npm audit` / `pip-audit` sem CVEs Críticos/Altos
- [ ] WordPress core na última versão estável
- [ ] Todos os plugins/temas atualizados
- [ ] Plugins/temas não usados **removidos** (não só desativados)
- [ ] Sem plugins/temas nulled / pirateados

## Operacional
- [ ] Backups automáticos (BD + uploads)
- [ ] Restore testado nos últimos 30 dias
- [ ] Logs de segurança com retenção mínima 30 dias
- [ ] Alertas para tentativas de login falhadas
- [ ] Plano de resposta a incidente documentado
- [ ] WAF ativo (Cloudflare / Wordfence / Sucuri / fail2ban)
- [ ] Monitoring de uptime e integridade de ficheiros
- [ ] Acesso SSH por chave (sem password)
- [ ] 2FA ativo para todas as contas admin

## Antes do `git push`
- [ ] `.env` no `.gitignore`
- [ ] Sem secrets no diff: `git diff --cached | grep -iE 'key|secret|token|password'`
- [ ] Sem `console.log` / `var_dump` / `error_log` com dados sensíveis
- [ ] Sem `TODO: security` / `FIXME: vulnerable` por resolver
- [ ] Code review por segundo developer (mínimo)
- [ ] Pipeline CI verde (lint + tests + security scan)

---

> **Regra final:** se ficou alguma caixa por marcar, **NÃO faças deploy.**
