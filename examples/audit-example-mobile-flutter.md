# Exemplo de Auditoria — App Flutter

> Few-shot para IAs auditarem apps mobile Flutter (Android+iOS).

## Input

### `pubspec.yaml`
```yaml
name: my_banking_app
dependencies:
  flutter: { sdk: flutter }
  http: ^0.13.0
  shared_preferences: ^2.0.0
  webview_flutter: ^4.0.0
```

### `lib/main.dart`
```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

const API_KEY = "sk_live_PLACEHOLDER_xxx";  // hardcoded
const API_URL = "http://api.minha-bank.com";

class AuthService {
  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$API_URL/login'),
      body: {'email': email, 'password': password, 'api_key': API_KEY},
    );
    final data = jsonDecode(response.body);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', data['token']);
    await prefs.setString('user_email', email);
    await prefs.setString('user_password', password);
  }

  Future<void> openHelp(String url) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
  }
}

void handleDeepLink(Uri uri) {
  if (uri.queryParameters['action'] == 'reset') {
    resetAccount();  // sem confirmação
  }
}
```

### `android/app/src/main/AndroidManifest.xml`
```xml
<application
    android:allowBackup="true"
    android:debuggable="true"
    android:usesCleartextTraffic="true">
  <activity android:name=".MainActivity" android:exported="true">
    <intent-filter>
      <action android:name="android.intent.action.VIEW" />
      <data android:scheme="mybank" />
    </intent-filter>
  </activity>
</application>
```

---

## Output esperado

```markdown
# Relatório de Segurança — my_banking_app

**Data:** 2026-05-06
**Stack:** Flutter 3.x · Android (target SDK ?) · iOS (alvo ?)
**Tipo:** App banking (alto risco)
**Ficheiros analisados:** 2 + manifest

## 1. Score: 0/100 — **Crítico — NÃO PUBLICAR**

| Severidade | Qtd | Subtotal |
|---|---:|---:|
| Crítico | 7 | -140 |
| Alto    | 4 | -40 |
| Médio   | 2 | -8 |
| **Total** | 13 | **0 (cap)** |

## 2. Resumo Cliente
Para uma app **banking**, esta tem **7 problemas críticos** que comprometem totalmente a segurança: API key e password do user em plain text no device + comunicação em HTTP + WebView aceita JavaScript de qualquer URL + deep link permite reset de conta sem confirmação. **Não publicar — poderias perder licença bancária.** Fixes 2-3 dias mas requerem refactor significativo.

## 3. Resumo Técnico
Modelo de ameaça mobile não considerado: secrets hardcoded (recuperáveis com jadx em segundos), credenciais persistidas em SharedPreferences plain text (extraíveis via adb backup), HTTP cleartext, sem cert pinning, WebView totalmente aberto (RCE potencial via JS bridge), debug enabled em release, allowBackup true permite extração via adb. URL Scheme em vez de App Links permite app maliciosa interceptar. Refactor: flutter_secure_storage, cert pinning, JS desativado em WebView, Universal Links/App Links, biometric prompt para ações destrutivas, ProGuard/R8.

## 4. Mapa de Superfícies

| # | Superfície | Localização | Trust | Risco |
|---|---|---|---|---|
| 1 | API HTTP | main.dart:13 | Hostile network | Crítico |
| 2 | SharedPreferences | main.dart:18-20 | Device | Crítico |
| 3 | WebView | main.dart:25 | Web content | Crítico |
| 4 | Deep link | main.dart:32 | Other apps | Crítico |
| 5 | App binary | apk/ipa | Reverse engineering | Crítico |
| 6 | adb backup | manifest | Local | Alto |

## 5. Attack Chains

### Vetor 1 — Roubo de credenciais (Crítico, 100%)
- C1 (HTTP) + C2 (sem cert pinning) + C3 (passwords em SharedPreferences)
- Atacante em Wi-Fi público faz MITM, captura login. Plus: device perdido/jailbroken → adb pull do plain text.

### Vetor 2 — Comprometimento total via reverse engineering (Crítico, 100%)
- C4 (API_KEY hardcoded) + C5 (debuggable=true) + sem ProGuard
- `jadx app.apk | grep -A2 'API_KEY ='` → `sk_live_PLACEHOLDER_xxx`
- Backend foi comprometido via key de admin

### Vetor 3 — Reset de conta via app maliciosa (Crítico, 95%)
- C6 (URL Scheme) + C7 (deep link sem confirmação)
- App maliciosa regista `mybank://` também → quando user clica num link, app maliciosa apanha → invoca `mybank://reset?action=reset` → resetAccount() sem prompt

## 6. Achados

