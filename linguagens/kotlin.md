# Kotlin — Cartão de Segurança

> Kotlin partilha JVM com Java. Tudo em `java.md` aplica-se. Este cartão cobre o **delta Kotlin** + uso em Android.

## Idiomas inseguros específicos de Kotlin

### `!!` (not-null assertion) em handlers
```kotlin
// BAD — !! lança NullPointerException
val user = repo.findById(id)!!  // se null → crash

// GOOD
val user = repo.findById(id) ?: throw NotFoundException()
```

### `lateinit var` sem inicialização
```kotlin
// BAD
lateinit var apiKey: String
fun call() { client.use(apiKey) }  // UninitializedPropertyAccessException

// GOOD — `by lazy` ou inicialização garantida
private val apiKey: String by lazy {
    System.getenv("API_KEY") ?: error("API_KEY missing")
}
```

### `String.format` com input
```kotlin
// BAD
String.format(userInput, args)

// GOOD — pattern hardcoded
String.format("User: %s", userInput)
```

### Coroutines sem timeout / cancelamento
```kotlin
// BAD
GlobalScope.launch {
    longTask()
}

// GOOD
viewModelScope.launch {
    withTimeout(10_000) {
        longTask()
    }
}
```

### Reflection com input
```kotlin
// BAD
val klass = Class.forName(userInput)
val instance = klass.getDeclaredConstructor().newInstance()

// GOOD — sealed class ou enum
sealed class Action { object A : Action(); object B : Action() }
when (val action = parseAction(userInput)) {
    Action.A -> ...
    Action.B -> ...
}
```

## Android-specific

### `WebView` settings
```kotlin
// BAD — WebView aceita JavaScript de qualquer URL + addJavascriptInterface
val webView = WebView(context)
webView.settings.javaScriptEnabled = true
webView.addJavascriptInterface(MyBridge(), "Android")
webView.loadUrl(userControlledUrl)

// GOOD
webView.settings.javaScriptEnabled = false  // se não precisas
webView.settings.allowFileAccess = false
webView.settings.allowFileAccessFromFileURLs = false  // deprecated mas verificar
webView.settings.allowUniversalAccessFromFileURLs = false
webView.settings.allowContentAccess = false
webView.settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW

// Validar URL
val safeUrl = userControlledUrl.takeIf {
    it.startsWith("https://meusite.tld/")
} ?: return
webView.loadUrl(safeUrl)
```

### `Intent` extras sem validação
```kotlin
// BAD — confia no que vem
val userId = intent.getStringExtra("user_id")!!.toLong()
loadUser(userId)

// GOOD — validar e fallback
val userId = intent.getStringExtra("user_id")?.toLongOrNull() ?: return
if (userId !in validUserIds) return
loadUser(userId)
```

### Deep links sem auth check
```kotlin
// BAD
override fun onNewIntent(intent: Intent) {
    val action = intent.data?.getQueryParameter("action")
    when (action) {
        "delete_account" -> deleteAccount()  // sem confirmar quem chama
    }
}

// GOOD
override fun onNewIntent(intent: Intent) {
    val action = intent.data?.getQueryParameter("action")
    when (action) {
        "delete_account" -> {
            requireUserConfirmation()
            requireBiometric()
            deleteAccount()
        }
    }
}
```

### `SharedPreferences` para dados sensíveis
```kotlin
// BAD
val prefs = getSharedPreferences("auth", Context.MODE_PRIVATE)
prefs.edit().putString("token", jwt).apply()  // plain text no disco

// GOOD — EncryptedSharedPreferences
val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val prefs = EncryptedSharedPreferences.create(
    context, "auth", masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)
```

### `MODE_WORLD_READABLE`/`MODE_WORLD_WRITABLE`
- Deprecated em API 17+. Lançam `SecurityException` em API 24+.
- Usar `MODE_PRIVATE` sempre.

### Logging com PII
```kotlin
// BAD
Log.d("Auth", "Token: $token")  // logs persistem em logcat

// GOOD — só em debug builds, e mesmo assim sem PII
if (BuildConfig.DEBUG) Log.d("Auth", "Auth call: ${token.take(4)}***")
```

### `Cipher.getInstance("AES")`
```kotlin
// BAD — default mode varia (ECB em alguns providers)
val cipher = Cipher.getInstance("AES")

// GOOD — explícito
val cipher = Cipher.getInstance("AES/GCM/NoPadding")
```

### `ContentProvider` exposto
```xml
<!-- BAD -->
<provider android:exported="true" android:authorities="..." />

<!-- GOOD — só se necessário, com permissões -->
<provider
    android:exported="true"
    android:permission="com.app.PERM_USE_PROVIDER"
    android:authorities="..." />
```

### Network Security Config
```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    <domain-config>
        <domain includeSubdomains="true">api.meusite.tld</domain>
        <pin-set>
            <pin digest="SHA-256">base64==</pin>  <!-- cert pinning -->
        </pin-set>
    </domain-config>
</network-security-config>
```

## Helpers seguros

| Necessidade | Use |
|---|---|
| Random | `SecureRandom` (java.security) |
| Storage cifrado | `EncryptedSharedPreferences`, `EncryptedFile` (androidx.security) |
| Keystore | `KeyStore.getInstance("AndroidKeyStore")` |
| Biometria | `BiometricPrompt` (androidx.biometric) |
| Network | OkHttp/Retrofit com cert pinning |
| HTTP | Retrofit com `CertificatePinner` |

## Pitfalls específicos

### Dynamic code loading
- `DexClassLoader`, `PathClassLoader` com APK externo → RCE.
- Auditar qualquer carregamento de código fora do APK assinado.

### `runtime.exec` em Android
- Usado para shell utils → command injection clássico.
- Maioria das apps não precisa.

### `Settings.Global` / `Settings.Secure`
- Algumas keys exigem permissões especiais; outras revelam info do device.

## Quick wins

- [ ] Kotlin 1.9+ / Android API 24+ minimum (preferir API 26+ para `EncryptedSharedPreferences`)
- [ ] Sem `!!` em código de produção — usar `?:` ou `requireNotNull`
- [ ] Coroutines com timeout
- [ ] WebView com `javaScriptEnabled = false` se não necessário
- [ ] `addJavascriptInterface` só com `@JavascriptInterface` annotation explícito (API 17+)
- [ ] Deep links com auth check / confirmação
- [ ] `EncryptedSharedPreferences` para tokens
- [ ] `network_security_config.xml` com `cleartextTrafficPermitted=false`
- [ ] Cert pinning para APIs críticas
- [ ] `ProGuard`/`R8` ativo (ofuscação básica)
- [ ] `Cipher.getInstance` com modo explícito (`AES/GCM/NoPadding`)
- [ ] Sem PII em `Log.*` mesmo em debug
- [ ] `android:exported` declarado explicitamente em `Activity`/`Service`/`Receiver`/`Provider` (API 31+ obriga)
