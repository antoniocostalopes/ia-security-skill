# Instalação — IA Security Skill v1.0

A skill funciona em qualquer IA. Escolhe a tua plataforma.

## Claude Code (CLI)

**Global** (todos os projetos):
```bash
git clone https://github.com/antoniocostalopes/ia-security-skill ~/.claude/skills/seguranca
```

**Por projeto:**
```bash
git clone https://github.com/antoniocostalopes/ia-security-skill .claude/skills/seguranca
```

**Uso:** dentro de qualquer projeto, pede *"audita este projeto"* / *"faz security review"*.

A IA deteta o stack automaticamente e carrega só o contexto relevante (15-25 ficheiros).

---

## Claude.ai (browser, Projects)

1. Descarrega ZIP / `git clone`
2. Em **claude.ai** → cria **Project** ("Auditoria de Segurança")
3. **Project knowledge:** upload da pasta inteira (suporta muitos ficheiros)
4. **Custom instructions:** Persona + Workflow do `PROMPT.md`

---

## ChatGPT Custom GPT

ChatGPT limita Knowledge a **20 ficheiros**. Como a skill total tem ~112, criámos **bundles especializados**.

1. **Explore GPTs** → **+ Create**
2. **Configure:**
   - **Name:** Auditoria de Segurança Universal
   - **Description:** Hacker amigável que ajuda a blindar código antes da entrega
   - **Instructions:** colar **`PROMPT-COMPACTO.md`** (5811 chars)
   - **Knowledge:** seguir um dos bundles em **[`bundles/chatgpt-knowledge.md`](bundles/chatgpt-knowledge.md)**:
     - **Universal Web** (default, recomendado)
     - **Mobile** (iOS, Android, RN, Flutter, MASVS)
     - **Cloud / DevOps** (containers, IaC, AWS/GCP/Azure, CI/CD)
     - **Node Full-Stack** (Express/Next/Nest)
     - **Python Full-Stack** (Django/Flask/FastAPI)
     - **PHP/WordPress/Laravel**
     - **Web3 / Smart Contracts**
3. **Capabilities:** desligar Web Browse / DALL·E
4. **Save** → partilhar link

---

## Cursor / Windsurf

```bash
git clone https://github.com/antoniocostalopes/ia-security-skill /tmp/skill
cp /tmp/skill/AGENTS.md ./AGENTS.md
cp -r /tmp/skill/{analises,linguagens,frameworks,mobile,outras-areas,relatorio} .cursor/
```

`AGENTS.md` é detetado automaticamente em Cursor 0.43+.

---

## GitHub Copilot

```bash
mkdir -p .github
curl -sSL https://raw.githubusercontent.com/antoniocostalopes/ia-security-skill/main/PROMPT-COMPACTO.md \
  -o .github/copilot-instructions.md
```

---

## Gemini / DeepSeek / Mistral / generic LLM

`PROMPT.md` (versão completa) ou `PROMPT-COMPACTO.md` (versão tight).

1. Cola como system prompt ou primeira mensagem
2. Cola código para auditar
3. Pede análise

---

## Aider

```bash
git clone https://github.com/antoniocostalopes/ia-security-skill /tmp/skill
aider --read /tmp/skill/PROMPT.md \
      --read /tmp/skill/analises/*.md
```

---

## Continue (VS Code)

`~/.continue/config.json` → `systemMessage` com conteúdo de `PROMPT-COMPACTO.md`.

---

## Verificação

Em qualquer cliente:

> *"Qual é o lema desta skill?"*

Resposta esperada:
> *"Encontra agora o que um atacante encontrará depois — e mostra como fechar."*

> *"Quantas linguagens cobre?"*

Resposta esperada:
> *"18 — JavaScript/TypeScript, Python, PHP, Java, C#/.NET, Go, Ruby, Rust, Kotlin, Swift, Dart, C/C++, Scala, Elixir, Shell/Bash, SQL, GraphQL, Solidity"*

---

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| Claude Code não ativa skill | Pasta no sítio errado | Confirma `~/.claude/skills/seguranca/SKILL.md` existe |
| ChatGPT corta prompt | Usaste `PROMPT.md` em Instructions | Usa `PROMPT-COMPACTO.md` (5800 chars) |
| Cursor ignora AGENTS.md | Versão antiga | Atualiza Cursor 0.43+ |
| Análise superficial | Stack não detetado | Verifica que `linguagens/` e `frameworks/` estão acessíveis |
| Mobile não analisado | `mobile/` não carregado | Confirma que pasta `mobile/` está na Knowledge ou filesystem |
| Falsos positivos altos | Skill não conhece o framework | Pede para ler o profile específico do framework |

---

## Atualizar

```bash
cd ~/.claude/skills/seguranca && git pull
```

Ou re-correr `install.sh`.
