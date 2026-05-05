# Mobile — Track de Segurança

> Mobile tem modelo de ameaça **diferente** de web. App corre em device controlado pelo utilizador (potencialmente atacante). Reverse engineering é trivial. Storage local sob controlo do user. Network pode ser intercepted (Wi-Fi malicioso). Todas estas premissas mudam o que é "seguro".

## Princípios fundamentais

1. **App é executada em ambiente hostil.** O cliente é o atacante.
2. **Tudo no APK/IPA é público.** Qualquer secret embedded é game over.
3. **Storage local não é privado.** Mesmo Keychain/Keystore tem limites em devices comprometidos.
4. **Network requires pinning.** TLS sozinho não chega contra MITM bem feito.
5. **Backend é a verdade.** Nunca confiar em validação client-side.

## OWASP MASVS (Mobile App Security Verification Standard)

A skill alinha-se com **MASVS v2** da OWASP. Resumo dos controlos:

| Categoria | Conteúdo |
|---|---|
| **MASVS-STORAGE** | Storage de dados sensíveis (Keychain, Keystore, EncryptedSharedPreferences) |
| **MASVS-CRYPTO** | Uso correto de crypto (não roll-your-own) |
| **MASVS-AUTH** | Autenticação, sessões, biometria |
| **MASVS-NETWORK** | TLS, cert pinning, ATS/NSC |
| **MASVS-PLATFORM** | IPC, deeplinks, intents, WebView |
| **MASVS-CODE** | Code quality, debug code, third-party SDKs |
| **MASVS-RESILIENCE** | Anti-tampering, jailbreak/root detection, ofuscação |
| **MASVS-PRIVACY** | PII handling, consent, data minimization |

## Estrutura desta track

```
mobile/
├── 00-mindset-mobile.md           ← postura específica mobile
├── 00-masvs-mapping.md            ← mapa MASVS → módulos
├── ios-native.md                  ← Swift/Objective-C
├── android-native.md              ← Kotlin/Java
├── react-native.md                ← RN bridges, AsyncStorage
├── flutter.md                     ← Dart, plataform channels
├── xamarin-maui.md                ← .NET MAUI
├── ionic-cordova-capacitor.md     ← Hybrid (WebView)
├── armazenamento-local.md         ← Storage seguro multi-platform
├── comunicacao-rede.md            ← TLS pinning, ATS, NSC
├── deeplinks-intents.md           ← URL schemes, App Links, Intent filters
├── webview.md                     ← WebView security
├── biometria-secure-enclave.md    ← Hardware-backed auth
├── jailbreak-root-tampering.md    ← Detect + react
├── reverse-engineering.md         ← Frida, Hopper, jadx, mitigação
└── store-distribution.md          ← Code signing, Play Integrity, App Attest
```

## Quando carregar esta track

- Projeto contém `Info.plist` (iOS), `AndroidManifest.xml` (Android)
- `package.json` com `react-native`, `@expo/`
- `pubspec.yaml` com Flutter
- `*.csproj` com `Xamarin.Forms`, `Microsoft.Maui`
- `config.xml` com Cordova/Capacitor
