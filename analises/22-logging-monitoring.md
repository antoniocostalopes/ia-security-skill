# Análise — Logging e Monitoring

> OWASP A09. O quê logar e o quê **não** logar. Logs maus = sem forense em incidente. Logs com PII = data leak. Sem alertas = atacante demora-se 200 dias antes de detetares.

## O que procurar

### 1. Eventos de segurança que devem ser logados

| Evento | Porquê |
|---|---|
| Login (sucesso e falha) | Detetar brute force / takeover |
| Logout | Trail de sessão |
| Password change | Detetar takeover post-fact |
| Email change | Detetar takeover |
| MFA enable/disable | Mudanças críticas |
| Permission/role change | Privilege escalation forense |
| Reset password requested/completed | Detetar abuse |
| Account lockout | Trail de defesa |
| Acesso a dados sensíveis (PII, dados financeiros) | Compliance + forense |
| Operações administrativas | Auditoria |
| API key created/revoked | Trail |
| Falhas de autorização (403) | Detetar enumeração |
| Falhas de validação (400) com pattern suspeito | Detetar varreduras |
| Webhooks recebidos / processados | Anti-fraude |

### 2. O que NUNCA logar

| ❌ Nunca | ❌ Por quê |
|---|---|
| Passwords (mesmo cifradas/hash) | Vazamento total se logs vazam |
| Tokens completos (JWT, sessão, API keys) | Reuso por quem ler o log |
| Cookies completos | Idem |
| `Authorization` header completo | Contém tokens/credenciais |
| Números completos de cartão de crédito (PAN) | PCI-DSS proibe |
| CVV / CVC | PCI-DSS proibe absolutamente |
| Dados médicos sem mascaramento (HIPAA) | Compliance |
| PII completa sem necessidade (NIF, IBAN, morada) | GDPR/LGPD |
| Stack traces em produção (em respostas HTTP) | Info disclosure ao atacante |
| Conteúdo de payloads encriptados antes de cifrar | Defeats encryption |
| Credenciais de DB / S3 / cloud | Game over |

### 3. Padrões perigosos

```python
# BAD — loga tudo
logger.info(f"Login attempt: {request.json}")
# Se request.json = {"email": "a@b.com", "password": "secret123"}
# → password no log

# GOOD
logger.info(f"Login attempt for email={request.json.get('email')}")
# password nunca tocada
```

```javascript
// BAD
app.use((req, res, next) => {
  console.log('Request:', { headers: req.headers, body: req.body });
  next();
});
// Authorization, cookies, password no log

// GOOD — middleware com sanitização
const SENSITIVE_HEADERS = ['authorization', 'cookie', 'x-api-key'];
const SENSITIVE_BODY_FIELDS = ['password', 'token', 'secret', 'creditCard'];

function sanitize(obj, sensitive) {
  return Object.fromEntries(
    Object.entries(obj).map(([k, v]) =>
      [k, sensitive.includes(k.toLowerCase()) ? '[REDACTED]' : v]
    )
  );
}

app.use((req, res, next) => {
  console.log('Request:', {
    method: req.method,
    path: req.path,
    headers: sanitize(req.headers, SENSITIVE_HEADERS),
    body: sanitize(req.body, SENSITIVE_BODY_FIELDS),
  });
  next();
});
```

```php
// BAD
error_log("Payment: " . print_r($_POST, true));
// $_POST['card_number'] no log

// GOOD
$safe = $_POST;
foreach (['card_number', 'cvv', 'password'] as $f) {
    if (isset($safe[$f])) $safe[$f] = '[REDACTED]';
}
error_log("Payment attempt: " . json_encode(array_intersect_key($safe, array_flip(['email', 'amount']))));
```

### 4. Mascaramento de PII em logs

```python
def mask_email(email):
    if '@' not in email: return email
    local, domain = email.split('@', 1)
    return f"{local[:2]}***@{domain}"

def mask_card(pan):
    if len(pan) < 13: return '[INVALID]'
    return f"{pan[:6]}{'*' * (len(pan) - 10)}{pan[-4:]}"  # PCI tokenization
```

### 5. Estrutura de log (structured logging)

```python
# BAD — string concatenation
logger.info(f"User {user_id} logged in from {ip}")
# difícil de parsear, agregar, alertar

# GOOD — structured
logger.info("user.login.success", extra={
    "user_id": user_id,
    "ip": ip,
    "user_agent": ua_hash,  # hash, não UA completo
    "session_id_hash": hashlib.sha256(session_id.encode()).hexdigest()[:16],
})
```

