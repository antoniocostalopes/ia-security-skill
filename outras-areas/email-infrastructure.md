# Email Infrastructure — Segurança

> Configuração ao nível DNS/SMTP, não app-level (que está em `analises/24-email-comunicacao.md`). Cobre: SPF, DKIM, DMARC, BIMI, MTA-STS, TLS-RPT, DNS records, headers de servidor.

## Quando carregar

- Projeto opera mail server próprio (Postfix, Exim, Sendgrid self-hosted)
- Domínio do cliente envia email transacional/marketing
- DNS records do domínio (zone files `.zone`, `.tf` com `route53_record`/`cloudflare_record`)
- Migração de email provider (analisar config nova)

## Mindset

- **Email foi desenhado em 1982** — confiança implícita, sem auth nativa
- **SPF/DKIM/DMARC** são bolt-ons que assinam autoria — sem eles, qualquer um pode forjar `from:`
- **Spoofing é trivial** sem proteções — basta `telnet smtp:25`
- **MITM no transporte** se sem MTA-STS / TLS-RPT
- **Reputation matters** — IP/domain reputation determina se email chega ao inbox
- **Compliance: GDPR + ePrivacy** — opt-in para marketing, opt-out fácil

## 8 categorias

### 1. SPF mal configurado ou ausente

**BAD** — sem SPF:
```
;; (sem record TXT v=spf1)
```

Qualquer servidor pode enviar email "do" teu domínio. Spam reputation arruinado.

**SPF correto:**
```
@   IN  TXT  "v=spf1 include:_spf.google.com include:sendgrid.net -all"
```

- `-all` (hard fail) > `~all` (soft fail) > `+all` (NUNCA — autoriza tudo)
- `include:` herdar sender approved
- `ip4:`, `ip6:` IPs específicos

**Common bugs:**
- `+all` no fim — equivalente a sem SPF
- Mais de 10 DNS lookups (SPF limit) — mecanismos `include:` aninhados
- Mecanismo `ptr` (deprecated, lento, inseguro)
- Esquecer subdomínios (`mail.example.com` precisa SPF próprio)

### 2. DKIM ausente, chave fraca, ou rotation inexistente

**BAD** — DKIM com 1024-bit key (já obsoleto):
```
default._domainkey.example.com  TXT  "v=DKIM1; k=rsa; p=MIGfMA0GCSqG..."  (1024 bit)
```

**GOOD** — 2048-bit RSA ou Ed25519:
```
selector2025._domainkey.example.com  TXT  "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."  (2048 bit)
```

**Rotation:**
- Selector inclui ano: `s2025-01`, `s2025-07`
- Rotate every 6-12 months
- Old selector permanece publicada com `p=` vazio (revoked)

### 3. DMARC ausente, `p=none` permanente, ou `rua` não monitorizado

DMARC junta SPF+DKIM e instrui receivers o que fazer com fails.

**BAD** — `p=none` permanente:
```
_dmarc.example.com  TXT  "v=DMARC1; p=none"
```

`p=none` é monitor-only. Se ficares aqui anos, atacantes spoofam livremente.

**Progressão correta:**
1. **Mês 1-3:** `p=none; rua=mailto:dmarc@example.com; pct=100` — coletar reports, ver quem envia
2. **Mês 4-6:** `p=quarantine; pct=10`, escalar para 100
3. **Mês 7+:** `p=reject; pct=100; rua=mailto:dmarc@example.com; ruf=mailto:dmarc-forensic@example.com`

**Final:**
```
_dmarc.example.com  TXT  "v=DMARC1; p=reject; rua=mailto:dmarc@example.com; ruf=mailto:dmarc@example.com; fo=1; adkim=s; aspf=s"
```

- `adkim=s` / `aspf=s` — strict alignment
- `fo=1` — reports em qualquer fail (SPF OR DKIM)

### 4. BIMI sem VMC certificate

BIMI mostra logo da empresa no Gmail/Yahoo se DMARC = `p=quarantine` ou `p=reject`.

**Setup:**
```
default._bimi.example.com  TXT  "v=BIMI1; l=https://example.com/logo.svg; a=https://example.com/vmc.pem"
```

- `l=` SVG do logo (Tiny SVG profile, < 32 KB)
- `a=` VMC (Verified Mark Certificate) emitido por Entrust/DigiCert/etc. — caro mas necessário para Gmail mostrar
- VMC valida que a empresa REALMENTE tem direitos sobre a marca

**Sem VMC:** BIMI ignorado por Gmail (sem fallback gracioso, simplesmente não mostra).

### 5. MTA-STS / TLS-RPT — TLS strict para email

**MTA-STS** força TLS no SMTP de servidores que aderem.

`_mta-sts.example.com`:
```
TXT  "v=STSv1; id=20250506T120000;"
```

