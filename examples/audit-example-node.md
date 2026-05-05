# Exemplo de Auditoria — App Node.js / Express

> Exemplo completo: input (código vulnerável) → output (relatório esperado).
> Serve como **few-shot reference** para IAs aprenderem o formato.

## Input — código submetido para auditoria

**Estrutura:**
```
my-api/
├── package.json
├── server.js
├── routes/
│   ├── auth.js
│   └── users.js
└── db.js
```

### `package.json`
```json
{
  "name": "my-api",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.16.0",
    "mysql2": "^2.0.0",
    "jsonwebtoken": "^8.5.1",
    "bcrypt": "^5.0.0"
  }
}
```

### `server.js`
```javascript
const express = require('express');
const cookieParser = require('cookie-parser');
const app = express();

app.use(express.json());
app.use(cookieParser());

app.use(require('./routes/auth'));
app.use(require('./routes/users'));

app.listen(3000, () => console.log('listening on 3000'));
```

### `routes/auth.js`
```javascript
const express = require('express');
const jwt = require('jsonwebtoken');
const router = express.Router();
const db = require('../db');

const SECRET = 'super_secret_123';

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const [rows] = await db.query(
    `SELECT * FROM users WHERE email = '${email}'`
  );
  if (rows.length === 0) {
    return res.status(401).json({ error: 'User not found' });
  }
  const user = rows[0];
  if (user.password !== password) {
    return res.status(401).json({ error: 'Wrong password' });
  }
  const token = jwt.sign({ id: user.id, role: user.role }, SECRET);
  res.json({ token, user });
});

module.exports = router;
```

### `routes/users.js`
```javascript
const express = require('express');
const router = express.Router();
const db = require('../db');

router.get('/users/:id', async (req, res) => {
  const [rows] = await db.query(
    `SELECT * FROM users WHERE id = ${req.params.id}`
  );
  res.json(rows[0]);
});

router.post('/users/:id', async (req, res) => {
  const updates = req.body;
  await db.query('UPDATE users SET ? WHERE id = ?', [updates, req.params.id]);
  res.json({ ok: true });
});

router.get('/users/:id/avatar', async (req, res) => {
  const file = req.query.file;
  res.sendFile(`/var/uploads/${file}`);
});

module.exports = router;
```

---

## Output — Relatório esperado da skill

```markdown
# Relatório de Segurança — my-api

**Data:** 2026-05-05
**Auditor:** Skill de Segurança (António Lopes) v1.0.0
**Stack:** Node.js + Express 4 + MySQL2 + JWT
**Ficheiros analisados:** 4 (server.js, routes/auth.js, routes/users.js, db.js)
**Linhas de código:** ~50

---

## 1. Score de Segurança

```
Score: 0/100
[░░░░░░░░░░░░░░░░░░░░] 0%
```

**Nível de blindagem:** **Crítico — NÃO PUBLICAR**

| Severidade | Quantidade | Peso unitário | Subtotal |
|---|---:|---:|---:|
| Crítico | 5 | -20 | -100 |
| Alto    | 3 | -10 | -30 |
| Médio   | 2 |  -4 | -8 |
| Baixo   | 1 |  -1 | -1 |
| **Total** | **11** | | **-139 (cap a 0)** |

---

## 2. Resumo para o Cliente

Esta API tem 5 problemas críticos que permitem a qualquer atacante na internet roubar a base de dados completa, fazer-se passar por qualquer utilizador, e ler ficheiros do servidor. **Não publicar.** As correções são simples — todas conhecidas, biblioteca standard. Estimo **1 dia de trabalho** para deixar tudo blindado. Boa notícia: nenhum problema é arquitetural, são patches localizados.

---

## 3. Resumo Técnico

Padrão recorrente: **input do user concatenado em SQL** (SQLi clássico em 2 endpoints) + **passwords em plaintext** (sem bcrypt apesar de declarado em deps) + **JWT secret hardcoded** + **path traversal** no avatar endpoint + **mass assignment** no update de user (atacante pode promover-se a admin). Falta auth middleware, rate limiting, validação de input, e CORS config. Architecture é simples e fácil de corrigir — aplicar Zod para validation, parameterized queries em mysql2, bcrypt.compare(), JWT secret via env var, allowlist de campos no update, path normalization no sendFile.

---

## 4. Mapa de Superfícies de Ataque

| # | Superfície | Localização | Auth | Exposição | Risco |
|---|---|---|---|---|---|
| 1 | POST /login | routes/auth.js:8 | Pública | Pública | Crítico |
| 2 | GET /users/:id | routes/users.js:5 | Nenhuma | Pública | Crítico |
| 3 | POST /users/:id | routes/users.js:11 | Nenhuma | Pública | Crítico |
| 4 | GET /users/:id/avatar | routes/users.js:16 | Nenhuma | Pública | Alto |

---

## 5. Previsão de Vetores Prováveis e Attack Chains

### Vetor 1 — Roubo total da base de dados (Crítico)
- **Encadeia:** C1 (SQLi em login) + C2 (SQLi em get user)
- **Passos:**
  1. Atacante envia `email=' UNION SELECT password,1,1 FROM users--`
  2. Recebe lista de password hashes
  3. Mas como passwords são **plaintext** (C3), nem precisa quebrar hashes