### 6. Onde devem ir os logs

```
✓ Sistema de logs centralizado (ELK, Datadog, Loki, CloudWatch, Splunk)
✓ Retention: ≥ 90 dias para security events, ≥ 1 ano para auditoria
✓ Imutável (append-only) — atacante não pode apagar trail
✓ Backups separados do servidor que gera os logs

✗ /var/www/html/logs/ (acessível via web)
✗ Mesmo disco que a app sem rotação
✗ Stdout sem capture
```

### 7. Alertas que devem existir

| Alerta | Threshold sugerido |
|---|---|
| Tentativas de login falhadas | > 10 falhas/min de mesmo IP ou para mesmo user |
| Account lockouts | > 5 lockouts/hora |
| Resposta 401/403 em rajada | > 50/min de mesmo IP (varredura) |
| Resposta 5xx | > 1% das requests |
| Latência elevada | p99 > 2s |
| Webhook signature failures | > 3/hora (atacante a tentar forjar) |
| Reset de password em massa | > 20/hora globalmente |
| Privilege escalation events | qualquer (alerta imediato) |
| API key created/revoked | qualquer |
| Permission change para admin | qualquer |
| Acesso a `/admin/*` por user não-admin | qualquer |

### 8. Anti-tampering

- Logs com **HMAC** ou assinatura por entry → atacante não consegue editar sem deixar trail.
- Append-only storage (S3 com Object Lock, etc.).
- Forwarding em real-time para sistema separado.

### 9. Time sync

- Servidor com NTP configurado e a funcionar.
- Logs em UTC (não timezone local).
- Timestamps com millisegundos.

### 10. Correlation IDs

```javascript
// Cada request recebe um ID que viaja por todo o stack
app.use((req, res, next) => {
  req.id = req.headers['x-request-id'] || crypto.randomUUID();
  res.setHeader('x-request-id', req.id);
  next();
});

// Logs incluem req.id sempre
logger.info({ requestId: req.id, event: 'payment.start', amount });
// → permite tracing cross-service
```

## Receita rápida — sanitização de logs (universal)

```python
SENSITIVE_KEYS = {'password', 'pwd', 'secret', 'token', 'authorization',
                  'cookie', 'api_key', 'access_token', 'refresh_token',
                  'card_number', 'cvv', 'pan', 'ssn', 'nif', 'iban'}

def redact(obj, depth=0):
    if depth > 5: return '[TRUNCATED]'
    if isinstance(obj, dict):
        return {k: ('[REDACTED]' if k.lower() in SENSITIVE_KEYS
                    else redact(v, depth + 1))
                for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact(x, depth + 1) for x in obj[:100]]  # cap também
    return obj
```

## Quick wins (faz isto antes de entregar)

- [ ] Listar todos os `logger.X(payload)` / `console.log(req.body)` — sanitizar
- [ ] Implementar middleware central de log com redação automática
- [ ] Eventos de auth (login, logout, reset, mfa) logados estruturadamente
- [ ] Retention configurada (≥ 90 dias para security events)
- [ ] Logs vão para sistema centralizado, não disco do app server
- [ ] `/var/log/`, `debug.log` **fora** do webroot
- [ ] Alertas configurados para os 5-10 eventos críticos
- [ ] Correlation ID em cada request
- [ ] Stack traces **nunca** em respostas HTTP em produção
- [ ] Timezone UTC consistente, NTP a funcionar

## Falsos positivos
- Logs locais em **dev** com payloads completos — OK (mas verifica `.gitignore`)
- Logging de eventos públicos não sensíveis (page views) sem PII — OK sem retention longa
- Stack traces em endpoint de health check interno — OK

## Severidade — em linguagem honesta
- **Crítico:** passwords/tokens em logs em produção (data leak se logs vazarem)
- **Crítico:** sem logging de auth events (incidente vai ser cego)
- **Alto:** logs no webroot acessíveis via HTTP
- **Alto:** sem alertas — atacante demora 200 dias a ser detetado
- **Médio:** PII completa em logs sem mascaramento
- **Médio:** stack traces em respostas HTTP em prod
- **Baixo:** logs sem correlation ID (dificulta forense, não é vuln direta)
