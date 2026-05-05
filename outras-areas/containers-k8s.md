# Containers e Kubernetes — Segurança

## Dockerfile — antipatterns clássicos

```dockerfile
# BAD
FROM ubuntu:latest                    # latest é mau (no pinning)
RUN apt-get install -y curl           # sem update; cache stale
ADD . /app                            # ADD é mais permissivo que COPY
USER root                             # default; mau
EXPOSE 22                             # SSH em container?
CMD ["/start.sh"]

# GOOD
FROM ubuntu:22.04@sha256:hash         # pinning por hash
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*       # cleanup cache

WORKDIR /app
COPY --chown=app:app . .              # ownership explícito
RUN useradd -r -u 1000 app
USER 1000                             # non-root
EXPOSE 8080                           # apenas o necessário
HEALTHCHECK --interval=30s CMD curl -f http://localhost:8080/health || exit 1
CMD ["./start.sh"]
```

## Secrets em Docker

### NÃO fazer
```dockerfile
# Secrets em ENV (visíveis em `docker history`)
ENV API_KEY=sk_live_abc

# Secrets em RUN (cached em layer)
RUN echo "abc" > /etc/secret
```

### Fazer
```dockerfile
# BuildKit secrets — não persistem na imagem
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=api_key cat /run/secrets/api_key
```

```bash
docker build --secret id=api_key,src=./api_key.txt .
```

Em runtime: env vars (passadas com `-e`) ou bind-mount de Vault.

## Multi-stage build — reduzir attack surface

```dockerfile
# Stage 1: build
FROM golang:1.21 AS builder
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app

# Stage 2: runtime — minimal
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app /app
USER nonroot
ENTRYPOINT ["/app"]
```

Distroless / scratch / alpine — menos pacotes = menos CVEs.

## Image scanning

```bash
# Trivy
trivy image meusite/app:latest

# Grype
grype meusite/app:latest

# Docker Scout
docker scout cves meusite/app:latest

# Snyk
snyk container test meusite/app:latest
```

Integrar na CI — block builds com Críticos/Altos.

## Kubernetes — Pod Security

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: meusite/app@sha256:hash
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]    # se necessário escutar < 1024
    resources:
      limits:
        memory: "512Mi"
        cpu: "500m"
      requests:
        memory: "256Mi"
        cpu: "250m"
```

## Pod Security Standards (PSS)

K8s 1.25+ tem **Pod Security admission**:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: prod
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
```

Níveis:
- **privileged** — sem restrições (mau)
- **baseline** — previne escalação conhecida
- **restricted** — práticas hardened atuais

## Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: prod
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]

---
# Allow específico
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: prod
spec:
  podSelector:
    matchLabels: { app: api }
  ingress:
  - from:
    - podSelector:
        matchLabels: { app: frontend }
    ports:
    - port: 8080
```

## Secrets em K8s

```yaml
# BAD — Secret em base64 não é encryption
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  password: cGFzc3dvcmQ=  # base64 de "password"

# GOOD — usar:
# - Sealed Secrets (Bitnami)
# - External Secrets Operator + AWS Secrets Manager / GCP Secret Manager / HashiCorp Vault
# - SOPS para encrypt em git
```

## RBAC

```yaml
# Princípio do menor privilégio
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]    # NÃO "*"
```

## Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  annotations:
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/server-snippet: |
      add_header Strict-Transport-Security "max-age=31536000" always;
spec:
  tls:
  - hosts: ["api.meusite.tld"]
    secretName: api-tls
  rules:
  - host: api.meusite.tld
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api
            port: { number: 80 }
```

## Common antipatterns

### `:latest` em image tags
- Builds não reproduzíveis. Tag com hash ou versão semântica.

### `runAsUser: 0` ou `privileged: true`
- Container com root do host se escapa.

### `hostNetwork: true` / `hostPID: true`
- Container vê network/PIDs do host.

### Sem network policies
- Default = allow all entre pods.

### `ConfigMap` para secrets
- ConfigMap não é encrypted.

### `kubectl exec` sem auditing
- Acesso a containers sem trail.

## Quick wins

- [ ] Dockerfile com pinned base image (sha256)
- [ ] Multi-stage build com runtime distroless/scratch
- [ ] `USER` non-root
- [ ] `--no-install-recommends` em apt-get
- [ ] BuildKit secrets para build-time secrets
- [ ] `trivy`/`grype` na CI sem Críticos
- [ ] Pod Security Standard `restricted` em namespaces de prod
- [ ] `securityContext` com `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`
- [ ] `capabilities: { drop: ["ALL"] }` + add only what needed
- [ ] Resource limits (memory + CPU)
- [ ] Network policies default-deny
- [ ] Secrets via External Secrets Operator / Sealed Secrets
- [ ] RBAC granular (não cluster-admin)
- [ ] Ingress com TLS + HSTS
- [ ] Audit logs habilitados
- [ ] Imagens scanned em CI + em runtime (Falco)
- [ ] etcd encryption at rest
- [ ] PodDisruptionBudgets para HA
