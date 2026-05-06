---
description: Triagem rápida de segurança — só Críticos e Altos
argument-hint: [path opcional]
---

Aplica a IA Security Skill em modo **triagem rápida** ao $ARGUMENTS (ou ao projeto inteiro).

Atalho para code review pré-commit ou validação rápida de PR.

**Regras de scope:**
- Reportar **apenas** achados Críticos e Altos
- Ignorar Médios e Baixos
- Output curto: 1 linha por achado no formato `[Severidade] ficheiro:linha — descrição (1 frase) → fix (1 frase)`
- Sem secção de attack chains, sem checklist
- Manter self-review e confidence (achados <60% descartados)

Carrega só os ficheiros essenciais de `~/.claude/skills/seguranca/`:
- `analises/00-mindset-atacante.md`
- `analises/00-patterns-deteccao.md`
- `analises/00-falsos-positivos-comuns.md`
- Análises das categorias mais críticas: SQL injection, XSS, server-side injections, auth/sessão, tokens, uploads
- Cartão da linguagem dominante

Salta o resto. Objetivo: feedback útil em <15 segundos.

Se não houver Críticos nem Altos, responde apenas `✓ Nenhum Crítico/Alto detetado em <path>` e termina.
