# GCP — Segurança

## IAM

### Princípios
- **Service Accounts** para apps (não user accounts).
- **Workload Identity** para GKE → service accounts sem keys.
- **MFA obrigatório** para users humanos (Google Workspace + advanced protection).
- **Predefined roles** preferíveis a custom (mas custom mais granular).

### Roles
- Evitar `roles/owner`, `roles/editor` em prod.
- Preferir specific roles: `roles/storage.objectViewer`, `roles/secretmanager.secretAccessor`.

### Service account keys — evitar

```bash
# BAD — service account key file (rotação manual)
gcloud iam service-accounts keys create key.json --iam-account=sa@project.iam

# GOOD — Workload Identity (GKE) ou Workload Identity Federation
```

## Cloud Storage (GCS)

```
- Uniform bucket-level access (não ACLs legacy)
- Bucket Lock para retention legal
- CMEK (Customer Managed Encryption Keys) com KMS
- Lifecycle rules para cold storage
- Versioning + retention para anti-delete
- Public access prevention (organization policy)
- VPC Service Controls para perimetrar
```

## Secret Manager

```python
from google.cloud import secretmanager

client = secretmanager.SecretManagerServiceClient()
name = f"projects/{project_id}/secrets/db_password/versions/latest"
response = client.access_secret_version(request={"name": name})
secret = response.payload.data.decode("UTF-8")
```

- **Automatic rotation** com Cloud Functions / Cloud Run.
- **Replication** policy (`automatic` ou `user_managed` com regiões específicas).
- **CMEK** para encryption.

## VPC

```
- Default VPC apagada / não usada
- Private Google Access para apps em private subnets
- Cloud NAT para egress
- VPC Service Controls (perimeter de dados sensíveis)
- VPC Flow Logs habilitados
- Private Service Connect para acesso a Google APIs
- Hierarchical firewall policies (organization-wide)
- Cloud Armor para WAF + DDoS
```

## Compute Engine

```
- OS Login com IAM (não SSH keys de instance metadata)
- Shielded VMs (Secure Boot, vTPM, integrity monitoring)
- IAP (Identity-Aware Proxy) tunnel para SSH (não SSH público)
- Confidential Computing (AMD SEV) para workloads sensíveis
- Compute Engine API access reduzido
- Auto-update enabled
```

## GKE

```
- Workload Identity (Service Account binding)
- Private cluster (master sem IP público)
- Authorized networks para acesso a master
- Network Policy enabled (Calico)
- Binary Authorization (signed images only)
- Pod Security Standards
- Shielded GKE Nodes
- Auto-upgrade enabled
- COS (Container-Optimized OS)
- VPC-native (alias IPs)
```

## Cloud Run

```
- Ingress: internal-only para serviços não públicos
- Service Account específico per service
- Environment variables via Secret Manager (não plain text)
- VPC connector se acessa recursos privados
- CPU allocation = "always allocated" para apps com background work
- Min instances para evitar cold start em endpoints sensíveis
- Concurrency setting adequado
```

## Cloud SQL

```
- Private IP (não public)
- Authorized networks vazios
- SSL/TLS obrigatório
- IAM database authentication
- Automated backups + point-in-time recovery
- Maintenance window definida
- Customer-managed encryption keys (opcional)
```

## Cloud Audit Logs

- **Admin Activity** — sempre habilitado
- **Data Access** — habilitar para resources sensíveis (custos)
- **System Event** — sempre
- **Policy Denied** — sempre
- Logs sink para Cloud Storage (long retention) + BigQuery (queries)

## Security Command Center

- **Standard** — gratuito, basic findings
- **Premium** — Event Threat Detection, Container Threat Detection, etc.
- Findings em Pub/Sub para integração com SIEM

## Common antipatterns

### `roles/owner` para Service Account
- Privilege escalation.

### Service Account keys committed em git
- Game over para o projeto inteiro.

### Cloud Storage com `allUsers` ou `allAuthenticatedUsers`
- Bucket público.

### GKE com master público + sem authorized networks
- Master API exposto.

### Compute Engine com `enable-oslogin: false` em metadata
- SSH keys legacy possíveis.

### Sem Organization Policies
- Defaults permissivos.

## Quick wins

- [ ] Org Policies: bloquear external IP em VMs, exigir uniform bucket access, bloquear public access
- [ ] Workload Identity (GKE) ou WIF (apps externas) — sem SA keys
- [ ] Service Accounts com roles específicas
- [ ] MFA enforcement (Google Workspace)
- [ ] Cloud Audit Logs Data Access habilitados em recursos sensíveis
- [ ] Security Command Center ativo (standard mínimo)
- [ ] Secrets em Secret Manager
- [ ] CMEK para storage/DB sensíveis
- [ ] Private clusters / Private services
- [ ] VPC Service Controls em projetos com dados sensíveis
- [ ] Cloud Armor em endpoints públicos
- [ ] Binary Authorization em GKE
- [ ] Shielded VMs
- [ ] OS Login para SSH
- [ ] IAP para acesso interno
- [ ] Forseti / Cloud Asset Inventory para audit contínuo
