# Multi-Tenant SaaS — Segurança

> Apps que servem múltiplos clientes na mesma infra. Falha cross-tenant = vazamento de dados de Cliente A para Cliente B = breach reportável a reguladores + lawsuit + perda de contrato.

## Quando carregar

- Schema com `tenant_id`, `org_id`, `workspace_id` em múltiplas tabelas
- Auth com claims tipo `org_id`, `workspace_id`, `team_id`
- Subdomínios por tenant (`acme.app.com`, `corp.app.com`)
- Path-based tenancy (`/orgs/{org_id}/...`)
- Modelos: pool (DB partilhado), bridge (schemas), silo (DB por tenant)

## Mindset

- **Tenant isolation é o core feature, não nice-to-have**
- **IDOR cross-tenant = pior breach possível** num SaaS
- **Compliance:** GDPR Art. 32 (data segregation), SOC 2 (logical access controls), HIPAA BAA
- **Defense in depth:** auth check + tenant filter na query + DB-level enforcement (RLS)
- **Tenant ID nunca vem do client** (header, body, cookie) — sempre do JWT/session

## 9 categorias críticas

### 1. Tenant ID do client em vez do token

**BAD** — `org_id` vem do header:
```javascript
app.get('/api/users', requireAuth, async (req, res) => {
  const orgId = req.headers['x-org-id'];  // CONTROLADO PELO CLIENT
  const users = await db.users.findMany({ where: { orgId } });
  res.json(users);
});
```

Atacante muda header `X-Org-Id: 999` e vê users de outro tenant.

**GOOD** — `org_id` do JWT:
```javascript
app.get('/api/users', requireAuth, async (req, res) => {
  const orgId = req.user.orgId;  // do JWT verified
  const users = await db.users.findMany({ where: { orgId } });
  res.json(users);
});
```

### 2. Filtros tenant esquecidos em queries

**BAD** — query sem WHERE tenant:
```javascript
app.get('/api/projects/:id', requireAuth, async (req, res) => {
  const project = await db.projects.findUnique({
    where: { id: req.params.id }
  });
  res.json(project);
});
```

Atacante muda `:id` para projeto de outro tenant — sem filtro `orgId`, devolve.

**GOOD** — sempre incluir tenant filter:
```javascript
app.get('/api/projects/:id', requireAuth, async (req, res) => {
  const project = await db.projects.findFirst({
    where: {
      id: req.params.id,
      orgId: req.user.orgId   // CRITICAL
    }
  });
  if (!project) return res.status(404).end();
  res.json(project);
});
```

### 3. Sem RLS (Row-Level Security) na DB

App-level filters falham eventualmente. RLS força no DB:

**PostgreSQL com RLS:**
```sql
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON projects
  USING (org_id = current_setting('app.current_org_id', true)::uuid);
```

E no app, antes de cada query:
```javascript
await db.$executeRaw`SET app.current_org_id = ${req.user.orgId}`;
const projects = await db.projects.findMany();  // RLS filtra automaticamente
```

Mesmo se developer esquece o WHERE, RLS bloqueia. Defense in depth.

### 4. JOIN cross-tenant não filtrado

**BAD**:
```sql
SELECT p.*, u.name
FROM projects p
JOIN users u ON u.id = p.created_by
WHERE p.org_id = $1
```

Se `users` não filtrar `org_id`, JOIN vaza nomes de users de outros tenants (mesmo que `p.org_id` esteja certo).

**GOOD:**
```sql
SELECT p.*, u.name
FROM projects p
JOIN users u ON u.id = p.created_by AND u.org_id = p.org_id
WHERE p.org_id = $1
```

### 5. Cache cross-tenant

**BAD** — Redis key sem tenant:
```javascript
const cacheKey = `user:${userId}`;
await redis.set(cacheKey, JSON.stringify(user));
```

Se `user.id` for número sequencial e duas tenants tiverem ID 5, vão sobrepor cache.

**GOOD:**
```javascript
const cacheKey = `tenant:${orgId}:user:${userId}`;
await redis.set(cacheKey, JSON.stringify(user));
```

### 6. Files / object storage sem tenant prefix

**BAD** — S3:
```
s3://my-bucket/uploads/12345.pdf
```

Atacante adivinha IDs e tenta `12346.pdf`, `12347.pdf`...

**GOOD** — path com tenant + UUIDs:
```
s3://my-bucket/orgs/{org_id}/uploads/{uuid}.pdf
```

E IAM policy / signed URLs verificam tenant.

### 7. Background jobs sem contexto tenant

