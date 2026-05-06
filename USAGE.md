# Como Usar — IA Security Skill

Guia completo de uso para developers. Cobre desde a primeira invocação até cenários avançados.

> **Para instalação**, ver [INSTALL.md](INSTALL.md).
> **Para exemplos completos** input → output, ver [examples/](examples/).

---

## Quick start (60 segundos)

Após [instalares](INSTALL.md) o adaptador da tua IA:

```
1. Abre o teu projeto
2. Diz à IA: "audita este projeto"
3. Recebes relatório em 30s com score + achados + fixes copy-paste
4. Aplica os fixes (manual ou pede à IA)
5. Re-corre: "audita de novo" → score sobe
6. Deploy com confiança
```

---

## Invocação por cliente

### Claude Code (CLI)

Após `git clone https://github.com/antoniocostalopes/ia-security-skill ~/.claude/skills/seguranca`:

Dentro de qualquer projeto, escreve no chat:
```
audita este projeto
```

Variantes que funcionam:
- `faz security review`
- `verifica vulnerabilidades`
- `audita o ficheiro server.js`
- `triagem rápida de segurança` (modo curto)

### Cursor / Windsurf

Após copiar `.cursorrules` ou `.cursor/rules/seguranca.mdc` para o projeto:

`Cmd+L` (Mac) ou `Ctrl+L` (Win) → escreve:
```
audit
```

ou:
```
@audit este código
```

### ChatGPT (Custom GPT)

Após criar Custom GPT com `PROMPT-COMPACTO.md` em Instructions e bundle em Knowledge:

No chat do Custom GPT, cola código ou anexa ficheiros e escreve:
```
audita este código
```

### GitHub Copilot Chat

Após copiar `PROMPT-COMPACTO.md` para `.github/copilot-instructions.md`:

No chat do Copilot (VS Code/JetBrains), com o ficheiro aberto:
```
@workspace audita este projeto
```

### Gemini / DeepSeek / Mistral / outros

1. Cola `PROMPT.md` inteiro como primeira mensagem
2. Em seguida, cola código a auditar
3. Pede:
```
audita este código aplicando a skill
```

### CLI standalone (`iass`)

Após setup do `cli-wrapper.sh`:

```bash
# Auditoria standard de um ficheiro
iass server.js

# Triagem rápida (só Críticos/Altos)
iass --quick app.py

# Auditar git diff atual (staged + unstaged)
iass --diff

# Auditar branch vs origin/main (típico para PRs locais)
iass --pr

# Gravar relatório em ficheiro
iass --output audit-report.md src/

# Auditar diretório inteiro
iass src/
```

---

## O que acontece nos bastidores

Quando dizes "audita este projeto", a IA executa um workflow estruturado de 8 fases:

```
┌─ Fase 1: Recon ────────────────────────────────────────
│  Lê manifests (package.json, composer.json, Cargo.toml,
│  Info.plist, AndroidManifest.xml, *.tf, *.sol, etc.)
│  → Deteta linguagens + frameworks + plataforma
│
├─ Fase 2: Carrega contexto (~30-50 ficheiros) ──────────
│  Sempre: analises/* (24 análises + meta files)
│  Per stack: linguagens/<lang>.md
│  Per framework: frameworks/<framework>.md
│  Se mobile: mobile/* (MASVS)
│  Se cloud/IaC/etc: outras-areas/<area>.md
│
├─ Fase 3: Análise universal (24 categorias) ────────────
│  Para cada categoria, 3 lentes:
│  1. Pattern matching (regex/keywords concretos)
│  2. Análise contextual (entender o flow)
│  3. Filter false positives (anti-hallucination)
│
├─ Fase 4: Análise específica (linguagem + framework) ───
│  Aplica antipatterns próprios do stack detetado
│
├─ Fase 5: Attack chains (mínimo 3) ─────────────────────
│  Cruza achados procurando combinações que escalam
│  severidade (ex.: enum + sem rate limit + msg distintas
│  → password spray)
│
├─ Fase 6: Self-review pass ─────────────────────────────
│  Para cada achado:
│  - Aplica filtro de falsos positivos
│  - Atribui confidence (95% / 80% / 60% / 40%)
│  - < 70% → reduz para "Suspeita"
│
├─ Fase 7: Gera relatório ────────────────────────────────
│  Markdown único no formato fixo do template
│
└─ Fase 8: Anexa checklist pré-produção ─────────────────
```

