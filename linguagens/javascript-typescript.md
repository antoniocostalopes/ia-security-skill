# JavaScript / TypeScript — Cartão de Segurança

## Funções e APIs perigosas

| API | Risco |
|---|---|
| `eval(code)`, `Function(code)`, `setTimeout(string)`, `setInterval(string)` | RCE / XSS |
| `child_process.exec(cmd)` | Command injection (preferir `execFile` ou `spawn` com array) |
| `child_process.spawn(cmd, args, { shell: true })` | Command injection |
| `vm.runInNewContext(code)` | Não é sandbox real — RCE |
| `fs.readFile(userPath)` | Path traversal |
| `require(userInput)` | RCE em Node antigo, info disclosure |
| `import(userInput)` (dynamic) | Idem |
| `XMLHttpRequest`/`fetch(userURL)` | SSRF (server) ou CORS bypass (cliente) |
| `JSON.parse(untrusted)` | OK em si, mas `JSON.parse` em loops sem cap → DoS |
| `innerHTML`, `outerHTML`, `document.write` | XSS |
| `el.insertAdjacentHTML('beforeend', x)` | XSS |
| `dangerouslySetInnerHTML={{__html: x}}` (React) | XSS |
| `v-html="x"` (Vue) | XSS |
| `[innerHTML]="x"` (Angular sem `DomSanitizer`) | XSS |
| `Object.assign(target, JSON.parse(x))` | Prototype pollution |
| `lodash.merge(a, b)` (versões < 4.17.20) | Prototype pollution |
| `JSON.parse` + `JSON.stringify` ciclos | DoS por memória |

## Idiomas inseguros

### Type coercion (`==` vs `===`)
```javascript
'1' == 1          // true
0 == false        // true
'' == 0           // true
[] == false       // true
'00' == false     // true
null == undefined // true
```
Sempre `===` em código de segurança (auth, comparações de tokens, etc.).

### Prototype Pollution
```javascript
// BAD
function deepMerge(target, source) {
  for (const key in source) {
    if (typeof source[key] === 'object') {
      target[key] = deepMerge(target[key] || {}, source[key]);
    } else {
      target[key] = source[key];
    }
  }
  return target;
}
// Atacante: { "__proto__": { "isAdmin": true } } → polui Object.prototype

// GOOD
function safeMerge(target, source) {
  for (const key of Object.keys(source)) {
    if (key === '__proto__' || key === 'constructor' || key === 'prototype') continue;
    // ...
  }
}
// Ou: Object.create(null) para objetos sem prototype
// Ou: Map em vez de plain object
```

### Async / Promise pitfalls
```javascript
// BAD — race condition: 2 inserts em paralelo
async function createUser(email) {
  const exists = await User.findOne({ email });
  if (exists) throw new Error('exists');
  return User.create({ email });
}
// 2 calls paralelos → 2 users com mesmo email

// GOOD — atomic
return User.findOneAndUpdate(
  { email },
  { $setOnInsert: { email, createdAt: new Date() } },
  { upsert: true, new: true, returnDocument: 'after' }
);
```

### Cookies em SameSite
```javascript
// BAD
res.cookie('session', token);  // sem flags

// GOOD
res.cookie('session', token, {
  httpOnly: true,
  secure: true,
  sameSite: 'lax',
  maxAge: 1000 * 60 * 60 * 24,
});
```

### Express middleware order
```javascript
// BAD — auth check vem depois de rotas admin
app.use('/admin', adminRouter);  // acessível
app.use(authMiddleware);

// GOOD
app.use(authMiddleware);
app.use('/admin', adminRouter);
```

## TypeScript-specific

### `as` é coerção, não validação
```typescript
const userInput = req.body as User;  // mente: não valida
// runtime: { __proto__: ..., role: 'admin' }

// GOOD — runtime validation com Zod / Yup / io-ts
const UserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});
const user = UserSchema.parse(req.body);  // throws se inválido
```

### `any` esconde tudo
```typescript
function process(data: any) {  // perde checking
  return data.user.name;        // crashes em runtime
}

// GOOD — unknown + narrowing
function process(data: unknown) {
  if (typeof data === 'object' && data !== null && 'user' in data) {
    // ...
  }
}
```

## Helpers seguros (stdlib + libs comuns)

| Necessidade | Use |
|---|---|
| Random tokens | `crypto.randomBytes(32).toString('hex')` |
| Constant-time compare | `crypto.timingSafeEqual(a, b)` (buffers iguais size) |
| HMAC | `crypto.createHmac('sha256', key).update(data).digest('hex')` |
| Password hashing | `bcrypt`/`argon2` (não `crypto.pbkdf2` para passwords novos) |
| URL parsing | `new URL(s)` (não regex caseiro) |
| Email validation | `validator.isEmail` (não regex caseiro) |
| Path normalization | `path.resolve` + check de prefix |
| HTML escape | `he` (`he.escape`) ou framework (React faz auto) |
| JSON Web Tokens | `jose` (recomendado) ou `jsonwebtoken` v9+ |

## Bibliotecas comuns com histórico de vulns

- **`lodash` < 4.17.21** → prototype pollution
- **`minimist` < 1.2.6** → prototype pollution
- **`node-serialize`** → RCE (evitar)
- **`marked` < 4.0.10** → XSS via comments/links
- **`handlebars` < 4.7.7** → SSTI / RCE
- **`express` < 4.20** → várias (manter atualizado)
- **`axios` < 1.6.0** → SSRF via redirects
- **`jsonwebtoken` < 9** → alg confusion default
- **`ws` < 7.4.6** → DoS via headers

## Quick wins

- [ ] `eslint-plugin-security` ativo
- [ ] `eslint-plugin-no-unsanitized` para HTML APIs
- [ ] `npm audit` sem Críticos/Altos
- [ ] TypeScript strict mode (`"strict": true`, `noImplicitAny`)
- [ ] Validação runtime de `req.body`/`req.query`/`req.params` com Zod ou similar
- [ ] `helmet` middleware no Express
- [ ] Cookies com flags `httpOnly + secure + sameSite`
