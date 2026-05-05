# Dart / Flutter — Cartão de Segurança

## Idiomas inseguros

### Null assertion `!`
```dart
// BAD
final user = users.first!;
final url = Uri.parse(input)!;

// GOOD
if (users.isEmpty) throw EmptyError();
final user = users.first;

final url = Uri.tryParse(input);
if (url == null) throw InvalidUrlError();
```

### `as` cast sem validação
```dart
// BAD
final user = obj as User;  // throws em runtime

// GOOD
if (obj is User) {
    final user = obj;
} else {
    handleError();
}
```

### Comparação de tokens
```dart
// BAD
if (expected == received) { ... }  // não constant-time

// GOOD
import 'package:crypto/crypto.dart';
import 'package:collection/collection.dart';

final eq = ListEquality().equals(
  utf8.encode(expected),
  utf8.encode(received),
);
// Para constant-time real, implementar manualmente:
bool constantTimeEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  int result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result == 0;
}
```

### Random
```dart
// BAD
import 'dart:math';
final token = Random().nextInt(1000000);

// GOOD
import 'dart:math';
final secure = Random.secure();
final bytes = List<int>.generate(32, (_) => secure.nextInt(256));
final token = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
```

## Flutter-specific

### Storage: secure storage para tokens
```dart
// BAD — SharedPreferences
import 'package:shared_preferences/shared_preferences.dart';
final prefs = await SharedPreferences.getInstance();
await prefs.setString('token', jwt);

// GOOD — flutter_secure_storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
const storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
await storage.write(key: 'token', value: jwt);
```

### Network: cert pinning
```dart
// Usar dio + dio_certificate_pinner ou http + manual SSL handler
import 'package:http/http.dart' as http;
import 'dart:io';

final client = HttpClient()
  ..badCertificateCallback = (cert, host, port) {
    final allowedFingerprints = ['SHA256:...'];
    final actual = sha256.convert(cert.der).toString();
    return allowedFingerprints.contains(actual);
  };
```

### WebView (`webview_flutter`)
```dart
// BAD — qualquer URL
final controller = WebViewController()
  ..loadRequest(Uri.parse(userInput));

// GOOD
final url = Uri.tryParse(userInput);
if (url == null || url.scheme != 'https'
    || !ALLOWED_HOSTS.contains(url.host)) {
  return;
}
controller.setJavaScriptMode(JavaScriptMode.disabled);  // se não precisas
controller.loadRequest(url);
```

### Deep links
```dart
// uni_links / app_links
StreamSubscription? _sub;

@override
void initState() {
  super.initState();
  _sub = uriLinkStream.listen((Uri? uri) {
    if (uri == null) return;
    handleDeepLink(uri);
  });
}

void handleDeepLink(Uri uri) {
  // BAD — confia em params
  if (uri.queryParameters['action'] == 'delete') deleteAccount();

  // GOOD — confirmar
  if (uri.queryParameters['action'] == 'delete') {
    showConfirmDialog(onConfirm: () async {
      await requireBiometric();
      deleteAccount();
    });
  }
}
```

### `print` / `debugPrint` em produção
```dart
// BAD
print('User token: $token');

// GOOD — assert é removido em release
assert(() {
  debugPrint('Auth call');  // sem PII
  return true;
}());
```

### Biometrics — `local_auth`
```dart
import 'package:local_auth/local_auth.dart';

final auth = LocalAuthentication();
final didAuth = await auth.authenticate(
  localizedReason: 'Authenticate to access account',
  options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
);
if (didAuth) { /* unlock */ }
```

### Jailbreak / Root detection
```dart
// flutter_jailbreak_detection
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

final isCompromised = await FlutterJailbreakDetection.jailbroken;
if (isCompromised) {
  // bloquear ou modo limitado
}
```

### Platform channels
```dart
// BAD — passar arbitrary data sem validar
const channel = MethodChannel('com.app/auth');
final result = await channel.invokeMethod('execute', userInput);

// GOOD — schema strict
final result = await channel.invokeMethod('login', {
  'email': validatedEmail,
  'token': validatedToken,
});
```

## Pacotes Pub.dev — verificação

- Verificar **publisher** (verified vs random).
- Last update recente.
- Issues abertas vs closed.
- Star count + downloads.
- Ler source (pacotes Pub são públicos).

### Pacotes com vulns conhecidas
- **`http` < 0.13.4** → várias
- **`dio`** — manter atualizado
- **`shared_preferences`** — não para secrets

## Quick wins

- [ ] Dart 3.x stable
- [ ] Sem `!`/`as` força em código de produção
- [ ] `flutter_secure_storage` para tokens (não `SharedPreferences`)
- [ ] Cert pinning em APIs críticas
- [ ] WebView com URL allowlist + JS desativado quando possível
- [ ] Deep links com confirmação para ações sensíveis
- [ ] Sem `print`/`debugPrint` com PII
- [ ] `local_auth` para operações sensíveis
- [ ] Detecção de jailbreak/root + ação adequada
- [ ] Platform channels com schema strict
- [ ] `Random.secure()` para tokens
- [ ] Constant-time compare em hashes
- [ ] Code obfuscation em release (`flutter build apk --obfuscate --split-debug-info=...`)
- [ ] `pub outdated` regularmente; `dart fix` para warnings
