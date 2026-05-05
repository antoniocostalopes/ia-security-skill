# Análise — Query Builders e ORMs (Antipatterns Universais)

> SQL injection é fácil de evitar quando se usa o ORM corretamente. O problema é o `raw()`, o `query()` direto, e os helpers "convenientes" que aceitam strings. Esta análise mapeia os antipatterns por linguagem/ORM.

## Princípio universal

> **Nunca concatenes input em query strings. Sempre prepared statements ou query builders parametrizados.**

Tudo o resto são detalhes por engine.

## Por linguagem / ORM

### PHP

#### PDO (vanilla)
```php
// BAD
$pdo->query("SELECT * FROM users WHERE id = $id");

// GOOD
$stmt = $pdo->prepare("SELECT * FROM users WHERE id = :id");
$stmt->execute(['id' => $id]);
```

#### `$wpdb` (WordPress)
```php
// BAD
$wpdb->query("SELECT * FROM wp_users WHERE ID = " . $_GET['id']);

// GOOD
$wpdb->get_results($wpdb->prepare(
  "SELECT * FROM {$wpdb->users} WHERE ID = %d", $id
));
// Placeholders: %s string, %d int, %f float, %i identifier (WP 6.2+)
```

#### Laravel Eloquent
```php
// BAD
DB::select("SELECT * FROM users WHERE name = '$name'");
User::whereRaw("name = '$name'");

// GOOD
DB::select("SELECT * FROM users WHERE name = ?", [$name]);
User::where('name', $name);
User::whereRaw("name = ?", [$name]);  // raw com bindings = OK
```

#### Doctrine (Symfony)
```php
// BAD
$query = $em->createQuery("SELECT u FROM User u WHERE u.name = '$name'");

// GOOD
$query = $em->createQuery("SELECT u FROM User u WHERE u.name = :name");
$query->setParameter('name', $name);
```

### Python

#### psycopg2 / sqlite3 / mysql.connector
```python
# BAD
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
cursor.execute("SELECT * FROM users WHERE id = " + user_id)
cursor.execute("SELECT * FROM users WHERE id = %s" % user_id)

# GOOD
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))  # tupla!
# nota: %s aqui é placeholder do driver, NÃO string formatting
```

#### SQLAlchemy
```python
# BAD
session.execute(f"SELECT * FROM users WHERE name = '{name}'")
session.execute(text(f"SELECT * FROM users WHERE name = '{name}'"))

# GOOD — ORM
session.query(User).filter_by(name=name).all()

# GOOD — raw com bind params
session.execute(text("SELECT * FROM users WHERE name = :name"), {'name': name})
```

#### Django ORM
```python
# BAD
User.objects.raw(f"SELECT * FROM users WHERE name = '{name}'")
User.objects.extra(where=[f"name = '{name}'"])

# GOOD
User.objects.filter(name=name)
User.objects.raw("SELECT * FROM users WHERE name = %s", [name])
```

### JavaScript / TypeScript / Node

#### node-postgres (`pg`)
```javascript
// BAD
client.query(`SELECT * FROM users WHERE id = ${id}`);

// GOOD
client.query('SELECT * FROM users WHERE id = $1', [id]);
```

#### `mysql2`
```javascript
// BAD
connection.query(`SELECT * FROM users WHERE id = ${id}`);

// GOOD
connection.execute('SELECT * FROM users WHERE id = ?', [id]);
```

#### Sequelize
```javascript
// BAD
sequelize.query(`SELECT * FROM users WHERE id = ${id}`);

// GOOD
sequelize.query('SELECT * FROM users WHERE id = :id',
  { replacements: { id }, type: QueryTypes.SELECT });
// MELHOR: usar models
User.findByPk(id);
```

#### Prisma
```javascript
// BAD
prisma.$queryRawUnsafe(`SELECT * FROM users WHERE id = ${id}`);

// GOOD — tagged template literal escapa automaticamente
prisma.$queryRaw`SELECT * FROM users WHERE id = ${id}`;
// MELHOR
prisma.user.findUnique({ where: { id } });
```

#### Knex
```javascript
// BAD
knex.raw(`SELECT * FROM users WHERE name = '${name}'`);

// GOOD
knex.raw('SELECT * FROM users WHERE name = ?', [name]);
knex('users').where('name', name);
```

### Java

#### JDBC vanilla
```java
// BAD
Statement st = conn.createStatement();
st.executeQuery("SELECT * FROM users WHERE id = " + id);

// GOOD
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
ps.setInt(1, id);
ps.executeQuery();
```

#### JPA / Hibernate
```java
// BAD
em.createQuery("SELECT u FROM User u WHERE u.name = '" + name + "'");
em.createNativeQuery("SELECT * FROM users WHERE name = '" + name + "'");

// GOOD
em.createQuery("SELECT u FROM User u WHERE u.name = :name")
  .setParameter("name", name);

// Ou Spring Data JPA
userRepository.findByName(name);
```

#### Spring JdbcTemplate
```java
// BAD
jdbcTemplate.queryForList("SELECT * FROM users WHERE id = " + id);

// GOOD
jdbcTemplate.queryForList("SELECT * FROM users WHERE id = ?", id);
```

### C# / .NET

#### Entity Framework Core
```csharp
// BAD
context.Users.FromSqlRaw($"SELECT * FROM Users WHERE Name = '{name}'");

// GOOD
context.Users.FromSqlRaw("SELECT * FROM Users WHERE Name = {0}", name);
context.Users.FromSqlInterpolated($"SELECT * FROM Users WHERE Name = {name}");
// Ou LINQ
context.Users.Where(u => u.Name == name);
```

