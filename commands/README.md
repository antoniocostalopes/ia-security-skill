# Slash Commands — IA Security Skill

Atalhos para invocação determinística da skill via `/comando`. Alternativa aos prompts em linguagem natural.

## Comandos disponíveis

| Comando | O que faz | Quando usar |
|---|---|---|
| `/audita [path]` | Auditoria completa (7 fases) | Pre-deploy, security review periódica |
| `/audita-rapido [path]` | Triagem (só Críticos/Altos, output curto) | Pre-commit, sanity check |
| `/audita-diff [base-branch]` | Auditoria das mudanças do diff vs base | PR review, validação de feature branch |

## Ativar os comandos

Os comandos não são ativados automaticamente pelo install da skill. Para os teres disponíveis no `/`:

### Opção A — User-scoped (todos os projetos)

```bash
mkdir -p ~/.claude/commands
cp ~/.claude/skills/seguranca/commands/audita*.md ~/.claude/commands/
```

### Opção B — Project-scoped (só num projeto)

```bash
mkdir -p .claude/commands
cp ~/.claude/skills/seguranca/commands/audita*.md .claude/commands/
```

### Opção C — Symlink (atualizações automáticas via `git pull`)

```bash
mkdir -p ~/.claude/commands
for cmd in audita audita-rapido audita-diff; do
  ln -s ~/.claude/skills/seguranca/commands/$cmd.md ~/.claude/commands/$cmd.md
done
```

## Não os queres ativar?

Sem problema. A skill ativa automaticamente via SKILL.md description quando dizes *"audita este projeto"*, *"faz security review"*, etc. Os slash commands são só atalhos opcionais para invocação determinística.

## Como funcionam

Cada `.md` neste folder tem frontmatter com `description` e `argument-hint`, seguido do prompt que será injetado na conversa quando o user escreve `/comando`. O `$ARGUMENTS` é substituído pelo que o user escrever depois do nome do comando.

Mais info sobre slash commands em [docs.claude.com/claude-code](https://docs.claude.com/claude-code).
