# IoT / Embedded — Segurança

> Devices físicos com firmware. Atacante pode ter acesso físico, debug interfaces (UART, JTAG), pode fazer reverse engineering do firmware. Modelo de ameaça é o mais hostil.

## OWASP IoT Top 10

1. **Weak/guessable/hardcoded passwords** — admin/admin, vazadas em batch
2. **Insecure network services** — telnet, FTP, UPnP expostos
3. **Insecure ecosystem interfaces** — APIs cloud sem auth
4. **Lack of secure update mechanism** — sem signed updates
5. **Use of insecure/outdated components** — kernels antigos, libs com CVE
6. **Insufficient privacy protection** — PII em plain text
7. **Insecure data transfer/storage** — sem encryption
8. **Lack of device management** — sem update mechanism
9. **Insecure default settings** — defaults perigosos
10. **Lack of physical hardening** — debug ports acessíveis

## Hardware attack surfaces

- **UART / Serial** — debug console acessível
- **JTAG / SWD** — debug + flash dump
- **SPI / I2C** — pode dar acesso a chips
- **USB** — DMA attacks
- **Wi-Fi / Bluetooth** — wireless attack
- **NFC** — proximity attack
- **Side-channel** — power analysis, EM emanation
- **Glitching** — voltage/clock manipulation para bypass checks

## Mitigações hardware

```
- Disable JTAG em produção (fuse blow)
- Secure Boot (signed bootloader)
- Encrypted flash (AES-XTS)
- Anti-tamper detection
- Trusted Platform Module (TPM)
- Secure Enclave / TrustZone
- Trusted Execution Environment (TEE)
- Tamper-evident enclosure
```

## Firmware security

### Secure Boot chain
```
ROM bootloader (immutable) → Bootloader 1 (signed) → Bootloader 2 (signed) → OS (signed) → App (signed)
```

Cada estágio verifica assinatura do próximo. Quebra na cadeia = boot interrompido.

### Update mechanism
```
- Signed firmware (RSA-2048+ ou ECDSA)
- Atomic A/B partitions
- Rollback prevention (anti-rollback fuses)
- Encrypted in transit
- Verified before install
- Recovery mode se update falha
```

### Code security
- C/C++ — buffer overflows são criticais (sem MMU em alguns devices)
- Stack canaries, ASLR, NX bit (se hardware suporta)
- Watchdog timers
- Memory safety: prefer Rust em projetos novos onde possível

## Network security

### Protocolos
- HTTPS para API
- MQTT com TLS (porta 8883)
- CoAP com DTLS
- LoRaWAN com session keys

### Comuns errors
- HTTP em dispositivos novos
- MQTT sem auth (anonymous allowed)
- Telnet/FTP abertos
- UPnP exposto

## Auth e identity

```
- Cada device com identidade única (não shared secrets)
- mTLS com client cert por device
- Certs provisioned em factory ou first-boot
- Rotation policy
- Revocation via CRL/OCSP
```

## Cloud backend para IoT

```
- AWS IoT Core / Azure IoT Hub / GCP IoT Core (deprecated, usar alternative)
- Per-device identity + cert
- Topic isolation (cada device só publica/subscreve em topics próprios)
- Device shadow para state offline
- Updates via OTA com signed payloads
```

## Common antipatterns

### Senhas default não alteradas
- Mirai botnet exploit clássico (admin/admin em câmaras IP).

### Debug interfaces ativas em produção
- UART/JTAG dão acesso root.

### Firmware sem signing
- Atacante flasha firmware malicioso.

### Sem rollback prevention
- Atacante volta para versão vulnerável.

### Hardcoded keys em todos os devices
- 1 device dump = todos comprometidos.

### Cloud API sem rate limit
- DDoS via botnet de devices.

### Plain text comunicação local (Wi-Fi config, etc.)
- Captura de credenciais Wi-Fi setup.

### Update mechanism sem rollback
- Bricked devices sem recovery.

## Compliance

- **EN 303 645** — ETSI baseline para consumer IoT
- **NISTIR 8259** — IoT cybersecurity baseline
- **IEC 62443** — industrial IoT
- **CRA (Cyber Resilience Act)** — EU, mandatório a partir de 2027

## Quick wins

- [ ] Sem default passwords (forçar setup com password forte no first boot)
- [ ] Disable debug interfaces em produção (UART, JTAG)
- [ ] Secure Boot habilitado
- [ ] Signed firmware updates com rollback prevention
- [ ] Per-device identity + cert (não shared secrets)
- [ ] TLS para todas as comunicações
- [ ] mTLS com cloud backend
- [ ] Auto-update enabled por default
- [ ] EOL policy clara (quanto tempo de updates)
- [ ] Encryption at rest (flash encrypted)
- [ ] Tamper detection
- [ ] Watchdog timers
- [ ] Rate limit no backend cloud
- [ ] Logging + monitoring centralizado
- [ ] Penetration testing pelo menos uma vez
- [ ] CVE monitoring para todas as deps (kernel, libs)
- [ ] Compliance com EN 303 645 (mínimo) ou NIST baseline
