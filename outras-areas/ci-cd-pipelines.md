# CI/CD Pipelines — Segurança Profunda

> Já há baseline em `analises/17-dependencias.md`. Aqui é o deep dive.

## GitHub Actions

### Princípios
- **Hash pinning** para third-party actions
- **Permissions: minimal** explícito
- **Secrets: scoped** (env, repo, org)
- **OIDC** para cloud auth (sem long-lived secrets)

### Setup seguro

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

permissions:
  contents: read           # default — least privilege
  id-token: write          # para OIDC
  packages: write          # se publica em GHCR

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # requires approval
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4 hash

      - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT:role/github-deploy
          aws-region: eu-west-1

      - run: ./deploy.sh
```

### `pull_request_target` — perigoso

```yaml
# BAD — pull_request_target dá acesso a secrets em código de fork
on: pull_request_target
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with: { ref: ${{ github.event.pull_request.head.sha }} }  # checkout do PR
      - run: ./build.sh                                            # → executa código não-confiável com secrets
```

```yaml
# GOOD — split: pull_request_target sem checkout, ou pull_request normal
on: pull_request
permissions: { contents: read }  # sem secrets
```

### Dependabot
- Auto-merge de patches de security via `dependabot.yml`.
- **Verificar** dependabot PRs — fork malicioso pode submeter PR.

### Secret scanning
- GitHub Secret Scanning ativo (push protection).
- Pre-commit hook local (gitleaks, trufflehog).

## GitLab CI

```yaml
# .gitlab-ci.yml
variables:
  GIT_DEPTH: 0
  GIT_SUBMODULE_STRATEGY: recursive

stages: [test, build, deploy]

include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Dependency-Scanning.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml

test:
  stage: test
  script: ./test.sh
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

deploy_prod:
  stage: deploy
  environment: production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  before_script:
    # OIDC para AWS
    - aws sts assume-role-with-web-identity ...
  script: ./deploy.sh
```

## Jenkins

```groovy
// Jenkinsfile
pipeline {
    agent { label 'docker' }

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    environment {
        // Credentials via withCredentials, não direto
    }

    stages {
        stage('Test') {
            steps {
                sh './test.sh'
            }
        }

        stage('Deploy') {
            when { branch 'main' }
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_KEY')
                ]) {
                    sh './deploy.sh'
                }
            }
        }
    }
}
```

## Build artifacts — security

### Não publicar
- Source maps em prod
- `.git/` no artefacto
- `node_modules/.bin/` não usados
- Test files / fixtures
- `.env*`, `secrets/`
- Dockerfile / build scripts (só para build, não shipping)

### Publicar
- Apenas binários compilados/minified
- SBOM (Software Bill of Materials)
- Signature do artefacto (cosign)
- Hash (SHA-256) publicado para verificação

## Container builds

```dockerfile
# Multi-stage com signed base
FROM cgr.dev/chainguard/static@sha256:hash AS runtime
COPY --from=builder /app /app
USER nonroot
ENTRYPOINT ["/app"]
```

```bash
# Sign com cosign
cosign sign --key cosign.key registry/app:latest

# Verify em deploy
cosign verify --key cosign.pub registry/app:latest
```

## Supply chain — SLSA

- **SLSA Level 1** — build script + provenance
- **SLSA Level 2** — version control + hosted build
- **SLSA Level 3** — non-falsifiable provenance, isolated build env
- **SLSA Level 4** — two-person review, hermetic builds

GitHub Actions tem SLSA Level 3 com proper config.

## Common antipatterns

### Secrets em logs
```yaml
- run: echo "Token: $SECRET_TOKEN"  # !!
```

### `actions/checkout@main`
- Sem version pinning. Atacante compromete `main` → acesso ao teu CI.

### `${{ github.event.pull_request.head.repo.full_name }}` sem validação
- Pode injetar comandos via repo names manipulados.

### Self-hosted runners em apps com PRs externos
- PR malicioso corre código no teu runner.

### `id-token: write` em workflows não OIDC
- Permissão excessiva.

### Caching of secrets
```yaml
- uses: actions/cache@v3
  with: { path: .env, ... }  # !! cache de secrets
```

### `set-env` / `add-path` (deprecated injection vectors)
- Injection via output. Migrar para `>> $GITHUB_ENV`.

### Workflow input validation
```yaml
on:
  workflow_dispatch:
    inputs:
      version:
        type: string
# Atacante mete `; rm -rf /` em version → command injection se usado em script
- run: echo "Version: ${{ github.event.inputs.version }}"  # injection
```

```yaml
# GOOD — usar env, escape via shell
env:
  VERSION: ${{ github.event.inputs.version }}
- run: echo "Version: $VERSION"
```

## SAST/DAST/SCA na CI

| Tool | Tipo | Linguagens |
|---|---|---|
| **Semgrep** | SAST | Multi |
| **CodeQL** | SAST | Multi (GitHub) |
| **Snyk** | SCA + SAST + IaC | Multi |
| **Trivy** | Container + IaC + Deps | Multi |
| **Dependabot** | SCA | GitHub |
| **Renovate** | SCA + auto-update | Multi |
| **Bandit** | SAST | Python |
| **Brakeman** | SAST | Ruby/Rails |
| **Gosec** | SAST | Go |
| **gitleaks** / **TruffleHog** | Secret scan | Multi |
| **OWASP ZAP** | DAST | Web |
| **Burp Enterprise** | DAST | Web |

## Quick wins

- [ ] Permissions `contents: read` default em todos os workflows
- [ ] Hash pinning de actions third-party
- [ ] OIDC para cloud auth (sem long-lived keys em secrets)
- [ ] Secret scanning push protection ativa
- [ ] SAST (Semgrep/CodeQL) na CI sem Highs
- [ ] SCA (Dependabot/Snyk) sem Críticos
- [ ] Container scanning (Trivy)
- [ ] IaC scanning (Checkov/tfsec)
- [ ] Secret detection (gitleaks)
- [ ] SBOM gerada e armazenada
- [ ] Container/binary signing (cosign)
- [ ] Branch protection rules: require PR review, status checks
- [ ] CODEOWNERS para arquivos sensíveis
- [ ] Required reviewers para mudanças em workflows
- [ ] Self-hosted runners segregados (não em apps com PRs externos)
- [ ] Build provenance (SLSA)
- [ ] Auditoria regular de permissions e secrets
