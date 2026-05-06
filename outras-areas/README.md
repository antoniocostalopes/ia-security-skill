# Outras Áreas — Domínios Especializados

> Áreas de segurança fora do código de aplicação tradicional. Cada uma é um mundo próprio; estes ficheiros dão **primer + apontadores**, não exaustivo. Carregar conforme stack detetado.

## Infraestrutura

| Área | Ficheiro | Quando carregar |
|---|---|---|
| Containers / Kubernetes | `containers-k8s.md` | `Dockerfile`, `*.yaml` (K8s), `helm/` |
| Container runtime | `container-runtime.md` | DaemonSets `falco`/`aqua`, AppArmor profiles, seccomp specs |
| Service mesh | `service-mesh.md` | Istio/Linkerd/Consul Connect installs, sidecar annotations |
| Infrastructure as Code | `iac-terraform.md` | `*.tf`, CloudFormation, Pulumi |
| CI/CD pipelines | `ci-cd-pipelines.md` | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` |

## Cloud

| Área | Ficheiro | Quando carregar |
|---|---|---|
| AWS | `cloud-aws.md` | `aws-cli` configs, SAM templates, CDK |
| GCP | `cloud-gcp.md` | `gcloud` configs, Deployment Manager |
| Azure | `cloud-azure.md` | `az` configs, ARM templates, Bicep |

## Identity & DNS

| Área | Ficheiro | Quando carregar |
|---|---|---|
| DNS / DNSSEC | `dns-security.md` | Zone files, `route53_record`, `cloudflare_record`, migrações DNS |
| Email infrastructure | `email-infrastructure.md` | Mail server config, SPF/DKIM/DMARC records, MTA-STS |

## Web platforms emergentes

| Área | Ficheiro | Quando carregar |
|---|---|---|
| WebAssembly | `webassembly.md` | `.wasm` files, `wasm-bindgen`, `assemblyscript`, WASI |
| Service workers / PWA | `service-workers-pwa.md` | `service-worker.js`, `workbox-*`, `manifest.webmanifest` |

## SaaS & arquitetura

| Área | Ficheiro | Quando carregar |
|---|---|---|
| Multi-tenant SaaS | `multi-tenant-saas.md` | Schema com `tenant_id`/`org_id`, subdomínios por tenant |

## AI / ML / Web3

| Área | Ficheiro | Quando carregar |
|---|---|---|
| ML / AI security | `ml-ai-security.md` | Modelos, training pipelines, RAG |
| LLM agent security | `llm-agent-security.md` | `openai`, `anthropic`, `langchain`, agentes com tool use |
| Web3 / Smart contracts | `web3-smart-contracts.md` | `*.sol`, `hardhat.config`, `foundry.toml` |

## Verticals especializadas

| Área | Ficheiro | Quando carregar |
|---|---|---|
| Game security | `game-security.md` | Unity/Unreal/Godot, multiplayer, IAP |
| IoT / Embedded | `iot-embedded.md` | Firmware C/C++, ESP/Arduino projects |

## Crypto avançada

| Área | Ficheiro | Quando carregar |
|---|---|---|
| Post-quantum crypto | `post-quantum-crypto.md` | Apps com confidentiality requirement ≥10 anos, migração TLS hybrid |

## Compliance

| Área | Ficheiro | Quando carregar |
|---|---|---|
| Privacidade / Compliance | `privacidade-compliance.md` | GDPR/LGPD/CCPA/HIPAA/PCI-DSS — sempre relevante |
