# Xamarin / .NET MAUI — Segurança

> .NET cross-platform language patterns em `linguagens/csharp-dotnet.md`. Foco aqui no MAUI/Xamarin specific.

## Storage — secrets

```csharp
// BAD — Preferences plain
Preferences.Set("token", jwt);

// GOOD — SecureStorage (Keychain iOS, KeyStore Android)
await SecureStorage.SetAsync("token", jwt);
var token = await SecureStorage.GetAsync("token");
```

## Network — cert pinning

```csharp
var handler = new HttpClientHandler {
    ServerCertificateCustomValidationCallback = (msg, cert, chain, errors) => {
        var fingerprint = cert!.GetCertHashString(HashAlgorithmName.SHA256);
        return ALLOWED_FINGERPRINTS.Contains(fingerprint);
    }
};
var client = new HttpClient(handler);
```

## Biometric

```csharp
// Plugin.Fingerprint or MAUI Essentials wrapper
var available = await CrossFingerprint.Current.IsAvailableAsync();
if (!available) return;

var auth = await CrossFingerprint.Current.AuthenticateAsync(
    new AuthenticationRequestConfiguration("Auth", "Authenticate to continue"));
if (auth.Authenticated) {
    // unlock
}
```

## WebView

```xml
<WebView
    Source="{Binding Url}"
    Navigating="OnNavigating">
</WebView>
```

```csharp
private void OnNavigating(object sender, WebNavigatingEventArgs e) {
    if (!e.Url.StartsWith("https://meusite.tld/")) {
        e.Cancel = true;
    }
}
```

## Common antipatterns

### `Preferences` para tokens
- Plain text. Usar `SecureStorage`.

### Hardcoded API keys em `App.xaml.cs`
- Visível em IL/decompile (ILSpy, dnSpy).

### `WebView.Source` direto com input
- Open link arbitrário.

### `HttpClient` sem timeout / sem cert validation
- DoS / MITM.

### `Application.Current.Properties` para secrets
- Same as Preferences — plain text.

### Logging com PII
- Logcat / Console acessível.

## Quick wins

- [ ] .NET 8 + MAUI
- [ ] `SecureStorage` para credenciais
- [ ] Cert pinning para APIs críticas
- [ ] WebView com URL allowlist
- [ ] Biometric para operações sensíveis
- [ ] Sem secrets em código
- [ ] HttpClient com Timeout
- [ ] AssemblyHelper / linker config para reduzir bundle
- [ ] Code obfuscation (Dotfuscator, ConfuserEx) para apps de alto risco
- [ ] Disable debug logs em release
- [ ] Permissions mínimas em `Info.plist` / `AndroidManifest.xml`
- [ ] Plus: ver `linguagens/csharp-dotnet.md` para C# specific
