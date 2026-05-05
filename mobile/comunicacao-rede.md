# Comunicação de Rede Mobile — TLS, Pinning, ATS, NSC

## TLS — não é opcional

Toda comunicação de app móvel deve ser **HTTPS-only**. HTTP é MITM trivial em redes Wi-Fi públicas.

### iOS — App Transport Security (ATS)

```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <!-- Bloqueia HTTP por default desde iOS 9 -->

    <key>NSAllowsArbitraryLoadsForMedia</key>
    <false/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <false/>

    <!-- Exceções específicas (red flag se necessárias) -->
    <key>NSExceptionDomains</key>
    <dict>
        <key>legacy-api.tld</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.2</string>
        </dict>
    </dict>
</dict>
```

### Android — Network Security Config (NSC)

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
            <!-- NÃO 'user' em prod (= aceita certs do user store, MITM trivial) -->
        </trust-anchors>
    </base-config>

    <!-- Exceções para hosts específicos -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.meusite.tld</domain>
    </domain-config>

    <!-- Debug — só em debug builds -->
    <debug-overrides>
        <trust-anchors>
            <certificates src="user" />
        </trust-anchors>
    </debug-overrides>
</network-security-config>
```

```xml
<!-- AndroidManifest.xml -->
<application
    android:networkSecurityConfig="@xml/network_security_config"
    android:usesCleartextTraffic="false">
```

## Cert pinning — defesa contra MITM com cert válido

Atacante com cert válido (CA comprometida, ou user instalou CA malicioso) faz MITM.
Pinning compara o cert recebido com lista hardcoded.

### iOS — `URLSession` delegate

```swift
class PinnedSession: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let cert = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let serverCertData = SecCertificateCopyData(cert) as Data
        let pinnedCertData = NSDataAsset(name: "PinnedCert")?.data

        if serverCertData == pinnedCertData {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
```

### iOS — TrustKit (mais robusto)

```swift
let trustKitConfig = [
    kTSKPinnedDomains: [
        "api.meusite.tld": [
            kTSKPublicKeyHashes: [
                "BASE64_PUBKEY_PIN_1",
                "BASE64_BACKUP_PIN_2",
            ],
            kTSKEnforcePinning: true,
            kTSKIncludeSubdomains: true,
        ],
    ]
] as [String: Any]

TrustKit.initSharedInstance(withConfiguration: trustKitConfig)
```

### Android — via Network Security Config

```xml
<network-security-config>
    <domain-config>
        <domain includeSubdomains="true">api.meusite.tld</domain>
        <pin-set expiration="2026-12-31">
            <pin digest="SHA-256">base64SHA256OfPublicKey==</pin>
            <pin digest="SHA-256">base64SHA256OfBackupKey==</pin>
        </pin-set>
        <trustkit-config enforcePinning="true" />
    </domain-config>
</network-security-config>
```

### Android — OkHttp pinning

```kotlin
val pinner = CertificatePinner.Builder()
    .add("api.meusite.tld", "sha256/base64==")
    .add("api.meusite.tld", "sha256/backupBase64==")
    .build()

val client = OkHttpClient.Builder()
    .certificatePinner(pinner)
    .build()
```

## Boas práticas de pinning

1. **Pinear public key**, não cert completo. Cert renovado mantém public key.
2. **Pin múltiplos** — current + backup. Plano para rotação.
3. **Expiry policy**. Pin sem expiry pode tornar app inutilizável.
4. **Backend rotation plan**. Se backend rota chave, app precisa de update antes.
5. **Failure mode** — falhar gracefully (avisar user, não crash).

## Common antipatterns

### `setHostnameVerifier(ALLOW_ALL_HOSTNAME_VERIFIER)`
- Aceita qualquer hostname. MITM trivial.

### `TrustManager` que aceita tudo
```java
// BAD
TrustManager tm = new X509TrustManager() {
    public void checkClientTrusted(X509Certificate[] chain, String authType) {}
    public void checkServerTrusted(X509Certificate[] chain, String authType) {}  // não throw = aceita
    public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
};
```

### `cleartextTrafficPermitted="true"` em prod
- Aceita HTTP.

### `<trust-anchors><certificates src="user" /></trust-anchors>` em prod
- Aceita CAs instalados pelo user (Charles, Burp, etc.) → MITM dev = MITM prod.

### Pin com expiry vencido sem fallback
- App quebra para todos os users.

### Sem backup pin
- Renovação de chave força emergency app update.

### `NSAllowsArbitraryLoads = true` "for development"
- Frequentemente esquecido em release.

## TLS — versões e cipher suites

- **TLS 1.2 mínimo**, TLS 1.3 preferida.
- Desativar SSL 3.0, TLS 1.0, TLS 1.1.
- Cipher suites com forward secrecy (ECDHE).

```xml
<!-- iOS NSExceptionMinimumTLSVersion -->
<string>TLSv1.2</string>
```

```xml
<!-- Android NSC -->
<base-config>
    <trust-anchors>...</trust-anchors>
    <!-- Modern cipher suites only -->
</base-config>
```

## Quick wins

- [ ] HTTPS-only — `NSAllowsArbitraryLoads=false`, `cleartextTrafficPermitted=false`
- [ ] TLS 1.2+ minimum
- [ ] Cert pinning em APIs críticas (auth, payment, PII)
- [ ] Pin **public key**, não cert
- [ ] Múltiplos pins (current + backup)
- [ ] Pinning com expiry policy + plano de rotação
- [ ] User-installed CAs **bloqueados** em release Android
- [ ] HTTP client com timeouts (connect + read)
- [ ] Hostname verification ON
- [ ] Failure mode: avisar user em pinning failure (não crash)
- [ ] Análise periódica: corre Burp contra app → tudo deve falhar
