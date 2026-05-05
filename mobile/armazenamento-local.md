# Armazenamento Local Mobile — Cross-Platform

> Storage de credenciais, tokens, PII e dados sensíveis. Diferentes APIs, mesmo princípio: **só system-provided secure storage**.

## Tabela comparativa

| Plataforma | Plain | Secure | Hardware-backed |
|---|---|---|---|
| **iOS** | UserDefaults, plist files | Keychain | Keychain + Secure Enclave |
| **Android** | SharedPreferences, files | EncryptedSharedPreferences | Keystore (TEE/StrongBox) |
| **React Native** | AsyncStorage | react-native-keychain, encrypted-storage | Via wrappers acima |
| **Flutter** | shared_preferences | flutter_secure_storage | Via secure_storage |
| **MAUI** | Preferences | SecureStorage | Via SecureStorage |
| **Capacitor** | Storage | Secure Storage Plugin | Via plugin |

## O que NÃO armazenar localmente (mesmo cifrado)

- Passwords em plain text (sempre derivar tokens)
- Credit card PAN (PCI-DSS proíbe)
- CVV / CVC (PCI-DSS proíbe absolutamente)
- Server-side secrets (API keys de admin)
- Private keys de utilizadores (preferir biometric-backed Keystore que nunca exporta)

## O que pode ser armazenado (com cuidado)

| Dado | Onde | Acessibilidade |
|---|---|---|
| Auth token (JWT) | Keychain/Keystore | Após unlock, this device only |
| Refresh token | Keychain/Keystore + biometric | Biometric required |
| Email do user | Encrypted prefs | Após unlock |
| Preferências UI | Plain prefs | Sempre |
| Cache de dados públicos | Plain files | Sempre |

## iOS — Keychain accessibility

```swift
// Mais restrito → mais seguro
kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly  // só com passcode + this device
kSecAttrAccessibleWhenUnlockedThisDeviceOnly     // após unlock + this device
kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly // após primeiro unlock + this device

// Menos restrito (sai em iCloud Keychain backup)
kSecAttrAccessibleWhenUnlocked
kSecAttrAccessibleAfterFirstUnlock
```

```swift
// Para tokens de auth — recomendado
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "auth_token",
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    kSecValueData as String: token.data(using: .utf8)!,
]

// Para chave que NUNCA deve sair do device (high security)
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    [.biometryCurrentSet, .privateKeyUsage],  // biometric obrigatório
    nil
)
```

## Android — Keystore + EncryptedSharedPreferences

```kotlin
// EncryptedSharedPreferences — para multiple keys/values
val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .build()

val prefs = EncryptedSharedPreferences.create(
    context, "secure_prefs", masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
)

// Keystore para chaves cryptographic
val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
keyGenerator.init(KeyGenParameterSpec.Builder("my_key",
    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
    .setUserAuthenticationRequired(true)            // exige biometric/PIN
    .setIsStrongBoxBacked(true)                     // hardware StrongBox se disponível
    .build())
```

## Backups — controlar o que sai

### Android
```xml
<!-- AndroidManifest.xml -->
<application
    android:allowBackup="false"  <!-- mais restrito -->
    android:fullBackupContent="@xml/backup_rules"
    android:dataExtractionRules="@xml/data_extraction_rules"  <!-- API 31+ -->
>
```

```xml
<!-- res/xml/backup_rules.xml — allowlist -->
<full-backup-content>
    <include domain="sharedpref" path="user_preferences.xml" />
    <exclude domain="sharedpref" path="secure_prefs.xml" />
    <exclude domain="database" path="auth.db" />
</full-backup-content>
```

### iOS
- Por default, tudo em `Documents/` vai para iCloud backup.
- Para excluir: `URLResourceValues.isExcludedFromBackup = true`
- Keychain com `*ThisDeviceOnly` não vai para iCloud Keychain backup.

```swift
var url = URL(fileURLWithPath: filePath)
var values = URLResourceValues()
values.isExcludedFromBackup = true
try url.setResourceValues(values)
```

## React Native

```javascript
import * as Keychain from 'react-native-keychain';

await Keychain.setGenericPassword('user', token, {
  accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
  accessControl: Keychain.ACCESS_CONTROL.BIOMETRY_CURRENT_SET,
  authenticationType: Keychain.AUTHENTICATION_TYPE.BIOMETRICS,
});
```

## Flutter

```dart
const storage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,  // não iCloud Keychain
  ),
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
);
```

## Common antipatterns

### `UserDefaults` (iOS) / `SharedPreferences` (Android) para tokens
- Plain text, accessible em backups, dumpable em jailbreak/root.

### Custom encryption "to be safe"
- Roll-your-own crypto = bug garantido. Usar APIs do sistema.

### Não excluir dados sensíveis de backups
- iCloud / Google Drive backup expõe.

### `SecureStorage` sem `accessControl: BIOMETRY`
- Token roubable em device unlocked sem biometric prompt.

### Cache de imagens / API responses com PII
- Caching libs (Glide, SDWebImage, Kingfisher) podem persistir conteúdo sensível.

### SQLite local sem encryption
- SQLCipher é a opção encrypted.

## Quick wins

- [ ] Tokens em Keychain (iOS) / EncryptedSharedPreferences ou Keystore (Android)
- [ ] Accessibility `*ThisDeviceOnly` em iOS
- [ ] `setUserAuthenticationRequired(true)` em Android Keystore para chaves sensíveis
- [ ] Biometric obrigatório para acesso a refresh tokens
- [ ] `android:allowBackup="false"` ou backup rules excluem PII
- [ ] iOS: `isExcludedFromBackup = true` para ficheiros sensíveis
- [ ] SQLite encrypted (SQLCipher) se BD local com PII
- [ ] Cache libs com config para excluir PII
- [ ] Logout apaga TUDO: Keychain entries, EncryptedPrefs, SQLite, cache
- [ ] Tokens com expiry curto + refresh em backend