- **Resultado:** todas as credenciais comprometidas
- **Probabilidade:** Alta · **Impacto:** Crítico
- **Tempo:** ~5 minutos · **Skill:** baixa · **Detect:** sem logs

### Vetor 2 — Tornar-se admin (Crítico)
- **Encadeia:** C5 (mass assignment) + ausência de auth middleware
- **Passos:**
  1. POST /users/123 com `{"role": "admin"}`
  2. UPDATE user 123 → role admin (sem ownership check, sem allowlist)
- **Resultado:** privilege escalation
- **Probabilidade:** Alta · **Impacto:** Crítico

### Vetor 3 — Ler /etc/passwd (Alto)
- **Encadeia:** A1 (path traversal em avatar)
- **Passos:**
  1. GET /users/1/avatar?file=../../../etc/passwd
- **Resultado:** leitura arbitrária de ficheiros do servidor
- **Probabilidade:** Alta · **Impacto:** Alto

---

## 6. Achados Detalhados

### Críticos

#### C1. SQL Injection em login
- **Categoria:** SQL Injection
- **Localização:** `routes/auth.js:10`
- **Código vulnerável:**
  ```javascript
  const [rows] = await db.query(
    `SELECT * FROM users WHERE email = '${email}'`
  );
  ```
- **Explicação:** Concatenação direta de input do utilizador em query SQL. Atacante envia `email=' OR 1=1--` para bypass auth, ou `' UNION SELECT...` para extrair dados.
- **Exploração:** `POST /login {"email": "' OR 1=1 LIMIT 1--", "password": "anything"}` → autentica como primeiro user.
- **Correção:**
  ```javascript
  const [rows] = await db.execute(
    'SELECT id, email, password, role FROM users WHERE email = ?',
    [email]
  );
  ```

#### C2. SQL Injection em GET /users/:id
- **Categoria:** SQL Injection
- **Localização:** `routes/users.js:7`
- **Código vulnerável:**
  ```javascript
  await db.query(`SELECT * FROM users WHERE id = ${req.params.id}`);
  ```
- **Explicação:** `req.params.id` é string, atacante pode meter SQL completo.
- **Exploração:** `GET /users/1 UNION SELECT password,1,1,1 FROM users` → dump.
- **Correção:**
  ```javascript
  const id = parseInt(req.params.id, 10);
  if (isNaN(id) || id <= 0) return res.status(400).json({ error: 'invalid id' });
  const [rows] = await db.execute(
    'SELECT id, email, role FROM users WHERE id = ?', [id]
  );
  if (!rows[0]) return res.status(404).json({ error: 'not found' });
  res.json(rows[0]);  // sem password
  ```

#### C3. Passwords em plaintext
- **Categoria:** Criptografia
- **Localização:** `routes/auth.js:14`
- **Código vulnerável:**
  ```javascript
  if (user.password !== password) {
  ```
- **Explicação:** Comparação direta = passwords armazenadas em plaintext. `bcrypt` está em deps mas não é usado. Game over se DB vazar.
- **Correção:**
  ```javascript
  const bcrypt = require('bcrypt');
  // No registo: const hash = await bcrypt.hash(password, 12);
  // No login:
  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) return res.status(401).json({ error: 'Credenciais inválidas' });
  ```
  Nota adicional: mensagem de erro **igual** para "user não existe" e "password errada" (anti-enumeração).

