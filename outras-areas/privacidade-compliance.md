# Privacidade e Compliance (GDPR, LGPD, CCPA, HIPAA, PCI-DSS)

> Compliance é largamente legal/processual, não código. Mas várias decisões técnicas têm impacto direto. Este módulo cobre o que developer pode/deve fazer.

## GDPR (UE) — princípios técnicos relevantes

### 1. Minimização de dados
Coletar **apenas** o estritamente necessário.
```
- Form de signup precisa de: email, password
- NÃO precisa de: idade, género, telefone, morada
```

### 2. Limitação por finalidade
Dados coletados para X não devem ser usados para Y sem novo consent.

### 3. Direito de acesso (Art. 15)
User pode pedir cópia dos seus dados.
- Implementar endpoint `/api/me/export` que devolve JSON com tudo.
- Incluir dados em todas as tabelas (não só `users`).

### 4. Direito ao esquecimento / apagar (Art. 17)
User pode pedir eliminação.
- Implementar `/api/me/delete` que apaga TUDO (cascade).
- Cuidado com backups — política de retention dos backups.
- Logs com PII também devem ser purgáveis.

### 5. Portabilidade de dados (Art. 20)
Export em formato standard (JSON, CSV).

### 6. Privacy by design / by default
Defaults seguros e privados (ex.: perfil privado por default, não público).

### 7. Breach notification (Art. 33)
Vazamento → notificar autoridade em 72h.
- Logging robusto + alertas para detetar breaches rapidamente.
- Plano de incident response documentado.

### 8. Data Protection Impact Assessment (DPIA)
Para processamentos de alto risco. Não é código mas pode levar a requisitos técnicos.

## LGPD (Brasil) — análogo a GDPR

Praticamente equivalente em requisitos técnicos. Mesmas práticas funcionam.

## CCPA / CPRA (Califórnia)

Equivalente leve a GDPR. Similar:
- Right to know
- Right to delete
- Right to opt-out (sale of personal info)
- Non-discrimination

## HIPAA (EUA, dados de saúde)

Requisitos técnicos extras:
- **Encryption at rest** obrigatória para PHI
- **Encryption in transit** obrigatória
- **Audit logs** robustos (quem acedeu o quê)
- **Access controls** granular per-user
- **Backups encriptados**
- **Disposal seguro** de dados antigos
- **Business Associate Agreements** (BAAs) com cloud providers

Cloud providers HIPAA-compliant: AWS, GCP, Azure (todos com BAA disponível).

## PCI-DSS (cartões de pagamento)

Aplicável se processas/armazenas/transmites PAN (Primary Account Number).

### Princípio: **não armazenar PAN**
Usa tokenização via Stripe, Adyen, PayPal, Braintree, etc. — eles armazenam o PAN, tu armazenas o token.

### Se mesmo precisares de armazenar:
- **Nunca** armazenar CVV/CVC (proibido absolutamente)
- PAN encriptado at rest (TDE, application-level)
- Network segmentation (CDE — Cardholder Data Environment)
- Logging de acesso a dados PAN
- Annual audit (QSA assessment para Level 1)

## Implementação técnica — patterns

### 1. PII redaction em logs
```python
SENSITIVE_KEYS = {'password', 'ssn', 'nif', 'credit_card', 'cvv', 'iban',
                  'phone', 'address', 'date_of_birth', 'medical_record'}

def redact_pii(obj):
    if isinstance(obj, dict):
        return {k: '[REDACTED]' if k.lower() in SENSITIVE_KEYS else redact_pii(v)
                for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact_pii(x) for x in obj]
    return obj
```

### 2. Soft delete vs hard delete
```python
# Soft delete — manter row com flag
class User:
    deleted_at = Column(DateTime, nullable=True)

def soft_delete(user):
    user.deleted_at = datetime.utcnow()
    user.email = f"deleted-{user.id}@deleted.local"  # anonimizar email
    user.name = "Deleted User"
    db.commit()

# Hard delete — fisicamente apagar
def hard_delete(user_id):
    db.execute("DELETE FROM users WHERE id = ?", [user_id])
    db.execute("DELETE FROM user_data WHERE user_id = ?", [user_id])
    db.execute("DELETE FROM logs WHERE user_id = ?", [user_id])  # logs também
    # Backup retention policy: dados em backups serão purgados em 30/90 dias
```

### 3. Data retention policy
```sql
-- Cron diário
DELETE FROM access_logs WHERE created_at < NOW() - INTERVAL '90 days';
DELETE FROM password_reset_tokens WHERE created_at < NOW() - INTERVAL '7 days';
DELETE FROM email_verification_tokens WHERE created_at < NOW() - INTERVAL '30 days';

-- Anonimizar em vez de delete onde aplicável
UPDATE users
SET email = CONCAT('deleted-', id, '@deleted.local'),
    name = 'Deleted User',
    phone = NULL
WHERE deleted_at < NOW() - INTERVAL '30 days';
```

