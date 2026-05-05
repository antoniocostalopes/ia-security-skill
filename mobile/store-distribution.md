# Store / Distribution Security

> Cada app passa por App Store ou Play Store. Cada store tem políticas de segurança. Aproveitar — eles fazem checks que tu não fazes.

## Code signing

### iOS
- **Obrigatório** — App Store rejeita sem signing.
- **Distribution certificate** + **Provisioning profile**.
- Renovações automáticas via Apple Developer.
- Verificar `entitlements.plist` corresponde ao necessário.

### Android
- **Obrigatório** desde sempre.
- **App Signing by Google Play** (recomendado) — Google guarda upload key + signing key.
- **Backup keystore offline** + multiple admins com acesso.
- **Key rotation** difícil — investir tempo em proteger keys originais.

```bash
# Verificar APK signing
apksigner verify --print-certs app.apk
# Output deve ter: Signed with v1, v2, v3 schemes (preferível)
```

## App Store Review

### iOS
- App passa por review humano (~1-3 dias).
- Reject reasons comuns:
  - Background activity sem justificação
  - Permissions não usadas
  - Encryption sem ITSAppUsesNonExemptEncryption
  - Use of private APIs
  - Missing privacy policy URL
  - Data Safety form incomplete (iOS 14+)

### Android
- Play Protect scan (automated).
- Manual review para algumas categorias (banking, financial, health).
- Reject reasons:
  - Permissions excessivas
  - Sensitive permissions sem declared use
  - Manifest issues
  - Target SDK desatualizado

## Privacy Manifest (iOS 17+)

```xml
<!-- PrivacyInfo.xcprivacy -->
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array><string>CA92.1</string></array>
        </dict>
    </array>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeEmailAddress</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array><string>NSPrivacyCollectedDataTypePurposeAccountManagement</string></array>
        </dict>
    </array>
</dict>
```

## Play Data Safety form

Obrigatório para todas as apps Android. Declarar:
- Que dados coletas
- Como usas
- Se partilhas com terceiros
- Práticas de segurança (encryption in transit, ability to delete)

## Permissions — declarar e justificar

### iOS
```xml
<!-- Cada permission precisa de purpose string clara -->
<key>NSCameraUsageDescription</key>
<string>Para tirar fotos de perfil. Não acedemos sem ação tua.</string>

<key>NSContactsUsageDescription</key>
<string>Para sugerir amigos. Os contactos são processados localmente.</string>
```

### Android
```xml
<!-- Cada permission requer declaration + runtime request (API 23+) -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Sensitive permissions também precisam de declaration no Play Console -->
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<!-- → Play Console: declare sensitive permission usage -->
```

## App Attest / Play Integrity — backend verification

Coberto em `jailbreak-root-tampering.md`.

```
Cada request crítico:
1. App gera attestation token
2. Envia para backend com request
3. Backend valida com Apple/Google
4. Se inválido → recusa request
```

## Update strategy

### Force update
```kotlin
// Verificar versão minima vs atual
val minVersion = remoteConfig.getString("min_version")
val currentVersion = BuildConfig.VERSION_NAME
if (compareVersions(currentVersion, minVersion) < 0) {
    showForceUpdateDialog()
}
```

> Para vulnerabilidades críticas: force update + reject API requests de versões antigas.

### Rollback strategy
- Manter staged rollout (Android: 5% → 10% → 50% → 100%).
- Ability to halt rollout se issues detected.
- Server-side feature flags para disable features quebradas sem app update.

## Beta testing

### iOS — TestFlight
- Public link para até 10000 testers.
- Internal: até 100 testers no team.
- Builds expiram após 90 dias.

### Android — Internal/Closed/Open testing
- Internal: até 100 testers
- Closed: convidados específicos
- Open: público

## Secrets em build pipeline

```yaml
# GitHub Actions — secrets
env:
  KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
  PRIVATE_KEY: ${{ secrets.IOS_PRIVATE_KEY }}

# NUNCA echo de secrets nos logs
# NUNCA commit de keystore.jks
```

```bash
# .gitignore
*.jks
*.keystore
*.p12
*.p8
google-services.json   # se contém configs sensíveis
GoogleService-Info.plist  # idem
fastlane/.env*
```

## Common antipatterns

### Keystore commitado no git
- Compromete a app **para sempre**. Atacante assina malware com a tua key.

### Distribution profile com `*` em wildcard
- Permite empacotar qualquer app com o teu certificate.

### `targetSdkVersion` desatualizado
- Play Store rejeita uploads com targetSdk antigo.
- Apps com targetSdk antigo perdem features de segurança novas.

### Privacy manifest / Data Safety incompleto
- Reject pelo store.
- Mais importante: violação de regulação (GDPR, CCPA).

### Sem version check no backend
- Users com versões vulneráveis continuam a usar a app.

### Beta builds com debug habilitado em prod
- TestFlight builds ainda têm que ser production-grade.

### Force update sem fallback de comunicação
- Se app crashes em update, user não consegue update.

## Quick wins

- [ ] Code signing correto (App Store / Play Store)
- [ ] Keystore Android backed up offline (não commit)
- [ ] App Signing by Google Play habilitado
- [ ] iOS Distribution certificate gerido por team account (não pessoal)
- [ ] Privacy manifest (iOS 17+) preenchido corretamente
- [ ] Play Data Safety form preenchido
- [ ] Permissions justificadas em Info.plist / declared no Play Console
- [ ] `targetSdkVersion` no latest stable
- [ ] App Attest / Play Integrity para attestation server-side
- [ ] Version check no backend (force update se vulnerable)
- [ ] Staged rollout estratégia
- [ ] Server-side feature flags para kill switches
- [ ] Beta testing antes de production rollout
- [ ] Secrets em CI/CD via env vars / vaults (não git)
- [ ] `.gitignore` cobre keystore, .p12, .p8, GoogleService-Info.plist
- [ ] Bug reporting + crash reporting (sem PII) — Sentry, Firebase Crashlytics
- [ ] Política de resposta a vulnerabilidades reportadas (security@meusite.tld)
