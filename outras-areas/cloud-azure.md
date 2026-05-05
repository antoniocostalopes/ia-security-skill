# Azure — Segurança

## Identity (Entra ID, ex-Azure AD)

- **MFA conditional access** obrigatório para users
- **Privileged Identity Management (PIM)** para roles administrativos (just-in-time)
- **Managed Identities** para apps (system ou user-assigned)
- **Service Principals** com cert auth (não secrets) onde possível

## RBAC

- Roles built-in preferíveis a custom (a menos que necessário)
- Atribuir no menor scope possível (resource > resource group > subscription)
- Owner role apenas para emergency / setup

## Storage Accounts

```
- Public access desabilitado (storageAccount + containers)
- Network ACLs (Selected networks, deny default)
- Private Endpoints
- Encryption at rest (Microsoft Managed Keys ou CMK)
- Soft delete habilitado
- Versioning para blobs críticos
- Secure transfer required (HTTPS only)
- TLS 1.2 minimum
- Shared Key access desabilitado (forçar Entra ID auth)
```

## Key Vault

```
- Soft delete + purge protection habilitados
- Network restrictions (Private Endpoint ou allowlist)
- RBAC (preferível a Access Policies legacy)
- Logging para Sentinel
- Auto-rotation para keys/secrets onde possível
```

```python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(vault_url="https://kv-prod.vault.azure.net", credential=credential)
secret = client.get_secret("db-password").value
```

## App Service / Functions

```
- Managed Identity ativo (não connection strings)
- HTTPS only
- Minimum TLS 1.2
- IP restrictions (allowlist)
- VNet integration para acesso a recursos privados
- App Settings em Key Vault references
- Health checks habilitados
- WAF (Application Gateway ou Front Door)
```

## SQL Database / Cosmos DB

```
- Entra ID authentication (não SQL auth)
- Private Endpoint (não Public Network Access)
- Transparent Data Encryption (default ON)
- Always Encrypted para colunas sensíveis
- Auditing habilitado, logs para Storage / Log Analytics
- Advanced Threat Protection
- Backup retention adequada
```

## Virtual Machines

```
- JIT (Just-In-Time) access via Defender
- Bastion host (não SSH/RDP públicos)
- Network Security Groups específicos
- Disk encryption (ADE) ou Server-Side Encryption with CMK
- Patches automáticos (Azure Update Manager)
- Defender for Servers
```

## AKS (Azure Kubernetes Service)

```
- API server: authorized IP ranges ou Private Cluster
- Entra ID integration
- RBAC + Azure RBAC
- Managed Identity (não Service Principal)
- Pod Identity ou Workload Identity
- Network Policy (Calico ou Azure)
- Azure Policy add-on
- Defender for Containers
```

## Networking

```
- Hub-spoke topology
- Azure Firewall ou Network Virtual Appliance
- DDoS Protection Standard (apps críticos)
- Private Endpoints para PaaS services
- Service Endpoints como mitigação básica
- Azure Front Door / Application Gateway com WAF
- Network Watcher Flow Logs
```

## Defender for Cloud

- **Enhanced security features** (paid) — recommendations + threat detection
- **Secure Score** — baseline compliance
- **Just-in-Time VM access**
- **Adaptive Application Controls**

## Sentinel

- SIEM/SOAR cloud-native
- Data connectors para Azure services + 3rd party
- Analytics rules para detection
- Playbooks (Logic Apps) para automated response

## Common antipatterns

### Subscription Owner para múltiplas pessoas
- Privilege excessivo.

### Service Principals com client secret
- Roda manualmente; preferir cert ou Managed Identity.

### Storage com Shared Key access ativo
- Anyone com a key tem acesso total.

### App Service com FTP habilitado
- FTP é cleartext.

### SQL Database com Public Network Access habilitado
- Exposto à internet.

### Custom roles com `*` em actions
- IAM permissivo.

## Quick wins

- [ ] MFA conditional access obrigatório
- [ ] PIM para roles administrativos
- [ ] Managed Identities (não service principal secrets)
- [ ] Defender for Cloud Standard tier
- [ ] Sentinel para SIEM
- [ ] Storage Accounts com Public access disabled + Shared Key disabled
- [ ] Key Vault com Private Endpoint + RBAC
- [ ] App Service HTTPS only + Min TLS 1.2 + Managed Identity
- [ ] SQL com Entra ID auth + Private Endpoint
- [ ] AKS Private Cluster + Workload Identity
- [ ] WAF em Application Gateway / Front Door
- [ ] DDoS Protection em apps críticos
- [ ] Activity Log + Diagnostic Settings centralizados
- [ ] Resource Locks (CanNotDelete) em recursos críticos
- [ ] Azure Policy enforcement (audit + deny)
- [ ] Backup centralizado (Azure Backup)
