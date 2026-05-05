# Android Native (Kotlin / Java) — Segurança

> Cross-platform language patterns em `linguagens/kotlin.md`. Aqui o foco é Android-specific.

## AndroidManifest — pontos críticos

```xml
<!-- Permissions: solicitar APENAS as necessárias -->
<uses-permission android:name="android.permission.INTERNET" />
<!-- BAD: <uses-permission android:name="android.permission.READ_PHONE_STATE" /> sem necessidade -->

<application
    android:allowBackup="false"            <!-- bloqueia adb backup com PII -->
    android:fullBackupContent="@xml/backup_rules"  <!-- ou allowlist -->
    android:dataExtractionRules="@xml/data_extraction_rules"  <!-- API 31+ -->
    android:debuggable="false"             <!-- false em release; android:debuggable nunca em manifest -->
    android:networkSecurityConfig="@xml/network_security_config"
    android:usesCleartextTraffic="false">

    <!-- Components: exported deve ser explícito (API 31+ obriga) -->
    <activity
        android:name=".MainActivity"
        android:exported="true">
        <intent-filter>
            <action android:name="android.intent.action.MAIN" />
        </intent-filter>
    </activity>

    <!-- Internal activities: exported false -->
    <activity android:name=".InternalActivity" android:exported="false" />

    <!-- ContentProvider: exported false a não ser que seja IPC público -->
    <provider
        android:name=".MyProvider"
        android:authorities="com.app.provider"
        android:exported="false" />
</application>
```

## Network Security Config

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
            <!-- NÃO incluir 'user' em prod (= aceita certs do user store, MITM trivial) -->
        </trust-anchors>
    </base-config>

    <!-- Cert pinning -->
    <domain-config>
        <domain includeSubdomains="true">api.meusite.tld</domain>
        <pin-set expiration="2026-01-01">
            <pin digest="SHA-256">base64SHA256OfPublicKey==</pin>
            <pin digest="SHA-256">base64SHA256OfBackupKey==</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

## Storage — EncryptedSharedPreferences

```kotlin
val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val sharedPrefs = EncryptedSharedPreferences.create(
    context,
    "secret_prefs",
    masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)

sharedPrefs.edit().putString("auth_token", token).apply()
```

## Storage — EncryptedFile

```kotlin
val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val encryptedFile = EncryptedFile.Builder(
    context,
    File(filesDir, "secret.txt"),
    masterKey,
    EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB
).build()

encryptedFile.openFileOutput().use { it.write(data) }
```

## Android Keystore — chaves hardware-backed

```kotlin
val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
val spec = KeyGenParameterSpec.Builder("my_key",
    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
    .setUserAuthenticationRequired(true)  // exige biometric/PIN
    .setUserAuthenticationParameters(60, KeyProperties.AUTH_BIOMETRIC_STRONG)
    .build()
keyGenerator.init(spec)
keyGenerator.generateKey()
```

## Biometric

```kotlin
import androidx.biometric.BiometricPrompt

val executor = ContextCompat.getMainExecutor(this)
val biometricPrompt = BiometricPrompt(this, executor,
    object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
            // unlock
        }
    })

val promptInfo = BiometricPrompt.PromptInfo.Builder()
    .setTitle("Authenticate")
    .setSubtitle("Required to access your account")
    .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
    .setNegativeButtonText("Cancel")
    .build()

biometricPrompt.authenticate(promptInfo)
```

## WebView

Coberto em `webview.md`. Resumo:
```kotlin
webView.settings.apply {
    javaScriptEnabled = false  // se não necessário
    allowFileAccess = false
    allowFileAccessFromFileURLs = false  // deprecated
    allowUniversalAccessFromFileURLs = false
    allowContentAccess = false
    mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
}
```

## Intents

```kotlin
// Implicit intent — pode ir para qualquer app
val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
startActivity(intent)  // user escolhe handler

// Explicit intent — sabes para onde vai
val intent = Intent(this, TargetActivity::class.java)
intent.putExtra("data", value)
startActivity(intent)

// Intent com sensitive data — usar PendingIntent.FLAG_IMMUTABLE
val pi = PendingIntent.getActivity(context, 0, intent,
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
```

## Deep links e App Links

```xml
<!-- App Link (verified) -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="meusite.tld" />
</intent-filter>
```

```json
// Hosted at https://meusite.tld/.well-known/assetlinks.json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.meusite.app",
    "sha256_cert_fingerprints": ["XX:YY:..."]
  }
}]
```

## Logging — sem PII

```kotlin
// BAD
Log.d("Auth", "Token: $token")  // logcat acessível em debug

// GOOD — apenas em debug
if (BuildConfig.DEBUG) {
    Log.d("Auth", "Auth flow started for ${user.email.take(3)}***")
}
```

## ProGuard / R8 — obfuscation

```gradle
// build.gradle (app)
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

## Common antipatterns

### `android:allowBackup="true"` (default) com PII
- `adb backup` extrai dados do app sem root.

### `android:debuggable="true"` em release
- Permite anexar debugger; usar `BuildConfig.DEBUG`.

### `usesCleartextTraffic="true"`
- Permite HTTP. Default em API 28+ é false.

### `WebView.addJavascriptInterface` em API < 17
- RCE via reflection. API 17+ requer `@JavascriptInterface`.

### `BroadcastReceiver` sem permission
- Outras apps podem trigger.

### Implicit intents com extras sensíveis
- Atacante pode interceptar.

### `getExternalFilesDir()` para dados sensíveis
- World-readable em algumas versões. Usar `filesDir` (internal).

### Hardcoded keys em código Java/Kotlin
- jadx revela em segundos.

### Usar `MODE_WORLD_READABLE` / `MODE_WORLD_WRITABLE`
- Deprecated. Lança exception em API 24+.

## Quick wins

- [ ] minSdkVersion 26+ (preferência)
- [ ] targetSdkVersion no latest
- [ ] `android:allowBackup="false"` ou backup rules excludem PII
- [ ] `android:debuggable="false"` em release
- [ ] `usesCleartextTraffic="false"`
- [ ] `network_security_config.xml` com cert pinning
- [ ] EncryptedSharedPreferences ou Keystore para tokens
- [ ] Biometric prompt para operações sensíveis
- [ ] WebView com `javaScriptEnabled=false` se possível
- [ ] WebView com mixed content disabled
- [ ] App Links (com `autoVerify="true"`) em vez de URL Schemes
- [ ] Components com `android:exported` explícito
- [ ] Sem PII em `Log.*` (mesmo debug)
- [ ] ProGuard/R8 ativo em release
- [ ] Sem secrets em código
- [ ] `PendingIntent.FLAG_IMMUTABLE` em PendingIntents
- [ ] Play Integrity API para verificar device
- [ ] Detection de root + ação adequada (em apps de alto risco)
- [ ] `dependency-check` ou similar sem CVEs em libs
