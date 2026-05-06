---
description: Auditoria de segurança completa via IA Security Skill
argument-hint: [path opcional]
---

Aplica a IA Security Skill ao $ARGUMENTS (ou ao projeto inteiro se não for indicado path).

Executa o workflow completo das 7 fases:
1. Reconhecimento e detecção de stack
2. Análise universal (24 categorias)
3. Análise específica por linguagem/framework detetado
4. Attack chains (mínimo 3 cadeias)
5. Self-review com confidence scoring
6. Cálculo de score e nível de blindagem
7. Geração do relatório (template fixo) + checklist pré-produção

Carrega o contexto seguindo as regras de loading hierárquico em `~/.claude/skills/seguranca/SKILL.md`.

Output: relatório Markdown único com score 0-100, mapa de superfícies, attack chains, achados detalhados com fix copy-paste, plano de correção em 4 fases e checklist final.