Tudo isto demora **20-60 segundos** consoante o tamanho do projeto e o modelo IA.

---

## O que recebes — anatomia do relatório

Markdown único com **10 secções obrigatórias na mesma ordem**:

### 1. Header
Nome do projeto, data, stack detetado, ficheiros analisados.

### 2. Score 0-100 + Nível de blindagem

```
Score: 73/100
[██████████████░░░░░░] 73%
Nível: Aceitável (corrige antes de produção)
```

| Score | Nível | Ação |
|---|---|---|
| 90-100 | **Blindado** | Pode publicar |
| 76-89 | **Sólido** | Correções menores |
| 61-75 | **Aceitável** | Corrigir antes de prod |
| 41-60 | **Vulnerável** | Bloquear deploy |
| 21-40 | **Frágil** | Refactor segurança |
| 0-20 | **Crítico** | **NÃO PUBLICAR** |

### 3. Resumo para Cliente
3-5 frases não-técnicas. Ex.: *"A app está bem na maior parte. Tens 2 problemas críticos que dão acesso a contas de outros utilizadores. Em meio dia ficas blindado para deploy."*

### 4. Resumo Técnico
5-10 linhas para devs com padrões problemáticos, áreas frágeis, dívida.

### 5. Mapa de Superfícies de Ataque
Tabela com endpoints, auth, exposição, risco.

### 6. Vetores Prováveis com Attack Chains
Mínimo 3 cenários de exploração realistas combinando achados.

### 7. Achados Detalhados
Cada um com:
- **Categoria** (uma das 24)
- **Severidade** (Crítico/Alto/Médio/Baixo)
- **Confiança** (95% / 80% / 60%) — após self-review
- **Localização** `ficheiro:linha`
- **Código vulnerável** (trecho)
- **Explicação** (porquê)
- **Exploração** (PoC realista)
- **Correção** (código copy-paste)

### 8. Plano de Correção em 4 Fases
- **Fase 1 — 24-48h** (BLOQUEIA DEPLOY): críticos
- **Fase 2 — 1 semana**: altos
- **Fase 3 — 2-4 semanas**: médios
- **Fase 4 — Hardening contínuo**: baixos + boas práticas

### 9. Checklist Final Pré-Produção
80+ itens checkbox por categoria (inputs, auth, headers, deps, operacional).

### 10. Recomendações Adicionais
Tools, deps a atualizar, próxima auditoria.

---

## Aplicar os fixes

### Manual (típico)
1. Abre o ficheiro indicado em "Localização"
2. Copia "Correção" do relatório
3. Substitui o código vulnerável
4. Repete para próximo achado

### IA aplica (mais rápido)
Após o relatório, escreve:
```
aplica os fixes Críticos
```

A IA gera diffs prontos. Aceitas/rejeitas cada um.

Variantes:
- `aplica os fixes Críticos e Altos`
- `aplica fix do achado C1`
- `gera PR com todos os fixes`

---

## Iteração — re-auditoria

Após aplicar fixes, valida:
```
audita de novo
```

Esperar:
```
Score: 88/100  (era 64)
Nível: Sólido (era Aceitável)
✓ C1 (SQL Injection) — RESOLVIDO
✓ A1 (Rate limit) — RESOLVIDO
✓ A2 (Tokens HttpOnly) — RESOLVIDO
○ M3 — ainda presente (médio, opcional)
```

Marcas o checklist final, fazes push.

---

## Cenários típicos

### Cenário 1 — Pré-deploy (developer solo)

Workflow no fim de cada feature, antes de `git push`:
```
1. Acabar feature
2. "audita este projeto antes do deploy"
3. Aplicar Críticos
4. Re-auditar
5. Score ≥ 76 (Sólido) → deploy
```

**Frequência:** ~1x por feature
**Tempo:** ~5-10 min total

### Cenário 2 — Code review de PR (team lead)

Em vez de leitura manual de PR:
```
1. Checkout da branch do PR
2. "audita as mudanças vs origin/main"
3. Comentar achados na PR
4. Approve ou request changes
```

**Frequência:** ~1x por PR
**Tempo:** ~3-5 min

