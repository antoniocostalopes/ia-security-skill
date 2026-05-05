# Mindset — Segurança Mobile

> Mobile é diferente. Web auditas o servidor. Mobile auditas o cliente — e o cliente está nas mãos do atacante.

## As 4 verdades inconvenientes

### 1. App é executada em device controlado pelo atacante
O utilizador (potencialmente atacante) tem:
- Acesso root/jailbreak ao device
- Capacidade de descompilar a app (jadx, Hopper, Ghidra)
- Capacidade de hookar funções (Frida)
- Capacidade de modificar tráfego (Burp + cert pinning bypass)
- Capacidade de modificar storage local
- Capacidade de modificar a app antes de a redistribuir

### 2. Tudo no APK/IPA é público
- Strings em código → `strings app.apk`
- Constantes do código → `jadx app.apk`
- API endpoints → `grep -r "https://" app/`
- Chaves "ofuscadas" → não funcionam contra atacante motivado

> **Regra:** se metes uma chave de API no código, considera-a comprometida no momento do release.

### 3. Storage local tem limites
- **Keychain (iOS) / KeyStore (Android)** — bom, mas:
  - Em devices jailbroken, dumpable
  - Em devices roubados, dumpable se sem auth biometrica obrigatória
  - Sync cross-device pode expor (iCloud Keychain)
- **EncryptedSharedPreferences (Android)** — bom, mas chave derivada do device
- **localStorage / AsyncStorage (web/RN)** — visível por XSS / file system

### 4. TLS não chega
- App pode aceitar **qualquer cert** se mal configurada (`NSAllowsArbitraryLoads`, `cleartextTrafficPermitted`)
- MITM com cert válido é trivial em redes hostis
- **Cert pinning** é defesa em profundidade real

## As 4 perguntas para mobile

Para cada feature, pergunta:

1. **O que acontece se a app for descompilada?** (secrets, endpoints, lógica visível)
2. **O que acontece se o device estiver jailbroken/rooted?** (storage acessível, hooks possíveis)
3. **O que acontece se o tráfego for intercepted?** (cert pinning, request signing)
4. **O que acontece se o user instalar uma app maliciosa lateral?** (deeplinks, IPC, clipboard, screenshots)

Se a resposta a qualquer destas for "fica feito", tens problema.

## Diferenças vs Web

| Aspeto | Web | Mobile |
|---|---|---|
| **Cliente** | Browser (semi-confiável) | App (totalmente hostil) |
| **Secrets em código** | Server-side OK | Tudo público |
| **Auth tokens** | Cookie HttpOnly + Secure | Keychain / Keystore |
| **Rede** | TLS chega | TLS + pinning |
| **Storage** | Server-side | Local + remoto |
| **Modelo de update** | Push imediato | Store review (1+ dias) |
| **Reverse engineering** | DevTools (limitado) | jadx / Hopper / Frida |
| **Anti-tampering** | Headers (limitado) | Code signing + integrity checks |

## "Defense in depth" mobile

Cada camada falha mais cedo ou mais tarde. Combina:

1. **Backend strong** — assume cliente compromisso, valida tudo server-side
2. **Cert pinning** — torna MITM mais difícil
3. **Storage cifrado** — Keychain/Keystore com biometric
4. **Anti-tampering** — detect jailbreak/root, integrity checks
5. **Code obfuscation** — torna RE mais demorado
6. **Run-time integrity** — DexGuard, iXGuard, RASP solutions
7. **Device attestation** — Play Integrity, App Attest
8. **Logging / monitoring server-side** — anomalies indicam abuse

## Trade-offs honestos

- **Cert pinning** quebra com renovação de cert. Plano: pin múltiplos certs (cur + next) com expiry.
- **Anti-tampering** pode bloquear users legítimos com root para outros fins.
- **Obfuscação** dificulta debug em produção.
- **Biometric obrigatório** exclui devices sem hardware capability.

> O equilíbrio depende do risco do app. Banking app: máximo. App de notas: mínimo.

## Lema mobile

> *"O cliente é hostil. O backend é a verdade. Cada camada extra de defesa atrasa, não impede — e atrasar é tudo o que precisas."*