#### C4. JWT secret hardcoded
- **Categoria:** Tokens / Secrets
- **Localização:** `routes/auth.js:6`
- **Código vulnerável:**
  ```javascript
  const SECRET = 'super_secret_123';
  ```
- **Explicação:** Secret no código = qualquer pessoa com acesso ao repo pode forjar tokens.
- **Correção:**
  ```javascript
  const SECRET = process.env.JWT_SECRET;
  if (!SECRET || SECRET.length < 32) throw new Error('JWT_SECRET missing or weak');
  ```
  Plus: rotacionar imediatamente (todos os tokens emitidos estão comprometidos).

#### C5. Mass assignment em UPDATE user
- **Categoria:** Permissões / Mass Assignment
- **Localização:** `routes/users.js:11`
- **Código vulnerável:**
  ```javascript
  router.post('/users/:id', async (req, res) => {
    const updates = req.body;
    await db.query('UPDATE users SET ? WHERE id = ?', [updates, req.params.id]);
  ```
- **Explicação:** `req.body` inteiro vai para SQL. Atacante envia `{"role": "admin", "password_hash": "..."}` → privilege escalation. Plus: sem auth check, qualquer um edita qualquer user (IDOR).
- **Correção:**
  ```javascript
  const { z } = require('zod');
  const UpdateUser = z.object({
    name: z.string().min(1).max(100).optional(),
    bio: z.string().max(500).optional(),
  }).strict();  // rejeita campos extra

  router.post('/users/:id', requireAuth, async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (id !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'forbidden' });
    }
    const parsed = UpdateUser.safeParse(req.body);
    if (!parsed.success) return res.status(400).json(parsed.error);
    await db.execute(
      'UPDATE users SET name = ?, bio = ? WHERE id = ?',
      [parsed.data.name, parsed.data.bio, id]
    );
    res.json({ ok: true });
  });
  ```

### Altos

#### A1. Path Traversal no avatar
- **Categoria:** Open Redirect / SSRF (path traversal sub-categoria)
- **Localização:** `routes/users.js:17`
- **Código vulnerável:**
  ```javascript
  router.get('/users/:id/avatar', async (req, res) => {
    const file = req.query.file;
    res.sendFile(`/var/uploads/${file}`);
  });
  ```
- **Explicação:** `?file=../../../etc/passwd` lê ficheiros arbitrários.
- **Correção:**
  ```javascript
  const path = require('path');
  router.get('/users/:id/avatar', requireAuth, (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) return res.status(400).end();
    // Storage por user_id (não query param)
    const filePath = path.join('/var/uploads', String(id), 'avatar.jpg');
    const safe = path.normalize(filePath);
    if (!safe.startsWith('/var/uploads/')) return res.status(400).end();
    res.sendFile(safe, (err) => err && res.status(404).end());
  });
  ```

#### A2. JWT sem validação de issuer/audience/expiração
- **Categoria:** Criptografia / JWT
- **Localização:** `routes/auth.js:18`
- **Código vulnerável:**
  ```javascript
  const token = jwt.sign({ id: user.id, role: user.role }, SECRET);
  ```
- **Explicação:** Sem `expiresIn` = token válido para sempre. Sem `iss`/`aud` = sem proteção contra reuso cross-app.
- **Correção:**
  ```javascript
  const token = jwt.sign(
    { sub: user.id, role: user.role },
    SECRET,
    { expiresIn: '15m', issuer: 'my-api', audience: 'my-api-clients', algorithm: 'HS256' }
  );
  ```
  Plus: implementar refresh token rotation.

#### A3. Resposta /login expõe utilizador completo
- **Categoria:** Exposição de dados
- **Localização:** `routes/auth.js:19`
- **Código vulnerável:**
  ```javascript
  res.json({ token, user });  // user inclui password
  ```
- **Explicação:** Devolve `user` direto da DB → inclui `password` (mesmo após mudança para hash, devolveria hash).
- **Correção:**
  ```javascript
  res.json({ token, user: { id: user.id, email: user.email, role: user.role } });
  ```

### Médios

#### M1. Falta de rate limit em /login
- **Categoria:** DoS / Auth
- **Localização:** `routes/auth.js`
- **Explicação:** Sem rate limit, brute force trivial.
- **Correção:** `express-rate-limit` 5 tentativas / 15 min por IP+email.

