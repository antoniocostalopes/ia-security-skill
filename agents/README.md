# Subagents — IA Security Skill

Subagent definitions para Claude Code. Permitem delegar a auditoria a um sub-contexto isolado, útil para:

- **Workflows compostos** — *"audita, depois aplica os Críticos, depois re-audita"*
- **Proteger contexto principal** — relatório longo (3-10K tokens) fica no subagent
- **Paralelismo** — auditar backend e mobile em paralelo via duas instâncias do subagent

## Subagent disponível

| Nome | Para quê |
|---|---|
| `auditor-seguranca` | Executa workflow completo das 7 fases e devolve relatório Markdown |

## Ativar o subagent

Os subagents não são ativados automaticamente pelo install da skill. Para o teres disponível:

### Opção A — User-scoped (todos os projetos)

```bash
mkdir -p ~/.claude/agents
cp ~/.claude/skills/seguranca/agents/auditor-seguranca.md ~/.claude/agents/
```

### Opção B — Project-scoped (só num projeto)

```bash
mkdir -p .claude/agents
cp ~/.claude/skills/seguranca/agents/auditor-seguranca.md .claude/agents/
```

### Opção C — Symlink (atualizações automáticas via `git pull`)

```bash
mkdir -p ~/.claude/agents
ln -s ~/.claude/skills/seguranca/agents/auditor-seguranca.md ~/.claude/agents/auditor-seguranca.md
```

## Como invocar

Depois de ativado, o agente principal pode delegar via Agent tool:

```
> audita o projeto via subagent auditor-seguranca para não poluir contexto
```

Ou em workflows compostos:

```
> usa o auditor-seguranca para auditar src/, depois aplica os fixes Críticos do relatório, depois pede ao auditor-seguranca para re-auditar e confirmar
```

## Não o queres ativar?

Sem problema. A skill funciona sem subagent — toda a auditoria corre no agente principal. O subagent é um atalho opcional para workflows mais elaborados.

## Tools disponíveis ao subagent

`Read`, `Glob`, `Grep`, `Bash` — read-only por design. Para aplicar fixes, o agente principal usa Edit/Write depois de receber o relatório.

Mais info sobre subagents em [docs.claude.com/claude-code](https://docs.claude.com/claude-code).
