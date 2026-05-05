# Flutter — Segurança

> Dart language patterns em `linguagens/dart.md`. Foco aqui em Flutter-specific.

## Storage — secrets

```dart
// BAD — SharedPreferences (plain text)
final prefs = await SharedPreferences.getInstance();
await prefs.setString('token', jwt);

// GOOD — flutter_secure_storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const storage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

await storage.write(key: 'token', value: jwt);
final token = await storage.read(key: 'token');
```

## Network — cert pinning

```dart
// Com http
import 'package:http/http.dart' as http;
import 'dart:io';

class PinnedClient extends http.BaseClient {
  final HttpClient _httpClient;

  PinnedClient() : _httpClient = HttpClient()
    ..badCertificateCallback = (cert, host, port) {
      // Verificar fingerprint do cert
      const allowedFingerprints = ['SHA256:base64=='];
      // ... compute and compare
      return allowedFingerprints.contains(/* ... */);
    };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final ioRequest = await _httpClient.openUrl(request.method, request.url);
    // ... copy headers, body
  }
}

// Alternativa: dio com dio_certificate_pinner
```

## Platform Channels — bridge Dart ↔ Native

```dart
// BAD — passar arbitrary data sem validação no native side
const platform = MethodChannel('com.app/auth');
final result = await platform.invokeMethod('login', userInput);

// GOOD — schema strict no native side
final result = await platform.invokeMethod('login', {
  'email': validatedEmail,
  'token': validatedToken,
});
```

## WebView — `webview_flutter`

```dart
final controller = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.disabled)  // se não precisas
  ..setBackgroundColor(Colors.white)
  ..setNavigationDelegate(NavigationDelegate(
    onNavigationRequest: (request) {
      if (request.url.startsWith('https://meusite.tld/')) {
        return NavigationDecision.navigate;
      }
      return NavigationDecision.prevent;
    },
  ))
  ..loadRequest(Uri.parse('https://meusite.tld/page'));
```

## Deep links — `app_links`

```dart
import 'package:app_links/app_links.dart';

final appLinks = AppLinks();
final initial = await appLinks.getInitialAppLink();
appLinks.uriLinkStream.listen((uri) {
  handleDeepLink(uri);
});

void handleDeepLink(Uri uri) {
  // Validar
  if (uri.host != 'meusite.tld') return;
  if (uri.path.startsWith('/auth/reset')) {
    final token = uri.queryParameters['token'];
    if (token == null || token.length < 32) return;
    // navegar com confirmação biométrica para ações sensíveis
  }
}
```

## Biometric — `local_auth`

```dart
import 'package:local_auth/local_auth.dart';

final auth = LocalAuthentication();
final canCheck = await auth.canCheckBiometrics;
final available = await auth.getAvailableBiometrics();

final didAuth = await auth.authenticate(
  localizedReason: 'Autentica para aceder à tua conta',
  options: const AuthenticationOptions(
    biometricOnly: true,
    stickyAuth: true,
  ),
);
```

## Code obfuscation

```bash
# Build com obfuscation + split debug info
flutter build apk --obfuscate --split-debug-info=./symbols/
flutter build ios --obfuscate --split-debug-info=./symbols/
```

> Sem `--obfuscate`, código Dart é descompilável quase 1:1.

## Hot reload em produção (não)

```dart
// BAD — assert é removido em release, mas...
assert(() {
  print('debug only');
  return true;
}());

// Configurar Sentry, Firebase Crashlytics, etc., para crash reporting (mas sem PII)
```

## Common antipatterns

### `print` em produção
- Visível em logcat / Console quando connected.

```dart
import 'package:flutter/foundation.dart';
if (kDebugMode) {
  print('debug only');
}
// Para release: usar logger package com filtros
```

### Variables `.env` empacotadas no bundle
- Public. Apenas se config não-secret.

### `WebView` com `JavaScriptMode.unrestricted` + URL externa
- XSS / RCE.

### `Image.network(userControlledUrl)` direto
- SSRF possível em algumas implementações.

### Permissions excessivas em `AndroidManifest.xml` / `Info.plist`
- Cada permissão é attack surface.

### Sem null safety
- Apps antigos pré-Dart 2.12. Migrar.

### `unawaited` futures sem error handling
- Crash silencioso.

## Quick wins

- [ ] Flutter 3.x stable
- [ ] Dart 3.x com null safety
- [ ] `dart pub outdated` regularmente
- [ ] `flutter_secure_storage` para tokens (não `shared_preferences`)
- [ ] Cert pinning em APIs críticas
- [ ] WebView com URL allowlist + JS off quando possível
- [ ] Deep links validados
- [ ] `local_auth` para operações sensíveis
- [ ] Build com `--obfuscate --split-debug-info=`
- [ ] Sem `print`/`debugPrint` com PII em release
- [ ] Sem secrets em código
- [ ] Permissions mínimas
- [ ] Detect root/jailbreak via `flutter_jailbreak_detection`
- [ ] Crash reporting (Sentry/Crashlytics) configurado SEM PII
- [ ] Code review de plataform channels
- [ ] Plus: ver `linguagens/dart.md` para Dart-specific