### Cenário 3 — Triagem rápida (commit time)

Antes de cada commit:
```bash
$ git add .
$ git commit -m "..."

# Pre-commit hook corre automaticamente:
🛡️  IA Security Skill — auditando 3 ficheiro(s)...
🚨 Encontrou: 1 Crítico
   [Crítico] auth.js:18 — SQL Injection
   💡 Substituir por: db.query('... WHERE id = $1', [id])
❌ Commit bloqueado.
```

Developer corrige, re-tenta commit.

**Frequência:** automática em cada commit
**Tempo:** ~5-10s por commit

### Cenário 4 — Audit completo trimestral

Para projetos críticos:
```bash
iass src/ --output audit-Q2-2026.md
```

Report arquivado para compliance/governance.

**Frequência:** trimestral
**Tempo:** auditoria 5-15 min + ações

### Cenário 5 — Hybrid Semgrep + IA (máximo recall)

```bash
~/.iass/integracoes/semgrep-integration.sh ./src
```

Semgrep apanha padrões clássicos rapidamente, IA confirma + adiciona business logic.

**Frequência:** auditorias profundas (releases major)
**Tempo:** 5-10 min

---

## Integrações em CI/CD

### GitHub Actions (audit automático em PRs)

```bash
# 1. Copiar workflow
mkdir -p .github/workflows
cp ~/.iass/integracoes/github-action-pr-audit.yml .github/workflows/security-audit.yml

# 2. Adicionar secret no repo:
#    Settings → Secrets and variables → Actions → New repository secret
#    Name: ANTHROPIC_API_KEY
#    Value: sk-ant-...

# 3. Pronto. Cada PR é auto-auditado, comment publicado, blocking se Críticos.
```

### Pre-commit hook (bloqueio local)

```bash
ln -s ~/.iass/integracoes/pre-commit-hook.sh .git/hooks/pre-commit
export ANTHROPIC_API_KEY="sk-ant-..."  # adicionar ao ~/.bashrc

# Commits com Críticos ficam bloqueados
```

### CLI em scripts

```bash
# No teu deploy script:
iass --quick src/ || { echo "Vulnerabilidades detetadas"; exit 1; }
```

---

## Personas — quem usa e como

### Indie dev / Freelancer
- **Setup:** Claude Code + skill em `~/.claude/skills/`
- **Uso:** ad-hoc antes de entregar projeto a cliente
- **Custo:** ~$0.30 por auditoria (Claude API)
- **Valor:** evita entregar código vulnerável → menos problemas pós-entrega

### Time pequeno (3-10 devs)
- **Setup:** pre-commit hook em todos + GitHub Action global
- **Uso:** automatizado em commits e PRs
- **Custo:** ~$10-30/mês
- **Valor:** baseline de segurança sem dev pensar nisso

### Enterprise / Compliance
- **Setup:** Hybrid Semgrep + IA, audit reports arquivados
- **Uso:** trimestral + ad-hoc para releases major
- **Custo:** $50-200/mês (mais auditorias)
- **Valor:** evidência para auditores SOC 2 / ISO 27001

### Pentester white-box
- **Setup:** CLI standalone, multi-pass com personas diferentes
- **Uso:** primeira passagem antes de manual review profundo
- **Custo:** depende
- **Valor:** cobertura sistemática de 24 categorias antes de deep dive

---

## Diferença vs SAST tradicional

| Aspecto | SAST (Semgrep, Snyk, CodeQL) | IA Security Skill |
|---|---|---|
| **Tipo de bug** | Patterns AST/regex conhecidos | Patterns + business logic + chains |
| **Falsos positivos** | Frequentes mas previsíveis | Variável, mitigado por self-review |
| **Custom rules** | DSL própria (steep curve) | Markdown (qualquer dev) |
| **Output** | Lista de findings | Relatório com score + plano + fixes |
| **Velocidade** | Segundos | 30s-2min |
| **Custo** | Licença ou compute | Tokens IA (~$0.30/audit) |
| **Contextual** | Não | Sim (cross-file, business flow) |
| **Determinístico** | Sim | Não (varia entre invocações) |

**Verdicto típico:** *"Uso ambos. Semgrep no CI para regressões rápidas. Skill para reviews profundos antes de deploys e em PRs grandes."*

