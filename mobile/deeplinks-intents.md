# Deep Links e Intents — Segurança

> Deep links são entry points **externos**. App maliciosa, link em SMS/email, página web — tudo pode trigger. Validação obrigatória.

## URL Schemes vs Universal Links / App Links

| | URL Scheme | Universal Links (iOS) / App Links (Android) |
|---|---|---|
| **Verificação** | Nenhuma — qualquer app regista | Verified via apple-app-site-association / assetlinks.json |
| **Hijacking** | Possível (last installed wins) | Impossível |
| **HTTPS** | Não obrigatório | Obrigatório |
| **Recomendação** | Migrar | Usar |

## iOS — Universal Links

```xml
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
      "appIDs": ["TEAMID.com.meusite.app"],
      "components": [
        {"/": "/auth/*"},
        {"/": "/share/*"},
        {"/": "/profile/*"}
      ]
    }]
  }
}
```

## Android — App Links

```xml
<!-- AndroidManifest.xml -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="meusite.tld" android:pathPrefix="/auth" />
</intent-filter>
```

```json
// https://meusite.tld/.well-known/assetlinks.json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.meusite.app",
    "sha256_cert_fingerprints": ["SHA256:XX:YY:..."]
  }
}]
```

## Validação obrigatória ao receber link

```swift
// iOS
func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return false }

    // Validar host
    guard url.host == "meusite.tld" || url.host == "www.meusite.tld" else { return false }
    guard url.scheme == "https" else { return false }

    // Validar path + parametros
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    guard let path = components?.path else { return false }

    switch path {
    case let p where p.hasPrefix("/auth/reset"):
        guard let token = components?.queryItems?.first(where: { $0.name == "token" })?.value,
              token.count == 64 else { return false }
        // Reset password — exigir biometric antes
        promptBiometricThenReset(token: token)
    case let p where p.hasPrefix("/share/"):
        // ...
    default:
        return false
    }
    return true
}
```

```kotlin
// Android
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    val data = intent.data ?: return

    // Validar host
    if (data.host !in listOf("meusite.tld", "www.meusite.tld")) return
    if (data.scheme != "https") return

    when {
        data.path?.startsWith("/auth/reset") == true -> {
            val token = data.getQueryParameter("token")
            if (token == null || token.length != 64) return
            promptBiometricThenReset(token)
        }
        data.path?.startsWith("/share") == true -> {
            // ...
        }
    }
}
```

## Intents (Android) — IPC

### Implicit vs Explicit

```kotlin
// Implicit — sistema escolhe quem responde
val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
startActivity(intent)
// Atacante pode interceptar se regista handler

// Explicit — sabes para onde vai
val intent = Intent(this, TargetActivity::class.java)
intent.putExtra("data", value)
startActivity(intent)
```

### PendingIntent

```kotlin
// API 31+: FLAG_IMMUTABLE ou FLAG_MUTABLE obrigatório
val pi = PendingIntent.getActivity(
    context, 0, intent,
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE  // imutável por default
)
```

### Receiver com permission

```xml
<receiver
    android:name=".MyReceiver"
    android:exported="true"
    android:permission="com.app.PRIVATE_BROADCAST">
    <intent-filter>
        <action android:name="com.app.MY_ACTION" />
    </intent-filter>
</receiver>
```

## Ações sensíveis via deep link

Deep link a executar ação destrutiva ou financeira **deve sempre confirmar**:

```kotlin
when (action) {
    "delete_account", "transfer_money", "change_password" -> {
        showConfirmDialog {
            requireBiometric { 
                // executar ação
            }
        }
    }
}
```

## Common antipatterns

### URL Scheme com action sensitive direta
```
myapp://delete_account
```
Qualquer app/website com link `myapp://...` triggera.

### Sem validação de path/params
- Atacante envia path inesperado.

### `Intent.parseUri(input)` com input não validado
- Pode injetar flags arbitrárias.

### `BroadcastReceiver` sem `android:permission`
- Outras apps trigger sem permissão.

### `setData(Uri)` confiando no source
- Atacante envia URI maliciosa.

### `pathPrefix="/"` em App Link
- Captura tudo, incluindo paths não previstos.

### App Link não verificado
- `android:autoVerify="false"` → comporta-se como URL Scheme.

## Quick wins

- [ ] Migrar URL Schemes → Universal Links (iOS) / App Links (Android)
- [ ] `apple-app-site-association` / `assetlinks.json` configurados
- [ ] `autoVerify="true"` em App Links
- [ ] Validação obrigatória de host, scheme, path, query params em deep link handlers
- [ ] Ações sensíveis via deep link → confirmação + biometric
- [ ] Intents explícitos sempre que possível
- [ ] `PendingIntent.FLAG_IMMUTABLE` (API 31+ obriga)
- [ ] BroadcastReceivers com `android:permission` se aplicável
- [ ] `android:exported` declarado explicitamente em todos os components (API 31+ obriga)
- [ ] `pathPrefix` específico, não `/`
- [ ] Ignore links com fragments suspeitos (`#javascript:`)
