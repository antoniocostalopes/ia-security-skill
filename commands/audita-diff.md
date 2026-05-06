---
description: Auditoria de segurança ao git diff vs main
argument-hint: [base-branch opcional, default origin/main]
---

Aplica a IA Security Skill **apenas às alterações** do diff atual.

**Determinação do diff (por esta ordem):**
1. Se $ARGUMENTS for fornecido, usa como base branch (ex: `develop`, `release/v2`)
2. Senão usa `origin/main` (default)
3. Diff a auditar: `git diff <base>...HEAD` + alterações staged + alterações não-staged no working tree

**Antes de auditar:**
- Corre `git status` para confirmar branch atual e estado
- Corre `git diff --stat <base>...HEAD` para ver scope das mudanças
- Lista ficheiros afetados

**Auditoria:**
- Foca **só nas linhas alteradas** + contexto imediato (±10 linhas)
- Para cada ficheiro alterado, lê o ficheiro completo apenas se necessário para verificar fluxo (taint analysis, validação a montante, etc.)
- Aplica workflow das 7 fases mas com scope reduzido às mudanças
- Attack chains: prioritiza chains que **envolvam** código novo + código existente

**Output:**
- Relatório curto: score do diff (0-100, não do projeto inteiro), achados detalhados só nas mudanças, recomendação clara para o reviewer (`✓ aprovar` / `⚠ pedir alterações` / `✗ bloquear merge`)
- Não anexar checklist de produção (este modo é para PR review, não para deploy final)

Útil para code review automatizado em PRs. Para auditoria completa do projeto inteiro usa `/audita`.
