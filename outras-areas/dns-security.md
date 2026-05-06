# DNS / DNSSEC — Segurança

> DNS é o fundamento da internet e o vetor menos auditado. Falhas aqui silenciam toda a app: redirecionamento, takeover, MITM no transporte.

## Quando carregar

- Zone files (`.zone`, `.bind`)
- Terraform com `aws_route53_*`, `cloudflare_record`, `azurerm_dns_*`, `google_dns_record_set`
- Migração de DNS provider
- Domínios próprios geridos pela equipa

## Mindset

- **DNS sem DNSSEC** = qualquer resolver pode ser envenenado
- **Subdomain takeover** quando record aponta para serviço cancelado
- **Zone transfer (AXFR)** público leak da topologia interna
- **DNS rebinding** ataca apps locais via browser
- **CAA records** controlam quem pode emitir SSL para o teu domínio

## 8 categorias

### 1. Subdomain takeover

Records `CNAME` apontam para serviços externos (Heroku, Azure, GitHub Pages). Se o serviço for desprovisionado mas o record permanecer, atacante reclama o serviço com o teu nome.

**BAD** — record órfão:
```
old-app  IN  CNAME  old-app.herokuapp.com.
```
(mas a app foi removida do Heroku)

Atacante:
1. Cria conta Heroku com app `old-app.herokuapp.com`
2. Heroku aceita (nome livre)
3. Atacante agora controla `old-app.example.com` — pode servir phishing, roubar cookies de sessão (se SameSite Lax + path same), receber emails se MX...

**GOOD:**
- Auditoria periódica: `dig +short ALL_SUBDOMAINS` e cross-check com providers ativos
- Tools: `subjack`, `subzy`, `nuclei -t takeovers`
- Apagar records de serviços cancelados imediatamente

**Vulnerable services list:** [github.com/EdOverflow/can-i-take-over-xyz](https://github.com/EdOverflow/can-i-take-over-xyz)

### 2. Zone transfer (AXFR) público

```bash
dig @ns1.example.com example.com AXFR
```

Se devolver toda a zone, atacante tem mapa completo: subdomínios internos, MX, SPF includes, IPs.

**Fix** — restrict AXFR ao secundário:
```
# BIND named.conf
zone "example.com" {
  type master;
  file "example.com.zone";
  allow-transfer { 192.0.2.2; };  // só secundário
};
```

### 3. CAA records ausentes

Sem `CAA`, qualquer CA pode emitir SSL para o teu domínio. Atacante com fake authority pode obter cert e MITM.

**Fix** — restringir CAs:
```
example.com  CAA  0 issue "letsencrypt.org"
example.com  CAA  0 issuewild ";"
example.com  CAA  0 iodef "mailto:security@example.com"
```

- `issue` — quem pode emitir end-entity certs
- `issuewild` — quem pode emitir wildcards (`;` = ninguém)
- `iodef` — onde reportar tentativas inválidas

### 4. DNSSEC ausente

Sem DNSSEC, recursive resolvers não verificam autenticidade — atacante envenena cache, redireciona tráfego.

**Setup (Route53 com Terraform):**
```hcl
resource "aws_route53_key_signing_key" "example" {
  hosted_zone_id            = aws_route53_zone.example.id
  key_management_service_arn = aws_kms_key.dnssec.arn
  name                      = "key-2025"
}

resource "aws_route53_hosted_zone_dnssec" "example" {
  hosted_zone_id = aws_route53_zone.example.id
}
```

E publicar DS record no registrar (parent zone). Verificar com:
```bash
dig +dnssec example.com
```
Procurar flag `ad` (authenticated data).

### 5. DoH/DoT bypass / DNS over plaintext

Cliente consultar DNS sobre UDP plaintext = MITM trivial em redes hostis.

**Server-side:**
- Configurar resolver com DoH/DoT (Cloudflare 1.1.1.1, Google 8.8.8.8 suportam)
- BIND/Unbound: usar `forward-tls-upstream: yes`

**Client-side (apps):**
- Não usar resolver do SO se não confias na rede
- Usar libraries DoH (`getdns`, `dnsviz`)

### 6. DNS rebinding (browser-side)

Server malicioso retorna TTL=0 com IP público inicial (passa SOP), depois retorna IP privado (192.168.1.1) — browser pensa same-origin e ataca app local.

**Mitigação app-level:**
- Validar `Host` header em todas as requests:
```python
ALLOWED_HOSTS = {'localhost', '127.0.0.1', 'app.local'}
if request.host.split(':')[0] not in ALLOWED_HOSTS:
    abort(400)
```
- IoT/local services: bind a `localhost` ou usar TLS com cert que matches só o host esperado

### 7. Wildcard records perigosos

```
*.example.com  A  1.2.3.4
```

Qualquer subdomain inexistente resolve para 1.2.3.4. Atacante regista subdomain via XSS no DNS (algumas vulnerabilidades), ou simplesmente apresenta-se como `random-string.example.com` para phishing.

**Quando é OK:**
- SaaS multi-tenant onde wildcard é deliberado
- App com tenants em subdomínios

**Quando é mau:**
- Domínio principal corporate sem necessidade
- Wildcard com TLS wildcard cert que vaza para toda a infra

### 8. NS / SOA delegation chain

Verificar:
- Todos os NS records resolvem
- TTLs razoáveis (3600+ para records estáveis)
- SOA email reachable
- Sem mismatched glue records

## Quick wins

- [ ] DNSSEC ativo + DS record no registrar
- [ ] Subdomínios auditados periodicamente (sem takeovers possíveis)
- [ ] CAA records com lista mínima de CAs autorizados
- [ ] CAA `iodef` com email monitorizado
- [ ] AXFR restringido aos NS secundários
- [ ] Records órfãos apagados imediatamente quando serviço é cancelado
- [ ] Wildcard records evitados (ou justificados)
- [ ] Hosts no app com `ALLOWED_HOSTS` validation
- [ ] Resolver DoH/DoT em ambientes corporate
- [ ] TTLs razoáveis (não < 60s sem motivo)
- [ ] Email do SOA monitorizado
- [ ] Registrar trancado contra transfer (registry lock se domain crítico)
- [ ] 2FA no painel do registrar
- [ ] DNS provider com auditoria/logging (CloudFlare, Route53 com CloudTrail)

## Falsos positivos

- Wildcard em SaaS multi-tenant — esperado
- TTL baixo durante migration — temporário OK
- AXFR público entre NS secundários (allow-transfer com IPs específicos) — OK

## Severidade típica

- **Crítico** — subdomain takeover ativo, sem DNSSEC + tráfego sensível, AXFR público num domínio enterprise
- **Alto** — sem CAA, sem DNSSEC, wildcard expondo phishing path
- **Médio** — TTLs irrealistas, falta de iodef
- **Baixo** — SOA email não monitorizado

## Cross-references

- [`email-infrastructure.md`](email-infrastructure.md) — DNS records para SPF/DKIM/DMARC/MTA-STS
- [`../analises/13-criptografia.md`](../analises/13-criptografia.md) — DNSSEC algorithms
- [`../analises/20-open-redirect-ssrf.md`](../analises/20-open-redirect-ssrf.md) — DNS rebinding via SSRF

## Recursos

- [DNSSEC Analyzer](https://dnssec-analyzer.verisignlabs.com/)
- [SSL Labs DNS](https://www.ssllabs.com/ssltest/) — também CAA
- [Subdomain takeover catalog](https://github.com/EdOverflow/can-i-take-over-xyz)
- [MX Toolbox DNS](https://mxtoolbox.com/SuperTool.aspx)