**BAD** — job processa user input sem confirmar tenant:
```javascript
queue.process('export-data', async (job) => {
  const { userId, orgId } = job.data;
  const data = await db.users.findUnique({ where: { id: userId } });
  await sendEmail(data.email, 'export.csv');
});
```

`orgId` em `job.data` veio do user originalmente — manipulável.

**GOOD** — verificar que userId pertence a orgId:
```javascript
queue.process('export-data', async (job) => {
  const { userId, orgId } = job.data;
  const user = await db.users.findFirst({
    where: { id: userId, orgId }
  });
  if (!user) throw new Error('Tenant mismatch');
  await sendEmail(user.email, 'export.csv');
});
```

### 8. Subdomain tenant + cookies SameSite

**BAD** — cookie do `app.com` com `Domain=.app.com`:
```
Set-Cookie: session=xxx; Domain=.app.com
```

`acme.app.com` e `evil-tenant.app.com` partilham cookies. Atacante regista tenant `evil-tenant`, página com XSS reflete cookie de outro tenant.

**GOOD** — sem `Domain` attribute (host-only):
```
Set-Cookie: session=xxx; Secure; HttpOnly; SameSite=Strict
```

Ou usar app domain único + path-based tenancy.

### 9. Admin / superuser sem tenant scoping

**BAD** — admin global vê tudo, sem audit:
```javascript
app.get('/admin/users', requireAdmin, async (req, res) => {
  const users = await db.users.findMany();
  res.json(users);
});
```

Admin malicioso ou comprometido = total breach.

**GOOD:**
- Admin tem scope (`super_admin`, `tenant_admin`, `support_admin`)
- Audit log de cada acesso a tenant data por admin
- Time-bound access (`require_reason` + auto-expire)
- Multi-person approval para cross-tenant queries

## Quick wins

- [ ] `tenant_id` em **todas** as tabelas que armazenam user data
- [ ] `tenant_id` extraído do JWT/session, **nunca** do client headers/body
- [ ] Todas as queries têm filter `tenant_id` (incluindo JOINs)
- [ ] RLS habilitado na DB (PostgreSQL: ENABLE ROW LEVEL SECURITY)
- [ ] Cache keys têm prefix `tenant:{id}:`
- [ ] Object storage paths têm `orgs/{tenant_id}/` prefix
- [ ] Background jobs validam `tenant_id` do payload contra DB
- [ ] Cookies host-only (sem `Domain=.app.com`)
- [ ] CORS por tenant se subdomínios separados
- [ ] Rate limiting por tenant (não por IP global — tenant grande não afeta pequeno)
- [ ] Audit log por tenant (quem acedeu, o quê, quando)
- [ ] Admin actions sobre tenant data têm reason + audit
- [ ] Tenants frias / inactivas têm dados encriptados em rest
- [ ] DB connections pool isolado se silo model
- [ ] Schema migrations testadas com cross-tenant data

## Testing approach

Cada feature deve ter teste cross-tenant:
```javascript
test('cross-tenant access blocked', async () => {
  const tenantA = await createTenant();
  const tenantB = await createTenant();
  const project = await tenantA.createProject();

  const userOfB = await tenantB.createUser();
  const response = await request(app)
    .get(`/api/projects/${project.id}`)
    .set('Authorization', `Bearer ${userOfB.token}`);

  expect(response.status).toBe(404);  // not 403 (revela existência)
});
```

## Falsos positivos

- Tabelas globais legítimas (`countries`, `currencies`, `feature_flags`) — sem tenant filter OK
- Admin endpoints com scope global e audit completo — design intencional
- Cache de assets imutáveis sem tenant — OK

## Severidade típica

- **Crítico** — IDOR cross-tenant ativo, RLS ausente em apps multi-tenant prod, admin sem audit
- **Alto** — JOIN sem tenant filter, cache cross-tenant possível, cookies com Domain wildcard
- **Médio** — rate limit por IP em vez de tenant, sem audit log
- **Baixo** — falta de cross-tenant tests automatizados

## Cross-references

- [`../analises/permissoes.md`](../analises/permissoes.md) — IDOR base
- [`../analises/14-autenticacao-sessao.md`](../analises/14-autenticacao-sessao.md)
- [`../analises/9-exposicao-dados.md`](../analises/exposicao-dados.md)
- [`service-mesh.md`](service-mesh.md) — namespace per tenant
- [`../analises/22-logging-monitoring.md`](../analises/22-logging-monitoring.md) — audit log

## Recursos

- [SaaS Tenant Isolation Strategies (AWS)](https://docs.aws.amazon.com/whitepapers/latest/saas-tenant-isolation-strategies/)
- [PostgreSQL Row Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