### 4. Consent tracking
```sql
CREATE TABLE consents (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id),
    purpose VARCHAR(100) NOT NULL,  -- 'marketing', 'analytics', etc.
    granted BOOLEAN NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT
);
```

### 5. Cookies — consent banner
```javascript
// Antes de qualquer cookie analítico/marketing:
if (!hasConsent('analytics')) {
    return;  // não setar cookies
}
gtag('config', 'GA_ID');
```

Cookies essenciais (sessão) **não precisam de consent** sob GDPR.
Cookies analíticos / marketing **precisam** de consent **explícito** (opt-in, não opt-out).

### 6. PII em URLs — não fazer
```
BAD:  /search?email=user@example.com  (vai para logs, referrer)
GOOD: POST /search { "email": "..." }
```

### 7. Headers sensíveis
```
- Cookies de sessão sem dados de PII embedded
- Headers custom sem info pessoal
- Sem `X-User-Email` ou similares em logs HTTP
```

### 8. Cross-border transfers
- Dados de UE para EUA → Standard Contractual Clauses (SCCs) ou Data Privacy Framework
- Cloud providers em UE para dados de UE (ou regiões specific)
- Documentar transfers em ROPA (Record of Processing Activities)

## Right to be Forgotten — implementação cuidadosa

Apagar user em sistema com:
- **Backups** — não consegues apagar de backups antigos. Documenta retention policy.
- **Logs** — alguns logs com user_id devem ser anonimizados, não apagados (audit trail).
- **Eventos analíticos** — se já agregados, podem ficar (não-identifiable).
- **Webhooks enviados a terceiros** — pedir terceiros para apagar (BAAs/DPAs)
- **Cache** — invalidar entries com user data
- **CDN cache** — purge se aplicável
- **Email queue** — cancelar emails pendentes
- **Search index** (Elasticsearch, Algolia) — re-index ou delete document
- **Replicas / read replicas** — propagação automática se DB
- **Backups offline** — esperar até purga natural

## Relatórios para utilizadores

```
GET /api/me/export
→ {
    "user": { ... },
    "posts": [...],
    "comments": [...],
    "logs": [...],
    "consents": [...],
    "exported_at": "2026-05-05T12:00:00Z"
  }
```

## Common antipatterns

### Email em URL
- `?email=x@y.com` em logs, referrers, browser history.

### Sem soft delete + hard delete plan
- "Deletar" só faz `is_deleted=true` para sempre. GDPR exige delete real.

### Logging de payloads completos com PII
- Logs persistem indefinidamente.

### Cookies de tracking sem consent
- Multas GDPR (até 4% do revenue global).

### Cross-border transfers sem documentação
- Schrems II ruling — UE-EUA exige SCCs + DPF.

### Dependência de "we don't store PII" sem auditoria
- Logs, caches, replicas frequentemente armazenam.

### Pedir mais dados que necessário
- "Date of birth" obrigatório quando idade já chega.

## Compliance checklist

- [ ] Data minimization — auditar campos coletados
- [ ] Privacy policy atualizada e acessível
- [ ] Cookie consent banner (opt-in para analytics/marketing)
- [ ] Endpoint `/me/export` (data portability)
- [ ] Endpoint `/me/delete` (right to erasure)
- [ ] Soft delete + hard delete schedule
- [ ] Data retention policy documentada e implementada
- [ ] PII redaction em logs
- [ ] Encryption at rest (DB)
- [ ] Encryption in transit (TLS)
- [ ] Audit logs para acesso a dados sensíveis
- [ ] Breach notification plan (72h GDPR)
- [ ] DPO designado (se obrigatório pelo tamanho)
- [ ] DPA (Data Processing Agreement) com sub-processors (cloud, etc.)
- [ ] BAA com cloud provider (HIPAA)
- [ ] Stripe/Adyen para PCI tokenization (não armazenar PAN)
- [ ] ROPA documentado
- [ ] DPIAs feitos para high-risk processing
- [ ] Annual security audit (interno ou externo)

## Ferramentas

- **OneTrust / Cookiebot** — consent management
- **Privacera / BigID** — data discovery + classification
- **Stripe / Adyen / Braintree** — PCI tokenization
- **AWS / GCP / Azure** — todos com HIPAA, GDPR, SOC 2 compliance disponível
- **Vanta / Drata** — automated SOC 2 / GDPR / ISO 27001 audits

## Severidade

- **Crítico:** PAN/CVV armazenado em plain text → PCI violation imediata
- **Crítico:** PII de utilizadores UE em país sem adequacy decision → GDPR violation
- **Alto:** Sem mechanism para right to erasure → GDPR fine 4% revenue
- **Alto:** Cookies de tracking sem consent banner → GDPR fine
- **Médio:** Logs com PII sem retention policy clara
- **Médio:** Backups sem encryption at rest
- **Baixo:** Privacy policy desatualizada
