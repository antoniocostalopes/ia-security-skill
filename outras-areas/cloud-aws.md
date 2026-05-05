# AWS — Segurança

## IAM — princípio do menor privilégio

### Roles vs Users
- **Apps** usam IAM Roles (assumed via instance profile, IRSA, etc.).
- **Humanos** usam IAM Users **com MFA obrigatório** (ou IAM Identity Center / SSO).
- **Nunca** access keys de IAM User em apps.

### Policies — exemplos

```json
// BAD
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "*",
    "Resource": "*"
  }]
}

// GOOD
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:PutObject"],
    "Resource": "arn:aws:s3:::my-bucket/*",
    "Condition": {
      "Bool": { "aws:SecureTransport": "true" },
      "StringEquals": { "s3:x-amz-server-side-encryption": "AES256" }
    }
  }]
}
```

### Service Control Policies (SCPs)
- Para Organizations — bloqueio global de ações (ex.: bloquear regiões não usadas).

## S3 — defaults perigosos

| Default | Mudar para |
|---|---|
| Público | Block all public access (account-level + bucket-level) |
| Sem encryption | SSE-S3 ou SSE-KMS by default |
| Sem versioning | Versioning enabled (recovery de delete acidental) |
| Sem MFA delete | MFA delete em buckets críticos |
| Sem logging | Server access logs para outro bucket |
| Sem lifecycle | Lifecycle para mover para Glacier após X dias |

## Secrets Manager / Parameter Store

```python
# Application code
import boto3
client = boto3.client('secretsmanager')
secret = client.get_secret_value(SecretId='prod/db/password')['SecretString']
```

```bash
# Rotation automático (Lambda)
aws secretsmanager rotate-secret --secret-id prod/db/password \
  --rotation-rules AutomaticallyAfterDays=30
```

## KMS

- **Customer Managed Keys (CMK)** — control completo + audit
- **AWS Managed Keys** — convenience, sem cost mas sem control
- Sempre **rotation enabled** (anual)
- Aliases (`alias/myapp-prod`) em vez de KeyId (mudaá com rotation)

## VPC

```
- Multi-AZ subnets (public + private)
- NAT Gateway (não NAT Instance) para egress de private
- VPC Endpoints (Gateway para S3/DynamoDB, Interface para outros)
- Security Groups stateful, NACLs stateless
- Flow Logs habilitados
- VPC Lattice / Transit Gateway para multi-VPC
```

## EC2

```
- IMDSv2 obrigatório (HttpTokens: required) — anti SSRF a metadata
- EBS encryption at rest (default em conta)
- Instance Connect ou SSM Session Manager (não SSH público)
- Security Groups específicos (sem 0.0.0.0/0 para 22, 3389)
- Patches automáticos (Systems Manager Patch Manager)
- AMI hardened (CIS AMIs)
```

## Lambda

```
- Execution role com permissões mínimas
- VPC config se acessa recursos privados
- Environment variables encryptadas com KMS
- Provisioned concurrency para evitar cold start em endpoints sensíveis
- AWS X-Ray para tracing
- Reserved concurrency para limit DoS
- Layer com dependencies separado (rapid update sem redeploy)
```

## RDS / Aurora

```
- Encryption at rest (KMS)
- Encryption in transit (force_ssl = 1)
- Public accessibility = false
- Subnet group em private subnets
- Automated backups + retention adequada
- Performance Insights habilitado
- Enhanced Monitoring
- Deletion protection
- IAM database authentication (não password) onde possível
- Read replicas para offloading
```

## CloudTrail

- **Multi-region** trail em conta master
- **Log file validation** habilitada
- **Logs em S3** com object lock + KMS encryption
- **CloudWatch Logs integration** para alarms
- **Event selectors** para data events em buckets/funções críticos

## GuardDuty / Security Hub / Config

- **GuardDuty** — threat detection (anomalies, crypto mining, etc.)
- **Security Hub** — agregação de findings
- **AWS Config** — compliance contínuo (rules: required-tags, s3-encryption-enabled, etc.)
- **Inspector** — vuln scanning de EC2/ECR

## WAF

```hcl
resource "aws_wafv2_web_acl" "api" {
  name  = "api-protection"
  scope = "REGIONAL"

  default_action { allow {} }

  rule {
    name     = "AWS-Common"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config { cloudwatch_metrics_enabled = true ... }
  }

  rule {
    name     = "RateLimit"
    priority = 2
    action { block {} }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
  }
}
```

## Common antipatterns

### Root account com access keys ativas
- Apagar imediatamente. Root só para account closure.

### Cross-account roles sem `External ID`
- Confused deputy attack.

### EC2 com IMDSv1 enabled
- SSRF na app → roubo de credenciais via metadata.

### S3 buckets públicos por engano
- Use Macie ou Trusted Advisor para detect.

### Sem tag de owner / cost-center
- Recursos órfãos não geridos.

### Logs sem KMS
- Se atacante acede ao bucket de logs, vê tudo.

## Quick wins

- [ ] Root account: MFA + sem access keys + sem uso quotidiano
- [ ] IAM Identity Center / SSO para humanos
- [ ] IAM Roles para apps (nunca access keys)
- [ ] MFA enforcement para todos os IAM users
- [ ] CloudTrail multi-region em todas as contas
- [ ] GuardDuty habilitado em todas as regiões usadas
- [ ] Security Hub centralizado
- [ ] AWS Config com rules de baseline
- [ ] S3 Block Public Access account-level
- [ ] Default EBS encryption
- [ ] IMDSv2 obrigatório em EC2
- [ ] SSM Session Manager (não SSH público)
- [ ] Secrets em Secrets Manager (não env vars committed)
- [ ] KMS keys com rotation enabled
- [ ] VPC Flow Logs habilitados
- [ ] WAF nos endpoints públicos
- [ ] AWS Backup centralizado
- [ ] Trusted Advisor checks regulares
