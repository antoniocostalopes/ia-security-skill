# Template do Relatório

> Usa este template **literalmente**. Substitui placeholders `<...>` mas mantém títulos, ordem e formatação.

---

````markdown
# Relatório de Segurança — <NOME DO PROJETO>

**Data:** <YYYY-MM-DD>
**Auditor:** <IA / nome>
**Stack:** <PHP X.Y / WordPress X.Y / Node Z / etc.>
**Ficheiros analisados:** <N>
**Linhas de código:** <N> (aprox.)

---

## 1. Score de Segurança

```
Score: <N>/100
[████████████░░░░░░░░] <N>%
```

**Nível de blindagem:** **<NÍVEL>**

| Severidade | Quantidade | Peso unitário | Subtotal |
|---|---:|---:|---:|
| Crítico | <n> | -20 | -<n*20> |
| Alto    | <n> | -10 | -<n*10> |
| Médio   | <n> |  -4 | -<n*4> |
| Baixo   | <n> |  -1 | -<n*1> |
| **Total** | **<N>** | | **-<S>** |

> Cálculo: `100 - (Críticos×20 + Altos×10 + Médios×4 + Baixos×1)`, mínimo 0.

---

## 2. Resumo para o Cliente

> Tom amigável e honesto: nem alarmismo, nem complacência. Mostra estado, esforço, caminho. Encoraja com factos, não com platitudes.

<Bloco de 3 a 5 frases em linguagem não técnica:
- Estado atual em uma frase clara (ex.: *"O site está bem na maior parte, mas tem 2 buracos importantes que dão acesso a contas de outros utilizadores"*).
- Principal risco em linguagem que cliente entende (sem CWE, sem CVSS).
- Esforço estimado em horas/dias humanos (*"meio dia de trabalho"*, *"um sprint"*).
- Recomendação clara e direta: **Pode publicar** / **Corrigir antes** / **NÃO publicar agora**.
- Frase de encorajamento honesto se aplicável: *"Tens 3 críticos mas todos com fix simples — meio dia ficas blindado"*.>

---

## 3. Resumo Técnico

> Para developers. Direto, sem jargão desnecessário, focado em padrões e fixes.

<5 a 10 linhas:
- Padrões problemáticos recorrentes (*"Falta de `current_user_can` em 5 endpoints — copy-paste do mesmo template inseguro"*).
- Áreas mais frágeis (que ficheiro/módulo concentra os problemas).
- Dívida técnica de segurança.
- Dependências a atualizar.
- Recomendação arquitetural se houver padrão sistémico.>

---

## 4. Mapa de Superfícies de Ataque

| # | Superfície | Localização | Auth | Exposição | Risco |
|---|---|---|---|---|---|
| 1 | REST endpoint | `/wp-json/x/v1/<rota>` | Nonce / Bearer / Nenhuma | Pública / Logged / Admin | Alto / Médio / Baixo |
| 2 | AJAX action | `wp_ajax_<nome>` | Nonce / Capability | Pública / Logged | ... |
| 3 | Webhook | `/webhook/<nome>` | HMAC / IP allowlist | Pública | ... |
| 4 | Form POST | `/wp-admin/admin-post.php?action=<x>` | Nonce | Logged / Admin | ... |
| 5 | Upload | `/wp-content/uploads/` | — | Pública (read) | ... |
| 6 | Cron job | `<callback>` | Internal | Internal | ... |
| 7 | CLI command | `wp <comando>` | Server access | Server | ... |

---

## 5. Previsão de Vetores Prováveis e Attack Chains

Baseado nos achados, estes são os vetores mais prováveis caso o código não seja corrigido. **Cada vetor mostra como achados individuais se combinam para escalar severidade.**

### Vetor 1 — <Nome>
- **Encadeia:** <C1> + <A2> + <M3>
- **Passos da exploração:**
  1. <passo 1>
  2. <passo 2>
  3. <passo 3>