#### M2. Sem helmet (security headers)
- **Categoria:** Headers HTTP
- **Localização:** `server.js`
- **Correção:** `app.use(require('helmet')())`.

### Baixos

#### B1. Express versão antiga
- **Categoria:** Dependências
- **Localização:** `package.json`
- **Explicação:** `^4.16.0` permite versões antigas. Express 4.20+ tem patches importantes.
- **Correção:** `"express": "^4.21.0"` + `npm update`.

---

## 7. Plano de Correção por Fases

### Fase 1 — Imediata (24-48h) · BLOQUEIA DEPLOY
- [ ] **C1, C2** — Substituir queries por `db.execute()` com bindings (1h)
- [ ] **C3** — Implementar `bcrypt.hash` + `bcrypt.compare` + migrar passwords existentes (3h)
- [ ] **C4** — Mover `JWT_SECRET` para env var + rotacionar (30 min)
- [ ] **C5** — Adicionar `requireAuth` middleware + Zod validation + ownership check (1h)
- [ ] **A1** — Refazer endpoint avatar com path validado (30 min)

**Esforço total:** ~6h

### Fase 2 — Curto prazo (1 semana)
- [ ] **A2** — JWT com `expiresIn`, `iss`, `aud` + refresh tokens (2h)
- [ ] **A3** — DTO no response /login (15 min)
- [ ] **M1** — express-rate-limit em login + /users (1h)
- [ ] **M2** — helmet middleware + CSP básico (30 min)
- [ ] Adicionar tests para anti-regressão

### Fase 3 — Médio prazo (2-4 semanas)
- [ ] **B1** — Atualizar deps + `npm audit` regular
- [ ] Logging estruturado (pino) com sanitização
- [ ] Cookies HttpOnly em vez de token em response (mover para sessão)

### Fase 4 — Hardening contínuo
- [ ] CI com `npm audit` + Snyk
- [ ] Pre-commit hook com gitleaks
- [ ] Dependabot ativo
- [ ] Auditoria trimestral

---

## 8. Checklist Final Antes de Produção

### Inputs e Outputs
- [ ] Todos os endpoints com Zod validation
- [ ] Sem `req.body` direto em DB (sempre via DTO/schema)
- [ ] Sem strings interpoladas em queries SQL

### Autenticação
- [ ] bcrypt cost ≥ 12 para passwords
- [ ] JWT com `expiresIn`, `iss`, `aud`
- [ ] Secrets via env var
- [ ] Rate limit em login

### Permissões
- [ ] requireAuth middleware em todos os endpoints privados
- [ ] Ownership check (req.user.id === resource.owner_id)
- [ ] Mass assignment bloqueado (allowlist via .strict())

### Headers
- [ ] helmet ativo
- [ ] HSTS configurado
- [ ] CSP definida

### Operacional
- [ ] Logs sem PII
- [ ] Backup automático testado
- [ ] Monitoring de 4xx/5xx anomalies

---

## 9. Recomendações Adicionais

- **Migrar para TypeScript** — type safety reduz outras classes de bugs
- **Adotar Prisma ou Drizzle** — type-safe DB layer, evita SQLi por design
- **Adicionar Sentry** — captura erros em prod
- **OAuth via Auth0/Clerk** — outsource auth complexity
- **Pen-test externo** após Fase 1 + Fase 2 completas
```

---

## Como esta IA usa este exemplo

Quando o utilizador disser *"audita este projeto"*, a IA deve:

1. **Detetar stack** (Node.js, Express, MySQL, JWT)
2. **Carregar contexto:**
   - `analises/*.md` (sempre)
   - `linguagens/javascript-typescript.md`
   - `frameworks/web/node-express.md`
3. **Aplicar 24 análises** com lente do atacante
4. **Tentar attack chains** (mínimo 3, como no exemplo)
5. **Devolver relatório** **exatamente neste formato** (header, score, resumos, mapa, vetores, achados, plano, checklist, recomendações)

Cada achado deve ter: categoria, severidade, ficheiro:linha, código vulnerável, explicação, exploração realista, correção copy-paste.

> Este é o output esperado. Variações de formatação (ex.: emojis, ordem de secções) **não** são aceitáveis — o template é fixo.
