# React Native — Segurança

## Storage — secrets

```javascript
// BAD — AsyncStorage (plain text no disco)
import AsyncStorage from '@react-native-async-storage/async-storage';
await AsyncStorage.setItem('token', jwt);

// GOOD — react-native-keychain
import Keychain from 'react-native-keychain';

await Keychain.setGenericPassword('user', token, {
  accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
  accessControl: Keychain.ACCESS_CONTROL.BIOMETRY_CURRENT_SET,
});

const credentials = await Keychain.getGenericPassword();
if (credentials) {
  const token = credentials.password;
}

// Alternativa: react-native-encrypted-storage
import EncryptedStorage from 'react-native-encrypted-storage';
await EncryptedStorage.setItem('token', jwt);
```

## Network — cert pinning

```javascript
// react-native-ssl-pinning
import { fetch } from 'react-native-ssl-pinning';

await fetch('https://api.meusite.tld/data', {
  method: 'GET',
  sslPinning: {
    certs: ['cert1'],  // arquivos .cer no bundle
  },
});

// Alternativa: usar TrustKit (iOS) e Network Security Config (Android)
// configurados nativamente em paralelo
```

## Bridges JS ↔ Native

Comunicação JS ↔ Native pode ser superfície de ataque se passa input não validado.

```javascript
// BAD
NativeModules.MyModule.executeCommand(userInput);

// GOOD — schema strict no native side
NativeModules.MyModule.login({
  email: validatedEmail,
  password: validatedPassword,
});
```

## WebView — `react-native-webview`

```jsx
<WebView
  source={{ uri: validatedUrl }}
  javaScriptEnabled={false}              // se possível
  domStorageEnabled={false}
  allowsBackForwardNavigationGestures={false}
  allowFileAccess={false}                // Android
  allowFileAccessFromFileURLs={false}
  allowUniversalAccessFromFileURLs={false}
  mixedContentMode="never"
  originWhitelist={['https://meusite.tld']}  // CRÍTICO
  onShouldStartLoadWithRequest={(request) => {
    return request.url.startsWith('https://meusite.tld');
  }}
/>
```

## Deep linking — react-navigation

```javascript
const linking = {
  prefixes: ['meusite.tld', 'app.meusite.tld'],
  config: {
    screens: {
      Profile: 'profile/:id',
    },
  },
};

// Verificar params
function handleProfileLink(id) {
  // BAD — confia
  navigation.navigate('Profile', { id });

  // GOOD — validar
  if (!/^\d+$/.test(id)) return;
  navigation.navigate('Profile', { id: parseInt(id, 10) });
}
```

## Bundle / source maps

```javascript
// metro.config.js — source maps NÃO devem ir para release
module.exports = {
  transformer: {
    minifierConfig: {
      keep_classnames: false,
      keep_fnames: false,
      mangle: { toplevel: true },
    },
  },
};

// android/app/build.gradle
project.ext.react = [
    enableHermes: true,  // bytecode (mais difícil de reverse)
]
```

## Hermes
- Engine JS otimizado para RN.
- Compila para bytecode (mais difícil de descompilar que minified JS).
- **Ativar em produção**.

## Common antipatterns

### `console.log` em produção
- React Native Debugger / Flipper / logcat tudo capturado.

```javascript
if (!__DEV__) {
  console.log = () => {};
  console.warn = () => {};
}
```

### Credentials em `.env` que vai para bundle
- `react-native-config` empacota TUDO no bundle. Public.
- Para secrets reais: backend.

### `Linking.openURL(userInput)` sem validar
- Pode abrir `tel:`, `sms:`, deep link malicioso.

### `WebView` aceitando `originWhitelist={['*']}`
- Permite qualquer origem.

### `react-native-fetch-blob` com paths não validados
- Path traversal em downloads.

### Sem `Platform.OS` checks
- Código que depende de iOS-only API crash em Android.

## Quick wins

- [ ] React Native 0.73+ (Hermes ON)
- [ ] `npm audit` sem Críticos
- [ ] Tokens em Keychain (iOS) / EncryptedSharedPreferences (Android) via react-native-keychain ou encrypted-storage
- [ ] Cert pinning em APIs críticas
- [ ] WebView com `originWhitelist` específico
- [ ] WebView com JS desativado se possível
- [ ] Deep links validados
- [ ] `console.log` removido em produção
- [ ] Sem secrets em código / .env
- [ ] Hermes ativo
- [ ] ProGuard/R8 ativo (Android)
- [ ] Bitcode ativo (iOS, descontinuado em Xcode 14+ mas optimization equivalente)
- [ ] Bridge calls com schema strict no native side
- [ ] `Linking.canOpenURL` antes de `openURL`
- [ ] Detect jailbreak/root via `react-native-jail-monkey` em apps de alto risco
- [ ] Plus: ver `linguagens/javascript-typescript.md` para JS-specific
