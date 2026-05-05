# MASVS Mapping — OWASP Mobile Security

> Mapa entre os controlos OWASP MASVS v2 e os módulos desta skill.

## MASVS-STORAGE — Armazenamento

> *Sensitive data is stored securely*

| Controlo | Módulo |
|---|---|
| MASVS-STORAGE-1: Sensitive data não vai para `Documents`/`Cache` desnecessariamente | `armazenamento-local.md` |
| MASVS-STORAGE-2: Apenas storage **system-provided** para credenciais | `armazenamento-local.md`, `ios-native.md`, `android-native.md` |
| MASVS-STORAGE-3: Sensitive data redactada de logs | `analises/22-logging-monitoring.md` |
| Backups excluem dados sensíveis | `armazenamento-local.md` |

## MASVS-CRYPTO — Criptografia

| Controlo | Módulo |
|---|---|
| MASVS-CRYPTO-1: Crypto algoritmos são strong (AES-256, SHA-256+, etc.) | `analises/13-criptografia.md` |
| MASVS-CRYPTO-2: Keys geridas via Keystore/Keychain | `armazenamento-local.md`, `biometria-secure-enclave.md` |

## MASVS-AUTH — Autenticação

| Controlo | Módulo |
|---|---|
| MASVS-AUTH-1: Auth via API standards (OAuth, OIDC) | `analises/14-autenticacao-sessao.md`, `analises/23-api-modernas.md` |
| MASVS-AUTH-2: Sessions devidamente terminadas | `analises/14-autenticacao-sessao.md` |
| MASVS-AUTH-3: Biometric local quando aplicável | `biometria-secure-enclave.md` |

## MASVS-NETWORK — Rede

| Controlo | Módulo |
|---|---|
| MASVS-NETWORK-1: TLS para todas as comunicações | `comunicacao-rede.md` |
| MASVS-NETWORK-2: Cert pinning em endpoints críticos | `comunicacao-rede.md` |

## MASVS-PLATFORM — Interação com plataforma

| Controlo | Módulo |
|---|---|
| MASVS-PLATFORM-1: Permissions justificadas e mínimas | `ios-native.md`, `android-native.md` |
| MASVS-PLATFORM-2: IPC mecanismos protegidos | `deeplinks-intents.md` |
| MASVS-PLATFORM-3: WebView config segura | `webview.md` |

## MASVS-CODE — Code quality

| Controlo | Módulo |
|---|---|
| MASVS-CODE-1: Apps usam software supply chain consciente | `analises/17-dependencias.md` |
| MASVS-CODE-2: Apps validam input de fontes externas | `analises/sanitizacao.md`, `deeplinks-intents.md` |
| MASVS-CODE-3: Sem código debug/test em release | `ios-native.md`, `android-native.md` |
| MASVS-CODE-4: Código de terceiros (SDKs) verificado | `analises/17-dependencias.md` |

## MASVS-RESILIENCE — Resistência a tampering

| Controlo | Módulo |
|---|---|
| MASVS-RESILIENCE-1: App detecta modificação | `jailbreak-root-tampering.md` |
| MASVS-RESILIENCE-2: App detecta runtime instrumentation (Frida) | `reverse-engineering.md` |
| MASVS-RESILIENCE-3: App impede análise estática trivial (obfuscation) | `reverse-engineering.md` |
| MASVS-RESILIENCE-4: App detecta runtime debug | `jailbreak-root-tampering.md` |

## MASVS-PRIVACY — Privacidade

| Controlo | Módulo |
|---|---|
| MASVS-PRIVACY-1: Minimização de dados pessoais | `outras-areas/privacidade-compliance.md` |
| MASVS-PRIVACY-2: PII tratada com consent | `outras-areas/privacidade-compliance.md` |

## Níveis MASVS

- **L1 (Standard):** baseline para qualquer app. Aplicar todos os MASVS-* exceto MASVS-RESILIENCE.
- **L2 (Defense-in-Depth):** apps com dados sensíveis. Adicionar parte do MASVS-RESILIENCE.
- **MASVS-R (Resilience):** apps de alto risco (banking, health, governamental). Aplicar tudo + monitorização ativa.

## Audit checklist por nível

### L1 — toda app
- [ ] Sem secrets em código
- [ ] Storage de credenciais em Keychain/Keystore
- [ ] TLS forçado (sem cleartext)
- [ ] Permissions mínimas
- [ ] WebView config segura
- [ ] Deep links validados
- [ ] Sem PII em logs
- [ ] Dependencies sem CVEs

### L2 — apps com dados sensíveis (acrescentar)
- [ ] Cert pinning
- [ ] Biometric prompt para operações sensíveis
- [ ] Backups configurados (Android: `android:allowBackup="false"` para dados sensíveis)
- [ ] Code obfuscation básico (ProGuard/R8 / Bitcode)
- [ ] Logout invalida tokens server-side
- [ ] Detecção básica jailbreak/root (avisar utilizador)

### MASVS-R — apps de alto risco (acrescentar)
- [ ] Anti-Frida / runtime hooks detection
- [ ] Anti-debug (PT_DENY_ATTACH no iOS, similar Android)
- [ ] App integrity check (re-validar signature em runtime)
- [ ] Device attestation (Play Integrity, App Attest)
- [ ] Servidor recusa requests de devices não-attested
- [ ] Encrypted assets (não JSON plain)
- [ ] String encryption (DexGuard, iXGuard)
- [ ] Tamper detection com kill switch
