# Integrações — IA Security Skill

Scripts e templates para integrar a skill no workflow de developer.

## O que tem aqui

| Ficheiro | Função | Quando usar |
|---|---|---|
| [`pre-commit-hook.sh`](pre-commit-hook.sh) | Bloquear commits com vulns críticas | Setup local de dev |
| [`github-action-pr-audit.yml`](github-action-pr-audit.yml) | Auditar PRs automaticamente | Quem usa GitHub Actions |
| [`cli-wrapper.sh`](cli-wrapper.sh) | Correr a skill via CLI | Auditoria standalone |
| [`semgrep-integration.sh`](semgrep-integration.sh) | Combinar Semgrep + skill | Análise híbrida (recall máximo) |

## Princípio das integrações

A skill por si só é **markdown** — precisa de uma IA para ser executada. Estas integrações automatizam a invocação:

```
Código    →    [Wrapper/Hook/Action]    →    IA (Claude/GPT)    →    Relatório
                       ↑
            Carrega skill como context
```

## Modelos de IA suportados

Os scripts assumem **Anthropic Claude API** por default (melhor para análise estruturada). Podes adaptar para:
- OpenAI (GPT-4 / GPT-4o)
- Google Gemini
- Local: Ollama com Llama 3.1+ ou DeepSeek

## Setup geral (one-time)

```bash
# 1. Clonar a skill
git clone https://github.com/antoniocostalopes/ia-security-skill ~/.iass

# 2. Configurar API key (Anthropic)
export ANTHROPIC_API_KEY="sk-ant-..."
# Adicionar ao ~/.bashrc ou ~/.zshrc para persistir

# 3. Tornar scripts executáveis
chmod +x ~/.iass/integracoes/*.sh
```

## Uso típico

### Auditoria pontual de um ficheiro
```bash
~/.iass/integracoes/cli-wrapper.sh app.js
```

### Pre-commit (bloquear vulns críticas)
```bash
ln -s ~/.iass/integracoes/pre-commit-hook.sh .git/hooks/pre-commit
```

### CI/CD (PRs)
```bash
mkdir -p .github/workflows
cp ~/.iass/integracoes/github-action-pr-audit.yml .github/workflows/security-audit.yml
# Adicionar ANTHROPIC_API_KEY como secret no GitHub repo
```

### Análise profunda combinada com Semgrep
```bash
~/.iass/integracoes/semgrep-integration.sh ./src
```

## Custos típicos (Anthropic Claude 3.5 Sonnet)

| Cenário | Tokens aprox. | Custo USD |
|---|---|---|
| Auditoria de 1 ficheiro pequeno (200 linhas) | ~15k | ~$0.05 |
| PR review (5 ficheiros, 1k linhas total) | ~30k | ~$0.10 |
| Auditoria completa pequena app | ~80k | ~$0.30 |
| Auditoria completa app média | ~200k | ~$0.80 |

**Sugestão:** rate limit nos scripts para evitar bills inesperadas. Adiciona `--max-budget` se preocupado.

## Limitações honestas

- **Não-determinístico:** mesma input → outputs ligeiramente diferentes entre invocações
- **Confidence variável:** depende do modelo escolhido
- **Falsos positivos:** mitigados por `analises/00-falsos-positivos-comuns.md` mas existem
- **Não substitui SAST tools:** complementa Semgrep/CodeQL/Snyk, não substitui

## Troubleshooting

| Problema | Solução |
|---|---|
| `ANTHROPIC_API_KEY not set` | Exportar a key no ambiente |
| Skill não carregada | Verificar path em `--read` flag |
| Output sem formato esperado | Atualizar para Claude 3.5 Sonnet (mais antigos podem variar) |
| Rate limit hit | Adicionar `sleep 2` entre chamadas no script |

## Contribuir

Mais integrações úteis:
- VS Code extension wrapper
- IntelliJ plugin
- Slack/Discord bot
- Pre-receive hook server-side (Git server)
- GitLab CI / Bitbucket Pipelines templates

PRs welcome.