`https://mta-sts.example.com/.well-known/mta-sts.txt`:
```
version: STSv1
mode: enforce
mx: *.mailgun.org
mx: mx.example.com
max_age: 604800
```

**TLS-RPT** instrui senders a reportar fails:
`_smtp._tls.example.com`:
```
TXT  "v=TLSRPTv1; rua=mailto:tls-reports@example.com"
```

**Sem MTA-STS:** atacante MITM pode downgrade SMTP para plaintext (StartTLS stripping).

### 6. Open relay / SMTP misconfiguration

**BAD** — Postfix `main.cf`:
```
mynetworks = 0.0.0.0/0
smtpd_relay_restrictions = permit_mynetworks
```

Servidor relaya para qualquer destination = spam paradise + reputation kill.

**GOOD:**
```
mynetworks = 127.0.0.0/8 [::1]/128 10.0.0.0/8
smtpd_relay_restrictions =
    permit_mynetworks
    permit_sasl_authenticated
    reject_unauth_destination
```

### 7. Email injection (CRLF) na app

App-level mas crítico: header injection via input não sanitizado:

**BAD** — Python:
```python
def send_email(to_address, subject):
    msg = f"To: {to_address}\nSubject: {subject}\n\nHello"
    smtp.sendmail(from_addr, to_address, msg)
```

User envia `victim@x.com\nBcc: attacker@y.com\nSubject: Spoofed`. Headers injetados.

**GOOD:**
```python
from email.mime.text import MIMEText
msg = MIMEText("Hello")
msg['To'] = to_address  # MIMEText valida e escapa
msg['Subject'] = subject
smtp.send_message(msg)
```

### 8. Reverse DNS (PTR) e HELO inconsistentes

```bash
$ dig -x 1.2.3.4
1.2.3.4.in-addr.arpa.  PTR  some-vps.cheap-host.net.
```

PTR diz "este IP é cheap-host" mas tu envias `HELO mail.example.com`. Receivers ficam suspicious.

**Fix:** ISP/cloud configura PTR matching o HELO (`mail.example.com` ↔ `1.2.3.4`).

## Quick wins

- [ ] SPF: `v=spf1 ... -all`, sem `+all`, < 10 DNS lookups
- [ ] DKIM: 2048-bit (ou Ed25519), selector com data, rotação anual
- [ ] DMARC: roadmap claro `none → quarantine → reject` com `rua` ativamente lido
- [ ] DMARC alignment strict (`adkim=s; aspf=s`) quando viável
- [ ] BIMI com VMC se branding crítico
- [ ] MTA-STS em `mode: enforce` (não testing)
- [ ] TLS-RPT com endpoint que recebe e processa reports
- [ ] PTR record alinhado com HELO
- [ ] SMTP server: `smtpd_relay_restrictions` correto (sem open relay)
- [ ] App-level: usar email library (não construir headers à mão)
- [ ] Subdomínios separados por uso: `mail.`, `notifications.`, `marketing.` (reputation isolation)
- [ ] SPF/DKIM/DMARC para `*.example.com` se subdomínios enviam email
- [ ] Wildcard DMARC para subdomínios não usados: `_dmarc.*` com `p=reject`
- [ ] DNSSEC ativo (próxima secção)
- [ ] List-Unsubscribe header em emails marketing (RFC 8058)
- [ ] Bounce handling (não dar 200 OK a tudo, processar 5xx/4xx)

## Falsos positivos

- `~all` em vez de `-all` — aceitável durante migration phase, problema só se permanente
- DMARC `p=none` durante primeiros 3 meses — esperado, problema se anos
- Múltiplos selectors DKIM publicados — normal durante rotation
- DKIM 1024 em legado — atualizar mas não emergência crítica

## Severidade típica

- **Crítico** — SPF `+all`, sem DMARC + sem SPF (spoofable), open relay, email injection na app
- **Alto** — DKIM 1024-bit, DMARC `p=none` >6 meses, sem MTA-STS num domínio sensível
- **Médio** — DKIM sem rotation, sem TLS-RPT, sem BIMI (estética mais que segurança)
- **Baixo** — PTR mismatch ligeiro, falta de List-Unsubscribe

## Cross-references

- [`../analises/24-email-comunicacao.md`](../analises/24-email-comunicacao.md) — app-level email
- [`dns-security.md`](dns-security.md) — DNSSEC, DNS records gerais
- [`../analises/13-criptografia.md`](../analises/13-criptografia.md) — RSA vs Ed25519

## Recursos

- [DMARC.org Deployment Guide](https://dmarc.org/overview/)
- [MTA-STS RFC 8461](https://datatracker.ietf.org/doc/html/rfc8461)
- [BIMI Group](https://bimigroup.org/)
- [MX Toolbox](https://mxtoolbox.com/) — verifica config rápida