### Críticos

#### C1. API em HTTP cleartext
- **Categoria:** Mobile / Comunicação rede
- **Confiança:** 100%
- **Localização:** `main.dart:7`, `AndroidManifest.xml:4`
- **Código:** `const API_URL = "http://..."` + `usesCleartextTraffic="true"`
- **Exploração:** MITM em qualquer rede insegura.
- **Correção:**
  - URL: `https://api.minha-bank.com`
  - `AndroidManifest.xml`: remover `usesCleartextTraffic="true"`, adicionar `android:networkSecurityConfig="@xml/network_security_config"` com cleartextTrafficPermitted=false
  - iOS: `Info.plist` com `NSAllowsArbitraryLoads = false` (default)

#### C2. Sem certificate pinning (banking app)
- **Categoria:** Mobile / Network
- **Confiança:** 95%
- **Localização:** `main.dart:9-12`
- **Explicação:** Sem pinning, MITM com cert válido (CA comprometido ou user instalou cert custom) é trivial.
- **Correção:**
  ```dart
  // pubspec.yaml: adicionar dio + dio_certificate_pinner
  import 'package:dio/dio.dart';
  import 'package:dio_certificate_pinner/dio_certificate_pinner.dart';

  final dio = Dio()
    ..interceptors.add(CertificatePinningInterceptor(
      allowedSHAFingerprints: ['SHA256_DA_TUA_CHAVE_PUBLICA_BACKEND'],
    ));
  ```

#### C3. Credenciais em SharedPreferences (plain text)
- **Categoria:** Mobile / Storage
- **Confiança:** 100%
- **Localização:** `main.dart:18-20`
- **Código:**
  ```dart
  await prefs.setString('token', data['token']);
  await prefs.setString('user_password', password);
  ```
- **Explicação:** SharedPreferences é XML em `/data/data/<pkg>/shared_prefs/` — extraível via adb (com `allowBackup=true`!) ou root. **Password armazenada é catástrofe — nunca armazenar password.**
- **Correção:**
  ```dart
  // pubspec.yaml: flutter_secure_storage
  import 'package:flutter_secure_storage/flutter_secure_storage.dart';

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  // NUNCA armazenar password — só refresh token
  await storage.write(key: 'refresh_token', value: data['refresh_token']);
  // Email pode ficar em SharedPreferences (não é secret)
  ```

#### C4. API_KEY hardcoded em código Dart
- **Categoria:** Tokens / Secrets / Mobile RE
- **Confiança:** 100%
- **Localização:** `main.dart:6`
- **Código:** `const API_KEY = "sk_live_PLACEHOLDER_xxx";`
- **Explicação:** App é distribuída como bundle. `jadx app.apk` ou `strings app.aab` revela todas as constantes. Stripe live key num cliente = todos os clientes têm a mesma → atacante usa.
- **Correção:**
  - **Backend proxy**: app chama `POST /charge` no teu backend, backend chama Stripe. Key fica server-side.
  - **Se mesmo precisares no client**: usar Stripe **publishable key** (`pk_live_...`), não secret.
  - **Build com obfuscation**: `flutter build apk --obfuscate --split-debug-info=./symbols`

#### C5. `debuggable="true"` em manifest
- **Categoria:** Configuração / Hardening
- **Confiança:** 100%
- **Localização:** `AndroidManifest.xml:3`
- **Explicação:** Permite anexar debugger em release. Combinado com sem ProGuard = código facilmente analisável.
- **Correção:**
  - Remover do manifest.
  - Build types em `build.gradle`:
    ```groovy
    buildTypes {
        release {
            debuggable false
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    ```

#### C6. URL Scheme `mybank://` (não App Link)
- **Categoria:** Mobile / Deep links
- **Confiança:** 95%
- **Localização:** `AndroidManifest.xml`
- **Explicação:** URL Scheme é hijackable — qualquer app pode registar `mybank://`. Last-installed wins. Para banking app é inaceitável.
- **Correção:**
  - **Migrar para App Links** (Android) e **Universal Links** (iOS):
    ```xml
    <intent-filter android:autoVerify="true">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.BROWSABLE" />
      <category android:name="android.intent.category.DEFAULT" />
      <data android:scheme="https" android:host="minha-bank.com" />
    </intent-filter>
    ```
  - Hospedar `https://minha-bank.com/.well-known/assetlinks.json` com cert SHA256.

#### C7. Deep link `reset` executa sem confirmação
- **Categoria:** Mobile / Deep links / Business logic
- **Confiança:** 100%
- **Localização:** `main.dart:32-34`
- **Código:**
  ```dart
  if (uri.queryParameters['action'] == 'reset') {
      resetAccount();
  }
  ```
