# Análise — Business Logic e Race Conditions

> Aqui é onde os scanners automáticos não chegam. Bugs de lógica de negócio e race conditions são a especialidade do hacker amigável — quase sempre dão fraude direta (dinheiro, cupões, stock).

## O que procurar

### Race conditions clássicos (TOCTOU — Time of Check / Time of Use)

#### Cupão de uso único
- "1 cupão por user, 10% off" → 100 requests paralelos usam o mesmo cupão 100×.

#### Saldo / wallet
- Verificar saldo → debitar em 2 passos sem lock → debitar 2× em paralelo.

#### Stock de produto
- "Resta 1 unidade" → comprado por 2 users em simultâneo.

#### Convites / códigos
- Código de convite single-use validado, depois consumido → consumido N×.

#### Reset de password
- Token validado, depois marcado como usado → usado para gerar 2 sessões.

#### Limite de tentativas
- "5 tentativas de login" → 100 paralelos passam todos.

#### Criação de conta
- "Email único" → 2 contas com mesmo email criadas em paralelo.

### Workflow bypass

- **Skip de passos**: checkout normal é `cart → endereço → pagamento → confirmação`. Atacante chama `/checkout/confirmar` direto, salta pagamento.
- **Replay de passos**: re-submeter `confirmar pagamento` com `order_id` antigo já entregue.
- **Estados inválidos**: forçar `order.status = 'paid'` por POST quando devia vir do gateway.
- **Reordering**: enviar passos por ordem inesperada (ex.: cancelar antes de pagar).

### Manipulação de preço / quantidade

- `?price=99.00` em parâmetro do produto (servidor confia)
- `quantity=-5` resulta em crédito (refund negativo)
- `discount=110%` aceito sem cap
- Carrinho com `total = sum(items)` calculado client-side e enviado
- Moeda alterada (`currency=USD` em vez de `EUR` — mantém o número, divide preço)
- IDs de produtos alterados a meio do checkout

### Limites lógicos

- Quantidade máxima por encomenda não verificada (`quantity=99999`)
- Múltiplos cupões aplicados quando devia ser 1
- Free trial registrado N× pelo mesmo email com `+alias` (`user+1@x.com`, `user+2@x.com`)
- Refund > valor pago
- Saque > saldo

### Privilege boundary tests

- "Apenas o dono edita" → edita ID `123` quando estás autenticado como user `456`
- "Apenas admin promove" → POST `role=admin` no endpoint `/profile`
- "Verificação de email obrigatória" → faz ações antes de confirmar email
- "MFA obrigatório para transferências" → envia transferência sem passar pelo challenge

### Idempotência ausente

- Webhook de pagamento processado N× → cobra/credita N× ao cliente
- Click duplo no botão "Pagar" → 2 cobranças
- Retry de network → ação executada 2×
- Falta de `idempotency_key` em endpoints state-changing

## Sinais de alarme

```php
// BAD — race condition em cupão
function aplicar_cupao($code, $user_id) {
    $cupao = $wpdb->get_row($wpdb->prepare(
        "SELECT * FROM cupoes WHERE code = %s AND used = 0", $code
    ));
    if (!$cupao) return false;

    // Janela de race: outro request pode passar aqui antes do UPDATE
    $wpdb->update('cupoes', ['used' => 1, 'used_by' => $user_id], ['id' => $cupao->id]);
    return true;
}

// GOOD — UPDATE atómico
function aplicar_cupao($code, $user_id) {
    global $wpdb;
    $afetadas = $wpdb->query($wpdb->prepare(
        "UPDATE cupoes SET used = 1, used_by = %d
         WHERE code = %s AND used = 0",
        $user_id, $code
    ));
    return $afetadas === 1; // exatamente 1 linha = sucesso
}
```

```php
// BAD — verificar saldo, depois debitar
function transferir($from_id, $to_id, $valor) {
    $saldo = get_saldo($from_id);
    if ($saldo < $valor) return false;
    debitar($from_id, $valor);     // race aqui
    creditar($to_id, $valor);
    return true;
}

// GOOD — transação + lock pessimista
function transferir($from_id, $to_id, $valor) {
    global $wpdb;
    $wpdb->query('START TRANSACTION');

    $row = $wpdb->get_row($wpdb->prepare(
        "SELECT saldo FROM contas WHERE id = %d FOR UPDATE",
        $from_id
    ));

    if (!$row || $row->saldo < $valor) {
        $wpdb->query('ROLLBACK');
        return false;
    }

    $wpdb->query($wpdb->prepare(
        "UPDATE contas SET saldo = saldo - %f WHERE id = %d",
        $valor, $from_id
    ));
    $wpdb->query($wpdb->prepare(
        "UPDATE contas SET saldo = saldo + %f WHERE id = %d",
        $valor, $to_id
    ));

    $wpdb->query('COMMIT');
    return true;
}
```

