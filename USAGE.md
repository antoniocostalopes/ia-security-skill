# Usar a IA Security Skill no Claude Code

Guia prático para developers que já têm Claude Code instalado e querem fazer auditoria de segurança defensiva ao seu código antes do deploy.

---

## Quick start (60 segundos)

```bash
# 1. Instalar (uma vez)
git clone https://github.com/antoniocostalopes/ia-security-skill ~/.claude/skills/seguranca

# 2. Usar (em qualquer projeto)
cd ~/projetos/o-meu-projeto
claude
> audita este projeto
```

Pronto. Em ~30 segundos tens um relatório Markdown completo.

---

## Como invocar a skill

O Claude Code lê o frontmatter de [`SKILL.md`](SKILL.md) e ativa a skill quando o teu prompt bate com a descrição. Estes prompts funcionam:

| Quando queres | Diz |
|---|---|
| Auditoria completa do projeto | `audita este projeto` |
| Security review do diretório atual | `faz security review aqui` |
| Auditar 1 ficheiro/pasta específico | `audita src/auth/` |
| Auditar antes de commit | `audita as alterações que vou commitar` |
| Auditar PR/diff | `audita o diff vs main` |
| Triagem rápida (só Críticos/Altos) | `triagem rápida — só críticos e altos` |
| Re-auditoria depois de fix | `audita de novo e mostra o que mudou` |
| Aplicar fixes do relatório | `aplica os fixes Críticos` |

A skill também ativa quando dizes coisas como *"vê se isto tem vulnerabilidades"*, *"isto está seguro?"*, *"que problemas de segurança tem este código?"*.

---

## O que acontece nos bastidores

### Fase 1 — Reconhecimento
O Claude Code lê manifests (`package.json`, `composer.json`, `requirements.txt`, `pyproject.toml`, `Gemfile`, `go.mod`, `pom.xml`, `*.csproj`, `mix.exs`, `Cargo.toml`, `Info.plist`, `AndroidManifest.xml`, `pubspec.yaml`, `Dockerfile`, `*.tf`, `*.sol`, etc.) para detetar:
- Linguagens dominantes
- Frameworks específicos
- Plataforma (web/mobile/cloud/IaC/web3)

### Fase 2 — Análise universal
Aplica as **24 categorias** de [`analises/`](analises/) a qualquer projeto: XSS, SQLi, CSRF, permissões, REST API, uploads, tokens, exposição, criptografia, auth, hardening, headers, dependências, business logic, server-side injections, SSRF, DoS, logging, APIs modernas, email/SMS.

### Fase 3 — Análise específica
Carrega só os ficheiros de [`linguagens/`](linguagens/) e [`frameworks/`](frameworks/) que correspondem ao stack detetado. Tipicamente 2-5 ficheiros, não 52.

### Fase 4 — Attack chains (mínimo 3)
Cruza achados procurando combinações que escalam severidade. Ex: *XSS armazenado + admin sem 2FA + cookies sem `HttpOnly` = ATO completo*.

### Fase 5 — Self-review com confidence
Re-avalia cada achado com pergunta *"isto é exploit real ou pattern match?"*. Atribui confidence:
- **95%** — verificado, exploração confirmada
- **80%** — alta confiança, contexto típico
- **60%** — provável, requer verificação manual
- **40%** — suspeita, pode ser falso positivo

Achados <40% são descartados. Ver [`analises/00-falsos-positivos-comuns.md`](analises/00-falsos-positivos-comuns.md).

### Fase 6 — Score & blindagem
Aplica fórmula de [`relatorio/score-blindagem.md`](relatorio/score-blindagem.md):
- **0-30** Crítico
- **31-50** Vulnerável
- **51-70** Aceitável
- **71-85** Sólido
- **86-100** Blindado

### Fase 7 — Relatório
Markdown único usando o template fixo em [`relatorio/template.md`](relatorio/template.md), anexa [`relatorio/checklist-producao.md`](relatorio/checklist-producao.md).

---

## Anatomia do relatório

Todo o output segue esta estrutura (10 secções):

```markdown
# Auditoria de Segurança — <projeto>
> Data · Stack · Auditor

## 1. Score
**62/100 — Aceitável (mas com 3 Críticos a fechar antes do deploy)**

## 2. Resumo executivo (cliente)
3 parágrafos em linguagem clara, sem jargão.

## 3. Resumo técnico
Lista bullet por categoria com counts.

## 4. Mapa de superfícies de ataque
- Entry points HTTP / API / WebSocket
- Trust boundaries
- Dados sensíveis (PII, tokens, secrets)

## 5. Attack chains (mínimo 3)
Chain #1: <vetor inicial> → <escalação> → <impacto final>

## 6. Achados detalhados
### CRÍTICO #1 — SQL Injection em /api/users [confidence 95%]
- Localização: src/routes/users.js:42
- Código vulnerável: ...
- Exploração: ...
- Correção (copy-paste): ...

## 7. Plano de correção em 4 fases
- Fase 1 (HOJE): Críticos
- Fase 2 (esta semana): Altos
- Fase 3 (este sprint): Médios
- Fase 4 (hardening): Baixos

## 8. Checklist pré-produção
- [ ] Headers HTTP (CSP, HSTS, X-Frame-Options)
- [ ] Auth/sessão (...)
- [ ] ...

## 9. Recomendações estratégicas
Próximos passos para subir maturidade.

## 10. Notas e limitações
O que a skill não verificou (ex: pentest live, runtime).
```