- **Correção:**
  ```dart
  Future<void> handleDeepLink(Uri uri) async {
      if (uri.queryParameters['action'] != 'reset') return;
      // 1. Mostrar dialog de confirmação
      final confirmed = await showConfirmDialog(message: 'Confirmar reset?');
      if (!confirmed) return;
      // 2. Exigir biometric
      final auth = await LocalAuthentication().authenticate(
          localizedReason: 'Confirma reset com biometria');
      if (!auth) return;
      // 3. Executar
      await resetAccount();
  }
  ```

### Altos

#### A1. WebView com JavaScript unrestricted + URL não validada
- **Categoria:** Mobile / WebView
- **Confiança:** 90%
- **Localização:** `main.dart:25-28`
- **Correção:**
  ```dart
  Future<void> openHelp(String url) async {
      final allowedHosts = ['help.minha-bank.com'];
      final parsed = Uri.tryParse(url);
      if (parsed == null || parsed.scheme != 'https' || !allowedHosts.contains(parsed.host)) {
          throw Exception('URL não permitida');
      }
      // JS desativado se possível para help estático
      final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.disabled)
          ..loadRequest(parsed);
  }
  ```

#### A2. `allowBackup="true"` em banking app
- **Categoria:** Configuração / Hardening
- **Confiança:** 100%
- **Localização:** `AndroidManifest.xml:2`
- **Correção:** `android:allowBackup="false"` + `android:dataExtractionRules` para API 31+.

#### A3. Sem detecção de jailbreak/root
- **Categoria:** Mobile / Resilience (MASVS-R)
- **Confiança:** 80%
- **Explicação:** Banking app deve detetar device comprometido e bloquear/limitar.
- **Correção:** `flutter_jailbreak_detection` + ação adequada (avisar user + limitar features).

#### A4. Sem App Attest (iOS) / Play Integrity (Android)
- **Categoria:** Mobile / Resilience
- **Confiança:** 75%
- **Explicação:** Para banking, server deveria verificar que requests vêm de app genuína.
- **Correção:** Implementar Play Integrity API + App Attest. Backend rejeita requests não atestados.

### Médios

#### M1. Sem code obfuscation
- **Confiança:** 70%
- **Correção:** `flutter build apk --obfuscate --split-debug-info=./symbols/`

#### M2. Sem rate limiting em login
- **Confiança:** 70%
- **Explicação:** Esperar do backend mas confirmar.

## 7. Plano de Correção

### Fase 1 — 48h (BLOQUEIA)
- [ ] C4 — Mover API_KEY para backend proxy
- [ ] C1 + C5 — HTTPS + remover debuggable + cleartextTraffic=false
- [ ] C3 — flutter_secure_storage, NUNCA armazenar password
- [ ] C7 — Confirmação + biometric em deep link reset

### Fase 2 — 1 semana
- [ ] C2 — Cert pinning
- [ ] C6 — Migrar URL Scheme → App Links/Universal Links
- [ ] A1 — WebView com allowlist + JS off
- [ ] A2 — allowBackup=false
- [ ] M1 — Code obfuscation em release

### Fase 3 — 2-4 semanas (banking-grade)
- [ ] A3 — Jailbreak/root detection
- [ ] A4 — Play Integrity + App Attest

### Fase 4 — Contínuo
- [ ] CI: lint Dart + flutter analyze
- [ ] Dependency check
- [ ] Pen-test externo (banking exige)

## 8. Checklist Pré-Produção (Banking)

- [ ] HTTPS-only, cleartext bloqueado
- [ ] Cert pinning ativo
- [ ] Tokens em flutter_secure_storage (nunca password)
- [ ] Sem secrets em código (verificado com `jadx`)
- [ ] Universal Links / App Links (não URL Schemes)
- [ ] Biometric para operações sensíveis
- [ ] WebView com JS off + URL allowlist
- [ ] allowBackup=false
- [ ] debuggable=false
- [ ] Code obfuscation (`--obfuscate`)
- [ ] Play Integrity / App Attest server-side validation
- [ ] Jailbreak/root detection com ação adequada
- [ ] Crash reporting sem PII
- [ ] Pen-test externo aprovado
- [ ] Compliance bancária revista (auditoria externa)

## 9. Recomendações

- **Banking apps NUNCA devem armazenar password.** Token de sessão + biometric reauth.
- **Considerar Frida/Mobile RASP** (Build38, Promon) para apps de muito alto risco
- **MASVS Level 2 + R** mandatório para banking
- **OWASP Mobile Top 10** revisão completa
- **Pen-test externo trimestral**
```
