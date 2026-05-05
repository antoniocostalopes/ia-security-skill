# Análise — Email e Comunicações Server-Side

> Email é vetor frequente: header injection, link tampering, phishing involuntário. Plus webhooks/SMS — todos os canais que a tua app envia.

## 1. Email Header Injection

Input do utilizador inserido em headers de email permite injetar `Bcc:`, alterar `From:`, etc.

### Sinais de alarme

```php
// BAD
mail($_POST['to'], 'Subject', $body);
// to = "victim@x.com\nBcc: attacker@y.com\nFrom: spoofed@bank.com"

// GOOD — usar lib que valida
use PHPMailer\PHPMailer\PHPMailer;
$mail = new PHPMailer(true);
$mail->addAddress($email);  // PHPMailer valida internamente
$mail->Subject = sanitize_subject($subject);
$mail->Body = $body;
```

```python
# BAD
import smtplib
from email.mime.text import MIMEText
msg = MIMEText(body)
msg['To'] = request.form['to']  # CRLF injection possível em alguns clients
msg['Subject'] = request.form['subject']
smtp.send_message(msg)

# GOOD — validar e usar email.utils
from email.utils import formataddr, parseaddr
to = parseaddr(request.form['to'])
if not to[1] or '\n' in to[1] or '\r' in to[1]:
    raise ValueError('invalid email')
msg['To'] = formataddr(to)
```

```javascript
// Node — nodemailer
// BAD
transporter.sendMail({
  to: req.body.to,  // se aceitar arrays/objects, validação extra
  subject: req.body.subject,  // CRLF possível
});

// GOOD
const { isEmail } = require('validator');
if (!isEmail(req.body.to)) return res.status(400).end();
if (/[\r\n]/.test(req.body.subject)) return res.status(400).end();
```

### Validação de subject/from
```python
def safe_header(s):
    if '\r' in s or '\n' in s:
        raise ValueError('CRLF in header')
    if len(s) > 998:  # RFC 5322 line length
        raise ValueError('header too long')
    return s
```

## 2. Phishing através do teu sistema

A tua app envia emails legítimos, mas atacante consegue manipular conteúdo → email vai com cara de oficial mas link para evil.tld.

### Padrões perigosos

```python
# BAD — template usa URL controlada
def send_welcome(user, signup_url):
    body = f"Click here to confirm: {signup_url}"
    send(user.email, "Welcome", body)

# Se signup_url vem de input user-controlled (ex.: ?next=http://evil.tld) → phishing
# email assinado pelo teu domínio (DKIM ✓) com link malicioso
```

```python
# GOOD — só passa o token, URL constrói-se server-side
def send_welcome(user, token):
    confirm_url = f"https://meusite.tld/confirm?token={token}"  # hardcoded base
    body = f"Click here to confirm: {confirm_url}"
    send(user.email, "Welcome", body)
```

### Open redirect a partir de email
- Email tem link `https://meusite.tld/r?u=<URL>` → endpoint redireciona.
- Se `u` não validado → user clica esperando ir para meusite, vai para evil.
- Mesma defesa de Open Redirect (allowlist).

## 3. SPF, DKIM, DMARC

Configuração DNS — não código, mas crítica. Sem isto, qualquer um manda emails do teu domínio.

### Verificações
```bash
# SPF
dig +short TXT meudominio.tld | grep spf
# Esperado: "v=spf1 include:_spf.google.com ~all"

# DKIM (Google Workspace example)
dig +short TXT google._domainkey.meudominio.tld
# Esperado: "v=DKIM1; k=rsa; p=MIGf..."

# DMARC
dig +short TXT _dmarc.meudominio.tld
# Esperado: "v=DMARC1; p=quarantine; rua=mailto:dmarc@meudominio.tld; pct=100"
```

### Política DMARC
- `p=none` → só monitoring, não bloqueia spoof
- `p=quarantine` → spoof vai para spam
- `p=reject` → spoof rejeitado (recomendado depois de período de teste)

## 4. Links em emails

### Tracking pixels e links
- Trackers próprios: cuidado com user-agent leakage, IP logging que pode ser GDPR concern.
- Trackers de terceiros (Mailgun, SendGrid clicks): aceitar apenas se compliance OK.
- Não usar trackers para emails transacionais sensíveis (password reset, MFA).