---

## Aplicar fixes

Depois do relatório, podes:

**Manual:** copiar o bloco "Correção" de cada achado e colar no ficheiro.

**Automático via Claude Code:**
```
aplica os fixes Críticos
```
ou
```
aplica todos os fixes do relatório, mostra-me o diff antes de gravar
```

A skill segue as correções tal como propostas. Para fixes complexos pede revisão antes de aplicar.

---

## Re-auditoria / iteração

Depois de aplicar fixes:

```
audita de novo e compara com o relatório anterior
```

O Claude Code reexecuta o workflow e mostra:
- Score antes / depois
- Achados resolvidos
- Achados que persistem
- Novos achados introduzidos pelos fixes (raro mas acontece)

Iterar até score >85 ou Críticos = 0.

---

## 5 cenários típicos

### 1. Pre-deploy de feature nova
```
audita src/checkout/ — vou fazer deploy esta tarde
```
Skill foca em superfícies novas, attack chains que cruzam código novo + existente.

### 2. Code review em PR
```
audita as alterações vs origin/main
```
Skill lê o diff e audita só o que mudou (mais rápido, menos ruído).

### 3. Triagem rápida
```
triagem rápida — só Críticos e Altos, output curto
```
Lista 1 linha por achado: `[Severidade] ficheiro:linha — descrição + fix em 1 linha`.

### 4. Auditoria completa periódica
```
audita o projeto todo, completo
```
Workflow completo, todas as 7 fases, relatório longo. Para revisões trimestrais.

### 5. Hardening proativo
```
o projeto não tem vulnerabilidades críticas mas quero hardening — sugere melhorias
```
Skill foca em camadas defensivas extra: CSP estrito, rate limiting, defense-in-depth, observabilidade de segurança.

---

## Limitações honestas

A skill **não** faz:

- **Pentest live** — não envia tráfego para o teu servidor, só lê código
- **Análise dinâmica / runtime** — não corre o código, não vê comportamento real
- **SAST com flow analysis profunda** — para isso usa Semgrep, CodeQL, Snyk em paralelo
- **Compliance auditing formal** — para PCI-DSS/HIPAA/SOC2 contrata auditor certificado
- **Validação contra threat model do teu negócio** — só vê código, não conhece o teu modelo de ameaça
- **Deteção de vulnerabilidades em dependências (CVEs)** — usa `npm audit` / `pip-audit` / Dependabot

A skill **complementa** estas ferramentas, não substitui.

### Falsos positivos / falsos negativos

A skill tem self-review pass mas pode ainda:
- Reportar XSS num campo que afinal está sanitizado a montante (FP)
- Não detetar vulnerabilidade lógica de negócio que requer entender intenção (FN)

Trata o relatório como **ponto de partida da revisão**, não verdade absoluta. Confidence scores ajudam a priorizar.

---

## FAQ rápido

**P: Tenho de copiar ficheiros para os meus projetos?**
R: Não. Instalas uma vez em `~/.claude/skills/seguranca/` e funciona em qualquer projeto.

**P: A skill envia o meu código para algum servidor?**
R: Só para o Claude Code (Anthropic), tal como qualquer outra interação. A skill em si é só ficheiros locais.

**P: Posso usar esta skill em projetos privados/comerciais?**
R: Sim. MIT license. Vê [LICENSE](LICENSE).

**P: Funciona em Windows / Mac / Linux?**
R: Sim. Só requer `git clone` para `~/.claude/skills/seguranca/`. No Windows é `%USERPROFILE%\.claude\skills\seguranca\`.

**P: Como atualizo?**
R: `cd ~/.claude/skills/seguranca && git pull`.

**P: A skill conhece o framework X?**
R: Vê [`frameworks/`](frameworks/). Se não lá estiver, pede via issue ou contribui via PR.

**P: Posso desativar análises específicas?**
R: Sim. No prompt: *"audita mas ignora deteção de DoS — vamos tratar disso depois"*.

**P: A skill pesa muito no contexto do Claude Code?**
R: Não. Carregamento hierárquico — só carrega ficheiros do stack detetado (15-50 ficheiros tipicamente).

**P: Posso usar com Claude Code em CI/CD?**
R: Sim, via `claude --print` ou `claude --headless` em GitHub Actions. Vê [docs.claude.com/claude-code](https://docs.claude.com/claude-code).

**P: A skill foca em segurança ofensiva?**
R: **Não.** É 100% defensiva — auditoria pré-entrega de código próprio/autorizado. Rejeita pedidos de pentest contra terceiros.

---

## Próximos passos

1. Instala: `git clone https://github.com/antoniocostalopes/ia-security-skill ~/.claude/skills/seguranca`
2. Audita um projeto: `claude` → `audita este projeto`
3. Vê exemplos: [Node](examples/audit-example-node.md) · [Laravel](examples/audit-example-php-laravel.md) · [Django](examples/audit-example-python-django.md) · [Flutter](examples/audit-example-mobile-flutter.md) · [Solidity](examples/audit-example-web3-solidity.md)
4. Star o repo se ajudar: [github.com/antoniocostalopes/ia-security-skill](https://github.com/antoniocostalopes/ia-security-skill)
