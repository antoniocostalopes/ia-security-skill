# Service Mesh — Segurança

> Istio, Linkerd, Consul Connect. Camada de mTLS automático + traffic policy entre microsserviços. Mal configurado, abre portas em vez de fechar.

## Quando carregar

- `kubectl get -n istio-system` retorna pods
- `helm list` mostra istio/linkerd/consul
- Manifests com `VirtualService`, `DestinationRule`, `PeerAuthentication`, `AuthorizationPolicy` (Istio)
- `linkerd.io/inject: enabled` annotations
- Arquitetura microsserviços com sidecar proxy (Envoy, linkerd-proxy)

## Mindset

- **mTLS automático ≠ mTLS enforced** — deve estar `STRICT`, não `PERMISSIVE`
- **Sidecar é trust boundary** — escapar do sidecar = escapar da policy
- **Authorization policies podem ser permissivas demais** (default allow)
- **Egress traffic** muitas vezes ignorado (data exfil sem alarmes)
- **Telemetria expõe topologia** se ingressada para fora

## 8 categorias críticas

### 1. mTLS em modo PERMISSIVE permanente

**BAD** — `PeerAuthentication`:
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE  # aceita plaintext OU mTLS
```

`PERMISSIVE` é para migration. Em prod, atacante dentro do cluster envia plaintext e bypassa todas as policies.

**GOOD** — `STRICT`:
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

Por namespace específico, override:
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

### 2. AuthorizationPolicy ausente ou cega

**BAD** — sem policy = default ALLOW (Istio):
```yaml
# nada
```

Qualquer pod chama qualquer pod.

**GOOD** — default deny + allowlist:
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: default-deny
  namespace: production
spec: {}
```
(spec vazia = deny all)

E policy específica para autorizar caminhos:
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: api-allow-from-frontend
  namespace: production
spec:
  selector:
    matchLabels:
      app: api
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - cluster.local/ns/production/sa/frontend-sa
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/v1/*"]
```

### 3. Egress não controlado

**BAD** — pods chamam internet sem `ServiceEntry`:
```yaml
# Istio default: PASSTHROUGH para qualquer destination
```

Atacante exfiltrate dados para `evil.com:443`. Sem registo, sem block.

**GOOD** — `outboundTrafficPolicy: REGISTRY_ONLY` + `ServiceEntry` allowlist:
```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: stripe-api
spec:
  hosts:
    - api.stripe.com
  ports:
    - number: 443
      name: https
      protocol: TLS
  resolution: DNS
```

E em `meshConfig`:
```yaml
meshConfig:
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
```

Tudo o que não tiver `ServiceEntry` é bloqueado.

### 4. Sidecar bypass via hostNetwork

**BAD** — pod com `hostNetwork: true`:
```yaml
spec:
  hostNetwork: true
  containers:
    - name: app
      image: app:1.0
```

Envoy sidecar não inteceta tráfego porque pod usa namespace de rede do host. mTLS bypass.

**GOOD** — bloquear via Pod Security Standards (`restricted` profile) ou OPA Gatekeeper policy:
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sPSPHostNetwork
metadata:
  name: psp-host-network
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
```

### 5. JWT validation incompleta

**BAD** — `RequestAuthentication` sem `audiences`:
```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
spec:
  jwtRules:
    - issuer: "https://auth.example.com"
      jwksUri: "https://auth.example.com/.well-known/jwks.json"
```

Token de outro serviço (mesmo issuer) é aceite.

**GOOD** — validar audience:
```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth-api
spec:
  selector:
    matchLabels:
      app: api
  jwtRules:
    - issuer: "https://auth.example.com"
      jwksUri: "https://auth.example.com/.well-known/jwks.json"
      audiences:
        - "api.example.com"
      forwardOriginalToken: false
```

### 6. mesh telemetry exposto sem auth

Prometheus / Grafana / Kiali / Jaeger expostos via `Gateway` sem auth = topology leak + querying de métricas sensíveis (latency permite timing attacks).

**Fix:**
- Auth obrigatório nos dashboards (`oauth2-proxy`, basic auth via Envoy filter)
- Ingress restrito a IPs internos (VPN-only)

### 7. Linkerd / Consul: similares mas diferentes

**Linkerd** — mTLS por default mas:
```yaml
linkerd.io/inject: enabled  # tem de estar em todos os namespaces críticos
```
Verificar `linkerd check`.

**Consul Connect:**
- Intentions = authorization policies. Sem intentions = deny by default (em mode `default`) ou allow (em mode `allow`)
- Verificar `consul intention list`

### 8. Certificate rotation / SPIFFE identity

mTLS depende de certs curtos. Verifica:
- Cert TTL razoável (< 24h é bom, 90 dias é mau)
- Auto-rotation funciona (Istio: `istio-ca-secret`)
- SPIFFE IDs únicos por workload (`spiffe://cluster.local/ns/<ns>/sa/<sa>`)

```bash
istioctl proxy-config secret <pod>.<ns> | grep "Cert Lifetime"
```

## Quick wins

- [ ] mTLS em `STRICT` em todos os namespaces de produção
- [ ] Default AuthorizationPolicy = deny + allowlist explícita
- [ ] `outboundTrafficPolicy: REGISTRY_ONLY` + ServiceEntry para todos os egresses
- [ ] hostNetwork bloqueado via Pod Security ou OPA
- [ ] JWT `audiences` validados em todas RequestAuthentication
- [ ] Telemetria (Prometheus, Grafana, Kiali, Jaeger) atrás de auth
- [ ] Cert TTL curto (<24h) com auto-rotation
- [ ] `linkerd check` ou `istioctl analyze` no CI
- [ ] OPA Gatekeeper / Kyverno policies para enforcement
- [ ] Auditing dos AuthorizationPolicy (`AUDIT` action para detection)
- [ ] Sidecar resources limites configurados (não OOM-friendly)
- [ ] Mesh CA segregada por ambiente (dev/staging/prod)

## Falsos positivos

- `PERMISSIVE` durante migration documentada — temporário aceitável
- `AuthorizationPolicy` permissiva em namespace de dev — OK
- ServiceEntry para muitos hosts (legacy migration) — pode ser legítimo

## Severidade típica

- **Crítico** — mTLS PERMISSIVE em prod, default allow em authorization, hostNetwork pods sem policy
- **Alto** — egress não controlado, JWT sem audience
- **Médio** — telemetry exposta, cert TTL longo
- **Baixo** — sidecar resources não tunados

## Cross-references

- [`containers-k8s.md`](containers-k8s.md) — base K8s
- [`container-runtime.md`](container-runtime.md) — Falco para detect mesh bypass
- [`../analises/14-autenticacao-sessao.md`](../analises/14-autenticacao-sessao.md) — JWT
- [`multi-tenant-saas.md`](multi-tenant-saas.md) — namespace isolation

## Recursos

- [Istio Security Best Practices](https://istio.io/latest/docs/ops/best-practices/security/)
- [Linkerd Security](https://linkerd.io/2/features/automatic-mtls/)
- [SPIFFE/SPIRE](https://spiffe.io/)
