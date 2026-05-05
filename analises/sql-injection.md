# Análise — SQL Injection

## O que procurar

### Concatenação direta
- `"SELECT * FROM x WHERE id = $id"`
- `"... WHERE name = '" . $_POST['name'] . "'"`
- Template literals em Node: `` `SELECT ... ${id}` ``
- Python f-strings: `f"SELECT ... {id}"`

### WordPress `$wpdb`
- `$wpdb->query("... $var ...")` sem `prepare()`
- `$wpdb->get_var("... $var ...")` sem `prepare()`
- `$wpdb->prepare()` com placeholder mas com aspas extra: `"WHERE name = '%s'"` (errado, `%s` já adiciona)
- `$wpdb->prepare()` sem placeholders (`prepare("SELECT ...")`) — efetivamente uma string
- Identificadores (nome de tabela/coluna) interpolados de input

### LIKE sem escape
- `"... WHERE name LIKE '%$term%'"` permite injeção e curinga descontrolado
- Falta `$wpdb->esc_like()` antes de adicionar `%`

### ORM / Query builders
- Eloquent: `DB::raw($input)`, `whereRaw("col = $x")`
- Doctrine: `createQuery("... $x ...")`
- Sequelize: `sequelize.query(\`... ${x} ...\`)` sem `replacements`
- SQLAlchemy: `text(f"... {x} ...")`

### Stored Procedures dinâmicos
- `EXEC sp_executesql @sql` com `@sql` montado por concatenação

## Sinais de alarme

```php
// BAD
$wpdb->query("SELECT * FROM wp_users WHERE ID = " . $_GET['id']);
$wpdb->get_results("SELECT * FROM x WHERE name = '$name'");
$wpdb->prepare("SELECT * FROM x WHERE name = '%s'", $name); // aspas a mais

// GOOD
$wpdb->query($wpdb->prepare("SELECT * FROM wp_users WHERE ID = %d", $id));
$wpdb->get_results($wpdb->prepare("SELECT * FROM x WHERE name = %s", $name));

// LIKE
$like = '%' . $wpdb->esc_like($term) . '%';
$wpdb->prepare("SELECT * FROM x WHERE name LIKE %s", $like);

// Identificadores: usar allowlist
$allowed = ['name', 'email', 'created_at'];
$col = in_array($_GET['sort'], $allowed, true) ? $_GET['sort'] : 'name';
$wpdb->get_results("SELECT * FROM x ORDER BY `$col`");
```

```js
// BAD
db.query(`SELECT * FROM x WHERE id = ${id}`);

// GOOD
db.query('SELECT * FROM x WHERE id = ?', [id]);
```

## Placeholders WP
- `%s` — string (com aspas automáticas)
- `%d` — inteiro
- `%f` — float
- `%i` — identificador (WP 6.2+)

## Quick wins (faz isto antes de entregar)

- [ ] Listar **todas** as queries dinâmicas (`grep` por concatenation patterns) — converter para prepared statements
- [ ] Sem `f-strings`/`template literals`/`string concatenation` em queries
- [ ] Sem `whereRaw`/`raw()`/`FromSqlRaw`/`$wpdb->query` com input — usar bindings
- [ ] `LIKE` com input → escapar wildcards (`esc_like`/`Str::escape`/manual replace)
- [ ] Identificadores dinâmicos (ORDER BY, table name) → allowlist server-side, **nunca** input direto
- [ ] `IN (...)` com array → gerar placeholders dinâmicos (`?,?,?`)
- [ ] SAST tool (Semgrep, CodeQL, Snyk) na CI a procurar SQLi patterns
- [ ] DB user com privilégios mínimos (sem DROP/GRANT em prod)
- [ ] Plus: ver `analises/query-builders-orm.md` para padrões por ORM

## Falsos positivos
- Queries totalmente estáticas (sem variáveis).
- Variáveis castadas: `(int)$id`, `intval($id)`, `absint($id)` — seguras para `%d`.
- Constantes definidas no código.

## Severidade típica
- Injection em endpoint não autenticado → leitura/escrita de DB: **Crítico**
- Injection em admin com nonce: **Alto**
- Injection em query read-only com pouco impacto: **Médio**
- Blind/timing-based dificilmente explorável: **Médio/Baixo**