```php
// BAD — preço vem do cliente
function checkout() {
    $total = floatval($_POST['total']);
    cobrar_cliente($total);
}

// GOOD — calculado server-side
function checkout() {
    $cart = get_user_cart(get_current_user_id());
    $total = 0;
    foreach ($cart->items as $item) {
        $produto = get_post($item->product_id);
        $preco = (float) get_post_meta($produto->ID, 'preco', true);
        $total += $preco * $item->quantity;
    }
    cobrar_cliente($total);
}
```

```php
// Idempotência em webhook
function handle_payment_webhook($event) {
    global $wpdb;

    // Garantir que processamos cada evento UMA vez
    $inserted = $wpdb->query($wpdb->prepare(
        "INSERT IGNORE INTO webhook_events (event_id, processed_at)
         VALUES (%s, NOW())",
        $event->id
    ));

    if ($inserted === 0) {
        return; // já processado
    }

    // ... processar
}
```

```php
// Validação de quantidade
function adicionar_ao_carrinho($product_id, $qty) {
    $qty = intval($qty);
    if ($qty < 1)         return new WP_Error('qty_invalida', 'mínimo 1');
    if ($qty > 100)       return new WP_Error('qty_invalida', 'máximo 100');

    $stock = (int) get_post_meta($product_id, 'stock', true);
    if ($qty > $stock)    return new WP_Error('sem_stock', 'sem stock');

    // ...
}
```

## Como testar (pensar como hacker amigável)

Para cada fluxo financeiro/sensível, faz mentalmente:

1. **Replay**: chamo o endpoint final 2× — o que acontece?
2. **Skip**: chamo o passo final sem fazer os anteriores — o que acontece?
3. **Negate**: meto valores negativos — o que acontece?
4. **Overflow**: meto valores enormes (`999999999`) — o que acontece?
5. **Wrong-user**: chamo com ID de outro user — o que acontece?
6. **Parallel**: 100 requests simultâneos — o que acontece?
7. **Wrong-state**: chamo "confirmar" quando estado é "cancelado" — o que acontece?
8. **Wrong-order**: faço passos por ordem trocada — o que acontece?

Se a resposta a qualquer destes for *"hmm, não testei"* → adiciona aos achados.

## Detetar race conditions na prática

```bash
# Burp Suite: Turbo Intruder com 50 requests simultâneos
# ou simples com curl (Linux)

for i in $(seq 1 100); do
  curl -X POST https://meusite.tld/api/aplicar-cupao \
    -H "Cookie: session=..." \
    -d 'code=DESCONTO10' &
done
wait

# Verificar quantas vezes foi aplicado
```

Se o cupão for aplicado >1 vez → race condition confirmado.

## Quick wins (faz isto antes de entregar)

- [ ] Todos os cupões / códigos de uso único têm `UPDATE ... WHERE used = 0` atómico
- [ ] Operações de saldo / wallet com transação + `SELECT ... FOR UPDATE`
- [ ] Webhook handlers com idempotency key (deduplicação por `event_id`)
- [ ] Endpoints state-changing com `Idempotency-Key` header (recomendado para APIs)
- [ ] Quantidades validadas com `min`, `max`, sem negativos
- [ ] Preços / totais **sempre** calculados server-side, nunca aceites do cliente
- [ ] Estados de workflow validados (`if (order.status !== 'pending') reject()`)
- [ ] Para cada fluxo crítico, teste mental das 8 perguntas acima

## Falsos positivos
- Endpoints read-only não precisam de idempotency
- Operações naturalmente idempotentes (`PUT /resource/123` setting absolute state) — OK
- Race conditions teóricos com janela < 1ms em ações pouco críticas — anota mas baixa severidade

## Severidade — em linguagem honesta
- **Crítico:** race em pagamento / saldo / cupão de valor real → fraude direta
- **Crítico:** preço do produto manipulável pelo cliente → "compras" a 0.01€
- **Crítico:** workflow bypass que salta pagamento
- **Alto:** webhook sem idempotency em ação de cobrança
- **Alto:** quantidade negativa aceita (refund free)
- **Médio:** múltiplas trial accounts pelo mesmo user (abuso)
- **Médio:** click-duplo gera 2 ações (UX + financeiro)
