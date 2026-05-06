# Game Security — Segurança

> Multiplayer games, IAP fraud, anti-cheat, save game tampering, telemetria. Indústria com fraud volume gigante e modelos de receita expostos a manipulação.

## Quando carregar

- Unity (`*.unity` scenes, `Assets/`)
- Unreal Engine (`.uproject`, `Source/`)
- Godot (`project.godot`)
- Multiplayer netcode (Mirror, Photon, FishNet, Unreal replication)
- IAP (`StoreKit`, `BillingClient`, `UnityIAP`)
- Backend para multiplayer (Nakama, PlayFab, GameLift, AccelByte)

## Mindset

- **Client é hostil** — qualquer dado do client é manipulável
- **Cheaters são profissionais** — Cheat Engine, x64dbg, IDA, Wireshark
- **Real money = motivation** — IAP fraud, RMT (real money trading), gold farming
- **Trust layers:** game client (untrusted) → game server (trusted) → backend (trusted)
- **Anti-cheat reativo, não preventivo** — bans pós-detection, não prevenção 100%

## 8 categorias

### 1. Game logic no client (autoritative client)

**BAD** — client decide damage:
```csharp
// Unity client
void OnHit(Player target) {
    int damage = weapon.damage;
    target.Health -= damage;
    NetworkClient.Send(new DamageMessage(target.id, damage));
}
```

Cheater set `weapon.damage = 9999`. Server aceita.

**GOOD** — server-authoritative:
```csharp
// Server
void OnDamageMessage(NetworkConnection conn, DamageMessage msg) {
    Player attacker = conn.identity.GetComponent<Player>();
    Player target = FindPlayer(msg.targetId);

    // Server valida: range, line of sight, weapon owned, cooldown
    if (!CanHit(attacker, target)) return;

    int actualDamage = attacker.weapon.damage;  // server knows real
    target.Health -= actualDamage;
    NetworkServer.SendToAll(new HealthUpdateMessage(target.id, target.Health));
}
```

### 2. Speedhack / movement validation ausente

**BAD** — server aceita posição do client:
```csharp
[Command]
void CmdUpdatePosition(Vector3 newPos) {
    transform.position = newPos;  // teleport possível
}
```

**GOOD** — server valida velocidade:
```csharp
[Command]
void CmdUpdatePosition(Vector3 newPos) {
    float distance = Vector3.Distance(transform.position, newPos);
    float maxDistance = maxSpeed * Time.fixedDeltaTime * 1.1f;  // 10% tolerance

    if (distance > maxDistance) {
        // Reject + reset client
        TargetForcePosition(connectionToClient, transform.position);
        return;
    }

    transform.position = newPos;
}
```

### 3. Save game tampering

Single-player save file edição com hex editor:
```
gold: 100  →  gold: 9999999
```

**Mitigação:**
- HMAC do save com chave embedded (nem sempre seguro, mas raises bar):
```csharp
string hmac = HmacSha256(saveData, secretKey);
File.WriteAllText("save.dat", $"{saveData}|{hmac}");

// Load:
var (data, expectedHmac) = ParseSave("save.dat");
if (HmacSha256(data, secretKey) != expectedHmac) {
    Debug.LogWarning("Save tampering detected");
    return;
}
```

**Limitações:** secretKey está no binário. Reverse engineer extrai. Mas reduz casual cheating.

- Cloud save (Steam Cloud, PlayFab) com server-authoritative state — ideal mas custoso
- Honor system para single-player — talvez OK aceitar tampering

### 4. IAP receipt validation

**BAD** — confiar no client:
```csharp
void OnPurchaseComplete(Product product) {
    GiveItemToPlayer(product.definition.id);
    // sem validação do receipt
}
```

Cheater envia fake purchase event. Recebe item gratuito.

**GOOD** — validar receipt no server:
```csharp
// Client envia receipt para o teu server
StartCoroutine(VerifyPurchase(product.receipt, product.definition.id));

IEnumerator VerifyPurchase(string receipt, string productId) {
    var request = UnityWebRequest.Post("/api/iap/verify", new Dictionary<string, string> {
        { "receipt", receipt },
        { "productId", productId }
    });
    yield return request.SendWebRequest();

    if (request.responseCode == 200) {
        // Server confirmou com Apple/Google/Steam
        GiveItemToPlayer(productId);
    }
}
```

E no server:
```python
# Verificar com Apple App Store
response = requests.post('https://buy.itunes.apple.com/verifyReceipt', json={
    'receipt-data': base64_receipt,
    'password': APP_STORE_SHARED_SECRET
})
result = response.json()
if result['status'] == 0:
    # Verificar product_id matches, não foi consumed antes
    grant_item_to_user(user_id, product_id)
```

### 5. Anti-cheat layers