#### Dapper
```csharp
// BAD
connection.Query<User>($"SELECT * FROM Users WHERE Name = '{name}'");

// GOOD
connection.Query<User>("SELECT * FROM Users WHERE Name = @Name", new { Name = name });
```

### Go

#### `database/sql`
```go
// BAD
db.Query("SELECT * FROM users WHERE id = " + idStr)
db.Query(fmt.Sprintf("SELECT * FROM users WHERE id = %d", id))

// GOOD
db.Query("SELECT * FROM users WHERE id = $1", id)  // postgres
db.Query("SELECT * FROM users WHERE id = ?", id)   // mysql/sqlite
```

#### GORM
```go
// BAD
db.Raw(fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", name)).Scan(&users)

// GOOD
db.Raw("SELECT * FROM users WHERE name = ?", name).Scan(&users)
db.Where("name = ?", name).Find(&users)
```

### Ruby

#### ActiveRecord (Rails)
```ruby
# BAD
User.where("name = '#{name}'")
User.find_by_sql("SELECT * FROM users WHERE name = '#{name}'")

# GOOD
User.where(name: name)
User.where("name = ?", name)
User.find_by_sql(["SELECT * FROM users WHERE name = ?", name])
```

### Rust

#### sqlx
```rust
// BAD — não há concatenation pattern fácil porque sqlx força macros, mas...
sqlx::query(&format!("SELECT * FROM users WHERE id = {}", id))

// GOOD
sqlx::query!("SELECT * FROM users WHERE id = $1", id)
    .fetch_one(&pool).await?;
```

#### diesel
```rust
// GOOD — diesel é seguro por design
users::table.filter(users::name.eq(name)).load(&conn)
```

## Padrões anti-injection que valem para todos

### LIKE com input
```sql
-- BAD: input "%admin%" muda significado da query
WHERE name LIKE '%' + ? + '%'  -- erro: ? já tem aspas

-- GOOD: escapar wildcards do input antes de adicionar %
escaped = name.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
WHERE name LIKE ? ESCAPE '\\'  -- bind: '%escaped%'
```

WordPress: `$wpdb->esc_like($input)`.
Laravel: `Str::escape()` ou usar `where('name', 'like', '%' . str_replace(['%', '_'], ['\\%', '\\_'], $input) . '%')`.

### IN (...) com array
```javascript
// BAD
const ids = [1, 2, 3];
db.query(`SELECT * FROM users WHERE id IN (${ids.join(',')})`);

// GOOD — gerar placeholders dinamicamente
const placeholders = ids.map((_, i) => `$${i + 1}`).join(',');  // postgres
db.query(`SELECT * FROM users WHERE id IN (${placeholders})`, ids);

// MELHOR: usar `= ANY` (postgres) ou query builder
db.query('SELECT * FROM users WHERE id = ANY($1)', [ids]);
```

### Identificadores (nome de tabela/coluna)
Placeholders **não** funcionam para identifiers. Usar allowlist.

```javascript
// BAD
db.query(`SELECT * FROM users ORDER BY ${req.query.sort}`);

// GOOD
const ALLOWED = ['name', 'created_at', 'email'];
const sort = ALLOWED.includes(req.query.sort) ? req.query.sort : 'name';
db.query(`SELECT * FROM users ORDER BY ${sort}`);
```

### ORDER BY com direção
```javascript
const dir = req.query.dir === 'desc' ? 'DESC' : 'ASC';  // só 2 valores
```

### Stored procedures dinâmicos
```sql
-- BAD (MSSQL) — sp_executesql com SQL montado
EXEC sp_executesql @sql = 'SELECT * FROM users WHERE id = ' + @id;

-- GOOD
EXEC sp_executesql N'SELECT * FROM users WHERE id = @id', N'@id INT', @id = @id;
```

## NoSQL Injection

ORMs NoSQL têm vulns equivalentes.

### MongoDB
```javascript
// BAD — body { username: { $ne: null }, password: { $ne: null } } passa
db.users.findOne({
  username: req.body.username,
  password: req.body.password,
});

// GOOD — strict types
db.users.findOne({
  username: String(req.body.username),
  password: String(req.body.password),
});
// MELHOR: validar schema (Joi, Zod) antes de chegar à query
```

### Redis
```javascript
// BAD
redis.eval(`return redis.call('get', '${userInput}')`, 0);

// GOOD
redis.get(userInput);
```

## Quick wins (faz isto antes de entregar)

- [ ] Listar todos os `query`/`raw`/`execute` do projeto — confirmar que usam parameterização
- [ ] Listar todos os `whereRaw`, `findBySql`, `$queryRaw`, `FromSqlRaw`, `Sequelize.literal` — confirmar `?`/`$1`/`@param` em vez de interpolação
- [ ] Listar todos os `LIKE` — confirmar que wildcards do input estão escapados
- [ ] Listar todos os `ORDER BY ...` dinâmicos — confirmar allowlist
- [ ] Listar todos os `IN (...)` — confirmar placeholders dinâmicos
- [ ] Para MongoDB: validar tipos antes de queries (`String()`, `Number()`, ou schema validator)

## Severidade — em linguagem honesta
- **Crítico:** SQLi em endpoint público (qualquer leitura/escrita de DB)
- **Crítico:** NoSQLi em endpoint de login (`{$ne:null}` bypass)
- **Alto:** SQLi em endpoint admin (precisa de auth, mas dump completo)
- **Alto:** SQLi blind via timing
- **Médio:** LIKE injection (pode ser blind, gradual)
- **Médio:** ORDER BY dinâmico sem allowlist (info disclosure via timing)
