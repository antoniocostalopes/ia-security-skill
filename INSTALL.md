# Instalação — IA Security Skill (Claude Code)

A skill é nativa do Claude Code. Instalas uma vez globalmente e fica disponível em qualquer projeto onde corras `claude`.

---

## Pré-requisitos

- **Claude Code** instalado e configurado ([docs.claude.com/claude-code](https://docs.claude.com/claude-code))
- **Git** disponível na PATH

---

## Instalação global (recomendada)

Disponível em todos os projetos onde uses Claude Code:

### macOS / Linux

```bash
git clone https://github.com/antoniocostalopes/ia-security-skill ~/.claude/skills/seguranca
```

### Windows (PowerShell)

```powershell
git clone https://github.com/antoniocostalopes/ia-security-skill "$env:USERPROFILE\.claude\skills\seguranca"
```

### Windows (Git Bash / WSL)

```bash
git clone https://github.com/antoniocostalopes/ia-security-skill ~/.claude/skills/seguranca
```

Pronto. **Zero configuração adicional.** O Claude Code deteta automaticamente a skill via o frontmatter de [`SKILL.md`](SKILL.md).

---

## Instalação por projeto (opcional)

Se preferires versionar a skill com um projeto específico (ex: para a equipa toda usar a mesma versão):

```bash
cd ~/projetos/o-meu-projeto
git clone https://github.com/antoniocostalopes/ia-security-skill .claude/skills/seguranca
```

E adiciona ao `.gitignore` se não quiseres comitar:
```
.claude/skills/seguranca/
```

Ou comita normalmente para fixar a versão para a equipa.

---

## Verificação

Em qualquer projeto:

```bash
claude
> qual é o lema da skill seguranca?
```

Resposta esperada:
> *"Encontra agora o que um atacante encontrará depois — e mostra como fechar."*

Se o Claude Code disser que não conhece a skill, verifica:

```bash
ls ~/.claude/skills/seguranca/SKILL.md
```

O ficheiro deve existir.

---

## Primeira auditoria

```bash
cd ~/projetos/qualquer-projeto
claude
> audita este projeto
```

Em ~30 segundos recebes um relatório Markdown com score, attack chains, achados e fixes. Ver [USAGE.md](USAGE.md) para detalhes.

---

## Extras opcionais

### Slash commands `/audita*`

Atalhos `/audita`, `/audita-rapido`, `/audita-diff` para invocação determinística:

```bash
mkdir -p ~/.claude/commands
cp ~/.claude/skills/seguranca/commands/audita*.md ~/.claude/commands/
```

Detalhes em [`commands/README.md`](commands/README.md).

### Subagent `auditor-seguranca`

Para workflows compostos (audit → apply fixes → re-audit) ou proteger contexto principal:

```bash
mkdir -p ~/.claude/agents
cp ~/.claude/skills/seguranca/agents/auditor-seguranca.md ~/.claude/agents/
```

Detalhes em [`agents/README.md`](agents/README.md).

---

## Atualizar

```bash
cd ~/.claude/skills/seguranca && git pull
```

Releases novos saem como tags `v1.x.x`. Para fixar uma versão específica:

```bash
cd ~/.claude/skills/seguranca && git checkout v1.0.0
```

---

## Desinstalar

```bash
rm -rf ~/.claude/skills/seguranca
```

(Windows: `Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\skills\seguranca"`)

---

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| Claude Code não ativa a skill | Pasta no sítio errado | Confirma `~/.claude/skills/seguranca/SKILL.md` existe |
| Skill ativa mas análise superficial | Stack não detetado | Verifica que tens manifests (`package.json`, etc.) na raiz do projeto |
| Falsos positivos altos | Framework não conhecido | Pede `audita usando o profile X` ou contribui com novo profile via PR |
| Mobile não analisado | Sem manifests mobile | Confirma `Info.plist` / `AndroidManifest.xml` / `pubspec.yaml` presentes |
| `git clone` falha em Windows com path longo | Limite de 260 chars | `git config --global core.longpaths true` |

---

## Notas

- Esta skill é **específica do Claude Code**. Para outras IAs (Cursor, ChatGPT, Copilot, etc.), garfa o repo e adapta — contribuições back via PR são bem-vindas.
- A skill **não** envia o teu código para nenhum servidor externo. É só ficheiros Markdown locais que o Claude Code carrega no contexto da conversa.
- Ver [SECURITY.md](SECURITY.md) para reportar vulnerabilidades na própria skill.