#### Memory protection
```csharp
// Encrypt valores críticos em memória
[Serializable]
public struct ProtectedInt {
    private int _xored;
    private int _key;

    public int Value {
        get => _xored ^ _key;
        set {
            _key = Random.Range(int.MinValue, int.MaxValue);
            _xored = value ^ _key;
        }
    }
}

ProtectedInt gold = new ProtectedInt { Value = 100 };
```

Cheat Engine procura `100` em RAM — não encontra direto.

#### Detect speedhack
```csharp
float lastFrameTime = Time.realtimeSinceStartup;

void Update() {
    float now = Time.realtimeSinceStartup;
    float realDelta = now - lastFrameTime;
    float gameDelta = Time.deltaTime;

    if (Math.Abs(realDelta - gameDelta) > 0.05f) {
        // Possible speedhack
        ReportSuspiciousActivity();
    }
    lastFrameTime = now;
}
```

#### Commercial anti-cheat
Para games competitivos: BattlEye, Easy Anti-Cheat (EAC), Vanguard. Kernel-level (intrusivo, mas eficaz). Hot debate sobre privacy.

### 6. RMT / botting / multi-account

Detecção:
- Behavior analysis: clicks per minute, patterns repetitivos, rota fixa
- IP reputation (datacenter IPs = bots)
- Device fingerprinting
- Phone verification para account creation
- Hardware bans para reincidentes (HWID + serial)

**Server-side:**
- Rate limit ações in-game (kill 1000 mobs em 1h é suspeito)
- Trade limits para new accounts
- Currency sinks (forçar gasto = drena gold farming economy)

### 7. Network packet manipulation

Wireshark + custom proxy = packet replay/modify.

**Mitigação:**
- TLS para todo o tráfego (não TCP plain)
- Sequence numbers + signatures (HMAC) em packets críticos
- Encryption layer custom (defesa em profundidade)
- Detect replay: nonce + window timing

### 8. UGC (User Generated Content) malicioso

Mods, custom maps, scripts de jogador:
```lua
-- Custom Lua mod
os.execute("rm -rf ~/")  -- RCE no client
```

**Mitigação:**
- Sandboxed scripting language (não native Lua)
- API limitada (sem `os`, `io`, `socket`)
- Code review para mods featured
- User opt-in para "untrusted" mods com warning claro

## Quick wins

- [ ] Server-authoritative para todo gameplay-critical state
- [ ] Movement validation com max speed checks
- [ ] IAP receipts validados server-side com Apple/Google/Steam
- [ ] Save files com HMAC (single player; redundante para cloud save)
- [ ] Rate limit no server: actions per minute, trades per hour
- [ ] Phone verification ou email verification para new accounts
- [ ] TLS em todos os endpoints (clients + admin)
- [ ] Anti-cheat sob measurement (false positive rate baixo)
- [ ] Memory protection para valores críticos in-client
- [ ] Detection de speedhack via time comparison
- [ ] Logging server-side de ações suspeitas (não só visíveis ao player)
- [ ] Behavioral analytics dashboards (gold gain rate, kills/hour)
- [ ] Soft bans (shadowban, queue separation) antes de hard bans
- [ ] Appeal process para false positives
- [ ] UGC sandboxed
- [ ] Trade window com limites para new accounts
- [ ] Currency sinks no design económico

## Falsos positivos

- Player legítimo com latency alto pode parecer speedhack — calibrar threshold
- IAP testers (Apple sandbox, Google test track) — endpoint diferente para validation
- Pro players têm APM (actions per minute) altíssimo — ajustar threshold por skill bracket

## Severidade típica

- **Crítico** — IAP sem validação server-side, gameplay 100% client-authoritative em PvP, save game tampering em competitive online
- **Alto** — speedhack viável sem detection, RMT sem behavioral analytics, UGC com native scripting
- **Médio** — anti-cheat ausente em F2P competitivo, sem device fingerprinting
- **Baixo** — falta de phone verification, sem currency sinks

## Cross-references

- [`../analises/permissoes.md`](../analises/permissoes.md) — autorização base
- [`../analises/14-autenticacao-sessao.md`](../analises/14-autenticacao-sessao.md)
- [`../analises/18-business-logic-race.md`](../analises/18-business-logic-race.md) — logic flaws
- [`../analises/21-dos-resource-limits.md`](../analises/21-dos-resource-limits.md) — DDoS de game servers
- [`../mobile/`](../mobile/) — para mobile games

## Recursos

- [OWASP Game Security](https://owasp.org/www-project-game-security-framework/)
- [Apple StoreKit Server Notifications](https://developer.apple.com/documentation/appstoreservernotifications)
- [Google Play Real-time Developer Notifications](https://developer.android.com/google/play/billing/rtdn-reference)
