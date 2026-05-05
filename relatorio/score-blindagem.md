# Score e Nível de Blindagem

## Fórmula

```
score = 100
score -= 20 × nº de achados Críticos
score -= 10 × nº de achados Altos
score -=  4 × nº de achados Médios
score -=  1 × nº de achados Baixos
score = max(0, score)
```

> Suspeitas (sem confirmação) **não** entram no cálculo. Mencionar à parte.

## Escala de blindagem

| Score | Nível | Cor / Tag | Recomendação |
|---:|---|---|---|
| 90–100 | **Blindado** | Verde | Pode ir a produção. Manter auditorias periódicas. |
| 76–89 | **Sólido** | Verde-claro | Correções menores recomendadas. Pode publicar com plano. |
| 61–75 | **Aceitável** | Amarelo | Corrigir Altos antes de produção. |
| 41–60 | **Vulnerável** | Laranja | Bloquear deploy até correções. |
| 21–40 | **Frágil** | Vermelho | Refactor de segurança necessário. |
|  0–20 | **Crítico** | Vermelho-escuro | **NÃO PUBLICAR.** Risco inaceitável. |

## Severidade — guia

### Crítico (-20)
Exploração remota não autenticada que leva a **um destes**:
- RCE (execução remota de código)
- Acesso completo à BD
- Tomada de conta (account takeover) de admin ou utilizadores
- Exposição de credenciais de produção
- Webhook de pagamento manipulável

### Alto (-10)
Requer baixo nível de auth ou condição comum:
- XSS armazenado visível por outros utilizadores
- IDOR de PII
- CSRF em ação destrutiva
- SQLi em endpoint admin
- Upload sem validação de tipo
- CORS misconfigurado em endpoint autenticado
- Falta de rate limit em login

### Médio (-4)
Impacto limitado ou exploração mais difícil:
- XSS DOM com pré-requisitos
- Exposição de versões de software
- User enumeration
- Mensagens de erro verbose
- Ausência de headers de segurança
- Logs com dados sensíveis (acesso interno)

### Baixo (-1)
Defesa em profundidade, boas práticas:
- Headers a otimizar
- Falta de `X-Frame-Options` em página não sensível
- Cookies sem `SameSite=Strict` quando `Lax` chega
- Documentação interna acessível

## Visualização (barra de progresso ASCII)

```
score 90+   [████████████████████]  Blindado
score 76-89 [████████████████░░░░]  Sólido
score 61-75 [█████████████░░░░░░░]  Aceitável
score 41-60 [██████████░░░░░░░░░░]  Vulnerável
score 21-40 [█████░░░░░░░░░░░░░░░]  Frágil
score 0-20  [██░░░░░░░░░░░░░░░░░░]  Crítico
```

Para gerar a barra:
- Cada bloco `█` = 5 pontos (20 blocos no total).
- `n_blocos = round(score / 5)`.

## Exemplos

| Achados | Cálculo | Score | Nível |
|---|---|---:|---|
| 0 críticos, 0 altos, 0 médios, 2 baixos | 100 - 2 | 98 | Blindado |
| 0 / 1 / 3 / 5 | 100 - 10 - 12 - 5 | 73 | Aceitável |
| 1 / 2 / 4 / 3 | 100 - 20 - 20 - 16 - 3 | 41 | Vulnerável |
| 3 / 5 / 8 / 10 | 100 - 60 - 50 - 32 - 10 | 0 | Crítico |
