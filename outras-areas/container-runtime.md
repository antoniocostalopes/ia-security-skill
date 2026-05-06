# Container Runtime — Segurança

> Detection e enforcement em runtime: Falco, AppArmor, SELinux, seccomp, capabilities, gVisor. Para além do `containers-k8s.md` (que cobre K8s manifests), este foca no runtime e no kernel.

## Quando carregar

- DaemonSets com `falco`, `aqua-csp`, `sysdig`, `tracee`
- AppArmor profiles (`/etc/apparmor.d/`)
- SELinux contexts (`getenforce` retorna `Enforcing`)
- seccomp profiles em pod specs
- gVisor (`runtimeClassName: gvisor`) ou Kata Containers

## Mindset

- **Container ≠ VM** — partilham kernel com host
- **Container escape** = root no host
- **Runtime detection** apanha o que SAST/manifest scanning não vê (zero-days, comportamento)
- **Defense in depth:** seccomp + AppArmor + SELinux + capabilities + read-only FS + non-root user
- **Sem profiles** = container tem ~300 syscalls disponíveis (incluindo perigosos)

## 7 categorias

### 1. Sem seccomp profile

**BAD** — pod sem seccomp:
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: app
      image: app:1.0
```

Default Docker seccomp tem ~50 syscalls bloqueados, mas alguns kubelet runtimes não aplicam. Container pode chamar `mount`, `unshare`, `keyctl` para escape.

**GOOD** — usar `RuntimeDefault` (mínimo) ou custom profile:
```yaml
apiVersion: v1
kind: Pod
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: app:1.0
      securityContext:
        seccompProfile:
          type: RuntimeDefault
```

Para apps stateless web típicas, custom profile reduzido:
```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": ["accept4", "bind", "close", "connect", "epoll_*", "fstat", "futex", "read", "write"],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

### 2. AppArmor sem profile

**BAD** — sem annotation:
```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: app
```

**GOOD** — usar `runtime/default` ou custom:
```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: runtime/default
spec:
  containers:
    - name: app
```

Kubernetes 1.30+: usar `appArmorProfile` em `securityContext`:
```yaml
spec:
  containers:
    - name: app
      securityContext:
        appArmorProfile:
          type: RuntimeDefault
```

Custom profile:
```
#include <tunables/global>
profile app-profile flags=(attach_disconnected) {
  #include <abstractions/base>
  /usr/bin/app r,
  /etc/app/** r,
  /var/log/app/** rw,
  deny /etc/passwd r,
  deny /proc/sys/** w,
}
```

### 3. Capabilities excessivas

**BAD**:
```yaml
spec:
  containers:
    - name: app
      securityContext:
        capabilities:
          add: ["SYS_ADMIN", "NET_ADMIN", "SYS_PTRACE"]
```

`SYS_ADMIN` é praticamente root. `NET_ADMIN` permite manipular tráfego de rede do host.

**GOOD** — drop ALL, add minimal:
```yaml
spec:
  containers:
    - name: app
      securityContext:
        capabilities:
          drop: ["ALL"]
          add: ["NET_BIND_SERVICE"]  # só se precisar bind <1024
```

Maior parte das apps web não precisa de NENHUMA capability:
```yaml
capabilities:
  drop: ["ALL"]
```

### 4. Falco / runtime detection sem rules customizadas

Falco default rules são genéricas. Para detection eficaz:

```yaml
# /etc/falco/falco_rules.local.yaml
- rule: Unauthorized access to secrets
  desc: Detect read of secret files outside known apps
  condition: >
    open_read and
    fd.name startswith /var/run/secrets/ and
    not proc.name in (myapp, kubelet, prometheus)
  output: >
    Unauthorized secret access (user=%user.name proc=%proc.name file=%fd.name container=%container.id)
  priority: WARNING
  tags: [secrets, mitre_credential_access]

- rule: Container shell spawn
  desc: Detect shell spawn in container (not in dev/debug containers)
  condition: >
    spawned_process and
    proc.name in (sh, bash, zsh, fish, ash) and
    container and
    not container.image.repository in (dev-debug-tools)
  output: >
    Shell spawned in container (user=%user.name proc.cmdline=%proc.cmdline container=%container.image.repository)
  priority: NOTICE
  tags: [shell, mitre_execution]
```

