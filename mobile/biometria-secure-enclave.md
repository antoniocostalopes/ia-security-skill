# Biometria, Secure Enclave e Hardware-Backed Keys

> Biometria + hardware secure storage = melhor defesa de auth local em mobile. Mas precisa ser usada bem — não como "checkbox feature".

## Conceitos

| Termo | iOS | Android |
|---|---|---|
| Hardware secure storage | Secure Enclave | TEE (Trusted Execution Environment) / StrongBox |
| Biometric API | LocalAuthentication / BiometricPrompt-equivalent | BiometricPrompt (androidx.biometric) |
| Key reside em hardware | Sim, com `.privateKeyUsage` | Sim, com `setIsStrongBoxBacked(true)` |
| Key extraível | Não (em theory) | Não (em theory) |

## iOS — LocalAuthentication

```swift
import LocalAuthentication

let context = LAContext()
context.localizedFallbackTitle = ""  // sem fallback para passcode (force biometric)

var error: NSError?
guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
    // Device sem biometric ou disabled
    return
}

context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                       localizedReason: "Authenticate to access your account") { success, error in
    DispatchQueue.main.async {
        if success {
            // Unlock app or perform action
        } else {
            // Falha — não revelar detalhes
        }
    }
}
```

### Policies
- `.deviceOwnerAuthentication` — biometric ou passcode (mais permissive)
- `.deviceOwnerAuthenticationWithBiometrics` — só biometric (mais restrito)

### Detect mudança de biometric (anti spoof)

```swift
// Antes de operação sensível
let context = LAContext()
context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
let evalPolicyDomainState = context.evaluatedPolicyDomainState

// Comparar com state anterior — se mudou, biometric foi adicionado/removido
let savedState = ... // from Keychain
if evalPolicyDomainState != savedState {
    // Possível tentativa de adicionar fingerprint malicioso → re-auth com password
}
```

## Android — BiometricPrompt

```kotlin
import androidx.biometric.BiometricPrompt
import androidx.biometric.BiometricManager

val biometricManager = BiometricManager.from(context)

when (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)) {
    BiometricManager.BIOMETRIC_SUCCESS -> {
        // Pode usar
    }
    BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE,
    BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> {
        // Hardware indisponível
    }
    BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> {
        // User não enrolled
    }
}

val executor = ContextCompat.getMainExecutor(this)
val biometricPrompt = BiometricPrompt(this, executor,
    object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
            // Unlock
        }
        override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
            // Handle (no detalhe ao user)
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

### Authenticators
- `BIOMETRIC_STRONG` — Class 3 (FAR < 1/50000)
- `BIOMETRIC_WEAK` — Class 2 (menos seguro, **não usar para crypto**)
- `DEVICE_CREDENTIAL` — PIN/password do device

> Para crypto, usar **só** `BIOMETRIC_STRONG`.

## Hardware-backed keys (Android)

```kotlin
val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")

val spec = KeyGenParameterSpec.Builder(
    "user_key",
    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
)
    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
    .setUserAuthenticationRequired(true)               // exige biometric
    .setUserAuthenticationParameters(
        0,                                              // duração 0 = exige sempre
        KeyProperties.AUTH_BIOMETRIC_STRONG
    )
    .setIsStrongBoxBacked(true)                        // hardware StrongBox se disponível
    .setInvalidatedByBiometricEnrollment(true)         // invalida se nova biometric enrolled
    .build()

keyGenerator.init(spec)
val key = keyGenerator.generateKey()
```

## Crypto-bound biometric (iOS)

```swift
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    [.biometryCurrentSet, .privateKeyUsage],  // chave usável só com biometric atual
    nil
)!

let attributes: [String: Any] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
    kSecAttrKeySizeInBits as String: 256,
    kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,  // gerar em Secure Enclave
    kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: "user_key".data(using: .utf8)!,
        kSecAttrAccessControl as String: access,
    ],
]

var error: Unmanaged<CFError>?
guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
    fatalError()
}
// Chave nunca sai do Secure Enclave; só pode ser usada com biometric prompt
```

## Quando usar biometric

- **Sempre** para login após primeiro setup
- **Sempre** para aceder a refresh token guardado
- **Sempre** para operações financeiras (transferências, compras)
- **Sempre** para alterar dados sensíveis (email, password, MFA)
- **Sempre** para revelar dados sensíveis (CVV armazenado, código MFA backup)

## Quando NÃO confiar só em biometric

- Login inicial → exigir password também (multi-factor)
- Após restore de backup → re-auth
- Após mudança de biometric enrollment → re-auth
- Após X tempo sem usar app → re-auth com password

## Common antipatterns

### Biometric como **única** auth
- Se device for unlocked, biometric prompt + finger do dono = bypass.
- Combinar com PIN/password para operações de risco.

### `BIOMETRIC_WEAK` para crypto
- Class 2 não pode bind a key. Falsos positivos altos.

### Não invalidar key com novo enrollment
- Atacante adiciona o seu fingerprint → acede.
- `setInvalidatedByBiometricEnrollment(true)` (Android).

### Storage de "biometric_enabled = true" sem revalidar
- App assume biometric ativa, mas user removeu.

### Mensagem de erro detalhada
- "Biometric not enrolled" revela info. Mensagem genérica "Auth failed".

### `FaceID` description ausente em `Info.plist`
- App crash ao tentar usar FaceID sem `NSFaceIDUsageDescription`.

## Quick wins

- [ ] Biometric obrigatório para refresh tokens e operações sensíveis
- [ ] `BIOMETRIC_STRONG` (Android) / `.deviceOwnerAuthenticationWithBiometrics` (iOS)
- [ ] Keys cryptographic em Secure Enclave (iOS) / StrongBox (Android)
- [ ] `setUserAuthenticationRequired(true)` em chaves Android Keystore
- [ ] `setInvalidatedByBiometricEnrollment(true)` em Android
- [ ] Detect mudança de biometric state e re-auth
- [ ] Multi-factor para login inicial (não só biometric)
- [ ] `NSFaceIDUsageDescription` em `Info.plist`
- [ ] Mensagens de erro genéricas
- [ ] Fallback para PIN/password se biometric indisponível (mas registar)
- [ ] Logout apaga keys hardware-backed se aplicável
