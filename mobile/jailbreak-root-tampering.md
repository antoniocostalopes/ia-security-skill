# Jailbreak / Root Detection e Anti-Tampering

> Detecção de devices comprometidos. **Não é prevenção**, é sinal de risco. Pode bloquear app, exigir auth adicional, ou apenas avisar — depende do contexto.

## Quando aplicar

- Apps de **alto risco**: banking, medical, payments, governo, enterprise
- Apps de **valor**: paid apps que querem proteger contra cracking
- **Não aplicar** em apps casuais — exclui users legítimos com root para outros fins

## iOS — Detect Jailbreak

```swift
func isJailbroken() -> Bool {
    // 1. Path checks (paths que existem em jailbroken)
    let paths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/usr/bin/ssh",
        "/private/var/lib/apt/",
    ]
    for path in paths {
        if FileManager.default.fileExists(atPath: path) { return true }
    }

    // 2. Cydia URL scheme
    if let url = URL(string: "cydia://package/com.example.package"),
       UIApplication.shared.canOpenURL(url) { return true }

    // 3. Try writing to root path (deve falhar em sandbox)
    let testPath = "/private/jailbreak_test.txt"
    do {
        try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: testPath)
        return true  // conseguiu escrever fora do sandbox
    } catch {
        // Esperado em device não-jailbroken
    }

    // 4. fork() check (sandbox proíbe)
    if getuid() == 0 { return true }  // running as root

    return false
}

// Frameworks: IOSSecuritySuite (open source) ou DTTJailbreakDetection
```

## Android — Detect Root

```kotlin
fun isRooted(): Boolean {
    // 1. Check for su binary
    val paths = listOf(
        "/system/bin/su", "/system/xbin/su", "/sbin/su",
        "/system/su", "/system/bin/.ext/.su",
        "/system/usr/we-need-root/su", "/data/local/su",
        "/data/local/xbin/su", "/data/local/bin/su"
    )
    if (paths.any { File(it).exists() }) return true

    // 2. Check for root apps
    val rootApps = listOf(
        "com.koushikdutta.superuser",
        "eu.chainfire.supersu",
        "com.noshufou.android.su",
        "com.thirdparty.superuser",
        "com.kingouser.com",
        "com.topjohnwu.magisk",
    )
    val pm = context.packageManager
    for (app in rootApps) {
        try {
            pm.getPackageInfo(app, 0)
            return true
        } catch (e: PackageManager.NameNotFoundException) {}
    }

    // 3. Test writing to system
    val testFile = File("/system/test_write")
    if (testFile.canWrite()) return true

    // 4. Check build tags
    val buildTags = Build.TAGS
    if (buildTags?.contains("test-keys") == true) return true

    // 5. Run su via Process
    try {
        val process = Runtime.getRuntime().exec("su")
        process.outputStream.close()
        process.waitFor()
        if (process.exitValue() == 0) return true
    } catch (e: Exception) {}

    return false
}

// Frameworks: RootBeer (popular)
```

## Detect Magisk hide / Zygisk
- Modern jailbreak/root tools escondem-se de app checks.
- **Combinar** múltiplos checks. Nenhum sozinho é fiável.
- Server-side attestation (Play Integrity, App Attest) é mais robusto.

## Anti-debug

```swift
// iOS — PT_DENY_ATTACH (impede debugger anexar)
import Darwin

func denyDebug() {
    typealias PtraceType = @convention(c) (Int32, pid_t, caddr_t, Int32) -> Int32
    let handle = dlopen(nil, RTLD_LAZY)
    let ptracePtr = dlsym(handle, "ptrace")
    let ptrace = unsafeBitCast(ptracePtr, to: PtraceType.self)
    _ = ptrace(31 /* PT_DENY_ATTACH */, 0, nil, 0)
}
```

```kotlin
// Android — Detectar debugger anexado
fun isDebuggerAttached(): Boolean {
    return Debug.isDebuggerConnected() || Debug.waitingForDebugger()
}

// Detectar se debug build
fun isDebuggable(): Boolean {
    return (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
}
```

## Anti-tampering (integrity checks)

### Verificar signature da app

```kotlin
// Android
fun getSigningSignatureHash(): String {
    val pm = context.packageManager
    val info = if (Build.VERSION.SDK_INT >= 28) {
        pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
    } else {
        pm.getPackageInfo(context.packageName, PackageManager.GET_SIGNATURES)
    }
    val sigs = if (Build.VERSION.SDK_INT >= 28) {
        info.signingInfo.apkContentsSigners
    } else {
        info.signatures
    }
    val md = MessageDigest.getInstance("SHA-256")
    return Base64.encodeToString(md.digest(sigs[0].toByteArray()), Base64.NO_WRAP)
}

// Comparar com hash esperado (hardcoded)
val EXPECTED_SIG = "base64HashOfRealSignature"
if (getSigningSignatureHash() != EXPECTED_SIG) {
    // App foi recompilada — bloquear ou avisar
}
```

```swift
// iOS — verificar bundle ID + team ID + provisioning
func isOriginalApp() -> Bool {
    guard let bundleID = Bundle.main.bundleIdentifier else { return false }
    if bundleID != "com.meusite.app" { return false }
    // Verificar code signing via SecCode (avançado)
    return true
}
```

## Server-side device attestation

Mais robusto que client-side checks. App envia attestation token, backend valida.

### Android — Play Integrity API

```kotlin
val integrityManager = IntegrityManagerFactory.create(context)
val integrityTokenResponse = integrityManager.requestIntegrityToken(
    IntegrityTokenRequest.builder()
        .setNonce(nonce)
        .build()
)
// Send token to backend, backend valida com Google
```

### iOS — App Attest

```swift
import DeviceCheck

let service = DCAppAttestService.shared
service.generateKey { keyId, error in
    service.attestKey(keyId, clientDataHash: hash) { attestation, error in
        // Send attestation to backend, backend valida com Apple
    }
}
```

## Como reagir a deteção

| Risco do app | Reação |
|---|---|
| Banking/Health | Bloquear funcionalidades críticas, avisar |
| Enterprise | Limitar acesso, log forense |
| Pago | Reduzir features, avisar (não banir) |
| Casual | Apenas log analytics |

> **Não crashes** a app. Failure mode amigável.

## Common antipatterns

### Single-check (só `Cydia.app`)
- Atacante esconde com 1 click.

### Detection logado mas sem ação
- Sinal sem reação = inútil.

### Bloquear app por root sem motivo claro
- Users legítimos com root irritados (developers, power users).

### Sem fallback se attestation falha
- Network issues, app store delay → users legítimos bloqueados.

### Anti-debug que crash a app
- UX terrível.

## Quick wins

- [ ] Para apps de alto risco: detection com **múltiplos checks**
- [ ] Combinar client-side + server-side attestation (Play Integrity / App Attest)
- [ ] Failure mode gracioso (avisar, não crash)
- [ ] Anti-debug em apps de banking/payments
- [ ] Signature verification no startup
- [ ] Re-auth biometric quando detection positiva
- [ ] Logging server-side de eventos de tampering (forense)
- [ ] Considerar ProGuard/R8 (Android) e Bitcode (iOS, descontinuado mas obfuscation equivalente)
- [ ] DexGuard / iXGuard para máximo (paid solutions)
- [ ] Atualizar regularmente — atacantes evoluem checks bypasses
