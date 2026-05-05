# WebView Security

> WebView é a porta para o mundo web dentro da app. Mal configurada = XSS na web vira RCE no nativo via JS bridge.

## Princípios

1. **Trust model**: Conteúdo dentro da WebView é hostil ou semi-confiável.
2. **JS Bridges são RCE wrappers**: cada `addJavascriptInterface` / `WKScriptMessageHandler` é potencial RCE.
3. **WebView não é browser**: tem privilégios elevados (file://, IPC com app).
4. **Mixed content é ataque**: HTTPS page carregando HTTP recursos = MITM.

## Android — `WebView` config segura

```kotlin
val webView = WebView(context)

webView.settings.apply {
    // JavaScript: desligar se não necessário
    javaScriptEnabled = false  // se true, é necessário, mas atenção a XSS

    // File access: NUNCA true em prod
    allowFileAccess = false
    allowFileAccessFromFileURLs = false  // deprecated mas verificar
    allowUniversalAccessFromFileURLs = false
    allowContentAccess = false

    // Mixed content: bloquear
    mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW

    // Dom storage: desligar se não necessário
    domStorageEnabled = false

    // Database: desligar (deprecated)
    databaseEnabled = false

    // Geolocation: prompt sempre
    setGeolocationEnabled(false)

    // User agent: customizar para identificar tráfego de app
    userAgentString = "MyApp/1.0 ${userAgentString}"
}

// SafeBrowsing (API 27+)
WebView.setSafeBrowsingEnabled(true)

// Bloquear navegação para outros sites
webView.webViewClient = object : WebViewClient() {
    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
        val url = request?.url.toString()
        if (!url.startsWith("https://meusite.tld/")) {
            // Open externally instead
            view?.context?.startActivity(Intent(Intent.ACTION_VIEW, request?.url))
            return true
        }
        return false
    }
}
```

## iOS — `WKWebView` config segura

```swift
let config = WKWebViewConfiguration()

// JS: configurar
let prefs = WKWebpagePreferences()
prefs.allowsContentJavaScript = false  // se possível
config.defaultWebpagePreferences = prefs

config.preferences.javaScriptCanOpenWindowsAutomatically = false

// Media
config.allowsAirPlayForMediaPlayback = false
config.allowsInlineMediaPlayback = false
config.mediaTypesRequiringUserActionForPlayback = .all

// User Content Controller — JS interop
let userController = WKUserContentController()
config.userContentController = userController

let webView = WKWebView(frame: .zero, configuration: config)

// Delegate para validar navegação
webView.navigationDelegate = self  // implementa decidePolicyFor

// Carregar URL com validação
guard let host = url.host,
      ALLOWED_HOSTS.contains(host),
      url.scheme == "https" else { return }
webView.load(URLRequest(url: url))
```

```swift
// Decision para cada navegação
extension MyVC: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel); return
        }
        if url.scheme != "https" || url.host != "meusite.tld" {
            // Abrir external
            UIApplication.shared.open(url)
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
}
```

## JS Bridges — extremamente perigoso

### Android — `addJavascriptInterface`

```kotlin
// API 17+ requer @JavascriptInterface annotation
class JsBridge {
    @JavascriptInterface
    fun login(email: String, token: String) {
        // VALIDAR email format, token format
        if (!isValidEmail(email)) return
        if (!isValidToken(token)) return
        // ...
    }

    // BAD — método sem annotation expõe TUDO via reflection
    fun executeAnything(input: String) { ... }  // bypass via Object.method
}

webView.addJavascriptInterface(JsBridge(), "AndroidBridge")
// JS chama: AndroidBridge.login("user@x", "abc...")
```

### iOS — `WKScriptMessageHandler`

```swift
class JsBridge: NSObject, WKScriptMessageHandler {
    func userContentController(_ uc: WKUserContentController,
                               didReceive msg: WKScriptMessage) {
        // Validar source frame (anti-spoofing)
        guard msg.frameInfo.securityOrigin.host == "meusite.tld" else { return }

        // Validar tipo
        guard let body = msg.body as? [String: Any] else { return }
        guard let action = body["action"] as? String else { return }

        // Allowlist de actions
        switch action {
        case "login":
            guard let email = body["email"] as? String,
                  let token = body["token"] as? String,
                  isValidEmail(email), isValidToken(token) else { return }
            handleLogin(email: email, token: token)
        default:
            return
        }
    }
}

userController.add(JsBridge(), name: "appBridge")
// JS: window.webkit.messageHandlers.appBridge.postMessage({ action: "login", ... })
```

## Common antipatterns

### `javaScriptEnabled = true` por defeito
- Se WebView só mostra HTML estático local, JS desnecessário.

### `loadUrl(userInput)` direto
- Open redirect, file:// access, javascript: scheme.

### `addJavascriptInterface` sem `@JavascriptInterface` annotation (API < 17)
- Reflection RCE clássico (CVE-2012-6636).

### `setAllowFileAccessFromFileURLs(true)`
- file:// pode aceder a outros file://, leitura arbitrária.

### Mixed content allowed
- HTTPS page → HTTP request → MITM.

### WebView com cookies partilhados com browser
- `CookieManager.getInstance()` — cuidado com partilha.

### `evaluateJavaScript(input)`
- Executa JS arbitrário. Equivalente a eval.

### File:// URI loading com input
- `webView.loadUrl("file://" + userPath)` → leitura arbitrária.

### Bridge methods com `Object`/`Any` parameter
- Atacante envia tipo errado, crash ou bypass.

### Não validar `securityOrigin` em messages (iOS)
- Subframe malicioso pode enviar mensagens.

## Quick wins

- [ ] `javaScriptEnabled = false` se não estritamente necessário
- [ ] `allowFileAccess*` = false em prod
- [ ] `mixedContentMode = NEVER_ALLOW`
- [ ] URL allowlist no `shouldOverrideUrlLoading` / `decidePolicyFor`
- [ ] HTTPS-only no scheme check
- [ ] JS bridges com schema validation strict
- [ ] `@JavascriptInterface` annotation em todos os métodos expostos
- [ ] Validar `securityOrigin` em iOS message handlers
- [ ] Sem `evaluateJavaScript(input)` com input
- [ ] SafeBrowsing ativo (Android API 27+)
- [ ] Custom UserAgent para identificar
- [ ] Cookies isolados (não partilhar com browser do device)
- [ ] Disable `domStorage`/`database` se não necessário
- [ ] Geolocation prompt sempre
