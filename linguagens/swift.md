# Swift — Cartão de Segurança

> Swift é forte em type safety. As vulnerabilidades vêm de iOS APIs específicas e idiomas como force unwrap.

## Idiomas inseguros

### Force unwrap (`!`)
```swift
// BAD
let user = users.first!         // crash se vazio
let url = URL(string: input)!   // crash se inválido

// GOOD
guard let user = users.first else { throw Error.empty }
guard let url = URL(string: input) else { throw Error.invalidURL }
```

### Force try (`try!`)
```swift
// BAD
let data = try! Data(contentsOf: url)

// GOOD
do {
    let data = try Data(contentsOf: url)
} catch {
    handle(error)
}
```

### `as!` (force cast)
```swift
// BAD
let user = obj as! User  // crash em runtime se tipo errado

// GOOD
guard let user = obj as? User else { return }
```

### `String` interpolation em logs
```swift
// BAD — token completo no log
NSLog("User: \(user) Token: \(token)")

// GOOD — redact sensível
NSLog("User login attempt for \(user.email.prefix(3))***")
```

### `String.init(contentsOf:)` com URL não validada
- Pode bloquear thread se URL externo lento (sem timeout).
- Usar `URLSession` async com timeouts.

### Comparação de tokens
```swift
// BAD
if expected == received { ... }  // não constant-time

// GOOD — usar CommonCrypto
import CommonCrypto
func secureCompare(_ a: Data, _ b: Data) -> Bool {
    guard a.count == b.count else { return false }
    var result: UInt8 = 0
    for i in 0..<a.count {
        result |= a[i] ^ b[i]
    }
    return result == 0
}
```

### Random
```swift
// BAD
Int.random(in: 0...Int.max)  // não criptograficamente seguro

// GOOD
import CryptoKit
var bytes = [UInt8](repeating: 0, count: 32)
let status = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
guard status == errSecSuccess else { fatalError() }
let token = Data(bytes).base64EncodedString()
```

## iOS-specific

### Keychain para secrets
```swift
// BAD — UserDefaults para token
UserDefaults.standard.set(jwt, forKey: "auth_token")

// GOOD — Keychain
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "auth_token",
    kSecValueData as String: jwt.data(using: .utf8)!,
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
]
SecItemAdd(query as CFDictionary, nil)
```

### App Transport Security (ATS)
```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <!-- BAD: <true/> permite HTTP -->
    <key>NSExceptionDomains</key>
    <dict>
        <!-- exceções específicas justificadas, não wildcard -->
    </dict>
</dict>
```

### `WKWebView` settings
```swift
// BAD
let webView = WKWebView()
webView.load(URLRequest(url: userURL))  // sem validação

// GOOD
let config = WKWebViewConfiguration()
let prefs = WKPreferences()
prefs.javaScriptCanOpenWindowsAutomatically = false
config.preferences = prefs
config.allowsAirPlayForMediaPlayback = false

// Validar URL
guard let host = userURL.host, ALLOWED_HOSTS.contains(host) else { return }
guard userURL.scheme == "https" else { return }
let webView = WKWebView(frame: .zero, configuration: config)
webView.load(URLRequest(url: userURL))
```

### `WKScriptMessageHandler` exposto
```swift
// BAD — bridge JS → Swift sem validação
class Handler: NSObject, WKScriptMessageHandler {
    func userContentController(_ uc: WKUserContentController, didReceive msg: WKScriptMessage) {
        let body = msg.body as! [String: Any]  // confia
        execute(body["command"] as! String)    // RCE potencial
    }
}

// GOOD — validar tudo
guard let body = msg.body as? [String: Any],
      let command = body["command"] as? String,
      ALLOWED_COMMANDS.contains(command) else { return }
```

### URL Schemes (Custom URL handlers)
```swift
// BAD — qualquer app pode chamar myapp://action/delete-account
func application(_ app: UIApplication, open url: URL, options: [...]: Any]) -> Bool {
    let action = url.host
    if action == "delete-account" { deleteAccount() }
    return true
}

// GOOD — Universal Links (verificáveis) + confirmação
// Migrar de URL Schemes para Universal Links sempre que possível
```

### Biometric / LocalAuthentication
```swift
// GOOD pattern
import LocalAuthentication

let context = LAContext()
var error: NSError?
guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }

context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                       localizedReason: "Authenticate to access account") { success, error in
    if success { /* unlock */ }
}
```

### Jailbreak detection (defesa em profundidade)
```swift
// Não dependas só disto, mas combina com outros sinais
func isJailbroken() -> Bool {
    let paths = ["/Applications/Cydia.app", "/usr/sbin/sshd", "/private/var/lib/apt/"]
    for p in paths {
        if FileManager.default.fileExists(atPath: p) { return true }
    }
    if let url = URL(string: "cydia://"), UIApplication.shared.canOpenURL(url) { return true }
    return false
}
```

### Pasteboard com dados sensíveis
```swift
// BAD
UIPasteboard.general.string = jwt

// GOOD — pasteboard temporário (iOS 10+)
UIPasteboard.general.setItems([["public.utf8-plain-text": jwt]],
    options: [.expirationDate: Date().addingTimeInterval(60),
              .localOnly: true])
```

### `print` em produção
- `print` vai para console do dispositivo (visível em Xcode connectado).
- Em release, usar `os_log` com nível adequado, sem PII.

## Helpers seguros

| Necessidade | Use |
|---|---|
| Random | `SecRandomCopyBytes`, `CryptoKit.SymmetricKey` |
| Constant-time | Implementação manual ou `CommonCrypto` |
| Keychain | `Security.framework` (`SecItemAdd`) |
| Crypto | `CryptoKit` (preferir sobre `CommonCrypto`) |
| Biometrics | `LocalAuthentication` |
| Cert pinning | `URLSession` com `URLSessionDelegate.didReceive challenge` |
| Networking seguro | `URLSession` com ATS ON |
| Secure storage | `Keychain` ou `SwiftKeychainWrapper` |

## Pitfalls específicos

### `URLSession` sem cert pinning
- Em apps de alto risco (banking, health), pinning é obrigatório.
- Combinar com Keychain access groups para evitar reuse.

### `NSURLConnection` (deprecated)
- Substituir por `URLSession`.

### `UIImagePickerController` com sourceType `.savedPhotosAlbum`
- Lê metadata de fotos (incluindo GPS). Apagar EXIF antes de upload se PII.

## Quick wins

- [ ] Swift 5.9+ / iOS 15+ minimum
- [ ] Sem `!`/`try!`/`as!` em código de produção (exceções: testes)
- [ ] Tokens e secrets em **Keychain**, não UserDefaults
- [ ] ATS ativo (sem `NSAllowsArbitraryLoads`)
- [ ] Cert pinning em APIs críticas
- [ ] WebView com JS desativado se não necessário
- [ ] WebView script handlers com validação strict
- [ ] Deep links com confirmação para ações sensíveis
- [ ] Migrar URL Schemes → Universal Links
- [ ] Biometric prompt antes de operações sensíveis
- [ ] Jailbreak/integrity detection (defesa em profundidade)
- [ ] Pasteboard com expiration para PII
- [ ] `os_log` com privacy markers em logs
- [ ] App Attest / DeviceCheck para verificar genuinidade do device