E configurar Falco para enviar alerts (Slack, PagerDuty, SIEM).

### 5. Container running as root

**BAD**:
```yaml
spec:
  containers:
    - name: app
      image: app:1.0
      # uid 0 by default
```

**GOOD**:
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10000
    runAsGroup: 10000
    fsGroup: 10000
  containers:
    - name: app
      image: app:1.0
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
```

E no `Dockerfile`:
```dockerfile
FROM gcr.io/distroless/nodejs:18
USER nonroot:nonroot
COPY --chown=nonroot:nonroot . /app
```

### 6. Privileged containers

**BAD**:
```yaml
securityContext:
  privileged: true
```

`privileged: true` = todas capabilities + acesso a `/dev/*` + `/sys/*`. Trivial container escape.

**Casos legítimos (raros):**
- DaemonSets de monitoring (Falco, Datadog) — devem usar capabilities específicas, não `privileged`
- CNI plugins durante setup

**Bloquear via Pod Security Standards `restricted`:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
```

### 7. gVisor / Kata para workloads sensíveis

Para multi-tenant ou code execution não confiável (CI runners, sandboxed code):

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
---
apiVersion: v1
kind: Pod
spec:
  runtimeClassName: gvisor
  containers:
    - name: untrusted-code
      image: builder:1.0
```

gVisor inteceta syscalls em userspace — kernel exploits no container não escapam.

**Performance trade-off:** ~10-30% overhead. Justificado para workloads de risco.

## SELinux notes

Em distros com SELinux (RHEL, Fedora):
- `getenforce` deve retornar `Enforcing`
- Container labels: `system_u:object_r:container_file_t:s0` por default
- Volumes mounted no host devem manter SELinux context (`:Z` em `docker run -v /host:/container:Z`)

```yaml
spec:
  securityContext:
    seLinuxOptions:
      level: "s0:c123,c456"
```

## Quick wins

- [ ] Pod Security Standards `restricted` enforced em prod namespaces
- [ ] `runAsNonRoot: true` em todos os pods (workload, não system)
- [ ] `allowPrivilegeEscalation: false`
- [ ] `readOnlyRootFilesystem: true` quando viável (apps web tipicamente OK)
- [ ] `capabilities.drop: [ALL]` + add específico mínimo
- [ ] `seccompProfile: RuntimeDefault` ou custom
- [ ] AppArmor / SELinux profile aplicado
- [ ] Sem `privileged: true` (ou justificado)
- [ ] Sem `hostPID`, `hostIPC`, `hostNetwork` (exceto justificados)
- [ ] Falco com rules customizadas + alerting integrado
- [ ] gVisor/Kata para workloads de execução não confiável (CI runners, sandboxes)
- [ ] Image scanning + admission control (Trivy + Kyverno)
- [ ] Imagens distroless ou minimalistas (não `ubuntu:latest`)
- [ ] `livenessProbe` / `readinessProbe` não excessivamente permissivos
- [ ] `imagePullPolicy: Always` para tags mutables (ou usar digests)

## Falsos positivos

- DaemonSets de observability com `privileged: true` ou `hostPID: true` — frequentemente legítimo, deve estar limitado a specific node selectors
- Containers init com mais permissions que main — esperado, mas devem terminar e não persistir
- `/var/run/docker.sock` montado — mau, mas pode ser justificado em CI ferramentas (Tekton, Jenkins)

## Severidade típica

- **Crítico** — `privileged: true` em apps regular, sem PSS, capabilities `SYS_ADMIN`
- **Alto** — running as root, sem seccomp, hostPID/Network sem justificação
- **Médio** — sem AppArmor, falta de Falco rules customizadas
- **Baixo** — readOnlyRootFilesystem ausente em apps stateless

## Cross-references

- [`containers-k8s.md`](containers-k8s.md) — Manifests K8s gerais
- [`service-mesh.md`](service-mesh.md) — sidecar bypass via hostNetwork
- [`../analises/15-configuracao-hardening.md`](../analises/15-configuracao-hardening.md)

## Recursos

- [Falco Rules](https://github.com/falcosecurity/falco/tree/master/rules)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [gVisor](https://gvisor.dev/)
- [Linux Capabilities Cheatsheet](https://man7.org/linux/man-pages/man7/capabilities.7.html)
