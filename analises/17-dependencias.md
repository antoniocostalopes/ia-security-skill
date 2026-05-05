# Análise — Dependências e Supply Chain

> O atacante já não precisa de te invadir. Basta invadir uma das 200 libs que tens em `composer.json`. Antes de entregar, mete 5 minutos a verificar.

## O que procurar

### Versões com CVEs conhecidos
- `composer.json` / `composer.lock` com pacotes vulneráveis
- `package.json` / `package-lock.json` / `yarn.lock` com vulns
- `requirements.txt` / `Pipfile.lock` com vulns
- WordPress core desatualizado
- Plugins WordPress com versões vulneráveis (especialmente "abandonados", `last updated > 1 ano`)
- Temas WordPress desatualizados

### Práticas de risco
- Plugins/temas **nulled** (versões pirateadas) — quase sempre com backdoors
- Plugins de fontes desconhecidas (sem repo oficial)
- Dependências sem versão pinned (`"foo": "*"`, `"bar": "latest"`)
- `npm install` sem `package-lock.json` versionado
- `composer install` sem `composer.lock` versionado
- Dependências instaladas em build sem hash check
- `git submodule` apontando para HEAD em vez de commit fixo

### Supply chain attack vectors
- **Typosquatting**: nome similar a lib popular (`lodahs` em vez de `lodash`)
- **Dependency confusion**: package privado com mesmo nome que público (npm prefere o público se versão for maior)
- **Compromised maintainer**: lib legítima pwned (ex.: `event-stream`, `ua-parser-js`)
- **Postinstall scripts**: npm/composer correm scripts arbitrários ao instalar
- **`auto_update`** sem revisão (atualiza para versão maliciosa silenciosamente)

### CI/CD security
- Secrets em logs de build
- Secrets em variáveis de ambiente expostas em PRs de fork
- GitHub Actions com `pull_request_target` permitindo execução de código de fork
- Workflows com `permissions: write-all`
- Actions de terceiros sem hash pinned (`actions/checkout@v4` em vez de `actions/checkout@<sha>`)
- `npm publish` / `composer publish` sem 2FA na conta

### Binários e artefactos
- `node_modules/` versionado no git
- `vendor/` versionado (geralmente mau hábito)
- Binários sem checksum / signature
- Source maps em produção (revela código original)

## Comandos rápidos

```bash
# PHP / Composer
composer audit                      # CVEs nas dependências
composer outdated --direct          # libs com updates disponíveis

# Node / npm
npm audit                           # vulns
npm audit --audit-level=high        # só altas e críticas
npm outdated                        # libs desatualizadas

# Yarn
yarn audit
yarn outdated

# Python
pip-audit                           # CVEs (precisa pip install pip-audit)
safety check

# WordPress
wp plugin list --update=available   # via WP-CLI
wp theme list --update=available
wp core check-update

# Snyk (multi-linguagem, mais completo)
snyk test
snyk monitor

# OSV-Scanner (open-source, multi-linguagem)
osv-scanner -r .
```

## Sinais de alarme — package.json

```json
// BAD
{
  "dependencies": {
    "lodash": "*",                    // qualquer versão
    "axios": "latest",                // pode mudar a qualquer momento
    "express": "^4.0.0"               // ^ permite minor updates automáticos
  }
}

// GOOD — pinned ou ranges restritos
{
  "dependencies": {
    "lodash": "4.17.21",              // versão exata
    "axios": "~1.6.0",                // só patch updates
    "express": "4.19.2"
  },
  "overrides": {                      // forçar versão segura mesmo que sub-dep peça outra
    "minimist": "1.2.8"
  }
}
```

## WordPress — auditoria de plugins/temas

```bash
# Listar plugins com info de update
wp plugin list --format=table

# Ver vulnerabilidades conhecidas (se WPVulnerability ou WPScan instalado)
wp wpvuln plugin --all

# Remover plugins desativados (não usar = remover)
wp plugin uninstall --deactivated

# Verificar integridade de ficheiros core
wp core verify-checksums
```

### Red flags em plugins
- Última atualização `> 12 meses`
- Sem repo oficial (descarregado de site obscuro)
- Avaliações suspeitas (5 estrelas em massa, sem texto)
- Permissões excessivas (`access to all files`)
- Faz chamadas a domínios desconhecidos
- Descarregado de fora do `wordpress.org/plugins/` sem auditoria

## CI/CD — exemplo seguro (GitHub Actions)

```yaml
name: CI
on: [push, pull_request]

permissions:
  contents: read              # default least-privilege

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      # Hash pinning — não usar @v4
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11

      - name: Setup PHP
        uses: shivammathur/setup-php@9e72090525849c5e82e596468b86eb55e9cc5401
        with:
          php-version: '8.2'

      - name: Install deps
        run: |
          composer install --no-progress --prefer-dist
          composer audit --no-dev || exit 1

      - name: Run tests
        run: vendor/bin/phpunit
        env:
          # Secrets só disponíveis em jobs do mesmo repo, não em PRs de fork
          DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
```

## Atualização — política recomendada

| Tipo | Frequência | Como |
|---|---|---|
| Patch security WP core | Imediato (auto) | `WP_AUTO_UPDATE_CORE = 'minor'` |
| Plugins/temas | Semanal | Manual com staging primeiro |
| Composer/npm direct deps | Mensal | `composer outdated --direct` + review |
| Sub-deps (transitivas) | Quando audit detetar | `composer audit` na CI |
| Major version updates | Trimestral | Branch dedicado, testes completos |

## Quick wins (faz isto antes de entregar)

- [ ] `composer audit` (ou `npm audit`) sem Críticos/Altos
- [ ] `composer.lock` / `package-lock.json` versionados
- [ ] WordPress core na última versão estável
- [ ] Plugins/temas todos atualizados
- [ ] **Apagar** plugins/temas não usados (não chega desativar)
- [ ] Sem plugins/temas nulled
- [ ] Versões pinned (sem `*` ou `latest`)
- [ ] Source maps **NÃO** publicados em produção
- [ ] `node_modules/`, `vendor/` no `.gitignore`
- [ ] Secrets de CI em variáveis (não em logs)
- [ ] GitHub Actions com hash pinning para actions externas
- [ ] 2FA ativo nas contas de publicação (npm/composer/PyPI)

## Falsos positivos
- CVE em dep de **dev only** (ex.: lib de testes) — relevante mas menor severidade
- CVE em sub-dep com call path não atingível na app — verificar exploit-ability
- Versão "vulnerável" mas com patch backported pelo distro (ex.: Debian)

## Severidade — em linguagem honesta
- **Crítico:** plugin nulled em produção, dependência com RCE conhecido em call path ativo
- **Alto:** WordPress core desatualizado com CVE público, plugins abandonados em produção
- **Médio:** CVEs altos em dependências de dev, source maps em produção
- **Baixo:** versões "outdated" sem CVE, faltar pinning em deps estáveis
