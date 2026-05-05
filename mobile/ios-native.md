# iOS Native (Swift / Objective-C) — Segurança

> Cobre Swift idiomático e padrões Apple. Para padrões cross-platform da linguagem ver `linguagens/swift.md`.

## App Transport Security (ATS)

```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <!-- BAD: <true/> permite HTTP -->

    <!-- Exceções, se inevitáveis (red flag) -->
    <key>NSExceptionDomains</key>
    <dict>
        <key>legacy-api.tld</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <false/>
        </dict>
    </dict>
</dict>
```

## Permissions e privacy strings

Cada permission requer string `Info.plist` clara.

```xml
<key>NSCameraUsageDescription</key>
<string>Para tirar fotos de perfil</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Para escolheres avatar</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Para encontrares lojas próximas</string>

<key>NSContactsUsageDescription</key>
<string>Para sugerir amigos a partir dos teus contactos</string>
```

## Keychain — storage seguro

```swift
import Security

func saveToKeychain(_ data: Data, account: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: Bundle.main.bundleIdentifier!,
        kSecAttrAccount as String: account,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        kSecValueData as String: data,
    ]
    SecItemDelete(query as CFDictionary)  // remove se existe
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.saveFailed }
}

// Para máxima segurança (biometric obrigatório)
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.biometryCurrentSet, .privateKeyUsage],
    nil
)!
```

## Configurações de Keychain

| Accessibility | Quando dispnível |
|---|---|
| `kSecAttrAccessibleWhenUnlocked` | Após primeiro unlock; persiste em backups |
| `kSecAttrAccessibleAfterFirstUnlock` | Após primeiro unlock (boot); persiste em backups |
| `kSecAttrAccessibleAlways` (deprecated) | Sempre; **não usar** |
| `*ThisDeviceOnly` | Não sai do device em backups |

> Para tokens de auth: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

## URL Schemes vs Universal Links

```xml
<!-- BAD — URL Scheme (qualquer app pode invocar) -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>myapp</string></array>
    </dict>
</array>
```

URL Scheme `myapp://` pode ser invocado por **qualquer** app (incluindo malicious). Se app maliciosa também regista `myapp://`, last-installed wins.

```xml
<!-- GOOD — Universal Links (verifiable via apple-app-site-association) -->
<!-- Entitlements -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:meusite.tld</string>
</array>
```

```json
// https://meusite.tld/.well-known/apple-app-site-association
{
  "applinks": {
    "details": [{
      "appIDs": ["TEAMID.bundle.identifier"],
      "components": [{"/": "/auth/*"}, {"/": "/share/*"}]
    }]
  }
}
```

## WebView (`WKWebView`)

```swift
let config = WKWebViewConfiguration()
let prefs = WKWebpagePreferences()
prefs.allowsContentJavaScript = false  // se não precisas de JS
config.defaultWebpagePreferences = prefs

config.preferences.javaScriptCanOpenWindowsAutomatically = false
config.allowsAirPlayForMediaPlayback = false
config.allowsInlineMediaPlayback = false

// User Content Controller — JS interop
let userController = WKUserContentController()
config.userContentController = userController
// Validar TUDO em script messages
```

```swift
// Carregar URL com validação
guard let host = url.host,
      ALLOWED_HOSTS.contains(host),
      url.scheme == "https" else {
    return
}
webView.load(URLRequest(url: url))
```

## Pasteboard

```swift
// BAD — JWT ou senha no pasteboard sem expirar
UIPasteboard.general.string = sensitiveData

// GOOD — pasteboard local com expiry
UIPasteboard.general.setItems(
    [["public.utf8-plain-text": sensitiveData]],
    options: [
        .expirationDate: Date().addingTimeInterval(60),
        .localOnly: true,
    ]
)
```

## Screenshots em background

```swift
// Esconder dados sensíveis quando app vai para background
override func sceneWillResignActive(_ scene: UIScene) {
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    blurView.frame = window?.bounds ?? .zero
    blurView.tag = 9999
    window?.addSubview(blurView)
}

override func sceneDidBecomeActive(_ scene: UIScene) {
    window?.viewWithTag(9999)?.removeFromSuperview()
}
```

## Logs / `print` em produção

```swift
import os.log

let log = OSLog(subsystem: "com.app", category: "auth")

// BAD — sempre logado, com qualquer dado
print("User token: \(token)")

// GOOD — privacy markers
os_log(.info, log: log, "User logged in: %{public}@ token: %{private}@",
       userId, token)
```

## URLSession — cert pinning

Coberto em `comunicacao-rede.md`.

## Common antipatterns

### `UserDefaults` para tokens
- Plain text no disco. Usar Keychain.

### `print` com PII em produção
- Logcat / Console acessível em debug builds connected.

### `WKWebView.evaluateJavaScript(input)`
- XSS / RCE através de JS interop.

### Hardcoded API keys em Swift code
- `let apiKey = "sk_live_xxx"` — visível em `strings binary | grep`.

### `NSAllowsArbitraryLoads` em produção
- Aceita HTTP, qualquer cert.

### URL Scheme handler sem validação
```swift
// BAD
func application(_ app: UIApplication, open url: URL, ...) -> Bool {
    if url.host == "delete-account" { deleteAccount() }
    return true
}

// GOOD
// Confirmar com user, exigir biometric, validar source app
```

### `LocalAuthentication` sem fallback
- Se device não tem biometric, app pode crash. Sempre handle.

### Backup no iCloud com dados sensíveis
- `kSecAttrAccessibleWhenUnlocked` é incluído no iCloud Keychain backup.
- Para sensitive: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

## Quick wins

- [ ] Swift 5.9+, iOS deployment target 15+
- [ ] ATS ativo (`NSAllowsArbitraryLoads` = false)
- [ ] Privacy strings em todas as permissions
- [ ] Migrar URL Schemes → Universal Links
- [ ] Tokens em Keychain com `*ThisDeviceOnly`
- [ ] Biometric (LocalAuthentication) para operações sensíveis
- [ ] WebView com JS desativado se não necessário
- [ ] WebView script handlers com validação strict
- [ ] Cert pinning para APIs críticas
- [ ] Pasteboard com expiry para PII
- [ ] Background screen mascarado (blur view)
- [ ] `os_log` com privacy markers (`%{private}@`)
- [ ] Sem `print` com PII
- [ ] Sem secrets em código (usar backend ou App Attest)
- [ ] App Attest / DeviceCheck para verificar genuinidade
- [ ] Jailbreak detection se app de alto risco
- [ ] Detect debugger (`PT_DENY_ATTACH` ou syscall check)