- **Resultado:** <RCE / takeover / fraude / dump>
- **Probabilidade:** Alta / Média / Baixa
- **Impacto:** Crítico / Alto / Médio
- **Pré-requisitos:** <auth necessária ou nenhuma>
- **Tempo estimado de exploração:** <minutos / horas / dias>
- **Skill necessária:** baixa / média / alta
- **Detect/Log atual:** <silencioso / ruidoso / inexistente>

### Vetor 2 — <Nome>
<estrutura igual>

### Vetor 3 — <Nome>
<estrutura igual>

> **Mínimo 3 vetores.** Mesmo que algum tenha probabilidade baixa, listar demonstra a profundidade da análise. Ordenar por `Probabilidade × Impacto`.

---

## 6. Achados Detalhados

### Críticos

#### C1. <Título curto>
- **Categoria:** <XSS / SQLi / CSRF / Permissões / REST / AJAX / Upload / Tokens / Exposição / $wpdb / Sanitização / Webhooks>
- **CWE:** <CWE-XX> (opcional)
- **Localização:** `<ficheiro.php>:<linha>`
- **Código vulnerável:**
  ```php
  <trecho 3–10 linhas>
  ```
- **Explicação:** <porquê é vulnerável, em 2–4 linhas>
- **Exploração (PoC):**
  ```
  curl -X POST https://site.tld/... -d 'payload=<malicioso>'
  ```
- **Impacto:** <RCE / leitura de DB / tomada de conta / etc.>
- **Correção:**
  ```php
  <código corrigido>
  ```

#### C2. ...

---

### Altos

#### A1. <Título>
<estrutura igual a C1>

---

### Médios

#### M1. <Título>
<estrutura igual a C1, pode ser mais sucinta>

---

### Baixos

#### B1. <Título>
<estrutura igual, breve>

---

### Suspeitas (requerem verificação manual)

> Achados onde não há evidência suficiente para confirmar mas o padrão é suspeito.

- `<ficheiro:linha>` — <descrição da suspeita>

---

## 7. Plano de Correção por Fases

### Fase 1 — Imediata (24–48h) · BLOQUEIA DEPLOY
Resolve todos os **Críticos** antes de qualquer publicação.

- [ ] **C1** — <título>
- [ ] **C2** — <título>
- [ ] Validação por equipa
- [ ] Re-auditoria dos achados críticos

**Esforço estimado:** <N horas>

### Fase 2 — Curto prazo (1 semana)
Resolve os **Altos** e introduz hardening base.

- [ ] **A1** — <título>
- [ ] **A2** — <título>
- [ ] Adicionar nonces a todos os formulários
- [ ] Restringir `/wp-json/wp/v2/users`
- [ ] Definir headers de segurança HTTP

**Esforço estimado:** <N horas>

### Fase 3 — Médio prazo (2–4 semanas)
Resolve **Médios**, atualiza dependências, melhora observabilidade.

- [ ] **M1** — <título>
- [ ] Atualizar dependências com CVEs
- [ ] Implementar rate limiting global
- [ ] Logs de segurança + alertas

**Esforço estimado:** <N horas>

### Fase 4 — Hardening contínuo
Resolve **Baixos** e estabelece processo.

- [ ] **B1** — <título>
- [ ] WAF (Cloudflare / Wordfence / Sucuri)
- [ ] Backups automáticos com teste de restore
- [ ] Auditoria trimestral
- [ ] Política de rotação de chaves
- [ ] Formação da equipa em secure coding

---

## 8. Checklist Final Antes de Produção

> Anexar conteúdo de `relatorio/checklist-producao.md` aqui.

---

## 9. Recomendações Adicionais

- **Dependências a atualizar:** <lista>
- **Plugins/libs a substituir:** <lista>
- **Ferramentas recomendadas:** WPScan, PHPStan, Psalm, ESLint security plugin, npm audit, Snyk, Wordfence/Sucuri.
- **Próxima auditoria:** <data sugerida>

---

## 10. Anexos

- Lista de ficheiros analisados.
- Lista de ficheiros não analisados (com motivo).
- Versões de dependências relevantes.
````