### URLs assinadas para links únicos
```python
# Gerar URL com expiry e assinatura
import hmac, hashlib, time, base64

def signed_url(user_id, action, expiry_seconds=3600):
    expires = int(time.time()) + expiry_seconds
    payload = f"{user_id}:{action}:{expires}"
    sig = hmac.new(SECRET, payload.encode(), hashlib.sha256).hexdigest()
    return f"https://meusite.tld/{action}?u={user_id}&e={expires}&s={sig}"

def verify_url(user_id, action, expires, sig):
    if int(expires) < time.time(): return False
    payload = f"{user_id}:{action}:{expires}"
    expected = hmac.new(SECRET, payload.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, sig)
```

## 5. Templates de email

### XSS em emails HTML
- Conteúdo dinâmico em templates HTML deve ser escapado (mesma regra de XSS web).
- Email clients (Gmail, Outlook) sanitizam parcialmente, mas não são WAF — defesa server-side é obrigatória.

```python
# BAD — Jinja autoescape OFF
template = Template("<p>Hello {{ name }}</p>")  # autoescape default em Flask=ON

# GOOD
from jinja2 import Environment, select_autoescape
env = Environment(autoescape=select_autoescape(['html', 'xml']))
```

### Server-Side Template Injection em emails
- Mesma vuln de SSTI mas via templates de email.
- Se utilizador controla nome de template ou conteúdo do template → SSTI.

## 6. SMS / Notifications

### SMS via Twilio/AWS SNS
- Custos altos por SMS — atacante envia 1000 SMS = $$ ao alvo.
- **Rate limit obrigatório** em endpoints que enviam SMS.
- **Confirmar número antes de cobrar quotas** (ex.: opt-in).
- **Não revelar custo no UI** que fique exposto.

```python
# BAD
@app.route('/send-otp', methods=['POST'])
def send_otp():
    sms.send(request.form['phone'], generate_otp())
    # sem rate limit, sem cap diário, sem validação de país

# GOOD
@app.route('/send-otp', methods=['POST'])
@limiter.limit('3/hour')
def send_otp():
    phone = validate_phone(request.form['phone'])
    if phone.country_code in BLOCKED_COUNTRIES:
        abort(400)
    if get_otp_count_today(phone) >= 5:
        abort(429)
    sms.send(phone, generate_otp())
```

### Push notifications
- Conteúdo de push pode aparecer em lock screen → não enviar PII.
- "Mensagem nova" em vez de "Carla diz: Não vou conseguir ir".

## 7. Webhooks outbound (a tua app a chamar)

Já coberto em `webhooks-integracoes.md` mas reforçar:
- Allowlist de URLs de destino se cliente configurar.
- Mascarar dados sensíveis no payload se possível.
- Retry com backoff exponencial, **com limite máximo** (não retry infinito).
- Idempotência key em cada request.

## Quick wins (faz isto antes de entregar)

### Email
- [ ] Substituir `mail()`/`smtplib.send_message` direto por libs (PHPMailer, nodemailer com validação)
- [ ] Validar `\r`, `\n`, comprimento em **todos** os headers (To, From, Subject, Reply-To)
- [ ] URLs em emails construídas server-side com base hardcoded
- [ ] Tokens de email com HMAC + expiry
- [ ] Templates HTML com autoescape ON
- [ ] Sem trackers em emails transacionais (password reset, MFA)

### DNS
- [ ] SPF configurado com `~all` ou `-all`
- [ ] DKIM configurado para o teu provider (Google, Microsoft, SendGrid)
- [ ] DMARC `p=quarantine` (depois `p=reject`)
- [ ] BIMI opcional (logo verificado em Gmail)

### SMS / Push
- [ ] Rate limit em endpoints que enviam SMS (≤ 5/hora por user/IP)
- [ ] Cap diário global de SMS (anti-bill-shock)
- [ ] Allowlist/blocklist de país
- [ ] Push notifications sem PII

### Webhooks outbound
- [ ] Retry limitado (3-5 tentativas) com backoff exponencial
- [ ] Timeout em cada chamada
- [ ] Idempotency key no payload

## Falsos positivos
- Email interno (sysadmin to sysadmin) com headers fixos — OK
- SMS interno com lista hardcoded de números — OK
- Webhooks com URL hardcoded em config — sem necessidade de allowlist runtime

## Severidade — em linguagem honesta
- **Crítico:** Email Header Injection que permite spoofar `From:` (usado para phishing externo)
- **Alto:** SMS endpoint sem rate limit (atacante esgota orçamento)
- **Alto:** SPF/DKIM/DMARC ausentes (qualquer um spoofs o domínio)
- **Médio:** Templates de email com XSS (dependente do cliente de email)
- **Médio:** URLs em emails sem assinatura HMAC (link tampering)
- **Baixo:** Push notifications com PII em lock screen
