# Infrastructure as Code (Terraform / CloudFormation / Pulumi) — Segurança

## State files — extremamente sensíveis

Terraform `terraform.tfstate` contém:
- Connection strings
- Passwords gerados
- Private keys
- IPs internos
- ARNs / resource IDs

### NÃO fazer
- Commit `terraform.tfstate` no git.
- Local state em filesystem partilhado sem encryption.
- State em S3 sem encryption.

### Fazer
```hcl
# backend remoto + encryption + lock
terraform {
  backend "s3" {
    bucket         = "tf-state-prod"
    key            = "main/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true              # SSE
    kms_key_id     = "alias/tf-state"  # KMS encryption
    dynamodb_table = "tf-state-lock"   # state locking
  }
}
```

## Secrets em IaC

```hcl
# BAD — hardcoded
resource "aws_db_instance" "db" {
  password = "supersecret123"  # state expõe; commit expõe
}

# GOOD — gerado, gerido em Secrets Manager
resource "random_password" "db" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db_pwd" {
  name = "prod/db/password"
}

resource "aws_secretsmanager_secret_version" "db_pwd" {
  secret_id     = aws_secretsmanager_secret.db_pwd.id
  secret_string = random_password.db.result
}

resource "aws_db_instance" "db" {
  password = random_password.db.result
}
```

```hcl
# Variables sensíveis — sensitive = true
variable "api_key" {
  type      = string
  sensitive = true   # não aparece em logs
}
```

## IAM — princípio do menor privilégio

```hcl
# BAD — wildcards
resource "aws_iam_policy" "app" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"           # !!
      Resource = "*"           # !!
    }]
  })
}

# GOOD
resource "aws_iam_policy" "app" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
}
```

## S3 buckets — defaults perigosos

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "meusite-data"
}

# CRÍTICO — bloquear public access
resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
  }
}

# Versioning (anti delete)
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration { status = "Enabled" }
}

# Logging
resource "aws_s3_bucket_logging" "data" {
  bucket        = aws_s3_bucket.data.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "data/"
}
```

## Security Groups — não 0.0.0.0/0

```hcl
# BAD
resource "aws_security_group_rule" "ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]   # SSH público
}

# GOOD
resource "aws_security_group_rule" "ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.bastion_cidr]   # só bastion
}
```

## Ferramentas de scanning

```bash
# Checkov — Bridgecrew
checkov -d .

# tfsec
tfsec .

# Terrascan
terrascan scan -d .

# Snyk IaC
snyk iac test .

# AWS-specific
aws-nuke (para teardown), prowler (audit)
```

## Common antipatterns

### State no git
- Secrets exposed.

### `count` sem checks idempotentes
- Recriar recursos pode destruir dados.

### `lifecycle { prevent_destroy = true }` ausente em recursos críticos
- `terraform destroy` apaga tudo.

### `data "aws_iam_policy_document"` com policies overly broad
- IAM permissivo.

### `resource "aws_s3_bucket" "x" { acl = "public-read" }`
- Bucket público.

### Default VPC usado para prod
- Sem segmentação.

### Secrets em variables.tf default
- Commitados.

## Quick wins

- [ ] State em backend remoto encriptado + lock
- [ ] Secrets via Secrets Manager / Vault, não hardcoded
- [ ] `sensitive = true` em variables sensíveis
- [ ] IAM policies específicas (sem `*` em Action/Resource)
- [ ] S3 buckets com Public Access Block + encryption + versioning
- [ ] Security Groups sem `0.0.0.0/0` para portas administrativas
- [ ] `lifecycle { prevent_destroy = true }` em DBs e storage críticos
- [ ] Checkov/tfsec na CI
- [ ] Audit logs habilitados (CloudTrail, Cloud Audit Logs)
- [ ] Tagging consistente (owner, env, cost-center)
- [ ] Terraform module review como código
- [ ] Plan output review obrigatório (não apply blind)