---

## Limitações honestas

### A skill NÃO é uma silver bullet
- Detecção depende do **modelo IA** (Claude 3.5 Sonnet > GPT-4 > Gemini > etc.)
- **Não é determinística** — mesma input pode dar outputs ligeiramente diferentes
- **Falsos positivos** existem mesmo com self-review
- **Falsos negativos** também (vulns muito subtis ou contextuais escapam)
- **Não substitui pen-test profissional** para apps críticas (banking, health)

### Comparação realista de detecção
```
Skill v1.1 sozinha:           ~85% recall, ~88% precision
Skill v1.1 + Semgrep hybrid:  ~95% recall, ~92% precision
Pen-test profissional:        ~98% recall, ~95% precision
```

### Quando NÃO usar a skill
- ❌ Pentest contra sistemas live ou de terceiros (sem autorização)
- ❌ Compliance auditing formal (SOC 2 audit) — usa ferramenta dedicada (Vanta, Drata)
- ❌ Resposta a incidente já ocorrido (usa SIEM, forense)
- ❌ Substituir audit profissional para apps críticas

### Quando usar
- ✅ Pre-deploy review do teu código
- ✅ Code review de PRs
- ✅ Triagem rápida em commit time
- ✅ Onboarding de developer junior em práticas seguras
- ✅ Primeiro filtro antes de pen-test profissional

---

## FAQ rápido

**Q: Funciona offline?**
A: Não. Precisa de IA (Claude/GPT/etc.) que usa API.

**Q: Funciona com modelos locais (Ollama, LM Studio)?**
A: Tecnicamente sim — colas o PROMPT.md como system prompt. Qualidade depende do modelo. Llama 3.1 70B+ é razoável; modelos < 7B falham.

**Q: Custo típico?**
A: ~$0.30 por auditoria com Claude 3.5 Sonnet. Triagem rápida ~$0.05.

**Q: Suporta a minha linguagem X que não está nos 18?**
A: Sim — IA aplica conhecimento próprio + as 24 análises universais. Mas sem cartão dedicado, a deteção é menos profunda.

**Q: Posso usar para auditar código de cliente?**
A: Sim, com autorização escrita. Skill é defensiva pré-entrega — não é pentest live.

**Q: Os fixes podem ser auto-aplicados?**
A: Não automaticamente. IA propõe, tu (ou dev) aprovas. Auto-apply é risco demasiado.

**Q: Compliance GDPR/HIPAA/SOC2?**
A: Skill ajuda detetar issues de privacidade/auth (ver `outras-areas/privacidade-compliance.md`), mas não substitui audit formal.

**Q: Posso treinar a skill com o meu código?**
A: Não no sentido tradicional — não há ML training. Mas podes adicionar regras/patterns próprias em `analises/*.md` via PR.

---

## Próximos passos

1. **[Instala](INSTALL.md)** o adaptador da tua IA
2. **Testa** num projeto teu real (qualquer tamanho)
3. **Revê** os exemplos em [examples/](examples/) para ver outputs esperados
4. **Configura** integrações ([integracoes/README.md](integracoes/README.md)) se quiseres automatizar
5. **Contribui** se descobrires falsos positivos/negativos ([CONTRIBUTING.md](CONTRIBUTING.md))

---

## Recursos

- 📦 [INSTALL.md](INSTALL.md) — instalação por plataforma
- 📚 [examples/](examples/) — input + output reais (Node, Laravel, Django, Flutter, Solidity)
- ⚙️ [integracoes/](integracoes/) — pre-commit, GH Action, CLI, Semgrep
- 📖 [analises/](analises/) — 24 análises + metodologia
- 🌐 [linguagens/](linguagens/) — 18 cartões de linguagem
- 🏗️ [frameworks/](frameworks/) — 34 framework profiles
- 📱 [mobile/](mobile/) — track MASVS completo
- ☁️ [outras-areas/](outras-areas/) — cloud, IaC, ML, Web3, IoT
- 🤝 [CONTRIBUTING.md](CONTRIBUTING.md) — como contribuir
- 🔒 [SECURITY.md](SECURITY.md) — reportar vulnerabilidades

> *"Encontra agora o que um atacante encontrará depois — e mostra como fechar."*
