# Reverse Engineering — Mitigação

> Apps móveis são distribuídas como binários. Atacante baixa do store, descompila, analisa lógica, encontra secrets, reescreve. Cada camada de obfuscação **atrasa**, não impede. Atrasar é o objetivo.

## Ferramentas que o atacante usa

### iOS
- **class-dump** — extrai Objective-C class info
- **Hopper / Ghidra / IDA** — disassembler
- **Frida** — runtime instrumentation
- **Cycript** — JS bridge to Objective-C runtime
- **MachOView** — analisa Mach-O binaries
- **Theos** / **Ldid** — modificar binaries

### Android
- **jadx** — APK → Java decompiler (excellent)
- **APKTool** — disassemble/reassemble APKs
- **dex2jar** + **JD-GUI** — alternative
- **Ghidra** — disassembler com plugin Android
- **Frida** — runtime instrumentation
- **Xposed framework** — runtime hooks
- **Drozer** — security testing framework
- **MobSF** — automated mobile security testing

### Cross-platform
- **Burp Suite** — proxy MITM
- **Wireshark** — análise de tráfego
- **Magisk** — root + módulos

## Camadas de obfuscação

### Nível 0 — Sem obfuscação
- Código descompilado é quase 1:1 com original.
- Strings em plain text.
- Símbolos (nomes de funções, variáveis) intactos.

### Nível 1 — Minification / ProGuard básico
- Renomeia símbolos para `a`, `b`, `c`.
- Remove código não usado.
- Strings ainda em plain text.

### Nível 2 — String encryption
- Strings cifradas, descifradas em runtime.
- Atacante hookea descifragem com Frida.

### Nível 3 — Control flow obfuscation
- Bytecode reorganizado para confundir análise.
- DexGuard, iXGuard, ConfuserEx.

### Nível 4 — RASP (Runtime Application Self-Protection)
- App detecta hooks/debug em runtime e age.
- Soluções comerciais: PromonShield, Build38, Guardsquare.

## Android — ProGuard / R8

```gradle
// build.gradle (app)
android {
    buildTypes {
        release {
            minifyEnabled true                 // R8 (default em AGP 4.0+)
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                          'proguard-rules.pro'
        }
    }
}
```

```proguard
# proguard-rules.pro

# Keep app entry point
-keep class com.app.MainActivity { *; }

# Keep view models for ViewBinding
-keep class * extends androidx.lifecycle.ViewModel { *; }

# Keep Retrofit interfaces (reflection)
-keep,allowobfuscation,allowshrinking interface retrofit2.Call
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation

# Remove logs em release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Don't optimize Native bindings
-keep class com.app.NativeBridge { native <methods>; }
```

### Limitações ProGuard
- Apenas obfusca nomes — código continua descompilável.
- Strings continuam em plain.
- Não impede Frida hooks.

## Android — DexGuard (paid)

- String encryption
- Class encryption
- Anti-Frida runtime checks
- Anti-debug
- Tamper detection
- Resource encryption

## iOS — Bitcode / código

iOS já tem code signing forte. Mas:
- Strings em plain text no `__cstring` section.
- Class names em Obj-C runtime.

### Mitigação
- **Swift** em vez de Obj-C (menos metadata exposto)
- **String obfuscation** manual ou via tools (iXGuard, Polidea)
- **Strip symbols** em release
- **Disable Bitcode** (descontinuado em Xcode 14+)

```swift
// Manual string obfuscation (simple XOR)
func decrypt(_ encrypted: [UInt8], key: UInt8) -> String {
    return String(bytes: encrypted.map { $0 ^ key }, encoding: .utf8) ?? ""
}

let API_KEY = decrypt([0x12, 0x34, 0x56, ...], key: 0x42)
```

> XOR não é segurança real, mas atrasa. Para sério, usar AES + chave derivada de info do device.

## Anti-Frida (Android)

```kotlin
fun isFridaPresent(): Boolean {
    // 1. Check for Frida server port
    try {
        val socket = Socket()
        socket.connect(InetSocketAddress("127.0.0.1", 27042), 100)
        socket.close()
        return true
    } catch (e: Exception) {}

    // 2. Check for Frida threads
    val threads = Thread.getAllStackTraces().keys
    for (thread in threads) {
        if (thread.name.lowercase().contains("frida") ||
            thread.name.lowercase().contains("gum-js")) {
            return true
        }
    }

    // 3. Check for Frida libraries loaded
    try {
        val maps = File("/proc/self/maps").readText()
        if (maps.contains("frida") || maps.contains("gum-js")) return true
    } catch (e: Exception) {}

    return false
}
```

## Anti-Frida (iOS)

```swift
func isFridaPresent() -> Bool {
    // Check for Frida default port
    let socket = socket(AF_INET, SOCK_STREAM, 0)
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = (27042 as UInt16).bigEndian
    inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

    let result = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    close(socket)
    return result == 0
}
```

## Strip API keys do código

A solução real é **não ter keys no código**:

```
[ App ] → [ Backend autenticado ] → [ API externa com key ]
```

Backend faz proxy. App só tem token de user, não API key de serviço.

Se app precisa mesmo de chamar API direto:
- **API key per device** — cada device recebe key única, expirável, rotacionável
- **OAuth Device Flow** — user autoriza device

## Detectar tampering — server-side

```
1. App envia attestation token (Play Integrity, App Attest)
2. App envia signature hash do binary atual
3. Backend valida ambos contra valores esperados
4. Se inválido, recusar requests críticos
```

## Common antipatterns

### Strings de API key como const
```kotlin
const val API_KEY = "sk_live_abc..."  // visível em jadx
```

### Comentários revelando lógica
```java
// Special bypass for testing — ?bypass=admin123
if (request.getParameter("bypass").equals("admin123")) { ... }
```

### `BuildConfig.DEBUG` checks bypassáveis
- `BuildConfig.DEBUG = false` é hardcoded em build, mas atacante pode flip via Magisk module.

### Confiar em check client-side único
- Frida bypass com 1 linha: `Java.use('com.app.RootCheck').isRooted.implementation = function() { return false; }`

### Não combinar ofuscação + RASP + server-side
- Cada camada sozinha é trivial. Combinadas são significativas.

## Quick wins

- [ ] **Não pôr secrets em código.** Backend proxy.
- [ ] ProGuard/R8 ativo (Android)
- [ ] Strip symbols em release iOS
- [ ] DexGuard/iXGuard para máximo (paid)
- [ ] String encryption manual ou via tool
- [ ] Anti-Frida checks em apps de alto risco
- [ ] Anti-debug checks
- [ ] Server-side attestation (Play Integrity, App Attest)
- [ ] Backend valida signature hash de cada request crítico
- [ ] Logout invalidates server-side tokens
- [ ] Rate limit + anomaly detection server-side (compensa client-side bypass)
- [ ] Bug bounty program para apps de alto risco
- [ ] Penetration testing periódico (red team)
- [ ] Atualizar mitigações regularmente — RE tools evoluem
